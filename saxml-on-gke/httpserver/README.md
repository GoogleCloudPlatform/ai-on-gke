# Inferencing using Saxml and an HTTP Server

## Background

[Saxml](https://github.com/google/saxml) is an experimental system that serves [Paxml](https://github.com/google/paxml), [JAX](https://github.com/google/jax), and [PyTorch](https://pytorch.org/) models for inference. A Sax cell (aka Sax cluster) consists of an admin server and a group of model servers. The admin server keeps track of model servers, assigns published models to model servers to serve, and helps clients locate model servers serving specific published models.

In order to interact with the Sax cluster today, users can use the command line tool, [saxutil](https://github.com/google/saxml#use-sax), or interact directly with the [Sax client](https://github.com/google/saxml/tree/main/saxml/client/).

This tutorial uses an HTTP Server to handle HTTP requests to Sax, supporting features such as model publishing, listing, updating, unpublishing, and generating predictions. The HTTP server uses the [Python Sax client](https://github.com/google/saxml/tree/main/saxml/client/python) in order to communicate with the Sax cluster and handle routing within the Sax system. With an HTTP server, interaction with Sax can also expand to further than at the VM-level. For example, integration with GKE and load balancing will enable requests to Sax from inside and outside the GKE cluster.

**This tutorial focuses on the deployment of the HTTP server and assumes you have already deployed a Sax Admin Server and Sax Model Server according to the [OSS SAX Docker Guide](https://github.com/google/saxml/tree/main/saxml/tools/docker)**

### Build Dockerfile.http

Build the HTTP Server image:

```
docker build -f Dockerfile.http -t sax-http .
```

### Run the HTTP Server Locally

If you haven't already, create a GCS Bucket to store Sax Cluster information:

```
GSBUCKET=${USER}-sax-data
gcloud storage buckets create gs://${GSBUCKET}
```

```
docker run -e SAX_ROOT=gs://${GSBUCKET}/sax-root -p 8888:8888 -it sax-http
```

In another terminal:

```
curl localhost:8888
```

You will see the output below:

```json
{
  "message": "HTTP Server for SAX Client"
}
```

### Publish a model

```
curl --request POST \
--header "Content-type: application/json" \
--silent \
localhost:8888/publish \
--data \
'{
    "model": "/sax/test/lm2b",
    "model_path": "saxml.server.pax.lm.params.lm_cloud.LmCloudSpmd2BTest",
    "checkpoint": "None",
    "replicas": 1
}'
```

You will see the output below:

```json
{
  "model": "/sax/test/lm2b",
  "path": "saxml.server.pax.lm.params.lm_cloud.LmCloudSpmd2BTest",
  "checkpoint": "None",
  "replicas": 1
}
```

### List all models in a Sax Cell

```
curl --request GET \
--header "Content-type: application/json" \
--silent \
localhost:8888/listall \
--data \
'{
    "sax_cell": "/sax/test"
}'
```

You will see the output below:

```json
["/sax/test/lm2b"]
```

### List a Sax Cell

```
curl --request GET \
--header "Content-type: application/json" \
--silent \
localhost:8888/listcell \
--data \
'{
    "model": "/sax/test/lm2b"
}'
```

You will see the output below:

```json
{
  "model": "/sax/test/lm2b",
  "model_path": "saxml.server.pax.lm.params.lm_cloud.LmCloudSpmd2BTest",
  "checkpoint": "None",
  "max_replicas": 1,
  "active_replicas": 1
}
```

### Generate a prediction

```
curl --request POST \
--header "Content-type: application/json" \
--silent \
localhost:8888/generate \
--data \
'{
    "model": "/sax/test/lm2b",
    "query": "Q: Who is Harry Potter's mom? A: "
}'
```

The result should be printed in the terminal

### Unpublish a model

```
$ curl --request POST \
--header "Content-type: application/json" \
--silent \
localhost:8888/unpublish \
--data '
{
    "model": "/sax/test/lm2b"
}
'
```

You will see the output below:

```json
{
  "model": "/sax/test/lm2b"
}
```

## Saxml HTTP Server APIs

The following are the APIs implemented in this HTTP Server, the complete [Python client interface](https://github.com/google/saxml/blob/main/saxml/client/python/sax.pyi) is available in the [google/saxml repository](https://github.com/google/saxml)

### generate

`/generate` is use to generate a response from a specific model.

#### generate Request

JSON object of the following format:

```
{
    "model": <String>,
    "query": <String>,
    "extra_inputs": {
        "temperature": <Number>,
        "per_example_max_decode_steps": <Number>,
        "per_example_top_k": <Number>,
        "per_example_top_p": <Number>
    }
}
```

- `model` is the name of the model to query.
- `query` is the prompt to send to the model.
- `extra_inputs` is an optional object that overrides the default decoding configuration of the model.
  - `temperature`: is the decoding temperature.
  - `per_example_max_decode_steps`: Is the maximum decoding steps for each request. Needs to be smaller than maximum value of max_decode_steps configured for the published model.
  - `per_example_top_k`: is the topK used for decoding.
  - `per_example_top_p`: is the topP used for decoding.

#### generate Response

JSON object with the following format:

```
[
    [
        <String>,
        <Number>
    ],
    ...
]
```

`[[<String>, <Number>]]` is an array of arrays

- `<String>` is the response from the model.
- `<Number>` is the score of the response.

### listall

`/listall` is used to list all model in a specific cell

#### listall Request

JSON object of the following format:

```
{
    "sax_cell": <String>
}
```

- `sax_cell` is the path to list.

#### listall Response

JSON object with the following format:

```
[
    <String>,
    ...
]
```

- `[<String>]` is an array Strings.
  - `<String>` is a model name.

### listcell

`/listcell` is used to list a specific model.

#### listcell Request

JSON object of the following format:

```
{
    "model": <String>
}
```

- `model` is the name of the model.

#### listcell Response

JSON object with the following format:

```
{
    "model": <String>,
    "model_path": <String>,
    "checkpoint": <String>,
    "max_replicas": <Number>,
    "active_replicas": <Number>
}
```

- `model` is the name of the model.
- `model_path` is the path of the model in the Saxml model registry.
- `checkpoint` is the location of the model checkpoint.
- `max_replicas` is the maximum number of replicas the model be deployed on.
- `active_replicas` is the number of replicas the model is currently deployed on.

### publish

`/publish` is used to publish a new model.

#### publish Request

JSON object of the following format:

```
{
    "model": <String>,
    "model_path": <String>,
    "checkpoint": <String>,
    "replicas": <Number>
}
```

- `model` is the name of the model.
- `model_path` is the path of the model in the Saxml model registry.
- `checkpoint` is the location of the model checkpoint.
- `replicas` is the number of replicas of the model to deploy.

#### publish Response

JSON object with the following format:

```
{
    "model": <String>
}
```

- `model` is the name of the model published.

### unpublish

`/unpublish` is used to unpublish a model.

#### unpublish Request

JSON object of the following format:

```
{
    "model": <String>
}
```

- `model` is the name of the model to unpublish.

#### unpublish Response

JSON object with the following format:

```
{
    "model": <String>
}
```

- `model` is the name of the model unpublished.

### update

`/update` is used to updated an existing model.

#### update Request

JSON object of the following format:

```
{
    "model": <String>,
    "model_path": <String>,
    "checkpoint": <String>,
    "replicas": <Number>
}
```

- `model` is the name of the model.
- `model_path` is the path of the model in the Saxml model registry.
- `checkpoint` is the location of the model checkpoint.
- `replicas` is the <Number> of replicas of the model to deploy.

#### update Response

JSON object with the following format:

```
{
    "model": <String>,
    "model_path": <String>,
    "checkpoint": <String>,
    "replicas": <Number>
}
```

- `model` is the name of the model.
- `model_path` is the path of the model in the Saxml model registry.
- `checkpoint` is the location of the model checkpoint.
- `replicas` is the number of replicas of the model to deploy.
