from flask import Blueprint, jsonify
from .users import bp as users_bp
from .wordsets import bp as wordsets_bp
from .userwords import bp as userwords_bp
from .hint_generation import bp as hint_generation_bp

def register_routes(app):
    # Register all blueprints
    app.register_blueprint(users_bp)
    app.register_blueprint(wordsets_bp)
    app.register_blueprint(userwords_bp)
    app.register_blueprint(hint_generation_bp)

    # Add root route
    @app.route('/')
    def index():
        return jsonify(message="Welcome to the Flask API"), 200
