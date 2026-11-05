# Current523 ground ItemClass.SpriteID consumer

This local continuation connects an existing ground-loot view to the private original SP2 bank. UI `IconID` resolution remains a separate image consumer. The ground source selector uses the complete current `ItemClass` row and its `SpriteID`; it never substitutes `IconID` or `ItemConsumeEffectSpriteID`.

`TwilightGroundLootManager._create_view()` resolves the existing admitted item's complete original row through `patch523_monster_drops.item_definition()`. Current native items enter `GroundLoot.configure_source_ground()` with that row. If a definition, action, original member or dispatch contract is unavailable, the source body remains pending. The existing Button, position, selection ring, grade beam and pickup callback remain owned by the ground-loot manager. No source binding is added to saved loot records or ownership receipts.

## Integration269 / image270 boundary

The existing ground consumer owner may supply an established original dispatch binding through:

```gdscript
ground_loot.bind_source_ground_visual(original_item, source_binding, source_bank_context)
```

This returns selection metadata, not proof of rendering or successful pickup. It refreshes only matching existing ground views; it does not spawn, consume, transfer or save an item. `original_item` must equal the entire original `ItemClass` row in the pinned common current523 tables. The manager also requires its admitted item definition to resolve to that same row before using a supplied binding.

`source_bank_context` uses the existing `current523_source_bank` configuration contract. A binding has these required fields:

| Field | Required meaning |
| --- | --- |
| `source_snapshot` | `patch523` |
| `item_class_id` | Exact original `ItemClass.ID` |
| `sprite_id` | Exact original `ItemClass.SpriteID` |
| `source_action_id` | Original SPR action selected by the ground consumer's dispatch evidence |
| `loop_policy` | Explicit boolean from that ground dispatch contract |
| `stored_direction` | Explicit stored source direction, integer 0–7 |
| `source_binding_evidence` | Nonempty dictionary preserving the originating ground dispatch/reference evidence |

No values for action, loop or direction are defaulted. `ItemClass.SpriteAnimationID` is retained in the selection's source reference without an inferred conversion to an SPR action. An explicit action must belong to the original actor's complete SPR action domain and have an actual registered action record. Literal dummy exclusions and normal source-bank pin/member checks still apply.

For direct existing visual consumers:

```gdscript
selection = GroundSelection.select(original_item, source_bank_context, source_binding)
configured = GroundSourceView.configure_ground_source(original_item, source_bank_context, source_binding)
```

`GroundSourceView.selection_status` preserves the complete source reference and precise pending reason. `source_status_changed` reports a later member/frame failure. The view uses the existing source renderer at the existing floor anchor, without icon scaling, a color-key shader or generated replacement art. A supplied non-looping action holds its source terminal frame; the view remains owned by the existing ground item until that owner removes it.

## Current input boundary

The existing ground path did not supply original ground action, loop or stored-direction semantics. An absent binding returns `current523_ground_explicit_binding_required`; this continuation does not manufacture a binding to activate a display. Known original examples are item233/247 → Sprite45, item310 → Sprite41 and item316 → Sprite3041, each with `SpriteAnimationID=1`. These ground identities are distinct from consume effects189/192. Their original SPR/physical input availability must be resolved separately.

This code has not been exercised in a game, render, test or CI run in this environment. Registration, selector success and observed gameplay remain separate states.
