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

import json
import requests
from PIL import Image
import numpy as np
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
    data = json.dumps({ 
        "instances": image.tolist()
    })
    headers = {"content-type": "application/json"}

    response = requests.post('http://'+args.i+':8000/v1/models/'+args.m+':predict', data=data, headers=headers)
    result = int(response.json()['predictions'][0][0])
    prediction = output_post(response.json()['predictions'][0])

    print(f"Calling TensorFlow Serve HTTP Service \t -> \t Prediction result: {prediction}")