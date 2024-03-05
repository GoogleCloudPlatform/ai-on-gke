# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import google.cloud.language as language
from .retry import retry

# Convert the project id into a full resource id.
parent = os.environ.get('PROJECT_ID', 'NULL')

# Instantiate a nlp client.
nature_language_client = language.LanguageServiceClient()

def is_nlp_api_enabled():
  if parent == 'NULL':
    return False
  # Check if the DLP API is enabled
  try:
    sum_moderation_confidences("test")
    return True
  except Exception as e:
    print(f"Error: {e}")
    return False

def sum_moderation_confidences(text):
  document = language.types.Document(
      content=text, type_=language.types.Document.Type.PLAIN_TEXT
  )

  request = language.ModerateTextRequest(
      document=document,
  )
  # Detects the sentiment of the text
  response = nature_language_client.moderate_text(
      request=request, retry=retry.retry_policy
  )

  # Parse response and sum the confidences of moderation, the categories are from https://cloud.google.com/natural-language/docs/moderating-text
  total_confidence = 0.0
  categories = []
  for category in response.moderation_categories:
    total_confidence += category.confidence
    categories.append(category.name)
  return total_confidence, categories

def is_content_inappropriate(text, nlp_filter_level):
  # Define thresholds
  thresholds = {
      'low': 1.0,  # 100% confidence for low sensitivity
      'mid': 0.5,  # 50% confidence for medium sensitivity
      'high': 0.2,  # 20% confidence for high sensitivity
  }

  # Map the filter level to a threshold
  if nlp_filter_level <= 20:
    threshold = thresholds['high']
  elif nlp_filter_level <= 50:
    threshold = thresholds['mid']
  else:
    threshold = thresholds['low']
  return sum_moderation_confidences(text) > threshold
