#!/usr/bin/env python3
"""Private source-definition inventory and conservative consumption evidence audit.

This tool never imports a game, changes a save, extracts source rows, or certifies
gameplay. A reviewed ledger supplies semantic evidence; code mentions and parsing
are recorded separately. The report and ledger must remain outside the checkout.
"""

from __future__ import annotations

import argparse
from collections import Counter
import csv
from dataclasses import dataclass, field
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import stat
import sys
import tempfile
from typing import Any
import zipfile


SCHEMA_VERSION = 1
STATUSES = frozenset({
    "used", "partial", "main_unconnected", "other_owner", "excluded", "empty", "unresolved",
})
EVIDENCE_KINDS = frozenset({
    "static_reference", "source_review", "parse", "compile", "install", "fixture",
    "inspection_render", "gameplay",
})
PIPELINE_STAGES = ("parser", "compiler", "runtime_consumer", "caller", "storage")
TABLE_NAME = re.compile(r"[A-Za-z][A-Za-z0-9_]*\Z")
TOKEN = re.compile(r"[A-Za-z][A-Za-z0-9_]*")
MAX_ARCHIVE_MEMBERS = 100_000
MAX_TABLE_BYTES = 128 * 1024 * 1024
MAX_JSON_BYTES = 1024 * 1024 * 1024


class AuditError(ValueError):
    """An ambiguous input or unsupported evidence claim."""


@dataclass(frozen=True)
class Table:
    name: str
    member: str
    rows: int
    json_bytes: int
    compressed_bytes: int
    sha256: str
    fields: tuple[str, ...]
    row_fields: tuple[tuple[str, ...], ...] = field(repr=False, compare=False)

    def report_record(self) -> dict[str, Any]:
        return {
            "table": self.name, "member": self.member, "rows": self.rows,
            "source_json_bytes": self.json_bytes,
            "source_compressed_member_bytes": self.compressed_bytes,
            "source_json_sha256": self.sha256, "field_names": list(self.fields),
        }


