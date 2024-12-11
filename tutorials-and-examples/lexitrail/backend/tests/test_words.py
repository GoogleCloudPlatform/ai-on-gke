import unittest
from tests.utils import TestUtils
from app import db
from app.models import Wordset
from datetime import datetime


class WordsTests(unittest.TestCase):

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

    def test_get_words_by_wordset_with_sufficient_options(self):
        """Test retrieving words by wordset with sufficient quiz options with the same syllables."""
        with self.app.app_context():
            # Create a wordset with enough words having the same syllable count
            wordset_id = TestUtils.create_test_wordset(db)
            TestUtils.create_test_words(db, wordset_id, [
                ("他", "tā", "him"),        # 1 syllable
                ("我", "wǒ", "me"),         # 1 syllable
                ("你", "nǐ", "you"),        # 1 syllable
                ("她", "tā", "her"),        # 1 syllable
            ])
            wordset = db.session.get(Wordset, wordset_id)
        
        response = self.client.get(f'/wordsets/{wordset.wordset_id}/words')
        self.assertEqual(response.status_code, 200)
        
        words_data = response.get_json().get('data', [])
        for word in words_data:
            # Verify the presence of all expected fields
            self.assertIn("word_id", word)
            self.assertIn("wordset_id", word)
            self.assertIn("word", word)
            self.assertIn("def1", word)
            self.assertIn("def2", word)
            self.assertIn("quiz_options", word)

            # Check that wordset_id matches the created wordset’s ID
            self.assertEqual(word["wordset_id"], wordset.wordset_id)
            
            # Verify that quiz options are present and correctly formatted
            self.assertEqual(len(word['quiz_options']), 3)

            # Ensure quiz options do not contain the word itself
            self.assertTrue(all(opt[0] != word["word"] for opt in word['quiz_options']))

            # Verify that all quiz options have the same syllable count as the original word
            syllable_count = len(word["word"])
            self.assertTrue(all(len(opt[0]) == syllable_count for opt in word['quiz_options']))


    def test_get_words_by_wordset_with_concatenated_options(self):
        """Test retrieving words by wordset requiring concatenated words for quiz options."""
        with self.app.app_context():
            # Create a wordset with words requiring concatenation to match syllable count
            wordset_id = TestUtils.create_test_wordset(db)
            TestUtils.create_test_words(db, wordset_id, [
                ("多少", "duōshǎo", "how much"),        # 2 syllables
                ("几个", "jǐgè", "several"),            # 2 syllables
                ("他", "tā", "him"),                    # 1 syllable
                ("你", "nǐ", "you"),                    # 1 syllable
                ("她", "tā", "her"),                    # 1 syllable
                ("我们", "wǒmen", "us"),                # 2 syllables (additional word for more options)
                ("这里", "zhèlǐ", "here")               # 2 syllables (additional word for more options)
            ])
            wordset = db.session.get(Wordset, wordset_id)
        
        response = self.client.get(f'/wordsets/{wordset.wordset_id}/words')
        self.assertEqual(response.status_code, 200)
        
        words_data = response.get_json().get('data', [])
        for word in words_data:
            if len(word["word"]) == 2:  # Only check for words with 2 syllables
                print(f"Testing word: {word['word']} with quiz options: {word['quiz_options']}")
                
                # Ensure quiz options do not contain the word itself
                self.assertTrue(
                    all(opt[0] != word["word"] for opt in word['quiz_options']),
                    f"One or more quiz options contain the original word '{word['word']}'"
                )
                
                # Check for concatenated words
                concatenated_options = [opt for opt in word['quiz_options'] if opt[2] == "[quiz word]"]
                for opt in concatenated_options:
                    print(f"Testing concatenated option: {opt}")
                    
                    # Verify `word` is concatenated without spaces
                    self.assertTrue(
                        len(opt[0]) > 2 and word["word"] not in opt[0],
                        f"Concatenated word '{opt[0]}' should be formed without spaces and not contain original word '{word['word']}'"
                    )
                    
                    # Verify `def1` is concatenated with a space between original `def1` values
                    self.assertIn(" ", opt[1], "Concatenated def1 should have spaces between original def1 values.")
                    # Verify `def2` is marked as concatenated
                    self.assertEqual(opt[2], "[quiz word]")


    def test_get_words_by_wordset_with_portioned_options(self):
        """Test retrieving words by wordset requiring portioned words for quiz options."""
        with self.app.app_context():
            # Create a wordset with words requiring portions for matching syllable count
            wordset_id = TestUtils.create_test_wordset(db)
            TestUtils.create_test_words(db, wordset_id, [
                ("怎么样", "zěnmeyàng", "how is it"),     # 3 syllables
                ("那么", "nàme", "then"),                # 2 syllables
                ("很好", "hěnhǎo", "great"),             # 2 syllables
                ("你", "nǐ", "you"),                     # 1 syllable
                ("他", "tā", "him"),
                ("她", "tā", "her"),
                ("它", "tā", "it"),
                ("他们", "tāmen", "them"),               # 2 syllables (additional word for more options)
                ("这里", "zhèlǐ", "here"),               # 2 syllables (additional word for more options)
                ("怎么样了", "zěnmeyàngle", "how is it now")  # 4 syllables (additional word to test portioning)
            ])
            wordset = db.session.get(Wordset, wordset_id)
        
        response = self.client.get(f'/wordsets/{wordset.wordset_id}/words')
        self.assertEqual(response.status_code, 200)
        
        words_data = response.get_json().get('data', [])
        for word in words_data:
            if len(word["word"]) == 3:  # Only check for words with 3 syllables
                # Ensure quiz options do not contain the word itself
                self.assertTrue(all(opt[0] != word["word"] for opt in word['quiz_options']))
                # Check for portioned words
                portioned_options = [opt for opt in word['quiz_options'] if opt[2] == "[quiz word]"]
                for opt in portioned_options:
                    # Verify `word` is portioned to match the syllable count of the original word
                    self.assertTrue(len(opt[0]) <= 3, "Portioned word should not exceed the syllable count of the original word.")
                    # Verify `def2` is marked as portioned
                    self.assertEqual(opt[2], "[quiz word]")

    
    
    def test_get_words_by_wordset_with_randomness_seed(self):
        """Test retrieving words by wordset with a specific randomness seed."""
        with self.app.app_context():
            # Create a wordset with enough words to ensure variability in selection
            wordset_id = TestUtils.create_test_wordset(db)
            TestUtils.create_test_words(db, wordset_id, [
                ("我", "wǒ", "me"),
                ("你", "nǐ", "your"),
                ("他", "tā", "him"),
                ("她", "tā", "her"),
                ("它", "tā", "it"),
                ("我们", "wǒmen", "us"),
                ("他们", "tāmen", "them"),
            ])
            wordset = db.session.get(Wordset, wordset_id)
        
        # Set a specific seed for reproducibility
        seed = 12345
        response1 = self.client.get(f'/wordsets/{wordset.wordset_id}/words?seed={seed}')
        response2 = self.client.get(f'/wordsets/{wordset.wordset_id}/words?seed={seed}')

        self.assertEqual(response1.status_code, 200)
        self.assertEqual(response2.status_code, 200)
        
        words_data1 = response1.get_json().get('data', [])
        words_data2 = response2.get_json().get('data', [])

        # Verify that the data matches when the same seed is used
        self.assertEqual(words_data1, words_data2, "Data should match when the same seed is used")

if __name__ == '__main__':
    unittest.main()
