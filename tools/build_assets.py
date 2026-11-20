"""Pack data/books/*.json into Flutter assets (gzip) + catalog.json.

Usage: python tools/build_assets.py
"""
import glob
import gzip
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "data", "books")
OUT = os.path.join(ROOT, "assets", "books")
os.makedirs(OUT, exist_ok=True)

CATEGORY_ORDER = [
    "אמונה", "קבצים ופנקסים", "מוסר ומידות",
    "תפילה ומועדים", "דרשות ומאמרים", "אגרות", "הלכה",
]
# Categories assigned by the downloaders, merged for display.
CATEGORY_MERGE = {"ספרי אורות": "אמונה", "אגדה ומחשבה": "אמונה"}


def work_key(title):
    t = re.sub(r"[\"'״׳]", "", title)
    t = t.replace("הקדש", "הקודש").replace("ראייה", "ראיה")
    return re.sub(r"\s+", " ", t).strip()


WIKISOURCE_LICENSE = "CC-BY-SA"
EXCLUDE = {"לנבוכי הדור"}


def has_declared_license(book, sefaria_versions):
    """Only editions whose license is declared at the source are included.
    Sefaria: "Texts with no noted license have not yet had their copyright status
    verified by Sefaria" (developers.sefaria.org, Copyright and Data Use)."""
    if book["source"] == "wikisource":
        return True
    versions = sefaria_versions.get(book["id"], [])
    return bool(versions) and all((v["license"] or "unknown") != "unknown" for v in versions)


SEPARATOR = re.compile(r"^[\s_\-–—=*.·•]+$")


# Only web material is removed: what the printed book contains (editors' introductions and notes,
# acknowledgements, publication details) stays. Removed: Wikisource users' summaries, Wikisource's
# own descriptions of the book, and site notices.
EDITORIAL_TITLES = re.compile(r"^(סיכום|מכאן והלאה נמחק.*)$")
EDITORIAL_BY_BOOK = {}
EDITORIAL_PARAS = re.compile(
    r"^(הערה: הסיכומים"                    # "the summaries were written by Wikisource users"
    r"|בגליון הבא מופיעה"                 # Wikisource note on a newspaper letter
    r"|חלוקה ל-?\d+ פיסקאות"              # Wikisource's own paragraph division note
    r"|הספר ניתן על ידי העורך והועלה לאתר"  # web upload credit
    r"|המהדורה המודפסת כוללת)"            # pointer to the printed edition
)


def drop_editorial(book):
    secs = book["sections"]
    by_book = EDITORIAL_BY_BOOK.get(book["id"], set())
    out, skip_level = [], None
    for i, s in enumerate(secs):
        if skip_level is not None:
            if s["l"] > skip_level:
                continue
            skip_level = None
        t = s["t"].strip()
        first_ws_intro = book["source"] == "wikisource" and i == 0 and t == "פתיחה"
        if first_ws_intro:  # drop only the blurb itself; the book's chapters may sit beneath it
            continue
        if EDITORIAL_TITLES.match(t) or t in by_book:
            skip_level = s["l"]
            continue
        s["p"] = [x for x in s["p"] if not EDITORIAL_PARAS.match(x.strip())]
        out.append(s)
    book["sections"] = out


def tidy(book):
    """Remove editorial material, the book-name prefix in chapter titles, and separator-only paragraphs."""
    drop_editorial(book)
    name = book["title"]
    for sec in book["sections"]:
        t = sec["t"]
        if t.startswith(name + " ") and len(t) > len(name) + 1:
            t = sec["t"] = t[len(name) + 1:].strip()
        if t.startswith("Gate "):  # untranslated Sefaria section name
            sec["t"] = "שער " + t[5:]
        sec["p"] = [x for x in sec["p"] if not SEPARATOR.match(x)]
    # drop headings left without any content beneath them
    secs, keep = book["sections"], []
    for i, s in enumerate(secs):
        if not s["p"]:
            nxt = secs[i + 1] if i + 1 < len(secs) else None
            if not nxt or nxt["l"] <= s["l"]:
                continue
        keep.append(s)
    book["sections"] = keep


def load_books(sefaria_versions):
    """All downloaded books, one edition per work (the most complete one)."""
    best = {}
    for path in sorted(glob.glob(os.path.join(SRC, "*.json"))):
        with open(path, encoding="utf-8") as f:
            book = json.load(f)
        if book["stats"]["chars"] < 2500:
            print(f"skipping stub {book['id']} ({book['stats']['chars']} chars)")
            continue
        tidy(book)
        book["category"] = CATEGORY_MERGE.get(book["category"], book["category"])
        key = work_key(book["title"])
        if key in EXCLUDE:
            continue
        if not has_declared_license(book, sefaria_versions):
            print(f"  {key}: skipping {book['id']} (license not declared at source)")
            continue
        cur = best.get(key)
        if cur is None or book["stats"]["chars"] > cur["stats"]["chars"]:
            if cur is not None:
                print(f"  {key}: keeping {book['id']} over {cur['id']}")
            best[key] = book
        else:
            print(f"  {key}: keeping {cur['id']} over {book['id']}")
    return list(best.values())


def editions_for(book, sefaria_versions):
    if book["source"] == "wikisource":
        return [{
            "title": "ויקיטקסט העברי",
            "titleEn": "Hebrew Wikisource",
            "license": WIKISOURCE_LICENSE,
            "source": book["sourceUrl"],
        }]
    out = []
    for v in sefaria_versions.get(book["id"], []):
        out.append({
            "title": v["versionTitleHe"] or v["versionTitle"],
            "titleEn": v["versionTitle"] if v["versionTitleHe"] else "",
            "license": v["license"],
            "source": v["source"] if v["source"].startswith("http") else "",
        })
    return out


def main():
    for old in glob.glob(os.path.join(OUT, "*.json.gz")):
        os.remove(old)
    with open(os.path.join(ROOT, "data", "sefaria_versions.json"), encoding="utf-8") as f:
        sefaria_versions = json.load(f)
    catalog, licenses = [], []
    total = 0
    for book in load_books(sefaria_versions):
        data = json.dumps({"id": book["id"], "sections": book["sections"]}, ensure_ascii=False,
                          separators=(",", ":")).encode("utf-8")
        gz = gzip.compress(data, compresslevel=9, mtime=0)
        with open(os.path.join(OUT, book["id"] + ".json.gz"), "wb") as f:
            f.write(gz)
        total += len(gz)
        title = book["title"].replace('"', "״")
        catalog.append({
            "id": book["id"],
            "title": title,
            "category": book["category"],
            "stats": book["stats"],
        })
        licenses.append({"group": book["category"], "book": title, "editions": editions_for(book, sefaria_versions)})

    def order(c):
        return CATEGORY_ORDER.index(c) if c in CATEGORY_ORDER else 99

    catalog.sort(key=lambda b: (order(b["category"]), b["title"]))
    licenses.sort(key=lambda b: (order(b["group"]), b["book"]))
    with open(os.path.join(ROOT, "assets", "catalog.json"), "w", encoding="utf-8") as f:
        json.dump({"categories": CATEGORY_ORDER, "books": catalog}, f, ensure_ascii=False, indent=1)
    with open(os.path.join(ROOT, "assets", "text_licenses.json"), "w", encoding="utf-8") as f:
        json.dump(licenses, f, ensure_ascii=False, indent=1)
    chars = sum(b["stats"]["chars"] for b in catalog)
    print(f"{len(catalog)} books, {chars:,} chars, {total / 1e6:.1f} MB compressed")


if __name__ == "__main__":
    main()
