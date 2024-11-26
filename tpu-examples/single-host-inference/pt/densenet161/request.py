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

import argparse
import logging
import urllib.request
import requests


def send_request(host):
  image_url = "https://raw.githubusercontent.com/pytorch/serve/master/docs/images/kitten_small.jpg"
  endpoint = f"http://{host}:8080/predictions/Densenet161"

  # Download the image from the URL
  logging.info(f'Download the kitten image from "{image_url}".')
  with urllib.request.urlopen(image_url) as url:
    image_bytes = url.read()

  # Send the POST request
  logging.info("Send the request to the model server.")
  response = requests.post(
      url=endpoint,
      data=image_bytes,
      headers={"Content-Type": "application/octet-stream"},
  )

  # Check the response
  if response.status_code == 200:
    logging.info("Request successful. Response: %s", response.json())
  else:
    logging.error("Request failed. Status Code: %s", response.status_code)


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
          "Test Request: Send image to PyTorch Serve Densenet161 Service on GKE"
          " for prediction"
      )
  )
  parser.add_argument(
      "--host",
      type=str,
      required=True,
      help=(
          "The host of PyTorch Serve Densenet161 Service on GKE (External IP of"
          " the GKE Service)"
      ),
  )

  args = parser.parse_args()
  send_request(args.host)
