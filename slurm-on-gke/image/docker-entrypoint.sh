#!/bin/bash
# MIT License

# Copyright (c) 2019 Giovanni Torres

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -euo pipefail

function start_munge(){

    echo "---> Copying MUNGE key ..."
    cp /tmp/munge.key /etc/munge/munge.key
    chown munge:munge /etc/munge/munge.key

    echo "---> Starting the MUNGE Authentication service (munged) ..."
    gosu munge /usr/sbin/munged "$@"
}

if [ "$1" = "slurmdbd" ]
then

    start_munge

    echo "---> Starting the Slurm Database Daemon (slurmdbd) ..."

    cp /tmp/slurmdbd.conf /etc/slurm/slurmdbd.conf
    echo "StoragePass=${StoragePass}" >> /etc/slurm/slurmdbd.conf
    chown slurm:slurm /etc/slurm/slurmdbd.conf
    chmod 600 /etc/slurm/slurmdbd.conf
    {
        . /etc/slurm/slurmdbd.conf
        until echo "SELECT 1" | mysql -h $StorageHost -u$StorageUser -p$StoragePass 2>&1 > /dev/null
        do
            echo "-- Waiting for database to become active ..."
            sleep 2
        done
    }
    echo "-- Database is now active ..."

    exec gosu slurm /usr/sbin/slurmdbd -D "${@:2}"

elif [ "$1" = "slurmctld" ]
then

    start_munge

    echo "---> Waiting for slurmdbd to become active before starting slurmctld ..."

    until 2>/dev/null >/dev/tcp/slurmdbd/6819
    do
        echo "-- slurmdbd is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmdbd is now active ..."

    echo "---> Setting permissions for state directory ..."
    chown slurm:slurm /var/spool/slurmctld

    echo "---> Starting the Slurm Controller Daemon (slurmctld) ..."
    if /usr/sbin/slurmctld -V | grep -q '17.02' ; then
        exec gosu slurm /usr/sbin/slurmctld -D "${@:2}"
    else
        exec gosu slurm /usr/sbin/slurmctld -i -D "${@:2}"
    fi

elif [ "$1" = "slurmd" ]
then
    echo "---> Set shell resource limits ..."
    #ulimit -l unlimited
    #ulimit -s unlimited
    #ulimit -n 131072
    #ulimit -a

    start_munge

    cgroup_dir=`find /sys/fs/cgroup/kubepods.slice -type d -name "kubepods-pod*"`    
    mkdir -p "$cgroup_dir/system.slice/slurmstepd.scope/system.slice/slurmstepd.scope"
    mkdir -p "/var/spool/slurmd"

    echo "---> Starting the Slurm Node Daemon (slurmd) ..."
    echo "${@:1}"
    exec slurmd -D -s -vvv --conf-server="slurmctld-0:6820-6830" -Z -N $POD_NAME

elif [ "$1" = "login" ]
then    
    
    start_munge
    while true; do sleep 30; done;
    
elif [ "$1" = "check-queue-hook" ]
then
    start_munge

    scontrol update NodeName=all State=DRAIN Reason="Preventing new jobs running before upgrade"

    RUNNING_JOBS=$(squeue --states=RUNNING,COMPLETING,CONFIGURING,RESIZING,SIGNALING,STAGE_OUT,STOPPED,SUSPENDED --noheader --array | wc --lines)

    if [[ $RUNNING_JOBS -eq 0 ]]
    then
        exit 0
    else
        exit 1
    fi

elif [ "$1" = "undrain-nodes-hook" ]
then
    start_munge
    scontrol update NodeName=all State=UNDRAIN
    exit 0

elif [ "$1" = "generate-keys-hook" ]
then
    mkdir -p ./temphostkeys/etc/ssh
    ssh-keygen -A -f ./temphostkeys
    kubectl create secret generic host-keys-secret \
    --dry-run=client \
    --from-file=./temphostkeys/etc/ssh \
    -o yaml | \
    kubectl apply -f -
    
    exit 0
    
elif [ "$1" = "debug" ]
then
    start_munge --foreground

else
    exec "$@"
fi
