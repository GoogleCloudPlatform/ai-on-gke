import os
from flask import request, jsonify
import requests as req
from app.config import Config
import functools
import logging

logging.basicConfig(level=logging.WARNING)
logger = logging.getLogger(__name__)

default_mock_user = "test@example.com"

def authenticate_user(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        if os.getenv('TESTING') == 'True':
            # If in test mode, mock the user info
            token = request.headers.get('Authorization')
            if token:
                parts = token.split(' ')
                if len(parts) == 2 and parts[0] == 'Bearer':
                    email = parts[1]  # Mock the token as an email for testing purposes
                    request.user = {"email": email}
            else:
                request.user = {"email": default_mock_user}  # Default mock user in test mode
            return func(*args, **kwargs)

        # Extract the token from the Authorization header
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({"message": "Missing token"}), 401

        try:
            parts = token.split(' ')
            if len(parts) != 2 or parts[0] != 'Bearer':
                return jsonify({"message": "Invalid token format"}), 401

            access_token = parts[1]

            # Call Google API to validate the access token
            google_url = f"https://www.googleapis.com/oauth2/v1/tokeninfo?access_token={access_token}"
            response = req.get(google_url)
            print (response)

            if response.status_code != 200:
                return jsonify({"message": "Invalid access token"}), 401

            idinfo = response.json()
            issued_to = idinfo.get('issued_to')

            # Check if the token matches the expected client_id
            if issued_to != Config.GOOGLE_CLIENT_ID:
                return jsonify({"message": 
                                f"Token's client ID: {issued_to} does not match app's client ID {Config.GOOGLE_CLIENT_ID}. More: {str(idinfo)}"}), 401

            # Set the user info on the request
            request.user = {"email": idinfo.get('email')}
            return func(*args, **kwargs)

        except Exception as e:
            logger.error(f"Error authenticate_user: {e}", exc_info=True)
            return jsonify({"message": "Error verifying access token", "error": str(e)}), 401

    return wrapper
