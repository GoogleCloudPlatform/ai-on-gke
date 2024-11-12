r"""Benchmark LLM serving throughput and latency.
This script is for sending requests with prompts to LLM server and benchmark
the latency and throughput at various request rates. It is a modified version of
https://github.com/vllm-project/vllm/blob/main/benchmarks/benchmark_serving.py.
It currently supports TGI, vLLM, Triton TensorRT-LLM and Saxml.
"""

from abc import ABC, abstractmethod
import argparse
import asyncio
from datetime import datetime
import json
import random
import requests
import time
import os
from typing import AsyncGenerator, List, Optional, Tuple, Dict, TypedDict
from prometheus_client import start_http_server, Histogram

import google.auth
import google.auth.transport.requests

import aiohttp
import numpy as np
from sympy import symbols
from sympy.parsing.sympy_parser import parse_expr
from transformers import AutoTokenizer
from transformers import PreTrainedTokenizerBase

MIN_SEQ_LEN = 4
CLIENT_TIMEOUT_SEC = 3 * 60 * 60
NEW_TEXT_KEY = "\nOutput:\n"
PROMETHEUS_PORT = 9090
NS_IN_SEC = 1_000_000_000

# Prometheus Metrics
prompt_length_metric = Histogram("LatencyProfileGenerator:prompt_length", "Input prompt length", buckets=[2**i for i in range(1, 16)])
response_length_metric = Histogram("LatencyProfileGenerator:response_length", "Response length", buckets=[2**i for i in range(1, 16)])
tpot_metric = Histogram('LatencyProfileGenerator:time_per_output_token', 'Time per output token per request')
  
class Backend(ABC):
    """
    An abstract base class for Backend that defines the interface
    for new model server backends.
    """

    async def send_request(
        self,
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
    ) -> Tuple[Optional[Tuple[int, int, float]], Optional[Dict[str, int]]]:
      """Sends request to server."""
      request_start_time = time.time()
      errors = init_errors_map()

      headers = {"User-Agent": "Benchmark Client"}
      pload = self.create_request_payload(
        prompt=prompt,
        prompt_len=prompt_len,
        output_len=output_len,
        best_of=best_of,
        use_beam_search=use_beam_search,
        top_k=top_k,
        tokenizer=tokenizer,
        sax_model=sax_model,
        model=model,
      )
      
      # Set client timeout to be 3 hrs.
      timeout = aiohttp.ClientTimeout(total=CLIENT_TIMEOUT_SEC)
      async with aiohttp.ClientSession(timeout=timeout,trust_env=True) as session:
        while True:
          try:
            async with session.post(f"{api_url}/{self.get_endpoint()}", headers=headers, json=pload, ssl=False) as response:
              output = await response.json()

            # Re-send the request if it failed.
            if "error" not in output:
              break
          except aiohttp.client_exceptions.ClientConnectorError as client_err:
            errors["ClientConnectorError"] += 1
            print(f"ClientConnectorError: {client_err}")
            return None, errors
          except asyncio.TimeoutError as timeout_err:
            errors["TimeoutError"] += 1
            print(f"TimeoutError: {timeout_err}")
            return None, errors
          except aiohttp.client_exceptions.ClientOSError as e:
            errors["ClientOSError"] += 1
            print(f"ClientOSError: {e}")
            return None, errors
          except aiohttp.client_exceptions.ContentTypeError as e:
            print(f"ContentTypeError: {e}, response: {response}")
            errors["ContentTypeError"] += 1
            return None, errors
          except aiohttp.client_exceptions.ServerDisconnectedError as e:
            errors["ServerDisconnectedError"] += 1
            print(f"ServerDisconnectedError: {e}")
            return None, errors
          except Exception as e: 
            print(f"Unknown error {e}")
            errors["unknown_error"] += 1
            return None, errors
      request_end_time = time.time()
      # Naive HF transformers generation and TensorRT-LLM generation stops at EOS
      # tokens and the generation may be shorter than the ground-truth output
      # sequence length.
      output_len = self.get_response_length(
        response=output,
        request_len=prompt_len,
        tokenizer=tokenizer
      )

      # (prompt len, output len, latency, success)
      request_latency = (prompt_len, output_len, (request_end_time - request_start_time))
      tpot_metric.observe((request_end_time - request_start_time) / output_len)
      prompt_length_metric.observe(prompt_len)
      response_length_metric.observe(output_len)

      return request_latency, None

    @abstractmethod
    def create_request_payload(self,
      prompt: str,
      prompt_len: int,
      output_len: int,
      best_of: int,
      use_beam_search: bool,
      top_k: int,
      tokenizer: PreTrainedTokenizerBase,
      sax_model: str,
      model: str) -> Dict:
        pass

    @abstractmethod
    def get_response_length(
        self, 
        request_len: int, 
        response: Dict, 
        tokenizer: PreTrainedTokenizerBase) -> int:
      pass
    
    @abstractmethod
    def get_server_metrics(self) -> List[str]:
      pass

    @abstractmethod
    def get_endpoint(self) -> str:
      pass

