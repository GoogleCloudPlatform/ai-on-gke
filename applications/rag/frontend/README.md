# RAG-on-GKE Frontend Webserver

This directory contains the code for a frontend flask webserver integrating with the inference
backend and (NYI) vector database through [LangChain](https://python.langchain.com/docs/get_started/introduction).

The image is hosted on `us-central1-docker.pkg.dev/ai-on-gke/rag-on-gke` and used by the frontend deployment.

## Sensitive Data Protection
Data Loss Prevention (DLP) and Natural Language Protection (NLP) System. Our integrated solution leverages the latest in data protection and language understanding technologies to safeguard sensitive information and ensure content appropriateness across digital platforms.

### Features:

#### Data Loss Prevention (DLP): 
Identifies, monitors, and protects sensitive data through detection techniques, ensuring compliance with data protection regulations. 

#### Natural Language Proctection (NLP): 
Using  the text moderation API from Cloud Natural Language API to analyzes text for sentiment, context, and content categorization, filtering out inappropriate material based on predefined categories such as Health, Finance, Politics, and Legal.

### Pre-requirement
1. Enable Cloud Data Loss Prevention (DLP)

We have two ways to enable the api:

    1. Go to https://console.developers.google.com/apis/api/dlp.googleapis.com/overview click enable api.
    2. Run command: `gcloud services enable dlp.googleapis.com`

This filter can auto fetch the templates in your project. Please refer to the following links to create templates:

    1. Inspect templates: https://cloud.google.com/dlp/docs/creating-templates-inspect
    2. De-identification templates: https://cloud.google.com/dlp/docs/creating-templates-deid

2. Enable Cloud Nature Language Protection NLP

Follow the instruction to [enable Nature Language API](https://cloud.google.com/natural-language/docs/setup#api)

The NLP (Nature Language Protection) System uses advanced NLP technologies to filter and moderate text, excluding content related to Health, Finance, Politics, and Legal categories to ensure appropriateness.