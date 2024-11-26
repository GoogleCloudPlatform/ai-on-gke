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

import os
import logging as log
import google.cloud.logging as logging
import traceback

from flask import Flask, render_template, request, jsonify
from langchain.chains import LLMChain
from langchain.llms import HuggingFaceTextGenInference
from langchain.prompts import PromptTemplate
from rai import dlp_filter # Google's Cloud Data Loss Prevention (DLP) API. https://cloud.google.com/security/products/dlp
from rai import nlp_filter # https://cloud.google.com/natural-language/docs/moderating-text
from cloud_sql import cloud_sql
import sqlalchemy

# Setup logging
logging_client = logging.Client()
logging_client.setup_logging()

app = Flask(__name__, static_folder='static')
app.jinja_env.trim_blocks = True
app.jinja_env.lstrip_blocks = True

# initialize parameters
INFERENCE_ENDPOINT=os.environ.get('INFERENCE_ENDPOINT', '127.0.0.1:8081')

llm = HuggingFaceTextGenInference(
    inference_server_url=f'http://{INFERENCE_ENDPOINT}/',
    max_new_tokens=512,
    top_k=10,
    top_p=0.95,
    typical_p=0.95,
    temperature=0.01,
    repetition_penalty=1.03,
)

prompt_template = """
### [INST]
Instruction: Always assist with care, respect, and truth. Respond with utmost utility yet securely.
Avoid harmful, unethical, prejudiced, or negative content.
Ensure replies promote fairness and positivity.
Here is context to help:

{context}

### QUESTION:
{user_prompt}

[/INST]
 """

# Create prompt from prompt template
prompt = PromptTemplate(
    input_variables=["context", "user_prompt"],
    template=prompt_template,
)

# Create llm chain
llm_chain = LLMChain(llm=llm, prompt=prompt)

@app.route('/get_nlp_status', methods=['GET'])
def get_nlp_status():
    nlp_enabled = nlp_filter.is_nlp_api_enabled()
    return jsonify({"nlpEnabled": nlp_enabled})

@app.route('/get_dlp_status', methods=['GET'])
def get_dlp_status():
    dlp_enabled = dlp_filter.is_dlp_api_enabled()
    return jsonify({"dlpEnabled": dlp_enabled})
@app.route('/get_inspect_templates')
def get_inspect_templates():
    return jsonify(dlp_filter.list_inspect_templates_from_parent())

@app.route('/get_deidentify_templates')
def get_deidentify_templates():
    return jsonify(dlp_filter.list_deidentify_templates_from_parent())

@app.before_request
def init_db():
    cloud_sql.init_db()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/prompt', methods=['POST'])
def handlePrompt():
    data = request.get_json()
    warnings = []

    if 'prompt' not in data:
        return 'missing required prompt', 400

    user_prompt = data['prompt']
    log.info(f"handle user prompt: {user_prompt}")

    context = ""
    try:
        context = cloud_sql.fetchContext(user_prompt)
    except Exception as err:
        error_traceback = traceback.format_exc()
        log.warn(f"Error: {err}\nTraceback:\n{error_traceback}")
        warnings.append(f"Error: {err}\nTraceback:\n{error_traceback}")

    try:
        response = llm_chain.invoke({
            "context": context,
            "user_prompt": user_prompt
        })
        if 'nlpFilterLevel' in data:
            if nlp_filter.is_content_inappropriate(response['text'], data['nlpFilterLevel']):
                response['text'] = 'The response is deemed inappropriate for display.'
                return {'response': response}
        if 'inspectTemplate' in data and 'deidentifyTemplate' in data:
            inspect_template_path = data['inspectTemplate']
            deidentify_template_path = data['deidentifyTemplate']
            if inspect_template_path != "" and deidentify_template_path != "":
                # filter the output with inspect setting. Customer can pick any category from https://cloud.google.com/dlp/docs/concepts-infotypes
                response['text'] = dlp_filter.inspect_content(inspect_template_path, deidentify_template_path, response['text'])

        if warnings:
            response['warnings'] = warnings
        log.info(f"response: {response}")
        return {'response': response}
    except Exception as err:
        log.info(f"exception from llm: {err}")
        traceback.print_exc()
        error_traceback = traceback.format_exc()
        response = jsonify({
            "warnings": warnings,
            "error": "An error occurred",
            "errorMessage": f"Error: {err}\nTraceback:\n{error_traceback}"
        })
        response.status_code = 500
        return response


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
