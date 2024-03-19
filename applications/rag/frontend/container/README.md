# Frontend Container

This directory contains the code for a frontend flask webserver integrating with the inference
backend and (NYI) vector database through [LangChain](https://python.langchain.com/docs/get_started/introduction).

The images are hosted on `us-central1-docker.pkg.dev/ai-on-gke/rag-on-gke` and used by the frontend deployment.

Check the cloudbuild.yaml for how to build/regenerate the images. Remember to update the image in `/applications/rag/frontend/container/main.tf` to your new image.