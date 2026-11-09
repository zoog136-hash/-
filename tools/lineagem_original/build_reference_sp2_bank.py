#!/usr/bin/env python3
"""Plan and compile an explicit current523 source-action bank, never install it.

The metadata handoff can plan addresses without original bytes. Use --plan-only
for that operation. Compilation separately requires complete original SPR files
and exact SP2 files; no pixels, FPS, directions, gameplay roles or native dispatch
are inferred. Outputs contain third-party originals and belong outside this repo.

Requests are JSONL(.gz): actor_id, action_id, action_key, target_members,
selection_semantics. --spr-root contains original list_*.spr filenames;
--original-root contains the exact Sprite/*.sp2 namespace. Dependencies absent
from the handoff require --dependency-index with explicit current523 identities.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from dataclasses import replace
import gzip
import hashlib
import copy
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
import zlib

import original_spr
import build_current523_identity_pack as identity


INVENTORY = "current523_sp2_all54384_action_inventory.jsonl.gz"
ACTIONS = "current523_sp2_action_source_index.jsonl.gz"
DECLARATIONS = "current523_sp2_declaration_raw_index.jsonl.gz"
HANDOFF = "current523_sp2_metadata_handoff_manifest.json"
MEMBER = re.compile(r"Sprite/[0-9]+-[0-9]+\.sp2\Z")
SHA = re.compile(r"[0-9a-f]{64}\Z")
CRC = re.compile(r"[0-9a-f]{8}\Z")
DUMMY_LITERAL = re.compile(r"(?<![A-Za-z])dummy(?![A-Za-z])|더미", re.IGNORECASE)
DUMMY_EXCLUSION_POLICY = "source_literal_dummy_declarations_only;project_inactive_dummy_edges;preserve_originals_and_normal_shared_members"
REFERENCE_INSTANCE_POLICY = "ordered_literal_edges_shared_frame_bindings_native_draw_multiplicity_unverified"
CONTRACT = {
    "format": "current523_identity_roles_v1",
    "selection": "explicit_source_actor_id_and_source_action_id",
    "loop": "unknown_requires_explicit_caller_policy",
    "timing": "source_explicit_fps_and_duration_ticks_only",
    "layer_policy": identity.LAYER_POLICY,
    "native_dispatch_verified": False,
    "installed_in_main_this_run": False,
    "pixels_or_composition_verified": False,
}


def consumer_contract(allow_host_timing=False, client_default_fps=False):
    contract = dict(CONTRACT)
    if client_default_fps:
        contract.update(timing="source_explicit_or_client_section_default", client_section_default_fps=original_spr.CLIENT_SECTION_DEFAULT_FPS,
                        client_default_evidence=original_spr.CLIENT_DEFAULT_EVIDENCE)
    if allow_host_timing:
        contract.update(timing="source_explicit_or_existing_host_policy", host_timing_opt_in=True,
                        source_fps_policy="preserve_literal_value_including_null")
    return contract


def literal_dummy_declaration(line, source_file, source_line, source_sha256):
    scan = line.lstrip()
    header = original_spr.HEADER.match(scan)
    if header is None:
        return None
    name = scan[header.end():].strip()
    inline = original_spr.ACTION.search(name)
    if inline is not None:
        name = name[:inline.start()].strip()  # An action named dummy is not an actor dummy label.
    literal = DUMMY_LITERAL.search(name)
    if literal is None:
        return None
    return {"sprite_id": int(header[1]), "literal_name": name, "literal_declaration": line,
            "matched_literal": literal[0], "source_file": source_name(source_file),
            "source_line": source_line, "source_sha256": source_sha256}


def source_dummy_declarations(paths, spr_proofs):
    """Read literal declaration names only; do not infer from files or pixels."""
    result = defaultdict(list)
    for path in paths:
        for number, line in enumerate(Path(path).read_bytes().decode("cp949").splitlines(), 1):
            row = literal_dummy_declaration(line, Path(path).name, number, spr_proofs[Path(path).name]["sha256"])
            if row is not None:
                result[row["sprite_id"]].append(row)
    return dict(result)


def metadata_dummy_declarations(metadata):
    result = defaultdict(list)
    for declaration in metadata["declarations"]:
        text = declaration.get("raw_declaration_text", "")
        if not text:
            continue
        row = literal_dummy_declaration(text.splitlines()[0], declaration["source_file"],
                                        declaration["source_line"], declaration["source_file_sha256"])
        if row is not None:
            result[row["sprite_id"]].append(row)
    return dict(result)


def source_dummy_alias_path(sprite_id, declarations, dummy):
    path, hits, seen = [], [], set()
    current = sprite_id
    while current not in seen:
        seen.add(current)
        matches = declarations.get(current, [])
        if len(matches) != 1:
            break  # Keep unrelated declaration ambiguity as its existing blocker.
        path.append(current)
        hits.extend(dummy.get(current, []))
        target = matches[0].alias_target
        if target is None:
            break
        current = target
    return {"sprite_ids":path,"dummy_declarations":hits,"resolved_source_endpoint":path[-1] if path else None,
            "normal_endpoint_globally_excluded":False} if hits else None


def source_dummy_registry(dummy):
    return {"sprite:"+str(sprite_id):{"source_snapshot":"patch523","reason":"source_literal_dummy",
        "dummy_declarations":rows,"source_graph_paths":[{"kind":"source_declared_root","sprite_ids":[sprite_id]}],
        "originals_preserved":True,"raw_member_namespace_excluded":False} for sprite_id,rows in sorted(dummy.items())}


def require(value, detail):
    if not value:
        raise ValueError(detail)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def records(path):
    opener = gzip.open if str(path).endswith(".gz") else open
    with opener(path, "rt", encoding="utf-8") as stream:
        for number, line in enumerate(stream, 1):
            if line.strip():
                value = json.loads(line)
                require(isinstance(value, dict), f"{path}:{number}: expected object")
                yield value


def request_records(path, body):
    """Parse the exact request bytes whose digest is recorded for this run."""
    if str(path).endswith(".gz"):
        body = gzip.decompress(body)
    for number, line in enumerate(body.decode("utf-8").splitlines(), 1):
        if line.strip():
            value = json.loads(line)
            require(isinstance(value, dict), f"{path}:{number}: expected object")
            yield value


def member_name(value):
    require(isinstance(value, str) and MEMBER.fullmatch(value), f"invalid exact SP2 member: {value!r}")
    return value


def source_name(value):
    require(isinstance(value, str) and "\\" not in value, "invalid SPR source path")
    path = PurePosixPath(value)
    require(not path.is_absolute() and ".." not in path.parts and path.suffix == ".spr", "invalid SPR source path")
    return path.name


def integer(value, label):
    require(type(value) is int and value >= 0, f"invalid {label}: {value!r}")
    return value


def digest_evidence(row):
    value = row.get("original_member_sha256_evidence")
    if isinstance(value, dict):
        value = value.get("sha256")
    value = value or row.get("sha256")
    require(value is None or isinstance(value, str) and SHA.fullmatch(value), "invalid original member SHA256")
    return value


def check_identity(row, external=False):
    member_name(row.get("member"))
    integer(row.get("bytes"), "original byte count")
    require(isinstance(row.get("crc32"), str) and CRC.fullmatch(row["crc32"]), "invalid original CRC32")
    archive = row.get("archive") or row.get("container")
    require(isinstance(archive, str) and bool(archive), "missing original archive/container identity")
    digest_evidence(row)
    if external:
        require(row.get("source_snapshot") in ("current523", "patch523"), "dependency is not an explicit current523 identity")
        require(digest_evidence(row) is not None and bool(row.get("identity_evidence")),
                "external dependency requires original SHA256 and identity_evidence")


def verified_metadata(directory):
    """Verify every handoff member before using its declared source provenance."""
    manifest = json.loads((directory / HANDOFF).read_text(encoding="utf-8"))
    seen = set()
    for row in manifest["members"]:
        name = row["name"]
        require(isinstance(name, str) and PurePosixPath(name).name == name and name not in seen,
                "unsafe/duplicate handoff member")
        seen.add(name)
        data = (directory / name).read_bytes()
        require(len(data) == row["bytes"] and sha(data) == row["sha256"], f"metadata member changed: {name}")
    require({INVENTORY, ACTIONS, DECLARATIONS} <= seen, "incomplete metadata handoff")
    # The original handoff fixed its denominators in code. A generated complete
    # client handoff (client523_bank_metadata.py) declares them explicitly; the
    # loader still requires the declared counts to match exactly.
    expected = manifest.get("expected_counts", {"inventory_members": 54384, "target_members": 45990})
    require(type(expected.get("inventory_members")) is int and type(expected.get("target_members")) is int,
            "invalid handoff expected_counts")
    return {"manifest_sha256": sha((directory / HANDOFF).read_bytes()),
            "members": {row["name"]: row["sha256"] for row in manifest["members"]},
            "expected_counts": dict(expected), "generator": manifest.get("generator")}


def load_metadata(directory, dependency_index=None):
    proof = verified_metadata(directory)
    inventory = {}
    for row in records(directory / INVENTORY):
        check_identity(row)
        require(row["member"] not in inventory, "duplicate handoff member identity")
        inventory[row["member"]] = row
    expected = proof["expected_counts"]
    require(len(inventory) == expected["inventory_members"],
            f"expected complete{expected['inventory_members']} handoff inventory")
    targets = {name for name, row in inventory.items() if row.get("source_family_categories")}
    require(len(targets) == expected["target_members"],
            f"expected complete{expected['target_members']} source-family targets")
    identities = dict(inventory)
    if dependency_index is not None:
        for row in records(dependency_index):
            check_identity(row, external=True)
            require(row["member"] not in identities, "duplicate/conflicting dependency member identity")
            identities[row["member"]] = row
        proof["dependency_index_sha256"] = sha(dependency_index.read_bytes())
    actions, sources = {}, {}
    for row in records(directory / ACTIONS):
        key = row["action_key"]
        require(key not in actions, "duplicate source action key")
        actions[key] = row
        _source_proof(sources, row)
    declarations = list(records(directory / DECLARATIONS))
    for row in declarations:
        _source_proof(sources, row)
    family_roots, related, family_evidence = defaultdict(set), defaultdict(set), defaultdict(list)
    contexts = {row["source_owner_key"]: row for row in records(directory / "current523_sp2_actor_dependency_context.jsonl.gz")}
    for row in records(directory / "current523_sp2_category_root_evidence.jsonl.gz"):
        root = integer(row["sprite_id"], "table SPR root")
        key = f"table:{row['category']}:{root}"
        family_roots[root].add(key)
        family_evidence[root].append({"evidence_key": key, "kind": "explicit_table_SPR_root", "record": row})
    for context in contexts.values():
        if context.get("explicit_table_contexts"):
            root = integer(context["source_declaration_sprite_id"], "owner-context SPR root")
            key = "owner:" + context["source_owner_key"]
            family_roots[root].add(key)
            family_evidence[root].append({"evidence_key": key, "kind": "explicit_source_owner_context", "record": context})
    for member in targets:
        context = contexts.get(inventory[member].get("source_owner_context_key"), {})
        owner = context.get("source_declaration_sprite_id")
        if owner in family_roots:
            related[owner].add(member)
        for item in context.get("explicit_table_contexts", []):
            related[item["table_referenced_SPR_id"]].add(member)
    return {"inventory": inventory, "targets": targets, "identities": identities,
            "actions": actions, "declarations": declarations, "sources": sources, "proof": proof,
            "family_roots": dict(family_roots), "family_related_targets": dict(related),
            "family_evidence": dict(family_evidence)}


def _source_proof(sources, row):
    name = source_name(row["source_file"])
    expected = row["source_file_sha256"]
    require(isinstance(expected, str) and SHA.fullmatch(expected), "invalid original SPR SHA256")
    require(name not in sources or sources[name]["sha256"] == expected, "conflicting SPR source SHA256")
    sources[name] = {"source_file": row["source_file"], "sha256": expected}


def metadata_declarations(metadata):
    """Only a planning model; it never stands in for full original SPR bytes."""
    result = defaultdict(list)
    for row in metadata["declarations"]:
        # The actual SPR reader resets its current declaration at an invalid
        # header. Such metadata remains in the source ledger, not in this AST.
        if row.get("header_valid", True) is not True:
            continue
        declaration = original_spr.Declaration(row["sprite_id"], row.get("alias_target"),
                                               source_name(row["source_file"]), row["source_line"])
        for key in row["animation_action_keys"]:
            action = metadata["actions"][key]
            code = action["action_id"]
            errors = list(action["parse_issues"])
            if code in declaration.actions:
                errors.append("duplicate action")
            declaration.actions[code] = {"code": code, "name": action["action_name_literal"],
                "fps": action["explicit_fps"], "tokens": [tuple(token) for token in action["source_tokens_selector_frame_ticks"]],
                "raw_body": action["raw_body"], "source_file": source_name(action["source_file"]),
                "source_line": action["source_line"], "fps_provenance": action.get("fps_source"),
                "declared_flag": action["declared_flag"], "errors": errors,
                "source_annotations": action.get("opaque_token_annotations", []), "metadata_action_key": key}
        references = [(reference, False) for reference in row.get("explicit_layer_references", [])]
        references.extend((reference, True) for reference in row.get("reference_issues", []))
        references.sort(key=lambda item: item[0].get("source_line", 0))
        for reference, source_issue in references:
            raw = reference["raw"]
            match = original_spr.ACTION.fullmatch(raw.strip())
            require(match is not None, f"invalid metadata layer reference {raw!r}")
            code, body = int(match[1]), match[3]
            values = list(map(int, re.findall(r"-?\d+", body)))
            count_valid = code != 105 or bool(values) and values[0] == len(values) - 1
            targets = values[1:] if code == 105 else values
            if not source_issue:
                require(targets == reference["targets"], "metadata layer targets differ from raw source")
            kind = {101: "shadow", 105: "clothes"}.get(code, "unresolved_source_reference")
            declaration.references.append({"kind": kind, "targets": targets,
                                           "raw": body, "count_valid": count_valid})
        result[declaration.sprite_id].append(declaration)
    return dict(result)


def verified_declarations(metadata, root, source_inputs=None, section_default_fps=None):
    require(root is not None, "complete original SPR files unavailable (--spr-root required)")
    root = root.resolve()
    paths, verified, missing = [], {}, {}
    for name, proof in sorted(metadata["sources"].items()):
        path = root / name
        require(not path.is_symlink(), f"original SPR symlink rejected: {proof['source_file']}")
        if not path.exists():
            missing[name] = proof
            continue
        require(path.is_file(), f"original SPR unavailable: {proof['source_file']}")
        require(path.resolve().is_relative_to(root), "SPR source escapes supplied root")
        body = path.read_bytes()
        require(sha(body) == proof["sha256"], f"complete original SPR SHA256 mismatch: {proof['source_file']}")
        verified[name] = {**proof, "bytes": len(body)}
        paths.append(path)
    if source_inputs is not None:
        source_inputs.update(expected_count=len(metadata["sources"]), verified_count=len(verified),
                             verified=verified, missing=missing)
    require(paths, "original SPR unavailable: no complete source file verified")
    declarations = original_spr.read(paths, section_default_fps)
    for path in paths:
        require(sha(path.read_bytes()) == metadata["sources"][path.name]["sha256"],
                f"original SPR changed while reading: {path.name}")
    return declarations


def requests_from(path, targets, body=None):
    requests = {}
    for row in request_records(path, path.read_bytes() if body is None else body):
        actor = integer(row.get("actor_id"), "actor ID")
        action = integer(row.get("action_id"), "action ID")
        key = row.get("action_key")
        require(isinstance(key, str) and bool(key), "request requires exact source action_key")
        members = row.get("target_members")
        require(isinstance(members, list) and bool(members), "request requires exact target_members")
        members = sorted({member_name(name) for name in members})
        require(set(members) <= targets, "request target is outside the complete target denominator")
        require("selection_semantics" in row, "request must preserve selection_semantics")
        identity_key = (actor, action)
        if identity_key in requests:
            existing = requests[identity_key]
            require(existing["action_key"] == key and existing["selection_semantics"] == row["selection_semantics"],
                    "conflicting duplicate actor/action request")
            existing["target_members"] = sorted(set(existing["target_members"]) | set(members))
        else:
            requests[identity_key] = {"actor_id": actor, "action_id": action, "action_key": key,
                                      "target_members": members, "selection_semantics": row["selection_semantics"]}
    return [requests[key] for key in sorted(requests)]


def _matching_action(action, source):
    return (action["code"] == source["action_id"]
            and action["source_file"] == source_name(source["source_file"])
            and action["source_line"] == source["source_line"]
            and action["raw_body"] == source["raw_body"]
            and action["declared_flag"] == source["declared_flag"]
            and action["tokens"] == [tuple(token) for token in source["source_tokens_selector_frame_ticks"]]
            and action["fps"] == source["explicit_fps"])


def expanded_requests(seeds, declarations, metadata, failures, statistics):
    """Discover only literal emitted addresses under the existing reader contract.

    FPS, historical frame evidence and SP2 identity availability are deliberately
    checked later. They cannot hide a source parent whose body is outside the
    difference inventory. Failed layer contracts establish family context only.
    """
    pending = {(row["actor_id"], row["action_id"]): row for row in seeds}
    roots = metadata.get("family_roots", {})
    statistics["explicit_source_root_ids"] = len(roots)

    def failed(root, action_id, key, error):
        failure = {"failure_key": f"sprite:{root}/action:{action_id}", "actor_id": root,
                   "action_id": action_id, "action_key": key, "reason": str(error),
                   "source_evidence_keys": sorted(roots[root]),
                   "related_family_target_members": sorted(metadata.get("family_related_targets", {}).get(root, set())),
                   "file_action_usage_proven": False,
                   "scope": "explicit family relationship only; failed reader contract is not an emitted file/action link"}
        if key in metadata["actions"]:
            source = metadata["actions"][key]
            failure["raw_source_action"] = source.get("action_raw", source["raw_body"])
            failure["source_file_sha256"] = source["source_file_sha256"]
        failures.append(failure)

    for root_index, root in enumerate(sorted(roots), 1):
        if root_index % 1000 == 0:
            print(f"REFERENCE_SP2_SOURCE_SCAN roots={root_index}/{len(roots)} "
                  f"actions={statistics['effective_source_actions_examined']} "
                  f"derived={statistics['derived_source_actions']} failures={len(failures)}", file=sys.stderr, flush=True)
        try:
            _, actions = original_spr.resolve(declarations, root)
        except (ValueError, KeyError) as error:
            statistics["source_root_resolution_failures"] += 1
            failed(root, None, None, error)
            continue
        for action_id, source in sorted(actions.items()):
            statistics["effective_source_actions_examined"] += 1
            key = source.get("metadata_action_key")
            try:
                require(key in metadata["actions"], "effective source action lacks exact metadata key")
                role = "source_action:" + str(action_id)
                prepared = identity.build_actor(root, declarations, metadata["sources"], ((role, action_id),))
            except (ValueError, KeyError) as error:
                statistics["unsupported_source_action_contracts"] += 1
                failed(root, action_id, key, error)
                continue
            emitted = prepared[1] & metadata["targets"]
            if not emitted:
                statistics["source_actions_without_target_addresses"] += 1
                continue
            statistics["source_actions_with_target_addresses"] += 1
            seed = pending.pop((root, action_id), None)
            if seed is not None and seed["action_key"] != key:
                failed(root, action_id, key, "seed action key conflicts with unique effective source action")
                pending[(root, action_id)] = seed
                continue
            statistics["expanded_seed_actions" if seed is not None else "derived_source_actions"] += 1
            request = {"actor_id": root, "action_id": action_id, "action_key": key,
                       "target_members": sorted(emitted | (set(seed["target_members"]) if seed else set())),
                       "seed_target_members": list(seed["target_members"]) if seed else [],
                       "selection_semantics": seed["selection_semantics"] if seed else "exact_source_action_id_only_no_gameplay_role_inferred",
                       "source_selection_evidence": {"kind": "complete_explicit_source_family_expansion",
                           "source_evidence_keys": sorted(roots[root]), "source_address_contract": "existing_build_actor",
                           "source_explicit_fps": source["fps"],
                           "positive_explicit_source_fps": type(source["fps"]) is int and source["fps"] > 0,
                           "required_member_identity_gaps": sorted(prepared[1] - metadata["identities"].keys()),
                           "reader_required_members": sorted(prepared[1]),
                           "checked_before_fps_or_dependency_identity_rejection": True,
                           "native_dispatch_verified": False}}
            yield request, prepared
    for pair in sorted(pending):
        seed = pending[pair]
        yield {**seed, "seed_target_members": list(seed["target_members"])}, None


MISSING_LAYER_POLICY = "client_omits_non_body_layer_without_client_file"


def omit_missing_layers(actor, members, proof, identities):
    """Drop shadow/clothes layers whose SP2 files the client itself does not ship.

    The client loads each layer by file name and draws nothing for an absent
    file; the body is never dropped. A layer identity (kind, sprite) is removed
    from the whole action when any of its addressed files is absent, so every
    frame keeps the same layer list the runtime requires; for clothes the
    client keeps only the prefix before the first missing entry.
    """
    absent = members - identities.keys()
    if not absent:
        return actor, members, proof, []
    dropped, clothes_order = set(), []
    for track in actor["roles"].values():
        for frames in track["directions"]:
            for frame in frames:
                for layer in frame["layers"]:
                    identity_key = (layer["kind"], layer["source_sprite_id"])
                    if layer["kind"] == "clothes" and identity_key not in clothes_order:
                        clothes_order.append(identity_key)
                    if layer["member"] in absent:
                        require(layer["kind"] != "body", f"dependency identity unavailable: body file absent from client {layer['member']}")
                        dropped.add(identity_key)
    # Clothes are built in list order and the client stops at the first null,
    # keeping only the successful prefix (LineageM 1.10.22.0 aux-layer analysis).
    first_missing = next((index for index, key in enumerate(clothes_order) if key in dropped), None)
    if first_missing is not None:
        dropped.update(clothes_order[first_missing:])
    actor = copy.deepcopy(actor)
    kept = set()
    for track in actor["roles"].values():
        for frames in track["directions"]:
            for frame in frames:
                frame["layers"] = [layer for layer in frame["layers"] if (layer["kind"], layer["source_sprite_id"]) not in dropped]
                kept.update(layer["member"] for layer in frame["layers"])
    proof = copy.deepcopy(proof)
    proof["declarations"] = [layer for layer in proof["declarations"]
                             if (layer["kind"], layer["declaration_path"][-1]["sprite_id"]) not in dropped]
    omitted = [{"kind": kind, "source_sprite_id": sprite, "policy": MISSING_LAYER_POLICY,
                "absent_files": sorted(m for m in absent if m.startswith(f"Sprite/{sprite}-"))}
               for kind, sprite in sorted(dropped)]
    proof["omitted_missing_layers"] = omitted
    return actor, kept, proof, omitted


def plan_action(request, declarations, metadata, prepared=None, allow_host_timing=False, omit_missing=False):
    dummy = metadata.get("dummy_declarations", {})
    require(source_dummy_alias_path(request["actor_id"], declarations, dummy) is None,
            "source_literal_dummy: explicit source declaration/alias path excluded by user")
    source = metadata["actions"].get(request["action_key"])
    require(source is not None, "unknown exact source action key")
    require(source["action_id"] == request["action_id"], "request source action ID mismatch")
    _, actions = original_spr.resolve(declarations, request["actor_id"])
    action = actions.get(request["action_id"])
    require(action is not None and _matching_action(action, source), "effective alias/override source action differs from request")
    require(type(action["fps"]) is int and action["fps"] > 0 or allow_host_timing and action["fps"] is None,
            "no positive explicit source FPS; timing cannot be invented")
    require(not action["errors"], f"source action errors: {action['errors']}")
    role = "source_action:" + str(request["action_id"])
    actor, members, proof = prepared if prepared is not None else identity.build_actor(
        request["actor_id"], declarations, metadata["sources"], ((role, request["action_id"]),))
    for layer in proof["declarations"]:
        require(not any(item["sprite_id"] in dummy for item in layer["declaration_path"]),
                "source_literal_dummy: explicit required source layer excluded by user")
    # build_actor's default loop policy belongs to named TWILIGHT roles. A raw
    # action number carries no loop/one-shot or gameplay event meaning.
    actor["roles"][role]["loop"] = None
    require(set(request["target_members"]) <= members, "requested target is not emitted by this exact action/layer contract")
    if omit_missing:
        actor, members, proof, _ = omit_missing_layers(actor, members, proof, metadata["identities"])
        require(set(request["target_members"]) <= members, "requested target belongs only to an omitted absent layer")
    unknown = sorted(members - metadata["identities"].keys())
    require(not unknown, f"dependency identity unavailable: {unknown}")
    return actor, members, proof


def saved_address_issues(actor, identities):
    issues, seen = [], set()
    for track in actor["roles"].values():
        for frames in track["directions"]:
            for frame in frames:
                for layer in frame["layers"]:
                    key = (layer["member"], layer["group_bit"], layer["frame_index"])
                    if key in seen:
                        continue
                    seen.add(key)
                    evidence = identities[layer["member"]].get("saved_SP2_frame_evidence") or {}
                    bits = evidence.get("stored_direction_bits")
                    counts = evidence.get("stored_frame_counts")
                    if not isinstance(bits, list) or not isinstance(counts, list) or len(bits) != len(counts):
                        continue  # Actual compilation must still validate the real SP2.
                    require(len(set(bits)) == len(bits) and all(type(bit) is int and 0 <= bit < 8 for bit in bits)
                            and all(type(count) is int and count >= 0 for count in counts),
                            "invalid saved direction/frame evidence")
                    available = dict(zip(bits, counts))
                    if layer["group_bit"] not in available:
                        issues.append({"member": key[0], "group_bit": key[1], "frame_index": key[2], "issue": "stored_direction_absent"})
                    elif key[2] >= available[key[1]]:
                        issues.append({"member": key[0], "group_bit": key[1], "frame_index": key[2], "issue": "stored_frame_out_of_range"})
    return issues


def source_layer_declarations(proof, declarations):
    """Retain literal attributes along each verified alias path; infer no inheritance."""
    result = []
    for layer in proof["declarations"]:
        path = []
        for source in layer["declaration_path"]:
            matches = declarations.get(source["sprite_id"], [])
            require(len(matches) == 1, "ambiguous actual source layer declaration")
            declaration = matches[0]
            require(declaration.source_file == source["source_file"]
                    and declaration.source_line == source["source_line"], "actual layer declaration differs from source proof")
            path.append({**source, "literal_attribute_directives": [dict(directive) for directive in declaration.directives
                                                                     if directive["code"] == 104]})
        result.append({"kind": layer["kind"], "source_sprite_id": path[-1]["sprite_id"],
                       "declaration_path": path,
                       "attribute_inheritance": "direct_declaration" if len(path) == 1 else "alias_path_unverified"})
    return result


def project_independent_source_layers(root_id, action_id, declarations, spr_proofs, excluded_dummy=None):
    """Separate explicit child-owned actions; retain literal references as evidence.

    The projection is only an input to the existing address compiler. Source
    declaration bytes/directives are unchanged. Independent edges are returned
    separately and must compile the child under its own exact source clock.
    """
    projected = dict(declarations)
    independent, excluded_edges, visited = [], [], {}
    reference_instances, bindings = [], {}
    excluded_dummy = excluded_dummy or {}

    def origin(sprite_id, kind, raw, reference_index=0, seen=()):
        require(sprite_id not in seen, f"SPR reference alias cycle {seen + (sprite_id,)}")
        matches = declarations.get(sprite_id, [])
        require(len(matches) == 1, f"{sprite_id}: ambiguous source reference declaration")
        declaration = matches[0]
        own = [ref for ref in declaration.references if ref["kind"] == kind]
        if own:
            code = {"shadow": 101, "clothes": 105}[kind]
            names = ("shadow",) if kind == "shadow" else ("clothes", "clothe")
            directives = [(index,item) for index,item in enumerate(declaration.directives)
                          if item["code"] == code and item["name"].lower() in names]
            require(reference_index < len(directives), f"{sprite_id}: literal source reference directive unavailable")
            directive_index,directive = directives[reference_index]
            require(directive["body"] == raw, f"{sprite_id}: source reference order differs from declaration")
            return {"sprite_id": sprite_id, "source_file": declaration.source_file,
                    "source_line": directive["line"], "source_sha256": spr_proofs[declaration.source_file]["sha256"],
                    "code": code, "name": directive["name"], "body": raw,
                    "source_directive_index":directive_index,"source_reference_index":reference_index}
        require(declaration.alias_target is not None, f"{sprite_id}: source reference origin unavailable")
        return origin(declaration.alias_target, kind, raw, reference_index, seen + (sprite_id,))

    def attach(sprite_id, parent_action, edge_path, seen=()):
        require(sprite_id not in seen, f"SPR source layer cycle {seen + (sprite_id,)}")
        references = original_spr.resolve_references(declarations, sprite_id)
        projected_refs, separated = [], False
        for kind, refs in references.items():
            require(kind in ("shadow", "clothes"), f"unknown SPR layer kind {kind}")
            for reference_index,reference in enumerate(refs):
                require(reference["count_valid"], f"invalid layer target count {sprite_id}")
                retained = []
                for target_index,target in enumerate(reference["targets"]):
                    dummy_path = source_dummy_alias_path(target, declarations, excluded_dummy)
                    if dummy_path is not None:
                        separated = True
                        edge = {"from_sprite_id":sprite_id,"target_sprite_id":target,"kind":kind,"source_reference":reference["raw"]}
                        excluded_edges.append({**edge,"reason":"source_literal_dummy","source_edge_path":edge_path+[edge],
                            "source_declaration":origin(sprite_id,kind,reference["raw"],reference_index),"excluded_alias_path":dummy_path,
                            "originals_preserved":True,"normal_parent_connection_preserved":True})
                        continue
                    edge_key = (sprite_id, kind, target)
                    context = tuple((edge["from_sprite_id"],edge["kind"],edge["target_sprite_id"]) for edge in edge_path)
                    declaration = origin(sprite_id,kind,reference["raw"],reference_index)
                    instance_id = (f"ref:{root_id}:{sprite_id}:{kind}:{declaration['source_file']}:"
                                   f"L{declaration['source_line']}:D{declaration['source_directive_index']}:T{target_index}")
                    prior = visited.get(edge_key)
                    if prior is not None:
                        require(prior["context"] == context and prior["source_reference"] == reference["raw"],
                                f"nonidentical or converging SPR reference context remains unresolved: {edge_key}")
                        binding = prior
                        separated = True
                    else:
                        binding = {"binding_id":f"binding:{root_id}:{sprite_id}:{kind}:{target}:A{action_id}",
                            "context":context,"source_reference":reference["raw"],"reference_instance_ids":[],
                            "kind":kind,"target_sprite_id":target,
                            "physical_source_sprite_id":original_spr.resolve(declarations,target)[0]}
                        visited[edge_key] = binding
                        bindings[binding["binding_id"]] = binding
                    binding["reference_instance_ids"].append(instance_id)
                    reference_instances.append({"instance_id":instance_id,"binding_id":binding["binding_id"],
                        "from_sprite_id":sprite_id,"target_sprite_id":target,"kind":kind,
                        "source_reference":reference["raw"],"source_declaration":declaration,"target_index":target_index,
                        "source_edge_path":edge_path+[{"from_sprite_id":sprite_id,"target_sprite_id":target,
                            "kind":kind,"source_reference":reference["raw"]}],
                        "canonical_instance_id":binding["reference_instance_ids"][0],
                        "connection_stage":"ordered_literal_instance_shared_source_binding",
                        "native_reference_multiplicity_verified":False})
                    if prior is not None:
                        continue  # Preserve the occurrence, not an invented second image/compositing call.
                    _, target_actions = original_spr.resolve(declarations, target)
                    own = target_actions.get(action_id)
                    edge = {"from_sprite_id": sprite_id, "target_sprite_id": target,
                            "kind": kind, "source_reference": reference["raw"]}
                    if own is not None:
                        require(not own["errors"], f"invalid child-owned source action {target}/{action_id}: {own['errors']}")
                    differs = own is not None and (own["tokens"] != parent_action["tokens"]
                        or own["declared_flag"] != parent_action["declared_flag"]
                        or own["fps"] not in (None, parent_action["fps"]))
                    if differs:
                        separated = True
                        independent.append({**edge, "source_edge_path": edge_path + [edge],
                            "source_declaration": declaration,"source_binding_id":binding["binding_id"],
                            "reference_instance_ids":binding["reference_instance_ids"],
                            "parent_action_id": action_id, "child_action_id": action_id,
                            "child_action_source": {key: own[key] for key in ("source_file", "source_line", "raw_body", "fps")},
                            "dispatch_policy": "host_parent_role_starts_child_own_source_action_native_dispatch_unverified",
                            "native_dispatch_verified": False})
                    else:
                        retained.append(target)
                        attach(target, own if own is not None else parent_action, edge_path + [edge], seen + (sprite_id,))
                projected_refs.append({**reference, "targets": retained})
        if separated:
            declaration = declarations[sprite_id][0]
            projected[sprite_id] = [replace(declaration, references=projected_refs)]

    _, actions = original_spr.resolve(declarations, root_id)
    require(action_id in actions and not actions[action_id]["errors"], f"absent/invalid source action {root_id}/{action_id}")
    attach(root_id, actions[action_id], [])
    reference_instances.sort(key=lambda item:(str(item["source_edge_path"][:-1]),item["source_declaration"]["source_file"],
        item["source_declaration"]["source_directive_index"],item["target_index"]))
    return projected, independent, excluded_edges, reference_instances, list(bindings.values())


def construct_source_graph(root_id, action_id, declarations, spr_proofs, action_key_for,
                           allow_host_timing=False, ancestors=(), excluded_dummy=None):
    """Compile explicit source nodes with child-owned clocks, without raw validation."""
    require(root_id not in ancestors, f"independent SPR source graph cycle {ancestors + (root_id,)}")
    excluded_dummy = excluded_dummy or {}
    require(source_dummy_alias_path(root_id,declarations,excluded_dummy) is None,
            "source_literal_dummy: explicit source declaration/alias path excluded by user")
    projected, edges, dummy_edges, reference_instances, bindings = project_independent_source_layers(root_id, action_id, declarations, spr_proofs, excluded_dummy)
    role = "source_action:" + str(action_id)
    actor, required, proof = identity.build_actor(root_id, projected, spr_proofs, ((role, action_id),))
    fps = actor["roles"][role]["fps"]
    require(type(fps) is int and fps > 0 or allow_host_timing and fps is None,
            "no positive explicit source FPS; timing cannot be invented")
    actor["roles"][role]["loop"] = None
    bound_layers = defaultdict(list)
    for binding in bindings:
        bound_layers[(binding["kind"],binding["physical_source_sprite_id"])].append(binding)
    for frames in actor["roles"][role]["directions"]:
        for frame in frames:
            for layer in frame["layers"]:
                matches = bound_layers.get((layer["kind"],layer["source_sprite_id"]),[])
                if len(matches) == 1:
                    layer.update(source_binding_id=matches[0]["binding_id"],
                                 reference_instance_ids=list(matches[0]["reference_instance_ids"]))
    members, records, independent = set(required), {}, []
    for edge in edges:
        child_id = edge["target_sprite_id"]
        child = construct_source_graph(child_id, action_id, declarations, spr_proofs, action_key_for,
                                       allow_host_timing, ancestors + (root_id,), excluded_dummy)
        members.update(child["members"])
        records.update(child["records"])
        independent.append({**edge, "child_actor_key": "sprite:" + str(child_id),
                            "child_source_action_key": action_key_for(child_id, action_id),
                            "child_action_path": f"actors/{child_id}/action-{action_id}.json",
                            "source_origin_policy": "original_source_origin_no_inferred_attachment_offset"})
    contract = consumer_contract(allow_host_timing)
    proof["source_reference_projection"] = "synchronized_edges_in_frame_layers;independent_edges_retained_as_explicit_child_records"
    dummy_projection_applied = bool(dummy_edges) or any(item.get("user_dummy_exclusions_applied") for item in records.values())
    compact = identity.compact_roles(actor, proof)
    for item,layer in zip(compact[role]["layers"],actor["roles"][role]["directions"][0][0]["layers"]):
        if "source_binding_id" in layer:
            item.update(source_binding_id=layer["source_binding_id"],reference_instance_ids=layer["reference_instance_ids"])
    record = {"schema": 1, "source_snapshot": "patch523", "consumer_contract": contract,
              "actor": actor, "compact_roles": compact, "source_proof": proof,
              "source_reference_instances":reference_instances,"source_reference_instance_policy":REFERENCE_INSTANCE_POLICY,
              "source_layer_declarations": source_layer_declarations(proof, declarations),
              "independent_source_layers": independent,
              "excluded_dummy_source_edges": dummy_edges,
              "source_layer_graph_complete_before_user_exclusions": not dummy_projection_applied,
              "user_dummy_exclusions_applied": dummy_projection_applied,
              "independent_source_layers_opt_in": True,
              "independent_layer_policy": "explicit_source_relation_same_action_id_child_own_clock_host_dispatch_unverified",
              "action_key": action_key_for(root_id, action_id),
              "selection_semantics": "explicit_source_action_and_declared_layer_relationship_only_native_dispatch_unverified",
              "compilation_validation": "not_repeated_per_user_instruction", "actual_main_game_feature_use": False}
    records[(root_id, action_id)] = record
    return {"record": record, "records": records, "members": members}


def verified_raw(root, members, identities):
    require(root is not None, "original SP2 bytes unavailable (--original-root required)")
    root = root.resolve()
    raw = {}
    for member in sorted(members):
        row = identities[member]
        path = root / member
        require(path.is_file() and not path.is_symlink(), f"original SP2 unavailable: {member}")
        require(path.resolve().is_relative_to(root), f"original SP2 escapes supplied root: {member}")
        body = path.read_bytes()
        digest = sha(body)
        require(len(body) == row["bytes"] and f"{zlib.crc32(body) & 0xffffffff:08x}" == row["crc32"],
                f"original SP2 size/CRC mismatch: {member}")
        expected = digest_evidence(row)
        require(expected is None or digest == expected, f"original SP2 SHA256 mismatch: {member}")
        raw[member] = {"body": body, "proof": {"member": member, "archive": row.get("archive"), "container": row.get("container"),
            "bytes": len(body), "crc32": row["crc32"], "sha256": digest,
            "expected_original_sha256": expected,
            "identity_basis": "size_crc_and_expected_sha256" if expected else "size_crc_with_newly_observed_sha256"}}
    return raw


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def write_file(output, name, body):
    target = output / name
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with target.open("xb") as stream:
        stream.write(body)
    target.chmod(0o600)


def link_file(output, name, source, body):
    """Hard-link a verified original instead of copying it (same filesystem only)."""
    target = output / name
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    require(source.read_bytes() == body, f"original changed before linking: {name}")
    try:
        os.link(source, target)
    except OSError as error:
        raise ValueError(f"--link-raw needs the output on the same filesystem as --original-root: {error}") from error


def write_records(output, name, rows):
    data = b"".join(json_bytes(row) for row in rows)
    write_file(output, name, gzip.compress(data, mtime=0) if name.endswith(".gz") else data)


def build(args):
    require(not args.output.exists() and not args.output.is_symlink(), "output must be a new private directory")
    output = args.output.resolve()
    repository = Path(__file__).resolve().parents[2]
    require(not output.is_relative_to(repository), "private bank output must be outside the repository")
    metadata = load_metadata(args.metadata, args.dependency_index)
    metadata["dummy_declarations"] = metadata_dummy_declarations(metadata)
    request_bytes = args.requests.read_bytes()
    request_sha256 = sha(request_bytes)
    seed_requests = requests_from(args.requests, metadata["targets"], request_bytes)
    allow_host_timing = getattr(args, "allow_host_timing", False)
    client_default_fps = getattr(args, "client_section_default_fps", False)
    omit_missing = getattr(args, "client_omit_missing_layers", False)
    require(not (allow_host_timing and client_default_fps), "choose host timing or the client section default, not both")
    timing_policy = "client_section_default_fps_24" if client_default_fps else "source_explicit_only"
    if client_default_fps or metadata["proof"].get("generator"):
        handoff = json.loads((args.metadata / HANDOFF).read_text(encoding="utf-8"))
        require(handoff.get("timing_policy", "source_explicit_only") == timing_policy,
                "metadata handoff timing policy differs from the requested build timing policy")
    contract = consumer_contract(allow_host_timing, client_default_fps)
    if omit_missing:
        contract["missing_layer_policy"] = MISSING_LAYER_POLICY
    original, source_problem, source_inputs = None, None, {}
    if not args.plan_only:
        try:
            original = verified_declarations(metadata, args.spr_root, source_inputs,
                                             original_spr.CLIENT_SECTION_DEFAULT_FPS if client_default_fps else None)
        except (ValueError, OSError) as error:
            source_problem = str(error)
    planning = metadata_declarations(metadata)
    output.mkdir(parents=True, mode=0o700)
    per_member = defaultdict(list)
    action_results, effective_requests, scan_failures, compiled, written_members = [], [], [], {}, {}
    expansion_statistics = Counter()
    parsed = {}
    for request, prepared in expanded_requests(seed_requests, planning, metadata, scan_failures, expansion_statistics):
        effective_requests.append(request)
        result = {**request, "status": "blocked_source_contract", "compiled": False}
        try:
            if not args.plan_only and source_problem is not None:
                result["status"] = "blocked_original_spr_unavailable_or_unverified"
                require(False, source_problem)
            actor, members, proof = plan_action(request, planning, metadata, prepared, allow_host_timing, omit_missing)
            result["required_members"] = sorted(members)
            result["saved_address_issues"] = saved_address_issues(actor, metadata["identities"])
            result["status"] = "blocked_saved_direction_or_frame"
            require(not result["saved_address_issues"], "saved exact direction/frame evidence rejects requested source addresses")
            result["planned_target_members"] = sorted(members & metadata["targets"])
            if args.plan_only:
                result["status"] = "planned_requires_original_source_and_sp2_validation"
            else:
                result["status"] = "blocked_original_spr_unavailable_or_unverified"
                require(source_problem is None, source_problem)
                result["status"] = "blocked_actual_source_contract"
                planned_actor, planned_members = actor, members
                actor, members, proof = plan_action(request, original, metadata, allow_host_timing=allow_host_timing,
                                                     omit_missing=omit_missing)
                require(members == planned_members and actor == planned_actor,
                        "actual SPR compiler relationships differ from metadata plan")
                result["status"] = "blocked_original_sp2_unavailable_or_unverified"
                raw = verified_raw(args.original_root, members, metadata["identities"])
                result["status"] = "blocked_actual_sp2_frame_contract"
                identity.validate_actor(actor, raw, parsed)
                compact = identity.compact_roles(actor, proof)
                record = {"schema": 1, "source_snapshot": "patch523", "consumer_contract": contract,
                          "actor": actor, "compact_roles": compact, "source_proof": proof,
                          "source_layer_declarations": source_layer_declarations(proof, original),
                          "action_key": request["action_key"], "selection_semantics": request["selection_semantics"]}
                name = f"actors/{request['actor_id']}/action-{request['action_id']}.json"
                body = json_bytes(record)
                for member, raw_record in raw.items():
                    if member in written_members:
                        require(written_members[member]["sha256"] == raw_record["proof"]["sha256"], "original SP2 changed during build")
                for member, raw_record in raw.items():
                    if member in written_members:
                        require(written_members[member]["sha256"] == raw_record["proof"]["sha256"], "original SP2 changed during build")
                        continue
                    if getattr(args, "link_raw", False):
                        link_file(output, "raw/" + member, args.original_root / member, raw_record["body"])
                    else:
                        write_file(output, "raw/" + member, raw_record["body"])
                    written_members[member] = {**raw_record["proof"], "path": "raw/" + member}
                write_file(output, name, body)
                compiled.setdefault("sprite:" + str(request["actor_id"]), {})[str(request["action_id"])] = {"path": name, "sha256": sha(body)}
                result["compiled"] = True
                result["compiled_target_members"] = sorted(members & metadata["targets"])
                result["status"] = "compiled_source_action_bank_not_installed"
        except (ValueError, KeyError, OSError, RuntimeError) as error:
            result["reason"] = str(error)
        action_results.append(result)
        requested = set(request["target_members"])
        seed_requested = set(request.get("seed_target_members", request["target_members"]))
        planned = set(result.get("planned_target_members", []))
        compiled_targets = set(result.get("compiled_target_members", []))
        for member in sorted(requested | planned):
            per_member[member].append({"actor_id": request["actor_id"], "action_id": request["action_id"],
                "action_key": request["action_key"], "status": result["status"], "reason": result.get("reason"),
                "directly_requested": member in requested, "planned_emitted": member in planned,
                "seed_directly_requested": member in seed_requested, "compiled_emitted": member in compiled_targets})
    family_failures = defaultdict(list)
    for failure in scan_failures:
        for member in failure["related_family_target_members"]:
            family_failures[member].append(failure["failure_key"])
    outcomes = []
    for member in sorted(metadata["targets"]):
        row, links = metadata["inventory"][member], per_member[member]
        statuses = {link["status"] for link in links}
        directly_requested = any(link["directly_requested"] for link in links)
        seed_directly_requested = any(link["seed_directly_requested"] for link in links)
        planned_emitted = any(link["planned_emitted"] for link in links)
        compiled_emitted = any(link["compiled_emitted"] for link in links)
        require(not compiled_emitted or member in written_members, "compiled target has no verified written member")
        status = ("compiled_source_action_bank_not_installed" if compiled_emitted
                  else "planned_requires_original_source_and_sp2_validation" if "planned_requires_original_source_and_sp2_validation" in statuses
                  else next(iter(statuses)) if len(statuses) == 1
                  else "blocked_source_actions" if links
                  else "blocked_source_family_contract_review" if family_failures[member]
                  else "blocked_no_source_action_request")
        outcomes.append({"member": member, "archive": row.get("archive"), "container": row.get("container"), "bytes": row["bytes"], "crc32": row["crc32"],
            "original_member_sha256_evidence": row.get("original_member_sha256_evidence"), "status": status,
            "requests": links, "directly_requested": directly_requested, "planned_emitted": planned_emitted,
            "seed_directly_requested": seed_directly_requested,
            "family_source_failures": family_failures[member],
            "request_selection_status": "directly_requested" if directly_requested else "emitted_dependency_without_direct_request" if planned_emitted else "no_direct_source_action_request",
            "compiled": compiled_emitted,
            "installed_this_run": False, "played_this_run": False,
            "active_installation": None, "playback_evidence": None})
    write_records(output, "action-outcomes.jsonl.gz", action_results)
    write_records(output, "file-outcomes.jsonl.gz", outcomes)
    write_records(output, "effective-requests.jsonl.gz", effective_requests)
    write_records(output, "source-family-scan-failures.jsonl.gz", scan_failures)
    write_records(output, "source-family-root-evidence.jsonl.gz",
                  ({"actor_id": root, "evidence": evidence} for root, evidence in sorted(metadata.get("family_evidence", {}).items())))
    require(sha(args.requests.read_bytes()) == request_sha256, "requests changed during build; no bank manifest published")
    compiled_count = sum(result["compiled"] for result in action_results)
    counts = {"target_files": len(outcomes), "seed_requested_actions": len(seed_requests),
              "requested_actions": len(effective_requests), "compiled_actions": compiled_count,
              "compiled_raw_members": len(written_members), "file_statuses": dict(Counter(row["status"] for row in outcomes)),
              "action_statuses": dict(Counter(row["status"] for row in action_results)),
              "directly_requested_target_files": sum(row["directly_requested"] for row in outcomes),
              "seed_directly_requested_target_files": sum(row["seed_directly_requested"] for row in outcomes),
              "planned_emitted_target_files": sum(row["planned_emitted"] for row in outcomes),
              "compiled_target_files": sum(row["compiled"] for row in outcomes)}
    summary = {"schema": 1, "kind": "current523_reference_sp2_action_bank", "source_snapshot": "patch523",
        "stage": "metadata_plan_only" if args.plan_only else "private_source_bank_compilation",
        "consumer_contract": contract, "counts": counts, "metadata_proof": metadata["proof"],
        "requests_sha256": request_sha256, "source_problem": source_problem,
        "seed_requests_sha256": request_sha256,
        "effective_requests_sha256": sha((output / "effective-requests.jsonl.gz").read_bytes()),
        "source_dummy_exclusion_policy": DUMMY_EXCLUSION_POLICY,
        "excluded_source_actors": source_dummy_registry(metadata["dummy_declarations"]),
        "complete_source_family_expansion": dict(expansion_statistics),
        "source_spr_hashes": metadata["sources"], "original_spr_inputs": source_inputs,
        "actual_original_spr_files_verified": original is not None and not source_inputs["missing"],
        "original_resource_delivery_complete": False, "installed_this_run": False, "played_this_run": False,
        "active_installation": None, "playback_evidence": None}
    write_file(output, "summary.json", json_bytes(summary))
    if compiled_count:
        manifest = {"schema": 1, "kind": summary["kind"], "source_snapshot": "patch523",
                    "consumer_contract": contract, "actors": compiled, "members": written_members}
        manifest.update(source_dummy_exclusion_policy=DUMMY_EXCLUSION_POLICY,
                        excluded_source_actors=summary["excluded_source_actors"])
        write_file(output, "manifest.json", json_bytes(manifest))
    print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
    return summary


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--requests", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--plan-only", action="store_true")
    parser.add_argument("--original-root", type=Path)
    parser.add_argument("--spr-root", type=Path)
    parser.add_argument("--dependency-index", type=Path)
    parser.add_argument("--allow-host-timing", action="store_true",
                        help="Keep absent source FPS null and permit the existing explicitly labelled host timing policy.")
    parser.add_argument("--client-omit-missing-layers", action="store_true",
                        help="Follow the client: drop shadow/clothes layers whose SP2 files the client does not ship "
                             "(the body is never dropped); recorded per action and in the bank contract.")
    parser.add_argument("--link-raw", action="store_true",
                        help="Hard-link verified original SP2 files into raw/ instead of copying them "
                             "(output must be on the same filesystem; the original files must not be edited afterwards).")
    parser.add_argument("--client-section-default-fps", action="store_true",
                        help="Use the client's evidenced per-section default rate (24) for actions without code110; "
                             "the metadata handoff must have been generated with the same policy.")
    parser.add_argument("--connect-received", action="store_true",
                        help="Write source connections from supplied receipts without additional hash/CRC/frame validation.")
    parser.add_argument("--saved-plan", type=Path)
    parser.add_argument("--input-receipt", type=Path, action="append", default=[])
    parser.add_argument("--followup-receipt", type=Path, action="append", default=[])
    parser.add_argument("--followup-scope", type=Path,
                        help="Supplied full follow-up denominator, preserved while applying literal source dummy exclusions.")
    parser.add_argument("--map-placement-exclusion-sprite", type=int, action="append", default=[])
    parser.add_argument("--normal-visual-context", type=Path, action="append", default=[])
    parser.add_argument("--resume-bank", type=Path)
    parser.add_argument("--reconnect-source-contract", action="append", default=[],
                        help="Construct only matching caught source contracts plus closures completed by newly received inputs.")
    parser.add_argument("--source-receipt", type=Path,
                        help="Previously completed whole-SPR receipt retained as provenance; not rechecked in receipt mode.")
    args = parser.parse_args(argv)
    if args.connect_received:
        if args.saved_plan is None or args.spr_root is None or args.original_root is None or not args.input_receipt:
            parser.error("--connect-received requires --saved-plan, --spr-root, --original-root and --input-receipt")
        import connect_received_sp2_bank
        connect_received_sp2_bank.connect(args)
        return 0
    if args.requests is None:
        parser.error("--requests is required for strict compilation and planning")
    try:
        result = build(args)
    except (ValueError, KeyError, OSError, RuntimeError, json.JSONDecodeError) as error:
        print(f"REFERENCE_SP2_BANK_FAILED: {error}", file=sys.stderr)
        return 1
    return 0 if args.plan_only or result["counts"]["compiled_actions"] == result["counts"]["requested_actions"] > 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
