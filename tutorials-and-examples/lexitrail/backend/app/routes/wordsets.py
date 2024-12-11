from flask import request, Blueprint, jsonify
from ..models import Wordset, Word
from ..utils import to_dict, success_response, error_response
from app import db
import logging
import random
import time

bp = Blueprint('wordsets', __name__, url_prefix='/wordsets')
logging.basicConfig(level=logging.DEBUG)  # Set logging level to DEBUG for detailed output
logger = logging.getLogger(__name__)

@bp.route('', methods=['GET'])
def get_all_wordsets():
    """Fetch all wordsets."""
    try:
        wordsets = Wordset.query.all()
        wordsets_data = [to_dict(ws) for ws in wordsets]
        return success_response(wordsets_data)
    except Exception as e:
        logger.error(f"Error get_all_wordsets: {e}", exc_info=True)
        return error_response(str(e), 500)

def count_syllables(word):
    """Simple function to count the syllables in a Chinese word."""
    return len(word)

def generate_quiz_options(word, words_by_syllable, syllable_count):
    logger.debug(f"Generating quiz options for word '{word.word}' with syllable count {syllable_count}")
    used_word_ids = {word.word_id}

    all_available_words = [w for words in words_by_syllable.values() for w in words if w.word_id not in used_word_ids]

    quiz_options = []
    same_syllable_words = [w for w in words_by_syllable.get(syllable_count, []) if w.word_id not in used_word_ids]

    if len(same_syllable_words) >= 3:
        quiz_options = random.sample(same_syllable_words, 3)
        used_word_ids.update(opt.word_id for opt in quiz_options)
        logger.debug(f"Selected same syllable words: {[opt.word for opt in quiz_options]}")
    else:
        # Add available same-syllable words first
        quiz_options.extend(same_syllable_words)
        used_word_ids.update(opt.word_id for opt in same_syllable_words)
        logger.debug(f"Not enough same syllable words, selected so far: {[opt.word for opt in quiz_options]}")

        # Continue filling up quiz options to reach 3
        while len(quiz_options) < 3:
           
            total_syllables = 0
            concatenated_word = ""
            concatenated_def1 = ""

            # Loop for concatenation
            while total_syllables < syllable_count:
                remaining_words = [w for w in all_available_words if w.word_id not in used_word_ids]
                logger.debug(f"Remaining words: {[w.word for w in remaining_words]}, count: {len(remaining_words)}")

                if not remaining_words:
                    error_msg = "Not enough words to continue concatenation to meet syllable count."
                    logger.error(error_msg)
                    raise ValueError(error_msg)

                next_word = random.choice(remaining_words)
                remaining_syllables_needed = syllable_count - total_syllables
                next_word_syllables = count_syllables(next_word.word)


                # Take only the needed portion of the word
                if next_word_syllables > remaining_syllables_needed:
                    portioned_word = next_word.word[:remaining_syllables_needed]
                    portioned_def1 = next_word.def1
                    concatenated_word += portioned_word
                    concatenated_def1 += ' ' + portioned_def1
                    total_syllables += remaining_syllables_needed
                    logger.debug(f"Portioned '{next_word.word}' to '{portioned_word}' for syllable count match.")
                else:
                    logger.debug(f"Concatenating '{next_word.word}' to '{concatenated_word}' to reach syllable count.")
                    concatenated_word += next_word.word
                    concatenated_def1 += ' ' + next_word.def1
                    total_syllables += next_word_syllables
                    
                    
                # Ensure no duplicate with an existing word
                existing_words = {w.word for w in all_available_words if w.word_id in used_word_ids}
                if concatenated_word in existing_words:
                    # Replace a character to ensure uniqueness
                    replace_index = random.randint(0, len(concatenated_word) - 1)
                    replacement_char = '的' if concatenated_word[replace_index] != '的' else '一'
                    concatenated_word = (
                        concatenated_word[:replace_index] + replacement_char + concatenated_word[replace_index + 1:]
                    )
                    logger.debug(
                        f"Replaced character at index {replace_index} in '{concatenated_word}' "
                        f"to avoid duplication, new word: '{concatenated_word}'"
                    )
                logger.debug(f"After concatenation: {concatenated_word} ({total_syllables}/{syllable_count} syllables)")

            # Append the final concatenated option
            quiz_options.append([
                concatenated_word[:syllable_count],  # Ensure it slices only if needed
                concatenated_def1.strip(),
                "[quiz word]"
            ])

    quiz_options_formatted = [
        [opt.word, opt.def1, opt.def2] if isinstance(opt, Word) else opt
        for opt in quiz_options
    ]
    logger.debug(f"Final quiz options for word '{word.word}': {quiz_options_formatted}")
    return quiz_options_formatted


@bp.route('/<int:wordset_id>/words', methods=['GET'])
def get_words_by_wordset(wordset_id):
    """Fetch words by wordset with quiz options and optional random seed."""
    try:
        # Fetch the wordset by ID
        wordset = db.session.get(Wordset, wordset_id)
        if not wordset:
            return error_response('Wordset not found', 404)

        # Set the random seed
        seed = request.args.get('seed', default=int(time.time()), type=int)
        random.seed(seed)
        logger.debug(f"Using random seed: {seed}")

        # Query words that belong to this wordset
        words = Word.query.filter_by(wordset_id=wordset_id).all()
        word_data = []

        # Calculate the total syllable count across all words in the wordset
        total_syllables = sum(count_syllables(word.word) for word in words)
        logger.debug(f"Total syllables in wordset (all words): {total_syllables}")


        words_by_syllable = {}

        for word in words:
            syllable_count = count_syllables(word.word)
            if syllable_count not in words_by_syllable:
                words_by_syllable[syllable_count] = []
            words_by_syllable[syllable_count].append(word)

        # Verify there are enough syllables for each word to generate options
        for word in words:
            syllable_count = count_syllables(word.word)
            remaining_syllables = total_syllables - syllable_count
            required_syllables = syllable_count * 3

            # If remaining syllables are insufficient, fail the entire method
            if remaining_syllables < required_syllables:
                error_msg = (
                    f"Insufficient syllables in wordset to generate quiz options for word '{word.word}' "
                    f"with required syllable count {syllable_count} per option."
                )
                logger.error(error_msg)
                return error_response(error_msg, 400)

            logger.debug(f"Processing word '{word.word}' with syllable count {syllable_count}")
            quiz_options = generate_quiz_options(word, words_by_syllable, syllable_count)

            word_data.append({
                "word_id": word.word_id,       # Include word_id
                "wordset_id": word.wordset_id, # Include wordset_id
                "word": word.word,
                "def1": word.def1,
                "def2": word.def2,
                "quiz_options": quiz_options
            })

        return success_response(word_data)
    except Exception as e:
        logger.error(f"Error in get_words_by_wordset: {e}", exc_info=True)
        return error_response(f"Error fetching words: {str(e)}", 500)

