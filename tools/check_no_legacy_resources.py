#!/usr/bin/env python3
"""Fail if old or self-made pictures can come back.

User decisions: 2026-11-10 (old pack removed) and 2026-11-17 ("자체 이미지화는
하나도 하지 마. 연결 안 됐으면 차라리 그냥 비워놔"). The game shows only the
original 523 resources from the separately installed resource pack; an
unconnected slot stays empty.

1. Committed files: under assets/ only the font, the Android launcher icons
   (assets/boot/twilight_icon*, kept by user decision 2026-11-17) and shader
   code are allowed. No picture is committed anywhere else (no screenshots in
   docs/ or tests/). external_map_packs/ and samples/ must be empty.
2. Code (scripts/, addons/, scenes/, Main.tscn) names no retired res://assets/
   file, and never calls ResourceLoader.exists() directly: an OTA update pack
   cannot delete files an older APK still carries, so an exists() check would
   bring the removed art back. Code asks scripts/resources/retired_assets.gd.
"""
import re
import subprocess
import sys

ALLOWED_PREFIXES = ("assets/fonts/", "assets/boot/twilight_icon")
ALLOWED_SUFFIXES = (".gdshader", ".gdshader.uid")
FORBIDDEN_ROOTS = ("external_map_packs/", "samples/")
PICTURE_SUFFIXES = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".bmp", ".tga", ".ktx", ".ctex", ".l1jpng")
CODE_ROOTS = ("scripts/", "addons/", "scenes/", "Main.tscn")
CODE_SUFFIXES = (".gd", ".tscn", ".tres")
GATE = "scripts/resources/retired_assets.gd"
ASSET_FILE = re.compile(r'res://(assets/[^"\'\s%]+\.[A-Za-z0-9]+)["\']')
EXISTS = re.compile(r"ResourceLoader\.exists\(")


def tracked(root, *paths):
    out = subprocess.run(["git", "-C", root, "ls-files", "-z", "--", *paths],
                         stdout=subprocess.PIPE, check=True).stdout
    return [p for p in out.decode("utf-8").split("\0") if p]


def kept_asset(path):
    return path.startswith(ALLOWED_PREFIXES) or path.endswith(ALLOWED_SUFFIXES)


def violations(paths):
    bad = []
    for path in paths:
        if path.startswith(FORBIDDEN_ROOTS):
            bad.append(path)
        elif path.startswith("assets/"):
            if not kept_asset(path):
                bad.append(path)
        elif path.lower().endswith(PICTURE_SUFFIXES):
            bad.append(path)
    return bad


def code_violations(name, text):
    if name == GATE:
        return []
    bad = []
    for number, line in enumerate(text.splitlines(), 1):
        for match in ASSET_FILE.finditer(line):
            if not kept_asset(match.group(1)):
                bad.append("%s:%d retired file %s" % (name, number, match.group(1)))
        if EXISTS.search(line):
            bad.append("%s:%d ResourceLoader.exists() (use retired_assets.gd usable())" % (name, number))
    return bad


def main():
    root = sys.argv[sys.argv.index("--root") + 1] if "--root" in sys.argv else "."
    paths = tracked(root)
    bad = violations(paths)
    code = [p for p in paths if p.startswith(CODE_ROOTS) and p.endswith(CODE_SUFFIXES)]
    for path in code:
        with open("%s/%s" % (root, path), encoding="utf-8", errors="replace") as handle:
            bad.extend(code_violations(path, handle.read()))
    if bad:
        print("OLD OR SELF-MADE PICTURES (%d):" % len(bad))
        for line in bad[:80]:
            print("  " + line)
        return 1
    print("NO_LEGACY_RESOURCES ok tracked=%d code=%d" % (len(paths), len(code)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