class vLLMBackend(Backend):
  def get_server_metrics(self) -> List[str]:
    return ["vllm:gpu_cache_usage_perc", "vllm:num_requests_waiting"]
  def get_endpoint(self) -> str:
      return "v1/completions"
  def create_request_payload(self,
      prompt: str,
      prompt_len: int,
      output_len: int,
      best_of: int,
      use_beam_search: bool,
      top_k: int,
      tokenizer: PreTrainedTokenizerBase,
      sax_model: str,
      model: str):
    return {
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
  def get_response_length(
        self, 
        request_len: int, 
        response: Dict, 
        tokenizer: PreTrainedTokenizerBase):
    output_token_ids = tokenizer(response["choices"][0]["text"]).input_ids
    return len(output_token_ids)

class JetstreamBackend(Backend):
  def get_server_metrics(self) -> List[str]:
    return [
      "jetstream_slots_used_percentage",
      "jetstream_prefill_backlog_size",
    ]
  def get_endpoint(self) -> str:
      return ""
  def create_request_payload(self,
      prompt: str,
      prompt_len: int,
      output_len: int,
      best_of: int,
      use_beam_search: bool,
      top_k: int,
      tokenizer: PreTrainedTokenizerBase,
      sax_model: str,
      model: str):
    return {
        "prompt": prompt,
        "max_tokens": output_len,
    }
  def get_response_length(
        self, 
        request_len: int, 
        response: Dict, 
        tokenizer: PreTrainedTokenizerBase):
    output_token_ids = tokenizer(response["response"]).input_ids
    return len(output_token_ids)

class TgiBackend(Backend):
  def get_server_metrics(self) -> List[str]:
    return [""]
  def get_endpoint(self) -> str:
    return ""
  def create_request_payload(self,
      prompt: str,
      prompt_len: int,
      output_len: int,
      best_of: int,
      use_beam_search: bool,
      top_k: int,
      tokenizer: PreTrainedTokenizerBase,
      sax_model: str,
      model: str):
    return {
      "inputs": prompt,
      "parameters": {
        "best_of": best_of,
        "max_new_tokens": output_len,
        "do_sample": True,
      },
    }
  def get_response_length(
        self, 
        request_len: int, 
        response: Dict, 
        tokenizer: PreTrainedTokenizerBase):
    output_token_ids = tokenizer(response["generated_text"]).input_ids
    return len(output_token_ids)

class NaiveTransformersBackend(Backend):
  def get_server_metrics(self) -> List[str]:
    return [""]
  def get_endpoint(self) -> str:
      return ""
  def create_request_payload(self,
      prompt: str,
      prompt_len: int,
      output_len: int,
      best_of: int,
      use_beam_search: bool,
      top_k: int,
      tokenizer: PreTrainedTokenizerBase,
      sax_model: str,
      model: str):
    return {
        "instances": [{
            "prompt": prompt,
            "max_length": output_len,
            "top_k": top_k,
        }]
    }
  def get_response_length(
        self, 
        request_len: int, 
        response: Dict, 
        tokenizer: PreTrainedTokenizerBase):
    complete_pred = response["predictions"][0][0]["generated_text"]
    new_text_start_index = complete_pred.find(NEW_TEXT_KEY) + len(NEW_TEXT_KEY)
    pred = complete_pred[new_text_start_index:]
    output_token_ids = tokenizer(pred).input_ids
    return len(output_token_ids) - request_len

class TensorrtLlmTritonBackend(Backend):
  def get_server_metrics(self) -> List[str]:
    return [""]
  def get_endpoint(self) -> str:
      return ""
  def create_request_payload(self,
      prompt: str,
      prompt_len: int,
      output_len: int,
      best_of: int,
      use_beam_search: bool,
      top_k: int,
      tokenizer: PreTrainedTokenizerBase,
      sax_model: str,
      model: str):
    return {
        "text_input": prompt,
        "max_tokens": output_len,
        "beam_width": 1 if not use_beam_search else best_of,
        "temperature": 0.0 if use_beam_search else 1.0,
        "top_p": 1.0,
        "bad_words": "",
        "stop_words": "",
        "stream": False,
    }
  def get_response_length(
        self, 
        request_len: int, 
        response: Dict, 
        tokenizer: PreTrainedTokenizerBase):
    output_token_ids = tokenizer(response["text_output"]).input_ids
    return len(output_token_ids)

class SaxBackend(Backend):
  def get_server_metrics(self) -> List[str]:
    return [""]
  def get_endpoint(self) -> str:
      return ""
  def create_request_payload(self,
      prompt: str,
      prompt_len: int,
      output_len: int,
      best_of: int,
      use_beam_search: bool,
      top_k: int,
      tokenizer: PreTrainedTokenizerBase,
      sax_model: str,
      model: str):
    return {
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
  def get_response_length(
        self, 
        request_len: int, 
        response: Dict, 
        tokenizer: PreTrainedTokenizerBase):
    output_token_ids = tokenizer(response["choices"][0]["text"]).input_ids
    return len(output_token_ids)

class BenchmarkConfig(TypedDict):
    model: str
    model_server: str
    start_time: float

class MetricSummary(TypedDict, total=False):
  json_field_name:   Optional[str]
  name:              str
  description:       str
  mean:              float
  median:            Optional[float]
  sd:                Optional[float]
  min:               Optional[float]
  max:               Optional[float]
  p90:               Optional[float]
  p99:               Optional[float]

class BenchmarkingStepReport(TypedDict):
  """Result for one step"""
  request_rate: float
  timestamp_start: float
  timestamp_end: float
  num_prompts_attempted: int
  latencies: List
  local_metrics: List[MetricSummary]
  server_metrics: Optional[List[MetricSummary]]
  errors: Dict[str, int]

class BenchmarkingReport():
  """Results for all steps for a single model"""
  args: argparse.Namespace
  config: BenchmarkConfig
  steps: List[BenchmarkingStepReport]
  
  def __init__(self, args : argparse.Namespace, model: str, start_time: float):
    self.args = args
    self.config = BenchmarkConfig(
      model        = model, 
      model_server  = args.backend, 
      start_time    = start_time
    )
    self.steps = []

  def record_metrics_for_step(
      self,
      request_rate: float, 
      timestamp_start: float,
      timestamp_end: float,
      num_prompts_attempted : int, 
      latencies: List,
      errors: Dict[str, int],
      backend: Backend,
    ):

    def fetch_metrics_from_gmp(backend: Backend, duration: float) -> List[MetricSummary]:
      """Gets summaries for metrics queried from GMP, queries vary per model server"""

      # Creates a credentials object from the default service account file
      # Assumes that script has appropriate default credentials set up, ref:
      # https://googleapis.dev/python/google-auth/latest/user-guide.html#application-default-credentials
      credentials, project_id = google.auth.default()
      # Prepare an authentication request - helps format the request auth token
      auth_req = google.auth.transport.requests.Request()

      # Request refresh tokens
      credentials.refresh(auth_req)
      url='https://monitoring.googleapis.com/v1/projects/%s/location/global/prometheus/api/v1/metadata' % (project_id)
      headers_api = {'Authorization': 'Bearer ' + credentials.token}
      request_post = requests.get(url=url, headers=headers_api)
      all_metrics_metadata = request_post.json()
      if request_post.ok is not True:
        print("HTTP Error: %s" % (all_metrics_metadata))
        return []
      if all_metrics_metadata["status"] != "success":
        print("Metadata error response: %s" % all_metrics_metadata["error"])
        return []
        
      metrics_list : List[MetricSummary] = []
      for metric in backend.get_server_metrics():
        print("Metric Name: %s" % (metric))

      # Find metric type
        metric_type = all_metrics_metadata['data'][metric]
        if all_metrics_metadata['data'][metric] is None:
          print("No metric found for: %s" % metric)
          return []
        metric_type = metric_type[0]['type']

        metric_results = {}
        # Queries scrape all metrics collected from the last $DURATION seconds from the backend's related
        # podmonitoring spec assumed to be named "$BACKEND-podmonitoring"
        queries = {
          "gauge": {
            "Mean": "avg_over_time(%s{job='%s-podmonitoring'}[%.0fs])" % (metric, self.args.backend, duration),
            "Median": "quantile_over_time(0.5, %s{job='%s-podmonitoring'}[%.0fs])" % (metric, self.args.backend, duration),
            "Sd": "stddev_over_time(%s{job='%s-podmonitoring'}[%.0fs])" % (metric, self.args.backend, duration),
            "Min": "min_over_time(%s{job='%s-podmonitoring'}[%.0fs])" % (metric, self.args.backend, duration),
            "Max": "max_over_time(%s{job='%s-podmonitoring'}[%.0fs])" % (metric, self.args.backend, duration),
            "P90": "quantile_over_time(0.9, %s{job='%s-podmonitoring'}[%.0fs])" % (metric, self.args.backend, duration),
            "P99": "quantile_over_time(0.99, %s{job='%s-podmonitoring'}[%.0fs])" % (metric, self.args.backend, duration),
          },
        "histogram": {
            "Mean": "sum(rate(%s_sum{job='%s-podmonitoring'}[%.0fs])) / sum(rate(%s_count{job='%s-podmonitoring'}[%.0fs]))" % (metric, self.args.backend, duration, metric, self.args.backend, duration),
            "Median": "histogram_quantile(0.5, sum(rate(%s_bucket{job='%s-podmonitoring'}[%.0fs])) by (le))" % (metric, self.args.backend, duration),
            "Min": "histogram_quantile(0, sum(rate(%s_bucket{job='%s-podmonitoring'}[%.0fs])) by (le))" % (metric, self.args.backend, duration),
            "Max": "histogram_quantile(1, sum(rate(%s_bucket{job='%s-podmonitoring'}[%.0fs])) by (le))" % (metric, self.args.backend, duration),
            "P90": "histogram_quantile(0.9, sum(rate(%s_bucket{job='%s-podmonitoring'}[%.0fs])) by (le))" % (metric, self.args.backend, duration),
            "P99": "histogram_quantile(0.99, sum(rate(%s_bucket{job='%s-podmonitoring'}[%.0fs])) by (le))" % (metric, self.args.backend, duration),
          }
        }

        metric_data : MetricSummary = {
              "name": metric,
              "description": f"Metrics for {metric} from {self.args.backend} backend",
            }
        for query_name, query in queries[metric_type].items():
            
            # Configure respective query
            url = f'https://monitoring.googleapis.com/v1/projects/{project_id}/location/global/prometheus/api/v1/query'
            headers_api = {'Authorization': f'Bearer {credentials.token}'}
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
              
            # Handle response
            if request_post.ok and response["status"] == "success":
                result_value = float(response["data"]["result"][0]["value"][1])
                if query_name == "Mean":
                    metric_data["mean"] = result_value
                elif query_name == "Median":
                    metric_data["median"] = result_value
                elif query_name == "Sd":
                    metric_data["sd"] = result_value
                elif query_name == "Min":
                    metric_data["min"] = result_value
                elif query_name == "Max":
                    metric_data["max"] = result_value
                elif query_name == "P90":
                    metric_data["p90"] = result_value
                elif query_name == "P99":
                    metric_data["p99"] = result_value
            else:
                error_message = response.get("error", "HTTP Error")
                print(f"Error fetching {query_name} for {metric}: {error_message}")
          
        metrics_list.append(metric_data)
      return metrics_list

    def metric_sumamry_from_points(name: str, description: str, points : List[float], json_field_name: Optional[str] = None) -> MetricSummary:
        mean = np.mean(points) if points else 0
        median = np.median(points) if points else 0
        sd = np.std(points) if points else 0
        min = np.min(points) if points else 0
        max = np.max(points) if points else 0
        p90 = np.percentile(points, 90) if points else 0
        p99 = np.percentile(points, 99) if points else 0

        return MetricSummary(
          json_field_name = json_field_name if json_field_name is not None else name,
          name = name,
          description = description,
          mean = float(mean),
          median = float(median),
          sd = float(sd),
          min = float(min),
          max = float(max),
          p90 = float(p90),
          p99 = float(p99)
        ) 
    
    total_time = (timestamp_end - timestamp_start)/ NS_IN_SEC
    if self.args.scrape_server_metrics:
      server_metrics = fetch_metrics_from_gmp(backend, total_time)

    self.steps.append(BenchmarkingStepReport(
      request_rate = request_rate,
      timestamp_start = timestamp_start,
      timestamp_end = timestamp_end,
      num_prompts_attempted = num_prompts_attempted,
      latencies = latencies,
      errors = errors,
      local_metrics = [
        metric_sumamry_from_points( 
          name="per_token_latency", 
          description="seconds/token (includes waiting time on server)", 
          points=[latency / (prompt_len + output_len) for prompt_len, output_len, latency in latencies]),
        metric_sumamry_from_points(
          json_field_name="request_latency", 
          name="latency",
          description="milliseconds/request (includes waiting time on server)" ,
          points=[1000 * latency for _, _, latency in latencies]),
        metric_sumamry_from_points(
          json_field_name="tpot", 
          name="per_output_token_latency", 
          description="milliseconds/output_token (includes waiting time on server)", 
          points=[1000 * latency / output_len for _, output_len, latency in latencies]),
        metric_sumamry_from_points(
          name="input_length", 
          description="length of prompt", 
          points=[float(prompt_len) for prompt_len, _, _ in latencies]),
        metric_sumamry_from_points(
          name="output_length", 
          description="length of response", 
          points=[float(output_len) for _, output_len, _ in latencies]),
        MetricSummary(
          name = "throughput",
          description = "throughput in requests per second",
          mean = (len(latencies) / ((timestamp_end - timestamp_start) / NS_IN_SEC)),
        ),
      ],
      server_metrics = server_metrics
    ))

  # Each element in the output list is a report for each step
  def to_text_reports(self, write_to_files: bool = False) -> List[str]:
    output : Dict[str, str] = {}
    required_stats = ["latency", "throughput", "input_length", "output_length", "per_output_token_latency"]
    for step in self.steps:
     if not all(required_stat in [metric['name'] for metric in step['local_metrics']] for required_stat in required_stats):
        raise Exception(f"All of the following stats must be recorded: {required_stats}")
     
    for step in self.steps:
      step_output : List[str] = []
      total_time = (step['timestamp_end'] - step['timestamp_start']) / NS_IN_SEC
      total_output_tokens = np.sum([output_len for _, output_len, _ in step['latencies']])
      output_tokens_per_second = total_output_tokens / total_time
      output_tokens_per_min = 60 * output_tokens_per_second

      total_input_tokens = np.sum([prompt_len for prompt_len, _, _ in step['latencies']])
      input_tokens_per_min = 60 * total_input_tokens / total_time

      total_tokens = total_input_tokens + total_output_tokens
      tokens_per_min = 60 * total_tokens / total_time
      step_output.append(f"====Result for Model: {self.config['model']}====")
      step_output.append(f"Errors: {step['errors']}")
      step_output.append(f"Total time: {total_time:.2f} s")
      step_output.append(f"Successful/total requests: {len(step['latencies'])}/{step['num_prompts_attempted']}")
      step_output.append(f"Requests/min: {60 * step['num_prompts_attempted'] / total_time:.2f}")
      step_output.append(f"Output_tokens/min: {output_tokens_per_min:.2f}")
      step_output.append(f"Input_tokens/min: {input_tokens_per_min:.2f}")
      step_output.append(f"Tokens/min: {tokens_per_min:.2f}")

      if self.args.machine_cost:
          step_output.append(
              f"Cost $/1k tokens: {self.args.machine_cost * 1000 / (60 * output_tokens_per_min)}"
          )
      for metric in step['local_metrics']:
        step_output.append(f"Average {metric['description']}:" f" {metric['mean']:.2f}")
      output_filename = f"latency-profile-{datetime.fromtimestamp(step['timestamp_start'] / NS_IN_SEC).strftime('%Y-%m-%d_%H-%M-%S')}.txt"
      output[output_filename] = '\n'.join(step_output)
      if write_to_files:
        with open(output_filename, 'w') as file:
          file.write(output[output_filename])
    return list(output.values())

  # The output is a a single json summary of all steps
  def to_json_report(self, write_to_file: bool = False) -> Dict:
    output = {
      "config": {
         **self.config,
        "num_models":  len(self.args.models) if self.args.save_aggregated_result else 1,
        "start_time": {
          "seconds" : self.steps[0]["timestamp_start"] // NS_IN_SEC,
          "nanos" : self.steps[0]["timestamp_start"] % NS_IN_SEC,
        },
      },
      "summary_stats": {
        "stats": [
            {
              "request_rate": step["request_rate"],
              **{(metric["json_field_name"] if "json_field_name" in metric else metric["name"]): metric for metric in step["local_metrics"]},
              "model_server_metrics": [
                  {"name": server_metric["name"], **server_metric}
                  for server_metric in step["server_metrics"]
              ] if step["server_metrics"] is not None else []
            }
            for step in self.steps
        ]
      },

      # Legacy use case, use config if possible
      "dimensions": {
        "date": self.args.start_datetime.strftime('%Y%m%d-%H%M%S'),
        "backend":  self.args.backend,
        "model_id": self.config['model'],
        "tokenizer_id": self.args.tokenizer,
      } if len(self.args.models.split(',')) == 1 else None,
      # Legacy use case, use summary_stats if possible
      "metrics": {
          # Traffic metrics
          "num_prompts_attempted": self.steps[0]['num_prompts_attempted'],
          "num_prompts_succeeded": len(self.steps[0]['latencies']),
          "request_rate": self.steps[0]['request_rate'],
          **{
              f"{stat}_{metric['name']}": value
              for metric in self.steps[0]["local_metrics"]
              if "json_field_name" in metric
              for stat, value in metric.items()
              if stat not in ["name", "description", "json_field_name"] and value is not None
          },
          "server_metrics": [
                  {"name": server_metric["name"], **server_metric}
                  for server_metric in self.steps[0]["server_metrics"]
              ] if self.steps[0]["server_metrics"] is not None else []
      } if len(self.steps) == 1 else None
    }
  
    if write_to_file:
      model_without_slash = self.config['model'].replace("/","-")
      file_name = (
          f"{self.args.file_prefix}-{self.args.backend}-{self.args.start_datetime.strftime('%Y%m%d-%H%M%S')}-{model_without_slash}.json"
      )
      with open(file_name, "w", encoding="utf-8") as outfile:
        json.dump(output, outfile)
    return output

def init_errors_map() -> Dict[str, int]:
  errors = {
    "ClientConnectorError": 0,
    "TimeoutError": 0,
    "ContentTypeError": 0,
    "ClientOSError": 0,
    "ServerDisconnectedError": 0,
    "unknown_error": 0,
  }
  return errors

def get_backend(backend: str) -> Backend:
  if backend == "vllm":
    return vLLMBackend()
  elif backend == "tgi":
    return TgiBackend()
  elif backend == "naive_transformers":
    return NaiveTransformersBackend()
  elif backend == "tensorrt_llm_triton":
    return TensorrtLlmTritonBackend()
  elif backend == "sax":
    return SaxBackend()
  elif backend == "jetstream":
    return JetstreamBackend()
  else:
    raise ValueError("Unsupported backend")

async def generate_next_request(
    input_requests: List[Tuple[str, int, int]],
    request_rate_expr: str,
    start_time: float,
) -> AsyncGenerator[Tuple[str, int, int], None]:
  """Gets request async."""
  request = random.choice(input_requests)
  while True:
    yield request

    if request_rate_expr == "oo":
      # If the request rate is infinity, then we don't need to wait.
      continue

    # Evaluate the request rate at this point in time
    t = symbols('t')
    expr_parsed = parse_expr(request_rate_expr, transformations="all", local_dict={"t": t})
    request_rate_at_t = expr_parsed.subs(t, ((time.time_ns() - start_time) / NS_IN_SEC))

    # Sample the request interval from the exponential distribution.
    interval = np.random.exponential(1.0 / request_rate_at_t)
    # The next request will be sent after the interval.
    await asyncio.sleep(interval)

def get_filtered_dataset(
    dataset_path: str,
    max_input_len: int,
    max_output_len: int,
    tokenizer: PreTrainedTokenizerBase,
    use_dummy_text: bool,
) -> List[Tuple[str, int, int]]:
    """Gets a subset of the dataset where all elements adhere to the specified constraints"""
    if use_dummy_text:
      dummy_prompt_token_ids = [0] * max_input_len
      dummy_prompt = tokenizer.decode(dummy_prompt_token_ids)
      return [(
          dummy_prompt,
          max_input_len,
          max_output_len,
      )]

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

    return filtered_dataset

async def benchmark(
    args: argparse.Namespace,
    backend: Backend,
    tokenizer: PreTrainedTokenizerBase,
    model: str,
) -> BenchmarkingReport:
  """Runs benchmark with asynchronous requests."""
  input_requests = get_filtered_dataset(
      args.dataset,
      args.max_input_length,
      args.max_output_length,
      tokenizer,
      args.use_dummy_text,
  )
  benchmark_results = BenchmarkingReport(args, model, time.time_ns())

  all_steps = {}
  if args.job is not None:
    all_steps = args.job
  elif args.num_prompts is not None:
    all_steps = {
      "steps": [{
        "rate": args.request_rate,
        "max_num_prompts": args.num_prompts,
      }]
    }
  for index, step in enumerate(all_steps["steps"]):
  
    # No need to sleep before running the first step
    if 'time_between_steps' in args.job and index != 0:
      print(f"Sleeping for {args.job['time_between_steps']} sec...")
      await asyncio.sleep(args.job["time_between_steps"])
    max_prompts = f" {step['max_num_prompts']} requests" if 'max_num_prompts' in step else ""
    duration = f" {step['time']} sec" if 'time' in step else " "
    print(f"Starting benchmarking{max_prompts} at {step['rate']} requests/sec for{duration}")

    tasks: List[asyncio.Task] = []
    prompts_sent_this_step: int = 0
    step_start_timestamp = time.time_ns()
    async for request in generate_next_request(input_requests, str(step["rate"]), step_start_timestamp):
      # Stop conditions
      if "max_num_prompts" in step and prompts_sent_this_step >= step["max_num_prompts"]:
        break
      if "time" in step and ((time.time_ns() - step_start_timestamp ) / NS_IN_SEC) > step["time"]:
        break

      prompt, prompt_len, output_len = request
      task = asyncio.create_task(
          backend.send_request(
              f"http://{args.host}:{args.port}",
              prompt,
              prompt_len,
              output_len,
              args.best_of,
              args.use_beam_search,
              args.top_k,
              tokenizer,
              args.sax_model,
              model,
          )
      )
      tasks.append(task)
      prompts_sent_this_step += 1

    print("All requests sent, awaiting responses...")
    results = await asyncio.gather(*tasks)
    step_end_timestamp = time.time_ns()
    print(f"Finished benchmarking step {index + 1}")

    all_latencies = []
    all_errors = init_errors_map()
    for latency, errors in results:
      if latency:
        all_latencies.append(latency)
      if errors:
        for err, count in errors.items():
          all_errors[err] = all_errors[err] + count
    benchmark_results.record_metrics_for_step(step['rate'], step_start_timestamp, step_end_timestamp, prompts_sent_this_step, all_latencies, all_errors, backend)
  
  print(f"Completed all steps, generating reports...")
  return benchmark_results

def aggregate_benchmark_reports(reports: List[BenchmarkingReport]) -> BenchmarkingReport: 
  """When benchmarking multiple models we will generate a BenchmarkingReport for each."""
  """If `save_aggregated_result` is set, we aggregate these into a single report."""

  aggregated_step_report = {
    "request_rate":  reports[0].steps[0]["request_rate"],
    "timestamp_start": 0.0,
    "timestamp_end": 0.0,
    "num_prompts_attempted": 0,
    "latencies": [],
    "server_metrics": [],
    "errors": {},
  }

  def accumulate_errors(errors_list: List[Dict[str, int]]) -> Dict[str, int]:
    accumulated_errors = init_errors_map()
    for errors in errors_list:
        for error_type, count in errors.items():
            accumulated_errors[error_type] += count
    return accumulated_errors

  for report in reports:
    # Input metavalidation asserts this report only has one step report
    report = report.steps[0]
    aggregated_step_report["timestamp_start"] = min(aggregated_step_report["timestamp_start"], report["timestamp_start"])
    aggregated_step_report["timestamp_end"] = max(aggregated_step_report["timestamp_end"], report["timestamp_end"])
    aggregated_step_report["num_prompts_attempted"] += report["num_prompts_attempted"]
    aggregated_step_report["latencies"].extend(report["latencies"])
    aggregated_step_report["errors"] = accumulate_errors([aggregated_step_report["errors"], report["errors"]])

  aggregated_report = BenchmarkingReport(reports[0].args, f"ALL-{len(reports)}-MODELS", aggregated_step_report["timestamp_start"])
  aggregated_report.record_metrics_for_step(**aggregated_step_report)

  return aggregated_report

async def main(args: argparse.Namespace):
  print(args)
  models = args.models.split(',')
  print(f"Models to benchmark: {models}")
  random.seed(args.seed)
  np.random.seed(args.seed)

  print(f"Starting Prometheus Server on port {PROMETHEUS_PORT}")
  start_http_server(PROMETHEUS_PORT)

  tokenizer = AutoTokenizer.from_pretrained(
      args.tokenizer, trust_remote_code=args.trust_remote_code
  )
  args.start_datetime = datetime.fromtimestamp(time.time_ns() / NS_IN_SEC)
  
  backend: Backend = get_backend(args.backend)
  reports : List[BenchmarkingReport] = await asyncio.gather(
    *[benchmark(args, backend, tokenizer, model) for model in models]
  )

  if args.save_aggregated_result:
    aggregated_benchmark = aggregate_benchmark_reports(reports)
    aggregated_benchmark.to_text_reports(write_to_files=True)
    aggregated_benchmark.to_json_report(write_to_file=args.save_json_results)
  else:
    for report in reports:
      report.to_text_reports(write_to_files=True)
      report.to_json_report(write_to_file=args.save_json_results)
  
def input_metavalidation(args: argparse.Namespace):
  """Validate a correct combination of arguments is set"""

  if sum([bool(args.request_rate is not None and args.num_prompts is not None), bool(args.job is not None)]) != 1:
    raise ValueError("All args must be set for one and only one of the following sets of arguments: {--request-rate, --num-prompts} or {--job}")

  if args.save_aggregated_result and args.benchmark is not None and len(args.benchmark) != 1 and args.models is not None and len(args.models) > 1:
      raise ValueError("Multi model benchmarking with multi step benchmarking is not supported yet")

  if args.use_beam_search and args.backend == "tgi":
    raise ValueError("Beam search is not supported by TGI")
  
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
  parser.add_argument("--file-prefix", type=str, default="benchmark")
  parser.add_argument("--host", type=str, default="localhost")
  parser.add_argument("--port", type=int, default=7080)
  parser.add_argument("--dataset", type=str, help="Path to the dataset.")
  parser.add_argument(
    "--models",
    type=str,
    help="Comma separated list of models to benchmark.",
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
      default=None,
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

  # Input assertions
  def is_expression_of_t(input_str):
    if input_str == "inf":
      return "oo"
    # Check if expression uses variables other than 't' by attempting to evaluate with only 't' defined
    try:
      t = symbols('t')
      expr_parsed = parse_expr(input_str, transformations="all", local_dict={"t": t})
      expr_parsed.subs(t, 1)
      return input_str
    except Exception:
      raise ValueError(f"Request rate {input_str}, must be an expression of `t`")
    
  parser.add_argument(
      "--request-rate",
      type=is_expression_of_t,
      default=None,
      help=(
          "Specifies the request rate as a function of time, f(t)."
          " Example format: '1+1.05*t', where 't' represents seconds from"
          " start. If set to 'inf', all requests are sent at time 0."
          " Otherwise, the function is interpreted to generate a Poisson"
          " process for request arrival times based on the provided rate"
          " expression."
    ),
  )

  def parse_request_rates(input_str):
      if input_str is None:
          return None
      # Check if input is a filename and load its contents
      if os.path.isfile(input_str):
          with open(input_str, 'r') as file:
              input_str = file.read()
      try:
          # Parse the input string as JSON
          request_data = json.loads(input_str)
          # Validate that the JSON has the correct structure
          if not isinstance(request_data, dict):
              raise argparse.ArgumentTypeError("Input JSON must be an object containing 'time_between_steps' and 'steps'.")
          # Check 'time_between_steps' field
          if "time_between_steps" not in request_data or (not isinstance(request_data["time_between_steps"], float) and not isinstance(request_data["time_between_steps"], int)):
              raise argparse.ArgumentTypeError("'time_between_steps' must be a float or int.")
          # Check 'steps' field
          if "steps" not in request_data or not isinstance(request_data["steps"], list):
              raise argparse.ArgumentTypeError("'steps' must be a list of objects with 'rate' and 'time'.")
          
          # Validate each entry in the 'steps' list
          for i, rate_entry in enumerate(request_data["steps"]):
            if not isinstance(rate_entry, dict):
                raise argparse.ArgumentTypeError(f"Entry {i} in 'steps' must be a JSON object.")
            
            if "rate" not in rate_entry:
                raise argparse.ArgumentTypeError(f"Entry {i} in 'steps' must have a 'rate' key.")
            if "time" not in rate_entry  and "max_num_prompts" not in rate_entry:
                raise argparse.ArgumentTypeError(f"Entry {i} in 'steps' must have a 'time' and/or 'max_num_prompts' key.")

            # Validate the 'rate' field to allow for string expressions or floats
            if isinstance(rate_entry["rate"], str):
                try:
                  is_expression_of_t(rate_entry["rate"])  # Validate the expression
                except Exception as e:
                  raise argparse.ArgumentTypeError(f"Entry {i} in 'steps': {e}")
            # Validate the 'time' field
            if not isinstance(rate_entry["time"], (float, int)):
                raise argparse.ArgumentTypeError(f"Entry {i} in 'steps': 'time' must be a positive float.")
          return request_data
      except json.JSONDecodeError as e:
          raise argparse.ArgumentTypeError("Invalid JSON format")

  parser.add_argument(
      "--job",
      type=parse_request_rates,
      default=None,
      required=False,
      help=(
          "Specify the benchmark procedure in JSON format, either as raw JSON"
          " or as a filename. \n"
          " The JSON should have the following structure:\n\n"
          "     {\n"
          "         \"time_between_steps\": float (seconds to rest between rates),\n" 
          "         \"rates\": [\n"
          "             {\n"
          "                 \"rate\": float | str (as would be passed to request-rate),\n"
          "                 \"time\": float (number of seconds for this step)\n"
          "                 \"max_num_prompts\": int (maximum number of prompts for this step)"
          "             },\n"
          "             ...\n"
          "         ]\n"
          "     }\n\n"
          " Example JSON:\n"
          "     '{\"time_between_steps\": 1.0, \"rates\": [{\"rate\": 2.0, \"time\": 0.0}, {\"rate\": \"1+0.5*t\", \"time\": 5.0}]}'\n\n"
          " Each entry should have a 'rate' and/or 'num_prompts' and 'time' value."
          " Each rate is finished when \"num_prompts\" prompts are sent"
          " (if specified) and \"time\" seconds have passed (if specified),"
          " whichever comes last"
      ),
  )

  parser.add_argument("--seed", type=int, default=int(time.time()))
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
    "--save-aggregated-result",
    action="store_true",
    help="Whether to aggregate results of all models and save the result.",
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
  input_metavalidation(cmd_args)
  asyncio.run(main(cmd_args))