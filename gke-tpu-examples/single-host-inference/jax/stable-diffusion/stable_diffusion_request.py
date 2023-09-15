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
import logging
import argparse
import ipaddress

import grpc
from PIL import Image
import tensorflow as tf
from tensorflow_serving.apis import predict_pb2
from tensorflow_serving.apis import prediction_service_pb2_grpc
from transformers import AutoTokenizer

import tensorflow as tf
from transformers import AutoTokenizer

def validate_ip_address(ip_string):
  try:
    ip_object = ipaddress.ip_address(ip_string)
    print("The IP address '{ip_object}' is valid.")
  except ValueError:
    print("The IP address '{ip_string}' is not valid")

def send_request():
  logging.info("Establish the gRPC connection with the model server.")
  _PREDICTION_SERVICE_HOST = str(args.external_ip)
  _GRPC_PORT = 8500
  options = [
      ("grpc.max_send_message_length", 512 * 1024 * 1024),
      ("grpc.max_receive_message_length", 512 * 1024 * 1024),
  ]
  channel = grpc.insecure_channel(
      f"{_PREDICTION_SERVICE_HOST}:{_GRPC_PORT}", options=options
  )
  stub = prediction_service_pb2_grpc.PredictionServiceStub(channel)

  tokenizer = AutoTokenizer.from_pretrained(
      "CompVis/stable-diffusion-v1-4", subfolder="tokenizer", revision="bf16"
  )
  prompt = "Painting of a squirrel skating in New York"
  logging.info(f'The prompt is "{prompt}".')
  logging.info("Tokenize the prompt.")
  inputs = dict()
  inputs["prompt_ids"] = tokenizer(
      prompt,
      padding="max_length",
      max_length=tokenizer.model_max_length,
      truncation=True,
      return_tensors="tf",
  ).input_ids

  request = predict_pb2.PredictRequest()
  request.model_spec.name = "stable_diffusion"
  request.model_spec.signature_name = (
      tf.saved_model.DEFAULT_SERVING_SIGNATURE_DEF_KEY
  )
  for key, val in inputs.items():
    request.inputs[key].MergeFrom(tf.make_tensor_proto(val))
  logging.info("Send the request to the model server.")
  res = stub.Predict(request)
  logging.info("Predict completed.")
  outputs = {
      name: tf.io.parse_tensor(serialized.SerializeToString(), serialized.dtype)
      for name, serialized in res.outputs.items()
  }
  image = outputs["output_0"].numpy()
  image = image.reshape(image.shape[1:])
  image = (image * 255).round().astype("uint8")
  pil_image = Image.fromarray(image)
  image_file = "stable_diffusion_images.jpg"
  pil_image = pil_image.save(image_file)
  logging.info(f'The image was saved as "{image_file}"')


if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument("external_ip")
  args = parser.parse_args()

  validate_ip_address(args.external_ip)

  logging.basicConfig(
      format="%(asctime)s.%(msecs)03d %(levelname)-8s [%(pathname)s:%(lineno)d] %(message)s",
      level=logging.INFO,
      datefmt="%Y-%m-%d %H:%M:%S",
  )
  send_request()
