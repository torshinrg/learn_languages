#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
LibriVox → Gutenberg pipeline (single + bulk) with:
- LibriVox-first description (HTML→plain text)
- Robust LibriVox lookup: API (query & path) + fuzzy + HTML results parsing
- Project Gutenberg fallback lookup by title if LV lacks a link
- Gutenberg text download + cleaning (per spec)
- Bulk via --input-jsonl; preserves input_language & language_level
- Verbose debug to STDERR + structured 'debug' object in JSON with --dump-all

Usage
-----
  python librivox_gutenberg.py --input-jsonl books.jsonl --save both --outdir ./out --dump-all --verbose
"""

import argparse, csv, json, re, sys, time, urllib.parse
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from difflib import SequenceMatcher

import requests
from bs4 import BeautifulSoup
from xml.etree import ElementTree as ET

# --------------------
# Config & Session
# --------------------
LV_API = "https://librivox.org/api/feed/audiobooks"  # no trailing slash
GB_LANDING = "https://www.gutenberg.org/ebooks/{gid}"
GB_RDF = "https://www.gutenberg.org/cache/epub/{gid}/pg{gid}.rdf"
GB_CACHE = "https://www.gutenberg.org/cache/epub/{gid}/"

UA = "Fluentano-LV-GB-Pipeline/1.6 (+https://fluentano.space; contact: dev@fluentano.space)"
sess = requests.Session()
sess.headers.update({"User-Agent": UA})
TIMEOUT = 25

def log(msg: str, verbose: bool):
    if verbose:
        print(msg, file=sys.stderr, flush=True)

# --------------------
# Models
# --------------------
@dataclass
class LibriVoxInfo:
    id: Optional[int]
    title: str
    authors: List[str]
    language: Optional[str]
    url_librivox: Optional[str]
    url_text_source: Optional[str]
    coverart_thumbnail: Optional[str]
    raw: Dict[str, Any]  # API fields or scraped HTML fields

@dataclass
class GutenbergInfo:
    gid: int
    title: Optional[str]
    authors: List[str]
    language: Optional[str]
    subjects: List[str]
    issued: Optional[str]
    cover_small: Optional[str]
    cover_medium: Optional[str]
    landing_url: str
    text_url: Optional[str]
    credits: Optional[str]
    # debug
    rdf_descriptions: List[str]
    rdf_formats: List[str]
    html_meta_description: Optional[str]
    html_ld_description: Optional[str]
    html_block_descriptions: List[str]
    text_url_candidates: List[str]

@dataclass
class Record:
    # requested
    input_title: Optional[str]
    input_language: Optional[str]
    language_level: Optional[str]
    # LibriVox
    librivox_id: Optional[int]
    librivox_title: Optional[str]
    librivox_language: Optional[str]
    librivox_url: Optional[str]
    librivox_text_source: Optional[str]
    librivox_cover_thumbnail: Optional[str]
    # Gutenberg
    gutenberg_id: int
    title: Optional[str]
    authors: List[str]
    language: Optional[str]
    subjects: List[str]
    description: Optional[str]
    credits: Optional[str]
    issued: Optional[str]
    cover_small: Optional[str]
    cover_medium: Optional[str]
    landing_url: str
    text_url: Optional[str]
    # local
    saved_text_path: Optional[str]
    saved_text_path_raw: Optional[str]

# --------------------
# Utilities
# --------------------
def slugify(s: str) -> str:
    s = re.sub(r"[^\w\s-]", "", s, flags=re.UNICODE)
    s = re.sub(r"\s+", "-", s.strip(), flags=re.UNICODE)
    return (s or "book").lower()[:96]

def safe_int(x) -> Optional[int]:
    try: return int(x)
    except: return None

def normalize_title(t: str) -> str:
    if not t: return ""
    repl = {"’":"'","‘":"'","“":'"',"”":'"',"–":"-","—":"-","…":"...","\u00a0":" "}
    for k,v in repl.items(): t = t.replace(k, v)
    t = re.sub(r"\s+", " ", t).strip().lower()
    return t

def title_similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, normalize_title(a), normalize_title(b)).ratio()

def lang_norm(x: Optional[str]) -> str:
    if not x: return ""
    x = x.strip().lower()
    return {"en":"english","eng":"english"}.get(x, x)

# --------------------
# LibriVox API (robust) + HTML fallback
# --------------------
def lv_api_request(url: str, params: Dict[str, str], verbose=False, note="") -> List[Dict[str, Any]]:
    log(f"[LV][API]{note} GET {url} params={params}", verbose)
    r = sess.get(url, params=params, timeout=TIMEOUT)
    log(f"[LV][API] -> status {r.status_code}", verbose)
    if r.status_code in (400,404): return []
    r.raise_for_status()
    data = r.json()
    return data.get("books", []) or []

def lv_search_api(title: Optional[str], author: Optional[str], lv_id: Optional[int], limit: int = 20, verbose=False) -> List[Dict[str, Any]]:
    base_params = {"format":"json","extended":"1","limit":str(limit)}
    # A) query-string
    try:
        params = dict(base_params)
        if lv_id: params["id"] = str(lv_id)
        if title: params["title"] = normalize_title(title)
        if author: params["author"] = author
        books = lv_api_request(LV_API, params, verbose, " [query]")
        if books: return books
    except requests.RequestException as e:
        log(f"[LV][API] query error: {e}", verbose)
    # B) path-style /title/<q>
    if title:
        try:
            url = f"{LV_API}/title/{urllib.parse.quote(normalize_title(title))}"
            books = lv_api_request(url, base_params, verbose, " [path]")
            if books: return books
        except requests.RequestException as e:
            log(f"[LV][API] path error: {e}", verbose)
        # C) anchored prefix
        prefix = " ".join(normalize_title(title).split()[:3])
        if prefix:
            try:
                url = f"{LV_API}/title/%5E{urllib.parse.quote(prefix)}"
                books = lv_api_request(url, base_params, verbose, " [path^]")
                if books: return books
            except requests.RequestException as e:
                log(f"[LV][API] path^ error: {e}", verbose)
    # D) id-only
    if lv_id:
        try:
            return lv_api_request(LV_API, {"format":"json","extended":"1","id":str(lv_id)}, verbose, " [id-only]")
        except requests.RequestException as e:
            log(f"[LV][API] id-only error: {e}", verbose)
    return []

def parse_lv_book_api(b: Dict[str, Any]) -> LibriVoxInfo:
    authors = []
    for a in b.get("authors", []) or []:
        name = " ".join(filter(None, [a.get("first_name"), a.get("last_name")])).strip()
        if name: authors.append(name)
    return LibriVoxInfo(
        id = safe_int(b.get("id")),
        title = b.get("title") or "",
        authors = authors,
        language = b.get("language"),
        url_librivox = b.get("url_librivox"),
        url_text_source = b.get("url_text_source"),
        coverart_thumbnail = (b.get("coverart_thumbnail") or b.get("coverart_jpg")),
        raw = b
    )

def choose_best_api_book(books: List[Dict[str, Any]], wanted_title: str, wanted_lang: Optional[str], verbose=False) -> Optional[LibriVoxInfo]:
    if not books: return None
    wanted_lang = lang_norm(wanted_lang)
    scored = []
    for b in books:
        t = b.get("title") or ""
        s = title_similarity(t, wanted_title)
        lang_bonus = 0.05 if (wanted_lang == "" or lang_norm(b.get("language")) == wanted_lang) else 0
        scored.append((s + lang_bonus, t, b))
    scored.sort(key=lambda x: x[0], reverse=True)
    if verbose:
        log("[LV][API] candidates (score,title): " + "; ".join([f"{s:.2f},{t}" for s,t,_ in scored[:5]]), True)
    best_score, _, best_b = scored[0]
    if best_score < 0.50:
        return None
    return parse_lv_book_api(best_b)

# ---- HTML fallback search (robust result picking) ----
def lv_search_html_best_project(title: str, verbose=False) -> Optional[str]:
    q = normalize_title(title)
    params = {"q": q, "search_form": "advanced"}
    url = "https://librivox.org/search"
    try:
        log(f"[LV][HTML] search GET {url} {params}", verbose)
        r = sess.get(url, params=params, timeout=TIMEOUT)
        log(f"[LV][HTML] -> status {r.status_code}", verbose)
        if r.status_code != 200: return None
        soup = BeautifulSoup(r.text, "html.parser")
        # pick anchors that look like catalog items
        candidates = []
        for a in soup.select("a[href]"):
            href = a.get("href","")
            text = a.get_text(" ", strip=True)
            if not href.startswith("http"):
                href = urllib.parse.urljoin("https://librivox.org/", href)
            # basic filter: project pages are top-level titles (not /author/, /reader/, /search)
            if "librivox.org" in href and all(k not in href for k in ("/author/","/reader/","/search")):
                score = title_similarity(text, title)
                candidates.append((score, text, href))
        candidates.sort(key=lambda x: x[0], reverse=True)
        if verbose and candidates:
            log("[LV][HTML] result candidates: " + "; ".join([f"{s:.2f},{t}" for s,t,_ in candidates[:5]]), True)
        return candidates[0][2] if candidates and candidates[0][0] >= 0.40 else None
    except requests.RequestException as e:
        log(f"[LV][HTML] search error: {e}", verbose)
        return None

def lv_scrape_project(url: str, verbose=False) -> Optional[LibriVoxInfo]:
    try:
        log(f"[LV][HTML] project GET {url}", verbose)
        r = sess.get(url, timeout=TIMEOUT)
        log(f"[LV][HTML] -> status {r.status_code}", verbose)
        if r.status_code != 200: return None
        soup = BeautifulSoup(r.text, "html.parser")
        title = (soup.find("h1").get_text(" ", strip=True) if soup.find("h1") else "") or ""

        # description HTML
        desc_container = (soup.select_one(".product-description")
                          or soup.select_one(".description")
                          or soup.select_one(".book-page .descr")
                          or soup.select_one("#description"))
        description_html = (desc_container.decode() if desc_container else None)

        # language (from metadata list)
        lang = None
        for li in soup.select("li"):
            txt = li.get_text(" ", strip=True)
            if txt.lower().startswith("language:"):
                lang = txt.split(":",1)[1].strip()
                break

        # authors (light)
        authors = []
        for a in soup.select('a[href*="/author/"]'):
            txt = a.get_text(" ", strip=True)
            if txt: authors.append(txt)
        authors = list(dict.fromkeys(authors))

        # find ALL links, report which matched Gutenberg
        links = []
        guten_links = []
        for a in soup.select("#content a[href], a[href]"):
            href = a.get("href","").strip()
            txt = a.get_text(" ", strip=True)
            if not href: continue
            if not href.startswith("http"):
                href = urllib.parse.urljoin(url, href)
            links.append({"href": href, "text": txt})
            if "gutenberg.org" in href.lower():
                guten_links.append(href)

        text_src = guten_links[0] if guten_links else None

        thumb = None
        img = soup.select_one("img.book-cover, img.cover, .book-page img")
        if img and img.get("src"):
            thumb = urllib.parse.urljoin(url, img["src"])

        raw = {
            "title": title,
            "description": description_html,
            "url_librivox": url,
            "url_text_source": text_src,
            "language": lang,
            "authors_scraped": authors,
            "coverart_thumbnail": thumb,
            "links_sample": links[:20],  # keep it small
        }
        return LibriVoxInfo(
            id=None, title=title, authors=authors, language=lang,
            url_librivox=url, url_text_source=text_src,
            coverart_thumbnail=thumb, raw=raw
        )
    except requests.RequestException as e:
        log(f"[LV][HTML] project error: {e}", verbose)
        return None

def lv_lookup(title: str, language: Optional[str], verbose=False) -> Tuple[Optional[LibriVoxInfo], Dict[str, Any]]:
    dbg = {"title": title, "lang": language, "api": {}, "html": {}}

    # 1) API
    api_books = lv_search_api(title, None, None, limit=25, verbose=verbose)
    dbg["api"]["count"] = len(api_books)
    if api_books:
        chosen = choose_best_api_book(api_books, title, language, verbose=verbose)
        if chosen:
            dbg["api"]["chosen"] = {"title": chosen.title, "lang": chosen.language, "url": chosen.url_librivox,
                                    "url_text_source": chosen.url_text_source}
            return chosen, dbg
    # 2) HTML search → project
    proj_url = lv_search_html_best_project(title, verbose=verbose)
    dbg["html"]["search_url"] = "https://librivox.org/search"
    dbg["html"]["project_url"] = proj_url
    if not proj_url:
        return None, dbg
    scraped = lv_scrape_project(proj_url, verbose=verbose)
    if scraped:
        dbg["html"]["scraped_has_gutenberg"] = bool(scraped.url_text_source)
        return scraped, dbg
    return None, dbg

# --------------------
# Project Gutenberg helpers (incl. fallback)
# --------------------
NS = {
    "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    "dcterms": "http://purl.org/dc/terms/",
    "pgterms": "http://www.gutenberg.org/2009/pgterms/",
}

def gb_fetch_rdf(gid: int) -> Optional[str]:
    url = GB_RDF.format(gid=gid)
    r = sess.get(url, timeout=TIMEOUT)
    return r.text if r.status_code == 200 else None

def text_or_none(el) -> Optional[str]:
    return (el.text.strip() if (el is not None and el.text) else None)

def pick_text_url_from_list(gid: int, urls: List[str]) -> Optional[str]:
    if not urls: return None
    utf8 = [u for u in urls if u.endswith(".txt.utf-8") or u.endswith(f"/{gid}-0.txt")]
    if utf8: return utf8[0]
    txts = [u for u in urls if u.endswith(".txt")]
    return txts[0] if txts else None

def gb_from_rdf(xml: str, gid: int) -> Dict[str, Any]:
    root = ET.fromstring(xml.encode("utf-8"))
    ebook = root.find(".//pgterms:ebook", NS)
    if ebook is None: return {}
    title = text_or_none(ebook.find("dcterms:title", NS))
    authors = []
    for creator in ebook.findall("dcterms:creator", NS):
        agent = creator.find(".//pgterms:agent", NS)
        name = text_or_none(agent.find("pgterms:name", NS)) if agent is not None else None
        if name: authors.append(name)
    language = None
    lang = ebook.find("dcterms:language", NS)
    if lang is not None:
        val = lang.find(".//rdf:value", NS)
        language = text_or_none(val)
    subjects = []
    for subj in ebook.findall("dcterms:subject", NS):
        val = subj.find(".//rdf:value", NS)
        t = text_or_none(val)
        if t: subjects.append(t)
    issued = text_or_none(ebook.find("dcterms:issued", NS))
    rdf_descriptions = [text_or_none(n) for n in ebook.findall("dcterms:description", NS)]
    rdf_descriptions = [d for d in rdf_descriptions if d]
    rdf_formats = []
    for el in ebook.findall(".//dcterms:hasFormat", NS):
        href = el.attrib.get("{%s}resource" % NS["rdf"])
        if href: rdf_formats.append(href)
    text_url = pick_text_url_from_list(gid, rdf_formats)
    cover_small = f"{GB_CACHE.format(gid=gid)}pg{gid}.cover.small.jpg"
    cover_medium = f"{GB_CACHE.format(gid=gid)}pg{gid}.cover.medium.jpg"
    return {
        "title": title, "authors": authors, "language": language,
        "subjects": subjects, "issued": issued,
        "rdf_descriptions": rdf_descriptions, "rdf_formats": rdf_formats,
        "cover_small": cover_small, "cover_medium": cover_medium,
        "text_url": text_url
    }

def get_landing_soup(gid: int) -> Optional[BeautifulSoup]:
    try:
        r = sess.get(GB_LANDING.format(gid=gid), timeout=TIMEOUT)
        if r.status_code != 200: return None
        return BeautifulSoup(r.text, "html.parser")
    except requests.RequestException:
        return None

def parse_html_meta_description(soup: BeautifulSoup) -> Optional[str]:
    el = soup.find("meta", attrs={"name": "description"})
    return (el.get("content", "").strip() if el and el.get("content") else None)

def parse_html_jsonld_description(soup: BeautifulSoup) -> Optional[str]:
    for s in soup.find_all("script", attrs={"type": "application/ld+json"}):
        try: data = json.loads(s.string or "{}")
        except Exception: continue
        if isinstance(data, dict) and isinstance(data.get("description"), str):
            return data["description"].strip()
        if isinstance(data, list):
            for item in data:
                if isinstance(item, dict) and isinstance(item.get("description"), str):
                    return item["description"].strip()
    return None

def parse_visible_block_descriptions(soup: BeautifulSoup) -> List[str]:
    blocks = []
    for h in soup.find_all(["h2","h3","h4"]):
        label = (h.get_text(" ", strip=True) or "").lower()
        if any(k in label for k in ["description","summary"]):
            paras, sib = [], h.find_next_sibling()
            while sib and len(paras) < 3:
                if sib.name in ["p","div","section"]:
                    txt = sib.get_text(" ", strip=True)
                    if txt and len(txt) > 40: paras.append(txt)
                sib = sib.find_next_sibling()
            if paras: blocks.append(" ".join(paras))
    for c in soup.select('.book-description, .description, .about, #about, .summary'):
        txt = c.get_text(" ", strip=True)
        if txt and len(txt) > 40: blocks.append(txt)
    seen, uniq = set(), []
    for b in blocks:
        if b not in seen: seen.add(b); uniq.append(b)
    return uniq

def parse_credits_and_language_from_reader_html(gid: int) -> Tuple[Optional[str], Optional[str]]:
    urls = [f"{GB_CACHE.format(gid=gid)}pg{gid}-images.html", f"{GB_CACHE.format(gid=gid)}pg{gid}.html"]
    for url in urls:
        try:
            r = sess.get(url, timeout=TIMEOUT)
            if r.status_code != 200: continue
            soup = BeautifulSoup(r.text, "html.parser")
            text = soup.get_text("\n", strip=True)
            credits  = _extract_line_value(text, "Credits:")
            language = _extract_line_value(text, "Language:")
            return credits, language
        except requests.RequestException:
            continue
    return None, None

def _extract_line_value(body: str, key: str) -> Optional[str]:
    m = re.search(rf"^{re.escape(key)}\s*(.+)$", body, flags=re.M)
    return m.group(1).strip() if m else None

def discover_text_url_candidates(gid: int) -> List[str]:
    cands = [
        f"https://www.gutenberg.org/ebooks/{gid}.txt.utf-8",
        f"https://www.gutenberg.org/files/{gid}/{gid}-0.txt",
        f"https://www.gutenberg.org/files/{gid}/{gid}.txt",
        f"https://www.gutenberg.org/cache/epub/{gid}/pg{gid}.txt",
    ]
    soup = get_landing_soup(gid)
    if soup:
        for a in soup.select("a[href]"):
            href = a.get("href", "")
            if href.endswith(".txt") or href.endswith(".txt.utf-8"):
                cands.append(requests.compat.urljoin(GB_LANDING.format(gid=gid), href))
    out, seen = [], set()
    for u in cands:
        if u not in seen:
            out.append(u); seen.add(u)
    return out

def prefer_utf8_text_url(cands: List[str]) -> Optional[str]:
    for u in cands:
        if u.endswith(".txt.utf-8"): return u
    for u in cands:
        if u.endswith("-0.txt"): return u
    for u in cands:
        if u.endswith(".txt"): return u
    return None

def gb_collect(gid: int) -> GutenbergInfo:
    landing_url = GB_LANDING.format(gid=gid)
    rdf_text = gb_fetch_rdf(gid)
    rdf_data = {"title": None, "authors": [], "language": None, "subjects": [], "issued": None,
                "rdf_descriptions": [], "rdf_formats": [], "cover_small": None, "cover_medium": None, "text_url": None}
    if rdf_text:
        try: rdf_data.update(gb_from_rdf(rdf_text, gid))
        except Exception: pass
    soup = get_landing_soup(gid)
    html_meta_description = parse_html_meta_description(soup) if soup else None
    html_ld_description   = parse_html_jsonld_description(soup) if soup else None
    html_block_descriptions = parse_visible_block_descriptions(soup) if soup else []
    credits, language_from_reader = parse_credits_and_language_from_reader_html(gid)
    text_candidates = discover_text_url_candidates(gid)
    chosen_text = rdf_data["text_url"]
    if chosen_text and not chosen_text.endswith(".txt.utf-8"):
        pref = prefer_utf8_text_url(text_candidates)
        if pref: chosen_text = pref
    if not chosen_text:
        chosen_text = prefer_utf8_text_url(text_candidates)
    language = rdf_data["language"] or language_from_reader
    return GutenbergInfo(
        gid=gid,
        title=rdf_data["title"],
        authors=rdf_data["authors"],
        language=language,
        subjects=rdf_data["subjects"],
        issued=rdf_data["issued"],
        cover_small=rdf_data["cover_small"],
        cover_medium=rdf_data["cover_medium"],
        landing_url=landing_url,
        text_url=chosen_text,
        credits=credits,
        rdf_descriptions=rdf_data["rdf_descriptions"],
        rdf_formats=rdf_data["rdf_formats"],
        html_meta_description=html_meta_description,
        html_ld_description=html_ld_description,
        html_block_descriptions=html_block_descriptions,
        text_url_candidates=text_candidates,
    )

# ---- PG FALLBACK: search by title to get an ebook id if LV lacked url_text_source
def pg_lookup_by_title(title: str, verbose=False) -> Optional[str]:
    # returns full ebook URL like https://www.gutenberg.org/ebooks/<id>
    q = normalize_title(title)
    url = "https://www.gutenberg.org/ebooks/search/"
    params = {"query": q}
    try:
        log(f"[PG][search] GET {url} {params}", verbose)
        r = sess.get(url, params=params, timeout=TIMEOUT)
        log(f"[PG][search] -> status {r.status_code}", verbose)
        if r.status_code != 200: return None
        soup = BeautifulSoup(r.text, "html.parser")
        # pick first result link with href /ebooks/<id>
        best = None
        best_score = 0.0
        for a in soup.select("a[href^='/ebooks/']"):
            href = a.get("href","")
            txt = a.get_text(" ", strip=True)
            score = title_similarity(txt, title)
            if score > best_score:
                best_score, best = score, href
        if best and best_score >= 0.40:
            return urllib.parse.urljoin("https://www.gutenberg.org", best)
        return None
    except requests.RequestException as e:
        log(f"[PG][search] error: {e}", verbose)
        return None

# --------------------
# IO & sinks
# --------------------
def download_text(url: str, path: Path) -> None:
    with sess.get(url, stream=True, timeout=TIMEOUT) as r:
        r.raise_for_status()
        with path.open("wb") as f:
            for chunk in r.iter_content(chunk_size=16384):
                if chunk: f.write(chunk)

def append_jsonl(p: Path, rec: Dict[str, Any]) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")

def append_csv(p: Path, rec: Dict[str, Any]) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    flat = {k: (" | ".join(map(str, v)) if isinstance(v, list) else v) for k, v in rec.items()}
    file_exists = p.exists()
    with p.open("a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(flat.keys()))
        if not file_exists: w.writeheader()
        w.writerow(flat)

# --------------------
# Cleaning (per your spec)
# --------------------
START_RE = re.compile(r'^\*{3}\s*START OF.*?PROJECT GUTENBERG.*?\*{3}\s*$', re.I | re.M)
END_RE   = re.compile(r'^\*{3}\s*END OF.*?PROJECT GUTENBERG.*?\*{3}\s*$',   re.I | re.M)

def clean_text(raw: str, unwrap: bool=False) -> str:
    text = raw.replace("\r\n", "\n").replace("\r", "\n")
    if text.startswith("\ufeff"): text = text.lstrip("\ufeff")
    start_m = START_RE.search(text); end_m = END_RE.search(text)
    if start_m and end_m and start_m.end() < end_m.start():
        text = text[start_m.end():end_m.start()]
    elif end_m:
        text = text[:end_m.start()]
    elif start_m:
        text = text[start_m.end():]
    else:
        m = re.search(r'^START:\s*FULL LICENSE.*$', text, re.I | re.M)
        if m: text = text[:m.start()]

    text = re.sub(r'\[Illustration:[^\]]*\]', '', text, flags=re.I | re.S)
    text = re.sub(r'\[(?:Illustration|Illustrations|Plate[^\]]*|Frontispiece[^\]]*)\]', '', text, flags=re.I)

    def strip_edge_colophons(seg: str) -> str:
        lines, keep = seg.splitlines(), []
        for ln in lines:
            s = ln.strip()
            if not s: keep.append(ln); continue
            if re.search(r'\b(CHISWICK|PRESS|PUBLISHER|HOUSE|COURT|ROAD|LONDON|NEW YORK|WHITTINGHAM)\b', s): continue
            if s.isupper() and len(s) <= 120 and re.search(r'[A-Z]{3}', s): continue
            keep.append(ln)
        return "\n".join(keep)

    if len(text) > 4000:
        head, mid, tail = text[:2000], text[2000:-2000], text[-2000:]
        text = strip_edge_colophons(head) + mid + strip_edge_colophons(tail)
    else:
        text = strip_edge_colophons(text)

    text = re.sub(r'^(Produced by.*)$', '', text, flags=re.I | re.M)
    text = re.sub(r'^(Credits?:.*)$',   '', text, flags=re.I | re.M)
    text = re.sub(r'^(Proofreading Team.*)$', '', text, flags=re.I | re.M)
    text = re.sub(r'^(Online Distributed Proofreading.*)$', '', text, flags=re.I | re.M)
    text = re.sub(r'https?://\S*(pgdp|proofread)\S*', '', text, flags=re.I)

    text = text.replace("\u00AD", "")
    text = re.sub(r'-\n(?=[A-Za-z])', '', text)

    if unwrap:
        paras = [p.strip() for p in re.split(r'\n{2,}', text)]
        paras = [re.sub(r'\s*\n\s*', ' ', p) for p in paras]
        text = "\n\n".join(paras)

    text = re.sub(r'(?<!\w)_(.+?)_(?!\w)', r'\1', text, flags=re.S)
    text = re.sub(r'[ \t]+\n', '\n', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()

def html_to_text(html: Optional[str]) -> Optional[str]:
    if not html: return None
    try:
        soup = BeautifulSoup(html, "html.parser")
        return soup.get_text(" ", strip=True)
    except Exception:
        return re.sub(r'<[^>]+>', '', html).strip()

# --------------------
# Core per-item
# --------------------
def extract_gid_from_url(u: Optional[str]) -> Optional[int]:
    if not u: return None
    m = re.search(r"/ebooks/(\d+)", u) or re.search(r"/etext/(\d+)", u)
    return int(m.group(1)) if m else None

def process_single_item(title: str, input_language: Optional[str], language_level: Optional[str],
                        outdir: Path, save: str, unwrap: bool, dump_all: bool, verbose: bool,
                        sleep_s: float=0.6, pg_fallback: bool=True) -> Dict[str, Any]:
    lv, lv_dbg = lv_lookup(title, input_language, verbose=verbose)
    if not lv:
        return {"ok": False, "stage": "select", "error": "No LibriVox match", "input_title": title, "debug": lv_dbg}

    gid = extract_gid_from_url(lv.url_text_source)
    pg_used = False
    if not gid and pg_fallback:
        log(f"[PG][fallback] No LV Gutenberg link for '{title}'. Trying PG search…", verbose)
        pg_url = pg_lookup_by_title(title, verbose=verbose)
        if pg_url:
            gid = extract_gid_from_url(pg_url)
            if gid:
                pg_used = True
                # record the link back into LV raw for transparency
                lv.raw["url_text_source_fallback"] = pg_url

    if not gid:
        return {"ok": False, "stage": "link", "error": "No Project Gutenberg link in url_text_source", "input_title": title, "debug": lv_dbg}

    # Gutenberg
    gb = gb_collect(gid)

    # Dirs
    books_dir = outdir / "books"
    books_dir.mkdir(parents=True, exist_ok=True)

    # Download + clean
    saved_raw = saved_clean = None
    chosen_text_url = gb.text_url
    t_slug = slugify(gb.title or lv.title or f"book-{gid}")
    raw_path = books_dir / f"gutenberg_{gid}_{t_slug}.txt"
    clean_path = books_dir / f"gutenberg_{gid}_{t_slug}.clean.txt"

    if chosen_text_url:
        try:
            log(f"[DL] GET {chosen_text_url}", verbose)
            download_text(chosen_text_url, raw_path)
            saved_raw = str(raw_path)
            raw_txt = raw_path.read_text(encoding="utf-8", errors="replace")
            cleaned = clean_text(raw_txt, unwrap=unwrap)
            clean_path.write_text(cleaned, encoding="utf-8")
            saved_clean = str(clean_path)
            log(f"[DL] saved RAW={saved_raw} CLEAN={saved_clean}", verbose)
        except Exception as e:
            log(f"[DL] error: {e}", verbose)

    lv_desc_plain = html_to_text(lv.raw.get("description"))

    rec = Record(
        input_title=title,
        input_language=input_language,
        language_level=language_level,

        librivox_id=lv.id,
        librivox_title=lv.title,
        librivox_language=lv.language,
        librivox_url=lv.url_librivox,
        librivox_text_source=lv.url_text_source or lv.raw.get("url_text_source_fallback"),
        librivox_cover_thumbnail=lv.coverart_thumbnail,

        gutenberg_id=gb.gid,
        title=gb.title or lv.title,
        authors=gb.authors if gb.authors else lv.authors,
        language=gb.language,
        subjects=gb.subjects,
        description=lv_desc_plain,
        credits=gb.credits,
        issued=gb.issued,
        cover_small=gb.cover_small,
        cover_medium=gb.cover_medium,
        landing_url=gb.landing_url,
        text_url=gb.text_url,

        saved_text_path=saved_clean or saved_raw,
        saved_text_path_raw=saved_raw
    )
    rec_dict = asdict(rec)

    # Persist
    to_save = set([s.strip().lower() for s in (save.split(",") if save else ["json"])])
    if "json" in to_save or "both" in to_save:
        append_jsonl(outdir / "books_meta.jsonl", rec_dict)
    if "csv" in to_save or "both" in to_save:
        append_csv(outdir / "books_meta.csv", rec_dict)

    time.sleep(sleep_s)

    if dump_all:
        return {
            "ok": True,
            "selected_record": rec_dict,
            "debug": {
                "librivox_lookup": lv_dbg,
                "pg_fallback_used": pg_used,
                "gutenberg_debug": {
                    "gid": gb.gid,
                    "landing_url": gb.landing_url,
                    "rdf": {
                        "title": gb.title,
                        "authors": gb.authors,
                        "language": gb.language,
                        "subjects": gb.subjects,
                        "issued": gb.issued,
                        "descriptions_all": gb.rdf_descriptions,
                        "formats_all": gb.rdf_formats,
                    },
                    "html": {
                        "meta_description": gb.html_meta_description,
                        "jsonld_description": gb.html_ld_description,
                        "block_descriptions": gb.html_block_descriptions,
                        "credits": gb.credits,
                    },
                    "text": {
                        "chosen": gb.text_url,
                        "candidates": gb.text_url_candidates,
                    },
                    "covers": {"small": gb.cover_small, "medium": gb.cover_medium}
                }
            }
        }
    else:
        return {"ok": True, "record": rec_dict}

# --------------------
# CLI
# --------------------
def main():
    ap = argparse.ArgumentParser(description="LibriVox → Gutenberg fetcher (single or bulk JSONL).")
    g = ap.add_mutually_exclusive_group(required=False)
    g.add_argument("--librivox-id", type=int)
    g.add_argument("--title", type=str)
    ap.add_argument("--author", type=str)
    ap.add_argument("--input-jsonl", type=str, help="Path to JSON Lines with {'title','language','language_level'}")
    ap.add_argument("--limit", type=int, default=20)
    ap.add_argument("--outdir", type=str, default=".")
    ap.add_argument("--save", type=str, default="json", help="json,csv,both")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--dump-all", action="store_true")
    ap.add_argument("--unwrap", action="store_true", help="Unwrap prose paragraphs")
    ap.add_argument("--sleep", type=float, default=0.6, help="Seconds between bulk items")
    ap.add_argument("--verbose", action="store_true", help="Verbose logs to STDERR")
    ap.add_argument("--no-pg-fallback", action="store_true", help="Disable PG fallback when LV lacks a link")
    args = ap.parse_args()

    outdir = Path(args.outdir).expanduser().resolve()

    # BULK
    if args.input_jsonl:
        infile = Path(args.input_jsonl).expanduser().resolve()
        if not infile.exists():
            print(json.dumps({"ok": False, "stage": "input", "error": f"File not found: {infile}"}))
            sys.exit(1)
        with infile.open("r", encoding="utf-8") as f:
            for idx, line in enumerate(f, 1):
                line = line.strip()
                if not line: continue
                try:
                    item = json.loads(line)
                except Exception as e:
                    print(json.dumps({"ok": False, "stage": "parse", "line": idx, "error": str(e)})); continue
                title = (item.get("title") or "").strip()
                input_lang = (item.get("language") or "").strip() or None
                lvl = (item.get("language_level") or "").strip() or None
                if not title:
                    print(json.dumps({"ok": False, "stage": "input", "line": idx, "error": "Missing 'title'"})); continue

                if args.dry_run:
                    lv, lv_dbg = lv_lookup(title, input_lang, verbose=args.verbose)
                    if not lv:
                        print(json.dumps({"ok": False, "line": idx, "error": "No LibriVox match", "input_title": title, "debug": lv_dbg})); continue
                    gid = extract_gid_from_url(lv.url_text_source)
                    if not gid and not args.no_pg_fallback:
                        pg_url = pg_lookup_by_title(title, verbose=args.verbose)
                        gid = extract_gid_from_url(pg_url) if pg_url else None
                    if not gid:
                        print(json.dumps({"ok": False, "line": idx, "error": "No Gutenberg link", "input_title": title, "debug": lv_dbg})); continue
                    gb = gb_collect(gid)
                    print(json.dumps({"ok": True, "line": idx, "preview": {
                        "title": gb.title or lv.title, "gutenberg_id": gid, "text_url": gb.text_url
                    }}, ensure_ascii=False)); continue

                res = process_single_item(
                    title=title,
                    input_language=input_lang,
                    language_level=lvl,
                    outdir=outdir,
                    save=args.save,
                    unwrap=args.unwrap,
                    dump_all=args.dump_all,
                    verbose=args.verbose,
                    sleep_s=args.sleep,
                    pg_fallback=not args.no_pg_fallback
                )
                print(json.dumps({"line": idx, **res}, ensure_ascii=False))
        return

    # SINGLE
    if not args.title and not args.librivox_id:
        print(json.dumps({"ok": False, "stage": "args", "error": "Provide --input-jsonl OR --title/--librivox-id"}))
        sys.exit(1)

    res = process_single_item(
        title=args.title or "",
        input_language=None,
        language_level=None,
        outdir=outdir,
        save=args.save,
        unwrap=args.unwrap,
        dump_all=args.dump_all,
        verbose=args.verbose,
        sleep_s=0.0,
        pg_fallback=not args.no_pg_fallback
    )
    print(json.dumps(res, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
