r"""Benchmark LLM serving throughput and latency.
This script is for sending requests with prompts to LLM server and benchmark
the latency and throughput at various request rates. It is a modified version of
https://github.com/vllm-project/vllm/blob/main/benchmarks/benchmark_serving.py.
It currently supports TGI, vLLM, Triton TensorRT-LLM and Saxml.
"""

import argparse
import asyncio
from datetime import datetime
import json
import random
import requests
import time
from typing import AsyncGenerator, List, Optional, Tuple, Dict

import google.auth
import google.auth.transport.requests

import aiohttp
import numpy as np
from transformers import AutoTokenizer
from transformers import PreTrainedTokenizerBase

from google.protobuf.timestamp_pb2 import Timestamp


# (prompt len, output len, latency)
REQUEST_LATENCY: List[Tuple[int, int, float]] = []

MIN_SEQ_LEN = 4
CLIENT_TIMEOUT_SEC = 3 * 60 * 60
NEW_TEXT_KEY = "\nOutput:\n"


def sample_requests(
    dataset_path: str,
    num_requests: int,
    max_input_len: int,
    max_output_len: int,
    tokenizer: PreTrainedTokenizerBase,
    use_dummy_text: bool,
) -> List[Tuple[str, int, int]]:
  """Samples requests from the dataset or creates dummy requests."""
  if use_dummy_text:
    dummy_prompt_token_ids = [0] * max_input_len
    dummy_prompt = tokenizer.decode(dummy_prompt_token_ids)
    dummy_requests = [(
        dummy_prompt,
        max_input_len,
        max_output_len,
    )] * num_requests
    return dummy_requests

  # Load the dataset.
  with open(dataset_path) as f:
    dataset = json.load(f)
  # Filter out the conversations with less than 2 turns.
  dataset = [data for data in dataset if len(data["conversations"]) >= 2]
  # Only keep the first two turns of each conversation.
  dataset = [
      (data["conversations"][0]["value"], data["conversations"][1]["value"])
      for data in dataset
  ]

  # Tokenize the prompts and completions.
  prompts = [prompt for prompt, _ in dataset]
  prompt_token_ids = tokenizer(prompts).input_ids
  completions = [completion for _, completion in dataset]
  completion_token_ids = tokenizer(completions).input_ids
  tokenized_dataset = []
  for i in range(len(dataset)):
    output_len = len(completion_token_ids[i])
    tokenized_dataset.append((prompts[i], prompt_token_ids[i], output_len))

  # Filter out too long sequences.
  filtered_dataset: List[Tuple[str, int, int]] = []
  for prompt, prompt_token_ids, output_len in tokenized_dataset:
    prompt_len = len(prompt_token_ids)
    if prompt_len < MIN_SEQ_LEN or output_len < MIN_SEQ_LEN:
      # Prune too short sequences.
      # This is because TGI causes errors when the input or output length
      # is too short.
      continue
    if prompt_len > max_input_len or output_len > max_output_len:
      # Prune too long sequences.
      continue
    filtered_dataset.append((prompt, prompt_len, output_len))

  # Sample the requests.
  sampled_requests = random.sample(filtered_dataset, num_requests)
  return sampled_requests


async def get_request(
    input_requests: List[Tuple[str, int, int]],
    request_rate: float,
) -> AsyncGenerator[Tuple[str, int, int], None]:
  """Gets request async."""
  input_requests = iter(input_requests)
  for request in input_requests:
    yield request

    if request_rate == float("inf"):
      # If the request rate is infinity, then we don't need to wait.
      continue
    # Sample the request interval from the exponential distribution.
    interval = np.random.exponential(1.0 / request_rate)
    # The next request will be sent after the interval.
    await asyncio.sleep(interval)


