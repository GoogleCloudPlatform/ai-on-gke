import base64
import os
import uuid
import langchain 
from rag_langchain.rag_chain import create_chain, take_chat_turn
from langchain_core.runnables.history import RunnableWithMessageHistory

langchain.debug = True

SESSION_ID = str(uuid.uuid4())

def syncmain():
    chain_with_history = create_chain()
    result = take_chat_turn(chain_with_history, SESSION_ID, "I'd like to see a movie about frogs.")
    print(result)
    result = take_chat_turn(chain_with_history, SESSION_ID, "Are there any movies about frogs that go to war with bugs?")
    print(result)
    result = take_chat_turn(chain_with_history, SESSION_ID, "What about movies featuring Kermit the frog?")
    print(result)
    result = take_chat_turn(chain_with_history, SESSION_ID, "Is there anything else you can tell me about Muppet movies?")
    print(result)

if __name__ == '__main__':
    syncmain()

