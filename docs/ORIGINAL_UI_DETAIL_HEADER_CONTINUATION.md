# Original inventory detail header continuation

This follow-up uses v19's already held ToolTip_HudType_Right original title44536/name44160/Close956 at ToolTipScene Project1012. The current actual detail_name text supplies the name, and source Close calls the same bag.close_detail used by InventoryDetailClose. That existing behavior only clears detail_active and reflows; it preserves selected reference, query, item locks and save state.

The original lock presentation now owns header and lock controls together. It hides the two matching old header controls only after the original source mounts, restores their captured visibility on close/failure/owner hiding, and rejects a stale selected reference. A disabled lock does not disable Close. No missing item body, use/equip/collection action or image relationship is invented.

No new pack or pixels are needed: combined v19 already contains these exact nodes. Original SHA and installer pin remain in ORIGINAL_UI_INVENTORY_LOCK_ABI.md. Additional tests, game runs, renders and CI were not executed; this code is unverified. The rest of the560-root scope remains incomplete; attendance/pass stay deferred.


## Selected item type field

Original ToolTip_HudType_Right Text42456 previews a weapon type (`무기 (활)`). The existing detail owner now publishes only its actual selected record's `type` string, tagged with the same opaque item reference, as source_detail_type. The source reader accepts this text only for the current selected reference. It does not use detail_type's mixed selection/lock/engraving text, construct a subtype, or duplicate catalog/classification lookups. Missing or stale type input hides the original type field. This is an existing producer passthrough, not a new claim about canonical mobile type classification.

The permitted original node scope widens only in optional combined v20; v19's header/close/lock behavior stays usable unchanged. Original CSB SHA remains `7aa63b5159335c1558e9bc83f8155979b1a9bf4ee37eaed24c7e2652c392c1ce`; parent/source geometry and source fonts are unchanged. No quantity field was established and no quantity label was invented.

v20 filename: TWILIGHT_current523_main_game_original_UI_combined_v20_20261105.zip;13,489,130 bytes; ZIP SHA256 `da600a9bb8a509e7f587f417d820791013ad2f708d83120e6f783847ea5c0d9b`; manifest pin `550662af4fd9d83f7c8aeac8b2df1e6873392f403d0f3762fac642af3a626ba9`. Relative directory source-ui/current523-main-game-original-ui-v20; original_ui.json/receipt.json/originals/UI structure and existing single-pack selector are unchanged. v20 retains every v19 scope;60 original files/38 scene trees/37 partial scopes are packaging units, not completed560 roots. Existing pack inputs/settings/saves are preserved; consumer installation and operation are unconfirmed.

Official private delivery succeeded: Drive ID `1wAaEZmVO6zdeCNyW84-9Xv068o3HlviT`. This is a new optional v20 input, not a repeated v19 upload, and does not automatically modify the installer selection or user configuration.
