# Typed item fields and actual quantity consumers

Continuation after merged PR280, based on main `52c8f4be5c739a6cf258dce72c9f886e712dfa7b`. The earlier local branch and private originals remain preserved. No UI follow-up PR was open when this branch was started. Existing v30 original nodes/pin/selection remain unchanged; this is code-only and requires no pack or Drive write. No tests, compilation, game execution, rendering or CI were run. These connections are unverified and do not establish a completed560-root numerator.

## Native category projection reaches inventory and sale filters

The current native item projector already emits source_equipment_status and slot from original equip relationships and category fields. The UI previously ignored that status and used a slot/name heuristic. That put unsupported/ambiguous source equipment into Other and could place a legacy item in both consumable and Other tabs. The new source_inventory_category.describe consumes the existing projection:

- mapped/unsupported_source_slot/ambiguous_source_equip_slots → equipment display group; this never grants equipment or use eligibility.
- no_source_equip_slot + consumable → consumable display group.
- no_source_equip_slot + material/currency → Other display group.
- missing/unrecognized source classification → All tab only, without inventing Other or deleting/hiding ownership.

The native inventory's existing filtered acquisition order, standalone bag filtering and existing sale filter use this grouping. Sale's physical enumeration, eligibility, quote, pricing and save remain with the existing owner. Non-native items retain their existing classifier, made mutually exclusive: recognized equipment takes precedence, then consumables, then Other. No source category IDs, names, hashes or activation rules are fabricated.

## Selected physical source record supplies original detail fields

The existing _item_visual_record(reference,fallback) presentation adapter already retains the selected physical record for recognized native images. It now also requires the physical record's name to match the selected opaque reference before using that record. No ID is inferred from a display label.

The same selected presentation record now supplies native inventory display/filter data and original ToolTip_HudType_Right name44160, type42456, class row40928/40580, and the record passed to the existing safety-kind/safe-level display queries for53168/52788. Header name formatting reuses the existing owner's _enhanced_display_name with the same physical reference. Source detail name/type/classes/safety DTOs are tagged with that exact reference; stale values are not consumed for a different selection.

_find_item_record and the authoritative gameplay/ownership/use/enhancement handlers are unchanged. These are presentation-field connections; no additional bonuses, costs, source records, class permissions or saves are introduced. Missing/oversized class information keeps the existing original row's conservative visibility behavior. No quantity node is invented in this tooltip.

## Quickslot amount is an amount, not a diagnostic caption

The old quickslot caption can contain a missing-original-image explanation for a skill. Original Slot_Skill Text18112 previously copied that general caption into its amount position. The actual _render_quickslots inventory argument now publishes a separate typed amount snapshot keyed by absolute slot and exact registered-entry identity. original_quickslot_amount returns only that current integer amount for item entries; a skill has no quantity text. AUTO is a separate live marker and is excluded from identity comparison.

The source quickslot consumer uses this producer instead of parsing or copying a caption. Zero remains an actual zero; missing/stale/invalid quantity hides only the amount field and does not invent a stock count. Existing missing-image explanations, image resolver, cooldown formatter, icon ownership, page policy and use callback remain unchanged. The existing original Text18112 and current v30 pack are reused.

## Large inventory row consumption

The original slot consumer previously scanned every owned entry again for each displayed reference before checking its authored capacity. It now creates one exact-reference index and follows the existing owner's filtered acquisition order through that index. Duplicate/missing references remain rejected; no sorting, first-match substitution, row placement or ownership is introduced. The linking pass is linear in owned plus ordered entries instead of their product. This also avoids the quadratic work before a large inventory correctly declines the current4/8-slot presentation. The fallback/partial-layout limitation remains unchanged and is not counted as full native inventory support.

## Specific remaining contracts

The original inventory presenter still has only the authored4/8 slot instances and declines larger filtered inventories. Repeated row placement/content sizing beyond that authored set remains unestablished; no pitch, row cloning or pagination was invented here. Tooltip quantity/use/equip targets, native cart/row/quantity/batch confirmation relations, original CSB-to-Sprite registration, reward targets and authoritative dialogue NPC identity remain separate missing inputs. The36 dependency gaps are unchanged.

The warehouse UI's99 limit was traced to the current world's explicit _warehouse_transfer quantity<=99 guard, even though the lower storage service permits9999. This work does not independently raise the UI limit past the authoritative caller guard or change another owner's transaction contract. A wider quantity contract requires that owner to expose the supported bound consistently. The existing source files, exclusions, packs, settings and saves remain intact.
