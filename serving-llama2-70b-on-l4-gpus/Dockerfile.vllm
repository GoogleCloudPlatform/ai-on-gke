FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04
ENV PORT=8080
ENV MODEL=/gcs-mount/llama-2-70b-chat
RUN apt-get update && \
    apt-get -y --no-install-recommends install python3 python3-pip git && \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir vllm

ENV PYTHONUNBUFFERED 1
CMD python3 -m vllm.entrypoints.api_server --host 0.0.0.0 --port $PORT --model "$MODEL" --tensor-parallel-size 8


