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

"""HTTP Server to interact with SAX Cluster, SAX Admin Server, and SAX Model Server."""

from fastapi import FastAPI, HTTPException, Response
import uvicorn
import json
import logging
from concurrent.futures import ThreadPoolExecutor
import asyncio
from pydantic import BaseModel, Field
from typing import Optional, Union, List

import sax

class ExtraInputs(BaseModel):
    temperature: Optional[float] = 0.5
    per_example_max_decode_steps: Optional[int] = 128
    per_example_top_k: Optional[int] = 200
    per_example_top_p: Optional[float] = 0.95

class Generate(BaseModel):
    model: str
    query: str
    extra_inputs: Optional[ExtraInputs] = Field(default_factory=ExtraInputs)

class Model(BaseModel):
    model: str
    model_path: str
    checkpoint: str
    replicas: int

class ModelID(BaseModel):
    model: str

class SaxCell(BaseModel):
    sax_cell: str

app = FastAPI()

executor = ThreadPoolExecutor(max_workers=1000)

@app.get("/")
def root():
    response = {"message": "HTTP Server for SAX Client"}
    response = Response(
        content=json.dumps(response, indent=4), 
        media_type="application/json"
        )
    return response

@app.get("/listcell")
def listcell(request: ModelID, status_code=200):
    try:
        details = sax.ListDetail(request.model)
        response = {
            'model': request.model,
            'model_path': details.model,
            'checkpoint': details.ckpt,
            'max_replicas': details.max_replicas,
            'active_replicas': details.active_replicas,
        }
        response = Response(
            content=json.dumps(response, indent=4), 
            media_type="application/json"
            )
        return response
    except Exception as e:
        logging.exception("Exception in model listcell")
        raise HTTPException(status_code=500, detail=str(e))
        return

@app.get("/listall")
def listall(request: SaxCell,status_code=200):
    try:
        response = sax.ListAll(request.sax_cell)
        response = Response(
            content=json.dumps(response, indent=4), 
            media_type="application/json"
            )
        return response
    except Exception as e:
        logging.exception("Exception in model listall")
        raise HTTPException(status_code=500, detail=str(e))
        return

@app.post("/publish")
def publish(request: Model, status_code=200):
    try:
        model = request.model
        model_path = request.model_path
        ckpt = request.checkpoint
        replicas = request.replicas

        sax.Publish(model, model_path, ckpt, replicas)
        response = {
            'model': model,
            'model_path': model_path,
            'checkpoint': ckpt,
            'replicas': replicas,
        }
        response = Response(
            content=json.dumps(response, indent=4), 
            media_type="application/json"
            )
        return response
    except Exception as e:
        logging.exception("Exception in model publish")
        raise HTTPException(status_code=500, detail=str(e))
        return

@app.post("/unpublish")
def unpublish(request: ModelID, status_code=200):
    try:
        sax.Unpublish(request.model)
        response = {
            'model': request.model,
        }
        response = Response(
            content=json.dumps(response, indent=4), 
            media_type="application/json"
            )
        return response
    except Exception as e:
        logging.exception("Exception in model unpublish")
        raise HTTPException(status_code=500, detail=str(e))
        return

@app.post("/generate")
async def lm_generate(request: Generate, status_code=200):
    try:
        model = request.model
        query = request.query
        sax.ListDetail(model)
        model_open = sax.Model(model)
        lm = model_open.LM()

        options = None
        if request.extra_inputs:
            options = sax.ModelOptions()
            input_vars = dict(request.extra_inputs)
            for key, value in input_vars.items():
                options.SetExtraInput(key, value)

        loop = asyncio.get_running_loop()
        response = await loop.run_in_executor(
            executor, generate_prompt, lm, query, options
        )
        response = Response(
            content=json.dumps(response, indent=4), 
            media_type="application/json"
            )
        return response
    except Exception as e:
        logging.exception("Exception in lm generate")
        raise HTTPException(status_code=500, detail=str(e))
        return

def generate_prompt(lm: sax.LanguageModel, query: str, options: sax.ModelOptions):
    response = lm.Generate(query, options)
    return response

@app.put("/update")
def update(request: Model, status_code=200):
    try:
        model = request.model
        model_path = request.model_path
        ckpt = request.checkpoint
        replicas = request.replicas
        sax.Update(model, model_path, ckpt, replicas)
        response = {
            'model': model,
            'model_path': model_path,
            'checkpoint': ckpt,
            'replicas': replicas,
        }
        response = Response(
            content=json.dumps(response, indent=4), 
            media_type="application/json"
            )
        return response

    except Exception as e:
        logging.exception("Exception in model update")
        raise HTTPException(status_code=500, detail=str(e))
        return