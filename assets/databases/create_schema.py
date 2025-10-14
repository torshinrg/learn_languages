#!/usr/bin/env python3
"""
Appwrite schema bootstrap (SDK-compatible) for language-learning books.

- Reads config from .env with keys:
    APPWRITE_ENDPOINT=
    APPWRITE_PROJECT=
    APPWRITE_API_KEY=
    APPWRITE_DATABASE_ID=
    NEW_SENTENCE_TOKENS_ID=   # optional (default: sentence_tokens)
    NEW_WORD_TRANSLATIONS_ID= # optional (default: word_translations)

- Creates/updates:
    sentence_tokens, word_translations
    extra attrs & indexes on reading_materials, sentences, words, user_word_status

Requires:
  pip install appwrite python-dotenv
"""

import os
from dotenv import load_dotenv
from appwrite.client import Client
from appwrite.services.databases import Databases
from appwrite.id import ID
from appwrite.exception import AppwriteException

# ------------------ Load .env ------------------
load_dotenv()

def need(key: str, default: str | None = None) -> str:
    val = os.getenv(key, default)
    if val is None or str(val).strip() == "":
        raise SystemExit(f"Missing required config '{key}' in .env")
    return val

ENDPOINT = need("APPWRITE_ENDPOINT")
PROJECT  = need("APPWRITE_PROJECT")
API_KEY  = need("APPWRITE_API_KEY")
DB_ID    = need("APPWRITE_DATABASE_ID")

NEW_SENTENCE_TOKENS_ID   = os.getenv("NEW_SENTENCE_TOKENS_ID", "sentence_tokens")
NEW_WORD_TRANSLATIONS_ID = os.getenv("NEW_WORD_TRANSLATIONS_ID", "word_translations")

# ------------------ Appwrite client ------------------
client = (
    Client()
    .set_endpoint(ENDPOINT)
    .set_project(PROJECT)
    .set_key(API_KEY)
)
db = Databases(client)

# ------------------ Helpers ------------------

def get_collection_id_by_name(name: str):
    res = db.list_collections(database_id=DB_ID)
    for c in res["collections"]:
        if c["name"] == name:
            return c["$id"]
    return None

def ensure_collection(collection_id: str, name: str, read_any: bool = True):
    # Return existing or create new
    try:
        col = db.get_collection(DB_ID, collection_id)
        return col["$id"]
    except AppwriteException:
        pass

    existing = get_collection_id_by_name(name)
    if existing:
        return existing

    perms = ['read("any")'] if read_any else []
    try:
        col = db.create_collection(
            database_id=DB_ID,
            collection_id=collection_id if collection_id else ID.unique(),
            name=name,
            permissions=perms,
            document_security=False,
            enabled=True
        )
        return col["$id"]
    except AppwriteException as e:
        if e.code == 409:
            return get_collection_id_by_name(name)
        raise

def swallow(f, *args, **kwargs):
    try:
        return f(*args, **kwargs)
    except AppwriteException as e:
        # Ignore "already exists"/duplicate index/duplicate attr, etc.
        if e.code in (409, 400):
            return None
        raise

def ensure_string_attr(col_id, key, size=128, required=False, array=False):
    swallow(db.create_string_attribute, DB_ID, col_id, key, size, required, array)

def ensure_integer_attr(col_id, key, required=False, min_val=-9223372036854775808, max_val=9223372036854775807, array=False, default=None):
    swallow(db.create_integer_attribute, DB_ID, col_id, key, required, min_val, max_val, array, default)

def ensure_index(col_id, key, type_, attributes, lengths=None, orders=None):
    if lengths is None:
        lengths = [0] * len(attributes)
    if orders is None:
        orders = [None] * len(attributes)
    swallow(db.create_index, DB_ID, col_id, key, type_, attributes, lengths, orders)

def ensure_relationship_attr(col_id, key, related_col_id, rel_type="manyToOne",
                             two_way=False, two_way_key=None, on_delete="setNull",
                             side="parent"):
    """
    Appwrite Python SDK has changed signatures over versions.
    We try a kwargs-style call first (newer SDK), then a positional fallback (older SDK).
    NOTE: Relationship attributes in Appwrite do NOT support 'required'.
    """
    # Attempt 1: keyword-args (newer SDKs)
    try:
        return db.create_relationship_attribute(
            database_id=DB_ID,
            collection_id=col_id,
            related_collection_id=related_col_id,
            type=rel_type,
            two_way=two_way,
            key=key,
            two_way_key=two_way_key,
            on_delete=on_delete,
            side=side,
        )
    except TypeError:
        # Attempt 2: positional (older SDKs): (db_id, col_id, related_col_id, type, two_way, key, two_way_key, on_delete[, side])
        try:
            return db.create_relationship_attribute(
                DB_ID, col_id, related_col_id, rel_type, two_way, key, two_way_key, on_delete, side
            )
        except TypeError:
            # Attempt 3: positional without 'side'
            return db.create_relationship_attribute(
                DB_ID, col_id, related_col_id, rel_type, two_way, key, two_way_key, on_delete
            )
    except AppwriteException as e:
        if e.code in (409, 400):
            return None
        raise

