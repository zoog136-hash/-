# Current523 ground ItemClass.SpriteID boundary

This continuation connects an existing ground-loot view to its complete current original ItemClass declaration. It preserves a precise pending state for the unresolved ground renderer/member relationship. It does not activate a ground image or actor animation.

The pinned image270 contract is [SOURCE523_ITEM_GROUND_HANDOFF.md at9fc7c6aa](https://github.com/zoog136-hash/-/blob/9fc7c6aaedf1c80d09fe084c664bf4c22df04ee9/docs/SOURCE523_ITEM_GROUND_HANDOFF.md). SpriteID is not an AssetView ID. UI IconID, a same-numbered actor and UIItemDropEffect.DropEffectSpriteID cannot substitute for the ground body. SpriteAnimation.Delay and SpriteAnimationAsset.AssetID/Order are usable only where actually declared; absent relationships create no frame, FPS or repeat policy.

## Integration269 / image270 / data271 boundary

The ground-loot owner retains spawn, physical item identity, quantity, receipt, position, pickup, selection and persistence. The existing native item flag and authoritative ItemClass ID come from that owner; no name, local item index or Sprite number establishes ownership.

At `_create_view`, the manager resolves the existing admitted item's full original row through `patch523_monster_drops.item_definition`. Current native item views pass it into `GroundLoot.configure_source_ground`. These views keep the existing Button, grade beam and selection ring; their item body is pending rather than replaced by a UI icon or procedural item body.

The same complete row may be supplied from image270's `active().source_consumer_row("ItemClass", item_class_id)` or data271's `current523_definition_rows.row("ItemClass", item_class_id)`. Retain each reader's actual receipt/provenance; do not invent row positions or hashes absent from its result. Extract the full original row from the successful result and pass it to:

```gdscript
pending = ground_loot.bind_source_ground_definition(original_item, source_bank_context, source_binding_evidence)
```

`source_bank_context` follows the existing private `current523_source_bank` contract. The third dictionary preserves any supplied ground relationship evidence without treating arbitrary fields as an action/loop/direction mapping. The selector requires complete agreement with the ItemClass row in the pinned common current523 archive, explicit TestItem=false and a positive SpriteID. A valid row is retained for matching existing native item views, even while the renderer relationship is pending. Invalid or changed definitions are rejected. This method does not create an item, activate art or write a ground/save/ownership record.

Direct boundary API:

```gdscript
pending = GroundSelection.select(original_item, source_bank_context, source_binding_evidence)
configured = GroundSourceView.configure_ground_source(original_item, source_bank_context, source_binding_evidence)
```

The current valid-row result is `ok=false`, `status="source_only_pending"`, `reason="current523_ground_original_member_and_renderer_role_unresolved"`. `GroundLoot.source_ground_status` retains the full ItemClass reference and SpriteAnimationID. It does not assert that a same-numbered actor's original action domain establishes a ground role. The pending view owns no rendered substitute and supplies no default action, frame, loop, FPS or direction.

## Exact current input boundary

Existing source records for representative actual consumables are:

| ItemClass | SpriteID | SpriteAnimationID | Existing mobile SPR declaration | Exact known raw member |
| --- | --- | --- | --- | --- |
|233 /247|45|1|list_0.spr:95, type9, no actions|Sprite/45-0.sp2;142B;CRC05a9ce29;Sprite228.dat|
|310|41|1|list_0.spr:91, type9, no actions|Sprite/41-0.sp2;143B;CRC307036d3;Sprite223.dat|
|316|3041|1|list_3.spr:150, type9, no actions|Sprite/3041-0.sp2;273B;CRC71b5ec73;Sprite214.dat|

The existing saved structure records describe one frame and stored direction bit0 for these three members. This is retained metadata, not a new decode or rendering result. Existing receipt41-0 has current-container evidence and a held raw source path. Receipt presence for45-0/3041-0 was not established in this targeted lookup. None of the three has a declaring action-source-index row; creating action0/1 for it would fabricate an SPR action.

The held common SpriteAnimation row1 has Delay0 and no SpriteAnimationAsset links. This does not supply the missing ItemClass/type9 static-ground member/frame/renderer relationship or an animation clock. The remaining input must establish that exact mobile ground relationship. Consume effects189/192 and PC sources are separate and cannot resolve it.

No game, render, test or CI run was performed. The bank remains unchanged by this pending ground boundary.
