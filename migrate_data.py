import os
import sqlite3
from appwrite.client import Client
from appwrite.services.databases import Databases
from appwrite.id import ID
from appwrite.query import Query
from dotenv import load_dotenv
import uuid
import asyncio

# Load environment variables
load_dotenv()

APPWRITE_ENDPOINT = os.getenv('APPWRITE_ENDPOINT')
APPWRITE_PROJECT_ID = os.getenv('APPWRITE_PROJECT_ID')
APPWRITE_ADMIN_KEY = os.getenv('APPWRITE_ADMIN_KEY')
APPWRITE_DATABASE_ID = '686c67840007e0dd589f' # Your specified database ID

LOCAL_DB_PATH = '/home/rus/personal/projects/learn_languages/assets/databases/lang_data.db'

# Appwrite Collection IDs (replace with actual IDs if different in your Appwrite project)
# These are the IDs from your previous Appwrite schema output.
APPWRITE_COLLECTION_IDS = {
    'languages': '686da5820011a3e3cde8',
    'words': '686c67d800103afca060',
    'sentences': '686c6bef001892379efa',
    'word_sentence_links': '686da90c002dfb68b114', # Not directly populated by this script
    'tasks': '686dc239001f86d73af8',
    'task_translations': 'task_translations_collection_id', # You need to create this collection in Appwrite
}

# --- Helper to get or create Appwrite document ---
async def get_or_create_document(databases_service, collection_id, data, unique_key_field=None):
    try:
        # Attempt to find existing document if unique_key_field is provided
        if unique_key_field:
            query_value = data[unique_key_field]
            try:
                # Debug print: Check type before await
                print(f"DEBUG: Type of databases_service.list_documents before await: {type(databases_service.list_documents)}")
                docs = await databases_service.list_documents(
                    database_id=APPWRITE_DATABASE_ID,
                    collection_id=collection_id,
                    queries=[Query.equal(unique_key_field, [query_value])]
                )
                if docs['documents']:
                    print(f"  Found existing {collection_id} document for {unique_key_field}={query_value}")
                    return docs['documents'][0]
            except Exception as e:
                print(f"Error during list_documents for {collection_id} with query {unique_key_field}={query_value}: {e}")
                import traceback
                traceback.print_exc()
                # Fall through to create if listing fails
        
        # If not found or no unique_key_field, create a new one
        # Debug print: Check type before await
        print(f"DEBUG: Type of databases_service.create_document before await: {type(databases_service.create_document)}")
        doc = await databases_service.create_document(
            database_id=APPWRITE_DATABASE_ID,
            collection_id=collection_id,
            document_id=ID.unique(),
            data=data
        )
        print(f"  Created new {collection_id} document: {doc['$id']}")
        return doc
    except Exception as e:
        print(f"Error in get_or_create_document for {collection_id} with data {data}: {e}")
        import traceback
        traceback.print_exc() # Print full traceback for debugging
        return None

