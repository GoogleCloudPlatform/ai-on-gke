# Copyright 2024 Google LLC
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

import time
from enum import Enum


class LocustRun:
    """Represents single run of Locust load tests."""

    def __init__(self, duration, users, rate):
        self.duration = duration
        self.users = users
        self.rate = rate

    duration: int = 120
    users: int = 10
    rate: int = 5

    start_time: time.time
    end_time: time.time


class MetricType(Enum):
    TIMESERIES = 1
    GAUGE = 2


class Metric:
    """Represents metric to be gathered from Cloud Monitoring"""

    def __init__(self, name, filter, aggregate, type):
        self.name = name
        self.filter = filter
        self.aggregate = aggregate
        self.type = type

    name: str
    filter: str
    aggregate: str = ""
    type: MetricType = MetricType.GAUGE

    results: any
