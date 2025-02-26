FROM python:3.12-slim

WORKDIR /app/
ADD requirements.txt /app/

RUN pip install --no-cache -r requirements.txt
ADD . /app/

EXPOSE 8000

CMD ["uvicorn", "rag_demo.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
