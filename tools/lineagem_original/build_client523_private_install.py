#!/usr/bin/env python3
"""One command: complete 523 client -> private source bank -> Main loader config.

Runs, in order and into one new private directory outside the repository:

1. client523_source.py      -> <out>/source   (verified by the 523 files_info SHA-1)
2. client523_bank_metadata  -> <out>/meta     (repository SPR reader, client 24fps default)
3. build_reference_sp2_bank -> <out>/bank     (--link-raw; client 24fps, absent-layer and frame rules)
   add_static_pictures        -> <out>/bank     (client no-action static branch)
4. configure_current523_source_bank -> <out>/current523_source_bank.json

The runtime still pins the original tables ZIP (d5192c3c...). Pass that ZIP with
--runtime-tables-zip; step 1 compares it table by table with the decoded client
tables and the run stops unless they are equivalent. Copy the printed config to
the game's user:// directory, or pass it with --current523-source-bank-config.

Needs the packages in requirements.txt (brotli for SP2). Nothing is uploaded.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PINNED_TABLES_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"


def run(*command):
    print("+", " ".join(str(c) for c in command[:3]), "...", flush=True)
    completed = subprocess.run([sys.executable, *map(str, command)], cwd=HERE, capture_output=True, text=True)
    if completed.returncode not in (0, 2):
        sys.stderr.write(completed.stderr[-4000:])
        raise SystemExit(f"step failed ({completed.returncode}): {command[0]}")
    return completed


def sha256(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            value.update(block)
    return value.hexdigest()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--files-info", type=Path, required=True)
    parser.add_argument("--client-zip", type=Path, action="append", default=[])
    parser.add_argument("--patch-zip", type=Path, action="append", default=[])
    parser.add_argument("--client-dir", type=Path)
    parser.add_argument("--content-password-b64-file", type=Path, required=True)
    parser.add_argument("--runtime-tables-zip", type=Path, required=True,
                        help="the tables ZIP pinned by the runtime (SHA-256 d5192c3c...)")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    out = args.output.resolve()
    repo = HERE.parents[1]
    if out == repo or repo in out.parents:
        parser.error("--output must be outside the repository")
    if out.exists():
        parser.error("--output must not exist yet")
    tables_zip = args.runtime_tables_zip.resolve()
    if sha256(tables_zip) != PINNED_TABLES_SHA256:
        parser.error("--runtime-tables-zip is not the runtime-pinned tables ZIP")
    out.mkdir(parents=True, mode=0o700)

    source = out / "source"
    command = ["client523_source.py", "--files-info", args.files_info.resolve(),
               "--content-password-b64-file", args.content_password_b64_file.resolve(),
               "--verify-tables-zip", tables_zip, "--output", source]
    for part in args.client_zip:
        command += ["--client-zip", part.resolve()]
    for patch in args.patch_zip:
        command += ["--patch-zip", patch.resolve()]
    if args.client_dir:
        command += ["--client-dir", args.client_dir.resolve()]
    run(*command)
    receipt = json.loads((source / "client523_receipt.json").read_text())
    if not receipt.get("complete"):
        raise SystemExit(f"client is incomplete: {len(receipt['missing'])} files missing; see {source}/client523_receipt.json")
    comparison = receipt["runtime_tables_zip_comparison"]
    if not comparison["equivalent"]:
        raise SystemExit("runtime tables ZIP differs from the client 523 tables: "
                         f"{len(comparison['different'])} different, {len(comparison['only_in_zip'])} only in ZIP, "
                         f"{len(comparison['only_in_client'])} only in client")

    meta = out / "meta"
    run("client523_bank_metadata.py", "--client-source", source, "--output", meta, "--client-section-default-fps")
    bank = out / "bank"
    result = run("build_reference_sp2_bank.py", "--metadata", meta, "--requests", meta / "seed-requests.jsonl",
                 "--output", bank, "--original-root", source / "sp2", "--spr-root", source / "spr",
                 "--client-section-default-fps", "--client-omit-missing-layers", "--client-frame-rules", "--link-raw")
    summary = json.loads(result.stdout)
    run("add_static_pictures.py", "--bank", bank, "--metadata", meta, "--spr-root", source / "spr",
        "--original-root", source / "sp2", "--link-raw")
    manifest = bank / "manifest.json"
    config = out / "current523_source_bank.json"
    run("configure_current523_source_bank.py", "--tables-zip", tables_zip, "--manifest", manifest,
        "--manifest-sha256", sha256(manifest), "--output", config)
    counts = summary["counts"]
    print(json.dumps({"config": str(config), "bank_manifest": str(manifest),
                      "requested_actions": counts["requested_actions"], "compiled_actions": counts["compiled_actions"],
                      "compiled_raw_members": counts["compiled_raw_members"],
                      "action_statuses": counts["action_statuses"]}, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
