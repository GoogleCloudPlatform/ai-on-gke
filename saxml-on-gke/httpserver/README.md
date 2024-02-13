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
$ curl localhost:8888
```

You will see the output below: 

```
{
    "message": "HTTP Server for SAX Client"
}
```

### Publish a model

```
$ curl --request POST \
-s \
localhost:8888/publish \
--data '
{
    "model": "/sax/test/lm2b",
    "model_path": "saxml.server.pax.lm.params.lm_cloud.LmCloudSpmd2BTest",
    "checkpoint": "None",
    "replicas": 1
}
'
```

You will see the output below: 

```
{
    "model": "/sax/test/lm2b",
    "path": "saxml.server.pax.lm.params.lm_cloud.LmCloudSpmd2BTest",
    "checkpoint": "None",
    "replicas": 1
}
```

### List all models in a Sax Cell

```
$ curl --request GET \
-s \
localhost:8888/listall \
--data '
{
    "sax_cell": "/sax/test"
}
'
```
You will see the output below: 

```
[
    "/sax/test/lm2b"
]
```

### List a Sax Cell

```
$ curl --request GET \
-s \
localhost:8888/listcell \
--data '
{
    "model": "/sax/test/lm2b"
}
'
```
You will see the output below: 

```
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
$ json_payload=$(cat  << EOF
{
  "model": "/sax/test/lm2b",
  "query": "Q: Who is Harry Potter's mom? A: "
}
EOF
)
$ curl --request POST \
--header "Content-type: application/json" \
-s \
localhost:8888/generate \
--data "$json_payload"
```

The result should be printed in the terminal

You can also add the following extra decode parameters:

```
{
  "model": "/sax/test/lm2b",
  "query": "Q: Who is Harry Potter's mom? A: ",
  "extra_inputs": {
		"temperature": 0.9,
		"per_example_max_decode_steps": 128,
      		"per_example_top_k": 1,
      		"per_example_top_p": 1.0
	}
}
```

### Unpublish a model

```
$ curl --request POST \
-s \
localhost:8888/unpublish \
--data '
{
    "model": "/sax/test/lm2b"
}
'
```

You will see the output below: 

```
{
    "model": "/sax/test/lm2b"
}
```