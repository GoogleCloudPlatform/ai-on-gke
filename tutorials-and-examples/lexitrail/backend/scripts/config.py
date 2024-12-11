import os
from dotenv import load_dotenv
from pathlib import Path

# Load environment variables from .env file located in the parent directory
env_path = Path('..') / '.env'
load_dotenv(dotenv_path=env_path)

# Environment variables
DB_ROOT_PASSWORD = os.getenv('DB_ROOT_PASSWORD', 'default_password')
DATABASE_NAME = os.getenv('DATABASE_NAME', 'test_db')
MYSQL_FILES_BUCKET = os.getenv('MYSQL_FILES_BUCKET', 'your-bucket-name')

# Hardcoded paths to CSV files
WORDSETS_CSV_PATH = '../terraform/csv/wordsets.csv'
WORDS_CSV_PATH = '../terraform/csv/words.csv'

# Database URI
DB_URI = f"mysql+pymysql://root:{DB_ROOT_PASSWORD}@127.0.0.1:3306/{DATABASE_NAME}"
