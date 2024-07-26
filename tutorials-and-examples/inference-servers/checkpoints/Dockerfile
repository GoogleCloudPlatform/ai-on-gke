# Ubuntu:22.04
# Use Ubuntu 22.04 from Docker Hub.
# https://hub.docker.com/_/ubuntu/tags?page=1&name=22.04
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt -y update && apt install -y --no-install-recommends \
    ca-certificates \
    git \
    python3.10 \
    python3-pip \
    curl \
    gnupg

RUN python3 -m pip install --upgrade pip

RUN update-alternatives --install \
    /usr/bin/python3 python3 /usr/bin/python3.10 1

RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN apt -y update && apt install -y google-cloud-cli

RUN pip install kaggle && \
pip install huggingface_hub[cli] && \
pip install google-jetstream

COPY checkpoint_converter.sh /usr/bin/
RUN chmod +x /usr/bin/checkpoint_converter.sh
ENTRYPOINT ["/usr/bin/checkpoint_converter.sh"]