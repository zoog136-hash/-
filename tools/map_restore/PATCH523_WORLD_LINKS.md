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

The **Current game portals** (`현재 게임 이동석`) mode lists the active host
field's existing triggers (38 in current Aden). Select an entry and use
**Walk to portal** (`이동석으로 이동`) to queue the ordinary manual walking path.
The existing arrival trigger performs the existing travel; this action never
sets the player's position. It rejects stale field/portal data, invalid arrival
positions, blocked paths, routes intercepted by another trigger, automatic
hunting, movement impairments and active charge skills before changing movement.
Unreachable routes preserve the previous movement/pickup state. Destination map
loading and any original travel restrictions remain enforced by the existing
travel code. The actual Main test covers one authored same-map portal; other
destinations are not claimed as individually exercised. This host mode works
without the optional M definition pack and does not activate native M portals.

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
`tests/host_portal_navigation_test.gd` checks navigation rejection/state
preservation. `tests/host_portal_gameplay_test.gd` starts Main without the M pack,
clicks the actual map UI, walks with player physics into an existing trigger and
checks the existing authored arrival, save/inventory/boss preservation and a real
host monster's damage/death/reward/respawn lifecycle. The test advances the
existing respawn clock; it adds no production placement or timer.
The older Library handoff download still fails at helper tools/list HTTP401.
An independently authorized Drive source671 installer now supplies the existing
14 contracts'508 source pixels. Its40 parts and complete ZIP SHA/CRC were
verified: 1,339,066,288 bytes, SHA256
`88b3f4470664571f1f6b2894602fa7a6895cc0443a9ac2f5c914f206ba2b876e`.
This is not an assertion that the older handoffs are identical or that508 art
is the latest523 art. The original671 installer remains in its existing private
Drive storage; no source art goes into this repo.

Restore a bounded private test subset from that complete installer:

```sh
python3 tools/monsters/restore_base508_host14_pixels.py \
  --source-zip /private/base508-monsters-source671-install.zip \
  --output /private/host14-pixels
```

The result retains14 exact existing contracts,184 original SP2 packets and their
unchanged track files:199 files /13,869,752 bytes. Manifest SHA256 is
`5eff1f07482988ca7a5606a174ac4fba35785496ba176a9e9b6a0212d58b1a82`.
Use a fresh isolated profile and append
`--lineagem-monster-pack=/private/host14-pixels/manifest.json` beside the523
options. Keep any existing larger installation; this subset is not its upgrade.
The compiler verifies the pinned complete source, inventories, selected payload
hashes, NPC/Sprite/view/link pairs and each referenced model/pixel. Its selected
files reproduce identically. It neither adopts other PR code nor adds an encounter.

`tests/base508_monster_host_ports_test.gd -- --check-game-actors` checks all14
actual Monster replacements with the523 options, native HP/level, absent
unverified loot, body texture decoding, five roles/eight directions and pooled
return to legacy state. `tests/patch523_native_population_main_test.gd` starts
actual Main with the same private flags and exercises an existing native orc
slot, its live admission UI, real damage/death and existing respawn service.
The role/direction checks decode560 first-frame body samples. Host-compatible
playback remains labelled; complete
native FPS/blend/AI or native geographic placement are separate claims.

## Current category rules and the next resource contract

Automatic target acquisition now consumes the current523
`NpcCategory.IsAutoSelectable` boolean. It checks the automatic distance/path
scanner, cached target and automatic weapon fallback. Manual nearest selection,
explicit ordered selection, manual attack/skill targeting and damage reception
retain their existing behavior. An explicitly selected actor remains the manual
priority while AUTO is on; this flag is an acquisition rule, not attack immunity.
The guard summon's automatic fallback follows the same rule. Explicit summon
designation and retaliation remain available, bound to that actor's current
`life_id` and current monster root so pool reuse cannot inherit an old exception.
Monster setup/retirement/rejection clear the category metadata. Legacy actors
retain their previous default. Source data and character-save schemas are unchanged.

The map inspector shows the original automatic-selection rule beside live native
actors and source class definitions. Current flags come from523 category rows;
the retained508 source context and pixels stay separate. No guessed setting is
needed for these known booleans.

The next verified resource is NPC93102 / Sprite26579, exact view554792 / link200832,
source Land4. Its native contract and category15 pass523 checks. Restore only its
additional files while reusing the unchanged existing14 subset:

```sh
python3 tools/monsters/restore_base508_host14_pixels.py \
  --source-zip /private/base508-monsters-source671-install.zip \
  --base-subset /private/host14-pixels \
  --extra-context 93102:554792:200832 \
  --output /private/contract15-pixels
```

The combined subset has15 records,211 SP2 packets and227 files /20,457,157 bytes.
Manifest SHA256 is
`4e2cd7aca0cdab69856d0623b598ec38c8a3f1c0c767f7bbb563c3f42e3cac91`.
It shares198 immutable base assets, writes28 new assets and a separate manifest,
and reads zero existing base assets from the source ZIP. Source metadata and all
six guard contexts remain unchanged. The guard is verified through the existing
factory/renderer/targeting API in a controlled Main probe; no new production
encounter, position or activation rule is added.

`patch523_extra_target_contract_test.gd` checks the new contract and40 first-frame
role/direction body samples. `auto_selection_order_test.gd` covers automatic versus
manual acquisition, cached targets, summon exceptions and stale pooled lives.
`patch523_auto_target_main_test.gd` exercises actual AUTO/manual UI, source
inspection, guard rendering, pooled category replacement and byte-identical forced
character save. A resource bundle can contain this subset under `monsters/` and
the separately verified definition pack under `world-links/`; extract outside the
project and point the two launch arguments at those directories. It still needs
the existing TWILIGHT executable/code and verified map pack. Drive storage alone
does not install or activate it. Preserve larger monster installations; this
bounded bundle is not their replacement.
`package_patch523_resource_bundle.py` verifies both component manifest pins and
their complete resource closure, then packages only runtime files, an inventory
and launch instructions. Reports and captures are excluded. Resource delivery
and source backups remain separate from the code PR and from actual game load.

The focused game-field test is an adapter harness, not a terrain or actual
original-map playthrough. The cumulative523 verifier compares every exported
Land/Territory/portal/relation and every per-Land class/context row against the
original with multiplicity; all 26 global condition tables are compared directly.
The repository's required Main/save/resource gates remain in force. Device and
full visual/gameplay audits are separate, unperformed claims unless reported.
