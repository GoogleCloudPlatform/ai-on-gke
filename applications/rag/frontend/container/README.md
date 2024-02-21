# Frontend Container

This directory contains the code for a frontend flask webserver integrating with the inference
backend and (NYI) vector database through [LangChain](https://python.langchain.com/docs/get_started/introduction).

The image is hosted on `us-central1-docker.pkg.dev/ai-on-gke/rag-on-gke` and used by the frontend deployment.

To build/regenerate the image, follow [these steps](https://cloud.google.com/build/docs/building/build-containers#use-dockerfile).