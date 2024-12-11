import csv
from .logging_setup import log_info

def load_word_data(wordsets_path, words_path):
    """
    Load both wordset descriptions and word data from CSV files, returning a dictionary 
    structured to meet the requirements of `process_entries` in `wordset_processing.py`.

    Parameters:
        wordsets_path (str): Path to the wordsets CSV file.
        words_path (str): Path to the words CSV file.

    Returns:
        dict: A dictionary where keys are wordset descriptions, each mapped to another dictionary.
              The inner dictionary maps words to their definitions (e.g., {"word": {"def1": "", "def2": ""}}).
    """
    # Step 1: Load wordset descriptions from wordsets CSV file
    id_to_description = {}
    description_data = {}
    
    log_info(f"Loading wordset descriptions from {wordsets_path}")
    
    with open(wordsets_path, mode='r', encoding='utf-8') as file:
        csv_reader = csv.DictReader(file)
        for row in csv_reader:
            wordset_id = row['wordset_id'].strip()
            description = row['description'].strip()
            if wordset_id and description:
                id_to_description[wordset_id] = description
                description_data[description] = {}  # Prepare a nested dict for each wordset description

    log_info(f"Loaded {len(description_data)} wordset descriptions.")
    #log_info(f"Example descriptions (first 1): {list(description_data.keys())[:1]}")
    
    # Step 2: Load words and definitions, grouped by wordset description
    log_info(f"Loading word data from {words_path}")
    
    with open(words_path, mode='r', encoding='utf-8') as file:
        csv_reader = csv.DictReader(file)
        for row in csv_reader:
            wordset_id = row['wordset_id'].strip()
            word = row['word'].strip()
            def1 = row.get('def1', '').strip()
            def2 = row.get('def2', '').strip()

            # Map word to its corresponding wordset description
            description = id_to_description.get(wordset_id)
            
            if description:
                if word:  # Only add words that are present
                    if description not in description_data:
                        description_data[description] = {}
                    description_data[description][word] = {"def1": def1, "def2": def2}

    # Step 3: Logging and return
    log_info(f"Loaded {len(description_data)} wordsets with word definitions.")
    #for desc, words in list(description_data.items())[:1]:  # Log example wordsets and words
    #    example_words = list(words.items())[:1]  # Limit to 1 examples per wordset for brevity
    #    log_info(f"Wordset '{desc}' with {len(words)} words, examples: {example_words}")
    
    return description_data
