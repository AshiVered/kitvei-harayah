"""Build the project website (landing page) into build/site/.

The page mirrors the app's home page: title, download / open-online buttons, and the
library grouped by category (read from assets/catalog.json, so it always matches the app).

Usage: python tools/build_site.py --user <github-user> --repo <repository>
The web app itself is expected at build/site/app/ (deploy_github_pages.ps1 puts it there).
"""
import argparse
import html
import json
import os
import re
import shutil
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = {  # simple inline glyphs matching the app's category icons
    "אמונה": "☀", "קבצים ופנקסים": "✎", "מוסר ומידות": "❦", "תפילה ומועדים": "✡",
    "דרשות ומאמרים": "❝", "אגרות": "✉", "שירה": "♪", "הלכה": "⚖",
}


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--user", required=True)
    ap.add_argument("--repo", required=True)
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "site"))
    ap.add_argument("--direct-download", action="store_true", help="link the button straight to the release zip")
    ap.add_argument("--download-version", help="release to link to (default: version in pubspec.yaml)")
    a = ap.parse_args()

    version = re.search(r"^version:\s*([0-9.]+)", open(os.path.join(ROOT, "pubspec.yaml"), encoding="utf-8").read(), re.M).group(1)
    if a.download_version:  # e.g. the newest release whose files are already attached
        version = a.download_version
    repo_url = f"https://github.com/{a.user}/{a.repo}"
    asset = f"KitveiHaRaayah-{version}-windows-x64.zip"
    # The release page (always valid); pass --direct-download once the zip is attached to the release.
    if a.direct_download:
        download_url = f"{repo_url}/releases/download/v{version}/{asset}"
    else:
        download_url = f"{repo_url}/releases/tag/v{version}"

    cat = json.load(open(os.path.join(ROOT, "assets", "catalog.json"), encoding="utf-8"))
    # Balanced columns, like the app's home page: each card goes to the shortest column.
    cols, heights = [[], [], []], [0.0, 0.0, 0.0]
    for c in cat["categories"]:
        books = [b for b in cat["books"] if b["category"] == c]
        if not books:
            continue
        target = min(range(3), key=lambda i: (heights[i], i))
        heights[target] += 2.2 + len(books)
        items = "\n".join(f'        <li><a href="app/">{html.escape(b["title"])}</a></li>' for b in books)
        cols[target].append(
            f'      <section class="card cat">\n'
            f'        <header><i>{ICONS.get(c, "✦")}</i><b>{html.escape(c)}</b></header>\n'
            f'        <ul>\n{items}\n        </ul>\n'
            f'      </section>')
    parts = ['    <div class="col">\n' + "\n".join(col) + '\n    </div>' for col in cols if col]

    page = open(os.path.join(ROOT, "site", "index.template.html"), encoding="utf-8").read()
    for k, v in {
        "{{LIBRARY}}": "\n".join(parts),
        "{{VERSION}}": version,
        "{{REPO_URL}}": repo_url,
        "{{RELEASES_URL}}": f"{repo_url}/releases",
        "{{DOWNLOAD_URL}}": download_url,
    }.items():
        page = page.replace(k, v)
    assert "{{" not in page, "unfilled placeholder"

    out = a.out
    os.makedirs(os.path.join(out, "assets"), exist_ok=True)
    with open(os.path.join(out, "index.html"), "w", encoding="utf-8") as f:
        f.write(page)
    for name in os.listdir(os.path.join(ROOT, "site", "assets")):
        shutil.copy2(os.path.join(ROOT, "site", "assets", name), os.path.join(out, "assets", name))
    for font in ("FrankRuhlLibre.ttf", "Heebo.ttf"):
        shutil.copy2(os.path.join(ROOT, "assets", "fonts", font), os.path.join(out, "assets", font))
    icon = Image.open(os.path.join(ROOT, "assets", "icon", "icon.png"))
    icon.resize((512, 512), Image.LANCZOS).save(os.path.join(out, "assets", "icon.png"))
    icon.resize((64, 64), Image.LANCZOS).save(os.path.join(out, "assets", "icon-64.png"))
    open(os.path.join(out, ".nojekyll"), "w").close()
    print(f"site built: {out} (version {version}, download {download_url})")


if __name__ == "__main__":
    main()
