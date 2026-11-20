"""Download all Rav Kook books available on Hebrew Wikisource (he.wikisource.org).

Each book's main page is crawled: links that belong to the book (subpages
"Book/..." or pages named "Book ...") are followed recursively, then all pages
are rendered by MediaWiki (batched transclusion) and converted to plain text.

Usage: python tools/download_wikisource.py [slug ...]
Writes data/books/wikisource-<slug>.json
"""
import json
import re
import sys
import time

from bs4 import BeautifulSoup, NavigableString, Tag

from common import clean_text, http_json, save_book

sys.stdout.reconfigure(encoding="utf-8")

API = "https://he.wikisource.org/w/api.php"
SLEEP = 1.0

# (slug, Wikisource title, app category)
BOOKS = [
    ("shemonah-kevatzim", "שמונה קבצים", "קבצים ופנקסים"),
    ("arpilei-tohar", "ערפלי טוהר", "קבצים ופנקסים"),
    ("kevatzim-ktav-yad", "קבצים מכתב יד קדשו", "קבצים ופנקסים"),
    ("kevatzim-ktav-yad-2", "קבצים מכתב יד קדשו כרך ב", "קבצים ופנקסים"),
    ("pinkas-13", "פנקס יג", "קבצים ופנקסים"),
    ("pinkasei-1", 'פנקסי הראי"ה חלק ראשון', "קבצים ופנקסים"),
    ("pinkasei-2", 'פנקסי הראי"ה חלק שני', "קבצים ופנקסים"),
    ("pinkasei-3", 'פנקסי הראי"ה חלק שלישי', "קבצים ופנקסים"),
    ("pinkasei-4", 'פנקסי הראי"ה חלק רביעי', "קבצים ופנקסים"),
    ("pinkasei-5", 'פנקסי הראי"ה חלק חמישי', "קבצים ופנקסים"),
    ("pinkasei-6", 'פנקסי הראי"ה חלק שישי', "קבצים ופנקסים"),
    ("pinkasei-7", 'פנקסי הראי"ה חלק שביעי', "קבצים ופנקסים"),
    ("metziot-katan", "מציאות קטן", "קבצים ופנקסים"),
    ("orot", "אורות", "ספרי אורות"),
    ("orot-hakodesh", "אורות הקודש", "ספרי אורות"),
    ("orot-hateshuvah", "אורות התשובה", "ספרי אורות"),
    ("orot-hatorah", "אורות התורה", "ספרי אורות"),
    ("orot-haemunah", "אורות האמונה", "ספרי אורות"),
    ("orot-hareiyah", "אורות הראיה", "ספרי אורות"),
    ("eder-hayakar", "אדר היקר", "אגדה ומחשבה"),
    ("ikvei-hatzon", "עקבי הצאן", "אגדה ומחשבה"),
    ("rosh-milin", "ראש מילין", "אגדה ומחשבה"),
    ("chazon-hatzimchonut", "חזון הצמחונות והשלום", "אגדה ומחשבה"),
    ("ein-ayah", "עין איה", "אגדה ומחשבה"),
    ("chavash-peer", "חבש פאר", "אגדה ומחשבה"),
    ("chazon-hageulah", "חזון הגאולה", "אגדה ומחשבה"),
    ("biurei-avot", 'באורי הראי"ה למסכת אבות', "אגדה ומחשבה"),
    ("mishnat-harav", "משנת הרב", "אגדה ומחשבה"),
    ("eretz-chefetz", "ארץ חפץ", "אגדה ומחשבה"),
    ("musar-avicha", "מוסר אביך", "מוסר ומידות"),
    ("midot-hareiyah", 'מידות הראי"ה', "מוסר ומידות"),
    ("igrot", 'אגרות הראי"ה', "אגרות"),
    ("igrot-hashlamot", 'השלמות לאגרות הראי"ה', "אגרות"),
    ("igrot-5", "אגרות הראיה ה", "אגרות"),
    ("maamarei", 'מאמרי הראי"ה', "דרשות ומאמרים"),
    ("midbar-shur", "מדבר שור", "דרשות ומאמרים"),
    ("olat-reiyah", 'עולת ראי"ה', "תפילה ומועדים"),
    ("meorot-hareiyah", 'מאורות הראי"ה', "תפילה ומועדים"),
    ("daat-kohen", "דעת כהן", "הלכה"),
    ("mishpat-kohen", "משפט כהן", "הלכה"),
    ("ezrat-kohen", "עזרת כהן", "הלכה"),
    ("orach-mishpat", "אורח משפט", "הלכה"),
    ("shabbat-haaretz", "שבת הארץ", "הלכה"),
    ("beer-eliyahu", "באר אליהו", "הלכה"),
    ("zivchei-reiyah", 'זבחי ראי"ה', "הלכה"),
    ("mitzvot-reiyah", 'מצות ראי"ה', "הלכה"),
    ("etz-hadar", "עץ הדר", "הלכה"),
    ("tov-roi", "טוב רואי", "הלכה"),
]

