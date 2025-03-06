# Copyright 2020 Google LLC
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
import setuptools

setuptools.setup(
    name="jupyterhub-gcp-iap-authenticator",
    python_requires='>=3.12.0',
    version="0.3.0",
    author="Aaron Liang",
    author_email="aaronliang@google.com",
    description="JupyterHub Authenticator for Cloud IAP with JWT",
    long_description="JupyterHub Authenticator for Cloud Identity-Aware Proxy with JSON Web Token",
    long_description_content_type="text/markdown",
    url="https://github.com/GoogleCloudPlatform/ai-on-gke/tree/main/modules/jupyter/authentication",
    packages=['gcpiapjwtauthenticator'],
    license='Apache 2.0',
    install_requires=[
        "jupyterhub>=5.2.1",
        "tornado>=6.4.2",
        "oauthenticator>=17.3.0",
        "pyjwt>=2.10.1",
        "google-api-python-client>=2.163.0",
        "google-auth>=2.38.0",
        "google-auth-oauthlib>=1.2.1",
        "google-cloud>=0.34.0",
    ],
)
