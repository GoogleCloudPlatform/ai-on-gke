import os
from typing import (List, Optional, Iterable, Any)

from google.cloud.sql.connector import Connector, IPTypes
import pymysql
import sqlalchemy
from sentence_transformers import SentenceTransformer
from langchain_core.vectorstores import VectorStore
import pg8000
from langchain_core.embeddings import Embeddings
from langchain_core.documents import Document
from sqlalchemy.engine import Engine
from langchain_google_cloud_sql_pg import PostgresEngine

VECTOR_EMBEDDINGS_TABLE_NAME = os.environ.get('TABLE_NAME', '') # CloudSQL table name for vector embeddings
# TODO make this configurable from tf
CHAT_HISTORY_TABLE_NAME = "message_store" # CloudSQL table name where chat history is stored

INSTANCE_CONNECTION_NAME = os.environ.get('INSTANCE_CONNECTION_NAME', '')
SENTENCE_TRANSFORMER_MODEL = 'intfloat/multilingual-e5-small' # Transformer to use for converting text chunks to vector embeddings
DB_NAME = "pgvector-database"

PROJECT_ID = os.environ.get('PROJECT_ID', '')
REGION = os.environ.get('REGION', '') 
INSTANCE = os.environ.get('INSTANCE', '')

db_username_file = open("/etc/secret-volume/username", "r")
DB_USER = db_username_file.read()
db_username_file.close()

db_password_file = open("/etc/secret-volume/password", "r")
DB_PASS = db_password_file.read()
db_password_file.close()

transformer = SentenceTransformer(SENTENCE_TRANSFORMER_MODEL)

# helper function to return SQLAlchemy connection pool
def init_connection_pool(connector: Connector) -> sqlalchemy.engine.Engine:
  # function used to generate database connection
  def getconn() -> pymysql.connections.Connection:
    conn = connector.connect(
        INSTANCE_CONNECTION_NAME,
        "pg8000",
        user=DB_USER,
        password=DB_PASS,
        db=DB_NAME,
        ip_type=IPTypes.PRIVATE
    )
    return conn

  # create connection pool
  pool = sqlalchemy.create_engine(
      "postgresql+pg8000://",
      creator=getconn,
  )
  return pool

def create_sync_postgres_engine():
    engine = PostgresEngine.from_instance(
        project_id=PROJECT_ID,
        region=REGION, 
        instance=INSTANCE,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASS,
        ip_type=IPTypes.PRIVATE        
    )
    engine.init_chat_history_table(table_name=CHAT_HISTORY_TABLE_NAME)
    return engine

#TODO replace this with the Cloud SQL vector store for langchain,
#   once the notebook also uses it (and creates the correct schema)
class CustomVectorStore(VectorStore):
    @classmethod
    def from_texts(
        cls,
        texts: List[str],
        embedding: Embeddings,
        metadatas: Optional[List[dict]] = None,
        **kwargs: Any,
    ):
        raise NotImplementedError

    def __init__(self, embedding: Embeddings, engine: Engine):
        self.embedding = embedding
        self.engine = engine

    @property
    def embeddings(self) -> Embeddings:
        return self.embedding


    # TODO implement
    def add_texts(self, texts: Iterable[str], metadatas: List[dict] | None = None, **kwargs: Any) -> List[str]:
        raise NotImplementedError
    
    #TODO implement similarity search with cosine similarity threshold

    def similarity_search(self, query: dict, k: int = 4, **kwargs: Any) -> List[Document]:
        print("ENTERING similarity_search")
        with self.engine.connect() as conn:
            try:
                q = query["question"]
                print(f"ENTERING query embedding for '{q}'")
                # embed query & fetch matches
                query_emb = self.embedding.embed_query(q)
                print(f"GOT embedding of length: {len(query_emb)}")
                emb_str = ",".join(map(str, query_emb))
                query_request = f"""SELECT id, text, 1 - ('[{emb_str}]' <=> text_embedding) AS cosine_similarity 
                    FROM {VECTOR_EMBEDDINGS_TABLE_NAME} 
                    ORDER BY cosine_similarity DESC LIMIT {k};"""
                query_results = conn.execute(sqlalchemy.text(query_request)).fetchall()
                print(f"GOT {len(query_results)} results")
                conn.commit()

                if not query_results:
                    message = f"Table {VECTOR_EMBEDDINGS_TABLE_NAME} returned empty result"
                    raise ValueError(message)
                print("****QUERY RESULTS****")
                for row in query_results:
                    print(row)
            except sqlalchemy.exc.DBAPIError or pg8000.exceptions.DatabaseError as err:
                message = f"Table {VECTOR_EMBEDDINGS_TABLE_NAME} does not exist: {err}"
                raise sqlalchemy.exc.DataError(message)
            except sqlalchemy.exc.DatabaseError as err:
                message = f"Database {INSTANCE_CONNECTION_NAME} does not exist: {err}"
                raise sqlalchemy.exc.DataError(message)
            except Exception as err:
                raise Exception(f"General error: {err}")

        #convert query results into List[Document]
        texts = [result[1] for result in query_results]
        return [Document(page_content=text) for text in texts]
