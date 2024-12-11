<img width="1633" alt="image" src="https://github.com/user-attachments/assets/2db50d59-624c-4d0f-a278-e8f629d354df">

# Architecture
The Lexitrail application is built using React, a popular JavaScript library for building user interfaces. The frontend is structured into components, each responsible for specific parts of the UI. The game logic is handled in React components, which manage state and user interactions.

# Running UI locally

Create .env file inside /ui/ folder. This file will not be saved to git.

```
cd ui/
npm install
npm start
```

# Deploy to cloud
```
cd terraform/
gcloud auth login
gcloud auth application-default login
```


# Create OAuthClientID

## Configure OAuth consent screen
* Go to APs & Services => OAuth consent screen
* Follow the prompts


## Configure client-side credentials
* Go to APIs & Services => Credentials
* Create OAuth client ID
* Application Type => `Web Application`
* Name => `Lexitrail UI`
* Click `Create`
* Save the `client_id` field, update it in the .env file
    ```
    REACT_APP_CLIENT_ID=<YOUR_CLIENT_ID>
    ```

Here is your updated schema with improved descriptions where necessary:

## DB schema

### Table: users

| column   | description               | SQL data type          | Python data type | Notes |
| -------- | ------------------------- | ---------------------- | ---------------- | ----- |
| email    | The user's email address, which is unique across the table. Used as a primary identifier for the user. | `VARCHAR(320) NOT NULL` | `str` | |
  
### Table: wordsets

| column      | description                              | SQL data type    | Python data type | Notes |
| ------------| ---------------------------------------- | ---------------- | ---------------- | ----- |
| wordset_id  | A unique, positive integer that auto-increments for each new wordset. Serves as the primary key for the table. | `INT AUTO_INCREMENT PRIMARY KEY` | `int`        | |
| description | A text field allowing up to 1024 unicode characters, used to describe the wordset. | `VARCHAR(1024) NOT NULL`  | `str`            | No changes needed. |

### Table: words

| column      | description                                               | SQL data type    | Python data type | Notes |
| ------------| --------------------------------------------------------- | ---------------- | ---------------- | ----- |
| word_id     | A unique, positive integer that auto-increments for each new word. Serves as the primary key for the table. | `INT AUTO_INCREMENT PRIMARY KEY` | `int`        | |
| word        | A word or phrase with a maximum length of 256 unicode characters. It is unique within its wordset. | `VARCHAR(256) NOT NULL`   | `str`            | Consider adding a unique constraint to ensure uniqueness within the wordset. |
| wordset_id  | Foreign key referencing the `wordsets.wordset_id`. This links the word to a specific wordset. | `INT NOT NULL`            | `int`            | Should reference `wordsets.wordset_id`. |
| def1        | The first definition of the word, allowing up to 1024 unicode characters. | `VARCHAR(1024) NOT NULL`  | `str`            |  |
| def2        | The second definition of the word, allowing up to 1024 unicode characters. | `VARCHAR(1024) NOT NULL`  | `str`            |  |

### Table: user_words

| column                | description                                               | SQL data type    | Python data type | Notes |
| ----------------------| --------------------------------------------------------- | ---------------- | ---------------- | ----- |
| user_id               | Foreign key referencing `users.email`. This, combined with `word_id`, forms a unique entry for each user's interaction with a word. | `VARCHAR(320) NOT NULL`  | `str`            | Should reference `users.user_id`. |
| word_id               | Foreign key referencing `words.word_id`. | `INT NOT NULL`            | `int`            | Should reference `words.word_id`. |
| is_included           | Boolean value indicating whether the word is included in the user's learning list. | `BOOLEAN NOT NULL` | `bool` | |
| is_included_change_time | Timestamp indicating when the `is_included` flag was last changed. | `TIMESTAMP NOT NULL`      | `datetime`       | Consider specifying `DEFAULT CURRENT_TIMESTAMP`. |
| last_recall           | Nullable boolean value indicating whether the user recalled the word the last time it was attempted. | `BOOLEAN` | `Optional[bool]` | |
| last_recall_time      | Nullable timestamp indicating when the user last attempted to recall the word. | `TIMESTAMP` | `Optional[datetime]` | Consider specifying as `DEFAULT NULL`. |
| recall_state          | Integer representing the recall state, ranging from -10 to 10, with rules to be determined. | `INT NOT NULL` | `int` | |
| hint_img              | Binary large object (BLOB) storing an encoded image that is personal to the user and serves as a reminder for the word. | `BLOB` | `bytes` |  |

