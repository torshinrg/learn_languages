#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
words_delete_zero_examples.py

Delete word documents from Appwrite WORDS collection whose entries in
`.processed_words.log` have example_count == 0.

Env (.env) required:
  APPWRITE_ENDPOINT
  APPWRITE_PROJECT
  APPWRITE_API_KEY
  APPWRITE_DATABASE_ID
  APPWRITE_WORDS_COLLECTION_ID

Optional (.env):
  PROCESSED_LOG_FILE=.processed_words.log
  DRY_RUN=0                       # set to 0 to actually delete
  VERIFY_ZERO_BEFORE_DELETE=0     # set to 1 to fetch the word and confirm example is empty
  HTTP_TIMEOUT=12
  VERBOSE=1

Usage:
  python words_delete_zero_examples.py
"""

import os, sys, time, random
from typing import List, Tuple, Any
from dotenv import dotenv_values

from appwrite.client import Client
from appwrite.services.databases import Databases
from appwrite.query import Query

# -----------------------
# Config
# -----------------------
cfg = dotenv_values(".env")

def need(k: str) -> str:
    v = (cfg.get(k) or "").strip()
    if not v:
        print(f"[FATAL] Missing {k} in .env", file=sys.stderr); sys.exit(1)
    return v

APPWRITE_ENDPOINT = need("APPWRITE_ENDPOINT")
APPWRITE_PROJECT  = need("APPWRITE_PROJECT")
APPWRITE_API_KEY  = need("APPWRITE_API_KEY")
DB_ID             = need("APPWRITE_DATABASE_ID")
WORDS_COLL        = need("APPWRITE_WORDS_COLLECTION_ID")

PROCESSED_LOG_FILE        = (cfg.get("PROCESSED_LOG_FILE") or ".processed_words.log").strip()
DRY_RUN                   = (cfg.get("DRY_RUN") or "0").lower() in ("1","true","yes","on")
VERIFY_ZERO_BEFORE_DELETE = (cfg.get("VERIFY_ZERO_BEFORE_DELETE") or "0").lower() in ("1","true","yes","on")
HTTP_TIMEOUT              = float((cfg.get("HTTP_TIMEOUT") or "12").strip())
VERBOSE                   = (cfg.get("VERBOSE") or "1").lower() in ("1","true","yes","on")

# -----------------------
# Appwrite
# -----------------------
client = Client()
client.set_endpoint(APPWRITE_ENDPOINT).set_project(APPWRITE_PROJECT).set_key(APPWRITE_API_KEY)
db = Databases(client)
print("[INIT] Appwrite client initialized")

# -----------------------
# Helpers
# -----------------------
def _sleep_backoff(try_no: int):
    delay = min(8.0, 0.5 * (2 ** (try_no-1))) + random.random()*0.2
    time.sleep(delay)

def with_retries(fn, *args, **kwargs):
    for t in range(1, 6):
        try:
            return fn(*args, **kwargs)
        except Exception as e:
            msg = str(e)
            is_4xx = " 4" in msg and "error" in msg
            if is_4xx or t == 5:
                print(f"[RETRY][GIVEUP] {e}", file=sys.stderr)
                raise
            if VERBOSE:
                print(f"[RETRY] {type(e).__name__}: {e} -> try {t+1}")
            _sleep_backoff(t)

def read_zero_ids(path: str) -> List[str]:
    ids: List[str] = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith("#"): continue
            parts = s.split("\t")
            if len(parts) < 5: continue
            wid, lang2, word, lemma, cnt = parts[:5]
            if cnt.strip() == "0":
                ids.append(wid)
    # de-dup, preserve order
    seen, out = set(), []
    for w in ids:
        if w not in seen:
            out.append(w); seen.add(w)
    return out

def example_count_from_doc(doc: dict) -> int:
    ex = doc.get("example")
    if not ex:
        return 0
    if isinstance(ex, list):
        return len(ex)
    return 1  # string/dict treated as 1

def verify_still_zero(word_id: str) -> bool:
    try:
        doc = with_retries(db.get_document,
                           database_id=DB_ID, collection_id=WORDS_COLL, document_id=word_id)
        return example_count_from_doc(doc) == 0
    except Exception as e:
        print(f"[VERIFY][WARN] could not read word {word_id}: {e}")
        # if we can't verify, be conservative and skip deletion when verification is requested
        return False

def delete_word(word_id: str) -> bool:
    if DRY_RUN:
        print(f"[DRY-RUN] would delete word {word_id}")
        return True
    try:
        with_retries(db.delete_document,
                     database_id=DB_ID, collection_id=WORDS_COLL, document_id=word_id)
        print(f"[DELETE] word {word_id}")
        return True
    except Exception as e:
        print(f"[ERR] delete {word_id} failed: {e}")
        return False

# -----------------------
# Main
# -----------------------
def main():
    zero_ids = read_zero_ids(PROCESSED_LOG_FILE)
    print(f"[INPUT] words with 0 examples in log: {len(zero_ids)}")

    deleted = 0
    skipped = 0

    for wid in zero_ids:
        if VERIFY_ZERO_BEFORE_DELETE:
            if not verify_still_zero(wid):
                print(f"[SKIP] {wid} no longer has 0 examples (or verify failed)")
                skipped += 1
                continue
        ok = delete_word(wid)
        if ok: deleted += 1
        else:  skipped += 1

    print(f"\n[SUMMARY] candidates={len(zero_ids)}, deleted={deleted}, skipped={skipped}, dry_run={int(DRY_RUN)}")

if __name__ == "__main__":
    main()
