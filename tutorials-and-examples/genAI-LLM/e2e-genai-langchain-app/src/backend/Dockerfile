FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Copy requirements
COPY requirements.txt requirements.txt

# Install dependencies
RUN pip install --require-hashes --no-cache-dir -r requirements.txt

# Copy all files
COPY . .

# Expose port for Flask
EXPOSE 5000

# Run main.py
CMD ["python", "main.py"]
