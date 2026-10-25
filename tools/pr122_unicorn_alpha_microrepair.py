#!/usr/bin/env python3
"""Extract a pinned unicorn source and propose a MICROSCOPIC alpha-only repair.

All changes are opt-in, source-only, and unapproved. This never changes any
production file, alters an import threshold, reauthors a silhouette, or fills
missing poses. Non-trivial disconnected details MUST be reauthored/reviewed.
"""
import argparse
import hashlib
import io
import json
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

STRUCTURE = np.ones((3, 3), dtype=np.uint8)  # exact standalone importer 8-neighbor connectivity


def sha(data):
    return hashlib.sha256(data).hexdigest()


def pinned_source(args):
    if bool(args.input) == bool(args.archive):
        raise ValueError("Provide exactly one original PNG or pinned archive")
    if args.input:
        src = Path(args.input)
        if src.is_symlink() or not src.is_file():
            raise ValueError("Missing/linked original source")
        data = src.read_bytes()
        name = src.name
    else:
        archive = Path(args.archive)
        if archive.is_symlink() or not archive.is_file():
            raise ValueError("Missing/linked archive")
        if not args.member or not args.archive_sha256:
            raise ValueError("Archive and member must each be SHA-pinned")
        if len(args.archive_sha256) != 64:
            raise ValueError("Invalid archive digest")
        h = hashlib.sha256()
        with archive.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                h.update(chunk)
        if h.hexdigest() != args.archive_sha256:
            raise ValueError("Archive SHA mismatch")
        from pathlib import PurePosixPath
        entry = PurePosixPath(args.member)
        if entry.is_absolute() or ".." in entry.parts or entry.suffix != ".png":
            raise ValueError("Unsafe PNG member")
        with zipfile.ZipFile(archive) as package:
            info = package.getinfo(str(entry))
            if info.file_size > 20 * 1024 * 1024:
                raise ValueError("Oversized member")
            data = package.read(info)  # ZIP member CRC is checked
        name = entry.name
    if len(args.source_sha256) != 64 or sha(data) != args.source_sha256:
        raise ValueError("Original PNG SHA mismatch")
    return name, data


def propose(data, max_island=3, max_total=11):
    with Image.open(io.BytesIO(data)) as picture:
        if picture.format != "PNG" or picture.mode != "RGBA":
            raise ValueError("Only preserved RGBA PNG sources are eligible")
        pixels = np.array(picture, copy=True)
    before = pixels.copy()
    mask = pixels[:, :, 3] > 100
    labels, count = ndimage.label(mask, structure=STRUCTURE)
    sizes = np.bincount(labels.ravel())[1:]
    report = {"status": "REFUSED", "original_sha256": sha(data),
              "image_size": [pixels.shape[1], pixels.shape[0]],
              "visible_components_before": int(count), "component_sizes": sorted(map(int, sizes), reverse=True),
              "alpha_threshold_unchanged": 100, "connectivity_unchanged": 8,
              "approved": False, "production_applied": False, "completed_added": 0}
    if count <= 1:
        report["reason"] = "Already one visible body; no source alteration allowed"
        return report, None
    if np.any(mask[0]) or np.any(mask[-1]) or np.any(mask[:, 0]) or np.any(mask[:, -1]):
        report["reason"] = "Existing opaque source touches canvas boundary"
        return report, None
    main_id = int(np.argmax(sizes) + 1)
    detached = (labels != 0) & (labels != main_id)
    bad = sizes[np.arange(count) != main_id - 1]
    detached_count = int(detached.sum())
    report["main_visible_pixels"] = int(sizes[main_id - 1])
    report["detached_visible_pixels"] = detached_count
    ys, xs = np.nonzero(detached)
    report["detached_coordinates_xy"] = [[int(x), int(y)] for x, y in zip(xs, ys)] if len(xs) <= 64 else []
    if (sizes[main_id - 1] < 200 or detached_count > max_total or
            not len(bad) or int(bad.max()) > max_island or detached_count <= 0):
        report["reason"] = "Disconnected detail exceeds pinned microrepair budget; reauthor, do not erase"
        return report, None
    # No changes inside the original main connected body or anywhere else.
    pixels[detached] = [0, 0, 0, 0]
    labels_after, count_after = ndimage.label(pixels[:, :, 3] > 100, structure=STRUCTURE)
    changed = np.any(pixels != before, axis=2)
    if (count_after != 1 or np.any(changed & (labels == main_id)) or
            not np.array_equal(changed, detached) or
            not np.array_equal(pixels[~detached], before[~detached])):
        raise ValueError("Microrepair pixel preservation invariant failed")
    out = io.BytesIO()
    Image.fromarray(pixels, "RGBA").save(out, format="PNG")
    rendered = out.getvalue()
    report.update(status="UNAPPROVED_ALPHA_MICROCANDIDATE", visible_components_after=int(count_after),
                  changed_pixels=detached_count, main_body_rgba_exact=True, output_sha256=sha(rendered),
                  note="Isolated high-alpha pixels only; alpha<=100 halo and visual identity need human review")
    return report, rendered


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--input", type=Path)
    p.add_argument("--archive", type=Path)
    p.add_argument("--archive-sha256")
    p.add_argument("--member")
    p.add_argument("--source-sha256", required=True)
    p.add_argument("--out-dir", type=Path, required=True)
    p.add_argument("--max-island", type=int, default=3)
    p.add_argument("--max-total", type=int, default=11)
    p.add_argument("--write-candidate", action="store_true")
    args = p.parse_args()
    if not 1 <= args.max_island <= 3 or not 1 <= args.max_total <= 11:
        p.error("Cannot relax source microrepair limits")
    name, data = pinned_source(args)
    report, output = propose(data, max_island=args.max_island, max_total=args.max_total)
    report.update(source_name=name, source_unchanged=True,
                  missing_approved_pngs_still_hold=2, visual_review_required=True,
                  actor="monster:알비노 유니콘")
    target = args.out_dir
    if target.is_symlink() or (target.exists() and (not target.is_dir() or any(target.iterdir()))):
        raise ValueError("Use a NEW EMPTY evidence-only output directory")
    target.mkdir(parents=True, exist_ok=True)
    if output is not None and args.write_candidate:
        filename = Path(name).stem + "-microcandidate.png"
        (target / filename).write_bytes(output)
        report["candidate_file"] = filename
        if sha((target / filename).read_bytes()) != report["output_sha256"]:
            raise ValueError("Candidate output SHA verification failed")
    else:
        report["candidate_file"] = None
    (target / "diagnostic.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
