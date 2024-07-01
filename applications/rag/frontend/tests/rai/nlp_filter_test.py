import os
import unittest
from unittest.mock import patch, MagicMock
from container.rai.nlp_filter import is_nlp_api_enabled, sum_moderation_confidences, is_content_inappropriate

class TestNLPFunctions(unittest.TestCase):

    @patch('container.rai.nlp_filter.nature_language_client')
    @patch('container.rai.nlp_filter.os.environ.get')
    @patch('container.rai.nlp_filter.sum_moderation_confidences')
    def test_is_nlp_api_enabled(self, mock_sum_moderation_confidences, mock_get_env, mock_nature_language_client):
        # Test when PROJECT_ID is not set
        mock_get_env.return_value = 'NULL'
        self.assertFalse(is_nlp_api_enabled())
        
        # Test when PROJECT_ID is set
        mock_get_env.return_value = 'test_project'
        mock_sum_moderation_confidences.return_value = True
        self.assertTrue(is_nlp_api_enabled())

        # Test when exception occurs
        mock_sum_moderation_confidences.side_effect = Exception("API Error")
        self.assertFalse(is_nlp_api_enabled())

    @patch('container.rai.nlp_filter.nature_language_client.moderate_text')
    def test_sum_moderation_confidences(self, mock_moderate_text):
        # Create a mock response
        mock_response = MagicMock()
        mock_response.moderation_categories = [
            MagicMock(name="Violence", confidence=0.9),
            MagicMock(name="Health", confidence=0.3),
            MagicMock(name="Politics", confidence=0.2),
        ]
        mock_moderate_text.return_value = mock_response

        result = sum_moderation_confidences("test text")
        self.assertEqual(result, 90)

    @patch('container.rai.nlp_filter.sum_moderation_confidences')
    def test_is_content_inappropriate(self, mock_sum_moderation_confidences):
        # Test with different levels of nlp_filter_level
        mock_sum_moderation_confidences.return_value = 70
        self.assertTrue(is_content_inappropriate("test text", 20))
        self.assertFalse(is_content_inappropriate("test text", 40))

if __name__ == '__main__':
    unittest.main()
