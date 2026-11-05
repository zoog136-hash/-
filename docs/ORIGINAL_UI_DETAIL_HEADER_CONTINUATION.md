# Original inventory detail header continuation

This follow-up uses v19's already held ToolTip_HudType_Right original title44536/name44160/Close956 at ToolTipScene Project1012. The current actual detail_name text supplies the name, and source Close calls the same bag.close_detail used by InventoryDetailClose. That existing behavior only clears detail_active and reflows; it preserves selected reference, query, item locks and save state.

The original lock presentation now owns header and lock controls together. It hides the two matching old header controls only after the original source mounts, restores their captured visibility on close/failure/owner hiding, and rejects a stale selected reference. A disabled lock does not disable Close. No missing item body, use/equip/collection action or image relationship is invented.

No new pack or pixels are needed: combined v19 already contains these exact nodes. Original SHA and installer pin remain in ORIGINAL_UI_INVENTORY_LOCK_ABI.md. Additional tests, game runs, renders and CI were not executed; this code is unverified. The rest of the560-root scope remains incomplete; attendance/pass stay deferred.
