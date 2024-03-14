# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""HTTP Server to interact with MaxText + JetStream Server."""

import asyncio
import concurrent.futures
import json
import logging
from typing import Optional

import fastapi
import grpc
from jetstream.core.proto import jetstream_pb2
from jetstream.core.proto import jetstream_pb2_grpc
import pydantic


class GenerateRequest(pydantic.BaseModel):
  server: Optional[str] = "127.0.0.1"
  port: Optional[str] = "9000"
  session_cache: Optional[str] = ""
  prompt: Optional[str] = "AB"
  priority: Optional[int] = 0
  max_tokens: Optional[int] = 3


app = fastapi.FastAPI()
executor = concurrent.futures.ThreadPoolExecutor(max_workers=200)

channel = grpc.insecure_channel("127.0.0.1:9000")
grpc.channel_ready_future(channel).result()
stub = jetstream_pb2_grpc.OrchestratorStub(channel)


@app.get("/")
def root():
  """Root path for MaxText + Jetstream HTTP Server."""
  response = {"message": "HTTP Server for MaxText + JetStream"}
  response = fastapi.Response(
      content=json.dumps(response, indent=4), media_type="application/json"
  )
  return response


@app.post("/generate", status_code=200)
async def generate(request: GenerateRequest):
  """Generate a prompt."""
  try:
    request = jetstream_pb2.DecodeRequest(
        session_cache=request.session_cache,
        additional_text=request.prompt,
        priority=request.priority,
        max_tokens=request.max_tokens,
    )
    loop = asyncio.get_running_loop()
    response = await loop.run_in_executor(
        executor, generate_prompt, stub, request
    )
    response = {"response": response}
    response = fastapi.Response(
        content=json.dumps(response, indent=4), media_type="application/json"
    )
    return response
  except Exception as e:
    logging.exception("Exception in generate")
    raise fastapi.HTTPException(status_code=500, detail=str(e))


def generate_prompt(
    orchestrator_stub: jetstream_pb2_grpc.OrchestratorStub,
    request: jetstream_pb2.DecodeRequest,
):
  """Generate a prompt."""
  response = orchestrator_stub.Decode(request)
  output = ""
  for token_list in response:
    output += str(token_list.response[0])
  return output
