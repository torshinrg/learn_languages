#!/usr/bin/env python3
import os, sqlite3, json, re, time, random, uuid, requests
from datetime import datetime
from appwrite.client import Client
from appwrite.services.databases import Databases
from appwrite.id import ID
from appwrite.query import Query
from appwrite.exception import AppwriteException

# ─────────────────────────────────────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────────────────────────────────────
ENDPOINT       = "https://nyc.cloud.appwrite.io/v1"
PROJECT_ID     = "686c65a5003935416060"
API_KEY        = "standard_20a29f5de14fd7f0cbd4ccef438573f1b0eaff3beea5495f2a416f6670d3aa2f75ade0f53ef01ea5cccf6817981e5a4b9ba4e10f973d0821189f51f103d8d1db0288c21b4949c30a5bb14535b3c4ef0a48e2326f5c5ecd5f00fab7cc31243773be536ae1fb5e0250bd640ce6df1470bb87804156034a36e1ffa6fd6eaf0d5c01"

SQLITE_FILE    = "lang_data.db"
CACHE_FILE     = "migration_cache.json"

DB_ID                    = "686c67840007e0dd589f"
COL_LANGUAGES            = "686da5820011a3e3cde8"
COL_WORDS                = "686c67d800103afca060"
COL_SENTENCES            = "686c6bef001892379efa"
COL_TASKS                = "686dc239001f86d73af8"

MAX_RETRIES       = 10
BASE_DELAY_SEC    = 0.6
HTTP_CONN_TIMEOUT = 15
HTTP_READ_TIMEOUT = 90
EXAMPLES_PER_WORD = 12
HEARTBEAT_EVERY   = 5000

_session = requests.Session()
_session.headers.update({
    "X-Appwrite-Project": PROJECT_ID,
    "X-Appwrite-Key": API_KEY,
    "Content-Type": "application/json"
})

# ─────────────────────────────────────────────────────────────────────────────
# CACHE
# ─────────────────────────────────────────────────────────────────────────────
def _blank_cache():
    return {"languages": [], "words": [], "word_examples": [], "word_languages": []}

def load_cache():
    if not os.path.exists(CACHE_FILE):
        return _blank_cache()
    try:
        with open(CACHE_FILE, "r") as f:
            data = json.load(f)
    except json.JSONDecodeError:
        ts = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
        bak = f"{CACHE_FILE}.corrupt-{ts}.bak"
        try:
            os.replace(CACHE_FILE, bak)
            print(f"⚠️  Cache corrupted, backed up to {bak}. Starting fresh.")
        except Exception:
            print("⚠️  Cache corrupted; could not rename. Starting fresh.")
        return _blank_cache()
    base = _blank_cache()
    for k in base:
        if k not in data:
            data[k] = base[k]
    return data

def save_cache(c):
    tmp = CACHE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(c, f, indent=2)
    os.replace(tmp, CACHE_FILE)

# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────
def init_appwrite():
    client = Client()
    client.set_endpoint(ENDPOINT).set_project(PROJECT_ID).set_key(API_KEY)
    return Databases(client)

def stable_doc_id(namespace: str, key: str) -> str:
    import uuid as _uuid
    return str(_uuid.uuid5(_uuid.NAMESPACE_URL, f"{namespace}:{key}"))

def _create_document_raw(collection_id: str, doc_id: str, data: dict):
    url = f"{ENDPOINT}/databases/{DB_ID}/collections/{collection_id}/documents"
    payload = {"documentId": doc_id, "data": data}
    resp = _session.post(url, json=payload, timeout=(HTTP_CONN_TIMEOUT, HTTP_READ_TIMEOUT))
    if 200 <= resp.status_code < 300:
        return resp.json()
    if resp.status_code == 409:
        r2 = _session.get(f"{ENDPOINT}/databases/{DB_ID}/collections/{collection_id}/documents/{doc_id}",
                          timeout=(HTTP_CONN_TIMEOUT, HTTP_READ_TIMEOUT))
        r2.raise_for_status()
        return r2.json()
    try: err = resp.json()
    except Exception: err = {"message": resp.text}
    raise AppwriteException(err.get("message", "Unknown error"), resp.status_code, err.get("type"), resp.text)

