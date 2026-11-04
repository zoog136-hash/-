"""Inspect exact523 timing/composition evidence without inventing execution.

Print a local diagnostic; do not publish the original tables. The compiled
runtime pack stays unchanged. Missing schema is evidence of a blocker in this
snapshot, not proof that the original client has no such implementation.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import zipfile

from build_player_skills523 import SOURCE_SHA256, digest, unique


def audit(source: Path, bindings_path: Path):
    if digest(source.read_bytes()) != SOURCE_SHA256:
        raise ValueError("expected exact cumulative523 source ZIP")
    bindings = json.loads(bindings_path.read_bytes())
    with zipfile.ZipFile(source) as archive:
        if archive.testzip() is not None:
            raise ValueError("source ZIP CRC failed")
        index = {r["path"]: r for r in json.loads(archive.read("index.json"))}

        def table(name):
            path = f"content/{name}.json"
            raw = archive.read(path)
            meta = index[path]
            data = json.loads(raw)["rows"]
            if (digest(raw), len(raw), len(data)) != (meta["sha256"], meta["bytes"], meta["row_count"]):
                raise ValueError(f"unverified source table: {name}")
            return data

        spells = unique(table("SpellClass"), "SpellClass")
        nodes = unique(table("SpellNode"), "SpellNode")
        bonuses = unique(table("Bonus"), "Bonus")
        types = unique(table("BonusType"), "BonusType")
        units = unique(table("Unit"), "Unit")
        links = defaultdict(list)
        for row in table("SpellBonus"):
            bonus = bonuses[row["BonusID"]]
            kind = types[bonus["BonusTypeID"]]
            links[row["SpellClassID"]].append({"name": kind["Name"], "unit": units[kind["UnitID"]]["Name"],
                "value": bonus["Value"], "min_spell_level": row["MinSpellLevel"],
                "application_type": bonus["BonusApplicationTypeID"], "application_target": bonus["BonusApplicationTargetID"]})
        absent = [name for name in ("SpellNodeType", "SpellNodeTarget", "ConditionType", "ConditionChangeSpell", "Restoration", "MultipleSpellGroup")
                  if f"content/{name}.json" not in index]
        selected = {r["spell_id"] for r in bindings["skills"].values()}
        graph = {}
        for root in (54703, 69601, 95662, 95102, 82, 349, 18304):
            pending, seen, edges, restorations = [root], set(), [], []
            while pending:
                spell_id = pending.pop(0)
                if spell_id in seen:
                    continue
                seen.add(spell_id)
                for entry in links[spell_id]:
                    if entry["name"] in ("SpellClassID", "NextSpellClassID") and entry["unit"] == "SpellClassID":
                        child = int(entry["value"])
                        edges.append({"from": spell_id, "to": child, **entry, "present": child in spells})
                        if child in spells:
                            pending.append(child)
                    if entry["name"] == "RestorationID":
                        restorations.append({"spell_id": spell_id, **entry})
            graph[str(root)] = {"spell_ids": sorted(seen), "edges": edges, "unresolved_restorations": restorations}
        native_node_refs = {int(spells[i]["SpellCompositionNode"]) for i in selected if spells[i]["SpellCompositionNode"]}
        all_compositions = {int(row["SpellCompositionNode"]) for row in spells.values() if row["SpellCompositionNode"]}
        result = {"source_zip_sha256": SOURCE_SHA256, "source_table_count": len(index),
            "bound_screen_items": len(bindings["skills"]), "unique_bound_spell_ids": len(selected),
            "bound_categories": dict(sorted(Counter(spells[i]["SpellCategoryID"] for i in selected).items())),
            "missing_definition_tables": absent, "referenced_composition_nodes": sorted(native_node_refs),
            "direct_id_join_unresolved": sorted(native_node_refs - nodes.keys()),
            "composition_to_node_id_join_confirmed": False,
            "all_composition_values": len(all_compositions),
            "direct_id_matches_across_all_compositions": len(all_compositions & nodes.keys()),
            "time_distance_columns": [name for name in spells[349] if any(token in name for token in ("Range", "Radius", "Delay"))],
            "typed_delay_bonuses": [{"name": row["Name"], "unit": units[row["UnitID"]]["Name"]}
                                    for row in types.values() if row["Name"] in ("NextSpellDelay", "SpellCastDelayIncreaseAbsolute", "EachSpellCastDelayIncreaseAbsolute")],
            "timing_constant_names": [row["Name"] for row in table("ConstantData") if any(token in row["Name"] for token in ("CastDelay", "GroupDelay", "ComboSpellWarmUp"))],
            "selected_graphs": graph,
            "interpretation": "SpellCompositionNode to SpellNode.ID is not a proven FK: only16 of85 composition values match IDs. The eight unresolved direct joins are not proven missing native node rows. User-authorized estimates implement named skill behavior separately from the original graph. Typed delay modifiers do not establish base delay conversion or contact/cooldown priority."}
        return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-zip", type=Path, required=True)
    parser.add_argument("--bindings", type=Path, default=Path(__file__).resolve().parents[2] / "data/skills/player_skills523_bindings.json")
    args = parser.parse_args()
    print(json.dumps(audit(args.source_zip, args.bindings), ensure_ascii=False, indent=2))
