import csv
import os

# Define the input files and output files
hsk_files = ["HSK1.csv", "HSK2.csv", "HSK3.csv", "HSK4.csv", "HSK5.csv", "HSK6.csv"]
wordsets_output_file = "wordsets.csv"
words_output_file = "words.csv"

# Prepare the wordsets.csv file content
wordsets_data = []
words_data = []
word_id_counter = 1  # Start word_id at 1

# Loop through each HSK file and process them
for idx, hsk_file in enumerate(hsk_files, start=1):
    wordset_name = f"HSK{idx}"
    
    # Add the wordset information to wordsets.csv
    wordsets_data.append([idx, wordset_name])

    with open(hsk_file, newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        
        # Process each row in the HSK file and prepare the words.csv data
        for row in reader:
            word = row['Chinese']
            def1 = row['Pinyin']
            def2 = row['English']
            words_data.append([word_id_counter, word, idx, def1, def2])  # Increment word_id
            word_id_counter += 1  # Auto-increment word_id

# Write to wordsets.csv
with open(wordsets_output_file, mode='w', newline='', encoding='utf-8') as wordsets_file:
    writer = csv.writer(wordsets_file)
    writer.writerow(['wordset_id', 'description'])  # Write header
    writer.writerows(wordsets_data)

# Write to words.csv
with open(words_output_file, mode='w', newline='', encoding='utf-8') as words_file:
    writer = csv.writer(words_file)
    writer.writerow(['word_id', 'word', 'wordset_id', 'def1', 'def2'])  # Write header
    writer.writerows(words_data)

print(f"Generated {wordsets_output_file} and {words_output_file} successfully.")
