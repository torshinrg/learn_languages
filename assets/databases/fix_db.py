#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys, os, re, time, random
from functools import lru_cache
from typing import Dict, Optional, Any, List, Tuple

# --------------------------------------------------------------------
# Python 3.11+ compatibility for libs that still call inspect.getargspec
# --------------------------------------------------------------------
import inspect
try:
    inspect.getargspec  # may not exist on 3.11+
except AttributeError:
    from collections import namedtuple
    from inspect import getfullargspec
    ArgSpec = namedtuple("ArgSpec", "args varargs keywords defaults")
    def _getargspec(func):
        fs = getfullargspec(func)
        return ArgSpec(fs.args, fs.varargs, fs.varkw, fs.defaults)
    inspect.getargspec = _getargspec  # monkey-patch
    print("[INIT] Applied inspect.getargspec compatibility shim")

# --- .env ---
from dotenv import dotenv_values

# --- Appwrite ---
from appwrite.client import Client
from appwrite.services.databases import Databases
from appwrite.query import Query

# --- Appwrite Query compatibility: orderAsc vs order_asc ---
if hasattr(Query, "order_asc"):
    ORDER_ASC = Query.order_asc
elif hasattr(Query, "orderAsc"):
    ORDER_ASC = Query.orderAsc
else:
    raise RuntimeError("Appwrite Query helper lacks order_asc/orderAsc. Please upgrade the SDK.")

# --- NLP ---
import spacy

print("[INIT] Starting script…")

# -----------------------
# Load config from .env
# -----------------------
cfg = dotenv_values(".env")

def need(key: str) -> str:
    val = (cfg.get(key) or "").strip()
    if not val:
        print(f"[FATAL] Missing {key} in .env", file=sys.stderr)
        sys.exit(1)
    return val

APPWRITE_ENDPOINT = need("APPWRITE_ENDPOINT")
APPWRITE_PROJECT  = need("APPWRITE_PROJECT")
APPWRITE_API_KEY  = need("APPWRITE_API_KEY")
DB_ID             = need("APPWRITE_DATABASE_ID")
WORDS_COLL        = need("APPWRITE_WORDS_COLLECTION_ID")
LANGS_COLL        = need("APPWRITE_LANGS_COLLECTION_ID")
SENTENCES_COLL    = need("APPWRITE_SENTENCES_COLLECTION_ID")

# Tunables (no filters – full rescan by default)
MAX_EXAMPLES_PER_WORD      = int((cfg.get("MAX_EXAMPLES_PER_WORD") or "20").strip())
RESUME_CURSOR_FILE         = (cfg.get("RESUME_CURSOR_FILE") or ".progress_words.cursor").strip()
PROCESSED_LOG_FILE         = (cfg.get("PROCESSED_LOG_FILE") or ".processed_words.log").strip()
FORCE_FULL_RESCAN          = (cfg.get("FORCE_FULL_RESCAN") or "1").lower() in ("1","true","yes","on")  # <- default ON
PAGE_LIMIT_WORDS           = int((cfg.get("PAGE_LIMIT_WORDS") or "100").strip())  # max 100

# Optional slow fallback scan for sentences (still off by default)
SLOW_FALLBACK                 = (cfg.get("SLOW_FALLBACK") or "0").lower() in ("1","true","yes","on")
MIN_FOUND_TO_SKIP_FALLBACK    = int((cfg.get("MIN_FOUND_TO_SKIP_FALLBACK") or "3").strip())
MAX_DOCS_SCANNED_FALLBACK     = int((cfg.get("MAX_DOCS_SCANNED_FALLBACK") or "2000").strip())

VERBOSE = (cfg.get("VERBOSE") or "1").lower() in ("1","true","yes","on")

print("[INIT] Loaded config from .env")

# -----------------------
# Appwrite setup + retry wrappers
# -----------------------
client = Client()
client.set_endpoint(APPWRITE_ENDPOINT).set_project(APPWRITE_PROJECT).set_key(APPWRITE_API_KEY)
db = Databases(client)
print("[INIT] Appwrite client initialized")

