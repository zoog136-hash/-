# PR232 common source-field contract for PR237

Status: the whole-map APIs below are published in PR232 commit `464dae43` and its continuation.
Earlier `f8cf6c2a` is the preceding Aden-only implementation. Do not copy the
loader into PR237 or substitute `source_70`/PC geography.

All seven requested Lands are included in the same ordinary997-Land scope.
Their154 original S32 packets are received, original-byte-SHA checked and included
in the common source pack. The final whole-map actual Main run covers all577
ordinary physical roots (12,558 checks), including each of these seven source
regions. It checks representative physics/blocked cells/boundaries/return/save
and the real restore method after field teardown. It is not native admission,
Totem EXP/growth integration or a new OS process for every region. The full normal input is6,570 originals:6,558 S32 and
12 retained SEG alternatives. Every SEG has a same-stem S32; SEG is preserved
without being parsed as S32. One nine-character Aden filename remains unplaced.

| Native Land.ID | Exact AssetPath | Received S32 |
| --- | --- | ---: |
|43974|`13158/`|24/24|
|43984|`13159/`|15/15|
|47454|`13344/`|21/21|
|44004|`13161/`|52/52|
|44014|`13162/`|2/2|
|48171|`13426/`|36/36|
|48181|`13427/`|4/4|

The current complete source-pack build directory is local; its exact payload is
in the verified17-part private Drive application bundle linked below:
`/workspace/aden-validation/current523-normal-source-pack-all6570-v5/`.
`source523.json`:17,260,837 bytes, SHA256
`6b71f4adb533b7acae6a7327e83af1b1322001a0f67c417bb3fae1bec35d96ca`.
Its original-byte inventory SHA is
`95d3dac855d422c866ecbc4cf21612802944c246d099278870ed87dee2b1cd39`.
All6,558 S32 files use lossless gzip storage with separately checked stored and
original byte identities. The full source records retain per-member original
bytes/SHA, section offsets/counts/hashes and exact native AssetPath.

