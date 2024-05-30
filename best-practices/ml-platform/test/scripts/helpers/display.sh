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

# Styles
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

# Colors
CYAN='\033[1;36m'
GREEN='\e[1;32m'
RED='\e[1;91m'
YELLOW="\e[38;5;226m"
RESET='\e[0m'

function echo_bold() {
    echo "${BOLD}${@}${NORMAL}"
}

function echo_error() {
    echo -e "${RED}${@}${RESET}"
}

function echo_success() {
    echo -e "${GREEN}${@}${RESET}"
}

function echo_title() {
    echo
    echo "${BOLD}# ${@}${NORMAL}"
}

function echo_warning() {
    echo -e "${YELLOW}${@}${RESET}"
}

function print_and_execute() {
    clean_command=$(echo ${@} | tr -s ' ')
    printf "${GREEN}\$ ${clean_command}${RESET}"
    printf "\n"
    eval "${clean_command}"
    return_code=$?

    if [ -z ${NO_LOG} ]; then
        if [ ${return_code} -eq "0" ]; then
            echo_success "[OK]"
        else
            echo_error "[Return Code: ${return_code}]"
            local_error=$(($local_error + 1))
        fi
    fi
    echo

    return ${return_code}
}
