#!/usr/bin/env python3
"""Install authorized Lineage-style skill icons locally, without redistributing them."""
import argparse
import hashlib
import io
import json
import re
import sys
import zipfile
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/skills/private_icons"
SUFFIXES = {".png", ".webp", ".jpg", ".jpeg"}

def ident(job, name):
    norm = re.sub(r"[\s:：()（）·]", "", name).replace("Lv", "").lower()
    return "lm_" + hashlib.sha256((job + ":" + norm).encode()).hexdigest()[:16]

def source_files(source):
    if source.is_dir():
        paths = {p.relative_to(source).as_posix(): p for p in source.rglob("*")
                 if p.is_file() and not p.is_symlink() and p.suffix.lower() in SUFFIXES}
        return sorted(paths), lambda key: paths[key].read_bytes()
    if source.is_file() and source.suffix.lower() == ".zip":
        archive = zipfile.ZipFile(source)
        paths = {}
        for info in archive.infolist():
            item = Path(info.filename)
            if (info.is_dir() or item.suffix.lower() not in SUFFIXES or
                    item.is_absolute() or ".." in item.parts or
                    info.file_size > 8_000_000):
                continue
            if info.filename in paths:
                raise ValueError("duplicate source path: " + info.filename)
            paths[info.filename] = info
        return sorted(paths), lambda key: archive.read(paths[key])
    raise ValueError("Provide a PNG/JPG/WebP folder or ZIP")

def encode_icon(data):
    from PIL import Image, ImageEnhance, ImageDraw
    if len(data) > 8_000_000: raise ValueError("source too large")
    with Image.open(io.BytesIO(data)) as opened:
        if min(opened.size) < 8 or max(opened.size) > 4096:
            raise ValueError("unexpected icon size")
        opened.load()
        icon = opened.convert("RGBA")
    icon.thumbnail((62, 62), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (64, 64))
    canvas.alpha_composite(icon, ((64-icon.width)//2, (64-icon.height)//2))
    rgb = ImageEnhance.Color(canvas.convert("RGB")).enhance(.985)
    output = Image.merge("RGBA", (*rgb.split(), canvas.getchannel("A")))
    ImageDraw.Draw(output).rounded_rectangle(
        (0, 0, 63, 63), radius=6, outline=(191, 161, 112, 24), width=1)
    buffer = io.BytesIO()
    output.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--source", type=Path, required=True)
    ap.add_argument("--mapping", type=Path, help='JSON {"lm_<skill_id>":"source/path.png"}')
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--rights-confirmed", action="store_true",
                    help="Confirm authorization to use and adapt the icon assets")
    args = ap.parse_args()
    if not args.dry_run and not args.rights_confirmed:
        ap.error("Installation requires --rights-confirmed")
    rows = json.loads((ROOT/"data/skills/curation.json").read_text(encoding="utf-8"))
    if len(rows) != 125: raise ValueError("Skill registry drift")
    mapping = json.loads(args.mapping.read_text(encoding="utf-8")) if args.mapping else {}
    if not isinstance(mapping, dict): raise ValueError("Mapping must be a JSON object")
    filenames, fetch = source_files(args.source)
    by_stem = defaultdict(list)
    for p in filenames: by_stem[Path(p).stem.casefold()].append(p)
    all_paths = {p.casefold(): p for p in filenames}
    selected, issues = {}, []
    for row in rows:
        job, name = str(row["job"]), str(row["name"])
        sid = ident(job, name)
        explicit = mapping.get(sid, mapping.get(job+":"+name))
        if explicit is not None:
            candidates = [all_paths[str(explicit).replace("\\", "/").casefold()]] if str(explicit).replace("\\", "/").casefold() in all_paths else []
        else:
            candidates = sorted(set(sum((by_stem[x.casefold()] for x in
                (sid, job+"_"+name, job+"-"+name, name)), [])))
        if len(candidates) == 1: selected[sid] = candidates[0]
        elif len(candidates) > 1 or explicit is not None:
            issues.append({"skill_id": sid, "candidate_count": len(candidates)})
    if issues and not args.dry_run: raise ValueError("Fix mapping ambiguity before install")
    written = 0
    if not args.dry_run:
        DEST.mkdir(parents=True, exist_ok=True)
        index = {}
        for sid, src in sorted(selected.items()):
            encoded = encode_icon(fetch(src))
            (DEST/(sid+".png")).write_bytes(encoded)
            index[sid] = {"source":src, "sha256":hashlib.sha256(encoded).hexdigest()}
            written += 1
        (DEST/"index.local.json").write_text(
            json.dumps(index, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"total":len(rows), "source_images":len(filenames),
                      "matched":len(selected), "unmatched":len(rows)-len(selected),
                      "issues":issues, "installed":written, "private":True},ensure_ascii=False))
    return 0

if __name__ == "__main__":
    sys.exit(main())
