import os
from pathlib import Path
from sqlalchemy import create_engine, text
from google.cloud import storage
from .config import DB_URI, MYSQL_FILES_BUCKET, WORDSETS_CSV_PATH, WORDS_CSV_PATH
from .logging_setup import log_info

def validate_local_files():
    """Validates that the required local CSV files and .env file are present."""
    env_file_path = Path('..') / '.env'
    if not env_file_path.exists():
        log_info(f"Missing required file: {env_file_path}")
        return False
    if not os.path.exists(WORDSETS_CSV_PATH):
        log_info(f"Missing required file: {WORDSETS_CSV_PATH}")
        return False
    if not os.path.exists(WORDS_CSV_PATH):
        log_info(f"Missing required file: {WORDS_CSV_PATH}")
        return False
    log_info("All required local files are present.")
    return True

def validate_db_connection():
    """Validates connection to the MySQL database."""
    log_info(f"Attempting to connect to MySQL server with connection string: {DB_URI}")
    engine = create_engine(DB_URI)
    try:
        with engine.connect() as conn:
            conn.execute(text('SELECT 1 FROM wordsets LIMIT 1'))
            log_info("Successfully connected to the specified database and executed SELECT 1 FROM wordsets.")
        return True
    except Exception as e:
        log_info(f"Failed to connect to the MySQL database or execute SELECT 1 FROM wordsets: {str(e)}")
        return False

def validate_gcs_connection():
    """Validates connection to the Google Cloud Storage bucket."""
    try:
        client = storage.Client()
        bucket = client.bucket(MYSQL_FILES_BUCKET)
        list(bucket.list_blobs())  # Check access
        log_info(f"Successfully connected to Google Cloud Storage bucket: {MYSQL_FILES_BUCKET}")
        return True
    except Exception as e:
        log_info(f"Failed to connect to Google Cloud Storage bucket: {str(e)}")
        return False
