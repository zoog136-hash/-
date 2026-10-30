# Follow-up: live inventory and shop detail states

Baseline: PR157 `95cfb271`, isolated script snapshot `/tmp/ui-detail-baseline`. Shared production files were never swapped for this follow-up.

Implemented in the existing inventory/shop path:

- Selected inventory item keeps its grade-colored border during hover and press. Only the previous/new selected slots need the extra state refresh. Equipped, selected and locked states are explicit in the detail labels; the original E and lock icons remain. Quantity labels reserve space for the lock and remain inside their slot. Full counts remain in the detail view.
- Shop prices, quantities and totals use exact grouped integers in a two-column right-aligned table. Long actual Korean product names wrap; redundant side headings were removed to give the table more room on the 854×480 viewport.
- Disabled purchase reason is visible as text on touch devices. Wallet text refreshes together with the selected quote, fixing a stale balance/disabled-state mismatch. An empty search clears the previous purchase caption.

All item IDs, prices, wallet/quantity validation, transaction signals, physical instance IDs, equipment/lock rules and source artwork are unchanged. No PR122/152/153/154/155 assets or feature code were imported or edited. HUD changes were not needed.

The actual Main fixture equips a real catalog item through the existing service and locks its physical reference through the world action. The actual shop product is `축복받은 오림의 장신구 마법 주문서 (각인)`, 99 at 450,000 = 44,550,000. The isolated wallet fixture is first 100,000,000 then 0, without executing a purchase. Inventory and physical IDs are checked unchanged by view/selection/filter/quantity interactions. Normal user saves are protected by distinct XDG directories.

`before/` and `after/` contain three states at 1280×720 and 854×480: equipped/locked detail, long-name shop quote and disabled purchase. These are unedited actual Godot viewport PNGs, not mocked UI or original-game pixel-equivalence evidence. The first fixture wrongly assumed an initially equipped item and failed; its log remains. The corrected fixture explicitly uses the existing acquire/equip service. Intermediate captures prompted the wallet and compact-space fixes; final files supersede those captures.

Only focused UI/shop checks are run for this follow-up. No full CI was requested by this subtask. Linux llvmpipe rendering is not Android device validation; no original artwork, animation, frame markers or economic values were changed.

## Final evidence

- Actual Main captures: **12 PNGs / 4,106,041 bytes**, per-file SHA-256 in `manifest.json`. Final after run: **37 checks, zero failures**, including six image-write checks. Baseline has 22 expected failures against the new presentation contract across two resolutions; these are not 22 separate gameplay bugs.
- Focused existing tests: `shop_authority_test` and `ui_renewal_integration_test` PASS.
- New `presentation_detail_states_test`: final runner **1/1 PASS**, 31 runtime assertions, no skipped/not-run checks. Its first runner attempt was a missing-DISPLAY setup failure because the capture-capable script was classified as visual; the failed test alone was rerun with DISPLAY=:97. No source or assertions were changed to resolve this setup failure.
- Inspected final 854×480 equipped/locked detail and disabled shop PNGs at actual pixel size: the short state row is readable, all five numeric rows fit, wallet0 agrees with the disabled reason, and the confirmation/purchase action remains separate.
- Production files are frozen after the final captures. No commit or full CI was made by this subtask.
