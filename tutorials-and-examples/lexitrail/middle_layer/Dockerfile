# Base Image
FROM python:3.11.5

WORKDIR /workspace/middle_layer

COPY requirements.txt /workspace/middle_layer
COPY agones /workspace/middle_layer/agones

# Install Dependencies
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install ./agones

COPY app.py /workspace/middle_layer

# Expose Port
EXPOSE 7101

# Start the Application
CMD ["python", "app.py"]
