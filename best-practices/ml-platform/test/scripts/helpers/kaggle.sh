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

if [ -z "${1}" ]; then
    echo_error "Missing kaggle arguments"
    exit 1
fi
kaggle_args=${1}

echo_title "Checking kaggle cli"

print_and_execute "kaggle ${kaggle_args}"
exit_code=${?}

case ${exit_code} in
0)
    echo_success "kaggle cli found and configured"
    ;;
1)
    echo_error "Missing kaggle credentials"
    ;;
2)
    echo_error "Malformed kaggle command"
    ;;
127)
    echo_error "kaggle cli not found"
    ;;
*)
    echo_error "Unhandled exit code ${exit_code}"
    ;;
esac
