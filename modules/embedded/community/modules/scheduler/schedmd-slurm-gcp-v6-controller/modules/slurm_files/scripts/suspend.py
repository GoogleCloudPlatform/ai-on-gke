#!/usr/bin/env python3

# Copyright (C) SchedMD LLC.
# Copyright 2015 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from typing import List
import argparse
import logging

import util
from util import (
    groupby_unsorted,
    log_api_request,
    batch_execute,
    to_hostlist_fast,
    wait_for_operations,
    separate,
    execute_with_futures,
)
from util import lookup, TPU

import slurm_gcp_plugins

log = logging.getLogger()

TOT_REQ_CNT = 1000


def truncate_iter(iterable, max_count):
    end = "..."
    _iter = iter(iterable)
    for i, el in enumerate(_iter, start=1):
        if i >= max_count:
            yield end
            break
        yield el


def delete_instance_request(instance):
    request = lookup().compute.instances().delete(
        project=lookup().project,
        zone=lookup().instance(instance).zone,
        instance=instance,
    )
    log_api_request(request)
    return request


def stop_tpu(data):
    tpu_nodeset = data["nodeset"]
    node = data["node"]
    tpu = data["tpu"]
    if tpu_nodeset.preserve_tpu and tpu.vmcount == 1:
        log.info(f"stopping node {node}")
        if tpu.stop_node(node):
            return
        log.error("Error stopping node {node} will delete instead")
    log.info(f"deleting node {node}")
    if not tpu.delete_node(node):
        log.error("Error deleting node {node}")


def delete_tpu_instances(instances):
    stop_data = []
    for prefix, nodes in util.groupby_unsorted(instances, lookup().node_prefix):
        log.info(f"Deleting TPU nodes from prefix {prefix}")
        lnodes = list(nodes)
        tpu_nodeset = lookup().node_nodeset(lnodes[0])
        tpu = TPU(tpu_nodeset)
        stop_data.extend(
            [{"tpu": tpu, "node": node, "nodeset": tpu_nodeset} for node in lnodes]
        )
    execute_with_futures(stop_tpu, stop_data)


def delete_instances(instances):
    """delete instances individually"""
    invalid, valid = separate(lambda inst: bool(lookup().instance(inst)), instances)
    if len(invalid) > 0:
        log.debug("instances do not exist: {}".format(",".join(invalid)))
    if len(valid) == 0:
        log.debug("No instances to delete")
        return

    requests = {inst: delete_instance_request(inst) for inst in valid}

    log.info(f"delete {len(valid)} instances ({to_hostlist_fast(valid)})")
    done, failed = batch_execute(requests)
    if failed:
        for err, nodes in groupby_unsorted(lambda n: failed[n][1], failed.keys()):
            log.error(f"instances failed to delete: {err} ({to_hostlist_fast(nodes)})")
    wait_for_operations(done.values())
    # TODO do we need to check each operation for success? That is a lot more API calls
    log.info(f"deleted {len(done)} instances {to_hostlist_fast(done.keys())}")


def suspend_nodes(nodes: List[str]) -> None:
    tpu_nodes, other_nodes = [], []
    for node in nodes[:]:
        if lookup().node_is_tpu(node):
            tpu_nodes.append(node)
        else:
            other_nodes.append(node)

    delete_instances(other_nodes)
    delete_tpu_instances(tpu_nodes)


def main(nodelist):
    """main called when run as script"""
    log.debug(f"SuspendProgram {nodelist}")

    # Filter out nodes not in config.yaml
    other_nodes, pm_nodes = separate(
        lookup().is_power_managed_node, util.to_hostnames(nodelist)
    )
    if other_nodes:
        log.debug(
            f"Ignoring non-power-managed nodes '{to_hostlist_fast(other_nodes)}' from '{nodelist}'"
        )
    if pm_nodes:
        log.debug(f"Suspending nodes '{to_hostlist_fast(pm_nodes)}' from '{nodelist}'")
    else:
        log.debug("No cloud nodes to suspend")
        return

    log.info(f"suspend {nodelist}")
    if lookup().cfg.enable_slurm_gcp_plugins:
        slurm_gcp_plugins.pre_main_suspend_nodes(lkp=lookup(), nodelist=nodelist)
    suspend_nodes(pm_nodes)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("nodelist", help="list of nodes to suspend")
    args = util.init_log_and_parse(parser)

    main(args.nodelist)
