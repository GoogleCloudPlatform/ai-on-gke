import unittest
import tempfile
from unittest.mock import patch, MagicMock
from tests.utils import TestUtils
from app import db
from app.models import UserWord
from app.routes.hint_generation import process_single_hint, generate_prompt, generate_image
from PIL import Image
import base64
import os

class HintGenerationTests(unittest.TestCase):

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

    def save_image_from_base64(self, base64_str, word):
        """Save a base64 image to a temporary file and return the file path."""
        image_data = base64.b64decode(base64_str)
        with tempfile.NamedTemporaryFile(delete=False, suffix=f"_{word}.jpg") as temp_file:
            temp_file.write(image_data)
            return temp_file.name

    @patch('app.routes.hint_generation.get_llm_model')
    @patch('app.routes.hint_generation.get_image_generation_model')
    def test_generate_prompt_logic(self, mock_image_model, mock_llm_model):
        """Test the logic of prompt generation with mocked LLM model."""
        mock_chat = MagicMock()
        mock_llm_model.return_value.start_chat.return_value = mock_chat
        mock_chat.send_message.return_value.candidates[0].content.parts[0].text = 'A subtle prompt for testing'
        
        prompt = generate_prompt("必须", "bìxū", "must")
        self.assertEqual(prompt, 'A subtle prompt for testing')

    @patch('app.routes.hint_generation.get_image_generation_model')
    def test_generate_image_logic(self, mock_image_model):
        """Test the image generation logic with mocked Image Generation model."""
        mock_image_model.return_value.generate_images.return_value = [MockImage()]
        prompt = 'A subtle prompt for testing image generation'
        
        image = generate_image(prompt)
        self.assertIsNotNone(image)
        self.assertEqual(image.size, (400, 300))

    def test_process_single_hint_unmocked(self):
        """Test process_single_hint without mocks and save the output image."""
        with self.app.app_context():
            result = process_single_hint("必须", "bìxū", "must")
            self.assertIsInstance(result, dict)
            self.assertIn('hint_text', result)
            self.assertIn('hint_image', result)
            self.assertGreater(len(result['hint_image']), 0, "Generated image data should not be empty.")

            # Save the real image to disk and print file path for review
            image_path = self.save_image_from_base64(result['hint_image'], "必须")
            print(f"Generated image saved at: {image_path}")

    def test_regenerate_hint_no_existing_image_force_false(self):
        """Test the /regenerate route with no existing image and force_regenerate=false."""
        with self.app.app_context():
            # Create test data using TestUtils
            user, wordset, word, userword = TestUtils.create_test_userword(db, user_email='test@example.com', word_name='Test Word')

            response = self.client.get(f'/hint/generate_hint?user_id={user.email}&word_id={word.word_id}')
            self.assertEqual(response.status_code, 200)
            response_data = response.get_json().get('data')
            self.assertIn('hint_text', response_data)
            self.assertIn('hint_image', response_data)
            self.assertGreater(len(response_data['hint_image']), 0, "Generated image data should not be empty.")

            # Verify database is updated with new image and hint
            updated_userword = UserWord.query.filter_by(user_id=user.email, word_id=word.word_id).first()
            self.assertIsNotNone(updated_userword.hint_text)
            self.assertIsNotNone(updated_userword.hint_img)

    def test_regenerate_hint_existing_image_force_false(self):
        """Test the /regenerate route with existing image and force_regenerate=false (should not regenerate)."""
        with self.app.app_context():
            # Create test data using TestUtils
            user, wordset, word, userword = TestUtils.create_test_userword(db, user_email='test@example.com', word_name='Test Word')
            userword.hint_text = 'Existing hint text'
            userword.hint_img = b'Existing image data'  # Properly encode the image data
            print ("test_regenerate_hint_existing_image_force_false: userword.hint_img: %s" %( userword.hint_img));
            db.session.commit()

            response = self.client.get(f'/hint/generate_hint?user_id={user.email}&word_id={word.word_id}&force_regenerate=false')
            self.assertEqual(response.status_code, 200)
            response_data = response.get_json().get('data')
            self.assertEqual(response_data['hint_text'], 'Existing hint text')
            self.assertEqual(response_data['hint_image'], base64.b64encode(b'Existing image data').decode('utf-8') )

    def test_regenerate_hint_existing_image_force_true(self):
        """Test the /regenerate route with existing image and force_regenerate=true (should regenerate)."""
        with self.app.app_context():
            # Create test data using TestUtils
            user, wordset, word, userword = TestUtils.create_test_userword(db, user_email='test@example.com', word_name='Test Word')
            userword.hint_text = 'Existing hint text'
            userword.hint_img = base64.b64encode(b'Existing image data')  # Properly encode the image data
            db.session.commit()

            response = self.client.get(f'/hint/generate_hint?user_id={user.email}&word_id={word.word_id}&force_regenerate=true')
            self.assertEqual(response.status_code, 200)
            response_data = response.get_json().get('data')
            self.assertIn('hint_text', response_data)
            self.assertIn('hint_image', response_data)
            self.assertGreater(len(response_data['hint_image']), 0, "Generated image data should not be empty.")

            # Verify database is updated with new image and hint
            updated_userword = UserWord.query.filter_by(user_id=user.email, word_id=word.word_id).first()
            self.assertNotEqual(updated_userword.hint_text, 'Existing hint text')
            self.assertNotEqual(updated_userword.hint_img, base64.b64encode(b'Existing image data'))

    def test_generate_hint_create_userword_entry(self):
        """Test the /generate_hint route when UserWord entry does not exist (should create it)."""
        with self.app.app_context():
            # Create test data without creating a UserWord entry
            user, wordset, word = TestUtils.create_test_word(db, user_email='test@example.com', word_name='Test Word')

            response = self.client.get(f'/hint/generate_hint?user_id={user.email}&word_id={word.word_id}')
            self.assertEqual(response.status_code, 200)
            response_data = response.get_json().get('data')
            self.assertIn('hint_text', response_data)
            self.assertIn('hint_image', response_data)
            self.assertGreater(len(response_data['hint_image']), 0, "Generated image data should not be empty.")

            # Verify that a new UserWord entry was created and updated with hint
            new_userword = UserWord.query.filter_by(user_id=user.email, word_id=word.word_id).first()
            self.assertIsNotNone(new_userword)
            self.assertIsNotNone(new_userword.hint_text)
            self.assertIsNotNone(new_userword.hint_img)

class MockImage:
    """Mock class for generated image objects."""
    def __init__(self):
        self._pil_image = Image.new('RGB', (100, 100))

    @property
    def pil_image(self):
        return self._pil_image

if __name__ == '__main__':
    unittest.main()
