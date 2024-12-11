# /app/routes/hint_generation.py

import time
import concurrent.futures
from flask import Blueprint, request
from ..config import Config
from ..utils import success_response, error_response
import vertexai
from vertexai.preview.vision_models import ImageGenerationModel
from vertexai.generative_models import GenerativeModel, SafetySetting
from PIL import Image as PIL_Image
import base64
from io import BytesIO
from app.auth import authenticate_user  # Import from auth.py
from google.cloud import aiplatform
from ..models import db, UserWord, Word
from ..utils import validate_user_access  # Import the shared validation function
from datetime import datetime
import logging

logging.basicConfig(level=logging.WARNING)
logger = logging.getLogger(__name__)



# Define the Blueprint
bp = Blueprint('hint_generation', __name__, url_prefix='/hint')

# Configuration for prompt generation
generation_config = {
    "max_output_tokens": 8192,
    "temperature": 1,
    "top_p": 0.95,
}

# Safety settings for LLM prompt generation
safety_settings = [
    SafetySetting(
        category=SafetySetting.HarmCategory.HARM_CATEGORY_HATE_SPEECH,
        threshold=SafetySetting.HarmBlockThreshold.OFF
    ),
    SafetySetting(
        category=SafetySetting.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
        threshold=SafetySetting.HarmBlockThreshold.OFF
    ),
    SafetySetting(
        category=SafetySetting.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
        threshold=SafetySetting.HarmBlockThreshold.OFF
    ),
    SafetySetting(
        category=SafetySetting.HarmCategory.HARM_CATEGORY_HARASSMENT,
        threshold=SafetySetting.HarmBlockThreshold.OFF
    ),
]

# Lazy-loaded model instances
_llm_model = None
_image_generation_model = None

aiplatform.init(project=Config.PROJECT_ID, location=Config.LOCATION)
vertexai.init(project=Config.PROJECT_ID, location=Config.LOCATION)

def get_llm_model():
    global _llm_model
    if _llm_model is None:
        try:
            _llm_model = GenerativeModel("gemini-1.5-flash-002")
        except Exception as e:
            raise RuntimeError(f"Failed to initialize LLM model: {str(e)}")
    return _llm_model

def get_image_generation_model():
    global _image_generation_model
    if _image_generation_model is None:
        try:
            _image_generation_model = ImageGenerationModel.from_pretrained("imagen-3.0-fast-generate-001")
        except Exception as e:
            raise RuntimeError(f"Failed to initialize Image Generation model: {str(e)}")
    return _image_generation_model

def generate_prompt(word, pinyin, translation):
    model = get_llm_model()
    chat = model.start_chat()
    response = chat.send_message(
        [f"""
        Generate a prompt that I can pass to an image generation model, like "imagen" to generate an image hint for Chinese word "{word}" pinyin "{pinyin}" translated as "{translation}". The hint should be subtle without revealing the meaning. No text should be in the picture.
        """],
        generation_config=generation_config,
        safety_settings=safety_settings
    )
    return response.candidates[0].content.parts[0].text

def generate_image(prompt):
    image_generation_model = get_image_generation_model()
    image = image_generation_model.generate_images(
        prompt=prompt,
        number_of_images=1,
        aspect_ratio="4:3",
        safety_filter_level="block_some",
        person_generation="allow_adult",
    )
    resized_image = image[0]._pil_image.resize((400, 300), PIL_Image.Resampling.LANCZOS)
    return resized_image

def image_to_base64(image):
    buffered = BytesIO()
    image.save(buffered, format="JPEG", quality=70)
    return base64.b64encode(buffered.getvalue()).decode("utf-8")


def process_single_hint(word, pinyin, translation):
    # Start timing for text generation
    start_text = time.time()
    
    # Generate the prompt
    prompt = generate_prompt(word, pinyin, translation)
    text_time = time.time() - start_text  # Measure the time taken for text generation

    # Start timing for image generation
    start_image = time.time()
    
    # Generate the image from the prompt
    image = generate_image(prompt)
    image_time = time.time() - start_image  # Measure the time taken for image generation

    # Convert the image to base64 format for return
    hint_image_base64 = image_to_base64(image)

    # Return the result with all relevant information
    return {
        'word': word,
        'hint_text': prompt,
        'hint_image': hint_image_base64,
        'text_generation_time': text_time,
        'image_generation_time': image_time
    }


