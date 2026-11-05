#!/usr/bin/env python3
"""Read a privately held, pinned 523 ZIP without extracting or executing it.

The returned definitions are private source data. The CLI emits only audit counts.
This is not an installer, an executable recipe, or proof of original UI identity.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import io
import json
import math
import os
from pathlib import Path, PurePosixPath
import stat
import zipfile
from fractions import Fraction

SOURCE_SIZE = 25_031_173
SOURCE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
# Hash/count evidence supplied by the independent source-inspection environment.
EVIDENCE = {
    "ItemHoningEntity": (24, "1d1c4ca0e9e72982d092d0b28ed83a40ded089292f907ac9ed0a3bff8de31cf7"),
    "ItemHoningCost": (6, "be80bb0c2e63ca1bde10b83b3d8ae07051c97fc2226409608a00aa9ef16545c2"),
    "ItemHoningProbability": (3, "c5e5b85c5481c9208e40da8b4834085d8dec24889dfb82526c502f22754a4ad8"),
    "ItemHoningEpithet": (1, "4890c96b605e250e748f254aa3f035a938d9292aa1e79b633a9561454ba812eb"),
    "ItemHoningEpithetBonus": (1, "3e34137df1a4d75c6fc0b19d1a99548b3c7710232f6e5e61742114b975088fc9"),
}
FIELDS = {
    "ItemHoningEntity": ("ID", "HoningID", "ItemClassID", "MinEnchant"),
    "ItemHoningCost": ("ID", "HoningID", "Enchant", "ItemClassID", "Amount"),
    "ItemHoningProbability": ("ID", "HoningID", "Enchant", "Probability"),
    "ItemHoningEpithet": ("ID", "HoningID", "Probability", "DescID"),
    "ItemHoningEpithetBonus": ("ID", "EpithetID", "BonusID"),
    "Bonus": ("ID", "BonusTypeID", "Value", "BonusApplicationTypeID", "BonusApplicationTargetID"),
}
MAX_INTEGER = 9_007_199_254_740_991
MAX_MEMBER = 64 * 1024 * 1024
MAX_TOTAL = 512 * 1024 * 1024


class SourceError(ValueError):
    pass


def require(value: bool, reason: str) -> None:
    if not value:
        raise SourceError(reason)


def _unique_object(pairs: list) -> dict:
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate JSON key")
        result[key] = value
    return result


def _integer(value: object, minimum: int = 0) -> bool:
    return type(value) is int and minimum <= value <= MAX_INTEGER


def decode_table(raw: bytes, table: str) -> list[dict]:
    """Strict typed parsing; BOM and CRLF remain part of the byte hash upstream."""
    try:
        payload = json.loads(raw.decode("utf-8-sig"), object_pairs_hook=_unique_object,
                             parse_constant=lambda _: (_ for _ in ()).throw(SourceError("nonfinite JSON")))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise SourceError(f"invalid JSON: {table}") from exc
    require(isinstance(payload, dict) and isinstance(payload.get("rows"), list), f"missing rows: {table}")
    rows = payload["rows"]
    ids = set()
    for row in rows:
        require(isinstance(row, dict), f"invalid row: {table}")
        for field in FIELDS[table]:
            value = row.get(field)
            if table == "Bonus" and field == "Value":
                require(type(value) in (int, float) and abs(value) <= MAX_INTEGER and math.isfinite(value),
                        "invalid Bonus.Value")
            else:
                positive = field in ("ID", "HoningID", "ItemClassID", "EpithetID", "BonusID", "Amount")
                require(_integer(value, 1 if positive else 0), f"invalid typed field: {table}.{field}")
        require(row["ID"] not in ids, f"duplicate ID: {table}")
        ids.add(row["ID"])
    return rows


def join_definitions(tables: dict[str, list[dict]]) -> dict:
    """Validate typed rows even after JSON round trips; do not trust cached indexes."""
    require(isinstance(tables, dict), "invalid tables")
    checked = {}
    for name in FIELDS:
        require(name in tables, f"missing table: {name}")
        checked[name] = decode_table(json.dumps({"rows": tables[name]}, allow_nan=False).encode(), name)
    bonus = {row["ID"]: row for row in checked["Bonus"]}
    epithets = {row["ID"]: row for row in checked["ItemHoningEpithet"]}
    links = []
    for row in checked["ItemHoningEpithetBonus"]:
        require(row["EpithetID"] in epithets, "dangling EpithetID")
        require(row["BonusID"] in bonus, "dangling BonusID")
        links.append({"link": copy.deepcopy(row), "epithet": copy.deepcopy(epithets[row["EpithetID"]]),
                      "bonus": copy.deepcopy(bonus[row["BonusID"]])})
    return {"tables": checked, "epithet_bonus_links": links, "execution_enabled": False}


def preview(definitions: dict, entity_id: int, enchant: int) -> dict:
    require(_integer(entity_id, 1) and _integer(enchant), "invalid selection")
    # Rebuild from rows: serialized or caller-supplied indexes/flags are not authority.
    valid = join_definitions(definitions.get("tables", {}))
    tables = valid["tables"]
    entities = [row for row in tables["ItemHoningEntity"] if row["ID"] == entity_id]
    require(len(entities) == 1, "unknown entity")
    entity = entities[0]
    honing_id = entity["HoningID"]
    costs = [row for row in tables["ItemHoningCost"] if row["HoningID"] == honing_id and row["Enchant"] == enchant]
    probabilities = [row for row in tables["ItemHoningProbability"] if row["HoningID"] == honing_id and row["Enchant"] == enchant]
    blockers = ["cost_relation_unverified", "probability_scale_unverified", "failure_transition_unverified",
                "destruction_transition_unverified", "physical_eligibility_unverified"]
    if enchant < entity["MinEnchant"]:
        blockers.append("below_source_minimum")
    if not costs:
        blockers.append("missing_cost_rows")
    if len(probabilities) != 1:
        blockers.append("missing_or_ambiguous_probability")
    return {"entity": copy.deepcopy(entity), "cost_rows": copy.deepcopy(costs),
            "probability_rows": copy.deepcopy(probabilities),
            "epithet_bonus_links": [link for link in valid["epithet_bonus_links"] if link["epithet"]["HoningID"] == honing_id],
            "execution_enabled": False, "blockers": blockers}


def _read_archive(path: Path, expected_size: int, expected_sha: str, evidence: dict) -> dict:
    # Open one regular file without following a leaf symlink; never extract members.
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, "rb") as source:
        before = os.fstat(source.fileno())
        require(stat.S_ISREG(before.st_mode), "source is not a regular file")
        require(before.st_size == expected_size, "source size mismatch")
        require(0 < expected_size <= 100 * 1024 * 1024, "source size limit")
        raw = source.read(expected_size + 1)
        after = os.fstat(source.fileno())
        require((before.st_size, before.st_mtime_ns, before.st_ctime_ns) ==
                (after.st_size, after.st_mtime_ns, after.st_ctime_ns), "source changed while reading")
    require(len(raw) == expected_size, "incomplete source read")
    require(hashlib.sha256(raw).hexdigest() == expected_sha, "source SHA256 mismatch")
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        entries = archive.infolist()
        require(len(entries) <= 10000, "ZIP member count limit")
        names = set()
        total = 0
        for info in entries:
            name = info.filename
            parts = name.rstrip("/").split("/")
            require(name and not PurePosixPath(name).is_absolute() and "\\" not in name
                    and ":" not in name and all(part not in ("", ".", "..") for part in parts), "unsafe ZIP path")
            require(name not in names, "duplicate ZIP member")
            names.add(name)
            require(not stat.S_ISLNK(info.external_attr >> 16), "ZIP symlink")
            require(not info.flag_bits & 1, "encrypted ZIP member")
            require(info.file_size <= MAX_MEMBER, "ZIP member size limit")
            total += info.file_size
            require(total <= MAX_TOTAL, "ZIP expanded size limit")
        require(archive.testzip() is None, "ZIP CRC mismatch")
        tables = {}
        for name in FIELDS:
            member = f"content/{name}.json"
            require(member in names, f"missing ZIP member: {member}")
            body = archive.read(member)
            if name in evidence:
                require(hashlib.sha256(body).hexdigest() == evidence[name][1], f"table SHA256 mismatch: {name}")
            tables[name] = decode_table(body, name)
            if name in evidence:
                require(len(tables[name]) == evidence[name][0], f"table count mismatch: {name}")
    definitions = join_definitions(tables)
    definitions["source_sha256"] = expected_sha
    return definitions


def read_owner_zip(path: str | Path) -> dict:
    """Only production entry point: fixed archive and per-table evidence, no override."""
    return _read_archive(Path(path), SOURCE_SIZE, SOURCE_SHA256, EVIDENCE)


# Public official-reference facts, supplied after browser inspection by the
# parent investigation. These are not private rows or a replacement source pack.
OFFICIAL_UPDATE = "https://lineagem.plaync.com/board/update/view?articleId=6a690338065bf16436e45e12"
OFFICIAL_PROBABILITY = "https://probability.plaync.com/lineagem/view?probCategoryId=6a66b3649bb1696f4bf77325"
OFFICIAL_PERCENT = {7: 7, 8: 15, 9: 33}
OFFICIAL_COST_NAMES = {"태고의 구": 1, "신화 연금석": 2}


def official_crosscheck(definitions: dict, entity_id: int, item_names: dict[int, str],
                        already_honed: bool | None = None) -> dict:
    """Cross-check source rows against dated public evidence without executing.

    item_names must come from the owner's verified ItemClass index. This helper
    cannot prove that provenance or the mythic-tier target classification, so
    matching facts never authorize consumption or an effect.
    """
    require(isinstance(item_names, dict), "invalid item name index")
    require(already_honed is None or type(already_honed) is bool, "invalid honing state")
    valid = join_definitions(definitions.get("tables", {}))
    require(_integer(entity_id, 1), "invalid entity")
    entities = [row for row in valid["tables"]["ItemHoningEntity"] if row["ID"] == entity_id]
    require(len(entities) == 1, "unknown entity")
    identity = entities[0]["HoningID"]
    blockers = ["source_target_class_unverified", "item_name_index_provenance_unverified",
                "source_probability_denominator_unconfirmed", "failure_transition_unverified",
                "failure_material_consumption_unverified", "failure_refund_unverified",
                "source_bonus_application_unverified"]
    if already_honed is True:
        blockers.append("already_honed")
    elif already_honed is None:
        blockers.append("existing_honing_state_unverified")
    stages = []
    denominators = []
    for enchant, percent in OFFICIAL_PERCENT.items():
        costs = [row for row in valid["tables"]["ItemHoningCost"]
                 if row["HoningID"] == identity and row["Enchant"] == enchant]
        probabilities = [row for row in valid["tables"]["ItemHoningProbability"]
                         if row["HoningID"] == identity and row["Enchant"] == enchant]
        # Preserve every cost row; two distinct required names must each bind to
        # one source ID. Do not merge duplicate rows or use name-based debits.
        named = [(item_names.get(row["ItemClassID"]), row["Amount"]) for row in costs]
        names_unique = all(sum(name == expected for name in item_names.values()) == 1
                           for expected in OFFICIAL_COST_NAMES)
        cost_match = names_unique and len(named) == 2 and all(
            named.count((name, amount)) == 1 for name, amount in OFFICIAL_COST_NAMES.items())
        if not cost_match:
            blockers.append(f"official_cost_binding_mismatch:{enchant}")
        denominator = None
        if len(probabilities) == 1 and probabilities[0]["Probability"] > 0:
            ratio = Fraction(probabilities[0]["Probability"] * 100, percent)
            if ratio.denominator == 1 and ratio.numerator <= MAX_INTEGER:
                denominator = ratio.numerator
        if denominator is None:
            blockers.append(f"probability_scale_not_reconciled:{enchant}")
        denominators.append(denominator)
        stages.append({"enchant": enchant, "official_success_percent": percent,
                       "source_probability_rows": copy.deepcopy(probabilities),
                       "source_cost_rows": copy.deepcopy(costs), "costs_match_official": cost_match})
    common_scale = denominators[0] if None not in denominators and len(set(denominators)) == 1 else None
    if common_scale is None:
        blockers.append("no_common_probability_scale")
    return {"execution_enabled": False, "references": [OFFICIAL_UPDATE, OFFICIAL_PROBABILITY],
            "scope": "mythic_tier_1_weapons_only", "stages": stages,
            "official_required_materials": copy.deepcopy(OFFICIAL_COST_NAMES),
            "official_success": {"epithet": "태고의", "damage_increase_percent": 5},
            "candidate_probability_denominator": common_scale,
            "denominator_evidence": "inferred_by_exact_crosscheck_not_source_storage_confirmation",
            "blockers": blockers}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-zip", required=True)
    args = parser.parse_args()
    try:
        definitions = read_owner_zip(args.source_zip)
    except (OSError, SourceError, zipfile.BadZipFile, RuntimeError) as exc:
        parser.exit(1, f"Honing source rejected: {exc}\n")
    print(json.dumps({"source_sha256": definitions["source_sha256"],
                      "counts": {key: len(value) for key, value in definitions["tables"].items()},
                      "execution_enabled": False}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
