#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
update_sentences_normalized_words.py

Goal:
- For every document in the SENTENCES collection, compute the list of token
  forms for that sentence's language and write to `normalizedWords` (array).
- Rule: VERB/AUX -> infinitive; all other POS -> lemma.
- Resume where it left off using a cursor file.
- Append a per-sentence log line for auditing.
- Print progress: processed/total and how many records are left.

Languages: ru, es, pt, it, de, fr, en
"""

import sys, os, re, unicodedata
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
        # some Python builds use varkw; handle generically
        varkw = getattr(fs, "varkw", None)
        return ArgSpec(fs.args, fs.varargs, varkw, fs.defaults)
    try:
        inspect.getargspec = _getargspec  # type: ignore[attr-defined]
        print("[INIT] Applied inspect.getargspec compatibility shim")
    except Exception:
        pass

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
    raise RuntimeError("Appwrite Query helper lacks order_asc/orderAsc. Upgrade the SDK.")

# --- NLP ---
import spacy

print("[INIT] Starting sentences updater…")

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
APPWRITE_PROJECT = need("APPWRITE_PROJECT")
APPWRITE_API_KEY = need("APPWRITE_API_KEY")
DB_ID = need("APPWRITE_DATABASE_ID")
SENTENCES_COLL = need("APPWRITE_SENTENCES_COLLECTION_ID")
LANGS_COLL = need("APPWRITE_LANGS_COLLECTION_ID")

# Progress printing cadence
PROGRESS_EVERY = int((cfg.get("PROGRESS_EVERY") or "50").strip())

# Resume/logging config (optional in .env)
SENT_RESUME_CURSOR_FILE = (cfg.get("SENT_RESUME_CURSOR_FILE") or ".progress_sentences.cursor").strip()
SENT_PROCESSED_LOG_FILE = (cfg.get("SENT_PROCESSED_LOG_FILE") or ".processed_sentences.log").strip()
SENT_RESET_PROGRESS = (cfg.get("SENT_RESET_PROGRESS") or "").lower() in ("1","true","yes","on")

print("[INIT] Loaded config from .env")

# -----------------------
# Appwrite setup
# -----------------------
client = Client()
client.set_endpoint(APPWRITE_ENDPOINT).set_project(APPWRITE_PROJECT).set_key(APPWRITE_API_KEY)
db = Databases(client)
print("[INIT] Appwrite client initialized")

# -----------------------
# spaCy model loaders
# -----------------------
def safe_load_spacy(model_name: str):
    try:
        print(f"[NLP] Loading spaCy model: {model_name}")
        return spacy.load(model_name)
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
MYSTEM = None
RU_MODE = None

try:
    import pymorphy2
    MORPH_RU = pymorphy2.MorphAnalyzer()
    RU_MODE = "pymorphy2"
    print("[RU] Using pymorphy2")
except Exception as e:
    print(f"[RU][WARN] pymorphy2 unavailable: {e}", file=sys.stderr)
    try:
        from pymystem3 import Mystem
        MYSTEM = Mystem()  # downloads mystem binary on first run
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

# -----------------------
# Helpers
# -----------------------
def _strip_accents(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")

def spacy_lemma(nlp, token_text: str) -> str:
    if nlp is None:
        print(f"[LEMMA][WARN] No spaCy model, fallback lowercase for '{token_text}'")
        return token_text.lower()
    doc = nlp(token_text)
    if not doc:
        print(f"[LEMMA][WARN] Empty spaCy doc for '{token_text}', fallback lowercase")
        return token_text.lower()
    lem = (doc[0].lemma_ or token_text).lower()
    print(f"[LEMMA] spaCy {token_text} → {lem}")
    return lem

def _is_verb(token: str, lang: str) -> bool:
    nlp = NLP_MODELS.get(lang)
    if nlp is None or not token:
        return False
    d = nlp(token)
    return bool(d and d[0].pos_ in ("VERB", "AUX"))

def looks_like_spanish_enclitic_host(base: str) -> bool:
    b = base.lower()
    # infinitive, gerund, affirmative imperative (common -a), -d (vosotros imperative)
    return b.endswith(("r", "ndo", "d", "a"))

def strip_romance_clitics_verified(word: str, lang: str) -> str:
    """Strip enclitic pronouns only if the remaining host is likely a verb (POS=VERB/AUX)."""
    w = word.lower()

    if lang == "pt":
        # Mostly hyphenated in PT. Only strip when hyphenated and host POS is a verb.
        if "-" in w:
            parts = [p for p in w.split("-") if p]
            if parts and parts[-1] in PT_CLITICS and len(parts) > 1:
                host = "-".join(parts[:-1])
                if _is_verb(host, "pt"):
                    print(f"[CLITIC] Removing PT clitic {parts[-1]} from {w}")
                    return host
        return w

    if lang == "es":
        for cl in sorted(ES_CLITICS, key=len, reverse=True):
            if w.endswith(cl) and len(w) > len(cl) + 1:
                base = w[:-len(cl)]
                if looks_like_spanish_enclitic_host(base) and _is_verb(base, "es"):
                    print(f"[CLITIC] Removing ES clitic {cl} from {w} (base={base})")
                    return base
        return w

    if lang == "it":
        for cl in sorted(IT_CLITICS, key=len, reverse=True):
            if w.endswith(cl) and len(w) > len(cl) + 1:
                base = w[:-len(cl)]
                # infinitive stems sometimes appear without final -e with enclitics
                base_e = base + "e" if base.endswith(("ar","er","ir")) else base
                if _is_verb(base_e, "it") or _is_verb(base, "it"):
                    chosen = base_e if _is_verb(base_e, "it") else base
                    print(f"[CLITIC] Removing IT clitic {cl} from {w} -> base={chosen}")
                    return chosen
        return w

    return w

def es_guess_infinitive(token: str) -> Optional[str]:
    """Conservative Spanish fallback when spaCy lemma == surface or fails."""
    s = token.lower()
    s_no = _strip_accents(s)

    # Future simple (hablaré, volverás, vivirá, hablaremos, hablaréis, hablarán)
    m = re.match(r"^(.*?)(ar|er|ir)(e|as|a|emos|eis|an)$", s_no)
    if m:
        stem, conj, _ = m.groups()
        return stem + conj

    # Conditional (hablaría, vivirías, comerían ...)
    m = re.match(r"^(.*?)(ar|er|ir)(ia|ias|ia|iamos|iais|ian)$", s_no)
    if m:
        stem, conj, _ = m.groups()
        return stem + conj

    # Pretérito -AR: hablé, hablaste, habló, hablamos, hablasteis, hablaron
    if re.match(r".*ar(e|aste|o|amos|asteis|on)$", s_no):
        return re.sub(r"ar(e|aste|o|amos|asteis|on)$", "ar", s_no)

    # Pretérito -ER/-IR: comí, comiste, comió, comimos, comisteis, comieron
    if re.match(r".*(er|ir)(i|iste|io|imos|isteis|ieron)$", s_no):
        return re.sub(r"(er|ir)(i|iste|io|imos|isteis|ieron)$", r"\1", s_no)

    # Imperfecto -AR: hablaba(s/…)
    if re.match(r".*aba(s|mos|is|n)?$", s_no):
        return re.sub(r"aba(s|mos|is|n)?$", "ar", s_no)

    # Imperfecto -ER/-IR: comía(s/…), vivíamos, etc. (fallback to -er)
    if re.match(r".*i(a|as|amos|ais|an)$", s_no):
        return re.sub(r"i(a|as|amos|ais|an)$", "er", s_no)

    return None

def to_infinitive_or_lemma(word: str, lang_code: str, pos: Optional[str]) -> str:
    """
    If POS is VERB/AUX -> return infinitive (best effort).
    Else -> return lemma (avoid 'shot'->'shoot').
    """
    lang = (lang_code or "").lower()

    # ----- VERBS/AUX -----
    if pos in ("VERB", "AUX", None):  # None when POS is unknown (fallback path uses heuristics)
        if lang == "ru":
            if RU_MODE == "pymorphy2":
                return MORPH_RU.parse(word)[0].normal_form
            elif RU_MODE == "mystem":
                lemmas = MYSTEM.lemmatize(word)
                return (lemmas[0].strip() if lemmas else word).lower()
            return word.lower()

        if lang in ("es","pt","it"):
            base = strip_romance_clitics_verified(word, lang)
            lem = spacy_lemma(NLP_MODELS.get(lang), base)
            if lang == "es":
                # If lemma didn't change or still suspicious, try fallback guess
                if lem == base.lower():
                    guess = es_guess_infinitive(base)
                    if guess:
                        return guess
            return lem

        if lang in ("fr","de","en"):
            return spacy_lemma(NLP_MODELS.get(lang), word)

        return word.lower()

    # ----- NON-VERBS -----
    if lang == "ru":
        if RU_MODE == "pymorphy2":
            return MORPH_RU.parse(word)[0].normal_form
        elif RU_MODE == "mystem":
            lemmas = MYSTEM.lemmatize(word)
            return (lemmas[0].strip() if lemmas else word).lower()
        return word.lower()

    if lang in ("en","es","fr","it","de","pt"):
        return spacy_lemma(NLP_MODELS.get(lang), word)

    return word.lower()

# -----------------------
# Language maps: $id <-> code
# -----------------------
def fetch_language_map() -> Tuple[Dict[str,str], Dict[str,str]]:
    print("[LANG] Fetching languages…")
    id_to_code: Dict[str, str] = {}
    cursor = None
    while True:
        q = [Query.limit(100)]
        if cursor:
            q.append(Query.cursor_after(cursor))
        page = db.list_documents(database_id=DB_ID, collection_id=LANGS_COLL, queries=q)
        docs = page.get("documents", [])
        if not docs:
            break
        for d in docs:
            code = (d.get("code") or d.get("name") or "").lower()
            print(f"[LANG] Loaded {d['$id']} → {code}")
            id_to_code[d["$id"]] = code
        cursor = docs[-1]["$id"]
        if page.get("total", 0) <= len(id_to_code):
            break
    code_to_id = {code: _id for _id, code in id_to_code.items()}
    return id_to_code, code_to_id

LANG_MAP, CODE_TO_ID = fetch_language_map()

def _lang_code_from_value(val: Any) -> Optional[str]:
    if not val:
        return None
    if isinstance(val, str):
        v = val.strip()
        if 2 <= len(v) <= 3:
            return v.lower()
        code = LANG_MAP.get(v)
        return (code or "").lower() if code else None
    if isinstance(val, dict):
        if "code" in val and val["code"]:
            return str(val["code"]).lower()
        if "$id" in val and val["$id"]:
            code = LANG_MAP.get(val["$id"])
            return (code or "").lower() if code else None
    return None

def sentence_lang_code(sentence_doc: Dict[str, Any]) -> Optional[str]:
    raw = sentence_doc.get("languageId")
    if raw is None:
        print("[SENTENCE-LANG][WARN] Missing languageId on sentence")
        return None
    return _lang_code_from_value(raw)

# -----------------------
# Tokenization / sentence processing
# -----------------------
WORD_RE_CACHE: Dict[str, re.Pattern] = {}

def _simple_word_iter(text: str):
    # Basic Unicode-ish tokenization if spaCy model not available
    pattern = WORD_RE_CACHE.get("split")
    if not pattern:
        pattern = re.compile(r"[^\w]+", flags=re.UNICODE)
        WORD_RE_CACHE["split"] = pattern
    for tok in [t for t in pattern.split(text) if t]:
        yield tok

def sentence_infinitives(text: str, lang_code: str) -> List[str]:
    nlp = NLP_MODELS.get(lang_code)
    # If we have no model: crude fallback (no POS)
    if nlp is None:
        toks = list(_simple_word_iter(text))
        outs = []
        for t in toks:
            outs.append(to_infinitive_or_lemma(t, lang_code, pos=None))
        return dedupe_preserve_order(outs)

    doc = nlp(text)
    outs = []
    for tok in doc:
        # keep alphabetic tokens only (handles punctuation/quotes)
        if not tok.text or (not tok.is_alpha and not tok.text.isalpha()):
            continue
        outs.append(to_infinitive_or_lemma(tok.text, lang_code, pos=tok.pos_))
    return dedupe_preserve_order(outs)

def dedupe_preserve_order(items: List[str]) -> List[str]:
    seen = set()
    out: List[str] = []
    for x in items:
        xl = x.lower()
        if xl and xl not in seen:
            seen.add(xl)
            out.append(xl)
    return out

# -----------------------
# Progress helpers
# -----------------------
def get_total_sentences_count() -> int:
    """
    Ask Appwrite for total count once. list_documents returns 'total' for the query.
    We request a tiny page (limit=1) to get the collection total.
    """
    try:
        page = db.list_documents(
            database_id=DB_ID,
            collection_id=SENTENCES_COLL,
            queries=[Query.limit(1)]
        )
        total = int(page.get("total", 0))
        print(f"[COUNT] Total sentences reported by Appwrite: {total}")
        return total
    except Exception as e:
        print(f"[COUNT][WARN] Could not fetch total; progress will be approximate: {e}")
        return 0

# -----------------------
# Resume / logging
# -----------------------
def load_resume_cursor() -> Optional[str]:
    if SENT_RESET_PROGRESS:
        print("[RESUME] SENT_RESET_PROGRESS=true -> ignoring saved cursor")
        return None
    try:
        if os.path.exists(SENT_RESUME_CURSOR_FILE):
            with open(SENT_RESUME_CURSOR_FILE, "r", encoding="utf-8") as f:
                cursor = f.read().strip()
                if cursor:
                    print(f"[RESUME] Loaded last sentence cursor: {cursor}")
                    return cursor
    except Exception as e:
        print(f"[RESUME][WARN] Could not read cursor file: {e}")
    return None

def save_resume_cursor(doc_id: str) -> None:
    try:
        with open(SENT_RESUME_CURSOR_FILE, "w", encoding="utf-8") as f:
            f.write(doc_id)
    except Exception as e:
        print(f"[RESUME][WARN] Could not write cursor file: {e}")

def append_processed_log(doc_id: str, lang_code: str, tokens_count: int, kept_count: int) -> None:
    try:
        with open(SENT_PROCESSED_LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"{doc_id}\t{lang_code}\t{tokens_count}\t{kept_count}\n")
    except Exception as e:
        print(f"[LOG][WARN] Could not append to processed log: {e}")

# -----------------------
# Main
# -----------------------
def process_sentences():
    scanned = 0          # processed in this run
    updated = 0
    total = get_total_sentences_count()

    resume_cursor = load_resume_cursor()
    page_cursor = resume_cursor

    print("[MAIN] Starting sentences processing…")
    if resume_cursor:
        print(f"[MAIN] Resuming after $id={resume_cursor}")

    while True:
        queries = [Query.limit(100), ORDER_ASC("$id")]
        if page_cursor:
            queries.append(Query.cursor_after(page_cursor))
        page = db.list_documents(database_id=DB_ID, collection_id=SENTENCES_COLL, queries=queries)
        docs = page.get("documents", [])
        if not docs:
            break

        for sdoc in docs:
            scanned += 1
            sid = sdoc["$id"]
            text = (sdoc.get("text") or "").strip()
            print(f"\n[SENT] {sid} text='{text[:60]}…'")

            lang_code = sentence_lang_code(sdoc)
            print(f"[SENT] lang_code={lang_code}")
            if not lang_code:
                print(f"[WARN] {sid}: cannot resolve language -> skipping normalization")
                save_resume_cursor(sid)
                append_processed_log(sid, "NA", 0, 0)
                # progress print
                if total:
                    left = max(total - scanned, 0)
                    if scanned % PROGRESS_EVERY == 0 or left == 0:
                        print(f"[PROGRESS] {scanned}/{total} processed; left {left}")
                continue

            # VERB/AUX -> infinitive; other POS -> lemma (unique, order-preserving)
            forms = sentence_infinitives(text, lang_code)
            print(f"[TOK] {sid} produced={len(forms)} forms")

            current = sdoc.get("normalizedWords")
            if not isinstance(current, list):
                current = []

            if current != forms:
                try:
                    db.update_document(
                        database_id=DB_ID,
                        collection_id=SENTENCES_COLL,
                        document_id=sid,
                        data={"normalizedWords": forms},
                    )
                    updated += 1
                    print(f"[WRITE] {sid} normalizedWords updated (old={len(current)} -> new={len(forms)})")
                except Exception as e:
                    print(f"[ERR] Update failed for {sid}: {e}", file=sys.stderr)
            else:
                print(f"[SKIP] {sid} normalizedWords unchanged ({len(forms)})")

            # persist progress
            save_resume_cursor(sid)
            append_processed_log(sid, lang_code, len(forms), len(forms))

            # progress print
            if total:
                left = max(total - scanned, 0)
                if scanned % PROGRESS_EVERY == 0 or left == 0:
                    print(f"[PROGRESS] {scanned}/{total} processed; left {left}")

        page_cursor = docs[-1]["$id"]
        # Also print page-level progress
        if total:
            left = max(total - scanned, 0)
            print(f"[PROGRESS] Page done → {scanned}/{total}; left {left}")

    # Final progress (covers case where 'total' not available)
    if total:
        left = max(total - scanned, 0)
        print(f"\n[SUMMARY] Sentences scanned this run={scanned}, updated={updated}, left={left}")
    else:
        print(f"\n[SUMMARY] Sentences scanned this run={scanned}, updated={updated}")

    print(f"[SUMMARY] Last cursor saved in: {SENT_RESUME_CURSOR_FILE}")
    print(f"[SUMMARY] Processed log appended in: {SENT_PROCESSED_LOG_FILE}")

if __name__ == "__main__":
    process_sentences()
