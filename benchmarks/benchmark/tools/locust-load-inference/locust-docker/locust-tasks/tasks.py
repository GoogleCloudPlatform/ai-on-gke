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

import logging
import random

from locust import FastHttpUser, task, events
from locust.runners import MasterRunner


logging.basicConfig(level=logging.INFO)


def load_test_prompts():
    """Loads test prompts from a local file location."""
    with open("locust-tasks/filtered_prompts.txt") as f:
        test_data = [line.rstrip() for line in f]
    return test_data


def generate_request(model_params, prompt):
    """Generates request for given model server"""
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
            "ignore_eos": True,
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
    else:
        raise ValueError(f"Unknown backend: {backend}")
    return pload


class BenchmarkUser(FastHttpUser):
    weight = 1

    @task
    def lm_generate(self):
        global test_data
        global model_params

        if not test_data:
            logging.error("No test data configured.")
            logging.error("Stopping the runner")
            self.environment.runner.stop()
            return

        prompt = test_data[random.randrange(0, len(test_data))]

        request = generate_request(model_params, prompt)
        headers = {"User-Agent": "Benchmark Client", "Connection": "close"}
        logging.info(f"Sending request: {request}")
        with self.client.post("/generate", headers=headers, json=request, catch_response=True) as resp:
            if resp.status_code != 200:
                # Locust considers response code  < 400 as success, if not 200 mark as otherwise.
                resp.failure("Got unexpected response")
                logging.error(
                    f"request {request} failed with: {resp.status_code}")


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


@events.init.add_listener
def _(environment, **kwargs):
    if not isinstance(environment.runner, MasterRunner):
        global model_params
        global test_data

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
        }
        logging.info(
            f"Using the following benchmark parameters:\n {model_params}")
