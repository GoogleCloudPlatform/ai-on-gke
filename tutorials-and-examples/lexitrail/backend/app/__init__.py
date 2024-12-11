from flask import Flask
from .config import Config
from .database import init_db, db  # Add db import
from .routes import register_routes
from flask_cors import CORS  # Import CORS

def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)
    
    # Initialize the database
    init_db(app)
    
    # Register routes
    register_routes(app)
    
    # Enable CORS for all origins
    CORS(app, resources={r"/*": {"origins": "*"}})

    return app

# Expose db so it can be imported from app
__all__ = ['create_app', 'db']
