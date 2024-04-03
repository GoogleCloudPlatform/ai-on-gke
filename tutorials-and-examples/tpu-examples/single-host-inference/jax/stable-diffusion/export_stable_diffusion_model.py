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
import os
import subprocess

from diffusers import FlaxStableDiffusionPipeline
import jax
from jax.experimental import jax2tf
import tensorflow as tf
from tensorflow_serving.apis import predict_pb2
from tensorflow_serving.apis import prediction_log_pb2


def export_stable_diffusion():
  # The Stable Diffusion implementation is from Stability AI
  # [blog](https://huggingface.co/CompVis/stable-diffusion-v1-4).
  pipeline, params = FlaxStableDiffusionPipeline.from_pretrained(
      "CompVis/stable-diffusion-v1-4", revision="bf16", dtype=jax.numpy.bfloat16
  )
  _TOKEN_LEN = pipeline.tokenizer.model_max_length
  logging.info("Use jax2tf to convert the Flax model.")

  # Converter the Jax model to TF2 model
  def predict_fn(params, prompt_ids):
    return pipeline._generate(
        prompt_ids=prompt_ids,
        params=params,
        # Default values:
        # `https://github.com/huggingface/diffusers/blob/v0.8.0/src/diffusers/
        # `pipelines/stable_diffusion/pipeline_flax_stable_diffusion.py#L246`.
        prng_seed=jax.random.PRNGKey(0),
        num_inference_steps=50,
        height=512,
        width=512,
        guidance_scale=7.5,
    )

  params_flat, params_tree = jax.tree_util.tree_flatten(params)
  params_vars_flat = tuple(tf.Variable(p) for p in params_flat)
  params_vars = jax.tree_util.tree_unflatten(params_tree, params_vars_flat)
  tf_predict = tf.function(
      lambda prompt_ids: jax2tf.convert(
          predict_fn, enable_xla=True, with_gradient=False, native_serialization_platforms=['tpu']
      )(params_vars, prompt_ids),
      input_signature=[
          tf.TensorSpec(
              shape=(1, _TOKEN_LEN), dtype=tf.int32, name="prompt_ids"
          ),
      ],
      autograph=False,
  )
  tf_model = tf.Module()
  tf_model.tf_predict = tf_predict
  tf_model._variables = params_vars_flat
  # Save the TF model.
  logging.info("Save the TF model.")
  _CPU_MODEL_PATH = "/tmp/jax/stable_diffusion_cpu/1"
  _TPU_MODEL_PATH = "/tmp/jax/stable_diffusion_tpu/1"
  tf.io.gfile.makedirs(_CPU_MODEL_PATH)
  tf.io.gfile.makedirs(_TPU_MODEL_PATH)
  tf.saved_model.save(
      obj=tf_model,
      export_dir=_CPU_MODEL_PATH,
      signatures={
          "serving_default": tf_model.tf_predict.get_concrete_function()
      },
      options=tf.saved_model.SaveOptions(
          function_aliases={"tpu_func": tf_model.tf_predict}
      ),
  )
  # Save a warmup request.
  prompt = "Labrador in the style of Hokusai"
  prompt_ids = pipeline.prepare_inputs(prompt)
  tf_inputs = dict()
  tf_inputs["prompt_ids"] = tf.constant(prompt_ids, dtype=tf.int32)
  _EXTRA_ASSETS_DIR = "assets.extra"
  _WARMUP_REQ_FILE = "tf_serving_warmup_requests"
  assets_dir = os.path.join(_CPU_MODEL_PATH, _EXTRA_ASSETS_DIR)
  tf.io.gfile.makedirs(assets_dir)
  with tf.io.TFRecordWriter(
      os.path.join(assets_dir, _WARMUP_REQ_FILE)
  ) as writer:
    request = predict_pb2.PredictRequest()
    for key, val in tf_inputs.items():
      request.inputs[key].MergeFrom(tf.make_tensor_proto(val))
    log = prediction_log_pb2.PredictionLog(
        predict_log=prediction_log_pb2.PredictLog(request=request)
    )
    writer.write(log.SerializeToString())


if __name__ == "__main__":
  os.environ["TOKENIZERS_PARALLELISM"] = "false"
  logging.basicConfig(
      format=(
          "%(asctime)s.%(msecs)03d %(levelname)-8s [%(pathname)s:%(lineno)d]"
          " %(message)s"
      ),
      level=logging.INFO,
      datefmt="%Y-%m-%d %H:%M:%S",
  )
  export_stable_diffusion()
