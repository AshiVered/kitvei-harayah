"""Download all Rav Kook books from Sefaria (Hebrew 'merged' version).

Usage: python tools/download_sefaria.py
Writes normalized book JSON files to data/books/sefaria-*.json
"""
import html
import re
import sys
import urllib.parse

from common import clean_text, heb_num, http_json, save_book

sys.stdout.reconfigure(encoding="utf-8")

# (Sefaria title, category in the app, note)
BOOKS = [
    ("Orot", "ספרי אורות", None),
    ("Orot HaKodesh", "ספרי אורות", None),
    ("Orot HaTeshuvah", "ספרי אורות", None),
    ("Orot HaTorah", "ספרי אורות", None),
    ("Shemonah Kevatzim", "קבצים ופנקסים", None),
    ("Olat Reiyah", "תפילה ומועדים", None),
    ("Ein Ayah", "אגדה ומחשבה", None),
    ("Middot HaRa'ayah", "מוסר ומידות", None),
    ("Musar Avikha", "מוסר ומידות", None),
    ("Midbar Shur", "דרשות ומאמרים", None),
    ("Ma'amar Hador", "דרשות ומאמרים", None),
    ("Shabbat HaAretz", "הלכה", None),
]

SECTION_NAMES = {
    "Chapter": "פרק", "Paragraph": "פסקה", "Section": "סימן", "Siman": "סימן",
    "Seif": "סעיף", "Letter": "אות", "Daf": "דף", "Halakhah": "הלכה", "Mishnah": "משנה",
    "Part": "חלק", "Volume": "כרך", "Essay": "מאמר", "Teaching": "מאמר", "Page": "עמוד",
    "Note": "הערה", "Footnote": "הערה", "Line": "שורה", "Book": "ספר", "Kovetz": "קובץ",
    "Piska": "פסקה", "Gate": "שער", "Passage": "קטע", "Comment": "הערה", "Prayer": "תפילה",
}

API = "https://www.sefaria.org"
_term_cache = {}


def term_he(name):
    if name not in _term_cache:
        try:
            t = http_json(f"{API}/api/terms/{urllib.parse.quote(name)}")
            he = [x["text"] for x in t.get("titles", []) if x["lang"] == "he" and x.get("primary")]
            _term_cache[name] = he[0] if he else name
        except Exception:
            _term_cache[name] = name
    return _term_cache[name]


def node_title(node):
    for t in node.get("titles", []):
        if t["lang"] == "he" and t.get("primary"):
            return t["text"]
    if node.get("sharedTitle"):
        return term_he(node["sharedTitle"])
    return None


FOOTNOTE = re.compile(r'<sup[^>]*class="footnote-marker"[^>]*>.*?</sup>\s*<i[^>]*class="footnote"[^>]*>.*?</i>', re.S)
TAG = re.compile(r"<[^>]+>")


def clean_html(s):
    if not isinstance(s, str):
        return ""
    s = FOOTNOTE.sub("", s)
    s = re.sub(r"<br\s*/?>", "\n", s)
    s = TAG.sub("", s)
    return clean_text(html.unescape(s))


def emit(text, names, level, sections):
    """Emit sections from a jagged array. The deepest level is paragraphs."""
    if isinstance(text, str):
        text = [text]
    if len(names) <= 1:
        paras = [p for p in (clean_html(x) for x in (text or [])) if p]
        if paras:
            if not sections:
                sections.append({"t": "", "l": level, "p": []})
            sections[-1]["p"].extend(paras)
        return
    name = SECTION_NAMES.get(names[0], names[0])
    for i, sub in enumerate(text or []):
        if not sub:
            continue
        sections.append({"t": f"{name} {heb_num(i + 1)}", "l": level, "p": []})
        emit(sub, names[1:], level + 1, sections)


def walk_schema(node, text, level, sections):
    title = node_title(node) if level >= 0 else None
    if "nodes" in node:
        if title:
            sections.append({"t": title, "l": level, "p": []})
        child_level = level + 1 if title else max(level, 0)
        for child in node["nodes"]:
            sub = None
            if isinstance(text, dict):
                if child.get("default"):
                    sub = text.get("", text.get("default"))
                else:
                    en = [t["text"] for t in child.get("titles", []) if t["lang"] == "en" and t.get("primary")]
                    for k in en + [child.get("key"), child.get("title"), child.get("sharedTitle")]:
                        if k and k in text:
                            sub = text[k]
                            break
            walk_schema(child, sub, child_level, sections)
        return
    if text is None:
        return
    names = node.get("sectionNames") or ["Paragraph"] * node.get("depth", 1)
    if title and not node.get("default"):
        sections.append({"t": title, "l": level, "p": []})
        emit(text, names, level + 1, sections)
    else:
        emit(text, names, max(level, 0), sections)


def download(title, category, note):
    print(f"== {title}")
    index = http_json(f"{API}/api/v2/raw/index/{urllib.parse.quote(title)}")
    he_title = index.get("heTitle") or node_title(index.get("schema", {})) or title
    ver = http_json(f"{API}/download/version/{urllib.parse.quote(title + ' - he - merged.json')}")
    sections = []
    walk_schema(index["schema"], ver["text"], -1, sections)
    # drop empty headings that have no content beneath (keep structural ones)
    cleaned = []
    for i, s in enumerate(sections):
        if not s["p"]:
            nxt = sections[i + 1] if i + 1 < len(sections) else None
            if not nxt or nxt["l"] <= s["l"]:
                continue
        cleaned.append(s)
    slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    book = {
        "id": f"sefaria-{slug}",
        "title": he_title,
        "enTitle": title,
        "source": "sefaria",
        "sourceUrl": f"https://www.sefaria.org/{urllib.parse.quote(title.replace(' ', '_'))}?lang=he",
        "license": "לפי רישיונות המהדורות בספריא (CC-BY / CC-BY-NC / נחלת הכלל)",
        "versionSources": ver.get("versionSource"),
        "category": category,
        "note": note,
        "sections": cleaned,
    }
    save_book(book)


if __name__ == "__main__":
    only = sys.argv[1:]
    for t, c, n in BOOKS:
        if only and t not in only:
            continue
        try:
            download(t, c, n)
        except Exception as e:
            print(f"!! failed {t}: {e}")
