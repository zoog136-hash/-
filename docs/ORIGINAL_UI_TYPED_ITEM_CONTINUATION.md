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

## Original production buttons reach the actual recipe owner

`source_main_production_controls.gd` mounts original ProductionScene Project132 → Production_All Project14392 → Production_Tab_List. Exact source SHA256 values are respectively `cae6672733b914c0143fe376574e73012b0cd628113002693f0639c877f47328`, `328546745405eac58203853570d76e07d9cc95477ac4ecd701d786651e3786ec`, and `14c9c7ed1333e0b20a2362d9c095065716e91cc4641e1b77adefe21d03fd1afb`.

The existing visible renewal_crafting owner, active workspace and current_id in recipe_ids are required. Btn_Production42160 dispatches its actual existing action button: the existing _craft callback still re-quotes, opens its existing confirmation and owns the transaction. Btn_Count_01(34356, original 수량 초기화) resets the existing SpinBox to its actual minimum. Btn_Count_10(31860) and Btn_Count_50(29364) apply exact +10/+50 only when the existing editable integer bounds permit them. Existing value_changed refreshes the quote. The current owner limit20 (or1 for outcome recipes) is preserved, so +50 is disabled; it is never silently clamped or used to increase that cap.

Original Normal/Disabled subtrees and labels follow current action/quantity availability. Original parent ProjectNode geometry and referenced components' own serialized root opacity are reused. The former action is hidden only after all four original native controls are constructed; failures retain it, and closing restores its previous visibility. Recipe-bound callbacks reject stale selection. Source hit regions join the existing workspace mouse/Android routing, and the original search popup retains its existing modal precedence. Static source-construction rejection is retained for that owner/recipe rather than rebuilding it each frame. No new quote, cost, reward, material, save or animation policy is implemented.

This is a partial component. Production progress Label_Amount48124/Label_Item_Name46112 are not treated as idle selection fields. Progress cancel40264, material-row placement, result/collection/storage-fee/probability controls, Sp_Block43868 and activation FX remain unconnected; their required owner contracts are not established here.

The retained v30 pack is unchanged. A new private **local candidate v31** combines its scopes with the original production controls: ZIP `TWILIGHT_current523_main_game_original_UI_production_controls_v31_20261106.zip`, 13,690,677 bytes, SHA256 `c206b155b01ffbccd2f0b580a43ecdd8ce5f21dc7214c2e506a87e46554c17ff`, manifest pin `b4ca0ddd32e08f8f49e67c47e1a9d6206edb4e6205f679136f3d82af02bcb712`. Packaging reports74 original files,47 scene trees,46 partial scopes and0 dependency blockers; these are packaging counts, not runtime or completion results. It has **no remote file ID**, is not uploaded/installed/selected, and does not replace the installer's v30 selection. Proposed relative destination is `source-ui/current523-main-game-original-ui-v31` using the existing TWILIGHT_SOURCE_UI/TWILIGHT_SOURCE_UI_SHA256 selector and original_ui.json/receipt.json/originals structure. Existing cfg/saves and previous packs are preserved. The production view is optional when its original member is absent from the selected pack.

Image-owner handoff remains precise: this production input connection establishes none of (1) CSB-root-to-original-Sprite registration.source_basis/original_registration_confirmed, (2) an authored quest-reward image target/role, (3) emoticon caller/target/playback, or (4) dungeon entrance/popup image target. Those relationships remain unestablished in the held caller contracts; existing slot coordinates are not substituted for them. No investigation, source creation or remote upload was added to fill them. No tests, compilation, game execution, rendering or CI were run for this continuation; it is unverified.

## Original warehouse settings entry

StorageScene Project132 → `UI/Storage/Storage_All.csb` (SHA256 `eb4ddfa71dc9be978fd03948ff938c12e2366f6542ff5844509c47f110b38328`) now optionally binds authored Btn_Auto_Set3780 and its `자동 보관 설정` labels4448/3884 to the existing `HUD.open_inventory_automation_settings("deposit")`, already used by this warehouse owner's automation controls. It requires the actual visible warehouse owner, the same workspace and existing mode selector in deposit mode0. Switching to withdraw hides this deposit-settings button; callbacks recheck the actual owner/mode. Existing native pointer/touch routing uses its original hit area. Normal4380/Disabled3832, backgrounds5884/5500/5116 retain original geometry and pixels. Source light effect4784 is outside this partial scope. No automatic transfer, category/submode, material/custom selection, quantity preset or batch/all-items action is inferred from this settings entry.

A newer **local-only v32 candidate** retains v30/v31 original scopes and adds this button: `TWILIGHT_current523_main_game_original_UI_storage_settings_v32_20261106.zip`,13,691,952 bytes, ZIP SHA256 `d012fa799a24a593bf1342ba8c75e29505f65612f7c6625151006bc09e53ba53`, manifest pin `6a8b49d374ceee8393f62984656151749b86c22a6ec51cedf1909a6c96f22ebf`. Its proposed destination is `source-ui/current523-main-game-original-ui-v32` with the same selector/structure. Packaging reports74 files/47 scene trees/46 partial scopes and0 dependency blockers. There is no remote ID, upload, installer selection change, installation or runtime pass. Both earlier candidates and the official v30 remain preserved. Additional originals, CSB registration, reward/emoticon/dungeon image roles and the full560 completion count remain unresolved as previously stated. These new input connections have not been tested, compiled, executed or rendered.
