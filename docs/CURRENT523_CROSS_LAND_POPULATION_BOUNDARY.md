# Cross-Land population boundary — local, unexecuted

This candidate is based on local map/lifetime checkpoint
`accf53114099a459c8e23a75bbdea1d7a9ea916f`. The prior eight-file compatibility
view, original worktree, packs, saves, patches and bundles remain unchanged.
No tests, parser, compilation, game, render, CI, publication or merge was run.

## Concrete source/factory connection implemented

The current source population resolves records with
`SOURCE_M_ROSTER.for_spawn(key, str(field.data.map_id), ...)`; the spawn port and
spawn policy also consume that exact host map. Generic M fields use their own
`m523_land_*` identity while Main deliberately retains its legacy host
`active_map_id`. `Monster.setup()` previously passed only `active_map_id` into
both spawn admissions and `SOURCE_M_BINDINGS.apply`, losing the exact source
field host identity already attached to the record.

`Monster.setup()` now asks
`world.current523_source_actor_host_map(record: Dictionary) -> String`
for current523-final records. Main returns the selected M field's existing map
ID only when the whole original Land row, exact AssetPath, definition Land ID,
source manifest pin and record runtime host match. A mismatch returns empty and
the unchanged spawn owner rejects it. Non-M field behavior remains the existing
host path. The NPC tuple, source admission, category, server/time conditions,
original input projection, visual owner, costs and actor generation are not
replaced or granted by this adapter. This is TWILIGHT host namespace plumbing,
not a native server API or entry rule.

## Actual transaction defect bounded

`_prepare_generic_source_travel()` already builds original target terrain and
passes it to `_commit_source_destination()`. That commit changes field pointers,
physics, player, options/time session and cost/save state, but has no target
population preparation/adoption transaction. PR276's `_attach_source_population`
is a separate post-switch mutation, not a safe preflight. A successful terrain
hop therefore cannot establish a correct destination actor set or occupancy.

The actual common commit now holds cross-Land requests before its renderer,
camera/player movement, options/time writes and payment commit, with
`TARGET_SOURCE_POPULATION_TRANSACTION_REQUIRED`. Same-Land paths are unchanged.
This also holds cross-Land Aden return at the same missing population boundary;
the already chosen Aden destination/fee policy itself is not reinterpreted.
No current-world actor check is presented as target occupancy, and no empty
population, invented spawn point or first destination is substituted.

This guard is a partial safety correction, not completion of cross-Land travel.

## Pinned PR276 and exact remaining owner contract

Read-only public PR276 is still Draft/open at
`6b9cfc85f4113c7d054ae5057724225f0c7bd04d`:

- `current523_source_spawns.gd::apply(field, catalog)` consumes exact original
  Territories / spawn relations / views and populates a private field's regions.
  Its counts and respawn windows are explicitly existing TWILIGHT policy, not
  original instance coordinates/counts. Do not create another density policy.
- `current523_source_population.gd` extends the existing source population and
  gates current-final records/budgets. It has no detached prepare/adopt/discard
  boundary and no ready target-actor receipt.
- Its controller `_attach_source_population(world, field)` redirects live roots,
  invokes `SOURCE_SPAWNS.apply` then `configure`, and changes loot activation.
  It cannot be called against the current World during preparation.
- `FieldPopulation.configure(controller, value)` captures bosses, clears summons,
  trims pools, releases shared region frames, changes generation, builds slots
  and calls the actor factory. `_spawn_slot` parents real actors before setup,
  consumes `world.rng`, connects callbacks and captures/restores boss lives.
- `Monster.setup(record, player_ref, world_ref, texture)` requires initialized
  scene nodes and calls `current_catalog.project_actor_record(source_record)`
  before original visual selection. That catalog method invokes
  `_admit_original_actor`, rebuilding the live NPC registry for a new identity.
  Calling it with the live service is not a read-only target preparation.

The remaining typed data-owner requirement is an original actor-batch preparation
and atomic adoption/rollback boundary around the existing NPC registry: produce
the canonical projected records and exact source-input candidate for explicit
target encounter records, bind it to the complete archive identity and current
NPC model identity, then adopt conditionally without losing environment registry
selections. On failure, its owner must retain/restore the prior NPC model and
admitted identities. Existing `build(host_npc_ids)` produces input, but
`project_actor_record` admits immediately and `_publish_original` is an internal
replacement; no public pure projected-record/adoption receipt exists in the
pinned data21b API. No proposed new method is treated as implemented here.

With that real receipt available, the map owner can construct an isolated actor
container against private target field/RNG/boss snapshots, validate actual target
occupancy and all transition generations, then adopt at this guarded commit and
discard/restore on failure. Source actors must exist and be ready; source data
absence, conditional/excluded views, missing original visuals or unknown actor
placement must remain held. A no-actor preparation is not success by default.

This candidate does not install PR276, copy its live attach routine into Main,
merge its branch or claim prepared actors, population adoption or rollback have
been implemented/executed. Its required code reference files are preserved
outside the code-view under `source-reference/pr276/` with Git blob provenance.