async def send_request(
    backend: str,
    api_url: str,
    prompt: str,
    prompt_len: int,
    output_len: int,
    best_of: int,
    use_beam_search: bool,
    top_k: int,
    tokenizer: PreTrainedTokenizerBase,
    sax_model: str,
    model: str,
) -> None:
  """Sends request to server."""
  request_start_time = time.time()

  headers = {"User-Agent": "Benchmark Client"}
  if backend == "vllm":
    pload = {
        "model": model,
        "prompt": prompt,
        "n": 1,
        "best_of": best_of,
        "use_beam_search": use_beam_search,
        "temperature": 0.0 if use_beam_search else 1.0,
        "top_p": 1.0,
        "max_tokens": output_len,
        "ignore_eos": False,
        "stream": False,
    }
  elif backend == "tgi":
    assert not use_beam_search
    params = {
        "best_of": best_of,
        "max_new_tokens": output_len,
        "do_sample": True,
    }
    pload = {
        "inputs": prompt,
        "parameters": params,
    }
  elif backend == "naive_transformers":
    # If max_length or top_k is not specified _MAX_LENGTH_DEFAULT = 200 and
    # _TOP_K_DEFAULT = 10 in peft/handler.py will be used.
    pload = {
        "instances": [{
            "prompt": prompt,
            "max_length": output_len,
            "top_k": top_k,
        }]
    }
  elif backend == "tensorrt_llm_triton":
    pload = {
        "text_input": prompt,
        "max_tokens": output_len,
        "beam_width": 1 if not use_beam_search else best_of,
        "temperature": 0.0 if use_beam_search else 1.0,
        "top_p": 1.0,
        "bad_words": "",
        "stop_words": "",
        "stream": False,
    }
  elif backend == "sax":
    pload = {
        "model": sax_model,
        "prompt": prompt,
        "n": 1,
        "best_of": best_of,
        "use_beam_search": use_beam_search,
        "temperature": 0.0 if use_beam_search else 1.0,
        "top_p": 1.0,
        "top_k": 50,
        "max_tokens": output_len,
        "stream": False,
    }
  elif backend == "jetstream":
    pload = {
        "prompt": prompt,
        "max_tokens": output_len,
    }
  else:
    raise ValueError(f"Unknown backend: {backend}")

  # Set client timeout to be 3 hrs.
  timeout = aiohttp.ClientTimeout(total=CLIENT_TIMEOUT_SEC)
  async with aiohttp.ClientSession(timeout=timeout) as session:
    while True:
      async with session.post(api_url, headers=headers, json=pload) as response:
        chunks = []
        async for chunk, _ in response.content.iter_chunks():
          chunks.append(chunk)
      output = b"".join(chunks).decode("utf-8")
      output = json.loads(output)

      # Re-send the request if it failed.
      if "error" not in output:
        break

  request_end_time = time.time()
  # Naive HF transformers generation and TensorRT-LLM generation stops at EOS
  # tokens and the generation may be shorter than the ground-truth output
  # sequence length.
  if backend == "naive_transformers":
    complete_pred = output["predictions"][0][0]["generated_text"]
    new_text_start_index = complete_pred.find(NEW_TEXT_KEY) + len(NEW_TEXT_KEY)
    pred = complete_pred[new_text_start_index:]
    output_token_ids = tokenizer(pred).input_ids
    output_len = len(output_token_ids) - prompt_len
  elif backend == "tensorrt_llm_triton":
    output_token_ids = tokenizer(output["text_output"]).input_ids
    output_len = len(output_token_ids)
  elif backend == "sax":
    output_token_ids = tokenizer(output["choices"][0]["text"]).input_ids
    output_len = len(output_token_ids)
  elif backend == "tgi":
    output_token_ids = tokenizer(output["generated_text"]).input_ids
    output_len = len(output_token_ids)
  elif backend == "vllm":
    output_token_ids = tokenizer(output["choices"][0]["text"]).input_ids
    output_len = len(output_token_ids)
  elif backend == "jetstream":
    output_token_ids = tokenizer(output["response"]).input_ids
    output_len = len(output_token_ids)

  request_latency = request_end_time - request_start_time
  REQUEST_LATENCY.append((prompt_len, output_len, request_latency))


async def benchmark(
    backend: str,
    api_url: str,
    input_requests: List[Tuple[str, int, int]],
    best_of: int,
    use_beam_search: bool,
    request_rate: float,
    top_k: int,
    tokenizer: PreTrainedTokenizerBase,
    sax_model: str,
    model: str,
) -> None:
  """Runs benchmark with asynchronous requests."""
  tasks: List[asyncio.Task] = []
  async for request in get_request(input_requests, request_rate):
    prompt, prompt_len, output_len = request
    task = asyncio.create_task(
        send_request(
            backend,
            api_url,
            prompt,
            prompt_len,
            output_len,
            best_of,
            use_beam_search,
            top_k,
            tokenizer,
            sax_model,
            model,
        )
    )
    tasks.append(task)
  await asyncio.gather(*tasks)


