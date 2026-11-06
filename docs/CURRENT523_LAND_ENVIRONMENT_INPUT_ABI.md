# Explicit current523 Land NpcBuff input — unverified

This is the PR282 data producer/registry boundary for the map-owned PR285 source-region receiver. No tests, compilation, game, render, CI, pack build, installation or effect activation was performed.

## Actual API

`scripts/monsters/current523_npc_input_projection.gd` instances expose:

```gdscript
build(host_npc_ids: Array) -> Dictionary # existing NPC signature/output retained
build_land_environment(land_id: int, asset_path: String, land_attribute_ids: Array) -> Dictionary
```

`scripts/monsters/patch523_npc_catalog.gd` exposes:

```gdscript
build_land_environment(land_id: int, asset_path: String, land_attribute_ids: Array) -> Dictionary
adopt_land_environment(candidate: Dictionary) -> Dictionary
admit_land_environment(land_id: int, asset_path: String, land_attribute_ids: Array) -> Dictionary
registered_land_environment(land_id: int, asset_path: String) -> Dictionary
environment_attributes() -> Array # registered roots only; no archive discovery
```

`build_land_environment` returns an empty dictionary with producer.problem (catalog wrapper: environment_error) on failure. `adopt_land_environment` requires the existing current-original NPC registry to be configured. It never configures/replaces that registry on the caller's behalf. `admit_land_environment` is only build then adopt. This data registration does not authorize a map, spawn, buff, entry or transaction.

## Input shape and original constraints

```text
{
  kind: "patch523_npc_land_environment_input", schema: 1,
  input_kind: "twilight.current523.land-environment-input.v1",
  source_snapshot: "patch523",
  source_archive_sha256: <existing SOURCE_SHA>,
  source_archive_identity: <complete existing definitions identity>,
  selection: {land_id, asset_path, land_attribute_ids: sorted unique integer IDs},
  tables: {table: {id_or_source_position_key: {source_row_1based, row}}},
  provenance: {table: {path, sha256, bytes, crc32, row_count}},
  excluded_source_rows, dependency_contract, execution_contract, limits
}
```

The exact entire original Land row must exist, and its AssetPath must equal the supplied string. No `str(Land.ID)+"/"` derivation, normalization or alternative AssetPath is accepted. The caller supplies explicit LandAttribute IDs; there is no archive-fill path for a missing/empty selection. Empty IDs explicitly registers no buff roots for that Land selection, replacing any prior selection for the same Land/AssetPath.

Every root must be an exact original owned LandAttribute, type504. Original LandAttributeType504 must declare Name NpcBuff and UnitID16, and Unit16 must declare BuffClassID. Value must be a positive integral BuffClass ID. Param1/2/3 must be integer0; unsupported parameter forms fail the candidate. Territory0 retains the existing declared Land-wide meaning; a nonzero exact Territories row must belong to this Land and have integral ordered inclusive bounds. The map owner still validates actual source cells.

The shared typed closure collector retains the exact referenced BuffClass, BuffGroup, complete BuffBonus set, Bonus, BonusType, Unit, BonusApplicationType, UIUnit, typed Buff/Spell/Invoke dependencies and StatusEffectAttr sets. Strict environment collection rejects an excluded link/dependency rather than silently publishing a partial set. Source test/dummy declarations remain excluded. BuffGroupID dependencies remain BuffGroup records, never BuffClass substitutions. No untyped InvokeOption parameter is interpreted as a spell identity. Raw conditional metadata and unsupported semantics remain under the existing receiver's guards; no new formula/clock/duration/geometry is selected.

## Adoption, identities and retention

Adoption re-produces the exact same original selection and requires full candidate equality. The candidate's whole archive identity must match the configured NPC source. It stages a union of only retained explicitly registered environment closures, rejects source-row/provenance conflicts with other selections and existing NPC rows, builds owner indexes, and adopts only after the whole operation succeeds. Failure retains all prior registrations. Repeating the same input is idempotent and does not increment the environment revision.

NPC `content`, `indexes`, `admitted_source_identities`, `source_identity`, `source_model_sha256` and combat generation are not changed by adoption. Environment tables/indexes/selections are a separate in-memory registry. Existing `row()`, `owned()`, `buff_details()` and `environment_buffs()` read explicitly registered environment rows through this registry; absent registry sets never load more rows from the archive. Subsequent `_publish_original`/NPC admissions replace only their existing NPC payload, retaining environment selections/indexes and their independent identity. Shared exact original rows are de-duplicated; a conflicting row is rejected.

Success returns the registered descriptor plus `ok:true`, `changed` and `npc_admission_changed:false`:

```text
{
  kind: "twilight.current523.registered-land-environment.v1",
  source_archive_identity, selection, land: <exact whole admitted Land>,
  environment_input_sha256: SHA256(canonical JSON of exact candidate),
  environment_registry_sha256: SHA256(canonical JSON of retained registry),
  environment_revision, npc_model_sha256,
  ok:true, changed, npc_admission_changed:false
}
```

These are runtime-computed payload identities, not the source ZIP SHA or an installed-pack identity. No digest value or successful adoption is claimed here. Failure returns `ok:false`, reason, existing environment revision/registry SHA and NPC model SHA with `npc_admission_changed:false`; it does not change NPC error/status. `registered_land_environment` returns an empty dictionary for an unregistered Land/AssetPath or unavailable/changed original source.

## Map owner handoff

After obtaining the actual selected M relation/AssetPath and explicit eligible attribute IDs, the map owner may call `catalog.admit_land_environment(land_id, asset_path, attribute_ids)`. On successful input adoption, it can pass `catalog.row("Land",land_id)` to its existing `source_region_context(point, admitted_land)`. The actual selected M/field identity, current population actor, integer source cell, region bounds, opt-ins, suppression and lifecycle remain with the map/consumer owner. Producing or registering a Land closure alone is not effect activation or observed consumption. No map/controller/field files or another owner's pending candidates were changed.

Direct access to `catalog.content.tables` remains the NPC payload only. Any optional old UI enumeration of environment roots must use `environment_attributes()`; the registry-only source-region receiver already uses row/owned/environment_buffs. This avoids invalidating NPC payload hashes simply to expose new Land rows.
