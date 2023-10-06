"""HTTP Server to interact with SAX Cluster, SAX Admin Server, and SAX Model Server."""

import http.server
import json
import sax

class Server(http.server.BaseHTTPRequestHandler):
  """Handler for HTTP Server."""

  invalid_res = {
    'message': "Invalid Request"
  }
  get_dict = {"/", "/listcell"}
  post_dict = {"/publish", "/unpublish", "/generate"}
  put_dict = {"/update"}

  def success_res(self, res):
    self.send_response(200)
    self.end_headers()
    self.wfile.write(json.dumps(res, indent=4).encode('utf-8'))
    self.wfile.write('\n'.encode('utf-8'))
    return

  def error_res(self, e):
    self.send_response(400)
    self.end_headers()
    error = {'Error': str(e)}
    self.wfile.write(json.dumps(error, indent=4).encode('utf-8'))
    self.wfile.write('\n'.encode('utf-8'))
    return
    
  def do_GET(self):
    """Handles GET requests."""

    if self.path not in self.get_dict:
      self.send_response(400)
      self.end_headers()
      self.wfile.write(json.dumps(self.invalid_res).encode('utf-8'))
      self.wfile.write('\n'.encode('utf-8'))
      return

    if self.path == '/':
      default_res = {'message': 'HTTP Server for SAX Client'}
      self.success_res(default_res)
      return

    content_length = int(self.headers['content-length'])
    data = self.rfile.read(content_length).decode('utf-8')
    params = json.loads(data)

    if self.path == '/listcell':
      """List details about a published model."""

      if len(params) != 1:
        self.error_res("Provide model for list cell")
        return
      
      try:
        model = params['model']
        details = sax.ListDetail(model)
        details_res = {
            'model': model,
            'model_path': details.model,
            'checkpoint': details.ckpt,
            'max_replicas': details.max_replicas,
            'active_replicas': details.active_replicas,
        }
        self.success_res(details_res)

      except Exception as e:
        self.error_res(e)

  def do_POST(self):
    """Handles POST requests."""

    if self.path not in self.post_dict:
      self.send_response(400)
      self.end_headers()
      self.wfile.write(json.dumps(self.invalid_res).encode('utf-8'))
      self.wfile.write('\n'.encode('utf-8'))
      return

    content_length = int(self.headers['content-length'])
    data = self.rfile.read(content_length).decode('utf-8')
    params = json.loads(data)

    if self.path == '/publish':
      """Publishes a model."""

      if len(params) != 4:
        self.error_res("Provide model, model path, checkpoint, and replica number for publish")
        return
      
      try:
        model = params['model']
        path = params['model_path']
        ckpt = params['checkpoint']
        replicas = int(params['replicas'])
        sax.Publish(model, path, ckpt, replicas)
        publish_res = {
            'model': model,
            'path': path,
            'checkpoint': ckpt,
            'replicas': replicas,
        }
        self.success_res(publish_res)

      except Exception as e:
        self.error_res(e)

    if self.path == '/unpublish':
      """Unpublishes a model."""

      if len(params) != 1:
        self.error_res("Provide model for unpublish")
        return
      
      try:
        model = params['model']
        sax.Unpublish(model)
        unpublish_res = {
            'model': model,
        }
        self.success_res(unpublish_res)

      except Exception as e:
        self.error_res(e)

    if self.path == '/generate':
      """Generates a text input using a published language model."""

      if len(params) != 2:
        self.error_res("Provide model and query for generate")
        return
      
      try:
        model = params['model']
        query = params['query']
        sax.ListDetail(model)
        model_open = sax.Model(model)
        lm = model_open.LM()
        res = lm.Generate(query)
        generate_res = {
            'generate_response': res,
        }
        self.success_res(generate_res)

      except Exception as e:
        self.error_res(e)
  
  def do_PUT(self):
    """Handles PUT requests."""

    if self.path not in self.put_dict:
      self.send_response(400)
      self.end_headers()
      self.wfile.write(json.dumps(self.invalid_res).encode('utf-8'))
      self.wfile.write('\n'.encode('utf-8'))
      return

    content_length = int(self.headers['content-length'])
    data = self.rfile.read(content_length).decode('utf-8')
    params = json.loads(data)

    if self.path == '/update':
      """Updates a model."""

      if len(params) != 4:
        self.error_res("Provide model, model path, checkpoint, and replica number for update")
        return
      
      try:
        model = params['model']
        path = params['model_path']
        ckpt = params['checkpoint']
        replicas = int(params['replicas'])
        sax.Update(model, path, ckpt, replicas)
        update_res = {
            'model': model,
            'path': path,
            'checkpoint': ckpt,
            'replicas': replicas,
        }
        self.success_res(update_res)

      except Exception as e:
        self.error_res(e)

s = http.server.HTTPServer(('0.0.0.0', 8888), Server)
s.serve_forever()
