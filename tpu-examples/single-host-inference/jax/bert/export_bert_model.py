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

from jax.experimental import jax2tf
import tensorflow as tf
from tensorflow_serving.apis import predict_pb2
from tensorflow_serving.apis import prediction_log_pb2
from transformers import AutoTokenizer
from transformers import FlaxBertForMaskedLM


def export_bert_base_uncased():
  _MAX_INPUT_SIZE = 64
  # The Bert implementation is based on `bert-base-uncased` HuggingFace's
  # [blog](https://huggingface.co/bert-base-uncased).
  _BERT_BASE_UNCASED = "bert-base-uncased"
  logging.info("Load Flax Bert model.")
  model = FlaxBertForMaskedLM.from_pretrained(_BERT_BASE_UNCASED)
  logging.info("Use jax2tf to convert the Flax model.")

  # Converter the Jax model to TF2 model
  def predict_fn(params, input_ids, attention_mask, token_type_ids):
    return model.__call__(
        params=params,
        input_ids=input_ids,
        attention_mask=attention_mask,
        token_type_ids=token_type_ids,
    )

  params_vars = tf.nest.map_structure(tf.Variable, model.params)
  tf_predict = tf.function(
      lambda input_ids, attention_mask, token_type_ids: jax2tf.convert(
          predict_fn,
          enable_xla=True,
          with_gradient=False,
          polymorphic_shapes=[
              None,
              f"(b, {_MAX_INPUT_SIZE})",
              f"(b, {_MAX_INPUT_SIZE})",
              f"(b, {_MAX_INPUT_SIZE})",
          ],
      )(params_vars, input_ids, attention_mask, token_type_ids),
      input_signature=[
          tf.TensorSpec(
              shape=(None, _MAX_INPUT_SIZE), dtype=tf.int32, name="input_ids"
          ),
          tf.TensorSpec(
              shape=(None, _MAX_INPUT_SIZE),
              dtype=tf.int32,
              name="attention_mask",
          ),
          tf.TensorSpec(
              shape=(None, _MAX_INPUT_SIZE),
              dtype=tf.int32,
              name="token_type_ids",
          ),
      ],
      autograph=False,
  )
  tf_model = tf.Module()
  tf_model.tf_predict = tf_predict
  tf_model._variables = tf.nest.flatten(params_vars)
  # Save the TF model.
  logging.info("Save the TF model.")
  _CPU_MODEL_PATH = "/tmp/jax/bert_cpu/1"
  _TPU_MODEL_PATH = "/tmp/jax/bert_tpu/1"
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
  _TEXT = ["Today is a [MASK] day.", "My dog is [MASK]."]
  tokenizer = AutoTokenizer.from_pretrained(
      _BERT_BASE_UNCASED, model_max_length=_MAX_INPUT_SIZE
  )
  tf_inputs = tokenizer(
      _TEXT, return_tensors="tf", padding="max_length", truncation=True
  )
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
  export_bert_base_uncased()