def _with_retries(fn, *args, **kwargs):
    tries, delay = 0, 0.5
    while True:
        try:
            return fn(*args, **kwargs)
        except Exception as e:
            tries += 1
            msg = str(e)
            is_4xx = " 4" in msg and "error" in msg
            if is_4xx or tries >= 6:
                print(f"[RETRY][GIVEUP] {e}", file=sys.stderr)
                raise
            sleep = delay * (2 ** (tries - 1)) + random.random() * 0.2
            if VERBOSE:
                print(f"[RETRY] {type(e).__name__}: {e} -> retry {tries} in {sleep:.2f}s")
            time.sleep(sleep)

def list_documents_safe(**kw):
    return _with_retries(db.list_documents, **kw)

def get_document_safe(**kw):
    return _with_retries(db.get_document, **kw)

def update_document_safe(**kw):
    return _with_retries(db.update_document, **kw)

# -----------------------
# spaCy model loaders (exclude heavy components)
# -----------------------
def safe_load_spacy(model_name: str):
    try:
        if VERBOSE: print(f"[NLP] Loading spaCy model: {model_name}")
        return spacy.load(model_name, exclude=["parser","ner","senter","textcat"])
    except Exception as e:
        print(f"[WARN] Could not load spaCy model '{model_name}': {e}", file=sys.stderr)
        return None

NLP_MODELS = {
    "en": safe_load_spacy("en_core_web_sm"),
    "es": safe_load_spacy("es_core_news_sm"),
    "fr": safe_load_spacy("fr_core_news_sm"),
    "it": safe_load_spacy("it_core_news_sm"),
    "de": safe_load_spacy("de_core_news_sm"),
    "pt": safe_load_spacy("pt_core_news_sm"),
}
print("[INIT] NLP models loaded (some may be None if missing)")

# -----------------------
# Russian lemmatizers (prefer pymorphy2; fallback to pymystem3)
# -----------------------
MORPH_RU = None
MYSTEM   = None
RU_MODE  = None

try:
    import pymorphy2
    MORPH_RU = pymorphy2.MorphAnalyzer()
    RU_MODE = "pymorphy2"
    print("[RU] Using pymorphy2")
except Exception as e:
    print(f"[RU][WARN] pymorphy2 unavailable: {e}", file=sys.stderr)
    try:
        from pymystem3 import Mystem
        MYSTEM = Mystem()
        RU_MODE = "mystem"
        print("[RU] Using pymystem3 (mystem)")
    except Exception as e2:
        RU_MODE = None
        print(f"[RU][ERROR] No Russian lemmatizer available: {e2}", file=sys.stderr)

# -----------------------
# Romance clitics lists
# -----------------------
ES_CLITICS = (
    "melo","mela","melos","melas","telo","tela","telos","telas",
    "selo","sela","selos","selas","noslo","nosla","noslos","noslas",
    "oslo","osla","oslos","oslas","me","te","se","nos","os","lo","la","los","las","le","les"
)
PT_CLITICS = (
    "lhes","lhe","nos","vos","me","te","se","o","a","os","as","lo","la","los","las","no","na","nos","nas"
)
IT_CLITICS = (
    "gliela","glielo","glieli","gliele","gliene",
    "melo","mela","meli","mele","mene",
    "telo","tela","teli","tele","tene",
    "selo","sela","seli","sele","sene",
    "celo","cela","celi","cele","cene",
    "velo","vela","veli","vele","vene",
    "mi","ti","si","ci","vi","lo","la","li","le","ne","gli","le"
)

def _es_probable_enclitic_base(base: str) -> bool:
    b = base.lower()
    return b.endswith("r") or b.endswith("ndo") or b.endswith("d")

def strip_romance_clitics(word: str, lang: str) -> str:
    w = word.lower()
    if lang == "pt":
        if "-" in w:
            parts = [p for p in w.split("-") if p]
            changed = False
            while parts and parts[-1] in PT_CLITICS:
                if VERBOSE: print(f"[CLITIC] Removing PT clitic {parts[-1]} from {w}")
                parts.pop(); changed = True
            return "-".join(parts) if (parts and changed) else w
        return w
    if lang == "es":
        for cl in sorted(ES_CLITICS, key=len, reverse=True):
            if w.endswith(cl) and len(w) > len(cl) + 1:
                base = w[:-len(cl)]
                if _es_probable_enclitic_base(base):
                    if VERBOSE: print(f"[CLITIC] Removing ES clitic {cl} from {w} (base={base})")
                    return base
        return w
    if lang == "it":
        for cl in sorted(IT_CLITICS, key=len, reverse=True):
            if w.endswith(cl) and len(w) > len(cl) + 1:
                base = w[:-len(cl)]
                if base.endswith(("ar","er","ir")):
                    base = base + "e"
                if VERBOSE: print(f"[CLITIC] Removing IT clitic {cl} from {w} -> base={base}")
                return base
        return w
    return w

