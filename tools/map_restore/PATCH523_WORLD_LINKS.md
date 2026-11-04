# Cumulative523 map definition links

The Main game's optional `base508_game_field.gd` can now bind a separately
installed cumulative523 portal/spawn definition pack. It binds the original
`Land.ID` and exact `AssetPath`, rather than matching TWILIGHT map IDs, NPC names,
or numeric IDs from different namespaces. Ordinary gameplay placements and saves
are unchanged. This does not replace the source-map renderer or merge PR #222.

## Build the private data pack

The source is `lineagem_patch523_all_content_validated_and_508_520_deltas.zip`,
SHA256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`.
The compiler rejects another source hash and an existing output directory.
Original Content rows and generated runtime data stay outside the public repo.

```sh
python3 tools/map_restore/build_patch523_world_links.py \
  --source-zip /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  --output /private/patch523-world-links
python3 tools/map_restore/verify_patch523_world_links.py \
  --source-zip /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  --pack /private/patch523-world-links
```

The deterministic output has 1,067 files / 22,859,928 bytes. Its `manifest.json`
SHA256 is `2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90`.
This is a definition pack, not a terrain/art pack. Each Land shard and the
separate condition tables have byte counts and SHA256 checks. Consumers require
the manifest hash explicitly; a missing/corrupt/mismatched requested pack blocks
the optional map before Main registers it.

Append these options to the existing `--base508-source-test` launch and its
verified source-pack/registration/legacy-reference arguments:

```text
--patch523-world-links=/private/patch523-world-links
--patch523-world-links-sha256=2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90
```

`base508_game_mode.prepare()` binds the catalog after the field's existing source
and navigation validation. The field exposes `portal_evidence()`,
`portal_context(portal_id)`, `spawn_evidence(pack_id)` and
`spawn_conditions(pack_id)`. The underlying `world_links.context_rows(table)`
returns the preserved raw condition/type/date rows. Returned evidence is copied
so consumers cannot alter source records through a query. A rejected binding
update preserves the previous valid binding; a successful source-field
reconfiguration clears the previous Land binding.

## What these links establish

- All 1,065 original Lands, 1,150 directed portals and 14,423 spawn Territory
  relations are retained, with original coordinates and row multiplicity.
- Aden is exactly Land4 / `Aden/`: 93 outgoing portals, including 56 internal
  moves; 1,343 spawn relations; 3,105 class-view rows. Its 142 unresolved packs
  remain unresolved. The global count is 411; shared packs are not double-counted.
- `IsSpawn=0` remains an explicit excluded definition; 1 is a definition whose
  runtime activation is unknown. Other/unknown values remain distinct.
  Conditional class levels, server Sets, repeated schedules, KR/TW service
  regions, day/night rows, WorldBoss rows and original Probability survive.
- Schedule, weekly entities, regional date tables, Land restrictions/time limits,
  separate LandTeleport costs/prerequisites and CompetitionDungeon definitions
  remain separate layers. A route sharing a portal target does not establish
  that the portal consumes its cost or applies its prerequisite.
- Inverted Territories are not normalized. Region targets are not replaced by
  their center. No reverse portals or same-number NPC/pack links are invented.

## Remaining boundaries

Content does not supply actual spawn counts, selected instance positions,
respawn periods, portal trigger geometry or automatic activation/arrival rules.
This implementation therefore exposes definitions through the actual game-field
API; it does **not** automatically spawn monsters or activate travel. It neither
replaces existing authored encounters nor assigns arbitrary actors to missing
packs. Set274 remains unresolved where no ServerLimit rows exist. UI categories
and occupancy hints are not terrain collision or proof of a current boss spawn.

The data snapshot is patch523; existing optional terrain packs may be base508.
An ID/AssetPath binding is definition namespace alignment, not proof that terrain,
actor-foot projection or every coordinate remained physically valid across
snapshots. Native trigger/arrival/instance policy and physical placement remain
follow-up work with explicit source/runtime evidence.

## Focused verification

```sh
python3 -m unittest discover -s tests -p test_patch523_world_links.py -v
godot --headless --path . --script tests/patch523_world_links_test.gd -- \
  --patch523-game-field \
  --patch523-pack=/private/patch523-world-links \
  --patch523-sha=2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90
```

Use isolated `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` for Godot.
The focused game-field test is an adapter harness, not a terrain or actual
original-map playthrough. The cumulative523 verifier compares every exported
Land/Territory/portal/relation and every per-Land class/context row against the
original with multiplicity; all 26 global condition tables are compared directly.
The repository's required Main/save/resource gates remain in force. Device and
full visual/gameplay audits are separate, unperformed claims unless reported.
