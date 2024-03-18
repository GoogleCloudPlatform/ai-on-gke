# RAG-on-GKE Frontend Webserver

This directory contains the code for a frontend flask webserver integrating with the inference
backend and vector database through [LangChain](https://python.langchain.com/docs/get_started/introduction).

## Sensitive Data Protection
[Data Loss Prevention (DLP)](https://cloud.google.com/security/products/dlp?hl=en) from [Sensitive Data Protection (SDP)](https://cloud.google.com/sensitive-data-protection/docs) and [Text moderation](https://cloud.google.com/natural-language/docs/moderating-text) System. Our integrated solution leverages the latest in data protection and language understanding technologies to safeguard sensitive information and ensure content appropriateness across digital platforms.

### Features:

#### Data Loss Prevention (DLP): 
Our DLP system is engineered to actively identify and safeguard sensitive information. It achieves this through advanced detection methods that redact sensitive data from both outputs and, where applicable, within the data itself. This approach prioritizes the robust protection of critical information. Please note, the current implementation of our DLP solution does not extend support for specific data protection compliance regulations. The primary objective is to ensure a strong foundation of data security that can be customized or augmented to align with compliance requirements as needed.
#### Text moderation from Cloud Natural Language API: 
Use text moderation capabilities from the Cloud Natural Language API to analyze user input and LLM responses for sentiment, content, and content categorization. Filter out inappropriate material based on predefined categories such as health, finance, politics, and legal.
### Pre-requirement
1. Enable Cloud Data Loss Prevention (DLP)

We have two ways to enable the api:

    1. Go to https://console.developers.google.com/apis/api/dlp.googleapis.com/overview click enable api.
    2. Run command: `gcloud services enable dlp.googleapis.com`

This filter can auto fetch the templates in your project. Please refer to the following links to create templates:

    1. Inspect templates: https://cloud.google.com/dlp/docs/creating-templates-inspect
    2. De-identification templates: https://cloud.google.com/dlp/docs/creating-templates-deid

2. Enable Cloud Natural Language API

Follow these instructions to [enable the Cloud Natural Language API](https://cloud.google.com/natural-language/docs/setup#api)
