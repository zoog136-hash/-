#!/usr/bin/env python3
"""Generate a build_reference_sp2_bank.py metadata handoff from a client523 source.

The earlier handoff was produced outside this repository for a 54,384-member
subset. This generator derives the same files from the complete client source
written by client523_source.py, using this repository's own SPR reader, so the
bank builder's metadata plan and its actual-SPR compilation share one parser.

Input  (--client-source): the private client523_source.py output directory
       (spr/list_*.spr, client523_sp2_inventory.json, tables ZIP, receipt).
Output (--output): a new private metadata directory plus a seed request file.

Every inventory member becomes a target. Source-family roots are the sprite IDs
referenced by the 523 tables (category = table.column) and every declared sprite
that owns SP2 members (category = list_declared_sp2_owner). Roots only tell the
builder where to look; it still compiles nothing that its strict SPR/SP2 checks
reject. No gameplay role, FPS or playback is inferred here.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import copy
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import zipfile

import original_spr
import build_current523_identity_pack as identity
import build_reference_sp2_bank as bank
from client523_source import SPRITE_COLUMN, SP2_MEMBER

CONTEXTS = "current523_sp2_actor_dependency_context.jsonl.gz"
ROOTS = "current523_sp2_category_root_evidence.jsonl.gz"
GENERATOR = "tools/lineagem_original/client523_bank_metadata.py"
REFERENCE_NAMES = {101: ("shadow",), 105: ("clothes", "clothe")}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def gz_jsonl(rows) -> bytes:
    text = "".join(json.dumps(row, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n" for row in rows)
    buffer = io.BytesIO()
    with gzip.GzipFile(fileobj=buffer, mode="wb", mtime=0) as stream:
        stream.write(text.encode("utf-8"))
    return buffer.getvalue()


def action_key(declaration, code):
    # Runtime contract (reference_sp2_bank.gd): "<source_file>:B<block>:A<action_id>".
    # The block is the declaration header's source line, unique within a file.
    return f"{declaration.source_file}:B{declaration.source_line}:A{code}"


def reference_raw(reference):
    code = 105 if reference["kind"] == "clothes" else 101
    name = reference.get("source_name") or reference["kind"]
    return f"{code}.{name}({reference['raw']})"


def table_roots(tables_zip: Path):
    roots = defaultdict(set)
    with zipfile.ZipFile(tables_zip) as archive:
        for name in archive.namelist():
            table = Path(name).stem
            data = json.loads(archive.read(name).decode("utf-8-sig"))
            rows = data.get("rows", []) if isinstance(data, dict) else data
            for row in rows if isinstance(rows, list) else []:
                if not isinstance(row, dict) or (table == "NpcClass" and row.get("TestNPC")):
                    continue
                for key, value in row.items():
                    if SPRITE_COLUMN.match(key) and type(value) is int and value > 0:
                        roots[value].add(f"{table}.{key}")
    return roots


def generate(client_source: Path, output: Path, root_filter=None, client_default_fps=False):
    if output.exists():
        raise SystemExit(f"output must be a new directory: {output}")
    spr_paths = sorted((client_source / "spr").glob("list_*.spr"))
    if not spr_paths:
        raise SystemExit("client source has no spr/list_*.spr")
    source_bytes = {path.name: path.read_bytes() for path in spr_paths}
    sources = {name: sha(body) for name, body in source_bytes.items()}
    lines = {name: body.decode("cp949").splitlines() for name, body in source_bytes.items()}
    default_fps = original_spr.CLIENT_SECTION_DEFAULT_FPS if client_default_fps else None
    declarations = identity.read_native_sprs(spr_paths, default_fps)
    for path in spr_paths:
        if path.read_bytes() != source_bytes[path.name]:
            raise SystemExit(f"original SPR changed while generating metadata: {path.name}")
    inventory_spec = json.loads((client_source / "client523_sp2_inventory.json").read_text())
    tables_zip = client_source / "tables" / "current523_content_tables.zip"
    receipt = json.loads((client_source / "client523_receipt.json").read_text())
    if not receipt.get("complete"):
        raise SystemExit("client source receipt is incomplete; refusing to describe a partial client")

    action_rows, declaration_rows = [], []
    for sprite_id in sorted(declarations):
        for declaration in declarations[sprite_id]:
            keys = []
            registered_keys = {}
            # A header file remap is not action inheritance. Only descriptors
            # registered for this requested actor are eligible action rows.
            # Literal/alias events below retain failed and duplicate attempts.
            for code in sorted(declaration.native_action_descriptors):
                if not 0 <= code < 173:
                    continue  # Raw registration evidence remains in the declaration.
                # Keep duplicate-header declarations in the source handoff.
                # Their exact registered candidates can be described without
                # granting the compiler's separate unique-owner admission.
                action = copy.deepcopy(declaration.native_action_descriptors[code])
                key = action_key(declaration, code)
                keys.append(key)
                registered_keys[str(code)] = key
                action_rows.append({
                    "action_key": key, "action_id": code, "action_name_literal": action["name"],
                    "explicit_fps": action["fps"],
                    "source_tokens_selector_frame_ticks": [list(t) for t in action["tokens"]],
                    "raw_body": action["raw_body"], "source_file": action["source_file"],
                    "source_file_sha256": sources[action["source_file"]], "source_line": action["source_line"],
                    "fps_source": action["fps_provenance"], "declared_flag": action["declared_flag"],
                    "parse_issues": list(action["errors"]),
                    "opaque_token_annotations": action["source_annotations"],
                    "native_selector_policy": identity.NATIVE_SELECTOR_POLICY,
                    "native_requested_sprite_id": sprite_id,
                    "native_body_request_sprite_id": action["native_body_request_sprite_id"],
                    "native_descriptor_origin_sprite_id": action["native_descriptor_origin_sprite_id"],
                    "native_registration_kind": action["native_registration_kind"],
                    "native_action_alias_chain": copy.deepcopy(action["native_action_alias_chain"]),
                    "native_request_declaration": {
                        "sprite_id": sprite_id, "source_file": declaration.source_file,
                        "source_line": declaration.source_line,
                        "source_file_sha256": sources[declaration.source_file]}})
            refs = [{"raw": reference_raw(r), "targets": list(r["targets"]),
                     "source_line": declaration.source_line} for r in declaration.references]
            declaration_rows.append({
                "sprite_id": sprite_id, "alias_target": declaration.alias_target,
                "source_file": declaration.source_file,
                "source_file_sha256": sources[declaration.source_file],
                "source_line": declaration.source_line, "header_valid": True,
                "raw_declaration_text": lines[declaration.source_file][declaration.source_line - 1],
                "animation_action_keys": keys, "explicit_layer_references": refs,
                "native_selector_policy": identity.NATIVE_SELECTOR_POLICY,
                "native_registered_action_keys": registered_keys,
                "native_literal_action_declarations": copy.deepcopy(declaration.native_literal_action_declarations),
                "native_action_aliases": copy.deepcopy(declaration.native_action_aliases),
                "native_action_registration": copy.deepcopy(declaration.native_action_registration),
                "native_directives": copy.deepcopy(declaration.directives),
                "native_references": copy.deepcopy(declaration.references),
                "reference_issues": []})

    sp2_root = client_source / "sp2"
    inventory_rows, owners = [], set()
    for member in sorted(inventory_spec):
        spec = inventory_spec[member]
        body_path = sp2_root / member
        digest = sha(body_path.read_bytes()) if body_path.is_file() else None
        owners.add(int(SP2_MEMBER.match(member).group(1)))
        inventory_rows.append({"member": member, "bytes": spec["bytes"], "crc32": spec["crc32"],
                               "archive": spec["container"], "sha256": digest,
                               "source_snapshot": "current523",
                               "source_family_categories": ["client523_complete_inventory"]})

    roots = table_roots(tables_zip)
    for sprite_id in declarations:
        if sprite_id in owners:
            roots[sprite_id].add("list_declared_sp2_owner")
    if root_filter is not None:
        roots = {k: v for k, v in roots.items() if k in root_filter}
    root_rows = [{"sprite_id": sprite_id, "category": category}
                 for sprite_id in sorted(roots) for category in sorted(roots[sprite_id])]

    output.mkdir(parents=True, mode=0o700)
    files = {bank.INVENTORY: gz_jsonl(inventory_rows), bank.ACTIONS: gz_jsonl(action_rows),
             bank.DECLARATIONS: gz_jsonl(declaration_rows), CONTEXTS: gz_jsonl([]), ROOTS: gz_jsonl(root_rows)}
    for name, body in files.items():
        (output / name).write_bytes(body)
    manifest = {"schema": 1, "generator": GENERATOR, "source_snapshot": "current523",
                "client_receipt_sha256": sha((client_source / "client523_receipt.json").read_bytes()),
                "tables_zip_sha256": sha(tables_zip.read_bytes()),
                "timing_policy": "client_section_default_fps_24" if client_default_fps else "source_explicit_only",
                "native_selector_policy": identity.NATIVE_SELECTOR_POLICY,
                "native_selector_scope": "restored525_static_to_current523_compatibility_inference_not_native523_or_Android_execution",
                "expected_counts": {"inventory_members": len(inventory_rows),
                                    "target_members": len(inventory_rows)},
                "members": [{"name": name, "bytes": len(body), "sha256": sha(body)} for name, body in sorted(files.items())]}
    (output / bank.HANDOFF).write_text(json.dumps(manifest, indent=1, sort_keys=True))
    (output / "seed-requests.jsonl").write_text("")
    summary = {"declarations": len(declaration_rows), "actions": len(action_rows),
               "inventory_members": len(inventory_rows),
               "inventory_members_with_sha256": sum(1 for r in inventory_rows if r["sha256"]),
               "roots": len(roots), "spr_sources": len(sources),
               "actions_with_fps": sum(1 for r in action_rows if r["explicit_fps"]),
               "native_selector_policy": identity.NATIVE_SELECTOR_POLICY,
               "registered_action_aliases": sum(1 for r in action_rows if r["native_registration_kind"] == "explicit_action_alias"),
               "literal_action_events": sum(len(r["native_literal_action_declarations"]) for r in declaration_rows),
               "action_alias_events": sum(len(r["native_action_aliases"]) for r in declaration_rows)}
    return summary


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--client-source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--client-section-default-fps", action="store_true",
                        help="apply the client's evidenced per-section default rate (24) to actions without code110")
    parser.add_argument("--root-id", type=int, action="append",
                        help="limit source-family roots to these sprite IDs (for partial runs)")
    args = parser.parse_args(argv)
    repo = Path(__file__).resolve().parents[2]
    out = args.output.resolve()
    if out == repo or repo in out.parents:
        parser.error("--output must be outside the repository")
    print(json.dumps(generate(args.client_source, out, set(args.root_id) if args.root_id else None,
                              args.client_section_default_fps)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
