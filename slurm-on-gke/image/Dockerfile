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

FROM ubuntu:22.04

ARG SLURM_TAG=slurm-23.02
ARG GOSU_VERSION=1.11


RUN set -x \
    && apt-get update \
    && apt-get install -y \
       wget \
       gcc \
       git \
       make \
       munge \
       libmunge-dev \
       python3-dev \
       python3-pip \
       python3 \
       hwloc \
       libhwloc-dev \
       libpmix-dev \
       libhttp-parser-dev \
       libmysqlclient-dev \
       libjson-c-dev \
       psmisc \
       bzip2 \
       python3-http-parser \
       nvidia-utils-535 \
       nvidia-cuda-toolkit-gcc \
       nvidia-cuda-dev \
       libnvidia-compute-535 \
       mariadb-server \
       libdbus-1-dev \
       openmpi-common \
       openmpi-bin \
       vim 

RUN pip3 install Cython nose

RUN set -ex \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -rf "${GNUPGHOME}" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

ENV SHELL=/bin/bash
RUN set -x \
    && git clone -b ${SLURM_TAG} --single-branch --depth=1 https://github.com/SchedMD/slurm.git \
    && cd slurm \
    && ./configure --enable-debug --prefix=/usr --sysconfdir=/etc/slurm \
        --with-mysql_config=/usr/bin  --libdir=/usr/lib64 \
    && make install \
    && install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh \
    && cd .. \
    && rm -rf slurm

RUN mkdir /var/spool/slurmd \
        /var/run/slurmd \
        /var/run/slurmdbd \
        /var/lib/slurmd \
        /var/log/slurm \
        /data \
        /etc/slurm \
    && touch /var/lib/slurmd/node_state \
        /var/lib/slurmd/front_end_state \
        /var/lib/slurmd/job_state \
        /var/lib/slurmd/resv_state \
        /var/lib/slurmd/trigger_state \
        /var/lib/slurmd/assoc_mgr_state \
        /var/lib/slurmd/assoc_usage \
        /var/lib/slurmd/qos_usage \
        /var/lib/slurmd/fed_mgr_state \
    && useradd -r --uid=990 slurm \
    && chown -R slurm:slurm /var/*/slurm*

WORKDIR /opt
RUN export VERSION=1.18 OS=linux ARCH=amd64 \
    && wget https://dl.google.com/go/go$VERSION.$OS-$ARCH.tar.gz \
    && tar -xzvf go$VERSION.$OS-$ARCH.tar.gz \
    && export PATH=$PWD/go/bin:$PATH \
    && git clone https://github.com/vpenso/prometheus-slurm-exporter.git \
    && cd prometheus-slurm-exporter \
    && go build

RUN mv /opt/prometheus-slurm-exporter/prometheus-slurm-exporter /usr/local/bin

RUN mkdir -p /run/munge \
    && chown munge.munge /run/munge

VOLUME /etc/slurm
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["slurmdbd"]