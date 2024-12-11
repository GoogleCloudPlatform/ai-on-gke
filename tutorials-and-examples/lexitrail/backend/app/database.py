from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

def init_db(app):
    db.init_app(app)

    # Automatically create tables if they don't exist
    #with app.app_context():
    #    db.create_all()
