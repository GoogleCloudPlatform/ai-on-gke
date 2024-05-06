import datetime
import logging
import json

class TokenMetricCollector:
    def __init__(self):
        self.tokens_sent = []
        self.tokens_received = []
        self.test_time = []
        self.success_count = 0
        self.failure_count = 0
        self.time_to_first_token_list = []

    def add_metric(self, sent, received, test_time, request_succesful_bool, ttft):
        if request_succesful_bool == 1:
            self.tokens_sent.append(sent)
            self.tokens_received.append(received)
            self.test_time.append(test_time)
            self.success_count += 1
            if ttft != 0:
                self.time_to_first_token_list.append(ttft)
        else:
            self.failure_count += 1

    def add_metrics(self, tokens_sent, tokens_received, test_time, success_count, failure_count, ttfts):
        self.tokens_sent = self.tokens_sent + tokens_sent
        self.tokens_received = self.tokens_received + tokens_received
        self.test_time = self.test_time + test_time
        self.success_count += success_count
        self.failure_count += failure_count
        self.time_to_first_token_list = self.time_to_first_token_list + ttfts

    def share_stats(self):
        return self.tokens_sent, self.tokens_received, self.test_time, self.success_count, self.failure_count, self.time_to_first_token_list

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