# ------------------ Locate core collections ------------------
words_id             = get_collection_id_by_name("words")                 or "686c67d800103afca060"
sentences_id         = get_collection_id_by_name("sentences")             or "686c6bef001892379efa"
languages_id         = get_collection_id_by_name("languages")             or "686da5820011a3e3cde8"
reading_materials_id = get_collection_id_by_name("reading_materials")     or "686daa12002cd5d38a9a"
user_word_status_id  = get_collection_id_by_name("user_word_status")      or "686dbee10039c42a91f9"

for cid, name in [
    (words_id, "words"),
    (sentences_id, "sentences"),
    (languages_id, "languages"),
    (reading_materials_id, "reading_materials"),
    (user_word_status_id, "user_word_status"),
]:
    try:
        db.get_collection(DB_ID, cid)
    except AppwriteException as e:
        raise SystemExit(f"Required existing collection '{name}' not found (id: {cid}). {e}")

# ------------------ Create NEW collections ------------------
sentence_tokens_id   = ensure_collection(NEW_SENTENCE_TOKENS_ID, "sentence_tokens", read_any=True)
word_translations_id = ensure_collection(NEW_WORD_TRANSLATIONS_ID, "word_translations", read_any=True)

# sentence_tokens attributes
ensure_relationship_attr(sentence_tokens_id, "sentence", sentences_id, rel_type="manyToOne", on_delete="cascade", side="parent")
ensure_relationship_attr(sentence_tokens_id, "readingMaterial", reading_materials_id, rel_type="manyToOne", on_delete="cascade", side="parent")
ensure_integer_attr(sentence_tokens_id, "position", required=True, min_val=0, max_val=2_000_000_000)
ensure_string_attr(sentence_tokens_id, "surface", size=64, required=True)
ensure_string_attr(sentence_tokens_id, "lemma", size=64, required=True)
ensure_integer_attr(sentence_tokens_id, "startMs", required=True, min_val=0, max_val=2_147_483_647)
ensure_integer_attr(sentence_tokens_id, "endMs", required=True, min_val=0, max_val=2_147_483_647)
ensure_string_attr(sentence_tokens_id, "pos", size=16, required=False)
ensure_string_attr(sentence_tokens_id, "morph", size=64, required=False)
ensure_relationship_attr(sentence_tokens_id, "word", words_id, rel_type="manyToOne", on_delete="setNull", side="parent")

# sentence_tokens indexes
ensure_index(sentence_tokens_id, "idx_sentence_pos", "unique", ["sentence", "position"])
ensure_index(sentence_tokens_id, "idx_lemma", "key", ["lemma"])
ensure_index(sentence_tokens_id, "idx_surface", "key", ["surface"])
ensure_index(sentence_tokens_id, "idx_rm", "key", ["readingMaterial"])

# word_translations attributes
ensure_relationship_attr(word_translations_id, "word", words_id, rel_type="manyToOne", on_delete="cascade", side="parent")
ensure_relationship_attr(word_translations_id, "uiLanguage", languages_id, rel_type="manyToOne", on_delete="restrict", side="parent")
ensure_string_attr(word_translations_id, "sense", size=255, required=True)
ensure_integer_attr(word_translations_id, "senseOrder", required=False, min_val=0, max_val=1000)
ensure_string_attr(word_translations_id, "source", size=64, required=False)
ensure_string_attr(word_translations_id, "license", size=64, required=False)

# word_translations indexes
ensure_index(word_translations_id, "idx_word", "key", ["word"])
ensure_index(word_translations_id, "idx_ui_lang", "key", ["uiLanguage"])
ensure_index(word_translations_id, "uniq_word_lang_order", "unique", ["word", "uiLanguage", "senseOrder"])

# ------------------ Enrich existing collections ------------------

# reading_materials extra metadata
ensure_string_attr(reading_materials_id, "author", 128, required=False)
ensure_string_attr(reading_materials_id, "narrator", 128, required=False)
ensure_string_attr(reading_materials_id, "license", 64, required=False)
ensure_string_attr(reading_materials_id, "sourceUrl", 255, required=False)
ensure_string_attr(reading_materials_id, "audioStorageId", 64, required=False)
ensure_integer_attr(reading_materials_id, "durationMs", required=False, min_val=0, max_val=2_147_483_647)
ensure_string_attr(reading_materials_id, "slug", 64, required=False)
ensure_index(reading_materials_id, "uniq_slug", "unique", ["slug"])

# sentences: link to reading_materials + order + timings
ensure_relationship_attr(sentences_id, "readingMaterial", reading_materials_id, rel_type="manyToOne", on_delete="setNull", side="parent")
ensure_integer_attr(sentences_id, "order", required=False, min_val=0, max_val=2_000_000_000)
ensure_integer_attr(sentences_id, "startMs", required=False, min_val=0, max_val=2_147_483_647)
ensure_integer_attr(sentences_id, "endMs", required=False, min_val=0, max_val=2_147_483_647)
ensure_index(sentences_id, "idx_rm", "key", ["readingMaterial"])
ensure_index(sentences_id, "idx_rm_order", "key", ["readingMaterial", "order"])

# words: add normalized (canonical/lemma) and unique with language
ensure_string_attr(words_id, "normalized", 64, required=False)
ensure_index(words_id, "uniq_lang_normalized", "unique", ["languages", "normalized"])

# user_word_status: unique per (userId, wordId)
ensure_index(user_word_status_id, "uniq_user_word", "unique", ["userId", "wordId"])

print("✅ Schema bootstrap completed.")
