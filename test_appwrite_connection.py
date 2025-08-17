import os
from appwrite.client import Client
from appwrite.services.databases import Databases
from appwrite.id import ID
from dotenv import load_dotenv
import asyncio

load_dotenv()

APPWRITE_ENDPOINT = os.getenv('APPWRITE_ENDPOINT')
APPWRITE_PROJECT_ID = os.getenv('APPWRITE_PROJECT_ID')
APPWRITE_ADMIN_KEY = os.getenv('APPWRITE_ADMIN_KEY')
APPWRITE_DATABASE_ID = '686c67840007e0dd589f' # Your specified database ID
TEST_COLLECTION_ID = '686da5820011a3e3cde8' # Using your languages collection ID for a simple test

async def test_connection():
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

    print(f"Attempting to create a test document in collection {TEST_COLLECTION_ID}...")
    try:
        test_data = {"code": "test", "name": "Test Language"}
        doc = await databases.create_document(
            database_id=APPWRITE_DATABASE_ID,
            collection_id=TEST_COLLECTION_ID,
            document_id=ID.unique(),
            data=test_data
        )
        print(f"Successfully created test document: {doc['$id']}")
        # Optionally, delete the test document
        # await databases.delete_document(
        #     database_id=APPWRITE_DATABASE_ID,
        #     collection_id=TEST_COLLECTION_ID,
        #     document_id=doc['$id']
        # )
        # print(f"Successfully deleted test document: {doc['$id']}")
    except Exception as e:
        print(f"Failed to create test document: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_connection())
