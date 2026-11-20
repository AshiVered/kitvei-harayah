"""Shared helpers for the Rav Kook library downloaders."""
import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(ROOT, "data", "books")
os.makedirs(DATA_DIR, exist_ok=True)

UA = "KitveiHaRaayahLibrary/1.0 (free offline study app; python-urllib)"


def http_get(url, params=None, data=None, retries=8, timeout=120):
    if params:
        url = url + ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
    body = urllib.parse.urlencode(data).encode() if data else None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, data=body, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504):
                wait = int(e.headers.get("Retry-After") or 0) or 5 * (attempt + 1)
                print(f"  HTTP {e.code}, waiting {wait}s")
                time.sleep(wait)
                continue
            raise
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            print(f"  network error {e}, retrying")
            time.sleep(5 * (attempt + 1))
    raise RuntimeError(f"failed: {url}")


def http_json(url, params=None, data=None):
    return json.loads(http_get(url, params, data).decode("utf-8"))


_ONES = ["", "א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"]
_TENS = ["", "י", "כ", "ל", "מ", "נ", "ס", "ע", "פ", "צ"]
_HUNDREDS = ["", "ק", "ר", "ש", "ת"]


def heb_num(n: int) -> str:
    """Hebrew numeral (gematria) without geresh, e.g. 15 -> טו."""
    if n <= 0:
        return str(n)
    out = ""
    thousands, n = divmod(n, 1000)
    if thousands:
        out += heb_num(thousands) + "'"
    while n >= 400:
        out += "ת"
        n -= 400
    out += _HUNDREDS[n // 100]
    n %= 100
    if n == 15:
        out += "טו"
    elif n == 16:
        out += "טז"
    else:
        out += _TENS[n // 10] + _ONES[n % 10]
    return out


_WS = re.compile(r"[ \t ‏‎]+")


def clean_text(s: str) -> str:
    s = s.replace("\r", "")
    s = _WS.sub(" ", s)
    s = re.sub(r" *\n *", "\n", s)
    s = re.sub(r"\n{3,}", "\n\n", s)
    return s.strip()


def save_book(book: dict):
    # drop empty sections at the tail, count stats
    paras = sum(len(s["p"]) for s in book["sections"])
    chars = sum(len(p) for s in book["sections"] for p in s["p"])
    book["stats"] = {"sections": len(book["sections"]), "paragraphs": paras, "chars": chars}
    path = os.path.join(DATA_DIR, book["id"] + ".json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(book, f, ensure_ascii=False)
    print(f"saved {book['id']}: {len(book['sections'])} sections, {paras} paragraphs, {chars:,} chars")
