import unittest
from tests.utils import TestUtils
from app.auth import default_mock_user

class UserTests(unittest.TestCase):

    temp_db_name = ''

    @classmethod
    def setUpClass(cls):
        cls.client, cls.app, cls.temp_db_name = TestUtils.setup_test_app()

    @classmethod
    def tearDownClass(cls):
        TestUtils.teardown_test_db(cls.temp_db_name)
    
    def setUp(self):
        """Set up default mock Authorization header."""
        self.headers = {}

    def test_create_user(self):
        response = TestUtils.authenticate_and_create_user(self.client, default_mock_user)
        self.assertEqual(response.status_code, 201)
        self.assertIn(b'User created successfully', response.data)

    def test_get_user(self):
        TestUtils.authenticate_and_create_user(self.client, 'user1@example.com')  # Create user
        TestUtils.mock_auth_header(self.headers, 'user1@example.com')  # Mock auth header

        response = self.client.get('/users/user1@example.com', headers=self.headers)
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'user1@example.com', response.data)

    def test_update_user(self):
        TestUtils.authenticate_and_create_user(self.client, 'user2@example.com')  # Create user
        TestUtils.mock_auth_header(self.headers, 'user2@example.com')  # Mock auth header

        response = self.client.put('/users/user2@example.com', json={'email': 'newemail@example.com'}, headers=self.headers)
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'User updated successfully', response.data)

    def test_delete_user(self):
        TestUtils.authenticate_and_create_user(self.client, 'user3@example.com')  # Create user
        TestUtils.mock_auth_header(self.headers, 'user3@example.com')  # Mock auth header

        response = self.client.delete('/users/user3@example.com', headers=self.headers)
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'User deleted successfully', response.data)

    def test_get_users(self):
        """This might be failing because the GET /users route is missing."""
        TestUtils.authenticate_and_create_user(self.client, default_mock_user)  # Create user
        TestUtils.mock_auth_header(self.headers, default_mock_user)  # Mock auth header

        response = self.client.get('/users', headers=self.headers)
        self.assertEqual(response.status_code, 200)

if __name__ == '__main__':
    unittest.main()
