# Ubuntu:22.04
# Use Ubuntu 22.04 from Docker Hub.
# https://hub.docker.com/_/ubuntu/tags?page=1&name=22.04
ARG UBUNTU_VERSION=83f0c2a8d6f266d687d55b5cb1cb2201148eb7ac449e4202d9646b9083f1cee0

FROM ubuntu@sha256:${UBUNTU_VERSION} as base_image

ENV DEBIAN_FRONTEND=noninteractive

RUN apt -y update && apt install -y --no-install-recommends \
    ca-certificates \
    git \
    python3.10 \
    python3-pip

RUN update-alternatives --install \
    /usr/bin/python3 python3 /usr/bin/python3.10 1

RUN git clone https://github.com/google/maxtext.git && \
git clone https://github.com/google/JetStream.git

RUN cd maxtext/ && \
bash setup.sh

RUN cd /JetStream && \
pip install -e .

RUN echo '#!/bin/bash\n\
cd /maxtext \n\
python3 MaxText/maxengine_server.py \
MaxText/configs/base.yml $@' \
> /usr/bin/maxengine_server_entrypoint.sh && chmod +x /usr/bin/maxengine_server_entrypoint.sh

ENTRYPOINT ["/usr/bin/maxengine_server_entrypoint.sh"]