def save_json_results(args: argparse.Namespace, benchmark_result, server_metrics):
  # Setup
  start_dt_proto = Timestamp()
  start_dt_proto.FromDatetime(args.start_datetime)

  final_json = {
    # metrics values are numerical
    "metrics" : {
      # Traffic
      "num_prompts": args.num_prompts,
      "request_rate": args.request_rate,
      'server_metrics': {
        **server_metrics
      },
      **benchmark_result
    },
    # dimensions values are strings
    "dimensions": {
      "date": args.start_datetime.strftime('%Y%m%d-%H%M%S'),
      "backend": args.backend,
      "model_id": args.model,
      "tokenizer_id": args.tokenizer,
      **(json.loads(args.additional_metadata_metrics_to_save) if args.additional_metadata_metrics_to_save else {})
    },
    "config": {
      "model": args.model,
      "model_server": args.backend,
      "start_time": {
        "seconds" : start_dt_proto.seconds,
        "nanos" : start_dt_proto.nanos
      }
    },
    "summary_stats": {
      "stats": [{
        "request_rate": args.request_rate,
        "request_latency": {
          "mean": benchmark_result["avg_latency"],
          "median": benchmark_result["median_latency"],
          "sd": benchmark_result["sd_latency"],
          "min": benchmark_result["min_latency"],
          "max": benchmark_result["max_latency"],
          "p90": benchmark_result["p90_latency"],
          "p99": benchmark_result["p99_latency"],
        },
        "throughput": {
          "mean": benchmark_result['throughput']
        },
        "input_length": {
          "mean": benchmark_result["avg_input_len"],
          "median": benchmark_result["median_input_len"],
          "sd": benchmark_result["sd_input_len"],
          "min": benchmark_result["min_input_len"],
          "max": benchmark_result["max_input_len"],
          "p90": benchmark_result["p90_input_len"],
          "p99": benchmark_result["p99_input_len"],
        },
        "output_length": {
          "mean": benchmark_result["avg_output_len"],
          "median": benchmark_result["median_output_len"],
          "sd": benchmark_result["sd_output_len"],
          "min": benchmark_result["min_output_len"],
          "max": benchmark_result["max_output_len"],
          "p90": benchmark_result["p90_output_len"],
          "p99": benchmark_result["p99_output_len"],
        },
        "tpot": {
          "mean": benchmark_result["avg_per_output_token_latency"],
          "median": benchmark_result["median_per_output_token_latency"],
          "sd": benchmark_result["sd_per_output_token_latency"],
          "min": benchmark_result["min_per_output_token_latency"],
          "max": benchmark_result["max_per_output_token_latency"],
          "p90": benchmark_result["p90_per_output_token_latency"],
          "p99": benchmark_result["p99_per_output_token_latency"],
        },
        "model_server_metrics" : [{"Name": name, **metrics} for name, metrics in server_metrics.items()]
      }]
    }
  }
  
  # Save to file
  base_model_id = args.model.split("/")[-1]
  file_name = (
      f"{args.backend}-{args.request_rate}qps-{base_model_id}-{args.start_datetime.strftime('%Y%m%d-%H%M%S')}.json"
  )
  with open(file_name, "w", encoding="utf-8") as outfile:
    json.dump(final_json, outfile)

def metrics_to_scrape(backend: str) -> List[str]:
  # Each key in the map is a metric, it has a corresponding 'stats' object
  # It must be populated on the outputs 'metrics' field as 'key':'stats'
  # If a value is specified for a given key, it will be populated on the outputs `summary_stats.stats` field as 'value':'stats' as well.
  if backend == "vllm":
    return ["vllm:gpu_cache_usage_perc", "vllm:num_requests_waiting"]
  elif backend == "jetstream":
    return [
      "jetstream_slots_used_percentage",
      "jetstream_prefill_backlog_size",
      "jetstream_time_to_first_token",
      "jetstream_time_per_output_token",
      "jetstream_time_per_request",
    ]
  else:
    return []

