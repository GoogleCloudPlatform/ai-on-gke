from sqlalchemy.orm import Session
from .db_operations import add_word, delete_word, add_wordset, delete_wordset, update_word
from .logging_setup import log_info

def process_entries(csv_data, db_data, session: Session, is_check=False):
    """
    Compare CSV and DB data for wordsets and words, log discrepancies, and perform updates.

    Parameters:
        csv_data (dict): A dictionary with wordset descriptions as keys, where each key maps to another dictionary.
                         Each inner dictionary maps words to their definitions (e.g., {"word": {"def1": "", "def2": ""}}).
        db_data (dict): A similar dictionary structure as `csv_data`, representing the current database data.
        session (Session): SQLAlchemy session for database interaction.
        is_check (bool): If True, only logs discrepancies without making changes; otherwise, applies updates to the database.

    Returns:
        tuple: (wordsets_added, wordsets_removed, words_added, words_removed, words_updated) counts for each operation.
    """
    # Validate format of first entry in csv_data and db_data for consistency
    try:
        # Validate csv_data format
        first_csv_wordset = next(iter(csv_data.values()), None)
        first_csv_word = next(iter(first_csv_wordset.values()), None) if first_csv_wordset else None
        if not (isinstance(first_csv_word, dict) and 'def1' in first_csv_word and 'def2' in first_csv_word):
            raise ValueError(f"csv_data format error: Expected 'def1' and 'def2' in word definitions, but got: {first_csv_word}")

        # Validate db_data format if it contains any wordsets
        if db_data:
            first_db_wordset = next(iter(db_data.values()))
            first_db_word = next(iter(first_db_wordset.values()), None)
            if not (isinstance(first_db_word, dict) and 'def1' in first_db_word and 'def2' in first_db_word):
                raise ValueError(f"db_data format error: Expected 'def1' and 'def2' in word definitions, but got: {first_db_word}")

    except Exception as e:
        log_info(f"Validation failed: {str(e)}")
        raise

    # Initialize counters
    wordsets_added = wordsets_removed = words_added = words_removed = words_updated = 0

    # Process wordsets and words
    for wordset_desc, csv_words in csv_data.items():
        db_words = db_data.get(wordset_desc, {})

        # Check if wordset exists in the database
        if wordset_desc not in db_data:
            log_info(f"Wordset '{wordset_desc}' is missing in the database. It will be added.")
            if not is_check:
                add_wordset(session, wordset_desc)
            wordsets_added += 1
            db_words = {}  # Set to empty to prepare for missing words check

        # Check for word discrepancies within the wordset
        for word, csv_defs in csv_words.items():
            db_defs = db_words.get(word)

            if word not in db_words:
                log_info(f"Word '{word}' in wordset '{wordset_desc}' is missing in the database. It will be added.")
                if not is_check:
                    add_word(session, word, wordset_desc, csv_defs['def1'], csv_defs['def2'])
                words_added += 1
            else:
                # Check definitions if word exists
                if csv_defs['def1'] != db_defs['def1'] or csv_defs['def2'] != db_defs['def2']:
                    diff_msg = f"Word '{word}' in wordset '{wordset_desc}' has differing definitions:\n"
                    if csv_defs['def1'] != db_defs['def1']:
                        diff_msg += f" - def1 differs: CSV='{csv_defs['def1']}', DB='{db_defs['def1']}'\n"
                    if csv_defs['def2'] != db_defs['def2']:
                        diff_msg += f" - def2 differs: CSV='{csv_defs['def2']}', DB='{db_defs['def2']}'"
                    log_info(diff_msg)
                    
                    # Update definitions if not a check
                    if not is_check:
                        update_word(session, word, wordset_desc, csv_defs['def1'], csv_defs['def2'])
                    words_updated += 1

        # Detect words in the DB that are not in the CSV (obsolete words)
        obsolete_words = set(db_words.keys()) - set(csv_words.keys())
        for word in obsolete_words:
            log_info(f"Word '{word}' in wordset '{wordset_desc}' is obsolete in the database. It will be removed.")
            if not is_check:
                delete_word(session, word, wordset_desc)
            words_removed += 1

    # Detect wordsets in the DB that are not in the CSV (obsolete wordsets)
    obsolete_wordsets = set(db_data.keys()) - set(csv_data.keys())
    for wordset_desc in obsolete_wordsets:
        log_info(f"Wordset '{wordset_desc}' is obsolete in the database. It will be removed.")
        if not is_check:
            delete_wordset(session, wordset_desc)
        wordsets_removed += 1

    # Return operation counts
    log_info(f"Summary: Wordsets added: {wordsets_added}, Wordsets removed: {wordsets_removed}, "
             f"Words added: {words_added}, Words removed: {words_removed}, Words updated: {words_updated}")

    return wordsets_added, wordsets_removed, words_added, words_removed, words_updated
