## Ray Observability

This README covers logging and monitoring integrations with Google Cloud for Ray clusters on Google Kubernetes Engine.

First install a Ray cluster using the Ray terraform templates in this repo. The terraform templates
enable logging and monitoring capabilities by default. See [Getting Started](../../README.md#getting-started) for
more details.

### Logging

To illustrate log collection, first submit a job and record the Job Submission ID:

```
$ ray job submit --address http://localhost:8265 -- python -c "import ray; ray.init(); print(ray.cluster_resources())"
Job submission server address: http://localhost:8265

-------------------------------------------------------
Job 'raysubmit_4KuDfyqXaYyzvpQd' submitted successfully
-------------------------------------------------------

Next steps
  Query the logs of the job:
    ray job logs raysubmit_4KuDfyqXaYyzvpQd
  Query the status of the job:
    ray job status raysubmit_4KuDfyqXaYyzvpQd
  Request the job to be stopped:
    ray job stop raysubmit_4KuDfyqXaYyzvpQd

Tailing logs until the job exits (disable with --no-wait):
2024-03-19 21:01:58,316 INFO worker.py:1405 -- Using address 10.80.0.22:6379 set in the environment variable RAY_ADDRESS
2024-03-19 21:01:58,317 INFO worker.py:1540 -- Connecting to existing Ray cluster at address: 10.80.0.22:6379...
2024-03-19 21:01:58,326 INFO worker.py:1715 -- Connected to Ray cluster. View the dashboard at http://10.80.0.22:8265 
{'CPU': 4.0, 'node:10.80.0.22': 1.0, 'memory': 8000000000.0, 'object_store_memory': 2280821145.0, 'node:__internal_head__': 1.0}

------------------------------------------
Job 'raysubmit_4KuDfyqXaYyzvpQd' succeeded
------------------------------------------
```

Follow these steps to view the persisted logs from the Ray job:

1. Open https://console.cloud.google.com/ 
2. Go to Logs Explorer in Cloud Logging
3. Use the following query to search for logs from your Ray job.

```
jsonpayload.ray_submission_id=%RAY_JOB_ID%
```

### Monitoring

To see monitoring metrics:
1. Open Cloud Console and open Metrics Explorer
2. In "Target", select "Prometheus Target" and then "Ray".
3. Select the metric you want to view, and then click "Apply".