def spacy_lemma(nlp, token_text: str) -> str:
    if nlp is None:
        if VERBOSE: print(f"[LEMMA][WARN] No spaCy model, fallback lowercase for '{token_text}'")
        return token_text.lower()
    doc = nlp(token_text)
    if not doc:
        if VERBOSE: print(f"[LEMMA][WARN] Empty spaCy doc for '{token_text}', fallback lowercase")
        return token_text.lower()
    lem = (doc[0].lemma_ or token_text).lower()
    if VERBOSE: print(f"[LEMMA] spaCy {token_text} → {lem}")
    return lem

# Lemma cache
LEMMA_CACHE: Dict[Tuple[str, str], str] = {}

def to_infinitive(word: str, lang_code: Optional[str]) -> str:
    if not word:
        return word
    lang = (lang_code or "").lower()
    key = (lang, word.lower())
    if key in LEMMA_CACHE:
        return LEMMA_CACHE[key]

    # RU
    if lang == "ru":
        if RU_MODE == "pymorphy2":
            out = MORPH_RU.parse(word)[0].normal_form
        elif RU_MODE == "mystem":
            lemmas = MYSTEM.lemmatize(word)
            out = (lemmas[0].strip() if lemmas else word).lower()
        else:
            out = word.lower()
        if VERBOSE: print(f"[INF][RU] {word} → {out}")
        LEMMA_CACHE[key] = out
        return out

    # ES/PT/IT
    if lang in ("es","pt","it"):
        stripped = strip_romance_clitics(word, lang)
        out = spacy_lemma(NLP_MODELS.get(lang), stripped)
        LEMMA_CACHE[key] = out
        return out

    # FR/DE/EN
    if lang in ("fr","de","en"):
        out = spacy_lemma(NLP_MODELS.get(lang), word)
        LEMMA_CACHE[key] = out
        return out

    # Unknown lang: still normalize to lowercase so we DON'T SKIP any word
    out = word.lower()
    if VERBOSE: print(f"[INF][WARN] Unknown lang -> lowercase '{word}' → '{out}'")
    LEMMA_CACHE[key] = out
    return out

# -----------------------
# Language map ($id -> code) and inverse (code -> $id)
# -----------------------
def fetch_language_map() -> Tuple[Dict[str,str], Dict[str,str]]:
    if VERBOSE: print("[LANG] Fetching languages…")
    id_to_code: Dict[str, str] = {}
    cursor = None
    while True:
        q = [Query.limit(100)]
        if cursor:
            q.append(Query.cursor_after(cursor))
        page = list_documents_safe(database_id=DB_ID, collection_id=LANGS_COLL, queries=q)
        docs = page.get("documents", [])
        if not docs:
            break
        for d in docs:
            code = (d.get("code") or d.get("name") or "").lower()
            if VERBOSE: print(f"[LANG] Loaded {d['$id']} → {code}")
            id_to_code[d["$id"]] = code
        cursor = docs[-1]["$id"]
        if page.get("total", 0) <= len(id_to_code):
            break
    code_to_id = {code: _id for _id, code in id_to_code.items()}
    return id_to_code, code_to_id

LANG_MAP, CODE_TO_ID = fetch_language_map()

# ---------- robust language value parsers ----------
def _lang_code_from_value(val: Any) -> Optional[str]:
    if not val:
        return None
    if isinstance(val, str):
        return (LANG_MAP.get(val) or "").lower() or None
    if isinstance(val, dict):
        if "$id" in val and val["$id"]:
            return (LANG_MAP.get(val["$id"]) or "").lower() or None
        if "code" in val and val["code"]:
            return str(val["code"]).lower()
    if isinstance(val, (list, tuple)):
        for item in val:
            code = _lang_code_from_value(item)
            if code:
                return code
    return None

