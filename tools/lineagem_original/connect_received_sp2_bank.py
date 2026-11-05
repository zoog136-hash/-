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
    value = dict(row)
    value["sha256"] = (row.get("sha256") or row.get("supplied_member_sha256")
                       or row.get("supplied_sha256") or row.get("expected_sha256"))
    value["local_path"] = row.get("local_path") or row.get("output_path") or str(original_root / row["member"])
    value["stage"] = row.get("stage", "previous_acquisition_verified_no_additional_validation_this_run")
    return value


def descriptor(member, receipt):
    result = {"member": member, "path": "raw/" + member,
              "bytes": receipt["bytes"], "sha256": receipt.get("sha256")}
    if result["sha256"] is None:
        relation = receipt.get("current523_relation", {})
        result.update(crc32=receipt["crc32"], stage=receipt["stage"], source_receipt_id=member,
            source_identity={"source_snapshot": "patch523",
                "basis": "supplied_exact_current523_member_archive_bytes_crc_domain",
                "archive": receipt.get("archive") or receipt.get("container"),
                "source_manifest_reference": receipt.get("source_manifest_reference"),
                "whole_current523_manifest_match": receipt.get("supplied_source_current523_manifest_match", relation.get("whole_current523_manifest_match")),
                "container_sha256": receipt.get("supplied_container_sha256") or relation.get("supplied_container_sha256"),
                "version_basis": receipt.get("target_identity_domain", {}).get("version_basis") or receipt.get("version_basis"),
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
    action_keys = {}
    for row in bank.records(args.metadata / bank.ACTIONS):
        action_keys[(bank.source_name(row["source_file"]), row["source_line"], row["action_id"])] = row["action_key"]

    def key_for(actor_id, action_id):
        _, actions = bank.original_spr.resolve(declarations, actor_id)
        action = actions[action_id]
        return action_keys[(action["source_file"], action["source_line"], action_id)]

    registry, raw, resume_root = {}, {}, args.resume_bank
    if resume_root is not None:
        previous = json.loads((resume_root / "manifest.json").read_text(encoding="utf-8"))
        bank.require(previous.get("consumer_contract") == contract,
                     "Resume bank timing contract differs; select its explicit host-timing mode or a matching strict bank.")
        registry = previous["actors"]
        raw = previous["members"]
        for entry in raw.values(): link_or_copy(resume_root / entry["path"], output / entry["path"])
        for entries in registry.values():
            for entry in entries.values(): link_or_copy(resume_root / entry["path"], output / entry["path"])
    outcomes, emitted = {}, defaultdict(dict)
    counts, statuses, source_blocks, followup_results, overlay_bindings = Counter(), Counter(), Counter(), [], {}
    dependency_requirements = []

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
        graph = bank.construct_source_graph(actor_id, action_id, declarations, sources, key_for, args.allow_host_timing)
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
            if request.get("compiled") and existing:
                result.update(status="compiled_source_graph_without_additional_validation",compiled=True,reused_previously_generated_record=True)
            else:
                old_members = request.get("actual_emitted_members") or request.get("required_members")
                is_independent = "independent layer timing unsupported" in reason
                missing = sorted(set(old_members or ()) - receipts.keys())
                eligible = is_independent or "dependency identity unavailable" in reason or request.get("status") in (
                    "blocked_original_sp2_not_received", "planned_requires_original_source_and_sp2_validation", "blocked_saved_direction_or_frame",
                    "blocked_requested_member_not_emitted_by_source_graph") or reason == "no positive explicit source FPS; timing cannot be invented" or "requested target is not emitted" in reason
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
                for member in set(result.get("actual_emitted_members", [])) & targets:
                    emitted[member][pair] = {"actor_id":pair[0],"action_id":pair[1],"action_key":request["action_key"],
                        "status":result["status"],"compiled_emitted":True,"directly_requested":member in request["target_members"]}
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
        except (ValueError,KeyError,RuntimeError) as error:
            followup_results.append({"actor_id":actor_id,"status":"blocked_source_graph_construction","reason":str(error),"compiled":False})
    for request in followup_parents.values():
        try: result = construct(request,"approved_followup_explicit_parent_context")
        except (ValueError,KeyError,OSError,RuntimeError) as error:
            result = {"compiled":False,"status":"blocked_source_graph_construction","reason":str(error)}
        followup_results.append({**request,**result,"scope":"approved_followup_explicit_parent_context","additional_validation_performed":False})
        for member in set(result.get("actual_emitted_members",[])) & set(followup):
            followup_emitted[member].append({"actor_id":request["actor_id"],"action_id":request["action_id"],
                "compiled":result["compiled"],"status":result["status"],"provided_parent_context":True})
    writer.records("followup-action-outcomes.jsonl.gz",followup_results)
    writer.records("followup-file-outcomes.jsonl.gz",({"member":member,"scope":"approved_followup_separate_scope",
        "source_receipt":row,"connections":followup_emitted[member],"compiled":any(r["compiled"] for r in followup_emitted[member]),
        "current_input_stage":row.get("stage"),"packed_output":{"present":member in raw,"path":raw.get(member,{}).get("path")},
        "registry":{"emitted":any(r["compiled"] for r in followup_emitted[member])},"consumer_event_selection":None,
        "additional_validation_performed":False,"actual_main_game_feature_use":False,"active_installation":None,"playback_evidence":None}
        for member,row in followup.items()))

    file_statuses = Counter()
    def file_rows():
        for previous in bank.records(plan / "file-outcomes.jsonl.gz"):
            member,links = previous["member"],{}
            for old in previous["requests"]:
                pair = old["actor_id"],old["action_id"]
                links[pair] = {**old,**outcomes.get(pair,{})}
            for pair,new in emitted.get(member,{}).items(): links[pair] = {**links.get(pair,{}),**new}
            ready = bool(emitted.get(member))
            status = "compiled_source_graph_without_additional_validation" if ready else previous["status"]
            file_statuses[status] += 1
            yield {**previous,"status":status,"requests":list(links.values()),"compiled":ready,"input_received":member in receipts,
                "current_input_stage":receipts.get(member,{}).get("stage","not_received"),
                "original_identity_receipt_id":member if member in receipts else None,
                "source_context_from_saved_plan":str(plan),
                "packed_output":{"present":member in raw,"path":raw.get(member,{}).get("path"),"additional_validation_performed":False},
                "registry":{"emitted":ready,"connection_count":len(emitted.get(member,{}))},"consumer_event_selection":None,
                "raw_bank_identity":raw.get(member),"additional_validation_performed":False,"installed_this_run":False,"played_this_run":False,
                "actual_main_game_feature_use":False,"actual_observed_original_bytes":None,"whole_file_use":False,"active_installation":None,"playback_evidence":None}
    writer.records("file-outcomes.jsonl.gz",file_rows())
    writer.records("source-receipts.jsonl.gz",({"source_receipt_id":member,**row,"used_in_registry":member in raw} for member,row in receipts.items()))
    writer.records("required-source-dependencies.jsonl.gz",dependency_requirements)
    manifest = {"schema":1,"kind":"current523_reference_sp2_action_bank","source_snapshot":"patch523",
        "consumer_contract":contract,"actors":registry,"members":raw,"normal_visual_overlay_bindings":overlay_bindings,
        "independent_source_layers_opt_in":True,"independent_layer_policy":"explicit_source_relation_same_action_id_child_own_clock_host_dispatch_unverified",
        "compilation_validation":"not_repeated_per_user_instruction","installed_this_run":False,"played_this_run":False}
    pin = writer.json("manifest.json",manifest)
    result = {"stage":"actual_source_graph_connections_written_without_additional_validation","counts":{**counts,
        "registered_actor_action_records":sum(len(r) for r in registry.values()),"registered_actors":len(registry),
        "raw_members_linked_or_copied":len(raw),"raw_original_bytes_from_existing_receipts":sum(r["bytes"] for r in raw.values()),
        "priority_target_files_connected":len(emitted),"priority_target_file_outcomes":sum(file_statuses.values()),
        "followup_input_files":len(followup),"followup_files_connected":sum(any(r["compiled"] for r in x) for x in followup_emitted.values()),
        "normal_visual_overlay_bindings":len(overlay_bindings)},"action_statuses":dict(statuses),"file_statuses":dict(file_statuses),
        "remaining_source_contract_outcomes_from_generation":dict(source_blocks),
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
