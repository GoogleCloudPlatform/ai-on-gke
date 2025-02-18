FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

RUN groupadd -r model && useradd -r -g model model

RUN pip install --no-cache-dir \
    torch \
    transformers \
    fastapi \
    uvicorn \
    pydantic

WORKDIR /app
COPY inference_server.py .

RUN chown -R model:model /app

USER model

EXPOSE 8000

ENV MODEL_PATH=/app/model

# Run the application
CMD ["uvicorn", "inference_server:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]