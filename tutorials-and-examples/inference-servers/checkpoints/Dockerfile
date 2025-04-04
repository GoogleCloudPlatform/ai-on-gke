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

# Ubuntu:22.04
# Use Ubuntu 22.04 from Docker Hub.
# https://hub.docker.com/_/ubuntu/tags?page=1&name=22.04
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt -y update && apt install -y --no-install-recommends \
    ca-certificates \
    git \
    python3.10 \
    python3-pip \
    curl \
    gnupg

RUN python3 -m pip install --upgrade pip

RUN update-alternatives --install \
    /usr/bin/python3 python3 /usr/bin/python3.10 1

RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN apt -y update && apt install -y google-cloud-cli

RUN git clone https://github.com/AI-Hypercomputer/maxtext.git && \
cd /maxtext && \
bash setup.sh

RUN pip install kaggle && \
pip install huggingface_hub[cli] && \
pip install google-jetstream && \
pip install llama-stack && \
pip install torch && \
pip install grain-nightly==0.0.10

COPY checkpoint_converter.sh /usr/bin/
RUN chmod +x /usr/bin/checkpoint_converter.sh
ENTRYPOINT ["/usr/bin/checkpoint_converter.sh"]