MAX_PAGES_PER_BOOK = 4000
MAX_DEPTH = 5


def api(params, post=False):
    params = dict(params, format="json", formatversion="2", maxlag="5")
    time.sleep(SLEEP)
    if post:
        return http_json(API, data=params)
    return http_json(API, params=params)


def fetch_wikitext(titles):
    """Return {requested_title: (resolved_title, wikitext or None)} for up to 50 titles."""
    out = {}
    for i in range(0, len(titles), 50):
        chunk = titles[i:i + 50]
        d = api({"action": "query", "titles": "|".join(chunk), "prop": "revisions",
                 "rvprop": "content", "rvslots": "main", "redirects": 1}, post=True)
        q = d.get("query", {})
        alias = {}
        for key in ("normalized", "redirects"):
            for r in q.get(key, []):
                alias[r["from"]] = r["to"]
        pages = {p["title"]: p for p in q.get("pages", [])}
        for t in chunk:
            real = t
            seen = 0
            while real in alias and seen < 5:
                real = alias[real]
                seen += 1
            p = pages.get(real)
            if not p or p.get("missing") or p.get("invalid"):
                out[t] = (real, None)
            else:
                out[t] = (real, p["revisions"][0]["slots"]["main"]["content"])
    return out


LINK = re.compile(r"\[\[([^\[\]|#]+)(?:#[^\[\]|]*)?(?:\|.*?)?\]\]", re.S)


def links_in_order(page_title, wikitext):
    res = []
    for m in LINK.finditer(wikitext):
        t = m.group(1).strip().replace("_", " ")
        if not t:
            continue
        if t.startswith("/"):
            t = page_title + t.rstrip("/")
        elif t.startswith("../"):
            continue
        if ":" in t.split("/")[0] and not t.startswith(":"):
            continue  # namespaced (קטגוריה:, קובץ:, W:, ...)
        t = t.lstrip(":")
        if t:
            t = t[0].upper() + t[1:]
        res.append(t)
    return res


def owner(title, roots):
    best = None
    for r in roots:
        if title == r or title.startswith(r + "/") or title.startswith(r + " "):
            if best is None or len(r) > len(best):
                best = r
    return best


def crawl(root, roots):
    """BFS over the book; returns ordered list of (title, depth, parent, wikitext)."""
    info = {}
    children = {}
    frontier = [root]
    visited = {root}
    depth = {root: 0}
    parent = {root: None}
    while frontier and len(info) < MAX_PAGES_PER_BOOK:
        got = fetch_wikitext(frontier)
        nxt = []
        for t in frontier:
            real, text = got[t]
            if text is None:
                continue
            if real != t and real in info:
                continue
            info[t] = (real, text)
            children[t] = []
            if depth[t] >= MAX_DEPTH:
                continue
            for link in links_in_order(real, text):
                if link in visited:
                    continue
                if owner(link, roots) != root:
                    continue
                visited.add(link)
                depth[link] = depth[t] + 1
                parent[link] = t
                children[t].append(link)
                nxt.append(link)
        print(f"  crawled {len(info)} pages, next level {len(nxt)}")
        frontier = nxt
    ordered = []

    def dfs(t):
        if t not in info:
            return
        ordered.append((t, depth[t], parent[t], info[t][1]))
        for c in children.get(t, []):
            dfs(c)

    dfs(root)
    return ordered


DROP_SELECTORS = [
    "table", "style", "script", "sup.reference", "ol.references", ".mw-references-wrap",
    ".mw-editsection", ".noprint", ".navbox", ".toc", "#toc", ".mw-empty-elt", "figure",
    ".thumb", ".ws-noexport", ".metadata", ".mw-cite-backlink", ".reference", "img",
    ".error", ".mw-kartographer-container",
]
BLOCK_TEXT = {"p", "li", "dd", "dt", "pre", "h1", "h2", "h3", "h4", "h5", "h6"}
CONTAINERS = {"div", "blockquote", "ul", "ol", "dl", "center", "section", "span", "font", "big", "small", "poem"}
HEADINGS = {"h1": 1, "h2": 1, "h3": 2, "h4": 3, "h5": 3, "h6": 3}
NAV_WORDS = ("הפרק הבא", "הפרק הקודם", "לדף הבא", "לדף הקודם", "חזרה לתוכן", "תוכן העניינים")