@bp.route('/generate', methods=['GET'])
@authenticate_user  # Protect this route
def generate_single_hint():
    try:
        word = request.args.get('word')
        pinyin = request.args.get('pinyin')
        translation = request.args.get('translation')

        if not word or not pinyin or not translation:
            return error_response('Missing required parameters: word, pinyin, translation', 400)

        start_total = time.time()
        result = process_single_hint(word, pinyin, translation)
        result['total_time'] = time.time() - start_total

        return success_response(result)

    except RuntimeError as e:
        logger.error(f"RuntimeError generate_single_hint: {e}", exc_info=True)
        return error_response(f"Initialization error: {str(e)}", 500)
    except Exception as e:
        logger.error(f"Error generate_single_hint: {e}", exc_info=True)
        return error_response(f"Error generating hint: {str(e)}", 500)

@bp.route('/generate_multiple', methods=['POST'])
@authenticate_user  # Protect this route
def generate_multiple_hints():
    try:
        data = request.json
        if not data or not isinstance(data, list):
            return error_response('Invalid input format', 400)

        start_total = time.time()
        results = []

        with concurrent.futures.ThreadPoolExecutor(max_workers=Config.PARALLELISM_LIMIT) as executor:
            future_to_word = {
                executor.submit(process_single_hint, entry['word'], entry['pinyin'], entry['translation']): entry['word']
                for entry in data
            }
            for future in concurrent.futures.as_completed(future_to_word):
                try:
                    results.append(future.result())
                except Exception as e:
                    logger.error(f"Error generating images: {e}", exc_info=True)
                    return error_response(f"Error generating images: {str(e)}", 500)

        response_time = time.time() - start_total
        return success_response({
            'hints': results,
            'total_time': response_time
        })

    except RuntimeError as e:
        logger.error(f"RuntimeError generate_multiple_hints: {e}", exc_info=True)
        return error_response(f"Initialization error: {str(e)}", 500)
    except Exception as e:
        logger.error(f"Error generate_multiple_hints: {e}", exc_info=True)
        return error_response(f"Error generating hints: {str(e)}", 500)
    
@bp.route('/generate_hint', methods=['GET'])
@authenticate_user  # Protect this route
def generate_hint():
    try:
        print("in generate_hint")
        user_id = request.args.get('user_id')
        word_id = request.args.get('word_id')
        force_regenerate = request.args.get('force_regenerate', 'false').lower() == 'true'

        print("force_regenerate=%s" %(force_regenerate))

        if not user_id or not word_id:
            return error_response('Missing required parameters: user_id, word_id', 400)

        # Use the shared validation function to ensure the user is only accessing their own data
        validation_response = validate_user_access(user_id)
        if validation_response:
            return validation_response

        # Fetch or create the UserWord entry
        print ("Trying to find userword with user_id=%s, word_id=%s" %(user_id, word_id))
        userword = UserWord.query.filter_by(user_id=user_id, word_id=word_id).first()
        if not userword:
            # Create a new UserWord entry if it does not exist
            print ("Userword does not exist, creating")

            userword = UserWord(
                user_id=user_id,
                word_id=word_id,
                is_included=True,  # Default value
                recall_state=0,  # Default recall state
                is_included_change_time=datetime.utcnow()
            )
            db.session.add(userword)
            db.session.commit()

        # Check if regeneration is needed
        print ("Check if regenerate is needed: hint_text=%s, hint_img=%s" %(userword.hint_text, userword.hint_img))
        if userword.hint_text and userword.hint_img and not force_regenerate:
            
            # Convert BLOB to base64 string instead of UTF-8 decoding
            hint_image_base64 = base64.b64encode(userword.hint_img).decode('utf-8')
            print ("hint_image_base64: %s" %(hint_image_base64))
            return success_response({
                'hint_text': userword.hint_text,
                'hint_image': hint_image_base64
            })

        # Fetch the Word entry
        word_entry = Word.query.filter_by(word_id=word_id).first()
        if not word_entry:
            return error_response('Word entry not found', 404)

        # Generate new hint text and image
        start_total = time.time()
        hint_result = process_single_hint(word_entry.word, word_entry.def1, word_entry.def2)
        hint_text = hint_result['hint_text']
        hint_img = hint_result['hint_image']

        # Update UserWord with new hint_text and hint_img
        userword.hint_text = hint_text
        userword.hint_img = base64.b64decode(hint_img)
        db.session.commit()

        response_time = time.time() - start_total
        return success_response({
            'hint_text': hint_text,
            'hint_image': hint_img,
            'total_time': response_time
        })

    except Exception as e:
        logger.error(f"Error generate_hint: {e}", exc_info=True)
        return error_response(f"Error generating hint: {str(e)}", 500)
