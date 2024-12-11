from flask import request, jsonify
import base64

def to_dict(model_instance):
    """
    Convert SQLAlchemy model instance to dictionary.
    Handles binary fields by excluding them or converting appropriately.
    """
    result = {}
    for c in model_instance.__table__.columns:
        value = getattr(model_instance, c.name)
        if isinstance(value, bytes):
            # Skip binary fields like hint_img or encode them
            result[c.name] = base64.b64encode(value).decode('utf-8') if c.name == 'hint_img' else None
        else:
            result[c.name] = value
    return result


def not_found_response(message="Resource not found"):
    """
    Returns a standardized JSON response for 404 errors.
    """
    response = jsonify({"error": message})
    response.status_code = 404
    return response

def success_response(data=None, message="Success"):
    """
    Returns a standardized JSON response for successful operations.
    """
    response = {"data": data, "message": message}
    return jsonify(response), 200

def error_response(message="An error occurred", status_code=400):
    """
    Returns a standardized JSON response for errors.
    """
    response = {"error": message}
    return jsonify(response), status_code

def validate_user_access(email):
    authenticated_email = request.user['email']

    # Print debug information for authenticated user
    print(f"Authenticated user: {request.user['email']} accessing user: {email}")

    # Check if the authenticated user is trying to access their own data
    if authenticated_email != email:
        return jsonify({"message": "Unauthorized: You can only access your own data"}), 403

    # If the user is authorized, return None to allow the request to proceed
    return None
