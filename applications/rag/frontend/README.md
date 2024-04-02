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

### Example

#### DLP

To safeguard sensitive data, follow the guidelines for [create inspect template](https://cloud.google.com/sensitive-data-protection/docs/creating-templates-inspect#dlp_create_inspect_template-console) and [create de-identify template](https://cloud.google.com/sensitive-data-protection/docs/creating-templates-deid).
Set up an inspect template to identify instances of PERSON_NAME and a de-identify template to substitute any found names in the content with their corresponding InfoType.

Execute the given query with DLP filtering active:
```
Who worked with Robert De Niro and name one film they collaborated
```

The expected output is:
```
[PERSON_NAME] has worked with many talented actors and directors throughout his career. One film he collaborated on with [PERSON_NAME] is "GoodFellas," which was released in 1990. In this film, [PERSON_NAME] played the role of [PERSON_NAME], a former mobster who recounts his rise and fall in a New York crime family.
```

#### Cloud Natural Language Moderation

Adjust the sensitivity level to 60 and attempt the following query:
```
Which movie will show blowing up a building
```

This should result in:
```
The response is deemed inappropriate for display.
```

Reducing the sensitivity threshold to 40 will reveal the initial answer:
```
It seems like you are asking about a movie that features a scene of blowing up a building. One such movie that comes to mind is "Die Hard" (1988), directed by John McTiernan and starring Bruce Willis, Alan Rickman, and Bonnie Bedelia. In this action film, the protagonist, New York City police detective John McClane, must save his estranged wife and other hostages taken by German terrorist Hans Gruber in the Nakatomi Plaza in Los Angeles. The film includes a memorable scene where McClane uses a makeshift explosive device to blow up the building's roof.

```