def _update_document_raw(collection_id: str, doc_id: str, data: dict):
    url = f"{ENDPOINT}/databases/{DB_ID}/collections/{collection_id}/documents/{doc_id}"
    resp = _session.patch(url, json={"data": data}, timeout=(HTTP_CONN_TIMEOUT, HTTP_READ_TIMEOUT))
    if 200 <= resp.status_code < 300:
        return resp.json()
    try: err = resp.json()
    except Exception: err = {"message": resp.text}
    raise AppwriteException(err.get("message", "Unknown error"), resp.status_code, err.get("type"), resp.text)

def create_document_with_retry(collection_id: str, doc_id: str, data: dict,
                               max_retries=MAX_RETRIES, base_delay=BASE_DELAY_SEC):
    for attempt in range(1, max_retries + 1):
        try:
            return _create_document_raw(collection_id, doc_id, data)
        except AppwriteException as e:
            code = getattr(e, "code", None)
            if code and 400 <= code < 500 and code != 409:
                raise
            delay = min(base_delay * (2 ** (attempt - 1)), 12.0) + random.uniform(0, .25)
            print(f"  ⚠️ create retry {attempt}/{max_retries} for {collection_id}/{doc_id}: {e} — {delay:.2f}s")
            time.sleep(delay)
    raise RuntimeError(f"Failed after {max_retries} retries: {collection_id}/{doc_id}")

def update_document_with_retry(collection_id: str, doc_id: str, data: dict,
                               max_retries=MAX_RETRIES, base_delay=BASE_DELAY_SEC):
    for attempt in range(1, max_retries + 1):
        try:
            return _update_document_raw(collection_id, doc_id, data)
        except AppwriteException as e:
            code = getattr(e, "code", None)
            if code and 400 <= code < 500 and code != 409:
                raise
            delay = min(base_delay * (2 ** (attempt - 1)), 12.0) + random.uniform(0, .25)
            print(f"  ⚠️ update retry {attempt}/{max_retries} for {collection_id}/{doc_id}: {e} — {delay:.2f}s")
            time.sleep(delay)
    raise RuntimeError(f"Failed after {max_retries} retries: {collection_id}/{doc_id}")

# ─────────────────────────────────────────────────────────────────────────────
# INDEX BOOTSTRAP (prevents the crash you saw)
# ─────────────────────────────────────────────────────────────────────────────
def list_indexes(collection_id: str):
    r = _session.get(f"{ENDPOINT}/databases/{DB_ID}/collections/{collection_id}/indexes",
                     timeout=(HTTP_CONN_TIMEOUT, HTTP_READ_TIMEOUT))
    r.raise_for_status()
    return r.json().get("indexes", [])

def ensure_index(collection_id: str, key: str, idx_type: str, attributes: list, orders=None):
    orders = orders or []
    existing = list_indexes(collection_id)
    if any(ix.get("key") == key for ix in existing):
        return True
    payload = {"key": key, "type": idx_type, "attributes": attributes, "orders": orders}
    r = _session.post(f"{ENDPOINT}/databases/{DB_ID}/collections/{collection_id}/indexes",
                      json=payload, timeout=(HTTP_CONN_TIMEOUT, HTTP_READ_TIMEOUT))
    if 200 <= r.status_code < 300:
        print(f"  ↳ [INDEX] created {key} ({idx_type}) on {collection_id}")
        return True
    # If already exists or cannot create, just log
    try:
        err = r.json()
        print(f"  ⚠️ index create '{key}' returned {r.status_code}: {err.get('message')}")
    except Exception:
        print(f"  ⚠️ index create '{key}' returned {r.status_code}: {r.text}")
    return False

def ensure_sentence_indexes():
    # key index enables Query.equal/contains on array + languageId
    ensure_index(COL_SENTENCES, "idx_normwords",  "key",      ["normalizedWords"], ["asc"])
    ensure_index(COL_SENTENCES, "idx_languageId", "key",      ["languageId"],      ["asc"])
    # fulltext index enables Query.search("text", …) fallback
    ok_ft = ensure_index(COL_SENTENCES, "idx_text_ft", "fulltext", ["text"], [])
    return ok_ft  # whether fulltext fallback can be used

