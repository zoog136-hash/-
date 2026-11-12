#!/usr/bin/env python3
"""Audit supplied current523 SPR attachment declarations without changing game data.

Outputs are private normalized evidence, not a runtime activation registry. Header
aliases are graph edges, never an instruction to inherit shadow/clothes/attributes.
The separate metadata projection applies the bounded restored525 loader contracts
(last101/104, first105) and explicitly does not claim native523/Android execution.
No images, sprites, frame durations, coordinates or missing source values are made.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from copy import deepcopy
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import zipfile
from typing import Any

HEADER = re.compile(rb"^[ \t]*#([0-9]+)[ \t]+([0-9]+)(?:=([0-9]+))?")
ANY_HEADER = re.compile(rb"^[ \t]*#")
DIRECTIVE = re.compile(rb"(?<![A-Za-z0-9_.])([0-9]+)\.([^()\r\n]*?)\(([^()]*)\)")
INTEGER = re.compile(rb"-?[0-9]+")
OPEN_DIRECTIVE = re.compile(rb"(?<![A-Za-z0-9_.])(101|102|104|105)\.([A-Za-z_][^()\r\n]*?)\(([^()\r\n]*)$")
SP2_NAME = re.compile(r"^Sprite/([0-9]+)-([0-9]+)\.sp2$")
KINDS = {101: "shadow", 102: "type", 104: "attribute", 105: "clothes"}
FRAME_TOKEN = re.compile(rb"(?<![0-9.])([0-9]+)\.([0-9]+):(-?[0-9]+)")
PROJECTION = "restored525_bounded_loader_contract_projected_to523_source_not_native_execution"
TABLE_ARCHIVE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def text(raw: bytes) -> str:
    # SPR numeric syntax is ASCII; cp949 preserves its original human labels.
    return raw.decode("cp949", errors="strict")


def parse_spr_bytes(raw: bytes, source_file: str, identity: dict | None = None) -> dict:
    """Preserve literal statements, target order/multiplicity and byte positions."""
    source_hash = sha256(raw)
    source = {"source_file": source_file, "bytes": len(raw), "sha256": source_hash,
              "sha1": hashlib.sha1(raw).hexdigest(), "identity": identity or {}}
    result = {"source": source, "declarations": [], "directives": [], "instances": [],
              "aliases": [], "conditional_effects": [], "orphan_directives": [], "issues": [], "directive_code_counts": {}}
    current = None
    cursor = 0
    code_counts = Counter()
    def record_orphans(content: bytes, line_number: int, cursor: int) -> None:
        candidate = re.match(rb"^[ \t]*#([0-9]+)", content)
        for match in DIRECTIVE.finditer(content):
            code = int(match[1])
            if code not in KINDS:
                continue
            result["orphan_directives"].append({"code":code,"kind":KINDS[code],
                "source_sprite_id":None,"candidate_header_sprite_id":int(candidate[1]) if candidate else None,
                "raw_body":text(match[3]),"source_file":source_file,"source_line":line_number,
                "source_byte_offset":cursor+match.start(),"source_byte_length":match.end()-match.start(),
                "source_sha256":source_hash,"syntax_status":"unbound_owner_header_not_parsed"})
    for line_number, line in enumerate(raw.splitlines(keepends=True), 1):
        content = line.rstrip(b"\r\n")
        begin_scan = 0
        if ANY_HEADER.match(content):
            if current is not None:
                current["source_end_byte_offset"] = cursor
                current["declaration_sha256"] = sha256(raw[current["source_byte_offset"]:cursor])
            current = None
            header = HEADER.match(content)
            if header is None:
                result["issues"].append({"kind": "unparsed_header", "source_file": source_file,
                    "source_line": line_number, "source_byte_offset": cursor, "raw_header": text(content)})
                record_orphans(content, line_number, cursor)
                cursor += len(line)
                continue
            sprite_id = int(header[1])
            begin = cursor + len(content) - len(content.lstrip(b" \t"))
            key = f"{source_file}:B{begin}:S{sprite_id}"
            tail = content[header.end():]
            separated = not tail or tail[:1] in b" \t"
            current = {"declaration_key": key, "source_sprite_id": sprite_id,
                "header_number": int(header[2]), "alias_target": int(header[3]) if header[3] else None,
                "source_file": source_file, "source_line": line_number,
                "source_byte_offset": begin, "source_end_byte_offset": None,
                "source_sha256": source_hash, "declaration_sha256": None,
                "header_status": "valid" if separated else "nonstandard_tail_separator",
                "directive_keys": []}
            result["declarations"].append(current)
            if not separated:
                result["issues"].append({"kind": "nonstandard_header_tail", "declaration_key": key,
                    "source_file": source_file, "source_line": line_number, "source_byte_offset": begin})
            if header[3]:
                equal = content.index(b"=", header.start(2), header.end())
                result["aliases"].append({"alias_key": key + ":alias", "declaration_key": key,
                    "source_sprite_id": sprite_id, "target_id": int(header[3]),
                    "source_file": source_file, "source_line": line_number,
                    "source_byte_offset": cursor + equal, "source_byte_length": len(header[3]) + 1,
                    "source_sha256": source_hash, "semantics": "literal_header_alias_no_metadata_inheritance"})
            begin_scan = header.end()
        if current is None:
            record_orphans(content, line_number, cursor)
        if current is not None:
            closed_matches = list(DIRECTIVE.finditer(content, begin_scan))
            matches = [(match, True) for match in closed_matches]
            for match in OPEN_DIRECTIVE.finditer(content, begin_scan):
                if not any(closed.start() <= match.start() < closed.end() for closed in closed_matches):
                    matches.append((match, False))
            for match, closed in sorted(matches, key=lambda pair:pair[0].start()):
                code = int(match[1])
                code_counts[code] += 1
                body = match[3]
                frame_tokens = list(FRAME_TOKEN.finditer(body))
                suffixes = list(re.finditer(rb"\](-?[0-9]+)", body))
                if body.count(b"]") != len(suffixes):
                    result["issues"].append({"kind":"unparsed_direct_effect_suffix", "source_file":source_file,
                        "source_line":line_number, "source_byte_offset":cursor + match.start(3),
                        "source_sprite_id":current["source_sprite_id"], "action_code":code})
                for suffix in suffixes:
                    preceding = [i for i, token in enumerate(frame_tokens) if token.end() <= suffix.start()]
                    target_raw = int(suffix[1])
                    signed_target = ((target_raw + 32768) % 65536) - 32768
                    result["conditional_effects"].append({
                        "suffix_key":f"{source_file}:B{cursor + match.start(3) + suffix.start()}:direct_effect",
                        "declaration_key":current["declaration_key"], "source_sprite_id":current["source_sprite_id"],
                        "action_code":code, "literal_token_ordinal":preceding[-1] if preceding else None,
                        "operator":"]", "operand_raw":target_raw, "target_id":signed_target,
                        "source_file":source_file, "source_line":line_number,
                        "source_byte_offset":cursor + match.start(3) + suffix.start(),
                        "source_byte_length":suffix.end() - suffix.start(), "source_sha256":source_hash,
                        "semantics":"restored525_conditional_direct_SPR_effect_not_persistent_follow_layer",
                        "native_activation_verified":False})
                if code not in KINDS:
                    continue
                tokens = body.split()
                values = [int(token) for token in tokens if INTEGER.fullmatch(token)]
                integers_only = bool(tokens) and len(values) == len(tokens)
                valid = closed and integers_only and ((code in (101, 102, 104) and len(values) == 1) or
                    (code == 105 and values[0] >= 0 and values[0] == len(values) - 1))
                directive_key = f"{source_file}:B{cursor + match.start()}:C{code}"
                row = {"directive_key": directive_key, "declaration_key": current["declaration_key"],
                    "source_sprite_id": current["source_sprite_id"], "code": code, "kind": KINDS[code],
                    "source_label": text(match[2]).strip(), "raw_body": text(body),
                    "integer_values": values, "syntax_status": "valid" if valid else "invalid",
                    "syntax_error": None if valid else ("unclosed_parenthesis" if not closed else "invalid_integer_count_or_shape"),
                    "target_count_declared": (values[0] if values and code == 105 else (1 if code == 101 else None)),
                    "source_file": source_file, "source_line": line_number,
                    "source_byte_offset": cursor + match.start(), "source_byte_length": match.end() - match.start(),
                    "body_byte_offset": cursor + match.start(3), "source_sha256": source_hash,
                    "instance_keys": []}
                current["directive_keys"].append(directive_key)
                result["directives"].append(row)
                if not valid:
                    result["issues"].append({"kind": "invalid_directive_syntax", "directive_key": directive_key,
                        "source_sprite_id": current["source_sprite_id"], "code": code,
                        "source_file": source_file, "source_line": line_number,
                        "source_byte_offset": row["source_byte_offset"]})
                if code not in (101, 105):
                    continue
                # Candidate numbers in malformed bodies stay diagnostic. They are
                # never admitted to the exact reference graph or loader projection.
                number_matches = list(re.finditer(rb"\S+", body))
                for target_index, number in enumerate(number_matches[1:] if code == 105 else number_matches):
                    token = number.group()
                    if INTEGER.fullmatch(token) is None:
                        continue
                    target_id = int(token)
                    instance_key = directive_key + f":T{target_index}"
                    status = "valid" if valid and 0 <= target_id <= 65535 else "invalid"
                    instance = {"instance_key": instance_key, "directive_key": directive_key,
                        "declaration_key": current["declaration_key"], "source_sprite_id": current["source_sprite_id"],
                        "target_index": target_index, "target_id": target_id, "kind": KINDS[code],
                        "syntax_status": status, "source_file": source_file, "source_line": line_number,
                        "source_byte_offset": cursor + match.start(3) + number.start(),
                        "source_byte_length": len(token), "source_sha256": source_hash,
                        "zero_request_id": target_id == 0, "native_activation_verified": False}
                    result["instances"].append(instance)
                    row["instance_keys"].append(instance_key)
        cursor += len(line)
    if current is not None:
        current["source_end_byte_offset"] = len(raw)
        current["declaration_sha256"] = sha256(raw[current["source_byte_offset"]:])
    result["directive_code_counts"] = {str(k): v for k, v in sorted(code_counts.items())}
    return result


def _metadata_projection(directives: list[dict]) -> list[dict]:
    by_owner = defaultdict(list)
    for row in directives:
        by_owner[row["source_sprite_id"]].append(row)
    projections = []
    for sprite_id, rows in sorted(by_owner.items()):
        attr = [r for r in rows if r["code"] == 104]
        shadow = [r for r in rows if r["code"] == 101]
        clothes = [r for r in rows if r["code"] == 105]
        last_attr = attr[-1] if attr else None
        last_shadow = shadow[-1] if shadow else None
        first_clothes = clothes[0] if clothes else None
        selected = [r for r in (last_attr, last_shadow, first_clothes) if r is not None]
        malformed = any(r["syntax_status"] != "valid" for r in selected)
        attr_value = None if last_attr and last_attr["syntax_status"] != "valid" else ((last_attr["integer_values"][0] & 511) if last_attr else 0)
        shadow_value = None if last_shadow and last_shadow["syntax_status"] != "valid" else ((last_shadow["integer_values"][0] & 32767) if last_shadow else 0)
        targets = None if first_clothes and first_clothes["syntax_status"] != "valid" else (first_clothes["integer_values"][1:] if first_clothes else [])
        projections.append({"source_sprite_id": sprite_id, "projection_status": "invalid_source_syntax" if malformed else "defined_static_projection",
            "contract": PROJECTION, "source_order": "numeric_list_file_then_original_byte_order",
            "cross_file_directives": len({r["source_file"] for r in rows}) > 1,
            "attr_low9": attr_value, "last104directive": last_attr["directive_key"] if last_attr else None,
            "shadow_id": shadow_value, "last101directive": last_shadow["directive_key"] if last_shadow else None,
            "clothes_targets": targets, "first105directive": first_clothes["directive_key"] if first_clothes else None,
            "statement_counts": {"101": len(shadow), "104": len(attr), "105": len(clothes)},
            "inactive_later105_directives": [r["directive_key"] for r in clothes[1:]],
            "inherited_from_header_alias": False, "native523_execution_verified": False})
    return projections


def build_inventory(parsed_sources: list[dict], roots: list[dict], members: list[dict] | None = None) -> dict:
    """Return normalized tables, with no Cartesian root × edge expansion."""
    ordered = sorted(parsed_sources, key=lambda p: int(re.search(r"list_([0-9]+)\.spr$", p["source"]["source_file"])[1]))
    result = {name: [deepcopy(r) for p in ordered for r in p[name]] for name in
              ("declarations", "directives", "instances", "aliases", "conditional_effects", "orphan_directives", "issues")}
    result["sources"] = [p["source"] for p in ordered]
    result["roots"] = sorted(roots, key=lambda r: (str(r.get("category", "")), str(r.get("table", "")), str(r.get("row_id", "")), str(r.get("field", "")), r["source_sprite_id"]))
    by_id = defaultdict(list)
    for row in result["declarations"]:
        by_id[row["source_sprite_id"]].append(row)
    for sprite_id, declarations in sorted(by_id.items()):
        if len(declarations) > 1:
            result["issues"].append({"kind": "duplicate_sprite_declarations", "source_sprite_id": sprite_id,
                "declaration_keys": [r["declaration_key"] for r in declarations]})
    directives = {r["directive_key"]: r for r in result["directives"]}
    graph = defaultdict(set)
    for alias in result["aliases"]:
        graph[alias["source_sprite_id"]].add(alias["target_id"])
        chain = [alias["source_sprite_id"]]
        target = alias["target_id"]
        status = "resolved_source_chain"
        while True:
            chain.append(target)
            if target in chain[:-1]:
                status = "cycle"
                break
            candidates = by_id.get(target, [])
            if len(candidates) != 1:
                status = "missing_declaration" if not candidates else "ambiguous_declaration"
                break
            if candidates[0]["alias_target"] is None:
                break
            target = candidates[0]["alias_target"]
        alias["declared_chain"] = chain
        alias["chain_status"] = status
        if status != "resolved_source_chain":
            result["issues"].append({"kind": "alias_" + status, "alias_key": alias["alias_key"], "chain": chain})
    member_index = defaultdict(list)
    normalized_members = []
    for member in members or []:
        match = SP2_NAME.fullmatch(str(member.get("member", "")))
        if match is None:
            raise ValueError("Member is not an explicit SP2 filename: " + str(member.get("member")))
        sprite_id, suffix = map(int, match.groups())
        if member.get("source_sprite_id", sprite_id) != sprite_id:
            raise ValueError("SP2 source_sprite_id disagrees with its literal filename")
        row = {**member, "source_sprite_id": sprite_id, "suffix": suffix}
        normalized_members.append(row)
        member_index[sprite_id].append(row)
    result["members"] = sorted(normalized_members, key=lambda r: (r["source_sprite_id"], r["suffix"]))
    for instance in result["instances"]:
        target = instance["target_id"]
        instance["target_declaration_keys"] = [r["declaration_key"] for r in by_id.get(target, [])]
        instance["physical_member_count"] = len(member_index.get(target, [])) if members is not None else None
        instance["physical_status"] = ("not_supplied" if members is None else ("present_in_supplied_member_universe" if member_index.get(target) else "absent_from_supplied_member_universe"))
        if instance["syntax_status"] == "valid" and target > 0:
            graph[instance["source_sprite_id"]].add(target)
    conditional_graph = defaultdict(set, {key:set(value) for key,value in graph.items()})
    for effect in result["conditional_effects"]:
        target = effect["target_id"]
        effect["target_declaration_keys"] = [r["declaration_key"] for r in by_id.get(target, [])]
        effect["physical_member_count"] = len(member_index.get(target, [])) if members is not None else None
        if target > 0:
            conditional_graph[effect["source_sprite_id"]].add(target)
    projection = _metadata_projection(result["directives"])
    # Declared sprites without any 101/104/105 still have their own zero/default
    # metadata; aliases do not copy the target's metadata into this row.
    projected_ids = {r["source_sprite_id"] for r in projection}
    for sprite_id in sorted(set(by_id) - projected_ids):
        projection.append({"source_sprite_id": sprite_id, "projection_status": "defined_static_projection",
            "contract": PROJECTION, "source_order": "numeric_list_file_then_original_byte_order",
            "cross_file_directives": False, "attr_low9": 0, "last104directive": None,
            "shadow_id": 0, "last101directive": None, "clothes_targets": [], "first105directive": None,
            "statement_counts": {"101": 0, "104": 0, "105": 0}, "inactive_later105_directives": [],
            "inherited_from_header_alias": False, "native523_execution_verified": False})
    result["metadata_projection"] = sorted(projection, key=lambda r: r["source_sprite_id"])
    # One topology row per literal relationship, with instance keys retaining
    # order/multiplicity in their own table. Never expand every root × edge.
    edge_groups = defaultdict(list)
    for row in result["aliases"]:
        edge_groups[(row["source_sprite_id"], "header_alias", row["target_id"])].append(row["alias_key"])
    for row in result["instances"]:
        if row["syntax_status"] == "valid" and row["target_id"] > 0:
            edge_groups[(row["source_sprite_id"], row["kind"], row["target_id"])].append(row["instance_key"])
    for row in result["conditional_effects"]:
        if row["target_id"] > 0:
            edge_groups[(row["source_sprite_id"], "conditional_direct_effect", row["target_id"])].append(row["suffix_key"])
    result["edges"] = [{"edge_key":f"{kind}:{source}:{target}", "source_sprite_id":source,
        "target_id":target, "kind":kind, "source_instance_keys":keys,
        "conditional":kind == "conditional_direct_effect",
        "semantics":"declared_source_relationship_not_an_active_runtime_binding"}
        for (source,kind,target),keys in sorted(edge_groups.items())]
    categories = defaultdict(set)
    for root in roots:
        if type(root.get("source_sprite_id")) is not int or root["source_sprite_id"] <= 0:
            raise ValueError("Roots must preserve only positive, explicit SPR references")
        categories[str(root["category"])].add(root["source_sprite_id"])
    categories["ALL_SUPPLIED_CHARACTER_ROOTS"] = {r["source_sprite_id"] for r in roots}
    scopes = []
    for category, root_ids in sorted(categories.items()):
        seen = set(root_ids)
        stack = sorted(root_ids)
        while stack:
            for target in sorted(graph[stack.pop()]):
                if target not in seen:
                    seen.add(target)
                    stack.append(target)
        conditional_seen = set(root_ids)
        conditional_stack = sorted(root_ids)
        while conditional_stack:
            for target in sorted(conditional_graph[conditional_stack.pop()]):
                if target not in conditional_seen:
                    conditional_seen.add(target)
                    conditional_stack.append(target)
        conditional_effects = [r for r in result["conditional_effects"] if r["source_sprite_id"] in conditional_seen]
        own_directives = [r for r in result["directives"] if r["source_sprite_id"] in seen]
        instances = [r for r in result["instances"] if r["source_sprite_id"] in seen]
        target_ids = {r["target_id"] for r in instances if r["syntax_status"] == "valid" and r["target_id"] > 0}
        scopes.append({"category": category, "root_count": len(root_ids), "root_ids": sorted(root_ids),
            "reachable_source_sprite_ids": sorted(seen), "reachable_count": len(seen),
            "missing_declaration_ids": sorted(seen - by_id.keys()),
            "attachment_statement_counts": dict(sorted(Counter(str(r["code"]) for r in own_directives if r["code"] in (101,105)).items())),
            "ordered_target_instances": len(instances), "distinct_attachment_target_ids": sorted(target_ids),
            "target_ids_without_physical_members": sorted(target_ids - member_index.keys()) if members is not None else None,
            "scope_semantics": "declared_alias_and_exact_attachment_graph_superset_not_native_activation",
            "conditionally_reachable_source_sprite_ids":sorted(conditional_seen),
            "conditional_direct_effect_instances":len(conditional_effects),
            "conditional_direct_effect_target_ids":sorted({r["target_id"] for r in conditional_effects}),
            "runtime_activation_verified": False, "visual_verification": "not_performed_by_this_audit"})
    result["scopes"] = scopes
    counts = Counter(str(r["code"]) for r in result["directives"])
    target_ids = {r["target_id"] for r in result["instances"] if r["syntax_status"] == "valid" and r["target_id"] > 0}
    offsets = result["declarations"] + result["directives"] + result["instances"] + result["aliases"] + result["conditional_effects"] + result["orphan_directives"]
    code_counts = Counter()
    for source in ordered:
        code_counts.update(source["directive_code_counts"])
    result["summary"] = {"schema": "twilight_current523_attachment_source_audit_v1",
        "source_files": len(ordered), "source_bytes": sum(r["bytes"] for r in result["sources"]),
        "declaration_rows": len(result["declarations"]), "distinct_sprite_ids": len(by_id),
        "directive_statement_counts": dict(sorted(counts.items())), "alias_rows": len(result["aliases"]),
        "all_directive_code_counts":dict(sorted(code_counts.items(), key=lambda pair:int(pair[0]))),
        "normalized_relationship_edges":len(result["edges"]),
        "conditional_direct_effect_instances":len(result["conditional_effects"]),
        "conditional_direct_effect_distinct_target_ids":len({r["target_id"] for r in result["conditional_effects"]}),
        "raw_102_values":dict(sorted(Counter(r["raw_body"] for r in result["directives"] if r["code"]==102).items())),
        "target_instances": len(result["instances"]), "distinct_positive_exact_target_ids": len(target_ids),
        "orphan_directive_counts":dict(sorted(Counter(str(r["code"]) for r in result["orphan_directives"]).items())),
        "unclosed_directive_statements":sum(r.get("syntax_error")=="unclosed_parenthesis" for r in result["directives"]),
        "instances_by_syntax_status":dict(sorted(Counter(r["syntax_status"] for r in result["instances"]).items())),
        "invalid_attachment_statements": sum(r["syntax_status"] != "valid" for r in result["directives"] if r["code"] in (101,105)),
        "instances_by_kind": dict(sorted(Counter(r["kind"] for r in result["instances"]).items())),
        "duplicate_sprite_ids": sorted(k for k,v in by_id.items() if len(v)>1),
        "raw_104_values": dict(sorted(Counter(r["raw_body"] for r in result["directives"] if r["code"] == 104).items())),
        "projected_low9_attributes": dict(sorted(Counter(str(r["attr_low9"]) for r in projection).items())),
        "root_occurrences": len(roots), "unique_character_root_ids": len(categories["ALL_SUPPLIED_CHARACTER_ROOTS"]),
        "physical_members_supplied": len(normalized_members) if members is not None else None,
        "target_ids_without_physical_members": sorted(target_ids - member_index.keys()) if members is not None else None,
        "offset_coverage": {"records":len(offsets), "records_with_exact_byte_offset":sum(type(r.get("source_byte_offset")) is int for r in offsets)},
        "issue_counts": dict(sorted(Counter(r["kind"] for r in result["issues"]).items())),
        "limits": ["All-source lexical counts and character-reachable counts have different denominators.",
            "Header aliases never imply inheritance of shadow/clothes/attribute metadata.",
            "Unclosed fragments and unbound-owner directives are retained without fabricating syntax or owner IDs.",
            "Recovered525 first/last loader projection is separate from confirmed523 source bytes.",
            "Multiplicity and malformed declarations are preserved; candidate operands are not invented requests.",
            "Physical presence does not prove a frame request, activation, blend, rendering or Android result.",
            "Literal ] effects have separate conditional reachability and are not persistent parent-following layers."]}
    return result


def verify_root_records(roots: list[dict], tables_zip: Path, expected_archive_sha256: str | None = None) -> dict:
    """Validate supplied explicit roots against actual table bytes, not snippets.

    This proves row/field/source identity; it does not invent a typed consumer or
    activation rule. The curated root projection and its semantic frontier stay
    in root provenance. Provenance path rows must also exist exactly as supplied.
    """
    raw = tables_zip.read_bytes()
    digest = sha256(raw)
    if expected_archive_sha256 is not None and digest != expected_archive_sha256:
        raise ValueError("Current523 table archive identity differs")
    tables = {}
    hashes = {}
    provenance_count = 0
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        def table(name: str) -> list[dict]:
            if name not in tables:
                try:
                    content = archive.read("content/" + name + ".json")
                    rows = json.loads(content)["rows"]
                except (KeyError, TypeError, json.JSONDecodeError) as error:
                    raise ValueError("Missing or invalid source table: " + str(name)) from error
                if not isinstance(rows, list):
                    raise ValueError("Source table rows are not an array: " + str(name))
                tables[name] = rows
                hashes[name] = sha256(content)
            return tables[name]

        def row(proof: dict) -> dict:
            name = proof.get("table")
            if not isinstance(name, str):
                raise ValueError("Root provenance has no explicit source table")
            rows = table(name)
            index = proof.get("row_index")
            if proof.get("table_sha256") != hashes[name] or type(index) is not int or index < 0 or index >= len(rows):
                raise ValueError("Source table hash or row index differs: " + name)
            actual = rows[index]
            if actual.get("ID") != proof.get("row_id"):
                raise ValueError("Source table row ID differs: " + name)
            return actual

        for root in roots:
            actual = row(root)
            field = root.get("field")
            if not isinstance(field, str) or field not in actual or actual[field] != root.get("source_sprite_id"):
                raise ValueError("Explicit root does not equal its original source field")
            for proof in root.get("provenance", {}).get("path", []):
                row(proof)
                provenance_count += 1
    return {"archive_sha256":digest,"archive_bytes":len(raw),"root_records_verified":len(roots),
        "provenance_row_occurrences_verified":provenance_count,"table_sha256":dict(sorted(hashes.items())),
        "scope":"row_field_and_provenance_identity_not_native_activation"}


def _rows_bytes(raw: bytes, name: str) -> list[dict]:
    """Parse one immutable input snapshot so reported hashes bind consumed rows."""
    if name.endswith(".gz"):
        raw = gzip.decompress(raw)
    if name.endswith((".jsonl", ".jsonl.gz")):
        return [json.loads(line) for line in raw.splitlines() if line.strip()]
    value = json.loads(raw)
    if not isinstance(value, list):
        raise ValueError("Expected an explicit JSON array: " + name)
    return value


def load_verified_sources(directory: Path, receipt_path: Path) -> tuple[list[dict], dict]:
    receipt_raw = receipt_path.read_bytes()
    receipt = json.loads(receipt_raw)
    expected_paths = {f"Client/Text/list_{n}.spr" for n in range(30)}
    files = receipt.get("files", [])
    if receipt.get("source_snapshot") != 523 or receipt.get("all_SHA1_size_verified") is not True or {r.get("path") for r in files} != expected_paths or len(files) != 30:
        raise ValueError("A complete, manifest-verified current523 list_0..29 receipt is required")
    parsed = []
    for row in files:
        path = directory / Path(row["path"]).name
        raw = path.read_bytes()
        entry = row.get("current523_entry", {})
        if len(raw) != row["bytes"] or sha256(raw) != row["sha256"] or hashlib.sha1(raw).hexdigest() != row["sha1"]:
            raise ValueError("Local SPR bytes disagree with receipt: " + row["path"])
        if str(entry.get("size")) != str(len(raw)) or entry.get("hash") != row["sha1"] or entry.get("path") != row["path"]:
            raise ValueError("SPR receipt does not match its current523 manifest entry: " + row["path"])
        parsed.append(parse_spr_bytes(raw, row["path"], row))
    return parsed, {"receipt_sha256": sha256(receipt_raw),
        "current_manifest_sha256": receipt.get("current_manifest_sha256"), "local_SPR_bytes_match_receipt_and_manifest_entries": True}


def write_inventory(inventory: dict, output: Path) -> dict:
    output.mkdir(parents=True, exist_ok=True)
    manifest = []
    for name, value in inventory.items():
        path = output / (name + (".json" if isinstance(value, dict) else ".jsonl"))
        if isinstance(value, dict):
            raw = (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode()
        else:
            raw = b"".join((json.dumps(row, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode() for row in value)
        path.write_bytes(raw)
        manifest.append({"path": path.name, "bytes": len(raw), "sha256": sha256(raw)})
    result = {"schema": "private_attachment_source_audit_outputs_v1", "files": manifest}
    (output / "audit-manifest.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spr-directory", required=True, type=Path)
    parser.add_argument("--spr-identities", required=True, type=Path)
    parser.add_argument("--roots", required=True, type=Path)
    parser.add_argument("--tables-zip", required=True, type=Path)
    parser.add_argument("--members", type=Path)
    parser.add_argument("--output", required=True, type=Path, help="Private evidence destination; do not commit source inventories/art")
    args = parser.parse_args()
    parsed, identity = load_verified_sources(args.spr_directory, args.spr_identities)
    roots_raw = args.roots.read_bytes()
    members_raw = args.members.read_bytes() if args.members else None
    roots = _rows_bytes(roots_raw, args.roots.name)
    root_identity = verify_root_records(roots, args.tables_zip, TABLE_ARCHIVE_SHA256)
    inventory = build_inventory(parsed, roots,
        _rows_bytes(members_raw, args.members.name) if members_raw is not None else None)
    inventory["summary"]["root_source_identity"] = root_identity
    inventory["summary"]["source_identity"] = identity
    inventory["summary"]["root_input_sha256"] = sha256(roots_raw)
    inventory["summary"]["member_input_sha256"] = sha256(members_raw) if members_raw is not None else None
    write_inventory(inventory, args.output)
    print(json.dumps(inventory["summary"], ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
