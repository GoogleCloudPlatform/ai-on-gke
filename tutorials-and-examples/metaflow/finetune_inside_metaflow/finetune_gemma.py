# Copyright 2025 Google LLC
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

from metaflow import FlowSpec, step, kubernetes, retry, environment

import constants

class FinetuneFlow(FlowSpec):

    # specify environment variables required by the finetune process
    @environment(
        vars={
            # model to finetune
            "MODEL_NAME": "google/gemma-2-9b",
            "LORA_R": "8",
            "LORA_ALPHA": "16",
            "TRAIN_BATCH_SIZE": "1",
            "EVAL_BATCH_SIZE": "2",
            "GRADIENT_ACCUMULATION_STEPS": "2",
            "DATASET_LIMIT": "1000",
            "MAX_SEQ_LENGTH": "512",
            "LOGGING_STEPS": "5",
        }
    )

    # specify kubernetes-specific options
    @kubernetes(
        image=constants.FINETUNE_IMAGE_NAME,
        image_pull_policy="Always",
        cpu=2,
        memory=4096,
        # secret to huggingfase that has to be added as a Kubernetes secret
        secrets=["hf-token"],
        # specify required GPU settings
        gpu=2,
        node_selector={"cloud.google.com/gke-accelerator": "nvidia-l4"},
    )
    @retry
    @step
    def start(self):
        print("Start finetuning")
        import finetune

        finetune.finetune_and_upload_to_hf(
            new_model="finetunned-gemma2-9b"
        )
        self.next(self.end)

    @step
    def end(self):
        print("FinetuneFlow is finished.")


if __name__ == "__main__":
    FinetuneFlow()
