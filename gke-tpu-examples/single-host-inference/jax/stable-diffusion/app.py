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

# Use flask to download a file from the serving model.
from flask import Flask, request, send_file
from stable_diffusion_request import send_request
import os

app = Flask(__name__)

@app.route('/', methods=['GET'])
def index():
    html = """
    <!DOCTYPE html>
    <html>
    <head>
    <title>Prompt Form</title>
    </head>
    <body>
    <form action="/" method="POST">
      <label for="html">Prompt:</label>
      <input type="text" size="50" name="prompt"
             value="A photo of an astronaut riding a horse."></br>
      <input type="submit" value="Submit">
    </form>
    </body>
    </html>
    """
    return html

@app.route('/', methods=['POST'])
def get_image():
    prompt = request.form['prompt']
    # Get model server IP
    ip = os.environ['EXTERNAL_IP']
    # Send requst
    send_request(ip, prompt)
    # Get the file name from the request.
    filename = "../../stable_diffusion_images.jpg"

    # Serve the generated file.
    return send_file(filename, mimetype="image/jpeg")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
