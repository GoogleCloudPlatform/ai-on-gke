FROM python:3.10-slim-buster
WORKDIR /webhook
COPY requirements.txt /webhook
COPY admission_controller.py /webhook
RUN pip install --no-cache-dir --upgrade -r /webhook/requirements.txt
CMD ["uvicorn", "admission_controller:app", "--host", "0.0.0.0", "--port", "5000","--ssl-keyfile=/certs/tls.key", "--ssl-certfile=/certs/tls.crt"]
