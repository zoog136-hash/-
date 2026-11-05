# Original main quickslot caller ABI (unexecuted)

The existing HUD now routes its current quickslot state and PointerTransfer
through the supplied original QuickSlotScene, PageViews and five-slot template.
This is a bounded original-node connection; full HUD/560-root completion and
actual game consumption are not established. Attendance/pass stay deferred.
No new test, game run, render, audit or CI was performed for these changes.

## Exact original inputs

| Member | SHA256 | Original nodes used |
| --- | --- | --- |
| `UI/QuickSlotScene.csb` | `a62e6450247e2ae8e4c0e0588417d443fe08a45c54606c6050d267528b33ceff` | Project3572 at600,0 |
| `UI/Main/Hud_QuickSlot_All.csb` | `670667993e83ff50068ec78156818f009972ba81ac30d162abfbe127be999088` | PageView2260/1732, original360x124 extents/clipping |
| `UI/Main/Hud_QuickSlotSet.csb` | `4c82afdae16a34a618b63e70b3793abf4b4a42465215f4221a4835b666523134` | Panel124; Projects1628/1360/1104/848/592 |
| `UI/MainFloating/Slot_Skill.csb` | `a2ef732cf9cee265b9dab0cee379ffab47fab6c2cc3b520d4d0cfd3eb3ad2c81` | Button20348, BG19808/18816, icon18488, amount18112, cooldown16968, AUTO13684 |

Slot_Skill18488 must be an explicitly declared external texture input in the
private pack. Its hidden editor sample never substitutes for an item/spell.
Source slot-number/charge/other effects and original page indicators are not
connected by this bounded scope. Existing game page controls remain available.

## Layout and existing game state

`source_page_view.gd` applies the documented Cocos2d-x3.6
[UIPageView layout](https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/ui/UIPageView.cpp):
the actual Layout position becomes `(index-currentIndex)*viewportWidth,0`.
Only equal-size original Layouts with identity root/wrapper/anchor/scale are
accepted. Raw original Panel position, page layout position and original size
are recorded separately. Slot child positions are never replaced with Godot
grid spacing. Serialized nonempty PageView children remain unsupported.

The host registers the supplied QuickSlotSet template in each authored empty
PageView, materializing only that group's current game page and explicitly
selecting that same index. This host template registration is explicit; the
original client's registration call sequence is not confirmed. The adapter
does not infer a new page count, swipe threshold, animation or repeat policy.
No QuickSlotScene clip is automatically played from its name.

`source_main_quickslot_bindings.gd` reads existing HUD.quickslot_entries,
quickslot_index(visible), World._quickslot_pages(), actual caption/cooldown
Label strings and entry.auto. It does not calculate costs, counts, cooldowns,
page rules or save operations. `build_group(group)` returns the actual five
project bindings/rows plus existing owner results. Empty slots retain existing
activation; dynamic text is hidden until an actual supplied value is present.

## Images, input and lifetime

`source_main_quickslot_images.gd` calls existing PR270 `describe_item` and
`Source523SkillImages.describe_skill`. Guardian records call
`Source523SkillImages.describe_guardian_skill(record, world.growth, "IconID")`
in `scripts/ui/source523_skill_buff_images.gd`, public46921c04. No Item/Spell/
Buff/Asset join or source-image decoder is recreated. Only actual original
Texture2D descriptors are accepted; an unsupported CSB image remains pending.

`source_main_quickslot_view.gd` accepts both current groups and every filled
original icon before hiding older quickslot buttons. Source button controls,
actual textures, absolute indices and unchanged entry identities are exposed
to existing PointerTransfer. Its tap/use, pending assignment, swipe, AUTO,
swap/clear and inventory-to-quickslot transfer routes are reused. Canvas and
original PageView clipping are respected. Existing typed Button/TextureRect
arrays remain intact for their image owner.

HUD accessors are `original_quickslot_hit_at(viewport_point)` and
`original_quickslot_control(visible_index)`. HUD state updates and its current
cooldown-label refresh call the existing main controller's
`refresh_quickslots()`. Refresh is deferred during an active pointer gesture;
stale presented page/entry identities cannot start another native gesture.
Label/AUTO changes refresh original nodes; changed page/entry stages a complete
replacement. Missing mandatory inputs restore the same existing buttons.
Closing/replacing the selected pack releases native scenes without changing
quickslot entries, ownership, effects or saves.

The separate37-original candidate and exact Drive/ZIP/manifest pins are in
[the installer handoff](ORIGINAL_UI_MAIN_PACK_INSTALL_HANDOFF.md).
It has static source dependencies, not consumer-installation or game-use proof.
