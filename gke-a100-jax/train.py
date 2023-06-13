# Copyright 2023 Google LLC
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
#

import jax
import os
import socket
import time

from absl import flags
from absl import app
from absl import logging

flags.DEFINE_integer('num_processes', 1, 'Number of processes')
flags.DEFINE_string('job_name', None, 'Job name')
flags.DEFINE_string('sub_domain', None, 'Service sub domain')
flags.DEFINE_string('coordinator_port', None, 'Port the coordinator listens on')
flags.mark_flag_as_required('job_name')
flags.mark_flag_as_required('sub_domain')
flags.mark_flag_as_required('coordinator_port')

FLAGS = flags.FLAGS

def _get_coordinator_ip_address(job_name, sub_domain):
    coordinator_fqdn = f'{FLAGS.job_name}-0.{FLAGS.sub_domain}'
    print(f'Coordinator host name: {coordinator_fqdn}') 

    for retry_attempt in range(120):
        try:
            time.sleep(1)
            coordinator_ipaddress = socket.gethostbyname(coordinator_fqdn)
        except socket.gaierror:
            print(f'Failed to resolve: {coordinator_fqdn}. Trying again in a second ...') 
        else:
            break

    print(f'Coordinator IP address: {coordinator_ipaddress}')

    return coordinator_ipaddress

def _main(argv):

    process_id = int(os.getenv("JOB_COMPLETION_INDEX"))
    num_processes = FLAGS.num_processes
    coordinator_address = _get_coordinator_ip_address(FLAGS.job_name, FLAGS.sub_domain)
    coordinator_address = f'{coordinator_address}:{FLAGS.coordinator_port}'

    jax.distributed.initialize(coordinator_address=coordinator_address,
                                num_processes=num_processes,
                                process_id=process_id)

    print(f'JAX process {jax.process_index()}/{jax.process_count()} initialized on {socket.gethostname()}')
    print(f'JAX global devices:{jax.devices()}')
    print(f'JAX local devices:{jax.local_devices()}')

    xs = jax.numpy.ones(jax.local_device_count())
    print(jax.pmap(lambda x: jax.lax.psum(x, 'i'), axis_name='i')(xs))

if __name__ == "__main__":
    app.run(_main)