# ─────────────────────────────────────────────────────────────────────────────
# LANGUAGES & WORDS (unchanged create logic)
# ─────────────────────────────────────────────────────────────────────────────
def migrate_languages(db, cache):
    print("⏳ Migrating languages…")
    defs = [("es","Spanish"),("en","English"),("fr","French"),
            ("de","German"),("it","Italian"),("pt","Portuguese"),("ru","Russian")]
    lang_map = {}
    for code, name in defs:
        if code in cache["languages"]:
            res = db.list_documents(DB_ID, COL_LANGUAGES, queries=[Query.equal("code", code)])
            if res["documents"]:
                lang_map[code] = res["documents"][0]["$id"]; print(f"  ↳ [SKIP] {code}")
            else:
                doc_id = stable_doc_id("language", code)
                doc = create_document_with_retry(COL_LANGUAGES, doc_id, {"code": code, "name": name})
                lang_map[code] = doc["$id"]; print(f"  ↳ [RECREATE] {code} → {doc['$id']}")
        else:
            doc_id = stable_doc_id("language", code)
            doc = create_document_with_retry(COL_LANGUAGES, doc_id, {"code": code, "name": name})
            lang_map[code] = doc["$id"]; cache["languages"].append(code); save_cache(cache)
            print(f"  ↳ [CREATE] {code} → {doc['$id']}")
    return lang_map

def migrate_words(conn, db, cache):
    print("⏳ Migrating words…")
    cur = conn.cursor(); cur.execute("SELECT id, text FROM words")
    for wid, wtext in cur.fetchall():
        if wid in cache["words"]: continue
        doc_id = stable_doc_id("word", str(wid))
        doc = create_document_with_retry(COL_WORDS, doc_id, {"word": wtext})
        cache["words"].append(wid); save_cache(cache)
        print(f"  ↳ [CREATE] word {wid} → {doc['$id']}")

# ─────────────────────────────────────────────────────────────────────────────
# WORD LINKING
# ─────────────────────────────────────────────────────────────────────────────
def detect_language_code(conn, word_text: str):
    tables = [("de","de_words"),("en","en_words"),("fr","fr_words"),
              ("it","it_words"),("pt","pt_words"),("ru","ru_words"),("es","es_words")]
    for code, table in tables:
        if conn.execute(f"SELECT 1 FROM {table} WHERE word = ? LIMIT 1", (word_text,)).fetchone():
            return code
        if conn.execute(f"SELECT 1 FROM {table} WHERE word = ? LIMIT 1", (word_text.lower(),)).fetchone():
            return code
    return None

def get_word_doc_id(db, local_word_id: str, word_text: str):
    stable_id = stable_doc_id("word", str(local_word_id))
    r = _session.get(f"{ENDPOINT}/databases/{DB_ID}/collections/{COL_WORDS}/documents/{stable_id}",
                     timeout=(HTTP_CONN_TIMEOUT, HTTP_READ_TIMEOUT))
    if r.status_code == 200: return stable_id
    res = db.list_documents(DB_ID, COL_WORDS, queries=[Query.equal("word", word_text), Query.limit(1)])
    if res["documents"]: return res["documents"][0]["$id"]
    return None

def set_examples_on_word(word_doc_id: str, example_ids: list):
    if not example_ids: return
    try:
        update_document_with_retry(COL_WORDS, word_doc_id, {"example": example_ids})
    except AppwriteException as e:
        if getattr(e, "code", None) in (400, 422):
            update_document_with_retry(COL_WORDS, word_doc_id, {"example": example_ids[0]})
        else:
            raise

def set_languages_on_word(word_doc_id: str, lang_ids: list):
    if not lang_ids: return
    try:
        update_document_with_retry(COL_WORDS, word_doc_id, {"languages": lang_ids})
    except AppwriteException as e:
        if getattr(e, "code", None) in (400, 422):
            update_document_with_retry(COL_WORDS, word_doc_id, {"languages": lang_ids[0]})
        else:
            raise

