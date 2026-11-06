"""Receipt-based source connections; deliberately no extra input/frame validation.

Invoked by build_reference_sp2_bank.py --connect-received. Supplied receipt
identities and complete-SPR proofs are retained as supplied, including unknown
hashes. Newly serialized digests identify registry records; they are not a
readback/integrity test. Original pixels stay in the requested private output.
"""
from collections import Counter, defaultdict
from pathlib import Path
import gzip
import hashlib
import json
import os
import shutil
import time

import build_reference_sp2_bank as bank


class Writer:
    def __init__(self, root):
        self.root, self.receipts = root, {}

    def blob(self, name, body):
        bank.write_file(self.root, name, body)
        self.receipts[name] = {"path": name, "bytes_serialized": len(body),
                               "sha256_at_write": bank.sha(body), "readback_validation_this_run": False}
        return self.receipts[name]

    def json(self, name, value):
        return self.blob(name, bank.json_bytes(value))

    def records(self, name, rows):
        target = self.root / name
        digest, count, size = hashlib.sha256(), 0, 0
        with target.open("xb") as file:
            class Sink:
                def write(self, body):
                    nonlocal size
                    digest.update(body)
                    size += len(body)
                    return file.write(body)
                def flush(self):
                    return file.flush()
            with gzip.GzipFile(filename="", mode="wb", fileobj=Sink(), mtime=0) as stream:
                for row in rows:
                    stream.write(bank.json_bytes(row))
                    count += 1
        target.chmod(0o600)
        self.receipts[name] = {"path": name, "rows_written": count, "bytes_serialized": size,
                               "sha256_at_write": digest.hexdigest(), "readback_validation_this_run": False}
        return self.receipts[name]


def supplied_identity(row, original_root):
    value = dict(row.get("descriptor", {})) if isinstance(row.get("descriptor"), dict) else {}
    if isinstance(row.get("supplied_identity"), dict):
        value.update(row["supplied_identity"])
    value.update(row)  # Preserve explicit receipt fields, including contradictions and nulls.
    value["sha256"] = (value.get("sha256") or value.get("supplied_member_sha256")
                       or value.get("supplied_sha256") or value.get("expected_sha256"))
    value["local_path"] = value.get("local_path") or value.get("output_path") or str(original_root / value["member"])
    value["stage"] = value.get("stage", "previous_acquisition_verified_no_additional_validation_this_run"
                               if value["sha256"] else "source_input_stage_unspecified")
    return value


def descriptor(member, receipt):
    result = {"member": member, "path": "raw/" + member,
              "bytes": receipt["bytes"], "sha256": receipt.get("sha256")}
    if result["sha256"] is None:
        relation = receipt.get("current523_relation", {})
        if not isinstance(relation, dict):
            relation = {}  # No supplied current-container contract can be inferred from another value.
        target_domain = receipt.get("target_identity_domain", {})
        if not isinstance(target_domain, dict):
            target_domain = {}
        version_basis = target_domain.get("version_basis") or receipt.get("version_basis")
        whole_manifest = receipt.get("supplied_source_current523_manifest_match")
        relation_whole_manifest = relation.get("whole_current523_manifest_match")
        if whole_manifest is False or relation_whole_manifest is False:
            whole_manifest = False
        elif whole_manifest is None:
            whole_manifest = relation_whole_manifest  # Copy a supplied value; never infer a whole-match claim.
        container_manifest = None
        if all(field in relation for field in ("manifest_path", "current523_container_bytes", "current523_container_sha1", "source_provenance_file")):
            container_manifest = {"archive":relation["manifest_path"], "bytes":relation["current523_container_bytes"],
                                  "sha1":relation["current523_container_sha1"],
                                  "source_provenance_file":relation["source_provenance_file"]}
            if version_basis is None:
                version_basis = "supplied_current523_container_manifest"
        # Runtime stage is a closed contract, not the acquisition log's wording.
        # Keep the original wording separately; CRC/source identity guards still
        # apply and a missing SHA stays unknown.
        result.update(crc32=receipt["crc32"], stage="received_not_additionally_validated",
            source_acquisition_stage=receipt["stage"], source_receipt_id=member,
            source_identity={"source_snapshot": "patch523",
                "basis": "supplied_exact_current523_member_archive_bytes_crc_domain",
                "archive": receipt.get("archive") or receipt.get("container"),
                "source_manifest_reference": receipt.get("source_manifest_reference"),
                "whole_current523_manifest_match": whole_manifest,
                "container_sha256": receipt.get("supplied_container_sha256") or relation.get("supplied_container_sha256"),
                "version_basis": version_basis,
                "container_manifest_identity": container_manifest,
                "source_original_snapshot": receipt.get("source_snapshot")})
    return result