def _lang_id_from_value(val: Any) -> Optional[str]:
    if not val:
        return None
    if isinstance(val, str):
        return val
    if isinstance(val, dict):
        if "$id" in val and val["$id"]:
            return val["$id"]
        if "code" in val and val["code"]:
            return CODE_TO_ID.get(str(val["code"]).lower())
    if isinstance(val, (list, tuple)):
        for item in val:
            lid = _lang_id_from_value(item)
            if lid:
                return lid
    return None

def get_lang_info_for_word(doc: Dict[str, Any]) -> Tuple[Optional[str], Optional[str]]:
    if "languages" in doc and doc["languages"]:
        v = doc["languages"]
        if VERBOSE: print(f"[LANG-DETECT] languages field type={type(v).__name__} preview={str(v)[:80]}")
        code = _lang_code_from_value(v)
        lid  = _lang_id_from_value(v)
        if code or lid:
            return code, lid
    if "languageId" in doc and doc["languageId"]:
        v = doc["languageId"]
        if VERBOSE: print(f"[LANG-DETECT] fallback languageId type={type(v).__name__} preview={str(v)[:80]}")
        code = _lang_code_from_value(v)
        lid  = _lang_id_from_value(v)
        if code or lid:
            return code, lid
    print(f"[LANG-DETECT][WARN] No language found for word doc {doc.get('$id')}")
    return None, None

# ---------- sentence language detection ----------
def sentence_lang_code(sentence_doc: Dict[str, Any]) -> Optional[str]:
    raw = sentence_doc.get("languageId")
    if not raw:
        return None
    return _lang_code_from_value(raw)

def sentence_lang_id(sentence_doc: Dict[str, Any]) -> Optional[str]:
    raw = sentence_doc.get("languageId")
    if not raw:
        return None
    return _lang_id_from_value(raw)

# ---------- helpers for examples ----------
def extract_example_ids(word_doc: Dict[str, Any]) -> List[str]:
    if "example" not in word_doc or not word_doc["example"]:
        return []
    ex = word_doc["example"]
    ids: List[str] = []
    if isinstance(ex, list):
        for item in ex:
            if isinstance(item, str):
                ids.append(item)
            elif isinstance(item, dict) and "$id" in item:
                ids.append(item["$id"])
    elif isinstance(ex, str):
        ids.append(ex)
    elif isinstance(ex, dict) and "$id" in ex:
        ids.append(ex["$id"])
    if VERBOSE: print(f"[EXAMPLES] Word {word_doc['$id']} existing example IDs={ids}")
    return ids

def _fetch_docs_by_ids(coll: str, ids: List[str]) -> Dict[str, Dict[str, Any]]:
    if not ids:
        return {}
    q = [Query.equal("$id", ids), Query.limit(min(100, len(ids)))]
    page = list_documents_safe(database_id=DB_ID, collection_id=coll, queries=q)
    docs = page.get("documents", [])
    return {d["$id"]: d for d in docs}

def filter_existing_examples(word_doc: Dict[str, Any], word_lang_code: Optional[str]) -> Tuple[List[str], int]:
    ex_ids = extract_example_ids(word_doc)
    if not ex_ids:
        return [], 0
    # If language unknown, DO NOT drop anything – keep all examples
    if not word_lang_code:
        return ex_ids, 0
    sid2doc = _fetch_docs_by_ids(SENTENCES_COLL, ex_ids)
    keep_ids: List[str] = []
    removed = 0
    for sid in ex_ids:
        sdoc = sid2doc.get(sid)
        if not sdoc:
            keep_ids.append(sid)
            continue
        s_code = sentence_lang_code(sdoc)
        if s_code and s_code == word_lang_code:
            keep_ids.append(sid)
        else:
            if VERBOSE:
                print(f"[REL] Drop sentence {sid} (lang={s_code}) from word {word_doc['$id']} (lang={word_lang_code})")
            removed += 1
    return keep_ids, removed

# ---------- sentence search (index-only; no language server filter) ----------
def _spanish_inf_candidates(lemma: str) -> List[str]:
    l = lemma.lower()
    cands = [l]
    if l.endswith("ado"):
        cands.append(l[:-3] + "ar")
    elif l.endswith("ido"):
        stem = l[:-3]
        cands.extend([stem + "er", stem + "ir"])
    seen, out = set(), []
    for x in cands:
        if x not in seen:
            out.append(x); seen.add(x)
    return out

