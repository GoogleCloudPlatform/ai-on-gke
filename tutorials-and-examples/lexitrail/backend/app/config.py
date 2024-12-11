# /app/config.py

import os
from dotenv import load_dotenv
from pathlib import Path

class Config:
    if not os.getenv('KUBERNETES_SERVICE_HOST'):
        env_path = Path('..') / '.env'
        load_dotenv(dotenv_path=env_path)
    
    DB_ROOT_PASSWORD = os.getenv('DB_ROOT_PASSWORD', 'default_password')
    DATABASE_NAME = os.getenv('DATABASE_NAME', 'test_db')
    GOOGLE_CLIENT_ID = os.getenv('GOOGLE_CLIENT_ID', 'default-client-id')
    
    PROJECT_ID = os.getenv('PROJECT_ID', 'your-default-project-id')
    LOCATION = os.getenv('LOCATION', 'us-central1')
    PARALLELISM_LIMIT = int(os.getenv('PARALLELISM_LIMIT', 5))  # Default to 5

    if os.getenv('KUBERNETES_SERVICE_HOST'):
        SQLALCHEMY_DATABASE_URI = 'mysql+pymysql://root:{}@mysql.{}.svc.cluster.local:3306/{}'.format(
            DB_ROOT_PASSWORD,
            os.getenv('SQL_NAMESPACE'),
            DATABASE_NAME
        )
    else:
        SQLALCHEMY_DATABASE_URI = 'mysql+pymysql://root:{}@localhost:3306/{}'.format(
            DB_ROOT_PASSWORD,
            DATABASE_NAME
        )

    SQLALCHEMY_TRACK_MODIFICATIONS = False


class TestConfig(Config):
    TESTING = True
    SQLALCHEMY_DATABASE_URI = ''
    GOOGLE_CLIENT_ID = 'test-client-id'
