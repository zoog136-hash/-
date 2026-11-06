#!/usr/bin/env python3
"""Prepare an offline, private adoption plan; never extract, install or select it."""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import stat
import zipfile
import zlib
from pathlib import Path, PurePosixPath

MANIFEST_LIMIT = 33_554_432
ACTION_LIMIT = 16_777_216
ROOT = "private-source-bank/source_reference523/"
REPOSITORY = Path(__file__).resolve().parents[2]


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise ValueError(reason)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def bounded(path: Path, limit: int) -> bytes:
    require(stat.S_ISREG(path.lstat().st_mode), "regular file required")
    require(path.stat().st_size <= limit, "input exceeds finite size bound")
    return path.read_bytes()


def relative(value: str) -> str:
    p = PurePosixPath(value)
    require(not p.is_absolute() and all(x not in ("", ".", "..") for x in value.split("/")), "unsafe path")
    require("\\" not in value and ":" not in value, "nonportable path")
    require(value in ("manifest.json", "source-action-domain-proofs.jsonl.gz")
            or (len(p.parts) == 3 and p.parts[:2] == ("raw", "Sprite") and p.suffix == ".sp2")
            or (len(p.parts) == 3 and p.parts[0] == "actors" and p.parts[1].isdigit()
                and p.name.startswith("action-") and p.suffix == ".json"), "unsupported bank path")
    return value


def additive(previous: dict, current: dict) -> None:
    mutable = {"members", "actors", "source_action_domains", "source_action_domain_proofs"}
    require(previous.keys() == current.keys(), "manifest schema changed")
    for key in previous.keys() - mutable:
        require(previous[key] == current[key], "existing manifest policy changed: " + key)
    for category in ("members", "source_action_domains"):
        require(all(current[category].get(k) == v for k, v in previous[category].items()),
                "existing source identities/domains changed")
    for actor, actions in previous["actors"].items():
        require(all(current["actors"].get(actor, {}).get(k) == v for k, v in actions.items()),
                "existing actor action changed")


