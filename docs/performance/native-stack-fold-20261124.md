# Native stack-fold preparation

Android 523.843 frame 8318 reports `loot.stack_fold_hud` at 103 ms. This
number covers the whole stacking call; it cannot identify the planner,
ownership validation, floor expiry, or snapshot copies individually.

- Floor expiry still runs at the same fold boundary. Expiring a receipted
  floor item can write a save; if that operation blocks ownership, the fold
  stops without adopting a candidate. No expiry, save, pickup, or proof is
  elided just because the last frame had no merge.
- No-op folds now skip building the detached floor and consumable ownership
  snapshots and reserved ID set. The synchronous planner needs these only
  once an actual merge bin exists. Its validation still covers the whole bag,
  warehouse, floor and inactive-character ownership and journals.
- Candidate proof, bag/merge order, lock and quantity caps remain unchanged.
  Stack cap reads only the existing original field, and identity comparison
  is skipped for a group with only one eligible member.
- Fixed detail keys `loot.fold_prune`, `loot.fold_plan`,
  `loot.fold_owner_snapshot`, and `loot.fold_validate` distinguish the next
  phone trace. The owner snapshot time is inside plan time. Do not sum them.

Public focused tests substitute only decoded native candidate proof where
private definitions are not installed. The optional
`TWILIGHT_CHECK_FOLD_WORLD=1` run exercises the actual Main fold entry and
unmodified validator for a no-op and an unproven merge; full native
pickup/save/reload still needs the original definition pack and Android
confirmation.