### Table: recall_history

| column                | description                                               | SQL data type    | Python data type | Notes |
| ----------------------| --------------------------------------------------------- | ---------------- | ---------------- | ----- |
| user_id               | Foreign key referencing `users.email`. | `VARCHAR(320) NOT NULL`  | `str`            | Should reference `users.user_id`. |
| word_id               | Foreign key referencing `words.word_id`. | `INT NOT NULL`            | `int`            | Should reference `words.word_id`. |
| is_included           | Boolean value indicating whether the word was included in the user's learning list at the time of recall. | `BOOLEAN NOT NULL` | `bool` |  |
| recall                | Boolean value indicating whether the user recalled the word or not. | `BOOLEAN NOT NULL`        | `bool`            |  |
| recall_time           | Timestamp indicating when the user attempted to recall the word. | `TIMESTAMP NOT NULL` | `datetime` | Consider specifying `DEFAULT CURRENT_TIMESTAMP`. |
| old_recall_state      | Integer representing the recall state before the recall attempt. | `INT NOT NULL` | `int` |  |
| new_recall_state      | Integer representing the recall state after the recall attempt. | `INT NOT NULL` | `int` |  |

These descriptions should help clarify the purpose of each column in the schema, making your README more informative and easier to understand.


# Validate

```bash
PROJECT_ID=alexbu-gke-dev-d
gcloud container clusters get-credentials lexitrail-cluster --location=us-central1
gcloud iam service-accounts get-iam-policy lexitrail-storage-sa@alexbu-gke-dev-d.iam.gserviceaccount.com
gcloud projects get-iam-policy alexbu-gke-dev-d --flatten="bindings[].members" --filter="bindings.members:serviceAccount:lexitrail-storage-sa@alexbu-gke-dev-d.iam.gserviceaccount.com"

kubectl run -it --rm   debug-gcs1   --namespace=mysql   --image=google/cloud-sdk:slim   --restart=Never --timeout=5m   --overrides='{
    "spec": {
      "serviceAccountName": "default"
    }
  }'   -- sh

```

Then after getting in:
```bash
gsutil ls gs://alexbu-gke-dev-d-lexitrail-mysql-files
gcloud auth list

```


# Flask Backend API

This Flask API provides CRUD functionality for users, wordsets, words, and userwords, as well as recall state updates with automatic recall history tracking.

## Installation

1. Install the dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Set up the `.env` file in the root directory:
   ```bash
   DATABASE_URL=mysql://username:password@localhost/dbname
   SECRET_KEY=your_secret_key_here
   ```

3. Run the app:
   ```bash
   python run.py
   ```

## API Routes

