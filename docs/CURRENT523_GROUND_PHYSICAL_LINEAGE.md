# Exact native monster-floor acquisition lineage

Local-only, untested follow-up after8d30900356598c3809812d43a8431d23eef9cedd. Public PR281 baseline remains af3ec2b35c533d98f21c6fc7949291c482d86b22. No tests, compilation, game, rendering, CI, remote writes, merge, source upload or phone/distribution update.

## Existing source and transaction owner

World._collect_ground_drop already dispatches native player-dropped receipt objects to current523_native_stack.collect_floor, then native monster drops to source523_ground_acquisition.collect. This follow-up changes only the latter existing owner and reuses the same source Drop/ItemClass/NpcClass/blessing rows, fixed existing quantity1/host selection policy, registered definitions, supplier and single-save transaction. No new drop chance, quantity policy, source eligibility or unsupported effect is inferred.

The owner keeps its existing source proof, floor ID, range, visibility time, line of sight, life state, capacity, duplicate acquisition receipt and source expiry checks. It now checks the existing shared reload/quest save guard before preparing ownership. Native equipment must retain the exact physical ID and data already produced by patch523_monster_drops.ground_metadata: record/name/level0/drop proof. The ID may not already exist in carried or warehouse ownership, or in another floor record. No replacement ID or equipment grant is manufactured on pickup.

## Native quantity supplier connection

For an ALREADY supported native quantity profile, the previous physical restore/awakening/growth producers must not also have created a competing physical result. The existing stage_grant receives the exact full source item, quantity and {kind:source523_floor,floor_id,drop:original proof} origin. It then passes its actual result through the shared `current523_native_stack.issued_ids(record, quantity, previous, granted, origin, false)` validator. This is the same all-ID/initial-quantity/immutable-receipt/unchanged-baseline check used by crafting; no second factory is created. The old local private _craft_issued_ids helper was generalized to this public static name, preserving its behavior.

Every newly issued ID must be absent from warehouse and floor custody. The exact issued set must equal the actual instance delta. The source_ground_acquisitions receipt retains each actual ID, initial quantity and native stack receipt in native_physical_receipts, as well as its existing source-row IDs, NPC/ItemClass/blessing, source input and drop-proof fingerprint. Equipment receipts add the selected source_equipment_physical_id. Old acquisition receipt rows without these optional fields remain unchanged.

The existing inventory weight calculation now calls World._indexed_item_weight(key, actual_source_item), preserving the already approved exact source-base/qualified-variant weight connection and its legacy fallback. No scale, carrying capacity or source weight is invented. Wallet, legacy/specialized and currently unsupported source-profile behavior stays with its existing owner; this is not a claim that every drop has a physical/use adapter.

## Save and adoption

Inventory, physical instances, next instance ID, gold, floor removal and complete acquisition receipts still enter ONE existing _save_game candidate. Existing owner authorization, source row checks, uncertain-save reload protection and confirmed-save floor take remain. The follow-up does not take a floor object before saving or grant live ownership merely to inspect it. An invalid/overlapping supplier result remains candidate-only and leaves floor/live ownership intact. No save/reconnect result is claimed without runtime verification.

The previous10-file local candidate, all earlier refs, originals and saves are preserved. No world/map/population/UI/data-reader file is edited. No pending spell-stage, potion or emoticon binding/effect is added; sound remains excluded. Frozen62ZIP/v30/index/source bank and successful phone install remain unchanged.
