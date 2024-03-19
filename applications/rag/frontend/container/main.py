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
import time
import logging as log
import google.cloud.logging as logging
import sqlalchemy
import pymysql
import traceback
import json

from flask import Flask, render_template, request, jsonify
from langchain.chains import LLMChain
from langchain.llms import HuggingFaceTextGenInference
from langchain.prompts import PromptTemplate
from rai import dlp_filter # Google's Cloud Data Loss Prevention (DLP) API. https://cloud.google.com/security/products/dlp
from rai import nlp_filter # https://cloud.google.com/natural-language/docs/moderating-text
from werkzeug.exceptions import HTTPException
from google.cloud.sql.connector import Connector
from sentence_transformers import SentenceTransformer

app = Flask(__name__, static_folder='static')
app.jinja_env.trim_blocks = True
app.jinja_env.lstrip_blocks = True

TABLE_NAME = os.environ.get('TABLE_NAME', '')  # CloudSQL table name
SENTENCE_TRANSFORMER_MODEL = 'intfloat/multilingual-e5-small' # Transformer to use for converting text chunks to vector embeddings
DB_NAME = "pgvector-database"

# initialize parameters
INFERENCE_ENDPOINT=os.environ.get('INFERENCE_ENDPOINT', '127.0.0.1:8081')
INSTANCE_CONNECTION_NAME = os.environ.get('INSTANCE_CONNECTION_NAME', '')

db_username_file = open("/etc/secret-volume/username", "r")
DB_USER = db_username_file.read()
db_username_file.close()

db_password_file = open("/etc/secret-volume/password", "r")
DB_PASS = db_password_file.read()
db_password_file.close()

db = None
filter_names = ['DlpFilter', 'WebRiskFilter']
transformer = SentenceTransformer(SENTENCE_TRANSFORMER_MODEL)
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

# helper function to return SQLAlchemy connection pool
def init_connection_pool(connector: Connector) -> sqlalchemy.engine.Engine:
    # function used to generate database connection
    def getconn() -> pymysql.connections.Connection:
        conn = connector.connect(
            INSTANCE_CONNECTION_NAME,
            "pg8000",
            user=DB_USER,
            password=DB_PASS,
            db=DB_NAME
        )
        return conn

    # create connection pool
    pool = sqlalchemy.create_engine(
        "postgresql+pg8000://",
        creator=getconn,
    )
    return pool

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
def init_db() -> sqlalchemy.engine.base.Engine:
    """Initiates connection to database and its structure."""
    global db
    connector = Connector()
    if db is None:
        db = init_connection_pool(connector)

@app.route('/')
def index():
    return render_template('index.html')

def fetchContext(query_text):
    with db.connect() as conn:
        results = conn.execute(sqlalchemy.text("SELECT * FROM " + TABLE_NAME)).fetchall()
        log.info(f"query database results:")
        for row in results:
            print(row)

        # chunkify query & fetch matches
        query_emb = transformer.encode(query_text).tolist()
        query_request = "SELECT id, text, text_embedding, 1 - ('[" + ",".join(map(str, query_emb)) + "]' <=> text_embedding) AS cosine_similarity FROM " + TABLE_NAME + " ORDER BY cosine_similarity DESC LIMIT 5;"
        query_results = conn.execute(sqlalchemy.text(query_request)).fetchall()
        conn.commit()
        log.info(f"printing matches:")
        for row in query_results:
            print(row)

    return query_results[0][1]

@app.route('/prompt', methods=['POST'])
def handlePrompt():
    logging_client = logging.Client()
    logging_client.setup_logging()
    data = request.get_json()

    if 'prompt' not in data:
        return 'missing required prompt', 400

    user_prompt = data['prompt']
    log.info(f"handle user prompt: {user_prompt}")
    context = ""

    try:
        context = fetchContext(user_prompt)
    except Exception as err:
        log.info(f"error fetching context, proceeding without: {err}")
    finally:
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
            log.info(f"response: {response}")
            return {'response': response}
        except Exception as err:
            log.info(f"exception from llm: {err}")
            traceback.print_exc()
            error_traceback = traceback.format_exc()
            response = jsonify({
                "error": "An error occurred",
                "message": f"Error: {err}\nTraceback:\n{error_traceback}"
            })
            response.status_code = 500
            return response


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