| **Route**                                | **Method** | **Description**                                                | **Example URL**                               | **Body**                                                 | **Response**                                                                                 |
|------------------------------------------|------------|----------------------------------------------------------------|-----------------------------------------------|----------------------------------------------------------|------------------------------------------------------------------------------------------------|
| `/users`                                 | POST       | Create a new user                                               | `/users`                                      | `{ "email": "user@example.com" }`                         | `{ "message": "User created successfully" }`                                                    |
| `/users`                                 | GET        | Retrieve all users                                              | `/users`                                      | N/A                                                      | `[{"email": "user1@example.com"}, {"email": "user2@example.com"}]`                              |
| `/users/<email>`                         | GET        | Retrieve a user by email                                        | `/users/user@example.com`                     | N/A                                                      | `{ "email": "user@example.com" }`                                                               |
| `/users/<email>`                         | PUT        | Update a user's email                                           | `/users/user@example.com`                     | `{ "email": "newemail@example.com" }`                     | `{ "message": "User updated successfully" }`                                                    |
| `/users/<email>`                         | DELETE     | Delete a user                                                   | `/users/user@example.com`                     | N/A                                                      | `{ "message": "User deleted successfully" }`                                                    |
| `/wordsets`                              | GET        | Retrieve all wordsets                                           | `/wordsets`                                   | N/A                                                      | `[{"wordset_id": 1, "description": "Basic Vocabulary"}]`                                         |
| `/wordsets/<wordset_id>/words`           | GET        | Retrieve all words for a wordset                                | `/wordsets/1/words`                           | N/A                                                      | `[{"word_id": 1, "word": "apple", "def1": "A fruit", "def2": "A tech company"}]`                 |
| `/userwords/query`                       | GET        | Retrieve userwords for a user and wordset                       | `/userwords/query?user_id=user&wordset_id=1`  | N/A                                                      | `[{"user_id": "user", "word_id": 1, "recall_state": 2}]`                                        |
| `/userwords/<user_id>/<word_id>/recall`  | PUT        | Update recall state for a userword                              | `/userwords/user/1/recall`                    | `{ "recall": true, "recall_state": 3, "is_included": true }` | `{ "message": "Recall state and recall updated successfully" }`                                 |



### Running Backend Unit Tests

1. **Create and Activate a Virtual Environment**  
   Create a virtual environment and activate it:

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
```

2. **Install Dependencies**  
   Install the required dependencies:

```bash
pip install -r requirements.txt
```

3. **Port-forward to connect to mysql db**

```bash
gcloud auth login
gcloud container clusters get-credentials lexitrail-cluster --location=us-central1
kubectl port-forward svc/mysql 3306:3306 -n mysql
```

4. **Ensure connection to db**

```bash
# Load environment variables from the parent directory's .env file
if [ -f ../.env ]; then
   echo "Loading environment variables from ../.env file..."
   export $(grep -v '^#' ../.env | xargs)
else
   echo "Error: .env file not found in the parent directory!"
   exit 1
fi

# Check if db_root_password is set
if [ -z "$DB_ROOT_PASSWORD" ]; then
   echo "Error: db_root_password not set in the .env file!"
   exit 1
fi
mysql -u root -p"$DB_ROOT_PASSWORD" -h 127.0.0.1 -P 3306 -e "SHOW DATABASES;"
```

3. **Run Unit Tests**  
   With the `.env` file already set up at the root level, run the tests:

```bash
pytest
# or other examples:
pytest tests/test_users.py::UserTests::test_create_user
pytest tests/test_userwords.py::UserWordTests
pytest tests/test_words.py::WordTests
pytest tests/test_wordsets.py::WordSetTests

```

4. **Deactivate the Virtual Environment**  
   Once finished, deactivate the virtual environment:

```bash
deactivate
```


### Local DB & UI Development

1. **Port-forward to connect to mysql db**
```bash
gcloud auth login
gcloud container clusters get-credentials lexitrail-cluster --location=us-central1
kubectl port-forward svc/mysql 3306:3306 -n mysql
```

2. **Launch python backend locally**

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
python run.py

# validate
curl -v http://localhost:5001/wordsets
```

2. **Launch UI locally**

```bash
cd UI
npm start

# validate
curl -v http://localhost:5001/wordsets
```


### Env file settings


PROJECT_ID=
CLUSTER_NAME=
DB_ROOT_PASSWORD=
MYSQL_FILES_BUCKET=
SQL_NAMESPACE=
DATABASE_NAME=
GOOGLE_CLIENT_ID=
PROJECT_ID=
LOCATION=


### Lexitrailcmdutil instructions

* Step 1: Port-forward to connect to MySQL database
```
gcloud auth login
gcloud auth application-default login
gcloud container clusters get-credentials lexitrail-cluster --location=us-central1
kubectl port-forward svc/mysql 3306:3306 -n mysql

```

* Step 2: Launch Python backend locally
```
cd backend
python3 -m venv venv
source venv/bin/activate
python scripts/lexitrailcmd.py [function]
```






