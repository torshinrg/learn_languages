import os
from appwrite.client import Client
from appwrite.services.databases import Databases
from appwrite.query import Query

# Load environment variables
from dotenv import load_dotenv
load_dotenv()

APPWRITE_ENDPOINT = os.getenv('APPWRITE_ENDPOINT')
APPWRITE_PROJECT_ID = os.getenv('APPWRITE_PROJECT_ID')
APPWRITE_ADMIN_KEY = os.getenv('APPWRITE_ADMIN_KEY')
APPWRITE_DATABASE_ID = '686c67840007e0dd589f' # Your specified database ID

if not all([APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, APPWRITE_ADMIN_KEY, APPWRITE_DATABASE_ID]):
    print("Error: Missing Appwrite environment variables. Make sure APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, APPWRITE_ADMIN_KEY are set in your .env file, and APPWRITE_DATABASE_ID is correct.")
    exit(1)

client = Client()
(client
    .set_endpoint(APPWRITE_ENDPOINT)
    .set_project(APPWRITE_PROJECT_ID)
    .set_key(APPWRITE_ADMIN_KEY)
)

databases = Databases(client)

def get_appwrite_schema():
    print(f"Fetching schema for database ID: {APPWRITE_DATABASE_ID}")
    try:
        collections_list = databases.list_collections(database_id=APPWRITE_DATABASE_ID)
        
        schema = {}
        for collection in collections_list['collections']:
            collection_id = collection['$id']
            collection_name = collection['name']
            print(f"\nCollection: {collection_name} (ID: {collection_id})")
            
            attributes_list = databases.list_attributes(
                database_id=APPWRITE_DATABASE_ID,
                collection_id=collection_id
            )
            
            collection_attributes = []
            for attribute in attributes_list['attributes']:
                attr_name = attribute['key']
                attr_type = attribute['type']
                attr_required = attribute['required']
                collection_attributes.append({
                    'name': attr_name,
                    'type': attr_type,
                    'required': attr_required
                })
                print(f"  - {attr_name} ({attr_type}, Required: {attr_required})")
            
            schema[collection_name] = {
                'id': collection_id,
                'attributes': collection_attributes
            }
        return schema
    except Exception as e:
        print(f"An error occurred while fetching Appwrite schema: {e}")
        return None

if __name__ == "__main__":
    appwrite_schema = get_appwrite_schema()
    if appwrite_schema:
        print("\n--- Appwrite Schema Summary ---")
        for col_name, col_info in appwrite_schema.items():
            print(f"Collection: {col_name} (ID: {col_info['id']})")
            for attr in col_info['attributes']:
                print(f"  - {attr['name']} ({attr['type']}, Required: {attr['required']})")
