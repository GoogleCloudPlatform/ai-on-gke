# Copyright 2024 Google LLC
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

FROM python:3.12

ENV DEBIAN_FRONTEND=noninteractive 

RUN apt-get update && \
    apt-get install -y curl gnupg && \
    curl -fsSL curl -fsSL https://deb.nodesource.com/setup_20.x | bash -

RUN apt-get install -y nodejs

RUN curl https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz > /tmp/google-cloud-sdk.tar.gz

RUN mkdir -p /usr/local/gcloud \
    && tar -C /usr/local/gcloud -xvf /tmp/google-cloud-sdk.tar.gz \
    && /usr/local/gcloud/google-cloud-sdk/install.sh

ENV PATH $PATH:/usr/local/gcloud/google-cloud-sdk/bin

WORKDIR /workspace/frontend

RUN mkdir public

COPY ./ /workspace/frontend/build_env/

RUN cd build_env && \
    npm install && \
    npm run build && \
    cp public/production/bundle.js /workspace/frontend/public

RUN rm -r build_env/

ADD ./ /workspace/frontend

RUN pip install -r requirements.txt

EXPOSE 8080

RUN gcloud auth application-default login

CMD ["python", "main.py"]
