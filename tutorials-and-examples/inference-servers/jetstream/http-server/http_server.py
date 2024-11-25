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

"""HTTP Server to interact with JetStream Server."""

import asyncio
import concurrent.futures
import json
import logging
import time
from typing import Optional
import uuid

import fastapi
from fastapi.responses import StreamingResponse
import grpc
from jetstream.core.proto import jetstream_pb2
from jetstream.core.proto import jetstream_pb2_grpc
import pydantic


class GenerateRequest(pydantic.BaseModel):
  server: Optional[str] = "127.0.0.1"
  port: Optional[str] = "9000"
  session_cache: Optional[str] = ""
  prompt: Optional[str] = "This is an example prompt"
  priority: Optional[int] = 0
  max_tokens: Optional[int] = 100
  stream: Optional[bool] = False


app = fastapi.FastAPI()
executor = concurrent.futures.ThreadPoolExecutor(max_workers=1000)

@app.get("/")
def root():
  """Root path for Jetstream HTTP Server."""
  response = {"message": "HTTP Server for JetStream"}
  response = fastapi.Response(
      content=json.dumps(response, indent=4), media_type="application/json"
  )
  return response

@app.get("/healthcheck")
async def healthcheck():
  try:
    request = jetstream_pb2.HealthCheckRequest()

    options = [("grpc.keepalive_timeout_ms", 10000)]
    async with grpc.aio.insecure_channel("127.0.0.1:9000", options=options) as channel:
      stub = jetstream_pb2_grpc.OrchestratorStub(channel)
      response = stub.HealthCheck(request)
      response = await response

      if response.is_live == False:
        raise fastapi.HTTPException(status_code=500, detail="Healthcheck failed, is_live = False")

      is_live = {"is_live": response.is_live}
      response = {"response": is_live}

      response = fastapi.Response(
          content=json.dumps(response, indent=4), media_type="application/json"
      )
      return response

  except Exception as e:
    logging.exception("Exception in healthcheck")
    logging.exception(e)
    raise fastapi.HTTPException(status_code=500, detail="Healthcheck failed")


@app.post("/generate", status_code=200)
async def generate(request: GenerateRequest):
  """Generate a prompt."""
  try:
    stream = request.stream
    request = jetstream_pb2.DecodeRequest(
        session_cache=request.session_cache,
        text_content=jetstream_pb2.DecodeRequest.TextContent(text=request.prompt),
        priority=request.priority,
        max_tokens=request.max_tokens,
    )

    if stream:
      response = StreamingResponse(generate_prompt_stream(request), media_type="application/json")
      return response

    else:
      future = executor.submit(generate_prompt, request)
      response = await future.result()
      response = {"response": response}
      response = fastapi.Response(
          content=json.dumps(response, indent=4), media_type="application/json"
      )
      return response
  except Exception as e:
    logging.exception("Exception in generate")
    raise fastapi.HTTPException(status_code=500, detail=str(e))


async def generate_prompt(
    request: jetstream_pb2.DecodeRequest,
):
  """Generate a prompt."""

  options = [("grpc.keepalive_timeout_ms", 10000)]
  async with grpc.aio.insecure_channel("127.0.0.1:9000", options=options) as channel:
    stub = jetstream_pb2_grpc.OrchestratorStub(channel)
    response = stub.Decode(request)
    output = ""
    async for r in response:
      output += str(r.stream_content.samples[0].text)
    return output

async def generate_prompt_stream(
    request: jetstream_pb2.DecodeRequest,
):
  """Generate a prompt streamed."""

  options = [("grpc.keepalive_timeout_ms", 10000)]
  async with grpc.aio.insecure_channel("127.0.0.1:9000", options=options) as channel:
    stub = jetstream_pb2_grpc.OrchestratorStub(channel)
    response = stub.Decode(request)
    async for r in response:
      request_id = "generate-" + str(uuid.uuid4().hex)
      chunk = {
        "id": request_id,
        "time_created": time.time(),
        "text": str(r.stream_content.samples[0].text)
      }
      yield json.dumps(chunk, indent=4)