FROM python:3.8

RUN git clone https://github.com/huggingface/diffusers.git

WORKDIR diffusers

RUN pip install "jax[tpu]" -f https://storage.googleapis.com/jax-releases/libtpu_releases.html
RUN pip install . 
RUN pip install tensorflow clu 
RUN pip install -U -r examples/text_to_image/requirements_flax.txt