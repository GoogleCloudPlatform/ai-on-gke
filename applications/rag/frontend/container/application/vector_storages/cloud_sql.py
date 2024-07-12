import os
from typing import (List, Optional, Iterable, Any)

import pg8000
import sqlalchemy
from sqlalchemy.engine import Engine

from langchain_core.vectorstores import VectorStore
from langchain_core.embeddings import Embeddings
from langchain_core.documents import Document

VECTOR_EMBEDDINGS_TABLE_NAME = os.environ.get('TABLE_NAME', '') 
INSTANCE_CONNECTION_NAME = os.environ.get('INSTANCE_CONNECTION_NAME', '')

class CloudSQLVectorStorage(VectorStore):
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
        with self.engine.connect() as conn:
            try:
                q = query["question"]
                # embed query & fetch matches
                query_emb = self.embedding.embed_query(q)
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