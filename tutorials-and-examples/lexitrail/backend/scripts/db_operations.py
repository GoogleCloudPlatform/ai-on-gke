from sqlalchemy.orm import Session
from .logging_setup import log_info
from app.models import Wordset, Word, UserWord, RecallHistory

def update_word(session: Session, word: str, wordset_description: str, def1: str, def2: str):
    """Update definitions of an existing word in the database if the wordset exists."""
    session.expire_all()  # Refresh session for latest state
    normalized_description = wordset_description.strip()
    all_wordsets = session.query(Wordset).all()

    # Search for exact match in wordsets
    matched_wordset_id = None
    for ws in all_wordsets:
        if ws.description.strip() == normalized_description:
            matched_wordset_id = ws.wordset_id
            break

    if matched_wordset_id:
        normalized_word = word.strip()
        word_record = session.query(Word).filter_by(word=normalized_word, wordset_id=matched_wordset_id).first()
        
        if word_record:
            word_record.def1 = def1.strip()
            word_record.def2 = def2.strip()
            try:
                session.commit()
                log_info(f"Successfully updated word '{normalized_word}' in wordset '{normalized_description}'.")
            except Exception as e:
                session.rollback()
                log_info(f"Error committing changes for word '{normalized_word}' in wordset '{normalized_description}': {str(e)}")
        else:
            log_info(f"Word '{normalized_word}' not found in wordset '{normalized_description}'. No update performed.")
    else:
        log_info(f"Wordset '{normalized_description}' not found in the database. Cannot update word '{word.strip()}'.")

def add_wordset(session: Session, description: str):
    """Add a new wordset entry to the database."""
    session.expire_all()  # Refresh session for latest state
    new_wordset = Wordset(description=description.strip())
    session.add(new_wordset)
    session.commit()

def delete_wordset(session: Session, description: str):
    """Delete a wordset entry and its dependencies from the database."""
    session.expire_all()  # Refresh session for latest state
    wordset = session.query(Wordset).filter_by(description=description.strip()).first()
    if wordset:
        # Delete all associated records
        session.query(UserWord).filter(UserWord.word_id.in_(
            session.query(Word.word_id).filter_by(wordset_id=wordset.wordset_id)
        )).delete(synchronize_session=False)
        
        session.query(RecallHistory).filter(RecallHistory.word_id.in_(
            session.query(Word.word_id).filter_by(wordset_id=wordset.wordset_id)
        )).delete(synchronize_session=False)
        
        session.query(Word).filter_by(wordset_id=wordset.wordset_id).delete(synchronize_session=False)
        session.delete(wordset)
        session.commit()
    else:
        log_info(f"Wordset '{description}' not found. No deletion performed.")

def add_word(session: Session, word: str, wordset_description: str, def1: str, def2: str):
    """Add a new word entry to the database if the associated wordset exists."""
    session.expire_all()  # Refresh session for latest state
    wordset = session.query(Wordset).filter_by(description=wordset_description.strip()).first()
    
    if wordset:
        new_word = Word(word=word.strip(), wordset_id=wordset.wordset_id, def1=def1.strip(), def2=def2.strip())
        session.add(new_word)
        session.commit()
    else:
        log_info(f"Wordset '{wordset_description.strip()}' not found in database. Cannot add word '{word.strip()}'.")

def delete_word(session: Session, word: str, wordset_description: str):
    """Delete a word entry and its dependencies from the database if the wordset exists."""
    session.expire_all()  # Refresh session for latest state
    wordset = session.query(Wordset).filter_by(description=wordset_description.strip()).first()
    if wordset:
        word_record = session.query(Word).filter_by(word=word.strip(), wordset_id=wordset.wordset_id).first()
        if word_record:
            session.query(UserWord).filter_by(word_id=word_record.word_id).delete(synchronize_session=False)
            session.query(RecallHistory).filter_by(word_id=word_record.word_id).delete(synchronize_session=False)
            session.delete(word_record)
            session.commit()
        else:
            log_info(f"Word '{word.strip()}' not found in wordset '{wordset_description.strip()}'. No deletion performed.")
    else:
        log_info(f"Wordset '{wordset_description.strip()}' not found. Cannot delete word '{word.strip()}'.")

def load_db_data(session: Session):
    """
    Load data from the database in the required format for processing, matching the 
    format {wordset_desc: {word: {'def1': ..., 'def2': ...}}}.
    """
    session.expire_all()  # Refresh session for latest state
    db_data = {}
    wordsets = session.query(Wordset).all()
    
    for wordset in wordsets:
        description = wordset.description.strip()
        db_data[description] = {}
        
        words = session.query(Word).filter_by(wordset_id=wordset.wordset_id).all()
        for word in words:
            db_data[description][word.word.strip()] = {
                "def1": word.def1.strip() if word.def1 else "",
                "def2": word.def2.strip() if word.def2 else ""
            }

    return db_data
