# PR232 common source-field contract for PR237

Status: the whole-map APIs below are published in PR232 commit `464dae43` and its continuation.
Earlier `f8cf6c2a` is the preceding Aden-only implementation. Do not copy the
loader into PR237 or substitute `source_70`/PC geography.

All seven requested Lands are included in the same ordinary997-Land scope.
Their154 original S32 packets are received, original-byte-SHA checked and included
in the common source pack. The full normal input is6,570 originals:6,558 S32 and
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

The current complete source pack is LOCAL_ONLY:
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
