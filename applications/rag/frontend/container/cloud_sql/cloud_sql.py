import os

from google.cloud.sql.connector import Connector, IPTypes
import pymysql
import sqlalchemy
from sentence_transformers import SentenceTransformer
import pg8000

db = None

TABLE_NAME = os.environ.get('TABLE_NAME', '')  # CloudSQL table name
INSTANCE_CONNECTION_NAME = os.environ.get('INSTANCE_CONNECTION_NAME', '')
SENTENCE_TRANSFORMER_MODEL = 'intfloat/multilingual-e5-small' # Transformer to use for converting text chunks to vector embeddings
DB_NAME = "pgvector-database"

db_username_file = open("/etc/secret-volume/username", "r")
DB_USER = db_username_file.read()
db_username_file.close()

db_password_file = open("/etc/secret-volume/password", "r")
DB_PASS = db_password_file.read()
db_password_file.close()

transformer = SentenceTransformer(SENTENCE_TRANSFORMER_MODEL)

def init_db() -> sqlalchemy.engine.base.Engine:
  """Initiates connection to database and its structure."""
  global db
  connector = Connector()
  if db is None:
    db = init_connection_pool(connector)


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

def fetchContext(query_text):
  with db.connect() as conn:
    try:
      results = conn.execute(sqlalchemy.text("SELECT * FROM " + TABLE_NAME)).fetchall()
      print(f"query database results:")
      for row in results:
        print(row)

      # chunkify query & fetch matches
      query_emb = transformer.encode(query_text).tolist()
      query_request = "SELECT id, text, text_embedding, 1 - ('[" + ",".join(map(str, query_emb)) + "]' <=> text_embedding) AS cosine_similarity FROM " + TABLE_NAME + " ORDER BY cosine_similarity DESC LIMIT 5;"
      query_results = conn.execute(sqlalchemy.text(query_request)).fetchall()
      conn.commit()

      if not query_results:
        message = f"Table {TABLE_NAME} returned empty result"
        raise ValueError(message)
      for row in query_results:
        print(row)
    except sqlalchemy.exc.DBAPIError or pg8000.exceptions.DatabaseError as err:
      message = f"Table {TABLE_NAME} does not exist: {err}"
      raise sqlalchemy.exc.DataError(message)
    except sqlalchemy.exc.DatabaseError as err:
      message = f"Database {INSTANCE_CONNECTION_NAME} does not exist: {err}"
      raise sqlalchemy.exc.DataError(message)
    except Exception as err:
      raise Exception(f"General error: {err}")

  return query_results[0][1]