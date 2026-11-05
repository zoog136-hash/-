#!/usr/bin/env python3
"""Classify source NPC definitions against an actual Main quote trace; read-only."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

SOURCE = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
EXCLUDED = ("이벤트", "[BM]", "혈맹", "내성", "공성", "지구라트", "투기장", "동물", "과거의 말하는 섬", "기억의섬", "기억의 섬")
DEPENDENCIES = {10: "PR245 existing skill-book learning and card qualification; no duplicate skill implementation",
                52: "PR245 spell execution and PR238 item identities; eight magic-scroll use definitions are not implemented here",
                29: "PR249 card/box reward definitions; no new random box implementation",
                111: "PR241 trial-dungeon content access",
                1622: "PR241 Orim content reward/currency",
                2231: "fishing currency/content authority is outside ordinary NPC sales",
                2303: "PR241 legacy Tower of Trials token exchange; source spawn is also absent",
                2313: "PR241 reboot Tower of Trials token exchange; source spawn is also absent"}


def classify(npc, runtime):
    if npc.get("source_zip_sha256") != SOURCE:
        raise ValueError("NPC source identity mismatch")
    merchants = npc["merchants"]
    groups = runtime["groups"]
    rows = runtime["rows"]
    if len(merchants) != 192 or len(groups) != 192 or len(rows) != 4328:
        raise ValueError("incomplete source/runtime coverage")
    by_goods = {}
    for row in rows:
        if row["goods_id"] in by_goods:
            raise ValueError("duplicate runtime goods")
        by_goods[row["goods_id"]] = row
    output = []
    for merchant in merchants:
        mid = merchant["merchant_id"]
        links = merchant["object_links"]
        traces = [by_goods[i] for i in merchant["goods_ids"]]
        if any(r["merchant_id"] != mid for r in traces):
            raise ValueError("runtime goods attached to another merchant")
        ready = sum(bool(r["ready"]) for r in traces)
        if groups[str(mid)] != {"ready": ready, "blocked": len(traces) - ready}:
            raise ValueError("runtime count mismatch")
        flags = []
        if not links: flags.append("missing_explicit_Unit25_object_reference")
        if links and not any(o["object_defined"] and o["sell_action_row_ids"] for o in links): flags.append("missing_defined_SellList_action")
        if links and not any(o["spawns"] for o in links): flags.append("missing_source_spawn")
        if any(any(token in str(o.get("name", "")) for token in EXCLUDED) for o in links): flags.append("excluded_content_or_unconfirmed_event_activation")
        if links and not any(not s["SpawnManually"] and s["ServerLimitSetID"] == 0 for o in links for s in o["spawns"]): flags.append("no_automatic_unrestricted_source_spawn")
        if not links: status = "DATA_ABSENT_REFERENCE"
        elif mid == 39: status = "NON_SALE_BUYBACK_DEPENDENCY_PR251"
        elif ready: status = "EXECUTABLE_GENERAL_SALES"
        elif "excluded_content_or_unconfirmed_event_activation" in flags: status = "EXCLUDED_SCOPE_OR_ACTIVATION"
        elif mid in DEPENDENCIES: status = "DEPENDENCY_UNIMPLEMENTED"
        elif "no_automatic_unrestricted_source_spawn" in flags and any(o["spawns"] for o in links): status = "EXCLUDED_SERVER_OR_MANUAL_SPAWN"
        elif "missing_source_spawn" in flags or "missing_defined_SellList_action" in flags: status = "DATA_ABSENT_ACTION_OR_SPAWN"
        else: status = "DEPENDENCY_UNIMPLEMENTED"
        output.append({"merchant_id": mid, "status": status, "ready_goods": ready,
                       "blocked_goods": len(traces) - ready, "source_gaps_and_conditions": flags,
                       "dependency": DEPENDENCIES.get(mid, ""),
                       "runtime_blockers": dict(Counter(r["reason"] for r in traces if not r["ready"]))})
    return {"schema": "twilight.source523.npc-scope.v1", "authorization": False,
            "source_zip_sha256": SOURCE, "runtime_scope": runtime.get("scope"),
            "summary": dict(Counter(r["status"] for r in output)), "groups": output}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("npc", type=Path); parser.add_argument("runtime", type=Path); parser.add_argument("output", type=Path)
    args = parser.parse_args()
    destination = args.output.resolve()
    if destination in [args.npc.resolve(), args.runtime.resolve()] or destination.exists() or destination.is_relative_to(Path(__file__).resolve().parents[2]):
        raise ValueError("choose a new private output outside the Git tree; preserve inputs")
    result = classify(json.loads(args.npc.read_bytes()), json.loads(args.runtime.read_bytes()))
    data = (json.dumps(result, ensure_ascii=False, indent=2) + "\n").encode()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("xb") as out: out.write(data)
    print(json.dumps({"summary": result["summary"], "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}))


if __name__ == "__main__": main()