The complete normal-map tile closure is7,557 TI2 members, computed from every
actual original S32 floor/cover/object reference. All7,557 are included in
`/workspace/aden-validation/current523-all7557-ti2-runtime-pack-v2/`.
`tilepack523.json`:21,156,382 bytes, SHA256
`8a954372eed28e360dc3c7c77f361fba1e0fcc7ee1daa7ffa204f6a679e28482`.
The immutable build directory is local; the same payload is included in the
[verified17-part Drive application bundle](https://drive.google.com/file/d/1j3fb_H18eH-iWsxELmukF2-vHvT9orMN/view?usp=drivesdk).
Its
originals are bounded-decoded on demand; no missing physical frame is padded into
an available frame. Whole-pack checks are15,235 passing Godot assertions across
all7,557 actual originals, including independent Python coverage hashes.

The user's latest priority is whole-map production. Totem-specific progression,
EXP, costs and UI integration remain deferred; the seven source roots below are
ordinary members of this same whole-map pipeline, with no separate loader.

## Runtime identity

Use `world.current523_source_geographic_contract()`; it returns an empty dictionary
outside the actual active generic source field. A valid copied contract includes:

```text
geographic_contract = CURRENT523_S32_OWN_SOURCE_FIELD_V1
native_land_id       = exact native Land.ID
native_asset_path    = exact original AssetPath, including slash
source_snapshot      = 523
source_manifest_sha256
source_inventory_sha256
native_land_table_sha256 = 8778d18d8c23a0ccb0a555f495e056987796232c616dec805dfb4c4d633b0ef9
collision_profile    = CURRENT523_S32_OWN_ALLOWLIST_V1
manifest_identity_verified = true
source_bytes_verified_on_read = true
native_m_rules_verified = false
```

The actual field has both `current523_source_field` and
`current523_generic_field` metadata. Its definition carries `source_map_id`,
`source_asset_path`, `source_manifest_sha256`, per-asset original
`source_sha256`, and the same `geographic_contract` string. Ordinary host
`world.active_map_id` is retained for save compatibility and must not select a
Totem region. Read the current source contract's native ID/AssetPath instead.
The current own rule checks both raw halves and existing floor references;
it is not verified native M collision or an old navigation-grid alias.

## Landing and entry

`prepare_current523_source_landing(raw_root, source_manifest_sha256,
 native_land_id, declared_bounds, selection_policy, allowed_raw_words)` is a pure
geographic query. It does not move the player, authorize admission, change fees,
consume tickets or reinterpret a native restriction.

The default `EXACT_POINT_ONLY` rejects non-singleton/inverted bounds.
`OWN_FIRST_CLEAR_IN_DECLARED_REGION_V1` is an explicitly selected own policy:
scan only the original region, refuse unknown/corrupt/blocked cells, limit the
search and return the first confirmed clear cell. It never turns a rectangle
center into a native fixed arrival or searches outside the declared region.
The returned result labels `native_landing_rule_verified=false` and includes
source packet/hash/raw-pair evidence. The active field also exposes
`choose_source_landing()` and `source_cell_info()` for this same query.

After the calling feature has satisfied its own verified admission/transaction
contract, the existing technical entry API is:

```gdscript
world.open_current523_aden_play(raw_root, tile_root, {
    "navigation_profile":"CURRENT523_GENERIC_S32_OWN_ALLOWLIST_V1",
    "source_manifest_sha256":source_pin,
    "tile_manifest_sha256":tile_pin,
    "native_land_id":native_land_id,
    "source_position":landing.source_components,
    "allowed_raw_words":[0,4,8,12,32],
    "portal_contract":""
})
```

Its name is retained for compatibility; generic mode has no10,000-Land-ID cap.
It validates the actual field, actor position and arrival frame before publishing
state. A false result preserves current runtime/preferences/save. It refuses
opening over another active source session. `close_current523_aden_play()`
returns to the initial host field/physics/position, including after source hops.
Progress uses the existing original writer; the source cursor is a separate
atomic preference. A successful item save is not turned into a failed transaction
merely because cursor preferences cannot be written.

## Original travel restrictions remain caller-owned

The parent verified three Locations, nine Portals and18 LandTeleport joins
against source ZIP `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`.
Keep Currency1=Adena, both0 and50,000 costs, and Teleport14171's
PrerequisiteType1/MinLevel80. All18 have AllowMapTeleport=false and
AllowInterTeleport=false. A geographic preflight or developer source preview
must never become a global free-map-travel permission. PR232 does not own the
Totem fee/admission policy and adds no duplicate native travel catalog.

Explicit Locations are42732 `(32653,32889)` and42742 `(32655,32890)` in43974,
and42772 `(32743,32799)` in43984. Their byte/value provenance does not guarantee
acceptance under the configured own collision rule. A Land is not missing original geography merely because it has no Locations row.
Nonpoint destination bounds remain regions; any chosen safe cell is an own
landing decision, not a recovered original fixed point.

The official M guides describe the [Atlantis gatekeepers](https://lineagem.plaync.com/guidebook/view?title=%EC%95%84%ED%8B%80%EB%9E%80%ED%8B%B0%EC%8A%A4),
[Tikal gatekeeper admission](https://lineagem.plaync.com/guidebook/view?title=%ED%8B%B0%EC%B9%BC+%EC%82%AC%EC%9B%90)
and [Thebes dungeon-menu entry](https://lineagem.plaync.com/guidebook/view?title=%ED%85%8C%EB%B2%A0%EB%9D%BC%EC%8A%A4+%EC%82%AC%EB%A7%89).
These consulted pages do not supply an exact internal landing-cell contract.
Their live schedules/fees are not copied over the pinned523 rows.

## Shared immutable inputs and PR230 definitions

The play controller reuses one successfully verified source catalog and one tile
catalog per current input identity. Each entry rehashes the bounded manifest
before reuse; a changed file or wrong pin is refused without clearing the last
valid cache. Field registries remain independent; original packet bytes are
verified on read and decoded tile atlases remain bounded to32. This avoids
reparsing the17MB catalog for every region/restore.

The existing Settings Land selector also retains one successfully verified
catalog identity. Every refresh still checks directory/pin and current manifest
bytes; only a new valid identity is parsed. A missing path, wrong pin or changed
manifest clears the proposed listing without replacing the previous valid
parsed cache. Same-identity refresh retains the selected logical ID. A rejected
candidate, different directory/pin or changed selected ID clears the uncommitted
explicit-coordinate checkbox; stored cursors are preserved. This UI cache and
the play controller cache are separate objects;
neither shares mutable per-field state or bypasses original checks on read.


PR232 reuses PR230's unchanged `patch523_world_links.gd` at owner commit
`5d1b1bdb0b00b855ffd87036a2e5f6b274ffa3eb`, Git blob
`0fcb00cba1d6ca7e5f2ea2e12aee187d622551e0`. It does not copy a second compiler or
original catalog. `current523_source_portal_provider.gd` adapts that owner's
verified Land shards into the existing geographic provider methods.

Use `world.bind_current523_source_definition_pack(directory, expected_sha256)`
or the owner's existing launch arguments:

```text
--patch523-world-links=/private/world-links
--patch523-world-links-sha256=2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90
```

Requested missing/corrupt definitions block optional source entry. Failed binding
updates preserve the previous valid binding. A caller-owned replacement/unbind
clears the previous genuine-pack status, so launch preparation cannot silently
reuse that stale status. This verifies the actual pack;
passing a pin to the lower-level caller-owned provider API alone is not proof.
The adapter retains up to4 verified Land instances and returns copied complete
original Portal/SourceLand/TargetTerritory/TargetLand rows and the unchanged
native definition contract. Exact Land.ID and AssetPath remain separate.

Native Land restrictions and unresolved time/weekly/competition conditions hold
the own manual action and appear as `원문 조건 보류` in the existing Settings UI.
Territory-scoped rules are evaluated only within their declared scope; unknown
scope/type stays held. Current523 exactType8/NoTeleport andType13/NoTeleportCome,
Unit20=TrueFalse, Value0 with all three original parameters present andzero are
copied into `declared_inactive_restrictions` with `side=source/target`; they are
not active holds. Unknown type/unit, missing/nonzero parameters or unresolved
scope cannot use that exception. The original Unit table and all26 compiled
condition tables were checked against the complete original Content archive;
this adapter does not add another runtime catalog. The existing UI shows the
inactive declaration alongside other remaining holds. This is no authorization,
fee waiver or verification of automatic entry. Native activation, cost and region arrival semantics are
not invented. Separate LandTeleport costs/prerequisites remain separate raw
contracts; a shared target does not assign their fee to a Portal. The provider
never changes native `activation_known=false` or `travel_enabled=false` into
true. The optional button remains an explicitly labelled TWILIGHT own manual
geographic action; this is not automatic original-M portal admission.

## Source-point navigation requests

`world.current523_source_portal_navigation_ticket(portal_id)` returns an
in-memory request identity for the active generic field and current actor.
`world.walk_to_current523_source_portal(portal_id, ticket)` validates the field
instance, definition generation, manifest, native Portal row and exact actor
position, then queues an ordinary physical walking path to the declared source
cell. It refuses stale/missing requests, blocked endpoints and incomplete routes
before changing movement. Tickets are ephemeral; do not persist or reuse them
after movement, field teardown or definition rebinding. They are not native
admission credentials. The existing Settings button consumes the same contract;
arrival does not activate a portal or use the separate manual transition API.

## Own path-search budget

The separate play options accept `path_search_limit`, an integer1..65536 for
SOURCE/GENERIC mode, default8192 for existing preferences. This configures the
existing bounded search, not allowed cells, native admission or trigger geometry.
A live change is refused; use a new validated entry. The same value is passed
to a prepared target field, so a source transition retains the exact own policy.
The Settings control, atomic preference readback and new-process restoration
consume that same value. No pack/manifest rebuild or game-save migration is
needed. Search failure does not establish native collision or grant permission
to substitute a partial path/nearby destination.


## Direct destination and gesture lifecycle

An invalid new direct destination in active current523 source play cancels the
superseded click path, zeros its velocity and shows a no-confirmed-route message.
It does not change the cell predicate or invent a nearest-cell fallback. Stale
Portal-navigation ticket refusal continues to preserve the accepted path.

Source close and a successful generic source-field commit cancel held world
pointer gestures, since the preserved host map ID alone cannot distinguish
those fields/cameras. All fallible target checks and checkpoint persistence
remain before commit. A failed transition preserves the valid path and gesture.
