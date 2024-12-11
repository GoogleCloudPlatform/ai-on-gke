from flask import Blueprint

bp = Blueprint('recall_history', __name__, url_prefix='/recall_history')

# No routes needed as per requirements
# All recall history manipulations are handled within userwords.py
