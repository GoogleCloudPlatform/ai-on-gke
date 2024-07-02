import unittest
from container.main import app

class TestApp(unittest.TestCase):

    def setUp(self):
        # Set up the test application
        self.app = app
        self.client = app.test_client()
        
    def test_get_nlp_status(self):
        with self.app.app_context():
            response = self.client.get('/get_nlp_status')
            self.assertEqual(response.status_code, 200)
            data = response.get_json()
            self.assertIn('nlpEnabled', data)
            self.assertIsInstance(data['nlpEnabled'], bool)

    def test_get_dlp_status(self):
        with self.app.app_context():
            response = self.client.get('/get_dlp_status')
            self.assertEqual(response.status_code, 200)
            data = response.get_json()
            self.assertIn('dlpEnabled', data)
            self.assertIsInstance(data['dlpEnabled'], bool)

    def test_get_inspect_templates(self):
        with self.app.app_context():
            response = self.client.get('/get_inspect_templates')
            self.assertEqual(response.status_code, 200)
            data = response.get_json()
            self.assertIsInstance(data, list)

    def test_get_deidentify_templates(self):
        with self.app.app_context():
            response = self.client.get('/get_deidentify_templates')
            self.assertEqual(response.status_code, 200)
            data = response.get_json()
            self.assertIsInstance(data, list)

    def test_handle_prompt(self):
        with self.app.app_context():
            data = {'prompt': 'What is the capital of France?'}
            response = self.client.post('/prompt', json=data)
            self.assertEqual(response.status_code, 200)
            data = response.get_json()
            self.assertIn('response', data)
            self.assertIn('text', data['response'])

    def test_handle_prompt_with_errors(self):
        with self.app.app_context():
            response = self.client.post('/prompt')
            self.assertEqual(response.status_code, 400)

    def test_handle_documents(self):
        with self.app.app_context():
            data = {'files': [('file1.txt', 'This is the content of file1.')]}
            response = self.client.post('/upload_documents', data=data, content_type='multipart/form-data')
            self.assertEqual(response.status_code, 200)

    def test_handle_documents_with_errors(self):
        with self.app.app_context():
            data = {}
            response = self.client.post('/upload_documents', data=data)
            self.assertEqual(response.status_code, 500)