@lru_cache(maxsize=20000)
def _sentence_ids_by_normword_cached(lang_id: str, lemma: str, cap: int) -> Tuple[str, ...]:
    out: List[str] = []
    try:
        q = [Query.contains("normalizedWords", [lemma]), Query.limit(min(100, cap * 3))]
        page = list_documents_safe(database_id=DB_ID, collection_id=SENTENCES_COLL, queries=q)
        docs = page.get("documents", [])
        for d in docs:
            sid = d["$id"]
            if sentence_lang_id(d) == lang_id:
                out.append(sid)
                if len(out) >= cap:
                    break
    except Exception as e:
        print(f"[SENTENCE-SEARCH][WARN] fast path failed for '{lemma}': {e}")
    return tuple(out[:cap])

def find_sentence_ids_by_word(lemma: str, lang_id: Optional[str], lang_code: Optional[str], cap: int) -> List[str]:
    lemma = (lemma or "").lower().strip()
    if not lemma or not lang_id:
        return []
    found = list(_sentence_ids_by_normword_cached(lang_id, lemma, cap))
    if len(found) >= cap:
        return found[:cap]
    if lang_code == "es":
        for cand in _spanish_inf_candidates(lemma):
            if cand == lemma:
                continue
            extra = list(_sentence_ids_by_normword_cached(lang_id, cand, cap))
            if extra:
                merged = list(dict.fromkeys(found + extra))
                if len(merged) >= cap:
                    return merged[:cap]
                found = merged
    if (not SLOW_FALLBACK) or len(found) >= MIN_FOUND_TO_SKIP_FALLBACK:
        return found[:cap]
    # Optional bounded fallback
    scanned = 0
    cursor = None
    while len(found) < cap and scanned < MAX_DOCS_SCANNED_FALLBACK:
        q = [Query.limit(100)]
        if cursor: q.append(Query.cursor_after(cursor))
        page = list_documents_safe(database_id=DB_ID, collection_id=SENTENCES_COLL, queries=q)
        docs = page.get("documents", [])
        if not docs: break
        for sdoc in docs:
            scanned += 1
            if sentence_lang_id(sdoc) != lang_id:
                continue
            nwords = sdoc.get("normalizedWords")
            if isinstance(nwords, list) and lemma in {str(t).lower() for t in nwords}:
                sid = sdoc["$id"]
                if sid not in found:
                    found.append(sid)
                    if len(found) >= cap:
                        break
        cursor = docs[-1]["$id"]
        if len(docs) < 100: break
    if scanned and VERBOSE:
        print(f"[SENTENCE-SEARCH][FALLBACK] scanned={scanned} added={len(found)} lemma='{lemma}'")
    return found[:cap]

# -----------------------
# Progress / resume utils (disabled when FORCE_FULL_RESCAN=1)
# -----------------------
def load_resume_cursor() -> Optional[str]:
    # When full rescan is forced, ignore resume file entirely.
    if FORCE_FULL_RESCAN:
        print("[RESUME] FORCE_FULL_RESCAN=1 -> starting from the beginning")
        return None
    try:
        if os.path.exists(RESUME_CURSOR_FILE):
            with open(RESUME_CURSOR_FILE, "r", encoding="utf-8") as f:
                cursor = f.read().strip()
                if cursor:
                    print(f"[RESUME] Loaded last cursor: {cursor}")
                    return cursor
    except Exception as e:
        print(f"[RESUME][WARN] Could not read cursor file: {e}")
    return None

def save_resume_cursor(doc_id: str) -> None:
    if FORCE_FULL_RESCAN:
        return  # do not save cursor in full-rescan mode
    try:
        with open(RESUME_CURSOR_FILE, "w", encoding="utf-8") as f:
            f.write(doc_id)
    except Exception as e:
        print(f"[RESUME][WARN] Could not write cursor file: {e}")

def append_processed_log(doc_id: str, lang_code: Optional[str], word: str, lemma: str, example_count: int) -> None:
    try:
        with open(PROCESSED_LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"{doc_id}\t{lang_code or 'NA'}\t{word}\t{lemma}\t{example_count}\n")
    except Exception as e:
        print(f"[LOG][WARN] Could not append to processed log: {e}")

