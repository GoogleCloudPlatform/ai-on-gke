import os
import logging

from llama_index.core import VectorStoreIndex
from llama_index.vector_stores.redis import RedisVectorStore
from llama_index.embeddings.huggingface import  HuggingFaceEmbedding
from llama_index.llms.ollama import Ollama

from fastapi import FastAPI, Depends
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse

from rag_demo import custom_schema, getenv_or_exit 

logger = logging.getLogger()

MODEL_NAME = getenv_or_exit("MODEL_NAME")
EMBEDDING_MODEL_NAME= os.getenv("EMBEDDING_MODEL_NAME", "BAAI/bge-small-en-v1.5")
REDIS_HOST = getenv_or_exit("REDIS_HOST")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
OLLAMA_SERVER_URL = getenv_or_exit("OLLAMA_SERVER_URL")

embed_model = HuggingFaceEmbedding(model_name=EMBEDDING_MODEL_NAME)

# Connect to vector store with already ingested data
vector_store = RedisVectorStore(
    schema=custom_schema,
    redis_url=f"redis://{REDIS_HOST}:{REDIS_PORT}",
)
# Create index from a vector store
index = VectorStoreIndex.from_vector_store(
    vector_store, embed_model=embed_model
)
# Connect to LLM using Ollama
llm = Ollama(
    model=MODEL_NAME,
    base_url=OLLAMA_SERVER_URL,
)
# Create query engine that is ready to query our RAG
query_engine = index.as_query_engine(llm=llm)

def get_query_engine():
    return query_engine

app = FastAPI()

@app.get("/invoke")
async def root(message: str, query_engine = Depends(get_query_engine)):
    response = query_engine.query(message)
    json_compatible_item_data = jsonable_encoder({"message": f"{response}"})
    return JSONResponse(content=json_compatible_item_data)
