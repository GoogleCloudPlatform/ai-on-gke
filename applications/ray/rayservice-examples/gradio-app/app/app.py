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

import requests
import gradio as gr
import os

model_id = os.environ["MODEL_ID"]

def inference_interface(message, history, model_temperature):

  json_message = {
    "model": model_id,
    "messages": [],
    "temperature": 0.7
  }

  print("* History: " + str(history))

  system_message = {"role": "system", "content": "You are a helpful assistant."}
  json_message["messages"].append(system_message)
  json_message['temperature'] = model_temperature

  if len(history) == 0:
    # when there is no history
    print("** Before adding messages: " + str(json_message['messages']))
    new_user_message = {"role": "user", "content": message}
    json_message['messages'].append(new_user_message)
  else:
    # we have history
    print("** Before adding additional messages: " + str(json_message['messages']))
    for item in history:
      user_message = {"role": "user", "content": item[0]}
      assistant_message = {"role": "assistant", "content": item[1]}
      json_message["messages"].append(user_message)
      json_message["messages"].append(assistant_message)
    new_user_message = {"role": "user", "content": message}
    json_message["messages"].append(new_user_message)
      
  print("*** Request" + str(json_message), flush=True)
  response = requests.post(os.environ["HOST"] + os.environ["CONTEXT_PATH"], json=json_message)
  json_data = response.json()
  output = json_data["choices"][0]["message"]["content"]
  return output

with gr.Blocks() as app:
  html_text = "You are chatting with: " + model_id
  gr.HTML(value=html_text)

  model_temperature = gr.Slider(minimum=0.1, maximum=1.0, value=0.7, label="Temperature", render=False)
  
  gr.ChatInterface(
    inference_interface,
    additional_inputs=[
        model_temperature
    ]
  )

app.launch(server_name="0.0.0.0")
