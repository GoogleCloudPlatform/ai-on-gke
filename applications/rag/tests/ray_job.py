# This script is copied from the applications/rag/example_notebooks/rag-kaggle-ray-sql-latest.ipynb for testing purposes
# TODO: remove this script and execute the notebook directly with nbconvert.

import os
import uuid
import ray
from langchain.document_loaders import ArxivLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from sentence_transformers import SentenceTransformer
from typing import List
import torch
from datasets import load_dataset_builder, load_dataset, Dataset
from huggingface_hub import snapshot_download
from google.cloud.sql.connector import Connector, IPTypes
import sqlalchemy

# initialize parameters
INSTANCE_CONNECTION_NAME = os.environ["CLOUDSQL_INSTANCE_CONNECTION_NAME"]
print(f"Your instance connection name is: {INSTANCE_CONNECTION_NAME}")
DB_NAME = "pgvector-database"

db_username_file = open("/etc/secret-volume/username", "r")
DB_USER = db_username_file.read()
db_username_file.close()

db_password_file = open("/etc/secret-volume/password", "r")
DB_PASS = db_password_file.read()
db_password_file.close()

# initialize Connector object
connector = Connector()

# function to return the database connection object
def getconn():
    conn = connector.connect(
        INSTANCE_CONNECTION_NAME,
        "pg8000",
        user=DB_USER,
        password=DB_PASS,
        db=DB_NAME,
        ip_type=IPTypes.PRIVATE
    )
    return conn

# create connection pool with 'creator' argument to our connection object function
pool = sqlalchemy.create_engine(
    "postgresql+pg8000://",
    creator=getconn,
)

SHARED_DATA_BASEPATH='/data/rag/st'
SENTENCE_TRANSFORMER_MODEL = 'intfloat/multilingual-e5-small' # Transformer to use for converting text chunks to vector embeddings
SENTENCE_TRANSFORMER_MODEL_PATH_NAME='models--intfloat--multilingual-e5-small' # the downloaded model path takes this form for a given model name
SENTENCE_TRANSFORMER_MODEL_SNAPSHOT="ffdcc22a9a5c973ef0470385cef91e1ecb461d9f" # specific snapshot of the model to use
SENTENCE_TRANSFORMER_MODEL_PATH = SHARED_DATA_BASEPATH + '/' + SENTENCE_TRANSFORMER_MODEL_PATH_NAME + '/snapshots/' + SENTENCE_TRANSFORMER_MODEL_SNAPSHOT # the path where the model is downloaded one time

# the dataset has been pre-dowloaded to the GCS bucket as part of the notebook in the cell above. Ray workers will find the dataset readily mounted.
SHARED_DATASET_BASE_PATH="/data/netflix-shows/"
REVIEWS_FILE_NAME="netflix_titles.csv"

BATCH_SIZE = 100
CHUNK_SIZE = 1000 # text chunk sizes which will be converted to vector embeddings
CHUNK_OVERLAP = 10
TABLE_NAME = 'netflix_reviews_db'  # CloudSQL table name
DIMENSION = 384  # Embeddings size
ACTOR_POOL_SIZE = 1 # number of actors for the distributed map_batches function

class Embed:
  def __init__(self):
        print("torch cuda version", torch.version.cuda)
        device="cpu"
        if torch.cuda.is_available():
            print("device cuda found")
            device="cuda"

        print ("reading sentence transformer model from cache path:", SENTENCE_TRANSFORMER_MODEL_PATH)
        self.transformer = SentenceTransformer(SENTENCE_TRANSFORMER_MODEL_PATH, device=device)
        self.splitter = RecursiveCharacterTextSplitter(chunk_size=CHUNK_SIZE, chunk_overlap=CHUNK_OVERLAP, length_function=len)

  def __call__(self, text_batch: List[str]):
      text = text_batch["item"]
      # print("type(text)=", type(text), "type(text_batch)=", type(text_batch))
      chunks = []
      for data in text:
        splits = self.splitter.split_text(data)
        # print("len(data)", len(data), "len(splits)=", len(splits))
        chunks.extend(splits)

      embeddings = self.transformer.encode(
          chunks,
          batch_size=BATCH_SIZE
      ).tolist()
      print("len(chunks)=", len(chunks), ", len(emb)=", len(embeddings))
      return {'results':list(zip(chunks, embeddings))}


# prepare the persistent shared directory to store artifacts needed for the ray workers
os.makedirs(SHARED_DATA_BASEPATH, exist_ok=True)

