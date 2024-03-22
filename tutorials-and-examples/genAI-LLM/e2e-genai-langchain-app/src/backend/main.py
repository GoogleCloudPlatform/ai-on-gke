# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from flask import Flask, request, jsonify
from flask_cors import CORS
from model import init_ray_and_deploy
import requests
import logging

app = Flask(__name__)
CORS(app)
logging.basicConfig(level=logging.INFO)

RAY_ENDPOINT = 'http://ray-cluster-kuberay-head-svc:8000'  # Consider moving to configuration

# NOTE: this example starts a new instance of Ray.serve deployment for simplicity.
# For production, recommendation would be to move this initialization into a different component
# Different routes can use different versions of Ray
init_ray_and_deploy()

@app.route('/run', methods=['POST'])
def run_model():
    text = request.args.get('text')
    if not text:
        return jsonify({"error": "Provide 'text' as a query parameter"}), 400
    
    try:
        response = requests.post(RAY_ENDPOINT, params={'text': text})
        response.raise_for_status()
    except requests.RequestException as e:
        logging.error(f"Error communicating with Ray service: {e}")
        return jsonify({"error": "Internal server error"}), 500

    return response.json()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

