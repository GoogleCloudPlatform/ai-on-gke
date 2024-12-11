# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Expose port 80 for Flask in production
EXPOSE 80

# Set environment variables
ENV FLASK_APP=run.py
ENV FLASK_ENV=production

# Run the Flask app on port 80
CMD ["flask", "run", "--host=0.0.0.0", "--port=80"]
