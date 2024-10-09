FROM jupyter/tensorflow-notebook:python-3.10
USER root
COPY requirements.txt ./requirements.txt
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server
# Create a virtual environment
RUN python3 -m venv /opt/venv

# Activate the virtual environment
ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --no-cache-dir -r ./requirements.txt
