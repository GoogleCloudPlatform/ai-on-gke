
FROM python:3.11-slim
WORKDIR /app
RUN apt-get -y update
RUN apt-get -y install git
COPY requirements.txt ./
RUN python -m pip install --upgrade pip
RUN pip install -U "jax[tpu]" -f https://storage.googleapis.com/jax-releases/libtpu_releases.html
RUN pip install -r requirements.txt
RUN pip install git+https://github.com/google/maxdiffusion.git
COPY main.py ./
EXPOSE 8000
#CMD ["gunicorn", "--bind", ":8000", "--workers", "1", "main:app","--timeout","600"]
#CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
ENTRYPOINT ["python", "main.py"]