def node_text(el):
    for br in el.find_all("br"):
        br.replace_with("\n")
    return clean_text(el.get_text(""))


_SEP = re.compile(r"[\s\-–—|•·,:;.<>«»()\[\]]+")


_TOC_WORDS = re.compile(r"(פרק|סימן|קובץ|אות|חלק|מאמר|אגרת|פסקה|דף|עמוד|סעיף)?\s*[א-ת]{1,4}[\"'״׳]?[א-ת]?(?=[\s\-–—|•·,\[\]()]|$)")


def is_toc_line(text):
    if len(text) > 800 or text.count(" ") < 2:
        return False
    rest = _SEP.sub("", _TOC_WORDS.sub("", text))
    return not rest and len(re.findall(r"פרק|סימן|קובץ|אגרת|•|\|| - ", text)) >= 3


def is_link_list(el, text):
    if not text:
        return True
    if is_toc_line(text):
        return True
    core = _SEP.sub("", text)
    if not core:
        return True
    link_len = sum(len(_SEP.sub("", a.get_text(""))) for a in el.find_all("a"))
    if link_len >= 0.75 * len(core) and len(text) < 600:
        return True
    if len(text) < 200 and ("<<" in text or ">>" in text or text.count("·") >= 1 and "|" in text):
        return True
    if len(text) < 60 and any(w in text for w in NAV_WORDS):
        return True
    return False


DROP_HEADINGS = {"קישורים חיצוניים", "ראו גם", "הערות שוליים", "הערות", "מקורות", "קישורים"}


def postprocess_page(blocks):
    """Keep only the vocalized copy when a page has both, drop meta sections."""
    heads = [b[2] for b in blocks if b[0] == "h"]
    has_both = any("לא מנוקד" in h for h in heads) and any(("מנוקד" in h and "לא" not in h) for h in heads)
    out, skip_level = [], None
    for b in blocks:
        if b[0] == "h":
            if skip_level is not None and b[1] <= skip_level:
                skip_level = None
            h = b[2].strip()
            if h in DROP_HEADINGS or (has_both and "לא מנוקד" in h):
                skip_level = b[1]
                continue
            if has_both and "מנוקד" in h:
                continue
        if skip_level is not None:
            continue
        out.append(b)
    return out


def html_to_blocks(html):
    """Return list of ('h', level, text) or ('p', text)."""
    soup = BeautifulSoup(html, "html.parser")
    for sel in DROP_SELECTORS:
        for el in soup.select(sel):
            el.decompose()
    blocks = []
    inline_buf = []

    link_chars = [0]

    def flush():
        if inline_buf:
            t = clean_text("".join(inline_buf))
            core = _SEP.sub("", t)
            is_nav = (not core or is_toc_line(t) or link_chars[0] >= 0.75 * len(core) and len(t) < 600
                      or len(t) < 200 and ("<<" in t or ">>" in t))
            if t and not is_nav:
                blocks.append(("p", t))
            inline_buf.clear()
        link_chars[0] = 0

    def walk(el):
        for ch in list(el.children):
            if isinstance(ch, NavigableString):
                if ch.__class__.__name__ in ("Comment", "Doctype"):
                    continue
                inline_buf.append(str(ch))
                continue
            if not isinstance(ch, Tag):
                continue
            name = ch.name
            if name in HEADINGS:
                flush()
                t = node_text(ch)
                if t:
                    blocks.append(("h", HEADINGS[name], t))
            elif name in BLOCK_TEXT:
                flush()
                # nested lists inside li -> handle children separately
                nested = ch.find(["ul", "ol", "dl"])
                if nested is not None and name in ("li", "dd", "dt"):
                    nested.extract()
                    t = node_text(ch)
                    if t and not is_link_list(ch, t):
                        blocks.append(("p", t))
                    walk(nested)
                    continue
                t = node_text(ch)
                if t and not is_link_list(ch, t):
                    blocks.append(("p", t))
            elif name in CONTAINERS or name == "div":
                if name in ("span", "font", "big", "small") and not ch.find(["p", "div", "br", "ul", "ol", "dl"]):
                    inline_buf.append(ch.get_text(""))
                    continue
                flush()
                walk(ch)
            elif name == "br":
                inline_buf.append("\n")
            elif name == "hr":
                flush()
            else:
                txt = ch.get_text("")
                if name == "a":
                    link_chars[0] += len(_SEP.sub("", txt))
                else:
                    link_chars[0] += sum(len(_SEP.sub("", a.get_text(""))) for a in ch.find_all("a"))
                inline_buf.append(txt)
        flush()

    root = soup.select_one(".mw-parser-output") or soup
    walk(root)
    return blocks


