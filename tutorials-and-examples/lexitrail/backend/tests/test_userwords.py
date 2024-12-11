import unittest
from datetime import datetime, timedelta
from tests.utils import TestUtils
from app.models import User, Wordset, Word, UserWord, RecallHistory
from app import db
from datetime import datetime, timedelta
from email.utils import parsedate_to_datetime  # For parsing the HTTP date format


class UserWordTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        """Set up the test application and temporary database."""
        cls.client, cls.app, cls.temp_db_name = TestUtils.setup_test_app()

    @classmethod
    def tearDownClass(cls):
        """Tear down the temporary database after all tests."""
        TestUtils.teardown_test_db(cls.temp_db_name)

    def setUp(self):
        """Clean up the database before each test."""
        with self.app.app_context():
            TestUtils.clear_database(db)

    def test_get_userwords_with_recall_histories(self):
        """Test fetching userwords with recall history information."""
        with self.app.app_context():
            # Create test data
            user, wordset, word, userword = TestUtils.create_test_userword(db)

            # Add recall history for the word
            for i in range(4):
                recall_history = RecallHistory(
                    user_id=user.email,
                    word_id=word.word_id,
                    is_included=userword.is_included,
                    recall=(i % 2 == 0),
                    recall_time=datetime.utcnow() - timedelta(days=i),
                    new_recall_state=i,
                    old_recall_state=i-1 if i > 0 else None
                )
                db.session.add(recall_history)

            db.session.commit()

            # Query userwords for the created user and wordset
            response = self.client.get(f'/userwords/query?user_id={user.email}&wordset_id={wordset.wordset_id}')
            self.assertEqual(response.status_code, 200)

            # Get the JSON response and extract the 'data' field
            response_data = response.get_json()
            userword_data = response_data.get('data')

            # Assert that the data is a list and contains expected data
            self.assertIsInstance(userword_data, list)
            self.assertGreater(len(userword_data), 0)

            # Validate that recall histories are included and only last 3 recall entries
            recall_histories = userword_data[0].get('recall_histories')
            self.assertEqual(len(recall_histories), 3)

            # Convert recall_time from the string format to datetime for comparison
            recall_times = [parsedate_to_datetime(rh['recall_time']) for rh in recall_histories]

            # Debugging: Print parsed recall times
            for i, rt in enumerate(recall_times):
                print(f"Parsed recall time {i}: {rt}")

            # Ensure recall entries are ordered by latest recall time
            self.assertTrue(recall_times[0] > recall_times[1])
            self.assertTrue(recall_times[1] > recall_times[2])


    def test_update_recall_state_existing_userword(self):
        """Test updating the recall state of an existing userword."""
        with self.app.app_context():
            # Create test data
            user, _, word, userword = TestUtils.create_test_userword(db)

            # Perform update recall state test
            response = self.client.put(
                f'/userwords/{user.email}/{word.word_id}/recall',
                json={'recall_state': 2, 'recall': True, 'is_included': True}
            )
            self.assertEqual(response.status_code, 200)

            # Verify that the UserWord was updated
            updated_userword = db.session.query(UserWord).filter_by(user_id=user.email, word_id=word.word_id).first()
            self.assertIsNotNone(updated_userword)
            self.assertEqual(updated_userword.recall_state, 2)
            self.assertEqual(updated_userword.is_included, True)

            # Verify that RecallHistory was updated
            recall_history = db.session.query(RecallHistory).filter_by(user_id=user.email, word_id=word.word_id).first()
            self.assertIsNotNone(recall_history)
            self.assertEqual(recall_history.new_recall_state, 2)
            self.assertEqual(recall_history.old_recall_state, 1)

    def test_update_recall_state_new_userword(self):
        """Test creating a new userword entry and updating recall state."""
        with self.app.app_context():
            # Use TestUtils to create the test user, wordset, and word
            user, wordset, word = TestUtils.create_test_word(db)

            # Perform update recall state test for a new userword entry
            response = self.client.put(
                f'/userwords/{user.email}/{word.word_id}/recall',
                json={'recall_state': 2, 'recall': True, 'is_included': True}
            )
            self.assertEqual(response.status_code, 200)

            # Verify the new userword was created
            userword = db.session.query(UserWord).filter_by(user_id=user.email, word_id=word.word_id).first()
            self.assertIsNotNone(userword)
            self.assertEqual(userword.recall_state, 2)
            self.assertEqual(userword.is_included, True)

            # Verify that RecallHistory was updated
            recall_history = db.session.query(RecallHistory).filter_by(user_id=user.email, word_id=word.word_id).first()
            self.assertIsNotNone(recall_history)
            self.assertEqual(recall_history.new_recall_state, 2)
            self.assertEqual(recall_history.old_recall_state, None)  # No old recall state for new entry
            self.assertEqual(recall_history.recall, True)


if __name__ == '__main__':
    unittest.main()
