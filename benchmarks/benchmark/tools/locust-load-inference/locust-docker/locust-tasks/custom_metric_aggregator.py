import logging

class TokenMetricCollector:
    def __init__(self):
        self.tokens_sent = []
        self.tokens_received = []
        self.test_time = []
        self.success_count = 0
        self.failure_count = 0
        

    def add_metric(self, sent, received, test_time, request_successful_bool):
        if request_successful_bool==1:
            self.tokens_sent.append(sent)
            self.tokens_received.append(received)
            self.test_time.append(test_time)
            self.success_count += 1
        else:
            self.failure_count += 1
            

    def calculate_average_tokens(self):
        avg_sent = sum(self.tokens_sent) / len(self.tokens_sent) if self.tokens_sent else 0
        avg_received = sum(self.tokens_received) / len(self.tokens_received) if self.tokens_received else 0
        avg_test_time = sum(self.test_time) / len(self.test_time) if self.tokens_sent else 0
        
        return avg_sent, avg_received, avg_test_time

    def write_to_csv(self, file_path='custom_metrics.csv'):
        import csv
        avg_sent, avg_received, avg_test_time = self.calculate_average_tokens()
        with open(file_path, mode='w', newline='') as file:
            writer = csv.writer(file)
            writer.writerow(['Metric', 'Average Value'])
            writer.writerow(['# of Successful Req', self.success_count])
            writer.writerow(['# of Failed Req', self.failure_count])
            writer.writerow(['Avg Tokens Sent Per Req', avg_sent])
            writer.writerow(['Avg Tokens Received Per Req', avg_received])
            writer.writerow(['Avg Test Time', avg_test_time])
            
