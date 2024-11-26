# Copyright 2023 The TensorFlow Authors. All Rights Reserved.
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
# ==============================================================================
import argparse
import json
import logging
import numpy as np
import requests
from tensorflow.keras.applications.resnet50 import decode_predictions
from tensorflow.keras.applications.resnet50 import preprocess_input
from tensorflow.keras.preprocessing import image


def send_request(host):
  # Define the API endpoint
  api_endpoint = f"http://{host}:8501/v1/models/resnet:predict"

  # Image source: "https://i.imgur.com/j9xCCzn.jpeg", already downloaded to current folder
  # Load the image, resize it to ResNet's expected input size, and convert the image to an array
  img = image.load_img("./tf/resnet50/banana.jpeg", target_size=(224, 224))
  img = image.img_to_array(img)
  img = np.expand_dims(img, axis=0)

  # Preprocess the image (mean subtraction and scaling)
  preprocessed_image = preprocess_input(img)

  # Prepare the JSON payload
  payload = {"instances": preprocessed_image.tolist()}

  # Send a POST request
  logging.info("Send the request to the model server.")
  response = requests.post(api_endpoint, data=json.dumps(payload))
  logging.info("Predict completed.")

  # Convert predictions to numpy array
  predictions = np.array(response.json()["predictions"])

  # Decode the predictions
  decoded_predictions = decode_predictions(predictions, top=3)

  # Format predictions for logging
  formatted_predictions = [
      f"ImageNet ID: {pred[0]}, Label: {pred[1]}, Confidence: {pred[2]}"
      for pred in decoded_predictions[0]
  ]

  # Log the predictions
  logging.info(f"Predict result: {formatted_predictions}")


if __name__ == "__main__":
  logging.basicConfig(
      format=(
          "%(asctime)s.%(msecs)03d %(levelname)-8s [%(pathname)s:%(lineno)d]"
          " %(message)s"
      ),
      level=logging.INFO,
      datefmt="%Y-%m-%d %H:%M:%S",
  )

  parser = argparse.ArgumentParser(
      description=(
          "Test Request: Send image to TF Serve Resnet50 Service on GKE for"
          " prediction"
      )
  )
  parser.add_argument(
      "--host",
      type=str,
      required=True,
      help=(
          "The host of TF Serve Resnet50 Service on GKE (External IP of the GKE"
          " Service)"
      ),
  )

  args = parser.parse_args()
  send_request(args.host)