def digest_file(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as handle:
        while block := handle.read(1024 * 1024):
            result.update(block)
    return result.hexdigest()


def _plain_integer(value: Any, label: str, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        raise AuditError(f"{label} must be an integer >= {minimum}")
    return value


def _text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise AuditError(f"{label} must be nonempty text")
    return value


def _unique_json(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result = {}
    for key, value in pairs:
        if key in result:
            raise AuditError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def read_json(raw: bytes | str, label: str) -> Any:
    try:
        return json.loads(raw, object_pairs_hook=_unique_json)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise AuditError(f"invalid JSON in {label}") from exc


def inventory_source(source: Path, expected_sha256: str | None = None,
                     expect_tables: int | None = None) -> tuple[str, list[Table]]:
    """Read every definition once; retain metadata only, never raw source rows."""
    source_sha256 = digest_file(source)
    if expected_sha256 is not None and source_sha256 != expected_sha256.lower():
        raise AuditError("source archive SHA256 does not match --expected-sha256")
    tables = []
    seen_members: set[str] = set()
    seen_tables: set[str] = set()
    json_bytes = 0
    archive_bytes = 0
    try:
        with zipfile.ZipFile(source) as archive:
            members = archive.infolist()
            if len(members) > MAX_ARCHIVE_MEMBERS:
                raise AuditError("archive has too many members")
            for member in members:
                name = member.filename
                path = PurePosixPath(name)
                if (not name or "\\" in name or path.is_absolute()
                        or ".." in path.parts or "." in name.split("/")
                        or name.rstrip("/") != path.as_posix()):
                    raise AuditError("archive contains a noncanonical member path")
                if name in seen_members:
                    raise AuditError("archive contains duplicate member names")
                seen_members.add(name)
                if stat.S_ISLNK(member.external_attr >> 16):
                    raise AuditError("archive contains a symbolic link")
                if member.flag_bits & 1:
                    raise AuditError("encrypted archive members are unsupported")
                if member.file_size > MAX_TABLE_BYTES:
                    raise AuditError("archive member exceeds the supported byte limit")
                archive_bytes += member.file_size
                if archive_bytes > MAX_JSON_BYTES:
                    raise AuditError("decompressed archive exceeds the supported byte limit")
                # Validate every member's CRC, including source metadata, without
                # extracting or retaining non-definition payloads.
                with archive.open(member) as handle:
                    while handle.read(1024 * 1024):
                        pass
                if not name.startswith("content/") or member.is_dir():
                    continue
                if len(path.parts) != 2 or path.suffix != ".json":
                    raise AuditError("content/ must contain only direct JSON tables")
                table_name = path.stem
                if not TABLE_NAME.fullmatch(table_name):
                    raise AuditError("unsupported source table name")
                if table_name.casefold() in seen_tables:
                    raise AuditError("archive has ambiguous table names")
                seen_tables.add(table_name.casefold())
                if member.file_size > MAX_TABLE_BYTES:
                    raise AuditError("table exceeds the supported byte limit")
                json_bytes += member.file_size
                if json_bytes > MAX_JSON_BYTES:
                    raise AuditError("source JSON exceeds the supported byte limit")
                raw = archive.read(member)  # zipfile checks this member's CRC.
                payload = read_json(raw, name)
                if (not isinstance(payload, dict) or set(payload) != {"rows"}
                        or not isinstance(payload.get("rows"), list)):
                    raise AuditError(f"{table_name} must contain a rows array")
                rows = payload["rows"]
                if any(not isinstance(row, dict) for row in rows):
                    raise AuditError(f"{table_name} contains a non-object row")
                fields = tuple(sorted({key for row in rows for key in row}))
                patterns: dict[tuple[str, ...], tuple[str, ...]] = {}
                row_fields = tuple(patterns.setdefault(tuple(sorted(row)), tuple(sorted(row))) for row in rows)
                tables.append(Table(
                    table_name, name, len(rows), len(raw), member.compress_size,
                    hashlib.sha256(raw).hexdigest(), fields, row_fields,
                ))
    except (OSError, zipfile.BadZipFile, RuntimeError) as exc:
        raise AuditError("could not read a valid source ZIP") from exc
    if not tables:
        raise AuditError("source ZIP has no content tables")
    if expect_tables is not None and len(tables) != expect_tables:
        raise AuditError("source table count does not match --expect-tables")
    if digest_file(source) != source_sha256:
        raise AuditError("source archive changed while being inventoried")
    return source_sha256, sorted(tables, key=lambda table: table.name)


def verify_source_metadata(source: Path, tables: list[Table]) -> list[str]:
    """Optionally compare bundled counts and hashes with the independently read bytes."""
    verified = []
    by_member = {table.member: table for table in tables}
    with zipfile.ZipFile(source) as archive:
        members = set(archive.namelist())
        if "index.json" in members:
            index = read_json(archive.read("index.json"), "index.json")
            if not isinstance(index, list) or len(index) != len(tables):
                raise AuditError("source index table count mismatch")
            seen = set()
            for record in index:
                if not isinstance(record, dict) or not isinstance(record.get("path"), str):
                    raise AuditError("invalid source index record")
                name = record["path"]
                if name in seen or name not in by_member:
                    raise AuditError("source index has duplicate or unknown tables")
                seen.add(name)
                table = by_member[name]
                if (record.get("bytes") != table.json_bytes or record.get("row_count") != table.rows
                        or record.get("sha256") != table.sha256
                        or sorted(record.get("fields", [])) != list(table.fields)):
                    raise AuditError("source index row, field, byte, or SHA256 mismatch")
            verified.append("index.json")
        if "table_inventory_1065.csv" in members:
            records = list(csv.DictReader(io.StringIO(archive.read("table_inventory_1065.csv").decode("utf-8-sig"))))
            if len(records) != len(tables):
                raise AuditError("source CSV table count mismatch")
            seen = set()
            for record in records:
                name = record.get("path")
                if name in seen or name not in by_member:
                    raise AuditError("source CSV has duplicate or unknown tables")
                seen.add(name)
                table = by_member[name]
                if (record.get("bytes") != str(table.json_bytes) or record.get("row_count") != str(table.rows)
                        or record.get("sha256") != table.sha256):
                    raise AuditError("source CSV row, byte, or SHA256 mismatch")
            verified.append("table_inventory_1065.csv")
        if "summary.json" in members:
            summary = read_json(archive.read("summary.json"), "summary.json")
            if (not isinstance(summary, dict) or summary.get("tables") != len(tables)
                    or summary.get("table_rows") != sum(table.rows for table in tables)
                    or summary.get("raw_bytes") != sum(table.json_bytes for table in tables)):
                raise AuditError("source summary denominator mismatch")
            verified.append("summary.json")
    if not verified:
        raise AuditError("no supported source metadata is available to verify")
    return verified


def gameplay_artifact(entry: dict[str, Any], table: Table, source_sha256: str,
                      repo: Path, callers: list[dict[str, Any]]) -> dict[str, Any]:
    """Validate a retained runtime trace; no inline claim substitutes for it.

    Trace provenance and semantic correctness still require human review. The
    artifact contains source row indices and consumed field names, never values.
    """
    artifact = entry.get("artifact")
    if not isinstance(artifact, dict):
        raise AuditError("gameplay evidence requires a retained runtime artifact")
    path = private_output(Path(_text(artifact.get("path"), "artifact path")), repo, "runtime artifact")
    expected = _text(artifact.get("sha256"), "artifact SHA256")
    if not re.fullmatch(r"[a-f0-9]{64}", expected):
        raise AuditError("invalid runtime artifact SHA256")
    if path.stat().st_size > MAX_TABLE_BYTES:
        raise AuditError("runtime artifact exceeds the supported byte limit")
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != expected:
        raise AuditError("runtime artifact SHA256 mismatch")
    trace = read_json(raw, "runtime artifact")
    if (not isinstance(trace, dict) or type(trace.get("schema_version")) is not int
            or trace.get("schema_version") != SCHEMA_VERSION
            or trace.get("kind") != "gameplay_consumption_trace"
            or trace.get("origin") != "normal_gameplay"
            or trace.get("fixture") is not False or trace.get("inspection_render") is not False):
        raise AuditError("runtime artifact must record normal gameplay without fixtures or inspection rendering")
    if (trace.get("source_sha256") != source_sha256
            or trace.get("source_json_sha256") != table.sha256
            or trace.get("table") != table.name or trace.get("run_id") != entry["run_id"]):
        raise AuditError("runtime artifact does not match the source, table, or gameplay run")
    caller = trace.get("caller")
    if (not isinstance(caller, dict) or not any(
            caller.get("path") == known["path"]
            and not PurePosixPath(known["path"]).parts[0] in {"tests", "tools"}
            and ("symbol" not in known or caller.get("symbol") == known["symbol"])
            for known in callers)):
        raise AuditError("runtime artifact caller must match a reviewed caller path")
    observations = trace.get("observations")
    if not isinstance(observations, list) or not observations:
        raise AuditError("runtime artifact requires actual row and field observations")
    observed: dict[int, set[str]] = {}
    for observation in observations:
        if not isinstance(observation, dict):
            raise AuditError("invalid gameplay observation")
        indices = observation.get("row_indices")
        fields = observation.get("fields")
        if (not isinstance(indices, list) or not indices
                or any(type(index) is not int or index < 0 or index >= table.rows for index in indices)
                or len(indices) != len(set(indices))):
            raise AuditError("invalid observed source row indices")
        if (not isinstance(fields, list) or not fields
                or any(not isinstance(name, str) for name in fields)
                or len(fields) != len(set(fields))):
            raise AuditError("invalid observed source fields")
        for index in indices:
            if set(fields) - set(table.row_fields[index]):
                raise AuditError("runtime artifact observes a field absent from its source row")
            observed.setdefault(index, set()).update(fields)
    return {
        "artifact_sha256": expected,
        "observed_rows": len(observed),
        "observed_fields": sorted({name for names in observed.values() for name in names}),
        "fully_observed_rows": sum(set(table.row_fields[index]) == names for index, names in observed.items()),
    }


def static_candidates(repo: Path, table_names: set[str]) -> dict[str, list[dict[str, Any]]]:
    """Literal discovery only. No candidate changes status or coverage metrics."""
    found: dict[str, list[dict[str, Any]]] = {name: [] for name in table_names}
    for directory in ("scripts", "tools", "tests"):
        root = repo / directory
        if not root.is_dir():
            continue
        for path in sorted(root.rglob("*")):
            if path.suffix not in {".gd", ".py"} or path.is_symlink() or not path.is_file():
                continue
            if not path.resolve().is_relative_to(repo):
                continue
            role = "fixture_or_test" if directory == "tests" else "code_candidate"
            try:
                with path.open(encoding="utf-8") as handle:
                    for number, line in enumerate(handle, 1):
                        for name in set(TOKEN.findall(line)) & table_names:
                            found[name].append({
                                "path": path.relative_to(repo).as_posix(),
                                "line": number, "role": role,
                            })
            except UnicodeError:
                continue
    return found


def _pipeline(value: Any, repo: Path, table_name: str) -> dict[str, list[dict[str, Any]]]:
    if value is None:
        value = {}
    if not isinstance(value, dict) or set(value) - set(PIPELINE_STAGES):
        raise AuditError(f"invalid pipeline stages for {table_name}")
    result = {}
    for stage in PIPELINE_STAGES:
        refs = value.get(stage, [])
        if not isinstance(refs, list):
            raise AuditError(f"{table_name}.{stage} must be a list")
        result[stage] = []
        for ref in refs:
            if not isinstance(ref, dict):
                raise AuditError(f"invalid {table_name}.{stage} reference")
            name = _text(ref.get("path"), "pipeline path")
            path = PurePosixPath(name)
            if path.is_absolute() or ".." in path.parts or "\\" in name:
                raise AuditError("pipeline references must be checkout-relative paths")
            resolved = (repo / name).resolve()
            if not resolved.is_relative_to(repo) or not resolved.is_file():
                raise AuditError(f"pipeline reference does not exist: {name}")
            entry = {"path": name}
            if "line" in ref:
                entry["line"] = _plain_integer(ref["line"], "pipeline line", 1)
            if "symbol" in ref:
                entry["symbol"] = _text(ref["symbol"], "pipeline symbol")
            result[stage].append(entry)
    return result


def validate_ledger(
    ledger: Any, tables: list[Table], source_sha256: str, repo: Path,
) -> dict[str, dict[str, Any]]:
    if ledger is None:
        return {}
    if (not isinstance(ledger, dict) or type(ledger.get("schema_version")) is not int
            or ledger.get("schema_version") != SCHEMA_VERSION):
        raise AuditError("ledger schema_version must be 1")
    if ledger.get("source_sha256") != source_sha256:
        raise AuditError("ledger source SHA256 does not match the source archive")
    records = ledger.get("records")
    if not isinstance(records, list):
        raise AuditError("ledger records must be a list")
    by_name = {table.name: table for table in tables}
    validated: dict[str, dict[str, Any]] = {}
    for record in records:
        if not isinstance(record, dict):
            raise AuditError("ledger record must be an object")
        name = _text(record.get("table"), "table name")
        if name not in by_name:
            raise AuditError(f"ledger references an unknown table: {name}")
        if name in validated:
            raise AuditError(f"ledger contains duplicate table records: {name}")
        table = by_name[name]
        status = _text(record.get("status"), f"{name} status")
        if status not in STATUSES:
            raise AuditError(f"invalid table status for {name}")
        if (status == "empty") != (table.rows == 0):
            raise AuditError(f"empty status must exactly match a zero-row table: {name}")
        item = {
            "status": status,
            "feature": _text(record.get("feature"), f"{name} feature"),
            "owner": _text(record.get("owner"), f"{name} owner"),
            "reason": _text(record.get("reason"), f"{name} reason"),
            "remaining": _text(record.get("remaining"), f"{name} remaining"),
            "pipeline": _pipeline(record.get("pipeline"), repo, name),
        }
        evidence = record.get("evidence", [])
        if not isinstance(evidence, list):
            raise AuditError(f"{name} evidence must be a list")
        item["evidence"] = []
        evidence_ids = set()
        for entry in evidence:
            if (not isinstance(entry, dict) or not isinstance(entry.get("kind"), str)
                    or entry.get("kind") not in EVIDENCE_KINDS):
                raise AuditError(f"invalid evidence kind for {name}")
            evidence_id = _text(entry.get("id"), "evidence id")
            if evidence_id in evidence_ids:
                raise AuditError(f"duplicate evidence id for {name}")
            evidence_ids.add(evidence_id)
            clean = {
                "id": evidence_id, "kind": entry["kind"],
                "reference": _text(entry.get("reference"), "evidence reference"),
                "scope": _text(entry.get("scope"), "evidence scope"),
            }
            if entry["kind"] == "gameplay":
                if entry.get("origin") != "normal_gameplay":
                    raise AuditError("gameplay evidence must exclude fixtures and inspection renders")
                if entry.get("source_json_sha256") != table.sha256:
                    raise AuditError(f"gameplay evidence must pin {name}'s source JSON SHA256")
                clean.update({
                    "origin": "normal_gameplay", "source_json_sha256": table.sha256,
                    "run_id": _text(entry.get("run_id"), "gameplay run_id"),
                })
                clean.update(gameplay_artifact(
                    entry, table, source_sha256, repo, item["pipeline"]["caller"],
                ))
            item["evidence"].append(clean)
        coverage = record.get("coverage")
        item["coverage"] = None
        if coverage is not None:
            if not isinstance(coverage, dict):
                raise AuditError(f"invalid coverage for {name}")
            rows = _plain_integer(coverage.get("rows"), "covered rows")
            if rows > table.rows:
                raise AuditError(f"covered rows exceed source rows for {name}")
            fields = coverage.get("fields")
            if (not isinstance(fields, list) or any(not isinstance(field, str) for field in fields)
                    or len(set(fields)) != len(fields) or set(fields) - set(table.fields)):
                raise AuditError(f"invalid covered fields for {name}")
            evidence_ref = _text(coverage.get("evidence_id"), "coverage evidence_id")
            matching = [entry for entry in item["evidence"] if entry["id"] == evidence_ref]
            if len(matching) != 1 or matching[0]["kind"] != "gameplay":
                raise AuditError("coverage requires normal-gameplay evidence, not loading or fixtures")
            if rows != matching[0]["observed_rows"] or set(fields) != set(matching[0]["observed_fields"]):
                raise AuditError("ledger coverage does not match the retained runtime artifact")
            item["coverage"] = {"rows": rows, "fields": fields, "evidence_id": evidence_ref}
        if status in {"used", "partial"}:
            needed = ("parser", "runtime_consumer", "caller")
            if any(not item["pipeline"][stage] for stage in needed):
                raise AuditError(f"{name} {status} requires parser, runtime consumer, and caller paths")
        if status == "used":
            if (not item["coverage"] or item["coverage"]["rows"] != table.rows
                    or set(item["coverage"]["fields"]) != set(table.fields)):
                raise AuditError("used requires gameplay coverage of every source row and field")
            full = next(entry for entry in item["evidence"]
                        if entry["id"] == item["coverage"]["evidence_id"])
            if full["scope"] != "all_rows_all_fields":
                raise AuditError("used requires an explicit all_rows_all_fields gameplay attestation")
            if full["fully_observed_rows"] != table.rows:
                raise AuditError("used requires every field of every row in the runtime artifact")
        if status == "excluded" and not any(e["kind"] == "source_review" for e in item["evidence"]):
            raise AuditError("excluded requires reviewed exclusion evidence")
        validated[name] = item
    return validated


def build_report(
    source_sha256: str, tables: list[Table], ledger: Any, repo: Path,
    *, scan_static: bool = True,
) -> dict[str, Any]:
    repo = repo.resolve()
    records = validate_ledger(ledger, tables, source_sha256, repo)
    candidates = static_candidates(repo, {table.name for table in tables}) if scan_static else {}
    entries = []
    stages = Counter()
    for table in tables:
        entry = table.report_record()
        record = records.get(table.name)
        if record is None:
            record = {
                "status": "empty" if table.rows == 0 else "unresolved",
                "feature": "unreviewed", "owner": "unassigned_or_unconfirmed",
                "reason": "No reviewed semantic evidence supplied.",
                "remaining": "Review compiler, runtime caller, ownership, and storage contracts.",
                "pipeline": {stage: [] for stage in PIPELINE_STAGES},
                "evidence": [], "coverage": None,
            }
        entry.update(record)
        entry["static_candidates"] = candidates.get(table.name, [])
        entries.append(entry)
        for kind in {evidence["kind"] for evidence in record["evidence"]}:
            stages[kind] += 1
    status_counts = Counter(entry["status"] for entry in entries)
    status_bytes = Counter()
    for entry in entries:
        status_bytes[entry["status"]] += entry["source_json_bytes"]
    full = [entry for entry in entries if entry["status"] == "used"]
    partial = [entry for entry in entries if entry["status"] == "partial"]
    source_bytes = sum(table.json_bytes for table in tables)
    full_bytes = sum(entry["source_json_bytes"] for entry in full)
    return {
        "schema_version": SCHEMA_VERSION,
        "classification": "private_audit_metadata_do_not_publish",
        "source_sha256": source_sha256,
        "denominators": {
            "content_tables": len(tables), "source_rows": sum(table.rows for table in tables),
            "source_uncompressed_json_bytes": source_bytes,
            "exclusions_removed_from_denominators": False,
        },
        "metrics": {
            "status_table_counts": {status: status_counts[status] for status in sorted(STATUSES)},
            "status_source_json_bytes": {status: status_bytes[status] for status in sorted(STATUSES)},
            "evidence_stage_table_counts": dict(sorted(stages.items())),
            "fully_consumed_tables_with_reviewed_gameplay_attestation": len(full),
            "fully_consumed_table_fraction": len(full) / len(tables),
            "fully_consumed_tables_source_json_bytes": full_bytes,
            "fully_consumed_tables_source_json_byte_fraction": full_bytes / source_bytes if source_bytes else 0,
            "partial_tables": len(partial),
            "partial_table_source_bytes_counted_as_fully_consumed": 0,
            "actual_gameplay_consumed_byte_extents": None,
            "reviewed_ledger_attests_95_percent": len(full) / len(tables) >= 0.95
                and (full_bytes / source_bytes if source_bytes else 0) >= 0.95,
        },
        "limitations": [
            "Semantic evidence is supplied by reviewed retained runtime artifacts; this tool validates contracts, not their semantic truth.",
            "Static references, loading, compilation, installation, fixtures, and inspection renders do not prove gameplay use.",
            "Full-table byte fractions attribute exact original JSON file sizes only to completely attested tables.",
            "Partial row or field usage has no inferred byte coverage; actual consumed byte extents remain unknown.",
            "Excluded and empty tables remain in the fixed original denominator; generated cache and archive bytes are separate.",
        ],
        "tables": entries,
    }


def private_output(path: Path, repo: Path, label: str) -> Path:
    path = path.resolve()
    if path.is_relative_to(repo.resolve()):
        raise AuditError(f"{label} must remain outside the checkout")
    # A sibling checkout is also a public-output hazard.
    if any((parent / ".git").is_file() or (parent / ".git" / "HEAD").is_file()
           for parent in path.parents):
        raise AuditError(f"{label} cannot be inside another Git checkout")
    return path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path, help="private original source ZIP")
    parser.add_argument("--repo", required=True, type=Path, help="checkout used for code evidence")
    parser.add_argument("--ledger", type=Path, help="private reviewed semantic evidence JSON")
    parser.add_argument("--output", type=Path, help="private report; default is beside source ZIP")
    parser.add_argument("--no-static-scan", action="store_true")
    parser.add_argument("--expected-sha256", help="pin the exact original source archive SHA256")
    parser.add_argument("--expect-tables", type=int, help="pin the source table denominator")
    parser.add_argument("--verify-metadata", action="store_true", help="compare bundled index/CSV/summary with independent counts")
    args = parser.parse_args(argv)
    try:
        repo = args.repo.resolve()
        if not repo.is_dir():
            raise AuditError("repo must be an existing directory")
        if args.expected_sha256 is not None and not re.fullmatch(r"[a-fA-F0-9]{64}", args.expected_sha256):
            raise AuditError("--expected-sha256 must be a 64-digit hexadecimal digest")
        if args.expect_tables is not None and args.expect_tables < 1:
            raise AuditError("--expect-tables must be positive")
        output = private_output(args.output or args.source.parent / "content-consumption-audit523.json", repo, "report")
        if args.ledger:
            ledger_path = private_output(args.ledger, repo, "ledger")
            ledger = read_json(ledger_path.read_bytes(), "ledger")
        else:
            ledger = None
        inputs = [args.source.resolve()] + ([ledger_path] if args.ledger else [])
        # Runtime traces are immutable audit inputs too. Protect direct paths,
        # symlinks, and hardlinks before opening a report destination for writing.
        if isinstance(ledger, dict) and isinstance(ledger.get("records"), list):
            for record in ledger["records"]:
                evidence = record.get("evidence") if isinstance(record, dict) else None
                if not isinstance(evidence, list):
                    continue
                for entry in evidence:
                    artifact = entry.get("artifact") if isinstance(entry, dict) else None
                    if isinstance(artifact, dict) and isinstance(artifact.get("path"), str):
                        inputs.append(Path(artifact["path"]).resolve())
        if any(output == value or (output.exists() and output.samefile(value)) for value in inputs):
            raise AuditError("report cannot overwrite source, ledger, or runtime trace inputs, including file aliases")
        source_sha256, tables = inventory_source(args.source, args.expected_sha256, args.expect_tables)
        report = build_report(source_sha256, tables, ledger, repo, scan_static=not args.no_static_scan)
        report["source_member_crc_validation"] = "all_members_passed"
        report["source_metadata_validation"] = verify_source_metadata(args.source, tables) if args.verify_metadata else []
        output.parent.mkdir(parents=True, exist_ok=True)
        # Avoid leaving a partially written report if a write fails.
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=output.parent,
                                             prefix=output.name + ".", suffix=".tmp", delete=False) as handle:
                temporary = Path(handle.name)
                handle.write(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
            temporary.replace(output)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
        print(json.dumps({"denominators": report["denominators"], "metrics": report["metrics"]}, ensure_ascii=False))
        return 0
    except (AuditError, OSError) as exc:
        print(f"consumption audit failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
