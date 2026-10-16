# TWILIGHT: nearest-level combat fallback (L1J source)

Source: user-provided a3.zip (2024 L1J SQL + BIN effective stats). **These are not official Lineage M values.**

## Rules

- 318 TWILIGHT species: 107 name-matched monsters unchanged; nearest-level fallback only for 211 name-unmatched species.
- 33 TWILIGHT runtime bosses use only L1J NPC records tagged as bosses. 178 normal monsters use only non-boss records.
- Absolute level gap is minimized. If multiple donors have that same gap, select a representative single donor closest to median HP/AC/MR at that level.
- Factor = TWILIGHT level / selected source level. HP = max(30, round(source HP * factor)). AC and MR use the same factor.
- L1J positive AC cannot be stored without TWILIGHT's existing positive-to-negative conversion changing its meaning, so preserve TWILIGHT's original AC in those 8 cases.
- Attack is an **estimate**, based on the average of the L1J NPC melee/ranged damage formula before armor, status, and skills; magic skill damage is not reproduced.
- Melee and ranged accuracy use the level*1.2 NPC physical-hit base proxy, not a percent success rate. Original TW magic accuracy is retained where a magic profile is known.
- The monster_catalog.gd loader only applies each stat override when the current record's level and original HP equal the reviewed baseline values.
- AI, skills, loot, respawn, visuals and boss classification are untouched.

## Cautions before merge

- Source boss levels: 10–120; source normal levels: 1–102. Higher-level TWILIGHT monsters are **extrapolations**.
- Some boss HPs rise from thousands to millions; e.g. level 194 boss 50,176 to 2,425,000. This is intentional for the requested linear interpolation/extrapolation but may break game balance.
- The nearest source level does **not** establish that the TWILIGHT monster is the same species as the donor.
- Existing boss-in-normal-spawn discrepancies (흑장로, 데스나이트) are not part of this change.
- Validate in Godot, especially hit-rate balance and high-level combat durations, before merging.

Run: python3 tools/test_l1j_level_fallback.py
