from flask import Flask, request, jsonify
import threading
import queue
import requests
import time
import os
import logging  # Import the logging module

from swagger_client.rest import ApiException
import swagger_client as Agones


app = Flask(__name__)

# create an instance of the API class
PORT=os.environ.get("AGONES_SDK_HTTP_PORT","9358")
conf = Agones.Configuration()
conf.host = "http://localhost:"+PORT

logging.basicConfig(level=logging.DEBUG)  # Set to logging.INFO for less verbose logs
logger = logging.getLogger(__name__)  # Get a logger for your application

logger.debug('gameserver started')
logger.debug('Agones SDK port: %s', PORT)

body = Agones.SdkEmpty() # SdkEmpty
agones = Agones.SDKApi(Agones.ApiClient(conf))
agones.health(body)

# Retry connection to Agones SDK for 5 times if it fails
retry = 5
while retry != 0:
    try:
        retry = retry - 1
        api_response = agones.ready(body)
        logger.debug('health check reponse: %s', api_response)
        break
    except:
        time.sleep(2)
        logger.debug('retry connection')

def agones_health():
    while True:
        try:
            api_response = agones.health(body)
            logger.debug('health check reponse: %s', api_response)
            time.sleep(2)
        except ApiException as exc:
            logger.error('health check failed: %s', exc)

health_thread = threading.Thread(target=agones_health)
health_thread.start()

# Create a thread-safe queue
task_queue = queue.Queue()

def worker(queue):
    """Worker function to process tasks from the queue."""
    while True:
        try:
            endpoint, data, headers = task_queue.get()
            # Simulate processing time
            time.sleep(1) 

            # Call the backend API to process the update
            try:
                backend_url = f"http://lexitrail-backend-service.backend/{endpoint}"
                print(f" Processing update: {data} to {backend_url} with headers: {headers}")
                response = requests.put(backend_url, json=data, headers=headers)
                response.raise_for_status()
                print(f" Processed update: {data} to {backend_url} with headers: {headers}, response: {response.json()}")
            except requests.exceptions.RequestException as e:
                print(f" Error processing update: {e}")
                # Re-add the task to the queue for retry
                task_queue.put((endpoint, data, headers))
                time.sleep(5)

            queue.task_done()
        except queue.Empty:
            pass  # Handle empty queue

@app.route('/update/<path:endpoint>', methods=['POST', 'OPTIONS'])
def queue_update(endpoint):
    print(f" begin processing request: {endpoint}")
    if request.method == 'OPTIONS':
        # Handle OPTIONS request (CORS preflight)
        print(f" begin OPTIONS request: {endpoint}")
        response = jsonify({'message': 'Preflight request successful'})
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', '*')
        response.headers.add('Access-Control-Allow-Methods', '*')
        return response
    elif request.method == 'POST':
        data = request.get_json()
        headers = dict(request.headers)
        print(f" begin POST request: {endpoint} {data} {headers}")
        task_queue.put((endpoint, data, headers))  # Add the task to the queue
        response = jsonify({'message': 'Update request received and queued'})  
        response.headers.add('Access-Control-Allow-Origin', '*') 
        response.status_code = 202
        return response

if __name__ == '__main__':
    # Start the worker thread
    num_workers = 4

    for i in range(num_workers):
        worker_thread = threading.Thread(target=worker, args=(task_queue,), daemon=True)
        worker_thread.start()
    
    app.run(debug=True, host='0.0.0.0', port=7101)