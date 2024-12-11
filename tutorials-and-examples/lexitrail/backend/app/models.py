from .database import db
from datetime import datetime
from sqlalchemy import and_

class User(db.Model):
    __tablename__ = 'users'
    email = db.Column(db.String(320), primary_key=True)

    # Relationship to UserWord
    userwords = db.relationship('UserWord', back_populates='user', lazy=True)

    # Relationship to RecallHistory
    recall_histories = db.relationship('RecallHistory', back_populates='user', lazy=True, overlaps="userword")

class Wordset(db.Model):
    __tablename__ = 'wordsets'
    wordset_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    description = db.Column(db.String(1024), nullable=False)

    # Relationship to Word
    words = db.relationship('Word', back_populates='wordset', lazy=True)

class Word(db.Model):
    __tablename__ = 'words'
    word_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    word = db.Column(db.String(256), nullable=False)
    wordset_id = db.Column(db.Integer, db.ForeignKey('wordsets.wordset_id'), nullable=False)
    def1 = db.Column(db.String(1024), nullable=False)
    def2 = db.Column(db.String(1024), nullable=False)

    # Relationships
    wordset = db.relationship('Wordset', back_populates='words')
    userwords = db.relationship('UserWord', back_populates='word', lazy=True)
    recall_histories = db.relationship('RecallHistory', back_populates='word', lazy=True, overlaps="userword")

class RecallHistory(db.Model):
    __tablename__ = 'recall_history'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)  # Primary key added
    user_id = db.Column(db.String(320), db.ForeignKey('users.email'), nullable=False)
    word_id = db.Column(db.Integer, db.ForeignKey('words.word_id'), nullable=False)
    is_included = db.Column(db.Boolean, nullable=False)
    recall = db.Column(db.Boolean, nullable=False)
    recall_time = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    new_recall_state = db.Column(db.Integer, nullable=False)
    old_recall_state = db.Column(db.Integer, nullable=True)

    # Relationships
    user = db.relationship('User', back_populates='recall_histories', overlaps="userword")
    word = db.relationship('Word', back_populates='recall_histories', overlaps="userword")

class UserWord(db.Model):
    __tablename__ = 'userwords'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.String(320), db.ForeignKey('users.email'), nullable=False)
    word_id = db.Column(db.Integer, db.ForeignKey('words.word_id'), nullable=False)
    is_included = db.Column(db.Boolean, default=True, nullable=False)  # Ensure this field is added
    is_included_change_time = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)  # Match with schema
    recall_state = db.Column(db.Integer, default=0,  nullable=False)
    last_recall = db.Column(db.Boolean, nullable=True)  # last_recall is a Boolean
    last_recall_time = db.Column(db.DateTime, nullable=True)
    hint_img = db.Column(db.LargeBinary, nullable=True)  # Add hint_img field for completeness
    hint_text = db.Column(db.String(2048), nullable=True)

    # Relationships
    user = db.relationship('User', back_populates='userwords', overlaps="recall_histories")
    word = db.relationship('Word', back_populates='userwords', overlaps="recall_histories")
    
    # Explicitly define the primaryjoin to link UserWord and RecallHistory
    recall_histories = db.relationship(
        'RecallHistory',
        backref='userword',
        primaryjoin=and_(
            user_id == db.foreign(RecallHistory.user_id),
            word_id == db.foreign(RecallHistory.word_id)
        ),
        lazy=True,
        overlaps="recall_histories, user, word"
    )

