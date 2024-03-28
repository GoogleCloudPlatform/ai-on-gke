FROM python:3.10-slim-bullseye as build-stage

ENV PATH=/venv/bin:${PATH}
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY requirements.txt /venv/requirements.txt
RUN pip install --no-cache-dir -r /venv/requirements.txt

COPY preprocessing.py /app/preprocessing.py

WORKDIR /app

CMD python preprocessing.py
