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

# Base image:

# FROM python:3.11.5
# RUN pip install -r requirements.txt

# Use base image from /applications/rag/frontend/main.tf - "rag-frontend" container.
# Remember to update the image here to the old image, and the one in "rag-frontend" to the updated image.
FROM us-central1-docker.pkg.dev/ai-on-gke/rag-on-gke/frontend@sha256:8f40b9485739fb2b2b4d77e18f101e1030abff63d4a6240c4cfbf2c333b593fc

ADD ./ /workspace/frontend
WORKDIR /workspace/frontend

CMD ["python", "main.py"]
