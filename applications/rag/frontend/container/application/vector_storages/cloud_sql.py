# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import uuid
import logging

from typing import List, Optional, Iterable, Any

import pg8000
import sqlalchemy
from sqlalchemy.engine import Engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.sql import func, text

from langchain_core.vectorstores import VectorStore
from langchain_core.embeddings import Embeddings
from langchain_core.documents import Document
from langchain.text_splitter import CharacterTextSplitter

from application.models import VectorEmbeddings

VECTOR_EMBEDDINGS_TABLE_NAME = os.environ.get("EMBEDDINGS_TABLE_NAME", "")
INSTANCE_CONNECTION_NAME = os.environ.get("INSTANCE_CONNECTION_NAME", "")

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)


class CloudSQLVectorStore(VectorStore):
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
        self.text_splitter = CharacterTextSplitter(
            separator="\n\n",
            chunk_size=1024,
            chunk_overlap=200,
        )

    @property
    def embeddings(self) -> Embeddings:
        return self.embedding

    # TODO implement
    def add_texts(
        self, texts: Iterable[str], metadatas: List[dict] | None = None, **kwargs: Any
    ) -> List[str]:
        with self.engine.connect() as conn:
            try:
                Session = sessionmaker(bind=conn)
                session = Session(bind=conn)
                for raw_text in texts:
                    id = uuid.uuid4()

                    texts = self.text_splitter.split_text(raw_text)
                    embeddings = self.embedding.encode(texts).tolist()
                    vector_embedding = VectorEmbeddings(
                        id=id, text=texts, text_embedding=embeddings[0]
                    )
                    session.add(vector_embedding)
                    conn.commit()

            except sqlalchemy.exc.DBAPIError or pg8000.exceptions.DatabaseError as err:
                message = f"Table {VECTOR_EMBEDDINGS_TABLE_NAME} does not exist: {err}"
                raise sqlalchemy.exc.DataError(message)
            except sqlalchemy.exc.DatabaseError as err:
                message = f"Database {INSTANCE_CONNECTION_NAME} does not exist: {err}"
                raise sqlalchemy.exc.DataError(message)
            except Exception as err:
                raise Exception(f"General error: {err}")

    # TODO implement similarity search with cosine similarity threshold

    def similarity_search(
        self, query: dict, k: int = 4, **kwargs: Any
    ) -> List[Document]:
        with self.engine.connect() as conn:
            try:
                Session = sessionmaker(bind=conn)
                session = Session(bind=conn)

                q = query.get("input")
                # embed query & fetch matches
                query_emb = self.embedding.embed_query(q)
                query_request = (
                    "SELECT id, text, text_embedding, 1 - ('["
                    + ",".join(map(str, query_emb))
                    + "]' <=> text_embedding) AS cosine_similarity FROM "
                    + VECTOR_EMBEDDINGS_TABLE_NAME
                    + " ORDER BY cosine_similarity DESC LIMIT "
                    + str(k)
                    + ";"
                )
                query_results = session.execute(text(query_request)).fetchall()

                print(f"GOT {len(query_results)} results")

                session.commit()
                session.close()

                if not query_results:
                    message = (
                        f"Table {VECTOR_EMBEDDINGS_TABLE_NAME} returned empty result"
                    )
                    raise ValueError(message)

            except sqlalchemy.exc.DataError or pg8000.exceptions.DatabaseError as err:
                message = f"Table {VECTOR_EMBEDDINGS_TABLE_NAME} does not exist: {err}"
                raise sqlalchemy.exc.DataError(message)
            except sqlalchemy.exc.DatabaseError as err:
                message = f"Database {INSTANCE_CONNECTION_NAME} does not exist: {err}"
                raise sqlalchemy.exc.DataError(message)
            except Exception as err:
                raise Exception(f"General error: {err}")

        # convert query results into List[Document]
        texts = [result[1] for result in query_results]
        return [Document(page_content=text) for text in texts]
