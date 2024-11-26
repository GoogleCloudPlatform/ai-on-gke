from flask import Flask, request, send_file
import requests
import os
from PIL import Image
from io import BytesIO

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
     
    url=os.environ['SERVER_URL']+"/generate"
    # Send requst
    data = {'prompt': prompt}
    result=requests.post(url, json = data)
    # Get the file name from the request.
    filename = "stable_diffusion_images.jpg"
    content = Image.open(BytesIO(result.content))
    content.save(filename)
    # Serve the generated file.
    return send_file(filename, mimetype="image/png")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)