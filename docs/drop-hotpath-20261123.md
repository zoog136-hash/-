# Measured drop hot path

The Android capture on 523.824 reported `kill.drop` at 560 ms within one
1,060 ms frame, but did not report which drop sub-operation consumed it.
This change does not assign the 560 ms to one operation, nor measure the
original online game's server drop logic. The source rows provide membership,
not server probabilities.

## What changes

- A release kill resolves original 523 drop candidates only when the first
  unchanged random trigger needs a pick. Debug/verification UI retains the
  eagerly observed NPC drop-source evidence used by the developer-only item
  details view. Source conditions, membership, bind order, sorting, exact
  ownership records, and RNG draws remain unchanged.
- Candidate resolution walks unchanged ItemData condition evidence at most
  once per item per call, even when both public and native binding are tried.
  The roll constructs a full bless variant DTO only when it is selected.
- Immediate floor spawn checks the accepted placement once. A transaction
  that stages and later publishes (e.g. bag-to-floor after save) still
  revalidates walkable position, active map, occupied cell, and ownership ID.
  The view, audio, pickup, occupancy, and persistence stay synchronous as before.
- The fixed hitch names distinguish original membership, host/native binding,
  selection construction, position, stage/commit, and the floor view (including
  native visual request). These are inclusive; do not sum parent and child.
  Measure cold and warm hunt kills separately on Android before assigning
  the remaining time to visual work, tracing, or source data.

## Regression

`drop_hotpath_test.gd` compares seeded field and boss rolls with the prior
eager algorithm (including the final RNG state). `patch523_monster_drops_test`
also compares eager/deferred variant proof and native blessed ownership on
synthetic source records; real original resources are optional and were not
available for this local run. `ground_loot_spatial_index_test` tests both
immediate placement and failure of stale staged placement, snapshot/restore,
map changes, expiry and one-time pickup.
