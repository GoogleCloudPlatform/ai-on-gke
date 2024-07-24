FROM pytorch/pytorch:2.3.1-cuda12.1-cudnn8-devel

RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

COPY fine_tune.py \
    fsdp_config.yaml \
    requirements.txt \
    logging.conf \
    /workspace/

RUN pip3 install --no-cache-dir -r requirements.txt
RUN CUDA_HOME=/usr/local/cuda-12.1 pip3 install --no-cache-dir flash-attn --no-build-isolation