def print_metrics(metrics: List[str], duration: float, backend: str):
  # Creates a credentials object from the default service account file
  # Assumes that script has appropriate default credentials set up, ref:
  # https://googleapis.dev/python/google-auth/latest/user-guide.html#application-default-credentials
  credentials, project_id = google.auth.default()
  # Prepare an authentication request - helps format the request auth token
  auth_req = google.auth.transport.requests.Request()

  server_metrics = {}

  # Request refresh tokens
  credentials.refresh(auth_req)
  url='https://monitoring.googleapis.com/v1/projects/%s/location/global/prometheus/api/v1/metadata' % (project_id)
  headers_api = {'Authorization': 'Bearer ' + credentials.token}
  request_post = requests.get(url=url, headers=headers_api)
  all_metrics_metadata = request_post.json()
  if request_post.ok is not True:
    print("HTTP Error: %s" % (all_metrics_metadata))
  if all_metrics_metadata["status"] != "success":
    print("Metadata error response: %s" % all_metrics_metadata["error"])

  for metric in metrics:
    print("Metric Name: %s" % (metric))

    # Find metric type
    metric_type = all_metrics_metadata['data'][metric]
    if all_metrics_metadata['data'][metric] is None:
      print("No metric found for: %s" % metric)
      return
    metric_type = metric_type[0]['type']

    metric_results = {}
    # Queries scrape all metrics collected from the last $DURATION seconds from the backend's related
    # podmonitoring spec assumed to be named "$BACKEND-podmonitoring"
    queries = {
      "gauge": {
        "Mean": "avg_over_time(%s{job='%s-podmonitoring'}[%.0fs])" % (metric, backend, duration),
        "Median": "quantile_over_time(0.5, %s{job='%s-podmonitoring'}[%.0fs])" % (metric, backend, duration),
        "Sd": "stddev_over_time(%s{job='%s-podmonitoring'}[%.0fs])" % (metric, backend, duration),
        "Min": "min_over_time(%s{job='%s-podmonitoring'}[%.0fs])" % (metric, backend, duration),
        "Max": "max_over_time(%s{job='%s-podmonitoring'}[%.0fs])" % (metric, backend, duration),
        "P90": "quantile_over_time(0.9, %s{job='%s-podmonitoring'}[%.0fs])" % (metric, backend, duration),
        "P99": "quantile_over_time(0.99, %s{job='%s-podmonitoring'}[%.0fs])" % (metric, backend, duration),
    },
      "histogram": {
        "Mean": "sum(rate(%s_sum{job='%s-podmonitoring'}[%.0fs])) / sum(rate(%s_count{job='%s-podmonitoring'}[%.0fs]))" % (metric, backend, duration, metric, backend, duration),
        "Median": "histogram_quantile(0.5, sum(rate(%s_bucket{job='%s-podmonitoring'}[%.0fs])) by (le))" % (metric, backend, duration),
        "Min": "histogram_quantile(0, sum(rate(%s_bucket{job='%s-podmonitoring'}[%.0fs])) by (le))" % (metric, backend, duration),
        "Max": "histogram_quantile(1, sum(rate(%s_bucket{job='%s-podmonitoring'}[%.0fs])) by (le))" % (metric, backend, duration),
        "P90": "histogram_quantile(0.9, sum(rate(%s_bucket{job='%s-podmonitoring'}[%.0fs])) by (le))" % (metric, backend, duration),
        "P99": "histogram_quantile(0.99, sum(rate(%s_bucket{job='%s-podmonitoring'}[%.0fs])) by (le))" % (metric, backend, duration),
    }
  }
    for query_name, query in queries[metric_type].items():
      # Configure respective query
      url='https://monitoring.googleapis.com/v1/projects/%s/location/global/prometheus/api/v1/query' % (project_id)
      headers_api = {'Authorization': 'Bearer ' + credentials.token}
      params = {'query': query}
      request_post = requests.get(url=url, headers=headers_api, params=params)
      response = request_post.json()

      # handle response
      if request_post.ok:
        if response["status"] == "success":
          metric_results[query_name] = float(response["data"]["result"][0]["value"][1])
          print("%s: %s" % (query_name, response["data"]["result"][0]["value"][1]))
        else:
          print("Cloud Monitoring PromQL Error: %s" % (response["error"]))
      else:
        print("HTTP Error: %s" % (response))
    server_metrics[metric] = metric_results
  return server_metrics

