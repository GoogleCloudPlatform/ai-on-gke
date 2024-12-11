import sys
from sqlalchemy.orm import sessionmaker
from sqlalchemy import create_engine
from .config import DB_URI
from .validators import validate_local_files, validate_db_connection, validate_gcs_connection
from .wordset_processing import process_entries
from .data_loader import load_word_data
from .db_operations import load_db_data
from .gcs_operations import upload_to_gcs
from .logging_setup import log_info
from .config import WORDSETS_CSV_PATH, WORDS_CSV_PATH

# Setup SQLAlchemy engine and session
engine = create_engine(DB_URI)
Session = sessionmaker(bind=engine)

def print_wordset_summary(session):
    """Prints a summary of wordsets and their word counts in both the file and database."""
    # Load wordsets and words from CSV
    csv_data = load_word_data(WORDSETS_CSV_PATH, WORDS_CSV_PATH)
    
    # Count words per wordset in CSV
    log_info("CSV wordsets and word counts:")
    for wordset_desc, words in csv_data.items():
        log_info(f" - Wordset: {wordset_desc}, Word Count: {len(words)}")
    
    # Load wordsets and words from the database using db_operations
    db_data = load_db_data(session)
    log_info("Database wordsets and word counts:")
    for wordset_desc, words in db_data.items():
        log_info(f" - Wordset: {wordset_desc}, Word Count: {len(words)}")

def dbupdate():
    """Synchronizes the database with the CSV files and uploads updated files to GCS."""
    log_info("Starting dbupdate function")
    session = Session()

    # Print wordset summary
    print_wordset_summary(session)

    try:
        # Load data from CSV
        csv_data = load_word_data(WORDSETS_CSV_PATH, WORDS_CSV_PATH)
        
        # Load data from DB in the required format using db_operations
        db_data = load_db_data(session)

        # Process entries for synchronization and log summary of changes
        log_info("Processing entries for dbupdate")
        wordsets_added, wordsets_removed, words_added, words_removed, words_updated = process_entries(csv_data, db_data, session, is_check=False)

        # Commit changes
        session.commit()
        log_info(f"dbupdate completed with counts: "
                 f"Wordsets added: {wordsets_added}, Wordsets removed: {wordsets_removed}, "
                 f"Words added: {words_added}, Words removed: {words_removed}, Words updated: {words_updated}")

    except Exception as e:
        log_info(f"Error during dbupdate in {__file__} at line {e.__traceback__.tb_lineno}: {str(e)}")
        session.rollback()

    try:
        log_info("Starting GCS upload step")
        upload_to_gcs(WORDSETS_CSV_PATH, 'csv/wordsets.csv')
        upload_to_gcs(WORDS_CSV_PATH, 'csv/words.csv')
        log_info("Completed GCS upload step")
    except Exception as e:
        log_info(f"Error uploading to GCS in {__file__} at line {e.__traceback__.tb_lineno}: {str(e)}")

    log_info("Completed dbupdate function")

def dbcheck():
    """Compares the database with CSV files and logs changes that would be applied by dbupdate."""
    log_info("Starting dbcheck function (dry run)")
    session = Session()

    # Print wordset summary
    print_wordset_summary(session)

    try:
        # Load data from CSV
        csv_data = load_word_data(WORDSETS_CSV_PATH, WORDS_CSV_PATH)
        
        # Load data from DB
        db_data = load_db_data(session)

        # Process entries and log summary of changes without applying them
        log_info("Processing entries for dbcheck (dry run)")
        wordsets_added, wordsets_removed, words_added, words_removed, words_updated = process_entries(csv_data, db_data, session, is_check=True)

        log_info(f"dbcheck completed (dry run) with counts: "
                 f"Wordsets added: {wordsets_added}, Wordsets removed: {wordsets_removed}, "
                 f"Words added: {words_added}, Words removed: {words_removed}, Words updated: {words_updated}")

    except Exception as e:
        log_info(f"Error during dbcheck in {__file__} at line {e.__traceback__.tb_lineno}: {str(e)}")

    log_info("Completed dbcheck function")

def main():
    """Main entry point for the command line utility."""
    if len(sys.argv) < 2:
        log_info("Error: No function provided. Supported functions: dbupdate, dbcheck")
        sys.exit(1)

    function = sys.argv[1].lower()
    if not validate_local_files() or not validate_db_connection():
        sys.exit(1)

    if function == 'dbupdate':
        if not validate_gcs_connection():
            sys.exit(1)
        dbupdate()
    elif function == 'dbcheck':
        dbcheck()
    else:
        log_info(f"Error: Unsupported function '{function}'. Supported functions: dbupdate, dbcheck")
        sys.exit(1)

if __name__ == "__main__":
    main()
