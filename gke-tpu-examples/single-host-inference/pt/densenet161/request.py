import requests
import urllib.request
import argparse
import logging

def send_request(host):
    image_url = "https://raw.githubusercontent.com/pytorch/serve/master/docs/images/kitten_small.jpg"
    endpoint = f"http://{host}:8080/predictions/Densenet161"

    # Download the image from the URL
    logging.info(f'Download the kitten image from "{image_url}".')
    with urllib.request.urlopen(image_url) as url:
        image_bytes = url.read()

    # Send the POST request
    logging.info("Send the request to the model server.")
    response = requests.post(
        url=endpoint,
        data=image_bytes,
        headers={'Content-Type': 'application/octet-stream'}
    )

    # Check the response
    if response.status_code == 200:
        logging.info("Request successful. Response: %s", response.json())
    else:
        logging.error("Request failed. Status Code: %s", response.status_code)

if __name__ == "__main__":
    logging.basicConfig(
        format="%(asctime)s.%(msecs)03d %(levelname)-8s [%(pathname)s:%(lineno)d] %(message)s",
        level=logging.INFO,
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    parser = argparse.ArgumentParser(description='Test Request: Send image to PyTorch Serve Densenet161 Service on GKE for prediction')
    parser.add_argument('--host', type=str, required=True, help='The host of PyTorch Serve Densenet161 Service on GKE (External IP of the GKE Service)')

    args = parser.parse_args()
    send_request(args.host)
