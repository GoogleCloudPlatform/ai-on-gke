#!/usr/bin/env bash

# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function check_local_error() {
    printf "\n"
    if [ ${local_error} -ne 0 ]; then
        echo_error "There was an error while executing the script, review the output."
    fi
    printf "\n"
}

function check_local_error_and_exit() {
    check_local_error

    if [ ! -z ${MLP_LOG_FILE} ]; then
        printf "\n"
        echo_bold "A log file is available at '${MLP_LOG_FILE}'"
        printf "\n"
    fi

    exit ${local_error}
}

function check_local_error_exit_on_error() {
    if [ ${local_error} -ne 0 ]; then
        check_local_error_and_exit
    fi
}

function get_lock_file() {
    lock_name="${1}"

    echo "${MLP_LOCK_DIR}/${MLP_SCRIPT_NAME}-${lock_name}.lock"
}

function lock_is_set() {
    lock_name="${1}"

    lock_file=$(get_lock_file "${lock_name}")
    if [ -f ${lock_file} ]; then
        # lock is set
        return 0
    fi

    # lock is NOT set
    return 1
}

function lock_set() {
    lock_name="${1}"

    lock_file=$(get_lock_file "${lock_name}")
    if [ ! -f ${lock_file} ]; then
        touch ${lock_file}
    else
        echo_warning "Lock ${lock_name} was already set"
    fi
}

function lock_unset() {
    lock_name="${1}"

    lock_file=$(get_lock_file "${lock_name}")
    if [ -f ${lock_file} ]; then
        rm -f ${lock_file}
    else
        echo_warning "Lock ${lock_name} was not set"
    fi

}

declare -A runtime=()

function start_runtime() {
    component="${1}"

    start_timestamp=$(date +%s)

    if [[ ${!runtime[@]} =~ ${component} ]]; then
        echo_warning "Component ${component} runtime counter already exists, using existing value"
    else
        runtime[${component}]=${start_timestamp}
    fi
}

function total_runtime() {
    component="${1}"

    end_timestamp=$(date +%s)

    total_runtime_value=0
    if [[ ${!runtime[@]} =~ ${component} ]]; then
        start_timestamp=${runtime[${component}]}
        total_runtime_value=$((end_timestamp - start_timestamp))
    else
        echo_warning "Component ${component} does not exist, cannot calculate runtime"
    fi

    echo_bold "Total runtime for ${component}: $(date -d@${total_runtime_value} -u +%H:%M:%S)"
}
