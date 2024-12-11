import os
from app import create_app

app = create_app()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5001))  # Default to 5001 for local development
    app.run(host='0.0.0.0', port=port, debug=True)
