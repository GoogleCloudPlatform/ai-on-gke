[1mdiff --cc tutorials-and-examples/inference-servers/jetstream/http-server/Dockerfile[m
[1mindex c9c08a6,b3f1b74..0000000[m
[1m--- a/tutorials-and-examples/inference-servers/jetstream/http-server/Dockerfile[m
[1m+++ b/tutorials-and-examples/inference-servers/jetstream/http-server/Dockerfile[m
[36m@@@ -4,7 -4,7 +4,11 @@@[m
  FROM ubuntu:22.04[m
  [m
  ENV DEBIAN_FRONTEND=noninteractive[m
[32m++<<<<<<< HEAD[m
[32m +ENV JETSTREAM_VERSION=v0.2.2[m
[32m++=======[m
[32m+ ENV PYTORCH_JETSTREAM_VERSION=v0.2.2[m
[32m++>>>>>>> 5c755a6 (Fix jetstream inference servers)[m
  [m
  RUN apt -y update && apt install -y --no-install-recommends \[m
      ca-certificates \[m
[1mdiff --cc tutorials-and-examples/inference-servers/jetstream/pytorch/jetstream-pytorch-server/Dockerfile[m
[1mindex 81fcdff,d432ff5..0000000[m
[1m--- a/tutorials-and-examples/inference-servers/jetstream/pytorch/jetstream-pytorch-server/Dockerfile[m
[1m+++ b/tutorials-and-examples/inference-servers/jetstream/pytorch/jetstream-pytorch-server/Dockerfile[m
[36m@@@ -4,7 -4,8 +4,12 @@@[m
  FROM ubuntu:22.04[m
  [m
  ENV DEBIAN_FRONTEND=noninteractive[m
[32m++<<<<<<< HEAD[m
[32m +ENV PYTORCH_JETSTREAM_VERSION=jetstream-v0.2.2[m
[32m++=======[m
[32m+ ENV PYTORCH_JETSTREAM_VERSION=v0.2.2[m
[32m+ ENV JETSTREAM_VERSION=v0.2.1[m
[32m++>>>>>>> 5c755a6 (Fix jetstream inference servers)[m
  [m
  RUN apt -y update && apt install -y --no-install-recommends \[m
      ca-certificates \[m
