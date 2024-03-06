import os
import json
import datetime

RESULT_FOLDER = './tmp'

START_TIME = 'start'
END_TIME = 'end'
GPU = 'train_au_percentage'
M_GPU = 'train_au_mean_percentage'
SAMPLE_THROUGHPUT = 'train_throughput_samples_per_second'
M_SAMPLE_THROUGHPUT = 'train_throughput_mean_samples_per_second'
M_MB = "train_io_mean_MB_per_second"
DURATION = 'duration'


def average(numbers):
  return sum(numbers) / len(numbers)

def process_summary(summary):
  metric = summary['metric']
  gpu = metric[M_GPU]
  spp = metric[M_SAMPLE_THROUGHPUT]
  mmb = metric[M_MB]
  fe_gpu_percentage = metric[GPU][0]
  fe_samples_per_second = metric[SAMPLE_THROUGHPUT][0]
  sub_gpu_percentage = average(metric[GPU][1:]) if len(metric[GPU]) > 1 else -1
  sub_spp = average(metric[SAMPLE_THROUGHPUT][1:])  if len(metric[SAMPLE_THROUGHPUT]) > 1 else -1
  start_time = summary[START_TIME]
  end_time = summary[END_TIME]
  total_time = datetime.datetime.strptime(end_time, "%Y-%m-%dT%H:%M:%S.%f") - datetime.datetime.strptime(start_time, "%Y-%m-%dT%H:%M:%S.%f")
  return total_time.total_seconds(), fe_gpu_percentage, fe_samples_per_second, sub_gpu_percentage, sub_spp, gpu, spp, mmb

headers = ['e2e training seconds', 'first epoch au percentage', 'first epoch throughput samples per second', 'subsequent epochs average au percentage', 'subsequent epochs throughput samples per second',
           'mean au percentage', 'mean throughput samples per second', 'mean MB per second']

def process_per_epoch_stats(epochs):
  fe_duration = float(epochs['1'][DURATION])
  sq_durations = []
  for i in range(2, len(epochs)):
    sq_durations.append(float(epochs[str(i)][DURATION]))
  sq_avg_duration = average(sq_durations) if len(sq_durations) > 0 else -1
  return fe_duration, sq_avg_duration

per_epoch_headers = ['first epoch duration seconds', "subsequent epochs average duration seconds"]

summary_results = []
per_epoch_results = []
for root, dirs, files in os.walk(RESULT_FOLDER):
  for file in files:
    if file == 'summary.json':
      with open(root +'/'+ file) as f:
        d = json.load(f)
        summary_results.append(process_summary(d))
    if file == 'per_epoch_stats.json':
      with open(root +'/'+ file) as f:
        d = json.load(f)
        per_epoch_results.append(process_per_epoch_stats(d))


print(list(zip(headers, list(map(average, zip(*summary_results))))))
print(list(zip(per_epoch_headers, list(map(average, zip(*per_epoch_results))))))
