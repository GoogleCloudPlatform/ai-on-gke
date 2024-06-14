FROM us-central1-docker.pkg.dev/tpu-pytorch-releases/docker/xla:nightly_3.10_tpuvm

RUN apt-get update -y

RUN apt-get install libomp5 -y
RUN pip3 install mkl mkl-include
RUN pip3 install tf-nightly tb-nightly tbp-nightly
RUN pip3 install numpy
RUN apt-get install numactl libopenblas-dev -y

RUN ln -s /usr/local/lib/libmkl_intel_ilp64.so.2 /usr/local/lib/libmkl_intel_ilp64.so.1

RUN rm -rf transformers
RUN git clone https://github.com/huggingface/transformers.git

WORKDIR transformers

RUN git checkout -q ebdb185befaa821304d461ed6aa20a17e4dc3aa2
RUN pip3 install -e .
RUN pip3 install datasets
RUN pip3 install evaluate
RUN pip3 install scikit-learn

COPY . .