# One time download of the sentence transformer model to a shared persistent storage available to the ray workers
snapshot_download(repo_id=SENTENCE_TRANSFORMER_MODEL, revision=SENTENCE_TRANSFORMER_MODEL_SNAPSHOT, cache_dir=SHARED_DATA_BASEPATH)

# Process the dataset first, wrap the csv file contents into a Ray dataset
ray_ds = ray.data.read_csv(SHARED_DATASET_BASE_PATH + REVIEWS_FILE_NAME)
print(ray_ds.schema)

# Distributed flat map to extract the raw text fields.
ds_batch = ray_ds.flat_map(lambda row: [{
    'item': "This is a " + str(row["type"]) + " in " + str(row["country"]) + " called " + str(row["title"]) + 
    " added at " + str(row["date_added"]) + " whose director is " + str(row["director"]) + 
    " and with cast: " + str(row["cast"]) + " released at " + str(row["release_year"]) + 
    ". Its rating is: " + str(row['rating']) + ". Its duration is " + str(row["duration"]) + 
    ". Its description is " + str(row['description']) + "."
}])
print(ds_batch.schema)

# Distributed map batches to create chunks out of each row, and fetch the vector embeddings by running inference on the sentence transformer
ds_embed = ds_batch.map_batches(
    Embed,
    compute=ray.data.ActorPoolStrategy(size=ACTOR_POOL_SIZE),
    batch_size=BATCH_SIZE,  # Large batch size to maximize GPU utilization.
    num_gpus=1,  # 1 GPU for each actor.
    # num_cpus=1,
)

# Use this block for debug purpose to inspect the embeddings and raw text
# print("Embeddings ray dataset", ds_embed.schema)
# for output in ds_embed.iter_rows():
#     # restrict the text string to be less than 65535
#     data_text = output["results"][0][:65535]
#     # vector data pass in needs to be a string  
#     data_emb = ",".join(map(str, output["results"][1]))
#     data_emb = "[" + data_emb + "]"
#     print ("raw text:", data_text, ", emdeddings:", data_emb)

# print("Embeddings ray dataset", ds_embed.schema)

data_text = ""
data_emb = ""

with pool.connect() as db_conn:
  db_conn.execute(
    sqlalchemy.text(
    "CREATE EXTENSION IF NOT EXISTS vector;"
    )
  )
  db_conn.commit()

  create_table_query = "CREATE TABLE IF NOT EXISTS " + TABLE_NAME + " ( id VARCHAR(255) NOT NULL, text TEXT NOT NULL, text_embedding vector(384) NOT NULL, PRIMARY KEY (id));"
  db_conn.execute(
    sqlalchemy.text(create_table_query)
  )
  # commit transaction (SQLAlchemy v2.X.X is commit as you go)
  db_conn.commit()
  print("Created table=", TABLE_NAME)
  
  query_text = "INSERT INTO " + TABLE_NAME + " (id, text, text_embedding) VALUES (:id, :text, :text_embedding)"
  insert_stmt = sqlalchemy.text(query_text)
  for output in ds_embed.iter_rows():
    # print ("type of embeddings", type(output["results"][1]), "len embeddings", len(output["results"][1]))
    # restrict the text string to be less than 65535
    data_text = output["results"][0][:65535]
    # vector data pass in needs to be a string  
    data_emb = ",".join(map(str, output["results"][1]))
    data_emb = "[" + data_emb + "]"
    # print("text_embedding is ", data_emb)
    id = uuid.uuid4()
    db_conn.execute(insert_stmt, parameters={"id": id, "text": data_text, "text_embedding": data_emb})

  # batch commit transactions
  db_conn.commit()

  # query and fetch table
  query_text = "SELECT * FROM " + TABLE_NAME
  results = db_conn.execute(sqlalchemy.text(query_text)).fetchall()
  # for row in results:
  #   print(row)

  # verify results
  transformer = SentenceTransformer(SENTENCE_TRANSFORMER_MODEL)
  query_text = "During my holiday in Marmaris we ate here to fit the food. It's really good" 
  query_emb = transformer.encode(query_text).tolist()
  query_request = "SELECT id, text, text_embedding, 1 - ('[" + ",".join(map(str, query_emb)) + "]' <=> text_embedding) AS cosine_similarity FROM " + TABLE_NAME + " ORDER BY cosine_similarity DESC LIMIT 5;" 
  query_results = db_conn.execute(sqlalchemy.text(query_request)).fetchall()
  db_conn.commit()
  print("print query_results, the 1st one is the hit")
  for row in query_results:
    print(row)

# cleanup connector object
connector.close()
print ("end job")