def inspect_step(expected: dict, contract_path: Path, archive: Path, previous: dict) -> tuple[dict, dict]:
    contract_bytes = bounded(contract_path, 2_097_152)
    require(sha(contract_bytes) == expected["contract_sha256"], "contract pin differs")
    contract = json.loads(contract_bytes)
    for key in ("base_manifest_sha256", "proposed_merged_manifest_sha256"):
        require(contract[key] == expected[key], "chain pin differs")
    require(contract["required_relative_bank_root"] == ROOT, "bank root differs")
    archive_bytes = bounded(archive, 104_857_600)
    require(len(archive_bytes) == expected["compressed_bytes"] and sha(archive_bytes) == expected["sha256"],
            "archive bytes/pin differ")
    entries = contract["files"]
    wanted = {ROOT + relative(row["path"]): row for row in entries}
    require(len(wanted) == len(entries) == expected["member_count"] <= 4096, "duplicate/member count differs")
    require(sum(row["bytes"] for row in entries) == expected["uncompressed_bytes"] <= 134_217_728,
            "decoded bytes differ")
    receipts = []
    manifests = {}
    with zipfile.ZipFile(io.BytesIO(archive_bytes)) as z:
        require(len(z.infolist()) == len(wanted) and set(z.namelist()) == set(wanted), "unexpected archive entries")
        for info in z.infolist():
            row = wanted[info.filename]
            limit = ACTION_LIMIT if row["path"].startswith("actors/") else MANIFEST_LIMIT
            require(not info.is_dir() and not info.flag_bits & 1
                    and info.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)
                    and not stat.S_ISLNK(info.external_attr >> 16), "unsupported ZIP entry")
            require(0 <= info.file_size == row["bytes"] <= limit, "entry size differs")
            data = z.read(info)
            require(sha(data) == row["sha256"], "member SHA differs: " + row["path"])
            receipts.append({"path": row["path"], "bytes": len(data), "sha256": row["sha256"],
                             "crc32": "%08x" % (zlib.crc32(data) & 0xffffffff)})
            if row["path"] == "manifest.json":
                require(sha(data) == expected["proposed_merged_manifest_sha256"], "target manifest differs")
                manifests = json.loads(data)
    require(bool(manifests), "target manifest absent")
    additive(previous, manifests)
    before = set(previous["members"])
    new_members = {v["path"]: v for k, v in manifests["members"].items() if k not in before}
    new_actions = {v["path"]: v for actor, actions in manifests["actors"].items()
                   for action, v in actions.items() if action not in previous["actors"].get(actor, {})}
    payload = {row["path"]: row for row in receipts}
    require(set(payload) == set(new_members) | set(new_actions)
            | {"manifest.json", "source-action-domain-proofs.jsonl.gz"}, "delta is not exactly additive")
    for path, record in (new_members | new_actions).items():
        if record["sha256"] is None and path in new_members:
            identity = record.get("source_identity", {})
            require(record.get("crc32") == payload[path]["crc32"]
                    and record.get("source_receipt_id") == record.get("member")
                    and identity.get("source_snapshot") == "patch523"
                    and identity.get("basis") == "supplied_exact_current523_member_archive_bytes_crc_domain"
                    and identity.get("archive") and identity.get("source_manifest_reference")
                    and identity.get("whole_current523_manifest_match") in (None, True),
                    "received member identity/CRC differs")
            require(identity.get("whole_current523_manifest_match") is True
                    or identity.get("version_basis") in ("retained508_outer_manifest", "supplied_current523_container_manifest"),
                    "received version identity absent")
            require(record.get("stage") in ("received_not_additionally_validated",
                    "received_original_from_prior_verified_package_no_new_validation"),
                    "unsupported historical receipt stage")
        else:
            require(payload[path]["sha256"] == record["sha256"], "manifest member receipt differs")
        if path in new_members:
            require(payload[path]["bytes"] == record["bytes"], "raw member length differs")
    require(payload["source-action-domain-proofs.jsonl.gz"]["sha256"]
            == manifests["source_action_domain_proofs"]["sha256"], "domain proof pin differs")
    return manifests, {"base_pin": expected["base_manifest_sha256"],
                       "target_pin": expected["proposed_merged_manifest_sha256"],
                       "archive_sha256": expected["sha256"], "members": receipts,
                       "new_originals": len(new_members), "new_actions": len(new_actions)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-manifest", required=True, type=Path)
    parser.add_argument("--source-config", required=True, type=Path)
    parser.add_argument("--contract", required=True, action="append", type=Path)
    parser.add_argument("--archive", required=True, action="append", type=Path)
    parser.add_argument("--output-plan", required=True, type=Path)
    args = parser.parse_args()
    chain = json.loads((REPOSITORY / "data/source523_sprite_update_chain_v1.json").read_text())
    require(chain.get("schema") == 1 and chain.get("frozen_distribution_mutation_allowed") is False,
            "unsupported adoption chain")
    pin = chain["base_manifest_sha256"]
    for step in chain["steps"]:
        require(step["base_manifest_sha256"] == pin, "broken manifest chain")
        pin = step["proposed_merged_manifest_sha256"]
    require(pin == chain["archive_chain_target_manifest_sha256"], "chain target differs")
    require(len(args.contract) == len(args.archive) == len(chain["steps"]), "complete ordered chain required")
    base = bounded(args.base_manifest, MANIFEST_LIMIT)
    require(sha(base) == chain["base_manifest_sha256"], "exact base manifest required")
    config_bytes = bounded(args.source_config, 1_048_576)
    config = json.loads(config_bytes)
    require(config.get("schema") == 1 and config.get("source_snapshot") == "patch523"
            and config.get("manifest_sha256") == sha(base), "source config/base mismatch")
    require(Path(config["manifest_path"]).resolve() == args.base_manifest.resolve(), "source config path differs")
    manifest = json.loads(base)
    steps = []
    for expected, contract, archive in zip(chain["steps"], args.contract, args.archive):
        manifest, receipt = inspect_step(expected, contract, archive, manifest)
        steps.append(receipt)
    # Never rewrite the authenticated ZIPs. Produce a separate final manifest
    # that repairs only the historical acquisition-stage serialization mismatch.
    stage_repairs = []
    for step in steps:
        for row in step["members"]:
            if not row["path"].startswith("raw/"):
                continue
            member = row["path"].removeprefix("raw/")
            spec = manifest["members"][member]
            if spec.get("sha256") is None and spec.get("stage") != "received_not_additionally_validated":
                stage_repairs.append({"member": member, "previous_stage": spec["stage"]})
                spec["source_acquisition_stage"] = spec["stage"]
                spec["stage"] = "received_not_additionally_validated"
    final_bytes = (json.dumps(manifest, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode()
    require(len(final_bytes) <= MANIFEST_LIMIT, "adoption manifest exceeds runtime bound")
    require(sha(final_bytes) == chain["target_manifest_sha256"]
            and len(final_bytes) == chain["adoption_manifest_bytes"]
            and len(stage_repairs) == chain["receipt_stage_repairs"], "final adoption candidate differs")
    destination = args.output_plan.resolve()
    require(not destination.is_relative_to(REPOSITORY), "private plan must be outside repository")
    require(not destination.is_relative_to(args.base_manifest.resolve().parent),
            "preserve the original bank directory")
    require(not destination.exists(), "preserve existing plan; choose a new destination")
    final_manifest = destination.with_suffix(".manifest.json")
    require(not final_manifest.exists(), "preserve existing adoption manifest")
    destination.parent.mkdir(parents=True, exist_ok=True)
    plan = {"schema": 1, "kind": "current523_separate_candidate_adoption_plan", "state": "not_applied",
            "legacy_manual_inventory_overlay_allowed": False, "base_manifest_sha256": sha(base),
            "archive_chain_target_manifest_sha256": chain["archive_chain_target_manifest_sha256"],
            "target_manifest_sha256": sha(final_bytes), "steps": steps,
            "final_manifest": {"path": str(final_manifest), "bytes": len(final_bytes), "sha256": sha(final_bytes)},
            "receipt_stage_repairs": stage_repairs,
            "original_config_sha256": sha(config_bytes), "original_config": config,
            "adoption_requires_separate_approval": True,
            "receiver_requirements": ["verify every base payload from the base manifest before copying",
                "clone the base into a new private candidate directory; never overlay frozen manual resources",
                "apply each ordered delta and member receipt; reject existing-path changes except proof/manifest",
                "preserve old proof/manifest; stage both archives without selecting intermediate manifests",
                "write the separate corrected final adoption manifest last using atomic replacement",
                "issue a new full candidate inventory; legacy v30/61 resource inventory stays unchanged",
                "create a separate config preserving tables and whitelist pins; switch only after approval"],
            "rollback": {"method": "reselect preserved original config and bank; do not reverse-overlay",
                         "original_bank_and_config_must_remain_unchanged": True},
            "gameplay_observed": False}
    with final_manifest.open("xb") as f:
        f.write(final_bytes)
    with destination.open("x", encoding="utf-8") as f:
        json.dump(plan, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("Prepared private adoption plan only; no resources/configuration selected or installed.")


if __name__ == "__main__":
    main()
