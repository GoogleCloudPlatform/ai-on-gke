from google.cloud import storage
from .logging_setup import log_info
from .config import MYSQL_FILES_BUCKET

def upload_to_gcs(local_file_path, gcs_file_path):
    """Uploads a local file to Google Cloud Storage."""
    try:
        client = storage.Client()
        bucket = client.bucket(MYSQL_FILES_BUCKET)
        blob = bucket.blob(gcs_file_path)
        blob.upload_from_filename(local_file_path)
        log_info(f"Uploaded {local_file_path} to {gcs_file_path} in bucket {MYSQL_FILES_BUCKET}")
    except Exception as e:
        log_info(f"Failed to upload {local_file_path} to GCS: {str(e)}")