def link_examples_for_words(conn, db, cache, lang_map, fulltext_ok: bool):
    print("⏳ Linking example sentences to words…")
    cur = conn.cursor(); cur.execute("SELECT id, text FROM words")
    rows = cur.fetchall(); processed = 0

    for wid, wtext in rows:
        token = (wtext or "").strip().lower()
        if not token: continue
        if wid in cache["word_examples"]:
            processed += 1
            if processed % HEARTBEAT_EVERY == 0: print(f"  …examples heartbeat: {processed} processed")
            continue

        word_doc_id = get_word_doc_id(db, wid, token)
        if not word_doc_id:
            print(f"  ⚠️ word not found in Appwrite: {wid} '{token}'")
            cache["word_examples"].append(wid); save_cache(cache); continue

        queries = [Query.equal("normalizedWords", token), Query.limit(EXAMPLES_PER_WORD)]
        code = detect_language_code(conn, token)
        if code and code in lang_map:
            queries.append(Query.equal("languageId", lang_map[code]))

        docs = []
        try:
            res = db.list_documents(DB_ID, COL_SENTENCES, queries=queries)
            docs = res.get("documents", [])
        except AppwriteException as e:
            print(f"  ⚠️ list_documents(equal normalizedWords) failed for '{token}': {e}")

        # Fallback to full-text search ONLY if index exists
        if not docs and fulltext_ok:
            try:
                res = db.list_documents(DB_ID, COL_SENTENCES,
                                        queries=[Query.search("text", token), Query.limit(EXAMPLES_PER_WORD)])
                docs = res.get("documents", [])
            except AppwriteException as e:
                print(f"  ⚠️ full-text fallback failed for '{token}': {e}")

        example_ids = [d["$id"] for d in docs]
        if not example_ids:
            print(f"  ⚠️ no example sentences found for '{token}' (lang={code})")
            cache["word_examples"].append(wid); save_cache(cache); continue

        set_examples_on_word(word_doc_id, example_ids)
        cache["word_examples"].append(wid); save_cache(cache)
        print(f"  ↳ [UPDATED] word {wid} examples → {len(example_ids)} ids")

        processed += 1
        if processed % HEARTBEAT_EVERY == 0: print(f"  …examples heartbeat: {processed} updated")

    print(f"✔ Words with examples set: {len(cache['word_examples'])}")

def set_languages_for_words(conn, db, cache, lang_map):
    print("⏳ Setting languages on words…")
    cur = conn.cursor(); cur.execute("SELECT id, text FROM words")
    rows = cur.fetchall(); processed = 0

    for wid, wtext in rows:
        token = (wtext or "").strip().lower()
        if not token: continue
        if wid in cache["word_languages"]:
            processed += 1
            if processed % HEARTBEAT_EVERY == 0: print(f"  …languages heartbeat: {processed} processed")
            continue

        word_doc_id = get_word_doc_id(db, wid, token)
        if not word_doc_id:
            print(f"  ⚠️ word not found in Appwrite: {wid} '{token}'")
            cache["word_languages"].append(wid); save_cache(cache); continue

        code = detect_language_code(conn, token)
        if not code or code not in lang_map:
            cache["word_languages"].append(wid); save_cache(cache); continue

        set_languages_on_word(word_doc_id, [lang_map[code]])
        cache["word_languages"].append(wid); save_cache(cache)
        print(f"  ↳ [UPDATED] word {wid} language → {code}")

        processed += 1
        if processed % HEARTBEAT_EVERY == 0: print(f"  …languages heartbeat: {processed} updated")

    print(f"✔ Words with languages set: {len(cache['word_languages'])}")

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
def main():
    cache = load_cache()
    conn  = sqlite3.connect(SQLITE_FILE); conn.row_factory = sqlite3.Row
    db    = init_appwrite()

    # Make sure the indexes we rely on exist
    fulltext_ok = ensure_sentence_indexes()

    lang_map = migrate_languages(db, cache)
    # If you still need to create words: migrate_words(conn, db, cache)

    link_examples_for_words(conn, db, cache, lang_map, fulltext_ok)
    set_languages_for_words(conn, db, cache, lang_map)

    conn.close()
    print("✅ Done.")

if __name__ == "__main__":
    main()
