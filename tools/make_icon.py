"""Render the app icon and write it where the builds pick it up.

The chosen design is "Rav Kook's figure rising above the horizon at dawn" (proposal B
without the sun), defined in tools/icon_proposals.py. The portrait comes from the 1924
public-domain photo (Library of Congress, npcc.25595); run tools/make_portrait.py first.

Usage: python tools/make_icon.py
Writes assets/icon/icon.png, windows/runner/resources/app_icon.ico and web icons.
"""
import base64
import io
import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from icon_proposals import p_figure_rising  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    icon = p_figure_rising().resize((1024, 1024), Image.LANCZOS)
    os.makedirs(os.path.join(ROOT, "assets", "icon"), exist_ok=True)
    icon.save(os.path.join(ROOT, "assets", "icon", "icon.png"))
    icon.save(os.path.join(ROOT, "windows", "runner", "resources", "app_icon.ico"),
              sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    web = os.path.join(ROOT, "web")
    if os.path.isdir(web):
        icon.resize((32, 32), Image.LANCZOS).save(os.path.join(web, "favicon.png"))
        os.makedirs(os.path.join(web, "icons"), exist_ok=True)
        for size in (192, 512):
            im = icon.resize((size, size), Image.LANCZOS)
            im.save(os.path.join(web, "icons", f"Icon-{size}.png"))
            im.save(os.path.join(web, "icons", f"Icon-maskable-{size}.png"))
        # The loading screen embeds the icon (data URI), so it appears instantly with the page.
        buf = io.BytesIO()
        icon.resize((176, 176), Image.LANCZOS).save(buf, format="PNG", optimize=True)
        uri = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")
        index = os.path.join(web, "index.html")
        page = open(index, encoding="utf-8").read()
        page = re.sub(r'(<img id="loading-icon" src=")[^"]*(")', lambda m: m.group(1) + uri + m.group(2), page)
        open(index, "w", encoding="utf-8").write(page)
    print("icon written")


if __name__ == "__main__":
    main()
