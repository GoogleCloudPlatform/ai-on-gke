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

from fastapi import FastAPI, BackgroundTasks
import requests
import time
from google.cloud import monitoring_v3
from google.cloud import storage
from datetime import datetime
import os
import yaml
from .data_model import Metric, MetricType, LocustRun

app = FastAPI()


@app.get("/run")
async def root(background_tasks: BackgroundTasks, duration=os.environ["DURATION"], users=os.environ["USERS"], rate=os.environ["RATE"]):

    run: LocustRun = LocustRun(duration=duration,
                               users=users,
                               rate=rate)

    background_tasks.add_task(call_locust, run)

    return {"message": f"""Swarming started"""}


def call_locust(run: LocustRun):
    locust_service = "locust-master.benchmark.svc.cluster.local"

    run.start_time = time.time()

    query_response = requests.post(f"""http://{locust_service}:8089/swarm""",  {
                                   "user_count": run.users, "spawn_rate": run.rate})

    time.sleep(int(run.duration))
    get_response = requests.get(f"""http://{locust_service}:8089/stop""")
    run.end_time = time.time()
    stats = requests.get(
        f"""http://{locust_service}:8089/stats/requests/csv""")

    # read metric list
    with open('metrics.yaml', "r") as f:
        metric_map = yaml.safe_load(f)

    metric_list: [Metric] = []
    metrics_dict = metric_map['metrics']

    for metric_name in metrics_dict:
        current = metrics_dict[metric_name]

        metric_list.append(Metric(
            name=metric_name, filter=current['filter'], aggregate=current['aggregation'], type=MetricType.GAUGE))

    for metric in metric_list:  # TODO: run this in parallel in coroutine
        metric.results = grab_metrics(
            run.start_time, run.end_time, metric.filter, metric.type)

    save_to_gss(run, stats.text, metric_list)


def grab_metrics(start_time: float, end_time: float, filter: str, type: MetricType):
    nanos = int((start_time - int(start_time)) * 10**9)
    client = monitoring_v3.MetricServiceClient()
    project_id = os.environ["PROJECT_ID"]
    project_name = f"projects/{project_id}"
    interval = monitoring_v3.TimeInterval(
        {
            "end_time": {"seconds": int(end_time), "nanos": nanos},
            "start_time": {"seconds": int(start_time), "nanos": nanos},
        }
    )

    try:
        results = client.list_time_series(
            request={
                "name": project_name,
                "filter": filter,
                "interval": interval,
                "view": monitoring_v3.ListTimeSeriesRequest.TimeSeriesView.FULL,
                # TODO: add agregation as specified in yaml
            }
        )
        return results
    except:
        print("No metrics found")
        results = []

    return results


def save_to_gss(run: LocustRun, stats, metrics_list: [Metric]):
    storage_client = storage.Client()
    bucket_name = os.environ["BUCKET"]

    bucket = storage_client.bucket(bucket_name)
    now = datetime.now()
    timestamp = now.strftime('stats_and_metrics%Y-%m-%d%H:%M:%S')
    blob = bucket.blob(timestamp)

    start_time_formatted = time.strftime(
        "%Y-%m-%d %H:%M:%S", time.gmtime(run.start_time))
    end_time_formatted = time.strftime(
        "%Y-%m-%d %H:%M:%S", time.gmtime(run.end_time))

    with blob.open("w") as f:
        f.write("*********** AI on GKE Benchmarking Tool ******************\n")
        f.write("**********************************************************\n")
        f.write(f"Test duration: {run.duration} [s] \n")
        f.write(f"Test start: {start_time_formatted} \n")
        f.write(f"Test end: {end_time_formatted} \n")
        f.write(f"Users: {run.users} \n")
        f.write(f"Rate: {run.rate} \n")
        f.write("\n**********************************************************\n\n")
        f.write("Locust statistics\n")
        f.write(stats)
        f.write("\n**********************************************************\n\n")
        f.write("\n\nMetrics\n")
        for m in metrics_list:
            f.write(m.name)
            f.write("\n")
            for result in m.results:
                label = result.resource.labels
                # metadata = result.metadata.system_labels.fields
                metricdata = result.metric.labels
                for l in label:
                    f.write(f"""{l}: {label[l]}\n""")
                for l in metricdata:
                    f.write(f"""{l}: {metricdata[l]}\n""")
                points = result.points
                f.write(f"""Number of points: {len(points)}\n""")
                for point in points:
                    p_point = (
                        point.value.double_value) if point.value.double_value is not None else 0
                    f.write(f""" {p_point},""")
                f.write("\n ")


# if __name__ == "__main__":
#    app.run(main)
