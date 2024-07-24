FROM python:3.12.4-slim

RUN apt-get update && \
    apt-get -y --no-install-recommends install python3-dev gcc python3-pip git && \
    rm -rf /var/lib/apt/lists/*

COPY validate_fine_tuned_model.py \
    requirements.txt \
    logging.conf \
    /

RUN pip3 install --no-cache-dir -r requirements.txt

ENV PYTHONUNBUFFERED 1

CMD python3 /validate_fine_tuned_model.py
