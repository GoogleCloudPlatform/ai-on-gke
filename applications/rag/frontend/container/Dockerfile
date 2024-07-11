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

FROM python:3.12.2

ENV DEBIAN_FRONTEND=noninteractive 

RUN curl https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz > /tmp/google-cloud-sdk.tar.gz

RUN mkdir -p /usr/local/gcloud \
    && tar -C /usr/local/gcloud -xvf /tmp/google-cloud-sdk.tar.gz \
    && /usr/local/gcloud/google-cloud-sdk/install.sh

ENV PATH $PATH:/usr/local/gcloud/google-cloud-sdk/bin

ADD ./ /workspace/frontend
WORKDIR /workspace/frontend

RUN pip install -r requirements.txt


COPY ./service-account.json /app/

ENV GOOGLE_APPLICATION_CREDENTIALS=/app/service-account.json

RUN gcloud auth activate-service-account --key-file=/app/service-account.json 

ENV PORT=8080
EXPOSE $PORT

ENV FLASK_APP=/workspace/frontend/main.py

# Run the application with Gunicorn
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:$PORT", "main:app"]
