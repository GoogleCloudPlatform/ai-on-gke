import datetime
import logging
import json
import csv
import os
from datetime import datetime
from google.cloud import storage

class MetricCollector:
    def __init__(self):
        self.request_metrics = []
        self.tokens_sent = []
        self.tokens_received = []
        self.test_time = []
        self.success_count = 0
        self.failure_count = 0
        self.time_to_first_token_list = []

    def add_metric(self, sent, received, test_time, request_succesful_bool, ttft):
        self.request_metrics.append({"success": request_succesful_bool, "input_tokens": sent, "output_tokens": received, "total_request_time": test_time, "time_to_first_token": ttft})
        if request_succesful_bool == 1:
            self.tokens_sent.append(sent)
            self.tokens_received.append(received)
            self.test_time.append(test_time)
            self.success_count += 1
            if ttft != 0:
                self.time_to_first_token_list.append(ttft)
        else:
            self.failure_count += 1

    def add_metrics(self, tokens_sent, tokens_received, test_time, success_count, failure_count, ttfts, request_metrics):
        self.tokens_sent = self.tokens_sent + tokens_sent
        self.tokens_received = self.tokens_received + tokens_received
        self.test_time = self.test_time + test_time
        self.success_count += success_count
        self.failure_count += failure_count
        self.time_to_first_token_list = self.time_to_first_token_list + ttfts
        self.request_metrics = self.request_metrics + request_metrics

    def share_stats(self):
        return self.tokens_sent, self.tokens_received, self.test_time, self.success_count, self.failure_count, self.time_to_first_token_list, self.request_metrics

    def calculate_average_tokens(self):
        if self.tokens_sent and len(self.tokens_sent) > 0:
            avg_sent = sum(self.tokens_sent) / \
                len(self.tokens_sent) if self.tokens_sent else 0
            avg_received = sum(self.tokens_received) / \
                len(self.tokens_received) if self.tokens_received else 0
            avg_test_time = sum(self.test_time) / \
                len(self.test_time) if self.tokens_sent else 0
            avg_output_token_latency = 0
            for i in range(0, self.success_count):
                avg_output_token_latency += (
                    self.tokens_received[i] / self.test_time[i])
            avg_output_token_latency = avg_output_token_latency / \
                self.success_count
            return avg_sent, avg_received, avg_test_time, avg_output_token_latency
        return 0, 0, 0, 0

    def json_dump_report(self):
        avg_sent, avg_received, avg_test_time, avg_output_token_latency = self.calculate_average_tokens()
        stats = {
            "average-tokens-sent": avg_sent,
            "average-tokens-received": avg_received,
            "average-output-token-latency": avg_output_token_latency,
            "average-test-time": avg_test_time,
            "average-time-to-first-token": sum(self.time_to_first_token_list)/max(len(self.time_to_first_token_list),1)
        }
        return json.dumps(stats)
    
    def dump_to_csv(self):
        fields = ['success', 'total_request_time', 'time_to_first_token', 'input_tokens', 'output_tokens']
        now = datetime.now()
        storage_client = storage.Client()
        bucket = storage_client.bucket(os.environ['BUCKET'])
        timestamp = now.strftime('metrics%Y-%m-%d%H:%M:%S.csv')
        blob = bucket.blob(timestamp)
        with blob.open('w') as metricsfile:
            writer = csv.DictWriter(metricsfile, fieldnames=fields)
            writer.writeheader()
            writer.writerows(self.request_metrics)

