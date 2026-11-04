#!/usr/bin/env python3
"""Project already-published slot contracts into small runtime-only inputs.

The full reviewed source remains at the pinned commit; no raw archive/art is
copied. Existing patch523 catalog records are the identity/provenance authority.
"""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
COMMIT = "76c9e38e90fdbb77ec13931e7e0e319486b8559c"


def source(name):
    path = "data/cards/" + name + ".json"
    raw = subprocess.check_output(["git", "show", COMMIT + ":" + path], cwd=ROOT)
    return json.loads(raw), subprocess.check_output(
        ["git", "rev-parse", COMMIT + ":" + path], cwd=ROOT, text=True
    ).strip()


def project(name, data, blob):
    data["projection_source"] = {"commit": COMMIT, "blob": blob,
                                 "policy": "runtime fields only; original preserved at source"}
    return data


def build(output):
    sections = {}
    new, blob = source("patch523_new_cards")
    catalog = json.loads((ROOT / "data/lineagem_base508/cards_patch523.json").read_text())
    by_id = {r["sourceId"]: r for rows in catalog["catalog"].values() for r in rows}
    identities = set()
    for category, rows in new["catalog"].items():
        overlays = []
        for row in rows:
            base = by_id[row["sourceId"]]
            assert row["source_original_card"] == base["source_original_card"]
            identities.add(row["sourceId"])
            overlay = {k: v for k, v in row.items() if k not in base or base[k] != v}
            overlay["sourceId"] = row["sourceId"]
            overlays.append(overlay)
        new["catalog"][category] = overlays
    assert len(by_id) == 720 and len(identities) == 16
    sections["new_cards"] = project("patch523_new_cards", new, blob)

    slots, blob = source("patch523_option_slots")
    keys = {identity.split(":", 1)[1] for identity in identities}
    slots["groups"] = {k: v for k, v in slots["groups"].items()
                       if k.rsplit(":", 1)[0] in keys}
    used = {str(int(link["BonusID"])) for row in slots["groups"].values() for link in row["links"]}
    slots["bonuses"] = {k: v for k, v in slots["bonuses"].items() if k in used}
    # Old reviewed deltas belong to the separate awakening feature. Preserve
    # the current PR249 baseline; only wire these 16 existing stable IDs.
    slots["reviewed_primary_keys"] = []
    slots["changed_primary_keys"] = []
    slots["counts"] = {"groups": len(slots["groups"]), "bonuses": len(used)}
    sections["options"] = project("patch523_option_slots", slots, blob)

    relic, blob = source("patch523_relic_subslot")
    card_fields = {"Name", "ID", "BuffCardDeckID", "GradeID", "StartDateTimeID", "EndDateTimeID", "ServerLimitSetID"}
    rows = {}
    for key, row in relic["cards"].items():
        out = {"card": {k: v for k, v in row["card"].items() if k in card_fields},
               "source_card_row_index_zero": row["source_card_row_index_zero"],
               "effects": row["effects"], "summon_binding": row["summon_binding"]}
        if "subslot_buff" in row:
            out["subslot_buff"] = {"ID": row["subslot_buff"]["ID"]}
        rows[key] = out
    relic["cards"] = rows
    for key in ["summon_item", "deck", "buff_groups", "equip_slots", "equip_slot_configs"]:
        relic.pop(key, None)
    sections["relic"] = project("patch523_relic_subslot", relic, blob)
    combat, blob = source("patch523_relic_combat")
    sections["relic_combat"] = project("patch523_relic_combat", {
        k: combat[k] for k in ["relic_subslot_buffs", "invoke_options", "invoke_spells"]
    }, blob)
    result = {"schema": "twilight.card-slots523.v1", "source_commit": COMMIT, **sections}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, separators=(",", ":")) + "\n")
    print(output, output.stat().st_size)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    build(parser.parse_args().output)
