# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Export Resnet50 TensorFlow model."""
import logging
import os
import subprocess

import tensorflow as tf
from tensorflow.keras.applications.resnet50 import ResNet50
from tensorflow_serving.apis import predict_pb2
from tensorflow_serving.apis import prediction_log_pb2


class ResNetModel(tf.keras.Model):
  """ResNet model for ImageNet classification."""

  def __init__(self):
    super().__init__()
    self._model = ResNet50(weights="imagenet")

  @tf.function
  def tpu_func(self, image):
    return self._model(image)

  @tf.function(
      input_signature=[
          tf.TensorSpec(shape=(None, 224, 224, 3), dtype=tf.float32)
      ]
  )
  def serve(self, image) -> tf.Tensor:
    return self.tpu_func(image)


def export_resnet():
  logging.info("Load TF ResNet-50 model.")
  resnet = ResNetModel()
  inputs = {"image": tf.random.uniform((1, 224, 224, 3), dtype=tf.float32)}
  # Save the TF model.
  logging.info("Save the TF model as Saved Model format.")
  _CPU_MODEL_PATH = "/tmp/tf/resnet_cpu/1"
  _TPU_MODEL_PATH = "/tmp/tf/resnet_tpu/1"
  tf.io.gfile.makedirs(_CPU_MODEL_PATH)
  tf.io.gfile.makedirs(_TPU_MODEL_PATH)
  tf.saved_model.save(
      obj=resnet,
      export_dir=_CPU_MODEL_PATH,
      signatures={"serving_default": resnet.serve.get_concrete_function()},
      options=tf.saved_model.SaveOptions(
          function_aliases={"tpu_func": resnet.tpu_func}
      ),
  )
  # Save a warmup request.
  inputs = {"image": tf.random.uniform((1, 224, 224, 3), dtype=tf.float32)}
  _EXTRA_ASSETS_DIR = "assets.extra"
  _WARMUP_REQ_FILE = "tf_serving_warmup_requests"
  assets_dir = os.path.join(_CPU_MODEL_PATH, _EXTRA_ASSETS_DIR)
  tf.io.gfile.makedirs(assets_dir)
  with tf.io.TFRecordWriter(
      os.path.join(assets_dir, _WARMUP_REQ_FILE)
  ) as writer:
    request = predict_pb2.PredictRequest()
    for key, val in inputs.items():
      request.inputs[key].MergeFrom(tf.make_tensor_proto(val))
    log = prediction_log_pb2.PredictionLog(
        predict_log=prediction_log_pb2.PredictLog(request=request)
    )
    writer.write(log.SerializeToString())

if __name__ == "__main__":
  logging.basicConfig(
      format="%(asctime)s.%(msecs)03d %(levelname)-8s [%(pathname)s:%(lineno)d] %(message)s",
      level=logging.INFO,
      datefmt="%Y-%m-%d %H:%M:%S",
  )

  export_resnet()