# --- Main Migration Function ---
async def migrate_data():
    if not all([APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, APPWRITE_ADMIN_KEY]):
        print("Error: Missing Appwrite environment variables. Check your .env file.")
        return

    if not os.path.exists(LOCAL_DB_PATH):
        print(f"Error: Local database not found at {LOCAL_DB_PATH}")
        return

    # --- Appwrite Client Setup (inside async function) ---
    client = Client()
    (client
        .set_endpoint(APPWRITE_ENDPOINT)
        .set_project(APPWRITE_PROJECT_ID)
        .set_key(APPWRITE_ADMIN_KEY)
    )
    databases_service = Databases(client)

    conn = sqlite3.connect(LOCAL_DB_PATH)
    cursor = conn.cursor()

    print(f"DEBUG: Type of databases_service object: {type(databases_service)}")
    print(f"DEBUG: Type of databases_service.list_documents: {type(databases_service.list_documents)}")

    # --- 1. Migrate Languages ---
    print("\n--- Migrating Languages ---")
    language_map = {} # Local code -> Appwrite language ID
    
    # Define languages based on your *_words tables
    languages_to_migrate = {
        'en': 'English', 'es': 'Spanish', 'fr': 'French',
        'de': 'German', 'it': 'Italian', 'pt': 'Portuguese', 'ru': 'Russian'
    }

    for code, name in languages_to_migrate.items():
        lang_data = {'code': code, 'name': name}
        appwrite_lang = await get_or_create_document(
            databases_service, # Pass the service instance
            APPWRITE_COLLECTION_IDS['languages'], 
            lang_data, 
            unique_key_field='code'
        )
        if appwrite_lang:
            language_map[code] = appwrite_lang['$id']
            print(f"  Mapped local '{code}' to Appwrite ID: {appwrite_lang['$id']}")
        else:
            print(f"  Failed to migrate language: {code}")

    # --- 2. Migrate Words ---
    print("\n--- Migrating Words ---")
    # Map local word text + language to Appwrite word ID
    appwrite_word_ids = {} # (text, language_code) -> appwrite_word_id

    for lang_code, appwrite_lang_id in language_map.items():
        table_name = f"{lang_code}_words"
        try:
            cursor.execute(f"SELECT word FROM {table_name}")
            words_data = cursor.fetchall()
            print(f"Processing words from {table_name}...")
            for row in words_data:
                word_text = row[0]
                word_data = {
                    'languageId': appwrite_lang_id,
                    'text': word_text,
                    'frequencyRank': 1 # Placeholder, adjust as needed
                }
                appwrite_word = await get_or_create_document(
                    databases_service, # Pass the service instance
                    APPWRITE_COLLECTION_IDS['words'], 
                    word_data, 
                    unique_key_field='text' # Assuming text is unique per language
                )
                if appwrite_word:
                    appwrite_word_ids[(word_text, lang_code)] = appwrite_word['$id']
                else:
                    print(f"  Failed to migrate word: {word_text} ({lang_code})")
        except sqlite3.OperationalError:
            print(f"  Table {table_name} not found in local DB, skipping.")
        except Exception as e:
            print(f"  Error processing {table_name}: {e}")

    # --- 3. Migrate Sentences ---
    print("\n--- Migrating Sentences ---")
    # First, create a lookup for audio links
    audio_links_lookup = {} # local_sentence_id -> audio_url
    try:
        cursor.execute("SELECT sentence_id, link FROM sentences_with_audio")
        for row in cursor.fetchall():
            audio_links_lookup[row[0]] = row[1]
        print(f"Loaded {len(audio_links_lookup)} audio links.")
    except sqlite3.OperationalError:
        print("Table sentences_with_audio not found, no audio links will be migrated.")

    appwrite_sentence_ids = {} # (local_sentence_id, language_code) -> appwrite_sentence_id

    cursor.execute("PRAGMA table_info(sentences)")
    sentence_columns = [col[1] for col in cursor.fetchall()]
    
    cursor.execute("SELECT * FROM sentences")
    sentences_data = cursor.fetchall()
    
    for row in sentences_data:
        local_row_data = dict(zip(sentence_columns, row))
        group_id = str(uuid.uuid4()) # Link all language versions of this sentence

        for lang_code, appwrite_lang_id in language_map.items():
            local_id_col = f"{lang_code}_id"
            local_text_col = f"{lang_code}_text"
            
            local_sentence_id = local_row_data.get(local_id_col)
            sentence_text = local_row_data.get(local_text_col)

            if sentence_text and local_sentence_id:
                audio_url = audio_links_lookup.get(local_sentence_id)
                
                sentence_data = {
                    'languageId': appwrite_lang_id,
                    'content': sentence_text,
                    'audioUrl': audio_url,
                    'groupId': group_id,
                    # Add other fields if they exist in Appwrite and you have data
                    # 'source': local_row_data.get('source_col_name'),
                    # 'normalizedWords': local_row_data.get('normalizedWords_col_name'),
                    # 'licence': local_row_data.get('licence_col_name'),
                }
                appwrite_sentence = await get_or_create_document(
                    databases_service, # Pass the service instance
                    APPWRITE_COLLECTION_IDS['sentences'], 
                    sentence_data,
                    unique_key_field='content' # Assuming content is unique per language
                )
                if appwrite_sentence:
                    appwrite_sentence_ids[(local_sentence_id, lang_code)] = appwrite_sentence['$id']
                else:
                    print(f"  Failed to migrate sentence: {sentence_text} ({lang_code})")
            # else:
            #     print(f"  Skipping sentence for {lang_code} due to missing ID or text.")

    # --- 4. Migrate Tasks and Task Translations ---
    print("\n--- Migrating Tasks and Task Translations ---")
    try:
        cursor.execute("SELECT id, description, locale, task_type FROM tasks")
        tasks_data = cursor.fetchall()
        for row in tasks_data:
            local_task_id, description, locale, task_type = row
            
            # Migrate to Appwrite 'tasks' collection
            task_data = {
                'type': task_type,
                'promptTemplate': description,
            }
            appwrite_task = await get_or_create_document(
                databases_service, # Pass the service instance
                APPWRITE_COLLECTION_IDS['tasks'], 
                task_data, 
                unique_key_field='promptTemplate' # Assuming promptTemplate is unique for tasks
            )

            if appwrite_task:
                # Migrate to Appwrite 'task_translations' collection
                translation_data = {
                    'taskId': appwrite_task['$id'],
                    'languageCode': locale,
                    'promptTemplate': description,
                }
                await get_or_create_document(
                    databases_service, # Pass the service instance
                    APPWRITE_COLLECTION_IDS['task_translations'], 
                    translation_data,
                    unique_key_field='taskId' # Assuming one translation per task per language
                )
            else:
                print(f"  Failed to migrate task: {description}")

    except sqlite3.OperationalError:
        print("Table tasks not found in local DB, skipping task migration.")
    except Exception as e:
        print(f"  Error processing tasks: {e}")

    conn.close()
    print("\nMigration process completed.")

if __name__ == "__main__":
    asyncio.run(migrate_data())