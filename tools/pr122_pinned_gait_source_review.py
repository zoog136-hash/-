#!/usr/bin/env python3
"""PR122: pinned actual wolf/dog WIP source review boards, never native art.

No pose is approved, synthesized, recolored, flipped, or added to the project.
The boards are *QA thumbnails* extracted from byte-verified historical ZIPs.
"""
import argparse
import hashlib
import io
import json
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path("docs/remake/evidence/pr100-direction-fix/original-based/final-handoff-20261015/source-archives")
PACKS = {
    "wolf": {
        "archive": ROOT / "unicorn/final07-and-wolf-delta/unicorn-wolf-source-FINAL-PAUSED-delta07-part01.zip",
        "sha256": "c30fc4e3e5116e197cab5afbd139ec0a6adde88772df47b9e122f28c777d7e6b",
        "members": [
            ("N pilot", "blackforest-wolf-authoring/recovery-by-unicorn/walk-N-compact-rear-threephase-pilot2.png", "1b625962b23518f72c6940c54f686d80b9d8c43d8cb89861dfdf92778e2aeea6"),
            ("NW rejected", "blackforest-wolf-authoring/recovery-by-unicorn/walk-NW-threephase-pilot1.png", "13f907145d4bb12b2ad7885f18d505215d35527ffd725f9053cefcaed5d2e259"),
            ("NE rejected", "blackforest-wolf-authoring/recovery-by-unicorn/walk-NE-threephase-pilot1.png", "5315d0bbe0599760d91ca12e7db89be3c8535372b5c1555a735968"),
        ],
    },
    "wild_dog": {
        "archive": ROOT / "iguana-and-wilddog/iguana-wilddog-source-only-WIP06-part06-STOPPED-delta.zip",
        "sha256": "4182a566ce058217893c0173da0d2f92f6257aaead7d42746b62a5b15c5a19eb",
        "members": [
            ("E walk A", "talking-island-wild-dog-authoring/E-walk0-individual-attempt2-groundplane.png", "4ce07fa076dd07db906b87079abf99c8147c2b313deabfd34d706"),
            ("E walk intermediate", "talking-island-wild-dog-authoring/E-walk1-individual-attempt1.png", "1c6008e40db13ebe203b337c862030332795535f234addc663031efdbf878e40"),
            ("E walk B pilot", "talking-island-wild-dog-authoring/E-walk4-physical-pilot3-B-single-primary.png", "2a73243d78d3aa0299cfb29f1c2935a6b6c7552092faafac055a5d8f699c0488"),
            ("Idle front8 rejected", "talking-island-wild-dog-authoring/idle-front8-attempt3-portrait-padding-UNVALIDATED.png", "fa7ff9297b47c1caa4254bce8a8c599a6988130287911637ab3fbc0cfd85691e"),
        ],
    },
}


def sha_bytes(data):
    return hashlib.sha256(data).hexdigest()


def safe_original(source, expected_sha):
    if source.is_symlink() or not source.is_file():
        raise ValueError(f"Archive not regular file: {source}")
    h = hashlib.sha256()
    with source.open("rb") as f:
        for part in iter(lambda: f.read(2 * 1024 * 1024), b""):
            h.update(part)
    if h.hexdigest() != expected_sha:
        raise ValueError(f"Archive SHA mismatch: {source}")
    return h.hexdigest()


def checkerboard(width, height):
    im = Image.new("RGBA", (width, height), "#e2e6e9")
    draw = ImageDraw.Draw(im)
    for y in range(0, height, 24):
        for x in range(0, width, 24):
            if (x // 24 + y // 24) % 2:
                draw.rectangle((x, y, x + 23, y + 23), fill="#bfc7cb")
    return im


def render_group(name, group, output):
    safe_original(group["archive"], group["sha256"])
    member_evidence = []
    board = Image.new("RGB", (1200, len(group["members"]) * 460 + 72), "#181f26")
    draw = ImageDraw.Draw(board)
    font = ImageFont.load_default()
    draw.text((24, 22), f"PR122 {name} - PRESERVED SOURCE QA - NOT APPROVED", fill="white", font=font)
    with zipfile.ZipFile(group["archive"]) as source:
        for n, (title, member, expected_sha) in enumerate(group["members"]):
            if member.startswith("/") or ".." in Path(member).parts:
                raise ValueError("Unsafe archive source member")
            info = source.getinfo(member)
            if info.file_size > 30 * 1024 * 1024:
                raise ValueError("Unexpectedly huge source member")
            body = source.read(info)  # Verify member CRC.
            if sha_bytes(body) != expected_sha:
                raise ValueError(f"Source PNG SHA mismatch: {member}")
            with Image.open(io.BytesIO(body)) as im:
                if im.format != "PNG" or im.mode != "RGBA":
                    raise ValueError(f"Source does not have preserved RGBA: {member}")
                original_size = list(im.size)
                thumb = im.copy()
                thumb.thumbnail((1140, 385), Image.Resampling.LANCZOS)
                panel = checkerboard(1152, 400)
                panel.alpha_composite(thumb, ((1152 - thumb.width) // 2, (400 - thumb.height) // 2))
            y = 60 + n * 460
            board.paste(panel.convert("RGB"), (24, y + 36))
            draw.text((24, y + 10), title + f" | {original_size[0]}x{original_size[1]} | {expected_sha[:16]}", fill="white", font=font)
            member_evidence.append({"label": title, "member": member, "original_png_sha256": expected_sha,
                                    "original_png_size": original_size, "archived_bytes": len(body),
                                    "source_pixels_modified": False, "visual_pass": False})
    out_file = output / f"pr122_{name}_WIP_SOURCE_REVIEW_ONLY.png"
    board.save(out_file)
    return {"actor_group": name, "archive": str(group["archive"]), "archive_sha256": group["sha256"],
            "review_board": out_file.name, "review_board_sha256": sha_bytes(out_file.read_bytes()),
            "members": member_evidence, "production_applied": False, "originals_rewritten": False,
            "independent_art_approved": False, "main_pass": False, "completed_added": 0,
            "next": ("Author joint/forepaw reversal rather than repeating failed NW/NE prompts"
                     if name == "wolf" else "Review head/core registration, E support pattern and idle16 before eight-direction expansion")}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--root", type=Path, default=Path("."))
    p.add_argument("--out", type=Path, required=True)
    args = p.parse_args()
    out = args.out
    if out.is_symlink() or (out.exists() and (not out.is_dir() or any(out.iterdir()))):
        raise ValueError("Use a fresh EMPTY output directory for source-only QA boards")
    out.mkdir(parents=True, exist_ok=True)
    results = []
    for name, pack in PACKS.items():
        group = {**pack, "archive": args.root / pack["archive"]}
        results.append(render_group(name, group, out))
    path = out / "source_review_manifest.json"
    path.write_text(json.dumps({"schema": 1, "status": "SOURCE_REVIEW_ONLY_HOLD", "groups": results},
                               ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"status": "SOURCE_REVIEW_ONLY_HOLD", "archive_checks": 2, "source_checks": 7,
                      "originals_modified": False, "production_applied": False, "manifest_sha256": sha_bytes(path.read_bytes())}))


if __name__ == "__main__":
    main()
