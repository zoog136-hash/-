# Original inventory detail header continuation

This follow-up uses v19's already held ToolTip_HudType_Right original title44536/name44160/Close956 at ToolTipScene Project1012. The current actual detail_name text supplies the name, and source Close calls the same bag.close_detail used by InventoryDetailClose. That existing behavior only clears detail_active and reflows; it preserves selected reference, query, item locks and save state.

The original lock presentation now owns header and lock controls together. It hides the two matching old header controls only after the original source mounts, restores their captured visibility on close/failure/owner hiding, and rejects a stale selected reference. A disabled lock does not disable Close. No missing item body, use/equip/collection action or image relationship is invented.

No new pack or pixels are needed: combined v19 already contains these exact nodes. Original SHA and installer pin remain in ORIGINAL_UI_INVENTORY_LOCK_ABI.md. Additional tests, game runs, renders and CI were not executed; this code is unverified. The rest of the560-root scope remains incomplete; attendance/pass stay deferred.


## Selected item type field

Original ToolTip_HudType_Right Text42456 previews a weapon type (`무기 (활)`). The existing detail owner now publishes only its actual selected record's `type` string, tagged with the same opaque item reference, as source_detail_type. The source reader accepts this text only for the current selected reference. It does not use detail_type's mixed selection/lock/engraving text, construct a subtype, or duplicate catalog/classification lookups. Missing or stale type input hides the original type field. This is an existing producer passthrough, not a new claim about canonical mobile type classification.

The permitted original node scope widens only in optional combined v20; v19's header/close/lock behavior stays usable unchanged. Original CSB SHA remains `7aa63b5159335c1558e9bc83f8155979b1a9bf4ee37eaed24c7e2652c392c1ce`; parent/source geometry and source fonts are unchanged. No quantity field was established and no quantity label was invented.

v20 filename: TWILIGHT_current523_main_game_original_UI_combined_v20_20261105.zip;13,489,130 bytes; ZIP SHA256 `da600a9bb8a509e7f587f417d820791013ad2f708d83120e6f783847ea5c0d9b`; manifest pin `550662af4fd9d83f7c8aeac8b2df1e6873392f403d0f3762fac642af3a626ba9`. Relative directory source-ui/current523-main-game-original-ui-v20; original_ui.json/receipt.json/originals/UI structure and existing single-pack selector are unchanged. v20 retains every v19 scope;60 original files/38 scene trees/37 partial scopes are packaging units, not completed560 roots. Existing pack inputs/settings/saves are preserved; consumer installation and operation are unconfirmed.

Official private delivery succeeded: Drive ID `1wAaEZmVO6zdeCNyW84-9Xv068o3HlviT`. This is a new optional v20 input, not a repeated v19 upload, and does not automatically modify the installer selection or user configuration.

## Existing safety value and source class row

The original Enchant_On52728 subtree's caption53168 (`안전강화`) and value52788 consume the actual selected record through the existing world's _enhancement_kind_for_record and _safe_enhancement_level services. The UI does not supply6/4 defaults, quote costs or run an enhancement. Existing host safety rules may themselves use source or host policy; showing them is not a claim of recovered mobile rules. No kind/valid integer hides the source group; Enchant_Off is not assigned an invented unavailable state.

The existing item-use service consumes source_class_names for class eligibility. The detail owner now passes that same explicit string list with its opaque selected reference to original class title40928/value40580. It preserves order and slash formatting without adding a public/all-classes meaning for an empty list. ListView_BasicInfo39440 contains exactly authored Panel39492 (312x20 within316x269); this one original row is retained without cloning. Its readonly input is consumed; elastic scrolling/other rows/comparison are not implemented or claimed. Missing/stale data or a full class list that does not fit its original source-font width hides the whole row; no partial class list is presented as complete. Original Test comparison40232 and the rest of the body stay unbound.

The poison status owner player.is_poisoned() and original LoadingBar_HP_Poison39796 were located. That original widget carries the unimplemented customProperty ` Red:#D80900 Sky:#29D6FF gray:#7F7F7F`. The poison draft is preserved privately and is not activated/published; the existing HP UI remains untouched. No palette/shader/loop policy was guessed. The CSB-root-to-original-Sprite relationship and canonical quest reward→target-slot assignment are still unestablished; these new text fields do not establish either image contract.

Combined v22 retains v20 plus the unshipped local v21 safety scope and class row. No source bytes, images, fonts or authored layout were changed. v19/v20 remain usable with their earlier smaller scopes. There were no additional tests, compile, game runs, renders or CI. Private pack construction is not runtime verification.

v22 file: TWILIGHT_current523_main_game_original_UI_combined_v22_20261105.zip;13,490,923B; ZIP SHA256 `b2e8cc6237d063c4c288c84db983bfad5b931ec81efce53c152edfa5f6071441`; manifest pin `68b85d0fb5a7631c2a06d36c8e26c40e8d12979bc4605dacdec83b32993845da`; relative directory source-ui/current523-main-game-original-ui-v22. Existing original_ui.json/receipt.json/originals/UI structure and TWILIGHT_SOURCE_UI/TWILIGHT_SOURCE_UI_SHA256 or --source-ui/--source-ui-sha256 selectors remain unchanged. No installed-base pack, overlay whitelist change, installer selection replacement, new access permission or automatic config write is introduced.60 raw files/38 scene trees/37 partial scopes remain packaging counts, not completed roots or game use.

Official private v22 delivery: Drive ID `1KGdRwGO-vslJdJHEl4PrTXLnR-w_Ngkn`. v21 is retained only as an unshipped local intermediate. v20 still contains MapScene Project132, Map_All, Map_Tab_Area and Map_List_Button partial scopes; map image pixels and map relation-file pin are a separate owner's contract, not part of this text-field connection.
