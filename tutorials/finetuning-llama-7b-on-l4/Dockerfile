FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04

RUN apt-get update && \
    apt-get -y --no-install-recommends install python3-dev gcc python3-pip git && \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir transformers peft datasets bitsandbytes protobuf scipy einops

COPY fine-tune.py /fine-tune.py

ENV PYTHONUNBUFFERED 1

CMD python3 /fine-tune.py