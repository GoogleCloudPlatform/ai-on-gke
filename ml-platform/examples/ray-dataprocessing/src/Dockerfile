FROM python:3.10-slim-bullseye as build-stage

ENV PATH=/venv/bin:${PATH}
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY requirements.txt /venv/requirements.txt
RUN pip install --no-cache-dir -r /venv/requirements.txt && \
python -m spacy validate && \
python -m spacy download en_core_web_sm

COPY preprocessing.py /app/preprocessing.py

WORKDIR /app

CMD python preprocessing.py
