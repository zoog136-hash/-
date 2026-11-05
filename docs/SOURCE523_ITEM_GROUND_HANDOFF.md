# Original item ground-role handoff

Integration269 owns the actual drop's original item identity and physical
ownership/pickup/save calls. The Sprite owner owns any original Sprite/member
and ground presentation contract. The image branch does not add a Sprite
player, new ground pixels or an inventory-icon-to-ground substitution.

## Existing full ItemClass readers

With an already authoritative **mobile ItemClass ID**, the selected source523
image pack already exposes:

```gdscript
var images = preload("res://scripts/ui/source523_image_assets.gd")
var reader: RefCounted = images.active()
var original: Dictionary = {}
if reader != null:
    original = reader.source_consumer_row("ItemClass", item_class_id)
```

Handle `reader == null` and the returned `ok:false` explicitly. Success returns
the full original row copy plus `source_table`, `source_id`,
`source_row_index_zero`, `source_table_sha256` and
`source_row_canonical_sha256` provenance. These are the current image pack's
original ItemClass declarations; no item, physical instance or drop is created.

Data271's existing `current523_definition_rows.gd` is the independent original
archive reader: `identity()` and `row("ItemClass", item_class_id)` return the
same-snapshot archive receipt and unique full original definition. It does not
supply row positions or row/table SHA, so those fields must not be invented.
Neither path derives an ID from names, local numeric IDs or a Sprite number.
`source523_image_assets.item_class_id(record)` only reads its numeric field;
the caller must retain the real supplier/namespace/full-row identity contract.
An image supplier qualifier or a definition read is not ownership or activation
permission. Existing exclusions and explicit TestItem/dummy declarations remain
the consuming owner's responsibility before activating the content.

## Declared source fields and remaining renderer role

The held ItemClass visual fields are `IconID`, `SpriteID`,
`SpriteAnimationID` and the `IsDroppable` boolean. The inspected schema does
not declare a ground Texture2D AssetID. `SpriteID` is not an AssetView ID, and
`IsDroppable` does not identify pixels or a renderer.

Direct original relationships available through that existing definition reader:

- `row("SpriteAnimation", SpriteAnimationID)` supplies the original Delay.
- `related("SpriteAnimationAsset", "SpriteAnimationID", id)` supplies the
  declared AssetID/Order chain where present. A zero/absent chain supplies no
  new member, frame, FPS or repeat policy.
- `related("UIItemDropEffect", "ItemClassID", item_class_id)` supplies
  `DropEffectSpriteID`. This is the drop **effect** role, not the base item.

The remaining contract is the exact ItemClass Sprite declaration to actual
ground Sprite/member and consuming renderer role, established by that owner.
The same integer in another namespace is insufficient. Inventory IconID,
an actor animation or a drop effect must not substitute for an unprovided
base-ground declaration.

The existing call is `ground_loot_manager._create_view` →
`item_visual_resolver.texture(..., ground=true)` → `TwilightGroundLoot`.
Source523 image `handles_item` intentionally handles only `ground=false`.
This handoff does not change drop records, colliders, positions, input,
ownership, pickup or persistence, or claim the existing category artwork as
original game resources. No source-byte audit, test, game execution, rendering,
CI or upload was run for this handoff.
