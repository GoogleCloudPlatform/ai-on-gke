FROM us-central1-docker.pkg.dev/tpu-pytorch-releases/docker/xla:nightly_3.10_tpuvm_20240229

RUN pip install -U git+https://github.com/huggingface/transformers.git
RUN pip install -U git+https://github.com/huggingface/trl.git
RUN pip install -U datasets peft

COPY . .

CMD python fsdp.py
