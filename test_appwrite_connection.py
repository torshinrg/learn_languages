import os
from appwrite.client import Client
from appwrite.services.databases import Databases
from appwrite.id import ID
from dotenv import load_dotenv

load_dotenv()

APPWRITE_ENDPOINT = os.getenv('APPWRITE_ENDPOINT')
APPWRITE_PROJECT_ID = os.getenv('APPWRITE_PROJECT_ID')
APPWRITE_ADMIN_KEY = os.getenv('APPWRITE_ADMIN_KEY')
APPWRITE_DATABASE_ID = '686c67840007e0dd589f' # Your specified database ID
TEST_COLLECTION_ID = '686c67d800103afca060' # Using your words collection ID for a simple test

def test_connection():
    if not all([APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, APPWRITE_ADMIN_KEY]):
        print("Error: Missing Appwrite environment variables. Check your .env file.")
        return

    client = Client()
    (client
        .set_endpoint(APPWRITE_ENDPOINT)
        .set_project(APPWRITE_PROJECT_ID)
        .set_key(APPWRITE_ADMIN_KEY)
    )
    databases = Databases(client)

    print(f"Attempting to list documents from collection {TEST_COLLECTION_ID}...")
    try:
        documents = databases.list_documents(
            database_id=APPWRITE_DATABASE_ID,
            collection_id=TEST_COLLECTION_ID,
        )
        print(f"Successfully listed documents: {documents}")
    except Exception as e:
        print(f"Failed to list documents: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_connection()
