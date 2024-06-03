FROM python:3.10.14-slim-bullseye as build-stage

ENV PATH=/venv/bin:${PATH}
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get -y update \
    && pip install --upgrade pip \
    && python -m venv /venv

COPY requirements.txt /venv/requirements.txt

RUN pip install --no-cache-dir -r /venv/requirements.txt

COPY logging.conf /app/logging.conf
COPY preprocessing.py /app/preprocessing.py

WORKDIR /app

CMD python preprocessing.py
