"""Fetch the license of every Hebrew Sefaria edition used by the library.

Writes data/sefaria_versions.json: {book_id: [{versionTitle, versionTitleHe, license, source}]}
Usage: python tools/fetch_licenses.py
"""
import json
import os
import sys
import urllib.parse

from common import ROOT, http_json
from download_sefaria import BOOKS

sys.stdout.reconfigure(encoding="utf-8")


def main():
    out = {}
    for title, _, _ in BOOKS:
        vs = http_json(f"https://www.sefaria.org/api/texts/versions/{urllib.parse.quote(title)}")
        he = [v for v in vs if v.get("language") == "he"]
        slug = "sefaria-" + "".join(c if c.isalnum() else "-" for c in title.lower()).strip("-")
        while "--" in slug:
            slug = slug.replace("--", "-")
        out[slug] = [{
            "versionTitle": v.get("versionTitle", ""),
            "versionTitleHe": v.get("versionTitleInHebrew") or v.get("versionTitleHe") or "",
            "license": v.get("license") or "",
            "source": v.get("versionSource") or "",
        } for v in he]
        print(title, [(v["versionTitle"], v["license"]) for v in out[slug]])
    with open(os.path.join(ROOT, "data", "sefaria_versions.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
