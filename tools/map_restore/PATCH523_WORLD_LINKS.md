# Cumulative523 map definition links

The Main game's existing monster creation path and map-screen information window
can use a separately installed cumulative523 definition pack. The optional
`base508_game_field.gd` also exposes the source APIs. They bind the original
`Land.ID` and exact `AssetPath`, rather than matching TWILIGHT map IDs, NPC names,
or numeric IDs from different namespaces. Existing host positions, counts and
respawn policies and saves are retained. This does not replace the source-map
renderer or merge PR #222.

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

Append these options to an ordinary game launch to enable the latest-definition
gate for existing explicit source-M encounters and the original-data UI:

```text
--patch523-world-links=/private/patch523-world-links
--patch523-world-links-sha256=2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90
```

The existing optional `--base508-source-test` mode can use the same options with
its verified source-pack/registration/legacy-reference arguments.
`base508_game_mode.prepare()` binds the catalog after the field's existing source
and navigation validation. The field exposes `portal_evidence()`,
`portal_context(portal_id)`, `spawn_evidence(pack_id)` and
`spawn_conditions(pack_id)`. The underlying `world_links.context_rows(table)`
returns the preserved raw condition/type/date rows. Returned evidence is copied
so consumers cannot alter source records through a query. A rejected binding
update preserves the previous valid binding; a successful source-field
reconfiguration clears the previous Land binding.

## Actual generation and UI paths

Open **Map → Portal/Spawn information** (`지도 → 포탈·출현 정보`). The window shows
current host generation slots, Aden's original spawn definitions and directed
portal destinations. Name/number search includes explicit member NPC/view/pack
identities. Original conditions and held states are displayed; source Portal
travel stays disabled. Without a verified definition pack, current host state
remains visible and original-data modes are disabled. Inspecting the window does
not move actors or write saves.

`FieldPopulation._spawn_slot()` checks resolved native identity before allocating
a node. `Monster.setup()` returns success/failure and independently checks incoming
and resolved records, covering direct, summoned and pooled lives. Rejected actors
stop physics/input/collision, clear prior visual/loot owners and are disposed
without death/reward events. Population, summons and the world direct-spawn
caller check this result. Immutable session holds retain an infinite internal
wait rather than inventing a native respawn period. Wholly held boss encounters
are checked before initializing/migrating their existing clocks, including delayed
or no-floor attempts; later rejected choices roll back that attempt's state.

The policy rechecks the exact tuple against authoritative base508 data and523
Land/AssetPath/class/view/pack/Territory, effective contextual level, Sprite and
combat/occupancy contracts. Explicit0 is excluded; other flags, nonzero server
sets and schedule/daynight/WorldBoss contexts are held. Changes needing a new
combat/coordinate adapter are held. Original pixels still need the existing
renderer guard; an applied rejection cannot fall back to another actor.
Separate metadata records the523 gate beside the retained base508 combat
identity and explicit host compatibility.

The14 existing host-Aden replacement contracts pass these definition checks.
Thirteen use source Land4; Kurts60303 intentionally uses source Land0 through its
existing host-Aden adaptation. Source Land is never inferred from host map name.
No new production encounter, source position, count or clock is added.

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
This implementation gates existing explicit host encounters and exposes
definitions through the field/UI. It does **not** add automatic geographic M
spawning or activate original Portal travel. It does not assign arbitrary actors
to missing packs. Set274 remains unresolved where no ServerLimit rows exist. UI categories
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
Also run `tests/patch523_spawn_policy_test.gd` for definition/identity/condition
rejections (the same launch options check all14 actual existing contracts).
`tests/patch523_spawn_main_test.gd` starts actual Main and checks pre-node holds,
delayed/no-floor boss state, direct/pooled rejection, the actual summon helper
with a named floor fixture, save/inventory/boss preservation and map UI. Under
OpenGL, `--patch523-capture-dir=/private/evidence` saves actual screenshots.
These are focused desktop checks, not original-M pixel/AI/device approval.
Retrieval of the existing optional monster pack failed at Library helper
tools/list HTTP401 in this consumer; positive original-M pixel execution is
therefore not claimed. Current Main's existing source3 actors and UI did run.

The focused game-field test is an adapter harness, not a terrain or actual
original-map playthrough. The cumulative523 verifier compares every exported
Land/Territory/portal/relation and every per-Land class/context row against the
original with multiplicity; all 26 global condition tables are compared directly.
The repository's required Main/save/resource gates remain in force. Device and
full visual/gameplay audits are separate, unperformed claims unless reported.
