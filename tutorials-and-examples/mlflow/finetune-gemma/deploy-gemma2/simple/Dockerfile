FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04

RUN apt-get update && \
    apt-get -y --no-install-recommends install python3-dev gcc python3-pip git && \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir \
    accelerate==1.1.1 bitsandbytes==0.45.0 \
    datasets==3.2.0 transformers==4.46.3 \
    peft==0.13.2 trl==0.12.2 torch==2.5.1 torchvision==0.20.1 \
    mlflow==2.19.0 google-cloud-storage==2.19.0

COPY requirements.txt /requirements.txt
RUN pip3 install -r requirements.txt

COPY main.py /main.py

ENV PYTHONUNBUFFERED 1

EXPOSE 11434

CMD ["python3", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "11434"]