def get_stats_for_set(name, description, points):
  avg = np.mean(points)
  median = np.median(points)
  sd = np.std(points)
  min = np.min(points)
  max = np.max(points)
  p90 = np.percentile(points, 90)
  p99 = np.percentile(points, 99)

  print(f"Average {description}:" f" {avg:.2f}")

  return {
    f'avg_{name}':  avg,
    f'median_{name}': median,
    f'sd_{name}': sd,
    f'min_{name}': min,
    f'max_{name}': max,
    f'p90_{name}': p90,
    f'p99_{name}': p99,
  }

def main(args: argparse.Namespace):
  print(args)
  random.seed(args.seed)
  np.random.seed(args.seed)

  endpoint = (
    "v1/completions"
    if args.backend == "vllm"
    else args.endpoint
)

  api_url = f"http://{args.host}:{args.port}/{endpoint}"
  tokenizer = AutoTokenizer.from_pretrained(
      args.tokenizer, trust_remote_code=args.trust_remote_code
  )
  input_requests = sample_requests(
      args.dataset,
      args.num_prompts,
      args.max_input_length,
      args.max_output_length,
      tokenizer,
      args.use_dummy_text,
  )

  benchmark_start_time = time.time()
  args.start_datetime = datetime.fromtimestamp(benchmark_start_time)

  asyncio.run(
      benchmark(
          args.backend,
          api_url,
          input_requests,
          args.best_of,
          args.use_beam_search,
          args.request_rate,
          args.top_k,
          tokenizer,
          args.sax_model,
          args.model,
      )
  )
  benchmark_result = {}
  benchmark_end_time = time.time()
  benchmark_time = benchmark_end_time - benchmark_start_time
  print(f"Total time: {benchmark_time:.2f} s")
  print(f"Requests/min: {60 * args.num_prompts / benchmark_time:.2f}")
  benchmark_result['benchmark_time'] = benchmark_time
  benchmark_result['throughput_rps'] = (args.num_prompts / benchmark_time)

  total_output_tokens = np.sum([output_len for _, output_len, _ in
                                REQUEST_LATENCY])
  output_tokens_per_second = total_output_tokens / benchmark_time
  benchmark_result['throughput'] = output_tokens_per_second

  output_tokens_per_min = 60 * output_tokens_per_second
  print(f"Output_tokens/min: {output_tokens_per_min:.2f}")
  benchmark_result['total_output_token'] = int(total_output_tokens)
  benchmark_result['output_tokens_per_min'] = output_tokens_per_min

  total_input_tokens = np.sum([prompt_len for prompt_len, _, _ in
                               REQUEST_LATENCY])
  input_tokens_per_min = 60 * total_input_tokens / benchmark_time
  print(f"Input_tokens/min: {input_tokens_per_min:.2f}")
  benchmark_result['total_input_tokens'] = int(total_input_tokens)
  benchmark_result['input_tokens_per_min'] = input_tokens_per_min

  total_tokens = total_input_tokens + total_output_tokens
  tokens_per_min = 60 * total_tokens / benchmark_time
  print(f"Tokens/min: {tokens_per_min:.2f}")
  benchmark_result['total_tokens'] = int(total_tokens)
  benchmark_result['tokens_per_min'] = tokens_per_min

  if args.machine_cost:
    print(
        "Cost $/1k tokens:"
        f" {args.machine_cost * 1000 / (60 * output_tokens_per_min)}"
    )

  benchmark_result = {
    **benchmark_result,
    **(get_stats_for_set("per_token_latency", "seconds/token (includes waiting time on server)", [
      latency / (prompt_len + output_len)
      for prompt_len, output_len, latency in REQUEST_LATENCY
    ])),

    # NOTE: The latency below includes requests awaiting time on server side.
    # It's not comparable with the model inference latency for batch size 1.
    **(get_stats_for_set("latency", "Average milliseconds/request (includes waiting time on server)" ,[1000 * latency for _, _, latency in REQUEST_LATENCY])),
    **(get_stats_for_set("per_output_token_latency", "Average milliseconds/output_token (includes waiting time on server)", [1000 * latency / output_len for _, output_len, latency in REQUEST_LATENCY])),
    **(get_stats_for_set("input_len", "input length", [float(prompt_len) for prompt_len, _, _ in REQUEST_LATENCY])),
    **(get_stats_for_set("output_len", "output length", [float(output_len) for _, output_len, _ in REQUEST_LATENCY]))
  }

  server_metrics = {}
  if args.scrape_server_metrics:
    server_metrics = print_metrics(metrics_to_scrape(args.backend), benchmark_time, args.backend)
  if args.save_json_results:
    save_json_results(args, benchmark_result, server_metrics)


