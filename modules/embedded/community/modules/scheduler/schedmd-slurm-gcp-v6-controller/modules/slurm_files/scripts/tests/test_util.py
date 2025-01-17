# Copyright 2024 "Google LLC"
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

import pytest
from mock import Mock
from common import TstNodeset, TstCfg # needed to import util
import util
from google.api_core.client_options import ClientOptions  # noqa: E402

# Note: need to install pytest-mock

@pytest.mark.parametrize(
    "name,expected",
    [
        (
            "az-buka-23",
            {
                "cluster": "az",
                "nodeset": "buka",
                "node": "23",
                "prefix": "az-buka",
                "range": None,
                "suffix": "23",
            },
        ),
        (
            "az-buka-xyzf",
            {
                "cluster": "az",
                "nodeset": "buka",
                "node": "xyzf",
                "prefix": "az-buka",
                "range": None,
                "suffix": "xyzf",
            },
        ),
        (
            "az-buka-[2-3]",
            {
                "cluster": "az",
                "nodeset": "buka",
                "node": "[2-3]",
                "prefix": "az-buka",
                "range": "[2-3]",
                "suffix": None,
            },
        ),
    ],
)
def test_node_desc(name, expected):
    assert util.lookup()._node_desc(name) == expected


@pytest.mark.parametrize(
    "name",
    [
        "az-buka",
    ],
)
def test_node_desc_fail(name):
    with pytest.raises(Exception):
        util.lookup()._node_desc(name)


@pytest.mark.parametrize(
    "names,expected",
    [
        ("pedro,pedro-1,pedro-2,pedro-01,pedro-02", "pedro,pedro-[1-2,01-02]"),
        ("pedro,,pedro-1,,pedro-2", "pedro,pedro-[1-2]"),
        ("pedro-8,pedro-9,pedro-10,pedro-11", "pedro-[8-9,10-11]"),
        ("pedro-08,pedro-09,pedro-10,pedro-11", "pedro-[08-11]"),
        ("pedro-08,pedro-09,pedro-8,pedro-9", "pedro-[8-9,08-09]"),
        ("pedro-10,pedro-08,pedro-09,pedro-8,pedro-9", "pedro-[8-9,08-10]"),
        ("pedro-8,pedro-9,juan-10,juan-11", "juan-[10-11],pedro-[8-9]"),
        ("az,buki,vedi", "az,buki,vedi"),
        ("a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12", "a[0-9,10-12]"),
        ("a0,a2,a4,a6,a7,a8,a11,a12", "a[0,2,4,6-8,11-12]"),
        ("seas7-0,seas7-1", "seas7-[0-1]"),
    ],
)
def test_to_hostlist_fast(names, expected):
    assert util.to_hostlist_fast(names.split(",")) == expected


@pytest.mark.parametrize(
    "api,ep_ver,expected",
    [
        (
            util.ApiEndpoint.BQ,
            "v1",
            ClientOptions(api_endpoint="https://bq.googleapis.com/v1/"),
        ),
        (
            util.ApiEndpoint.COMPUTE,
            "staging_v1",
            ClientOptions(api_endpoint="https://compute.googleapis.com/staging_v1/"),
        ),
        (
            util.ApiEndpoint.SECRET,
            "v1",
            ClientOptions(api_endpoint="https://secret_manager.googleapis.com/v1/"),
        ),
        (
            util.ApiEndpoint.STORAGE,
            "beta",
            ClientOptions(api_endpoint="https://storage.googleapis.com/beta/"),
        ),
        (
            util.ApiEndpoint.TPU,
            "alpha",
            ClientOptions(api_endpoint="https://tpu.googleapis.com/alpha/"),
        ),
    ],
)
def test_create_client_options(
    api: util.ApiEndpoint, ep_ver: str, expected: ClientOptions, mocker
):
    ud_mock = mocker.patch("util.universe_domain")
    ep_mock = mocker.patch("util.endpoint_version")
    ud_mock.return_value = "googleapis.com"
    ep_mock.return_value = ep_ver
    assert util.create_client_options(api).__repr__() == expected.__repr__()



@pytest.mark.parametrize(
        "nodeset,err",
        [
            (TstNodeset(reservation_name="projects/x/reservations/y"), AssertionError), # no zones
            (TstNodeset(
                reservation_name="projects/x/reservations/y",
                zone_policy_allow=["eine", "zwei"]), AssertionError), # multiples zones
            (TstNodeset(
                reservation_name="robin",
                zone_policy_allow=["eine"]), ValueError), # invalid name
            (TstNodeset(
                reservation_name="projects/reservations/y",
                zone_policy_allow=["eine"]), ValueError), # invalid name
            (TstNodeset(
                reservation_name="projects/x/zones/z/reservations/y",
                zone_policy_allow=["eine"]), ValueError), # invalid name
        ]
)
def test_nodeset_reservation_err(nodeset, err):
    lkp = util.Lookup(TstCfg())
    lkp._get_reservation = Mock()
    with pytest.raises(err):
        lkp.nodeset_reservation(nodeset)
    lkp._get_reservation.assert_not_called()
    
@pytest.mark.parametrize(
        "nodeset,policies,expected",
        [
            (TstNodeset(), [], None), # no reservation
            (TstNodeset(
                reservation_name="projects/bobin/reservations/robin",
                zone_policy_allow=["eine"]), 
                [],
                util.ReservationDetails(
                    project="bobin",
                    zone="eine",
                    name="robin",
                    policies=[],
                    bulk_insert_name="projects/bobin/reservations/robin")),
            (TstNodeset(
                reservation_name="projects/bobin/reservations/robin",
                zone_policy_allow=["eine"]), 
                ["seven/wanders", "five/red/apples", "yum"],
                util.ReservationDetails(
                    project="bobin",
                    zone="eine",
                    name="robin",
                    policies=["wanders", "apples", "yum"],
                    bulk_insert_name="projects/bobin/reservations/robin")),
            (TstNodeset(
                reservation_name="projects/bobin/reservations/robin/snek/cheese-brie-6",
                zone_policy_allow=["eine"]), 
                [],
                util.ReservationDetails(
                    project="bobin",
                    zone="eine",
                    name="robin",
                    policies=[],
                    bulk_insert_name="projects/bobin/reservations/robin/snek/cheese-brie-6")),

        ])

def test_nodeset_reservation_ok(nodeset, policies, expected):
    lkp = util.Lookup(TstCfg())
    lkp._get_reservation = Mock()
    
    if not expected:
        assert lkp.nodeset_reservation(nodeset) is None
        lkp._get_reservation.assert_not_called()
        return
    
    lkp._get_reservation.return_value = {
        "resourcePolicies": {i: p for i, p in enumerate(policies)},
    }
    assert lkp.nodeset_reservation(nodeset) == expected
    lkp._get_reservation.assert_called_once_with(expected.project, expected.zone, expected.name)
    
    
