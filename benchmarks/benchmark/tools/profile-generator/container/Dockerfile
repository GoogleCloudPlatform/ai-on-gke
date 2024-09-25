FROM python:3.9.20-slim-bookworm as dev

RUN apt-get update -y \
    && apt-get install -y python3-pip git vim curl wget
RUN pip3 install --upgrade pip
WORKDIR /workspace

# install build and runtime dependencies
COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt

RUN pip install -U "huggingface_hub[cli]"

RUN wget https://huggingface.co/datasets/anon8231489123/ShareGPT_Vicuna_unfiltered/resolve/main/ShareGPT_V3_unfiltered_cleaned_split.json

COPY benchmark_serving.py benchmark_serving.py
COPY latency_throughput_curve.sh latency_throughput_curve.sh

RUN chmod +x latency_throughput_curve.sh
RUN chmod +x benchmark_serving.py