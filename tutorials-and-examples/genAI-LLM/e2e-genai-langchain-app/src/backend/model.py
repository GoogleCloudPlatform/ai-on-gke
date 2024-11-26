# Copyright 2023 Google LLC
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

import ray
from ray import serve
import logging
import os

from langchain.prompts import PromptTemplate
from langchain.chains import LLMChain
from langchain.llms import OpenAI, HuggingFacePipeline
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM, AutoConfig, pipeline

# Logging configuration
logging.basicConfig(level=logging.INFO)

# Configurations (consider using environment variables or a dedicated config module)
MODEL_ID = os.environ.get('MODEL_ID', 'google/flan-t5-small')
RAY_ADDRESS = os.environ.get('RAY_ADDRESS', 'ray://ray-cluster-kuberay-head-svc:10001')

def create_chains(llm):
    template1 = "Give me a fact about {topic}."
    template2 = "Translate to french: {fact}"

    # Create the prompts
    prompt = PromptTemplate(input_variables=["topic"], template=template1)
    second_prompt = PromptTemplate(input_variables=["fact"], template=template2)
    
    # Create and combine chains
    fact_chain = LLMChain(llm=llm, prompt=prompt)
    translate_chain = LLMChain(llm=llm, prompt=second_prompt)
    return fact_chain, translate_chain

def init_model():
    logging.info("Initializing the model...")
    config = AutoConfig.from_pretrained(MODEL_ID)
    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_ID, config=config)
    _pipeline = pipeline('text2text-generation', model=model, tokenizer=tokenizer, max_length=512)
    llm = HuggingFacePipeline(pipeline=_pipeline)
    return create_chains(llm)

fact_chain, translate_chain = init_model()

@serve.deployment
class DeployLLM:
    def __init__(self):
        self.fact_chain = fact_chain
        self.translate_chain = translate_chain

    def _run_chain(self, text: str):
        fact = self.fact_chain.run(text)
        translation = self.translate_chain.run(fact)
        return fact, translation

    async def __call__(self, request):
        # 1. Parse the request
        text = request.query_params["text"]
        # 2. Run the chain
        fact, translation = self._run_chain(text)
        # 3. Return the response
        return [fact, translation]

def init_ray_and_deploy():
    logging.info("Initializing Ray and deploying the model...")
    ray.init(
        address=RAY_ADDRESS,
        runtime_env={
            "pip": [
                "transformers>=4.26.0",
                "langchain",
                "requests",
                "torch"
                ]
        }
    )
    deployment = DeployLLM.bind()
    serve.run(deployment, host="0.0.0.0")
