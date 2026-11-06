# Current523 NPC source-region receiver

Status: map-owned selection, production/adoption call and receipt-gated receiver
are connected locally against PR282 commit
`21bcd2d1325fffcb27923ffccf3a59b1542e1149`. Its producer/catalog code was read
from immutable Git objects, not installed/merged in this map checkout. No
data-owned files changed. These changes have not been compiled, executed,
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

The actual production/adoption ABI is pinned below. Required typed rows are
exact `Land`, its `LandAttribute`/`LandAttributeType`,
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

Until the compatible data code is integrated and ordinary source input is ready,
this receiver deliberately yields no new original-region effect. Connected code
is not completed NpcBuff activation or observed game consumption.

## Selected-field production/adoption call site

The map provider's `npc_environment_selection_for_land(land_id, exact_asset)`
prepares a map-owned selection quote from the pinned production definition,
not from the initially empty NPC catalog. It contains the exact Land row,
AssetPath, explicit NpcBuff LandAttribute IDs and their original rows/territories.
Only the already supported type 504 / BuffClassID / zero-parameter forms qualify.
The quote schema `twilight.map.npc-environment-selection.v1` is a map selection
contract; it is not the data producer's input schema or adoption receipt.

At committed generic source-field entry and certain successful travel,
`_prepare_selected_npc_environment(field, point)` checks the actual selected field,
current player point, complete Land, AssetPath, source-location proof, definition
pin and provider generation. It stores the prepared quote in field metadata
`current523_npc_environment_selection`; errors remain held selection metadata.
No actor/frame loop performs production or adoption. Failed/uncertain travel
does not run this successful-transition preparation.

The pinned data code exposes `build_land_environment(land_id, asset_path,
land_attribute_ids)`, `adopt_land_environment(candidate)`,
`admit_land_environment(...)`, and `registered_land_environment(land_id, asset_path)`.
The map calls build then adopt so it can first compare the exact Land, selected
LandAttribute/type rows and Territories from the produced closure with its
production-map selection. Empty IDs are passed explicitly, never expanded from
an empty catalog. The map never configures/replaces the NPC registry itself.

The candidate must be `patch523_npc_land_environment_input`, schema 1,
input_kind `twilight.current523.land-environment-input.v1`, patch523, with the
catalog's complete original archive identity and exact sorted selection.
The success receipt must be `twilight.current523.registered-land-environment.v1`.
The map compares it with the actual `registered_land_environment` descriptor,
selected Land/AssetPath/IDs, complete original identity, runtime candidate JSON
SHA, registry SHA/revision and unchanged NPC model/admitted identities/combat
generation. Empty/failed/mismatched results hold in
`current523_npc_environment_admission` metadata. Optional input failure does not
rewrite a committed travel transaction, costs, settings or prior registrations.

The actor receiver also requires that successful selected-field admission,
re-reads the actual registered descriptor, and checks the selected input hash
and IDs before existing bounds/effect processing. The input hash stays independent
of later NPC model rebuilds or unrelated environment registry revisions. No
per-actor/frame build/adopt call was added.

Actual effects require existing `host_enabled`, `environment_enabled` and
`native_regions` settings, plus a living admitted M actor in the actual current
population field. Initial source-input failure remains held until ordinary input
readiness and a new legitimate field entry; no polling/rebuild/installation loop
was added. A registered input alone does not create a population or an effect.

The pinned producer currently rejects `land_id <= 0`; original logical Land 0
therefore remains a held `land_asset_path_identity_mismatch` at that data
boundary. No substitute Land identity is fabricated. The data owner must resolve
that narrow rule if Land 0 registration is required.