def link_or_copy(source, destination):
    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    try:
        os.link(source, destination)
    except OSError:
        shutil.copyfile(source, destination)
    destination.chmod(0o600)


def connect(args):
    os.umask(0o077)
    started, last_report = time.monotonic(), time.monotonic()
    output = args.output.resolve()
    bank.require(not output.is_relative_to(Path(__file__).resolve().parents[2]), "original connection output must be private, outside the repository")
    output.mkdir(mode=0o700, parents=True)
    writer = Writer(output)
    plan = args.saved_plan
    summary = json.loads((plan / "summary.json").read_text(encoding="utf-8"))
    sources = (summary.get("source_spr_hashes") or summary.get("source_spr_hashes_from_existing_proof")
               or summary["source_spr_hashes_from_existing_receipt"])
    contract = bank.consumer_contract(args.allow_host_timing)
    inventory = {row["member"]: row for row in bank.records(args.metadata / bank.INVENTORY)}
    targets = {name for name, row in inventory.items() if row.get("source_family_categories")}
    receipts, followup = {}, {}
    for path in args.input_receipt or []:
        for row in bank.records(path): receipts[row["member"]] = supplied_identity(row, args.original_root)
    for path in args.followup_receipt or []:
        for row in bank.records(path):
            followup[row["member"]] = row
            receipts[row["member"]] = supplied_identity(row, args.original_root)
    identities = dict(inventory)
    for member, row in receipts.items():
        if member not in identities and (row.get("current523_relation") or row.get("supplied_source_current523_manifest_match")):
            identities[member] = row
    declarations = bank.original_spr.read([args.spr_root / name for name in sources])
    dummy = bank.source_dummy_declarations([args.spr_root / name for name in sources], sources)
    actor_contexts = {row["source_owner_key"]:row for row in bank.records(args.metadata / "current523_sp2_actor_dependency_context.jsonl.gz")}
    followup_scope = ({row["member"]:row for row in bank.records(args.followup_scope)}
                      if args.followup_scope else dict(followup))
    # The supplied SPR declarations define this bank's source namespace, even
    # for a dummy with no action or physical member (such as a pure placeholder).
    # The registry governs actor paths in this pinned bank, never raw filenames.
    excluded_registry = bank.source_dummy_registry(dummy)
    dummy_path_cache, dummy_graph_cache = {}, {}

    def dummy_path(sprite_id):
        if sprite_id not in dummy_path_cache:
            dummy_path_cache[sprite_id] = bank.source_dummy_alias_path(sprite_id,declarations,dummy)
        return dummy_path_cache[sprite_id]

    def graph_has_dummy(sprite_id,seen=()):
        if sprite_id in dummy_graph_cache: return dummy_graph_cache[sprite_id]
        if sprite_id in seen: return False
        if dummy_path(sprite_id) is not None: return True
        for declaration in declarations.get(sprite_id,[]):
            if declaration.alias_target is not None and graph_has_dummy(declaration.alias_target,seen+(sprite_id,)): return True
            for reference in declaration.references:
                if any(graph_has_dummy(target,seen+(sprite_id,)) for target in reference["targets"]): return True
        dummy_graph_cache[sprite_id] = False
        return False

    def file_dummy_path(member):
        owner = actor_contexts.get(inventory.get(member,{}).get("source_owner_context_key"),{}).get("source_declaration_sprite_id")
        return dummy_path(owner) if isinstance(owner,int) else None
    action_keys = {}
    for row in bank.records(args.metadata / bank.ACTIONS):
        action_keys[(bank.source_name(row["source_file"]), row["source_line"], row["action_id"])] = row["action_key"]

    def key_for(actor_id, action_id):
        _, actions = bank.original_spr.resolve(declarations, actor_id)
        action = actions[action_id]
        return action_keys[(action["source_file"], action["source_line"], action_id)]

    registry, raw, resume_root = {}, {}, args.resume_bank
    preserved_records, projection_required = {}, set()
    if resume_root is not None:
        previous = json.loads((resume_root / "manifest.json").read_text(encoding="utf-8"))
        bank.require(previous.get("consumer_contract") == contract,
                     "Resume bank timing contract differs; select its explicit host-timing mode or a matching strict bank.")
        registry = previous["actors"]
        raw = previous["members"]
        for actor_key,info in previous.get("preserved_actor_records",{}).items():
            kept = {}
            for action_id,entry in info["records"].items():
                path = "preserved_records/history/"+entry["path"]
                link_or_copy(resume_root / entry["path"],output / path)
                kept[action_id] = {**entry,"path":path,"previous_record_path":entry["path"]}
            preserved_records[actor_key] = {**info,"records":kept}
        for entry in raw.values(): link_or_copy(resume_root / entry["path"], output / entry["path"])
        for entries in registry.values():
            for entry in entries.values(): link_or_copy(resume_root / entry["path"], output / entry["path"])
        for actor_key in list(registry):
            sprite_id = int(actor_key.removeprefix("sprite:"))
            excluded = dummy_path(sprite_id)
            if excluded is not None:
                preserved_records[actor_key] = {"reason":"source_literal_dummy","source_graph_path":excluded,
                    "records":registry.pop(actor_key),"active":False,"originals_preserved":True}
            elif graph_has_dummy(sprite_id):
                entries = registry.pop(actor_key)
                kept = {}
                for action_id,entry in entries.items():
                    preserved_path = "preserved_records/"+entry["path"]
                    destination = output / preserved_path
                    destination.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
                    (output / entry["path"]).rename(destination)
                    kept[action_id] = {**entry,"path":preserved_path}
                    projection_required.add((sprite_id,int(action_id)))
                preserved_records[actor_key] = {"reason":"user_requested_dummy_layer_projection","records":kept,
                    "active":False,"originals_preserved":True}
    outcomes, emitted = {}, defaultdict(dict)
    active_records, active_members = set(), set()
    counts, statuses, source_blocks, followup_results, overlay_bindings = Counter(), Counter(), Counter(), [], {}
    dependency_requirements = []
    dummy_touched, dummy_actions = defaultdict(list), []

    def activate(pair):
        if pair in active_records: return
        entry = registry.get("sprite:"+str(pair[0]),{}).get(str(pair[1]))
        if entry is None: return
        active_records.add(pair)
        # Existing actor metadata is read only to assemble active connections;
        # no pixel/hash/frame-quality validation is performed.
        record = json.loads((output / entry["path"]).read_text(encoding="utf-8"))
        for track in record["actor"]["roles"].values():
            for frames in track["directions"]:
                for frame in frames:
                    active_members.update(layer["member"] for layer in frame["layers"])
        for child in record.get("independent_source_layers",[]):
            activate((child["target_sprite_id"],child["child_action_id"]))

    def register(records, members):
        for member in sorted(members):
            if member not in raw:
                receipt = receipts[member]
                link_or_copy(receipt["local_path"], output / "raw" / member)
                raw[member] = descriptor(member, receipt)
        for (actor_id, action_id), record in records.items():
            actor_key, action_key = "sprite:" + str(actor_id), str(action_id)
            if action_key in registry.get(actor_key, {}): continue
            path = f"actors/{actor_id}/action-{action_id}.json"
            receipt = writer.json(path, record)
            registry.setdefault(actor_key, {})[action_key] = {"path": path, "sha256": receipt["sha256_at_write"],
                "validation_this_run": "not_repeated_per_user_instruction"}
            counts["new_actor_action_records_written"] += 1

    def construct(request, scope):
        actor_id, action_id = request["actor_id"], request["action_id"]
        graph = bank.construct_source_graph(actor_id, action_id, declarations, sources, key_for,
                                             args.allow_host_timing, excluded_dummy=dummy)
        members = graph["members"]
        missing_identity = sorted(members - identities.keys())
        if missing_identity:
            dependency_requirements.append({"actor_id":actor_id,"action_id":action_id,"action_key":key_for(actor_id,action_id),
                "scope":scope,"required_members":sorted(members),"missing_current523_identities":missing_identity,
                "source_relations":graph["record"].get("independent_source_layers",[])})
            return {"compiled":False,"status":"blocked_current523_dependency_identity", "missing_current523_identities":missing_identity,
                    "reason":"Explicit current523 identity has not been supplied for every constructed source dependency.",
                    "actual_emitted_members":sorted(members)}
        requested = set(request.get("target_members", []))
        unmatched = sorted(requested-members)
        if not members & (targets | followup.keys()):
            return {"compiled":False,"status":"blocked_no_authorized_target_emission",
                    "reason":"Constructed source addresses do not emit an authorized target in this connection scope.",
                    "unemitted_requested_members":unmatched,"actual_emitted_members":sorted(members)}
        missing = sorted(members - receipts.keys())
        if missing:
            return {"compiled":False,"status":"blocked_original_sp2_not_received", "missing_original_members":missing,
                    "reason":"The required original member closure has not been received.",
                    "actual_emitted_members":sorted(members)}
        register(graph["records"], members)
        return {"compiled":True,"status":"compiled_source_graph_without_additional_validation", "actual_emitted_members":sorted(members),
                "unemitted_requested_members":unmatched,
                "excluded_dummy_source_edges":graph["record"].get("excluded_dummy_source_edges",[]),
                "independent_source_layers":graph["record"].get("independent_source_layers",[]),
                "compiled_source_nodes":len(graph["records"]),"literal_source_fps":graph["record"]["actor"]["roles"]["source_action:"+str(action_id)]["fps"]}

    def action_rows():
        nonlocal last_report
        for request in bank.records(plan / "action-outcomes.jsonl.gz"):
            pair = request["actor_id"], request["action_id"]
            result = {**request, "additional_validation_performed":False,"installed_this_run":False,"played_this_run":False,
                      "actual_main_game_feature_use":False,"active_installation":None,"playback_evidence":None}
            reason = str(request.get("reason", ""))
            existing = str(pair[1]) in registry.get("sprite:"+str(pair[0]), {})
            excluded = dummy_path(pair[0])
            if excluded is not None:
                result.update(compiled=False,status="excluded_source_literal_dummy",reason="Explicit source dummy declaration/alias path excluded by user.",
                    dummy_exclusion=excluded,originals_preserved=True,actual_emitted_members=[])
                dummy_actions.append({"actor_id":pair[0],"action_id":pair[1],"action_key":request["action_key"],"dummy_exclusion":excluded})
                for member in set(request.get("actual_emitted_members") or request.get("required_members") or request.get("target_members",[])):
                    dummy_touched[member].append({"actor_id":pair[0],"action_id":pair[1],"dummy_exclusion":excluded})
            elif request.get("compiled") and existing:
                result.update(status="compiled_source_graph_without_additional_validation",compiled=True,reused_previously_generated_record=True)
            else:
                old_members = request.get("actual_emitted_members") or request.get("required_members")
                is_independent = "independent layer timing unsupported" in reason
                missing = sorted(set(old_members or ()) - receipts.keys())
                filters = getattr(args,"reconnect_source_contract",[]) or []
                newly_available_closure = bool(request.get("missing_original_members")) and not (
                    set(request["missing_original_members"])-receipts.keys())
                newly_supplied_identity = bool(request.get("missing_current523_identities")) and not (
                    set(request["missing_current523_identities"])-identities.keys())
                matching_contract = not filters or any(text in reason or text in str(request.get("previous_source_blocker","")) for text in filters)
                eligible = pair in projection_required or graph_has_dummy(pair[0]) or is_independent or "dependency identity unavailable" in reason or request.get("status") in (
                    "blocked_original_sp2_not_received", "planned_requires_original_source_and_sp2_validation", "blocked_saved_direction_or_frame",
                    "blocked_requested_member_not_emitted_by_source_graph") or reason == "no positive explicit source FPS; timing cannot be invented" or "requested target is not emitted" in reason or matching_contract and bool(filters) or newly_supplied_identity
                eligible = eligible and (matching_contract or newly_available_closure or newly_supplied_identity or pair in projection_required)
                if eligible and not (missing and not is_independent):
                    counts["source_graph_construction_attempts"] += 1
                    if result.get("reason"): result["previous_source_blocker"] = result.pop("reason")
                    try: result.update(construct(request, "priority_source_family"))
                    except (ValueError,KeyError,OSError,RuntimeError) as error:
                        result.update(compiled=False,status="blocked_source_graph_construction",reason=str(error))
                elif missing and eligible:
                    if result.get("reason"): result["previous_source_blocker"] = result.pop("reason")
                    result.update(compiled=False,status="blocked_original_sp2_not_received",missing_original_members=missing,
                                  reason="The required original member closure has not been received.")
            if result.get("compiled"):
                if result.get("reason"):
                    result["previous_source_blocker"] = result.pop("reason")
                counts["compiled_effective_requests"] += 1
                activate(pair)
                for member in set(result.get("actual_emitted_members", [])) & targets:
                    emitted[member][pair] = {"actor_id":pair[0],"action_id":pair[1],"action_key":request["action_key"],
                        "status":result["status"],"compiled_emitted":True,"directly_requested":member in request["target_members"]}
                for edge in result.get("excluded_dummy_source_edges",[]):
                    counts["dummy_source_edges_disabled_while_normal_parent_preserved"] += 1
                    for member in set(request.get("actual_emitted_members",[]))-set(result.get("actual_emitted_members",[])):
                        dummy_touched[member].append({"actor_id":pair[0],"action_id":pair[1],"excluded_source_edge":edge})
            outcomes[pair] = {key:result.get(key) for key in ("status","compiled","reason","previous_source_blocker","missing_original_members","missing_current523_identities","known_saved_frame_findings")}
            statuses[result["status"]] += 1
            if not result.get("compiled"):
                message = str(result.get("reason", ""))
                kind = result["status"] if result["status"] in ("blocked_current523_dependency_identity","blocked_original_sp2_not_received") else next((label for text,label in (
                    ("expected one", "missing_or_ambiguous_source_declaration"),
                    ("ambiguous source", "missing_or_ambiguous_source_declaration"),
                    ("cycle", "source_alias_or_layer_cycle"),
                    ("duplicate SPR layer edge", "duplicate_explicit_layer_edge"),
                    ("invalid layer target count", "malformed_literal_layer_count"),
                    ("frame count mismatch", "literal_source_frame_count_mismatch"),
                    ("unknown direction flag", "unsupported_literal_direction_flag"),
                    ("unknown SPR directional flag", "unsupported_literal_direction_flag"),
                    ("negative frame duration", "negative_literal_source_ticks"),
                    ("effective alias/override", "requested_source_key_differs_from_effective_override"),
                    ("absent/invalid source action", "missing_or_invalid_literal_source_action"),
                    ("independent layer timing", "independent_source_layer_still_unconstructed")) if text in message), result["status"])
                source_blocks[kind] += 1
            counts["effective_request_rows_written"] += 1
            if time.monotonic()-last_report >= 20:
                print(json.dumps({"stage":"writing_source_graph_connections","seconds":round(time.monotonic()-started,3),**counts},sort_keys=True),flush=True)
                last_report = time.monotonic()
            yield result
    writer.records("action-outcomes.jsonl.gz", action_rows())

    # Follow-up roots come only from supplied gates and literal event targets.
    followup_roots, contexts, followup_parents = defaultdict(set), {}, {}
    for member,row in followup.items():
        gate = row.get("followup_consumer_gate", {})
        metadata = gate.get("metadata", {})
        actor_id = metadata.get("sprite_id")
        if actor_id is None and row.get("source_request",{}).get("consumer_gates"):
            actor_id = actor_contexts.get(inventory.get(member,{}).get("source_owner_context_key"),{}).get("source_declaration_sprite_id")
        if isinstance(actor_id,int): followup_roots[actor_id].add(member)
    for path in args.normal_visual_context or []:
        for row in bank.records(path):
            if row["member"] not in followup: continue
            for parent in row.get("normal_visual_parent_source_paths", []):
                link = parent.get("typed_parent_action_link", {})
                action = parent.get("source_action_tokens", {})
                if isinstance(link.get("root_sprite_id"),int) and isinstance(action.get("action_id"),int):
                    followup_parents[(link["root_sprite_id"],action["action_id"])] = {"actor_id":link["root_sprite_id"],
                        "action_id":action["action_id"],"action_key":action["action_key"],"target_members":[row["member"]],
                        "provided_parent_context":parent}
                for event in parent.get("literal_event_tokens", []):
                    actor_id = event["target_sprite_id"]
                    followup_roots[actor_id].add(row["member"])
                    contexts.setdefault(actor_id, []).append({"typed_parent_action_link":parent.get("typed_parent_action_link"),
                        "literal_event_token":event,"completed_dependency_path":parent.get("completed_dependency_path")})
    followup_emitted = defaultdict(list)
    for actor_id,members in sorted(followup_roots.items()):
        try:
            _, source_actions = bank.original_spr.resolve(declarations,actor_id)
            if not source_actions:
                followup_results.append({"actor_id":actor_id,"status":"blocked_no_literal_source_action_requires_supported_parent_binding",
                    "compiled":False,"related_followup_members":sorted(members)})
            for action_id in sorted(source_actions):
                request = {"actor_id":actor_id,"action_id":action_id,"action_key":key_for(actor_id,action_id),"target_members":[]}
                try: result = construct(request,"approved_followup_separate_scope")
                except (ValueError,KeyError,OSError,RuntimeError) as error:
                    result = {"compiled":False,"status":"blocked_source_graph_construction","reason":str(error)}
                result.update(request,scope="approved_followup_separate_scope",additional_validation_performed=False)
                followup_results.append(result)
                for member in set(result.get("actual_emitted_members",[])) & set(followup):
                    followup_emitted[member].append({"actor_id":actor_id,"action_id":action_id,"compiled":result["compiled"],"status":result["status"]})
                if result["compiled"] and len(source_actions)==1 and actor_id in contexts:
                    overlay_bindings[str(actor_id)] = {"actor_key":"sprite:"+str(actor_id),"source_action_id":action_id,
                        "source_action_key":request["action_key"],"child_action_path":f"actors/{actor_id}/action-{action_id}.json",
                        "dispatch_policy":"existing_host_compatible_overlay_native_dispatch_unverified",
                        "parent_action_contexts":contexts[actor_id],"native_dispatch_verified":False}
                if result["compiled"]: activate((actor_id,action_id))
        except (ValueError,KeyError,RuntimeError) as error:
            followup_results.append({"actor_id":actor_id,"status":"blocked_source_graph_construction","reason":str(error),"compiled":False})
    for request in followup_parents.values():
        try: result = construct(request,"approved_followup_explicit_parent_context")
        except (ValueError,KeyError,OSError,RuntimeError) as error:
            result = {"compiled":False,"status":"blocked_source_graph_construction","reason":str(error)}
        followup_results.append({**request,**result,"scope":"approved_followup_explicit_parent_context","additional_validation_performed":False})
        if result["compiled"]: activate((request["actor_id"],request["action_id"]))
        for member in set(result.get("actual_emitted_members",[])) & set(followup):
            followup_emitted[member].append({"actor_id":request["actor_id"],"action_id":request["action_id"],
                "compiled":result["compiled"],"status":result["status"],"provided_parent_context":True})
    writer.records("followup-action-outcomes.jsonl.gz",followup_results)
    def followup_file_rows():
        for member,scope_row in followup_scope.items():
            row = followup.get(member,{})
            exclusion = file_dummy_path(member)
            connected = any(r["compiled"] for r in followup_emitted[member])
            if exclusion is not None and not connected:
                counts["followup_dummy_connection_excluded_files"] += 1
                counts["followup_dummy_connection_excluded_original_bytes"] += inventory.get(member,scope_row).get("bytes",0)
            yield {"member":member,"scope":"approved_followup_separate_scope","source_scope_metadata":scope_row,
        "source_receipt":row or None,"connections":followup_emitted[member],"compiled":connected,
        "source_dummy_exclusion":exclusion,"eligible_connection_excluded":exclusion is not None and not connected,
        "current_input_stage":row.get("stage","not_received"),"packed_output":{"present":member in raw,"path":raw.get(member,{}).get("path")},
        "registry":{"emitted":any(r["compiled"] for r in followup_emitted[member])},"consumer_event_selection":None,
        "additional_validation_performed":False,"actual_main_game_feature_use":False,"active_installation":None,"playback_evidence":None}
    writer.records("followup-file-outcomes.jsonl.gz",followup_file_rows())

    file_statuses = Counter()
    def file_rows():
        for previous in bank.records(plan / "file-outcomes.jsonl.gz"):
            member,links = previous["member"],{}
            retained_paths = {bank.json_bytes(item):item for item in previous.get("dummy_excluded_connection_paths",[])}
            retained_paths.update({bank.json_bytes(item):item for item in dummy_touched.get(member,[])})
            member_dummy_paths = list(retained_paths.values())
            for old in previous["requests"]:
                pair = old["actor_id"],old["action_id"]
                links[pair] = {**old,**outcomes.get(pair,{})}
            for pair,new in emitted.get(member,{}).items(): links[pair] = {**links.get(pair,{}),**new}
            ready = bool(emitted.get(member))
            exclusion = file_dummy_path(member)
            touched = bool(member_dummy_paths) or exclusion is not None
            if previous.get("compiled"):
                counts["previous_priority_compiled_files"] += 1
                counts["previous_priority_compiled_original_bytes"] += inventory[member]["bytes"]
            if ready:
                counts["active_priority_compiled_original_bytes"] += inventory[member]["bytes"]
            if touched:
                counts["priority_dummy_paths_touch_files_nonadditive"] += 1
                counts["priority_dummy_paths_touch_original_bytes_nonadditive"] += inventory[member]["bytes"]
                if ready:
                    counts["priority_shared_normal_path_preserved_files_nonadditive"] += 1
                    counts["priority_shared_normal_path_preserved_original_bytes_nonadditive"] += inventory[member]["bytes"]
                else:
                    counts["priority_dummy_connection_excluded_files"] += 1
                    counts["priority_dummy_connection_excluded_original_bytes"] += inventory[member]["bytes"]
            # A saved planning status describes its old action graph, not the
            # current availability of this member. Keep a received original
            # separate from an action blocked by another missing raw member.
            input_received = member in receipts
            blocker_states = sorted({str(link.get("status")) for link in links.values()
                                     if link.get("status") and not link.get("compiled")})
            if ready:
                status = "compiled_source_graph_without_additional_validation"
            elif touched:
                status = "excluded_source_literal_dummy"
            elif not input_received:
                status = "blocked_original_sp2_not_received"
            elif "blocked_original_sp2_not_received" in blocker_states:
                status = "blocked_source_dependency_original_not_received"
            elif "blocked_current523_dependency_identity" in blocker_states:
                status = "blocked_current523_dependency_identity"
            elif "blocked_source_address_construction" in blocker_states:
                status = "blocked_source_address_construction"
            elif "blocked_source_graph_construction" in blocker_states:
                status = "blocked_source_graph_construction"
            elif previous["status"] in ("blocked_existing_source_contract", "blocked_source_family_contract_review"):
                status = previous["status"]
            elif not links:
                status = "blocked_no_source_action_request"
            else:
                status = "blocked_source_actions_or_missing_inputs"
            file_statuses[status] += 1
            yield {**previous,"status":status,"previous_planning_status":previous["status"],
                "connection_blocker_states":blocker_states,"requests":list(links.values()),"compiled":ready,"input_received":input_received,
                "input_status":"received" if input_received else "not_received",
                "received_original_identity":receipts.get(member),
                "current_input_stage":receipts.get(member,{}).get("stage","not_received"),
                "original_identity_receipt_id":member if member in receipts else None,
                "source_context_from_saved_plan":str(plan),
                "packed_output":{"present":member in raw,"path":raw.get(member,{}).get("path"),"additional_validation_performed":False},
                "registry":{"emitted":ready,"connection_count":len(emitted.get(member,{}))},"consumer_event_selection":None,
                "source_dummy_exclusion":exclusion,"dummy_excluded_connection_paths":member_dummy_paths,
                "eligible_connection_excluded":touched and not ready,"shared_normal_path_preserved":touched and ready,
                "raw_bank_identity":raw.get(member),"additional_validation_performed":False,"installed_this_run":False,"played_this_run":False,
                "actual_main_game_feature_use":False,"actual_observed_original_bytes":None,"whole_file_use":False,"active_installation":None,"playback_evidence":None}
    writer.records("file-outcomes.jsonl.gz",file_rows())
    writer.records("source-receipts.jsonl.gz",({"source_receipt_id":member,**row,"used_in_registry":member in raw} for member,row in receipts.items()))
    writer.records("required-source-dependencies.jsonl.gz",dependency_requirements)
    for actor_key in list(registry):
        sprite_id = int(actor_key.removeprefix("sprite:"))
        for action_id in list(registry[actor_key]):
            if (sprite_id,int(action_id)) not in active_records:
                entry = registry[actor_key].pop(action_id)
                preserved_records.setdefault(actor_key,{"reason":"inactive_after_user_dummy_connection_exclusion",
                    "records":{},"active":False,"originals_preserved":True})["records"][action_id] = entry
        if not registry[actor_key]: registry.pop(actor_key)
    preserved_raw = {member:entry for member,entry in raw.items() if member not in active_members}
    active_raw = {member:entry for member,entry in raw.items() if member in active_members}
    writer.records("excluded-source-dummy-declarations.jsonl.gz",({"source_actor_id":sprite_id,"dummy_declarations":rows}
                   for sprite_id,rows in sorted(dummy.items())))
    writer.records("dummy-excluded-action-outcomes.jsonl.gz",dummy_actions)
    domains, domain_proofs = {}, []
    for actor_key in registry:
        sprite_id = int(actor_key.removeprefix("sprite:"))
        body_id,source_actions = bank.original_spr.resolve(declarations,sprite_id)
        domains[actor_key] = {"source_snapshot":"patch523","source_actor_id":sprite_id,
            "resolved_body_sprite_id":body_id,"action_ids":sorted(source_actions),
            "action_domain_basis":"all_effective_original_SPR_actions_not_only_compiled_entries","source_proof_key":actor_key}
        domain_proofs.append({"source_proof_key":actor_key,"source_actor_id":sprite_id,
            "declaration_path":bank.identity.declaration_path(declarations,sprite_id,sources),
            "source_actions":[{"action_id":action_id,"source_action_key":key_for(sprite_id,action_id),
                "source_file":action["source_file"],"source_line":action["source_line"],
                "source_sha256":sources[action["source_file"]]["sha256"],"literal_fps":action["fps"],
                "literal_source_errors":action["errors"]} for action_id,action in sorted(source_actions.items())]})
    writer.records("source-action-domain-proofs.jsonl.gz",domain_proofs)
    manifest = {"schema":1,"kind":"current523_reference_sp2_action_bank","source_snapshot":"patch523",
        "consumer_contract":contract,"actors":registry,"members":active_raw,"normal_visual_overlay_bindings":overlay_bindings,
        "source_dummy_exclusion_policy":bank.DUMMY_EXCLUSION_POLICY,"excluded_source_actors":excluded_registry,
        "source_dummy_exclusion_scope":"source_actor_paths_in_this_pinned_reference_bank",
        "source_action_domains":domains,"source_action_domain_proofs":{"path":"source-action-domain-proofs.jsonl.gz",
            "source_proof_key_field":"source_proof_key","sha256":writer.receipts["source-action-domain-proofs.jsonl.gz"]["sha256_at_write"]},
        "source_reference_instance_policy":bank.REFERENCE_INSTANCE_POLICY,
        "preserved_actor_records":preserved_records,"preserved_raw_members":preserved_raw,
        "map_placement_exclusions":{"sprite_ids":sorted(set(args.map_placement_exclusion_sprite)),
            "scope":"map_placement_only","placement_owner":"map_lane","originals_preserved":True},
        "independent_source_layers_opt_in":True,"independent_layer_policy":"explicit_source_relation_same_action_id_child_own_clock_host_dispatch_unverified",
        "compilation_validation":"not_repeated_per_user_instruction","installed_this_run":False,"played_this_run":False}
    pin = writer.json("manifest.json",manifest)
    result = {"stage":"actual_source_graph_connections_written_without_additional_validation","counts":{**counts,
        "registered_actor_action_records":sum(len(r) for r in registry.values()),"registered_actors":len(registry),
        "raw_members_linked_or_copied":len(raw),"raw_original_bytes_from_existing_receipts":sum(r["bytes"] for r in raw.values()),
        "active_registry_raw_members":len(active_raw),"active_registry_original_bytes":sum(r["bytes"] for r in active_raw.values()),
        "preserved_raw_members_not_active":len(preserved_raw),"preserved_actor_action_records_not_active":sum(len(r["records"]) for r in preserved_records.values()),
        "priority_target_files_connected":len(emitted),"priority_target_file_outcomes":sum(file_statuses.values()),
        "followup_input_files":len(followup),"followup_files_connected":sum(any(r["compiled"] for r in x) for x in followup_emitted.values()),
        "normal_visual_overlay_bindings":len(overlay_bindings)},"action_statuses":dict(statuses),"file_statuses":dict(file_statuses),
        "remaining_source_contract_outcomes_from_generation":dict(source_blocks),
        "source_dummy_exclusion_policy":bank.DUMMY_EXCLUSION_POLICY,"excluded_source_actor_ids":sorted(dummy),
        "original_priority_denominator_files":len(targets),"original_priority_denominator_bytes":sum(inventory[m]["bytes"] for m in targets),
        "followup_denominator_files":len(followup_scope),
        "unconnected_followup_from_generation":[{"member":member,"current_input_stage":followup[member].get("stage"),
            "connections":followup_emitted[member],"reason":"No complete available source-owned action or supplied supported parent closure was constructed."}
            for member in followup if not any(row["compiled"] for row in followup_emitted[member])],
        "input_receipts":[str(p) for p in args.input_receipt or []],"followup_receipts":[str(p) for p in args.followup_receipt or []],
        "source_receipt_from_previous_work":str(args.source_receipt) if args.source_receipt else None,
        "source_spr_hashes_from_existing_receipt":sources,"saved_plan":str(plan),"consumer_contract":contract,
        "additional_validation_performed":False,"new_tests_run":False,"raw_hash_CRC_frame_rechecks":False,
        "manifest_sha256_at_serialization":pin["sha256_at_write"],"duration_seconds":round(time.monotonic()-started,3),
        "installed_this_run":False,"played_this_run":False,"actual_main_game_feature_use":False,"actual_observed_original_bytes":None,
        "whole_file_use":False,"active_installation":None,"playback_evidence":None}
    writer.json("summary.json",result)
    writer.json("output-write-receipts.json",writer.receipts)
    print(json.dumps(result,sort_keys=True),flush=True)
    return result
