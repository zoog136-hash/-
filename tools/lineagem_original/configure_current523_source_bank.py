#!/usr/bin/env python3
"""Write private Main loader options from an already produced source bank.

This creates configuration only. It does not compile, inspect, render or verify
source resources. Runtime production guards enforce the source and bank pins.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tables-zip", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--manifest-sha256", required=True)
    parser.add_argument("--overlay-whitelist", type=Path)
    parser.add_argument("--overlay-whitelist-sha256")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    config = {
        "schema": 1,
        "enabled": True,
        "source_snapshot": "patch523",
        "tables_zip": str(args.tables_zip.absolute()),
        "manifest_path": str(args.manifest.absolute()),
        "manifest_sha256": args.manifest_sha256,
    }
    if args.overlay_whitelist is not None:
        if not args.overlay_whitelist_sha256:
            parser.error("--overlay-whitelist-sha256 is required with --overlay-whitelist")
        config["overlay_whitelist_path"] = str(args.overlay_whitelist.absolute())
        config["overlay_whitelist_sha256"] = args.overlay_whitelist_sha256
    # Avoid writing source settings or private paths into the public repository.
    repository = Path(__file__).resolve().parents[2]
    destination = args.output.absolute()
    if destination.is_relative_to(repository):
        parser.error("The configuration must be outside the public repository.")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Created private runtime configuration: {destination}")
    print(f"Main argument: --current523-source-bank-config={destination}")


if __name__ == "__main__":
    main()
