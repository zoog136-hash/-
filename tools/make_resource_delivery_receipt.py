#!/usr/bin/env python3
"""Create a sidecar receipt for a real, independently preserved private original-art ZIP.

This does not upload files or claim Godot integration. Verify the same ZIP
again using check_resource_integrity.py --release-dir before reporting delivery.
"""
import argparse
import json
from pathlib import Path
import zipfile
from check_resource_integrity import SOURCE_PACK_NAME, safe_relative, sha256_file, require


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release-dir", type=Path, required=True)
    args = parser.parse_args()
    directory = args.release_dir.resolve()
    package = directory / SOURCE_PACK_NAME
    require(package.is_file(), f"ARCHIVE MISSING: {package}")
    with zipfile.ZipFile(package) as archive:
        require(archive.testzip() is None, "ZIP CRC CHECK FAILED")
        originals = [i for i in archive.infolist() if not i.is_dir() and
                     (i.filename.startswith("assets/external_l1j/") or
                      i.filename.startswith("assets/external_spx/") or
                      i.filename.startswith("assets/l1j/verified/") or
                      i.filename.startswith("data/l1j/maps/"))]
        require(originals, "ZIP DOES NOT CONTAIN EXPECTED ORIGINAL RESOURCE PATHS")
        for item in originals:
            safe_relative(item.filename)
            require(item.file_size > 0, f"EMPTY SOURCE: {item.filename}")
    receipt = {
        "schema": 1,
        "archive": SOURCE_PACK_NAME,
        "bytes": package.stat().st_size,
        "sha256": sha256_file(package),
        "original_file_count": len(originals),
        "disclaimer": "ZIP integrity only; licensing, complete original map coverage, fresh checkout installation and Godot visual rendering require separate review",
    }
    target = directory / "resource_delivery_receipt.json"
    target.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"RECEIPT_WRITTEN {target} original_files={len(originals)}")


if __name__ == "__main__":
    main()