if __name__ == "__main__":
  parser = argparse.ArgumentParser(
      description="Benchmark the online serving throughput."
  )
  parser.add_argument(
      "--backend",
      type=str,
      default="vllm",
      choices=[
          "vllm",
          "tgi",
          "naive_transformers",
          "tensorrt_llm_triton",
          "sax",
          "jetstream"
      ],
  )
  parser.add_argument(
      "--sax_model",
      type=str,
      default="",
      help="Model name to send request to at API server for SAX model server.",
  )
  parser.add_argument("--endpoint", type=str, default="generate")
  parser.add_argument("--host", type=str, default="localhost")
  parser.add_argument("--port", type=int, default=7080)
  parser.add_argument("--dataset", type=str, help="Path to the dataset.")
  parser.add_argument(
    "--model",
    type=str,
    help="Name of the model.",
  )
  parser.add_argument(
      "--tokenizer",
      type=str,
      required=True,
      help="Name or path of the tokenizer.",
  )
  parser.add_argument(
      "--best-of",
      type=int,
      default=1,
      help="Generates `best_of` sequences per prompt and returns the best one.",
  )
  parser.add_argument("--use-beam-search", action="store_true")
  parser.add_argument(
      "--num-prompts",
      type=int,
      default=1000,
      help="Number of prompts to process.",
  )
  parser.add_argument(
      "--max-input-length",
      type=int,
      default=1024,
      help=(
          "Maximum number of input tokens for filtering the benchmark dataset."
      ),
  )
  parser.add_argument(
      "--max-output-length",
      type=int,
      default=1024,
      help=(
          "Maximum number of input tokens for filtering the benchmark dataset."
      ),
  )
  parser.add_argument(
      "--top-k",
      type=int,
      default=32000,
      help=(
          "Number of candidate tokens that are considered at each step of the"
          " generation process. 32000 is the vocab_size of Open-LLaMA and"
          " LLaMA2 models."
      ),
  )
  parser.add_argument(
      "--request-rate",
      type=float,
      default=float("inf"),
      help=(
          "Number of requests per second. If this is inf, "
          "then all the requests are sent at time 0. "
          "Otherwise, we use Poisson process to synthesize "
          "the request arrival times."
      ),
  )
  parser.add_argument("--seed", type=int, default=0)
  parser.add_argument(
      "--trust-remote-code",
      action="store_true",
      help="trust remote code from huggingface",
  )
  parser.add_argument(
      "--machine-cost",
      type=float,
      default=None,
      help="Machine cost per hour including accelerators (if any)",
  )
  parser.add_argument(
      "--use-dummy-text",
      action="store_true",
      help=(
          "Whether to use dummy text with length defined by max_input_length"
          " and max_output_length."
      ),
  )
  parser.add_argument(
      "--save-json-results",
      action="store_true",
      help="Whether to save benchmark results to a json file.",
  )
  parser.add_argument(
      "--additional-metadata-metrics-to-save",
      type=str,
      help=(
          "Additional metadata about the workload. Should be a dictionary in"
          " the form of a string."
      ),
  )
  parser.add_argument(
      "--scrape-server-metrics",
      action="store_true",
      help="Whether to scrape server metrics.",
  )
  cmd_args = parser.parse_args()
  main(cmd_args)