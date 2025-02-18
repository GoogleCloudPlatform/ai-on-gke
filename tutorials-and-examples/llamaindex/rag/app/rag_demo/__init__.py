import os
import logging 

from redisvl.schema import IndexSchema

logger = logging.getLogger()

custom_schema = IndexSchema.from_dict(
    {
        "index": {"name": "bucket", "prefix": "doc"},
        # customize fields that are indexed
        "fields": [
            # required fields for llamaindex
            {"type": "tag", "name": "id"},
            {"type": "tag", "name": "doc_id"},
            {"type": "text", "name": "text"},
            # custom vector field for bge-small-en-v1.5 embeddings
            {
                "type": "vector",
                "name": "vector",
                "attrs": {
                    "dims": 384,
                    "algorithm": "hnsw",
                    "distance_metric": "cosine",
                },
            },
        ],
    }
)

def getenv_or_exit(name: str) -> str:
    value = os.getenv(name) 
    if value is None:
        logger.critical(f"The environment variable '{name}' is not specified")
        exit(1)

    return value
