#syntax=docker/dockerfile:1.7-labs

# Use Alpine as the base image
FROM alpine:latest

# Copy all .safetensors files to the /model directory
COPY model/*.safetensors /model/

# Copy all other files to the /model directory, excluding .safetensors
COPY --exclude='*.safetensors' model/ /model/ 

# (No CMD or ENTRYPOINT, as per your requirement)
