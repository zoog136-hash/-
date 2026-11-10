#!/usr/bin/env python3
"""Fail if pre-November (old pack) resources are committed again.

User decision (2026-11-10): the game shows only the original 523 resources
from the separately installed resource pack. Older art (L1J, CC-BY actors,
generated card/skill art, Inven icons, old map packs) is removed from the
repository and is never a substitute: an unconnected slot stays empty.

Allowed under assets/: fonts, the app icon and loading screen (assets/boot),
and shader code (*.gdshader). external_map_packs/ and samples/ must be empty.
"""
import subprocess
import sys

ALLOWED_PREFIXES = ("assets/fonts/", "assets/boot/")
ALLOWED_SUFFIXES = (".gdshader", ".gdshader.uid")
FORBIDDEN_ROOTS = ("external_map_packs/", "samples/")


def tracked(root):
    out = subprocess.run(["git", "-C", root, "ls-files", "-z", "--", "assets", "external_map_packs", "samples"],
                         stdout=subprocess.PIPE, check=True).stdout
    return [p for p in out.decode("utf-8").split("\0") if p]


def violations(paths):
    bad = []
    for path in paths:
        if path.startswith(FORBIDDEN_ROOTS):
            bad.append(path)
        elif path.startswith("assets/") and not path.startswith(ALLOWED_PREFIXES) and not path.endswith(ALLOWED_SUFFIXES):
            bad.append(path)
    return bad


def main():
    root = sys.argv[sys.argv.index("--root") + 1] if "--root" in sys.argv else "."
    paths = tracked(root)
    bad = violations(paths)
    if bad:
        print("OLD RESOURCES COMMITTED (%d):" % len(bad))
        for path in bad[:50]:
            print("  " + path)
        return 1
    print("NO_LEGACY_RESOURCES ok tracked=%d" % len(paths))
    return 0


if __name__ == "__main__":
    sys.exit(main())
