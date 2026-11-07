# Current523 NPC source-region receiver

Status: map-owned receiver implemented; producer/adoption extension is pending
with the PR282 data owner. These changes have not been compiled, executed,
rendered or tested, per the current user instruction. No resource pack changes.

## Existing data-owner ABI

- `scripts/monsters/current523_npc_input_projection.gd`:
  `build(host_npc_ids: Array) -> Dictionary` builds the typed closure for admitted
  NPC identities. It does not currently accept a Land/environment selection.
- `scripts/monsters/patch523_npc_catalog.gd`:
  `configure_original() -> bool`, `_admit_original_actor(source: Dictionary) -> bool`,
  `project_actor_record(record: Dictionary) -> Dictionary` are the existing
  identity/admission path. `_publish_original(candidate: Dictionary) -> void`
  replaces the registry, rebuilds owner indexes and its `source_model_sha256`.
  New environment input must survive subsequent NPC admission/rebuilds without
  replacing existing NPC admission or changing the source identity.
- Registry-only lookup: `row(table: String, id: int) -> Dictionary`,
  `owned(table: String, id: int) -> Array`, `buff_details(id: int) -> Dictionary`,
  `environment_buffs(land_id: int) -> Array`, and
  `scalar(table: String, id: int, name: String, unit: String = "", fallback: float = 0.0) -> float`.
  Empty admitted sets are authoritative, not a request to scan the whole archive.

No new producer/adoption method is asserted here. The data owner must provide
its actual signature and input identity before map-side admission can be wired.
Required typed rows are exact `Land`, its `LandAttribute`/`LandAttributeType`,
`Unit`, optional `Territories`, and the referenced `BuffClass` dependency closure.

## Map receiver

`current523_source_field.source_region_context(point: Vector2, admitted_land: Dictionary) -> Dictionary`
requires the admitted complete Land row to equal the selected field's original
Land declaration. `definition.source_map_id`, `source_asset_path`, actual
`source_asset`, and manifest identity must agree. AssetPath comes from this
relationship; it is never constructed as `str(Land.ID) + "/"`.

The returned dictionary contains schema/snapshot, exact Land and AssetPath,
integer source cell, catalog and Land-table pins, original member/hash/location
provenance, and the current field instance. Outside/unloaded/unproven cells
return an empty dictionary. The existing read-only source-cell projection is
reused; its TWILIGHT coordinate policy is not native-client semantic proof.

`patch523_npc_extensions.bindings(actor)` uses that context only for the current
source field and its actual current population's admitted M actor. The catalog
source identity, NPC identity/Sprite/DescId and current population field must
match. Previous-field actors and target coordinates cannot supply this context.
Existing host/environment/native-region opt-ins and suppression remain intact.

Only admitted `NpcBuff` type 504, Unit 16 `BuffClassID`, exact BuffClass reference,
zero Param1/2/3, and the selected Land are accepted. Territory 0 is the declared
Land-wide binding; otherwise the admitted territory must belong to that Land
and contain the exact integer source cell within inclusive valid bounds.
Unsupported forms remain absent. No NoBuffGroup conversion, whole-source
fallback, new status formula, duration, ordering, entry permission or spawn is
introduced. Existing effects and lifecycle owners consume the resulting binding.

Until the data owner's real environment production/adoption ABI is supplied,
the current original NPC input has no admitted Land/environment closure and
this receiver deliberately yields no new original-region effect. This is not
completed NpcBuff activation or observed game consumption.
