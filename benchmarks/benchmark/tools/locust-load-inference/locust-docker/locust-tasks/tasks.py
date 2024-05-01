#!/usr/bin/env python

# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import json
import logging
import os
import random
import threading
import time
from locust import web  # Import the web module from Locust
from typing import Callable, List
from locust import FastHttpUser, task, events, User
from locust.runners import MasterRunner
from transformers import AutoTokenizer, PreTrainedTokenizerBase

from locust.exception import LocustError
from jetstream.core.proto import jetstream_pb2
from jetstream.core.proto import jetstream_pb2_grpc
from typing import Any, Callable
import grpc
import grpc.experimental.gevent as grpc_gevent
from grpc_interceptor import ClientInterceptor


from custom_metric_aggregator import TokenMetricCollector
local_metric_collector = TokenMetricCollector()

logging.basicConfig(level=logging.INFO)
grpc_gevent.init_gevent()

def load_test_prompts():
    """Loads test prompts from a local file location."""
    with open("locust-tasks/filtered_prompts.txt") as f:
        test_data = [line.rstrip() for line in f]
    return test_data


def generate_request(prompt):
    """Generates request for given model server"""
    global model_params
    backend = model_params["backend"]
    best_of = model_params["best_of"]
    output_len = model_params["max_output_len"]
    use_beam_search = model_params["use_beam_search"]
    sax_model = model_params["sax_model"]

    if backend == "vllm":
        pload = {
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
        params = {
            "best_of": best_of,
            "max_new_tokens": output_len,
            "do_sample": True,
        }
        pload = {
            "inputs": prompt,
            "parameters": params,
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
    return pload


def get_token_count(prompt, resp):
    """Get number of tokens to prompt and resp using the tokenizer"""
    global tokenizer
    backend = model_params["backend"]

    number_of_input_tokens = len(tokenizer.encode(prompt))
    number_of_output_tokens = 0

    if backend == "vllm":
        resp_dict = json.loads(resp.content.decode('utf-8'))
        total_tokens = len(
            tokenizer.encode(resp_dict["text"][0]))
        number_of_output_tokens = total_tokens - number_of_input_tokens
    elif backend == "tgi":
        resp_dict = json.loads(resp.content.decode('utf-8'))
        number_of_output_tokens = len(
            tokenizer.encode(resp_dict['generated_text']))
    elif backend == "tensorrt_llm_triton":
        resp_dict = json.loads(resp.content.decode('utf-8'))
        number_of_output_tokens = len(
            tokenizer.encode(resp_dict['text_output']))
    elif backend == "sax":
        number_of_output_tokens = 0  # to be added
    else:
        raise ValueError(f"Unknown backend: {backend}")
    return number_of_input_tokens, number_of_output_tokens


class BenchmarkUser(FastHttpUser):
    weight = 1
    # Connection_timeout and network_timeout default is 60s. For inferencing workloads with
    # a large payload this timeout can be too short. Increasing timeouts to large amount.
    # TODO: turn timeout into a variable.
    connection_timeout = 10800
    network_timeout = 10800

    @task
    def lm_generate(self):
        global test_data
        global model_params
        global tokenizer

        if not test_data:
            logging.error("No test data configured.")
            logging.error("Stopping the runner")
            self.environment.runner.stop()
            return

        prompt = test_data[random.randrange(0, len(test_data))]

        request = generate_request(prompt)
        headers = {"User-Agent": "Benchmark Client", "Connection": "close"}
        logging.info(f"Sending request: {request}")
        test_start_time = time.time()
        with self.client.post("/generate", headers=headers, json=request, catch_response=True) as resp:
            if resp.status_code == 200:
                self.handle_successful_response(prompt, resp, test_start_time)
            else:
                if resp.status_code == 0:
                    logging.error(
                        f"Failed request with invalid response code: {resp.status_code}. Due to requests.RequestException thrown by Session, caused by connection errors, timeouts or similar. Try increasing connection_timeout")
                self.handle_failed_response(request, resp)

def handle_successful_response(prompt, reponse, start_time):
    global model_params
    test_time = time.time() - start_time
    request_successful_bool = 1
    tokens_sent, tokens_received = get_token_count(prompt, reponse)

    send_metrics(tokens_sent, tokens_received, test_time, request_successful_bool)

def handle_failed_response(request, response):
    global model_params
    response.failure("Got unexpected response")
    logging.error(f"request {request} failed with: {response.status_code}")
    tokens_sent = -1
    tokens_received = -1
    test_time = -1
    request_successful_bool = 0

    send_metrics(tokens_sent, tokens_received, test_time, request_successful_bool)

def send_metrics( tokens_sent, tokens_received, test_time, request_successful_bool):
    local_metric_collector.add_metric(
        tokens_sent, tokens_received, test_time, request_successful_bool)
    logging.info(
        f'sending to master: metric_update: {[tokens_sent, tokens_received, test_time, request_successful_bool]}')

@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """on test stop the locust master resets metric collector"""
    if isinstance(environment.runner, MasterRunner):
        logging.info(f'dumping metrics before clear: {local_metric_collector.json_dump_report()}')
        logging.info(f'init metric_collector')
        local_metric_collector.__init__()


"""
Methods for collecting custom metrics to share to master web ui
"""

@events.report_to_master.add_listener
def on_report_to_master(client_id, data):
    """
    This event is triggered on the worker instances every time a stats report is
    to be sent to the locust master. It will allow us to add our local workers metrics
    to the dict that is being sent, and then we clear the local stats in the worker, so
    as to avoid sending duplicate data to the master on the next run.
    """
    tokens_sent, tokens_recieved, test_time, success_count, failure_count = local_metric_collector.share_stats()
    data["tokens-sent"] = tokens_sent
    data["tokens-received"] = tokens_recieved
    data["test-time"] = test_time
    data["success-count"] = success_count
    data["failure-count"] = failure_count
    local_metric_collector.__init__


@events.worker_report.add_listener
def on_worker_report(client_id, data):
    """
    This event is triggered on the master instance when a new stats report arrives
    from a worker. Here we just add the local stats to the master's aggregated
    stats dict.
    """
    local_metric_collector.add_metrics(
        data["tokens-sent"], data["tokens-received"], data["test-time"], data["success-count"], data["failure-count"])


@events.init_command_line_parser.add_listener
def _(parser):
    parser.add_argument("--backend", type=str, required=True, env_var="BACKEND",
                        include_in_web_ui=True, default="",  help="Backend Model Server")
    parser.add_argument("--best_of", type=int, env_var="BEST_OF",
                        include_in_web_ui=True, default=1,  help="Generates `best_of` sequences per prompt and returns the best one.")
    parser.add_argument("--max_output_len", type=int, env_var="MAX_OUTPUT_LEN",
                        include_in_web_ui=True, default=1024,  help="Maximum number of output tokens. Used as max tokens for generate request.")
    parser.add_argument("--sax_model", type=str, env_var="SAX_MODEL",
                        include_in_web_ui=True, default="",  help="Required for sax backend. Used only for sax backend. Model name to send request to at API server for SAX model server.")
    parser.add_argument("--use_beam_search", action="store_true", env_var="USE_BEAM_SEARCH",
                        include_in_web_ui=True, help="Whether to use beam search instead of sampling.")
    parser.add_argument("--tokenizer", type=str, env_var="TOKENIZER",
                        include_in_web_ui=False, default="", help="Tokenizer to use for token calculations")

@events.init.add_listener
def _(environment, **kwargs):
    if not isinstance(environment.runner, MasterRunner):
        global model_params
        global test_data
        global local_metric_collector
        global tokenizer

        tokenizer = AutoTokenizer.from_pretrained(
            environment.parsed_options.tokenizer)

        logging.info(
            "Loading test prompts from locust-tasks/filtered_prompts.txt.")
        test_data = []
        try:
            test_data = load_test_prompts()
        except Exception as e:
            logging.error(f"Failed to load test data: {e}")
        logging.info(f"Loaded {len(test_data)} test prompts.")

        model_params = {
            "backend": environment.parsed_options.backend,
            "best_of": environment.parsed_options.best_of,
            "max_output_len": environment.parsed_options.max_output_len,
            "sax_model": environment.parsed_options.sax_model,
            "use_beam_search": environment.parsed_options.use_beam_search,
            "tokenizer": environment.parsed_options.tokenizer,
        }
        logging.info(
            f"Using the following benchmark parameters:\n {model_params}")


@events.init.add_listener
def locust_init(environment, **kwargs):
    """
    We need somewhere to store the stats 

    On the master node the metric_collector will contain the aggregated sum of all content-lengths,
    while on the worker nodes this will be the sum of the content-lengths since the
    last stats report was sent to the master
    """
    if environment.web_ui:
        # this code is only run on the master node (the web_ui instance doesn't exist on workers)
        @environment.web_ui.app.route("/stats/custom_metrics")
        def total_content_length():
            """
            Add a route to the Locust web app, where we can see the total content-length
            """
            return local_metric_collector.json_dump_report()

class GrpcUser(User):
    abstract = True
    stub_class = None

    def __init__(self, environment):
        super().__init__(environment)
        for attr_value, attr_name in ((self.host, "host"), (self.stub_class, "stub_class")):
            if attr_value is None:
                raise LocustError(f"You must specify the {attr_name}.")

        self._channel = grpc.insecure_channel(self.host)
        interceptor = LocustInterceptor(environment=environment)
        self._channel = grpc.intercept_channel(self._channel, interceptor)

        self.stub = self.stub_class(self._channel)

class GrpcBenchmarkUser(GrpcUser):
    stub_class = jetstream_pb2_grpc.OrchestratorStub

    @task
    def grpc_infer(self):
        prompt = test_data[random.randrange(0, len(test_data))]
        request = jetstream_pb2.DecodeRequest(
            additional_text=prompt,
            priority=0,
            max_tokens=model_params["max_output_len"],
        )
        logging.info(f"Prompt: {prompt}")
        #return values format is from the interceptor, which makes the actual call
        output, ttft, response_time = self.stub.Decode(request)
        logging.info(f"Response: {output}")

        number_of_input_tokens = len(tokenizer.encode(prompt))
        number_of_output_tokens = len(tokenizer.encode(output))
        send_metrics(number_of_input_tokens, number_of_output_tokens, response_time,1)


class LocustInterceptor(ClientInterceptor):
    def __init__(self, environment, *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.env = environment

    def intercept(
        self,
        method: Callable,
        request_or_iterator: Any,
        call_details: grpc.ClientCallDetails,
    ):
        response = None
        exception = None
        start_perf_counter = time.perf_counter()
        response_length = 0
        responses = method(request_or_iterator, call_details)
        output = ""
        response_length = 0
        ttft = 0
        # Response is streamed and iterated over as it is received. The first
        # chunk sent back is used to calculate time to first token(TTFT).
        for response in responses:
            if ttft == 0:
                ttft = time.perf_counter() - start_perf_counter
            output += response.response[0]
            response_length += response.ByteSize()  
        response_time_ms = (time.perf_counter() - start_perf_counter) * 1000
        logging.info(f"response_time {response_time_ms}; ttft:{ttft * 1000}")
        self.env.events.request.fire(
            request_type="grpc",
            name=call_details.method,
            response_time=response_time_ms,
            response_length=response_length,
            response=response,
            context=None,
            exception=exception,
        )
        return output, ttft, response_time_ms
