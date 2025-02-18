import os
import sys
import pathlib


from llama_index.embeddings.huggingface import HuggingFaceEmbedding
from llama_index.core.ingestion import (
    DocstoreStrategy,
    IngestionPipeline,
    IngestionCache,
)
from llama_index.storage.kvstore.redis import RedisKVStore as RedisCache
from llama_index.storage.docstore.redis import RedisDocumentStore
from llama_index.core.node_parser import SentenceSplitter
from llama_index.vector_stores.redis import RedisVectorStore

from redisvl.schema import IndexSchema
from llama_index.core import SimpleDirectoryReader, VectorStoreIndex

# Add rag_demo package to PYTHONPATH so this script can access it.
sys.path.append(str(pathlib.Path(__file__).parent.parent.absolute()))
from rag_demo import custom_schema, getenv_or_exit 


EMBEDDING_MODEL_NAME = os.getenv("EMBEDDING_MODEL_NAME", "BAAI/bge-small-en-v1.5")
REDIS_HOST = getenv_or_exit("REDIS_HOST")
REDIS_PORT = int(os.getenv("REDIS_URL", "6379"))
INPUT_DIR = getenv_or_exit("INPUT_DIR")

embed_model = HuggingFaceEmbedding(model_name=EMBEDDING_MODEL_NAME)
vector_store = RedisVectorStore(
    schema=custom_schema,
    redis_url=f"redis://{REDIS_HOST}",
)

# Set up the ingestion cache layer
cache = IngestionCache(
    cache=RedisCache.from_host_and_port(REDIS_HOST, REDIS_PORT),
    collection="redis_cache",
)

pipeline = IngestionPipeline(
    transformations=[
        SentenceSplitter(),
        embed_model,
    ],
    docstore=RedisDocumentStore.from_host_and_port(
        REDIS_HOST, REDIS_PORT, namespace="document_store"
    ),
    vector_store=vector_store,
    cache=cache,
    docstore_strategy=DocstoreStrategy.UPSERTS,
)

index = VectorStoreIndex.from_vector_store(
    pipeline.vector_store, 
    embed_model=embed_model
)

reader = SimpleDirectoryReader(input_dir=INPUT_DIR)

def load_data(reader: SimpleDirectoryReader):
    docs = reader.load_data()
    for doc in docs:
        doc.id_ = doc.metadata["file_path"]
    return docs

docs = load_data(reader)
print(f"Loaded {len(docs)} docs")

nodes = pipeline.run(documents=docs, show_progress=True)
print(f"Ingested {len(nodes)} Nodes")
