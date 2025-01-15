import streamlit as st
import os
import uuid

from langchain_core.messages import HumanMessage
from langchain_openai import ChatOpenAI
from langgraph.checkpoint.postgres import PostgresSaver
from langgraph.graph import START, MessagesState, StateGraph
from psycopg import Connection

AI_PREFIX = "Assistant"
HUMAN_PREFIX = "User"

@st.cache_resource
def get_checkpointer():
    db_uri = os.environ.get("DB_URI")
    connection_kwargs = { "autocommit": True, "prepare_threshold": 0 }
    conn = Connection.connect(conninfo=db_uri, **connection_kwargs)
    checkpointer = PostgresSaver(conn)
    checkpointer.setup()
    return checkpointer

@st.cache_resource
def get_model():
    model_base_url = os.environ.get("MODEL_BASE_URL")
    model_name = os.environ.get("MODEL_NAME")
    return ChatOpenAI(base_url=model_base_url, openai_api_key="-", model=model_name)

# Initialize Streamlit
st.set_page_config(page_title="Streamlit chatbot", page_icon="🤖")
st.title("Streamlit chatbot")
st.caption("Powered by Google Cloud, Langchain and PostgreSQL")

# Initialize the chat_id and messages
headers = st.context.headers
user_id = headers.get("X-Goog-Authenticated-User-Id")

if "chat_id" not in st.session_state:
    st.session_state.chat_id = user_id or str(uuid.uuid4())
if "messages" not in st.session_state:
    st.session_state.messages = []

# Initialize the model
model = get_model()
def call_model(state: MessagesState):
    response = model.invoke(state["messages"])
    return {"messages": response}

# Initialize the workflow and LangChain Graph state
workflow = StateGraph(state_schema=MessagesState)
workflow.add_edge(START, "model")
workflow.add_node("model", call_model)
app = workflow.compile(checkpointer=get_checkpointer())
config = {"configurable": {"thread_id": st.session_state.chat_id}}

# Load messages from LangChain Graph state and display them
app_state = app.get_state(config)
if "messages" in app_state.values:
    for message in app_state.values["messages"]:
        st.chat_message(message.type).markdown(message.content)

# Get the user input and generate a response
if prompt := st.chat_input("Enter your message"):
    prompt = prompt.strip()
    st.chat_message("human").markdown(prompt)
    st.session_state.messages.append({"role": "human", "content": prompt})

    with st.spinner(text="Processing..."):
        output = app.invoke({"messages": [HumanMessage(prompt)]}, config)

    response_content = output["messages"][-1].content.strip()
    st.chat_message("ai").markdown(response_content)
    st.session_state.messages.append({"role": "ai", "content": response_content})

# Add button to reset chat history
if len(st.session_state.messages) and st.button("Restart chat"):
    st.session_state.messages = []
    cursor = get_checkpointer().conn.cursor()
    cursor.execute("DELETE FROM checkpoints WHERE thread_id = %s", (st.session_state.chat_id,))
    cursor.execute("DELETE FROM checkpoint_writes WHERE thread_id = %s", (st.session_state.chat_id,))
    cursor.execute("DELETE FROM checkpoint_blobs WHERE thread_id = %s", (st.session_state.chat_id,))
    st.rerun()
