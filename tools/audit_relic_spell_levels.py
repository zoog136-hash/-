#!/usr/bin/env python3
"""Independently audit the authorized patch523 relic level-rule source bytes.

This exports hashes and counts only. The original tables/archive stay private.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import zipfile

SOURCE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
SOURCE_BYTES = 25031173


def audit(source, catalog):
    if source.stat().st_size != SOURCE_BYTES or hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise ValueError("Expected the verified current patch523 archive")
    hashes = {}
    with zipfile.ZipFile(source) as archive:
        def table(name):
            raw = archive.read("content/" + name + ".json")
            hashes[name] = hashlib.sha256(raw).hexdigest()
            return json.loads(raw.decode("utf-8-sig"))["rows"]

        def index(name):
            rows = table(name)
            out = {row["ID"]: row for row in rows}
            if len(out) != len(rows):
                raise ValueError("Duplicate ID in " + name)
            return out

        cards, bonuses, types = index("BuffCard"), index("Bonus"), index("BonusType")
        units, applications = index("Unit"), index("BonusApplicationType")
        mappings, links = index("BuffCardTranscendence"), index("BuffCardTranscendenceBonus")
        groups = collections.defaultdict(list)
        for link in links.values():
            bonus = bonuses[link["BonusID"]]
            typ = types[bonus["BonusTypeID"]]
            assert typ["Name"] == "SpellLevelUp" and units[typ["UnitID"]]["Name"] == "Value"
            assert applications[bonus["BonusApplicationTypeID"]]["Name"] == "Grade"
            assert bonus["Value"] == 1 and bonus["BonusApplicationTargetID"] in (1, 4, 5, 32)
            groups[link["TranscendenceGroupID"]].append(link)
        current = {row["source_card_id"]: row for row in json.loads(catalog.read_text())["catalog"]["성물"]}
        matched, unregistered, used_groups = [], [], set()
        identities = set()
        for mapping in mappings.values():
            card_id = mapping["BuffCardID"]
            assert card_id not in identities
            identities.add(card_id)
            card = cards[card_id]
            assert card["BuffCardDeckID"] == 98 and mapping["TranscendenceGroupID"] in groups
            used_groups.add(mapping["TranscendenceGroupID"])
            if card_id not in current:
                unregistered.append(card_id)
                continue
            old = current[card_id]["source_original_card"]
            assert current[card_id]["sourceId"] == f"m508:98:{card_id}"
            for key in ("ID", "BuffCardDeckID", "BuffClassID", "GradeID", "ServerLimitSetID", "StartDateTimeID", "EndDateTimeID"):
                assert old[key] == card[key], (card_id, key)
            matched.append(card_id)
        assert (len(mappings), len(links), len(matched), unregistered) == (59, 13, 58, [25162])
        return {"source_bytes":SOURCE_BYTES, "source_sha256":SOURCE_SHA256,
                "source_table_sha256":hashes, "mappings":len(mappings), "bonus_links":len(links),
                "bonus_groups":len(groups), "matched_current_cards":len(matched),
                "unregistered_source_cards":unregistered, "unmapped_bonus_groups":sorted(set(groups) - used_groups),
                "combat_values":"pending native skill identity and per-level value connection",
                "cost_probability_or_upgrade_operation":"not declared by these tables"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--catalog", type=Path, default=Path("data/lineagem_base508/cards.json"))
    args = parser.parse_args()
    print(json.dumps(audit(args.source, args.catalog), ensure_ascii=False, indent=2))