def render_pages(pages, context_title):
    """Render a list of (title, wikitext) using batched transclusion. Returns {title: html}."""
    out = {}
    batch, size = [], 0
    batches = []
    for t, text in pages:
        n = len(text)
        if batch and (size + n > 250_000 or len(batch) >= 40):
            batches.append(batch)
            batch, size = [], 0
        batch.append(t)
        size += n
    if batch:
        batches.append(batch)
    for bi, b in enumerate(batches):
        src = "".join(f'\n\n<div id="KSPLIT-{i}"></div>\n\n{{{{:{t}}}}}\n' for i, t in enumerate(b))
        try:
            d = api({"action": "parse", "text": src, "title": context_title, "contentmodel": "wikitext",
                     "prop": "text", "disablelimitreport": 1, "disableeditsection": 1, "wrapoutputclass": ""},
                    post=True)
            html = d["parse"]["text"]
        except Exception as e:
            print(f"  batch render failed ({e}); rendering one by one")
            html = ""
            for i, t in enumerate(b):
                try:
                    d = api({"action": "parse", "page": t, "prop": "text", "disablelimitreport": 1,
                             "disableeditsection": 1}, post=True)
                    html += f'<div id="KSPLIT-{i}"></div>' + d["parse"]["text"]
                except Exception as e2:
                    print(f"  failed {t}: {e2}")
        parts = re.split(r'<div id="KSPLIT-(\d+)"></div>', html)
        for j in range(1, len(parts) - 1, 2):
            out[b[int(parts[j])]] = parts[j + 1]
        print(f"  rendered batch {bi + 1}/{len(batches)}")
    return out


def short_title(title, parent):
    if parent and title.startswith(parent):
        rest = title[len(parent):].lstrip("/ ").strip()
        if rest:
            return rest
    return title.split("/")[-1]


def build_book(slug, root_req, category, roots_map, all_roots):
    got = fetch_wikitext([root_req])
    real, text = got[root_req]
    if text is None:
        print(f"!! missing on Wikisource: {root_req}")
        return None
    print(f"== {root_req} -> {real}")
    pages = crawl(real, all_roots | {real})
    print(f"  {len(pages)} pages in book")
    html = render_pages([(t, w) for t, _, _, w in pages], real)
    sections = []
    for t, depth, parent, _ in pages:
        blocks = postprocess_page(html_to_blocks(html.get(t, "")))
        level = max(depth - 1, 0) if depth else 0
        title = short_title(t, parent) if depth else "פתיחה"
        cur = {"t": title, "l": level, "p": []}
        sections.append(cur)
        for b in blocks:
            if b[0] == "h":
                cur = {"t": b[2], "l": level + (1 if depth else 0) + b[1] - 1, "p": []}
                sections.append(cur)
            else:
                cur["p"].append(b[1])
    # drop empty sections that have no deeper content following
    cleaned = []
    for i, s in enumerate(sections):
        if not s["p"]:
            nxt = sections[i + 1] if i + 1 < len(sections) else None
            if not nxt or nxt["l"] <= s["l"]:
                continue
        cleaned.append(s)
    # The root page of a book is often only an index; drop it if empty of text.
    if cleaned and cleaned[0]["t"] == "פתיחה" and not cleaned[0]["p"]:
        cleaned = cleaned[1:]
    book = {
        "id": f"wikisource-{slug}",
        "title": root_req,
        "source": "wikisource",
        "sourceUrl": "https://he.wikisource.org/wiki/" + real.replace(" ", "_"),
        "license": "ויקיטקסט – CC BY-SA 4.0; טקסט המקור בנחלת הכלל",
        "category": category,
        "note": None,
        "pages": len(pages),
        "sections": cleaned,
    }
    if sum(len(p) for s in cleaned for p in s["p"]) < 1500:
        print(f"  (no text content found for {root_req})")
        return None
    save_book(book)
    return book


def main():
    only = set(sys.argv[1:])
    resolved = fetch_wikitext([t for _, t, _ in BOOKS])
    all_roots = {resolved[t][0] for _, t, _ in BOOKS if resolved[t][1] is not None}
    summary = []
    for slug, title, cat in BOOKS:
        if only and slug not in only:
            continue
        try:
            b = build_book(slug, title, cat, resolved, all_roots)
            summary.append((title, b["stats"] if b else None))
        except Exception as e:
            print(f"!! failed {title}: {e}")
            summary.append((title, f"error {e}"))
    print("\nSUMMARY")
    for t, s in summary:
        print(t, s)


if __name__ == "__main__":
    main()