# -----------------------
# Main loop (no filters; process ALL words)
# -----------------------
def process_words():
    scanned = 0
    lemmas_written = 0
    relations_removed_total = 0
    examples_linked_total = 0

    print("[MAIN] Starting word processing… (full rescan)" if FORCE_FULL_RESCAN else "[MAIN] Starting word processing…")

    page_cursor = load_resume_cursor()  # None when full rescan forced

    while True:
        queries = [Query.limit(PAGE_LIMIT_WORDS), ORDER_ASC("$id")]
        if page_cursor:
            queries.append(Query.cursor_after(page_cursor))
        page = list_documents_safe(database_id=DB_ID, collection_id=WORDS_COLL, queries=queries)
        docs = page.get("documents", [])
        if not docs:
            break

        for doc in docs:
            scanned += 1
            word = doc.get("word") or ""
            print(f"\n[WORD] {doc['$id']} word='{word}'")

            lang_code, lang_id = get_lang_info_for_word(doc)
            print(f"[WORD] Detected lang_code={lang_code} lang_id={lang_id}")

            # 1) Normalize EVERY word (never skip)
            infinitive = to_infinitive(word, lang_code)

            # 2) Examples: if language known → filter; else keep as-is (no drop)
            keep_ids, removed = filter_existing_examples(doc, lang_code)
            relations_removed_total += removed

            # 3) Find candidate sentences ONLY if we know lang_id
            if lang_id:
                new_ids = find_sentence_ids_by_word(infinitive, lang_id, lang_code, MAX_EXAMPLES_PER_WORD)
            else:
                new_ids = []  # cannot safely link without language

            # Dedup & cap
            existing_set = set(keep_ids)
            merged: List[str] = keep_ids[:]
            for sid in new_ids:
                if sid not in existing_set:
                    merged.append(sid)
                    existing_set.add(sid)
                if len(merged) >= MAX_EXAMPLES_PER_WORD:
                    break

            # 4) Prepare update payload
            update_payload: Dict[str, Any] = {}
            cur_inf = doc.get("normilized_words")
            if infinitive and infinitive != cur_inf:
                update_payload["normilized_words"] = infinitive  # write infinitive/base for ALL words

            current_ids = extract_example_ids(doc)
            if set(current_ids) != set(merged):
                update_payload["example"] = merged
                examples_linked_total += max(0, len(merged) - len(keep_ids))

            # 5) Write if anything changed
            if update_payload:
                try:
                    update_document_safe(
                        database_id=DB_ID,
                        collection_id=WORDS_COLL,
                        document_id=doc["$id"],
                        data=update_payload,
                    )
                    print(f"[WRITE] Updated {doc['$id']} fields={list(update_payload.keys())} (examples={len(merged)})")
                    if "normilized_words" in update_payload:
                        lemmas_written += 1
                except Exception as e:
                    print(f"[ERR] Update failed for {doc['$id']}: {e}", file=sys.stderr)
            else:
                print(f"[SKIP] No changes for {doc['$id']} (lemma and examples unchanged)")

            # Progress (disabled saving when full rescan forced)
            save_resume_cursor(doc["$id"])
            append_processed_log(doc["$id"], lang_code, word, (infinitive or ""), len(merged))

        # advance page cursor to last item in this page
        page_cursor = docs[-1]["$id"]

    print(f"\n[SUMMARY] Scanned={scanned}, LemmasWritten={lemmas_written}, "
          f"WrongExampleLinksRemoved={relations_removed_total}, "
          f"ExamplesNewlyLinked={examples_linked_total}, "
          f"MaxExamplesPerWord={MAX_EXAMPLES_PER_WORD}, "
          f"WordsPageSize={PAGE_LIMIT_WORDS}, FullRescan={int(FORCE_FULL_RESCAN)}")
    if not FORCE_FULL_RESCAN:
        print(f"[SUMMARY] Last cursor saved in: {RESUME_CURSOR_FILE}")
    print(f"[SUMMARY] Processed log appended in: {PROCESSED_LOG_FILE}")

if __name__ == "__main__":
    process_words()
