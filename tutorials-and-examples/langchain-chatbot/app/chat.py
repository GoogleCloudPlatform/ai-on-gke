import streamlit as st
import os
import uuid

from langchain.chains import LLMChain
from langchain.memory import ConversationBufferMemory
from langchain.prompts import PromptTemplate
from langchain_community.llms import VLLMOpenAI
from langchain_community.chat_message_histories import RedisChatMessageHistory

AI_PREFIX = "Assistant"
HUMAN_PREFIX = "User"

base_url = os.environ.get("MODEL_BASE_URL")
model_name = os.environ.get("MODEL_NAME")
redis_conn_string = os.environ.get("REDIS_CONN_STRING")

# Initialize Streamlit
st.set_page_config(page_title="Streamlit chatbot", page_icon="🤖")
st.title("Streamlit chatbot")
st.caption("Powered by Google Cloud, Langchain and Redis")

# Initialize the chat_id and messages
if "chat_id" not in st.session_state:
    st.session_state.chat_id = str(uuid.uuid4())
if "messages" not in st.session_state:
    st.session_state.messages = []

# Initialize the memory
redis_chat_memory = RedisChatMessageHistory(
    url=redis_conn_string,
    session_id=st.session_state.chat_id
)
memory = ConversationBufferMemory(
    memory_key="chat_history",
    chat_memory=redis_chat_memory,
    ai_prefix=AI_PREFIX,
    human_prefix=HUMAN_PREFIX)

# Initialize the LLMChain
prompt = PromptTemplate(template="{chat_history}\n" + HUMAN_PREFIX + ": {human_input}\n" + AI_PREFIX + ": ")
llm = VLLMOpenAI(model=model_name, base_url=base_url, openai_api_key="-")
llm_chain = LLMChain(
    llm=llm,
    prompt=prompt,
    verbose=True,
    memory=memory,
)

# Display the chat messages
for message in st.session_state.messages:
    st.chat_message(message["role"]).markdown(message["content"])

# Get the user input and generate a response
if prompt := st.chat_input("Enter your message"):
    prompt = prompt.strip()
    st.chat_message("human").markdown(prompt)
    st.session_state.messages.append({"role": "human", "content": prompt})

    response = llm_chain.predict(human_input=prompt).strip()
    st.chat_message("ai").markdown(response)
    st.session_state.messages.append({"role": "ai", "content": response})
