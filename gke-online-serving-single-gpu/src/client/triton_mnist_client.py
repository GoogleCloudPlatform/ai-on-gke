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

import requests
import numpy as np
from PIL import Image
import climage
import tritonclient.http as httpclient
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("-i", help="External IP address of the Triton Server")
parser.add_argument("-m", help="Name of the model")
parser.add_argument("-p", help="Image to send for inference")
args = parser.parse_args()

def img_prep(image):
    image = image.resize((28, 28))
    image = np.array(image).astype(np.float32)
    image = image.reshape(1, 28, 28, 1)
    return image

def output_post(preds):
    return np.argmax(np.squeeze(preds))

if __name__ == '__main__':

    image = Image.open(args.p)
    image = img_prep(image)
    model_name = args.m
    triton_http_url = args.i+":8000"

    # Triton HTTP call
    triton_client_http = httpclient.InferenceServerClient(url=triton_http_url)
    inputs_http = []
    outputs_http = []
    inputs_http.append(httpclient.InferInput('input_1', [1, 28, 28, 1], "FP32"))
    inputs_http[0].set_data_from_numpy(image)
    outputs_http.append(httpclient.InferRequestedOutput('output_1'))
    results_http = triton_client_http.infer(model_name, inputs_http, outputs=outputs_http)
    output_http = np.squeeze(results_http.as_numpy('output_1'))
    prediction_http = output_post(output_http)

    print(f"Calling Triton HTTP Service \t -> \t Prediction result: {prediction_http}")
