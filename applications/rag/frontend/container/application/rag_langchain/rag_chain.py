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

import logging

from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.runnables import RunnableParallel, RunnableLambda
from langchain_core.runnables.history import RunnableWithMessageHistory

from langchain_community.embeddings.huggingface import HuggingFaceEmbeddings
from langchain_google_cloud_sql_pg import PostgresChatMessageHistory


from application.cloud_sql.cloud_sql import (
    CHAT_HISTORY_TABLE_NAME,
    create_sync_postgres_engine,
)
from application.rag_langchain.huggingface_inference_model import (
    HuggingFaceCustomChatModel,
)
from application.vector_storages import CloudSQLVectorStore

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)

QUESTION = "input"
HISTORY = "chat_history"
CONTEXT = "context"

SENTENCE_TRANSFORMER_MODEL = "intfloat/multilingual-e5-small"  # Transformer to use for converting text chunks to vector embeddings

template_str = """Answer the Question given by the user. Keep the answer to no more than 2 sentences. 
Improve upon your previous answers using History, a list of messages. 
Messages of type HumanMessage were asked by the user, and messages of type AIMessage were your previous responses.
Stick to the facts by basing your answers off of the Context provided.
Be brief in answering.
\n\n
Context: {context} 
"""

prompt = ChatPromptTemplate.from_messages(
    [
        ("system", template_str),
        MessagesPlaceholder("chat_history"),
        ("human", "{input}"),
    ]
)

engine = create_sync_postgres_engine()


def get_chat_history(session_id: str) -> PostgresChatMessageHistory:
    history = PostgresChatMessageHistory.create_sync(
        engine, session_id=session_id, table_name=CHAT_HISTORY_TABLE_NAME
    )

    logging.info(
        f"Retrieving history for session {session_id} with {len(history.messages)}"
    )
    return history


def clear_chat_history(session_id: str):
    history = PostgresChatMessageHistory.create_sync(
        engine, session_id=session_id, table_name=CHAT_HISTORY_TABLE_NAME
    )
    history.clear()


def create_chain() -> RunnableWithMessageHistory:
    model = HuggingFaceCustomChatModel()

    langchain_embed = HuggingFaceEmbeddings(model_name=SENTENCE_TRANSFORMER_MODEL)
    vector_store = CloudSQLVectorStore(langchain_embed, engine)

    retriever = vector_store.as_retriever()

    setup_and_retrieval = RunnableParallel(
        {
            "context": retriever,
            QUESTION: RunnableLambda(lambda d: d[QUESTION]),
            HISTORY: RunnableLambda(lambda d: d[HISTORY]),
        }
    )

    chain = setup_and_retrieval | prompt | model
    chain_with_history = RunnableWithMessageHistory(
        chain,
        get_chat_history,
        input_messages_key=QUESTION,
        history_messages_key=HISTORY,
        output_messages_key="output",
    )
    return chain_with_history


def take_chat_turn(
    chain: RunnableWithMessageHistory, session_id: str, query_text: str
) -> str:
    config = {"configurable": {"session_id": session_id}}
    result = chain.invoke({"input": query_text}, config=config)
    return result

