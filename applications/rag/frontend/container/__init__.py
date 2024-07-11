import os

from flask import Flask

from .rag_langchain.rag_chain import engine

def create_app():
    app = Flask(__name__, static_folder='static')
    app.jinja_env.trim_blocks = True
    app.jinja_env.lstrip_blocks = True
    app.config['ENGINE'] = engine
    app.config['SECRET_KEY'] = os.environ.get("SECRET_KEY")

    return app

