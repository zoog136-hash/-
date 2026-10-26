#!/usr/bin/env python3
"""Audit every raw and runtime item row without changing gameplay databases."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
import hashlib
import json
from pathlib import Path
import subprocess
from PIL import Image


STATES = ("original_linked", "inven_exact_name", "inven_visual_alias", "original_review_pending", "self_authored_substitute", "bundled_ui_art", "image_missing")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit(root: Path, runtime: dict, sources: dict, base: str) -> tuple[dict, dict]:
    catalog = json.loads((root / "data/catalog_v19.json").read_text())["아이템"]
    extraction = json.loads((root / "data/v19_extraction_manifest.json").read_text())["catalog_images"]
    errors: list[str] = []
    tracked = set(subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode().split("\0"))
    files: dict[str, dict] = {}
    proofs = {}
    names: dict[str, list[str]] = defaultdict(list)
    image_urls: dict[str, set[str]] = defaultdict(set)
    ids = set()
    for row in catalog:
        identity = str(row["sourceId"])
        if identity in ids:
            errors.append("duplicate sourceId " + identity)
        ids.add(identity)
        names[row["name"]].append(identity)
        path = row["image_path"]
        image_urls[path].add(row["sourceImageUrl"])
        relative = path.removeprefix("res://")
        local = root / relative
        if not path.startswith("res://assets/") or ".." in Path(relative).parts or not local.is_file():
            errors.append("missing/unsafe catalog path: " + identity)
            continue
        if relative not in tracked:
            errors.append("untracked source image: " + relative)
        if path not in files:
            try:
                with Image.open(local) as image:
                    image.load()
                    dimensions = list(image.size)
                    alpha_visible = image.convert("RGBA").getchannel("A").getextrema()[1] > 0
                files[path] = {"sha256": sha(local), "bytes": local.stat().st_size, "size": dimensions,
                               "decoded": True, "alpha_visible": alpha_visible, "tracked": relative in tracked}
            except Exception as exc:
                errors.append(f"decode failed {path}: {exc}")
                continue
        expected = extraction.get(row["imageKey"], {})
        if expected.get("path") != path or expected.get("sha256") != files[path]["sha256"]:
            errors.append("extraction manifest mismatch: " + identity)
        if not files[path]["alpha_visible"]:
            errors.append("fully transparent source icon: " + identity)
        page = sources.get("records", {}).get(identity, {})
        remote = sources.get("images", {}).get(row["sourceImageUrl"], {})
        verified = (page.get("verification") == "structured_item_identity_v3"
                    and all(page.get(k) for k in ("exact_id_found", "exact_name_found", "exact_image_found"))
                    and remote.get("id_byte_matches", {}).get(identity) is True
                    and remote.get("sha256") == files[path]["sha256"])
        proofs[identity] = {"path": path, "sha256": files[path]["sha256"],
                            "identity": "source_id_name_image_bytes_verified" if verified else "pending",
                            "rights": "preexisting_repository_asset_reused_no_new_original_bytes"}
    for path, urls in image_urls.items():
        if len(urls) > 1:
            errors.append("one file bound to different source image URLs: " + path)
    index = json.loads((root / "data/catalog_image_index_v19.json").read_text())["아이템"]
    paths_by_name: dict[str, set[str]] = defaultdict(set)
    for row in catalog:
        paths_by_name[row["name"]].add(row["image_path"])
    for name, path in index.items():
        if path not in paths_by_name.get(name, set()):
            errors.append("name index points to another item's image: " + name)
    l1j = json.loads((root / "data/visuals/runtime_manifest.json").read_text())["items"]
    catalog_by_id = {str(row["sourceId"]):row for row in catalog}
    l1j_report = []
    for identity, binding in l1j.items():
        if binding.get("game_source_id") != identity:
            errors.append("L1J key/sourceId disagreement: " + identity)
        if identity in catalog_by_id and binding.get("name") != catalog_by_id[identity]["name"]:
            errors.append("L1J sourceId/name disagreement: " + identity)
        entry = {"id":identity,"name":binding.get("name"),"source_icon_id":binding.get("source_icon_id"),"files":{}}
        for kind in ("path","ground_path"):
            path = binding.get(kind, "")
            local = root / path.removeprefix("res://")
            if not path.startswith("res://assets/") or not local.is_file():
                errors.append("L1J file missing: " + identity + "/" + kind)
                continue
            with Image.open(local) as image:
                image.load()
            entry["files"][kind] = {"path":path,"sha256":sha(local),"tracked":path.removeprefix("res://") in tracked}
            if not entry["files"][kind]["tracked"]: errors.append("L1J file not tracked: " + path)
        l1j_report.append(entry)
    protected = {}
    # Catalog/DB identity is pinned to the item-audit baseline. Gameplay modules
    # may legitimately change in a full-game PR, so compare them to the checked
    # out commit instead. This still catches mutation by the audit/runtime steps.
    pinned_data = ("data/catalog_v19.json", "data/game_db_v17.json", "data/catalog_image_index_v19.json")
    runtime_code = ("scripts/world.gd", "scripts/player.gd", "scripts/original_enhancement.gd")
    for path in (*pinned_data, *runtime_code):
        reference = base if path in pinned_data else "HEAD"
        original = subprocess.check_output(["git", "show", f"{reference}:{path}"], cwd=root)
        unchanged = original == (root / path).read_bytes()
        protected[path] = {"sha256": sha(root / path), "reference": reference,
                           "unchanged_from_reference": unchanged}
        if path in pinned_data:
            protected[path]["unchanged_from_base"] = unchanged
        if not unchanged:
            errors.append("protected source changed relative to " + reference + ": " + path)
    sets = {}
    for group in ("catalog", "legacy", "runtime"):
        rows = runtime.get(group, [])
        counts = Counter()
        for row in rows:
            info = row["resolution"]
            identity = str(info.get("source_id", ""))
            path = info["path"]
            if not row.get("loaded"):
                info["status"] = "image_missing"
                errors.append(f"runtime texture load failed: {group}/{row['row']}")
            elif identity in proofs and path == proofs[identity]["path"]:
                info["status"] = "original_linked" if proofs[identity]["identity"] != "pending" else "original_review_pending"
            if path and not (root / path.removeprefix("res://")).is_file():
                errors.append("resolved path missing: " + path)
            if path and path not in files:
                local = root / path.removeprefix("res://")
                if local.is_file():
                    with Image.open(local) as image:
                        image.load()
                        files[path] = {"sha256":sha(local),"bytes":local.stat().st_size,"size":list(image.size),
                                       "decoded":True,"tracked":path.removeprefix("res://") in tracked}
            if path in files:
                row["sha256"] = files[path]["sha256"]
                if not files[path]["tracked"]: errors.append("untracked runtime image: " + path)
            if group == "catalog" and path != row["pinned_path"]:
                errors.append("catalog sourceId path substituted: " + str(row["sourceId"]))
            if info["status"] not in STATES:
                errors.append("unrecognized visual state: " + str(info["status"]))
            counts[info["status"]] += 1
        sets[group] = {"total":len(rows),"states":{key:counts[key] for key in STATES},"rows":rows}
    if len(runtime.get("catalog", [])) != len(catalog): errors.append("incomplete runtime catalog export")
    errors.extend(runtime.get("failures", []))
    report = {"schema":1,"base_sha":base,"checked_date":"2026-10-12", "engine":runtime.get("engine"),
              "definitions":{"inven_exact_name":"Inventory-only exact item name and verified Inven image; no gameplay fields replaced.",
                             "inven_visual_alias":"Explicit Inven artwork alias for a custom/variant item; not an exact original-item identity match.",
                             "bundled_ui_art":"Stock UI picture, not an original item identity match.",
                             "original_linked":"Exact sourceId/name/image URL and PNG SHA verified against the current item detail data, or an existing manually reviewed L1J pair. This is image identity, not a new redistribution licence.",
                             "original_review_pending":"Image displays, but identity evidence is incomplete; excluded from confirmed original count.",
                             "self_authored_substitute":"Explicit TWILIGHT family symbol or existing owned UI icon; not original art.",
                             "image_missing":"No displayable texture; never counted as linked."},
              "sources":sets,"duplicate_names":{k:v for k,v in names.items() if len(v)>1},
              "files":files,"protected_data":protected,"failures":errors,
              "legacy_name_index":{"entries":len(index),"ambiguous_names":sum(len(names[name])>1 for name in index)},
              "l1j_candidates":l1j_report,
              "source_evidence_summary":sources.get("summary",{}),
              "notes":["Raw catalog and legacy row counts overlap; runtime is the actually merged active encyclopedia.",
                       "Inventory-only source acquisitions and explicit aliases are recorded separately in data/inven_inventory_icons.json; no private pack delivery is claimed.",
                       "Pending candidates and family substitutes remain separate even when every slot has a picture."]}
    return report, {"schema":1,"checked_date":"2026-10-12","records":proofs}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--source-evidence", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--base", default="f24c0a8372adc33dda4dcf76735b90ec7e537aba")
    parser.add_argument("--write-provenance", action="store_true")
    args = parser.parse_args()
    report, proofs = audit(args.root, json.loads(args.runtime.read_text()), json.loads(args.source_evidence.read_text()), args.base)
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "audit.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    fields = ["dataset","row","sourceId","name","grade","type","slot","status","route","path","sha256","family","loaded"]
    with (args.output / "audit.csv").open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for group, data in report["sources"].items():
            for row in data["rows"]:
                output = {key:row.get(key, "") for key in fields}
                output.update({key:row["resolution"].get(key, "") for key in ("status","route","path","family")})
                output["dataset"] = group
                writer.writerow(output)
    summary = {key:{"total":value["total"],"states":value["states"]} for key,value in report["sources"].items()}
    summary["failures"] = report["failures"]
    (args.output / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    if args.write_provenance and not report["failures"]:
        (args.root / "data/item_visual_provenance.json").write_text(json.dumps(proofs, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False))
    raise SystemExit(bool(report["failures"]))


if __name__ == "__main__":
    main()
