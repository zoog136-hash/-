# Actual result-card phase and selected SpecialDungeon contracts

PR286 continuation after265a46e45234bc4894352905bdc55cbac306232e on main d758bcfc0424baa331fc4b954dbf50aa5343ba63. This connects metadata contracts to existing actual UI owners; it does not claim a rendered screen or assigned pixels. No image decoder/texture provider, new UI display node, renderer, gameplay selection/order, timing, grant or save logic is introduced. Tests/compile/game/render/CI/merge/upload were not run. The frozen phone62ZIP/v30/index/source bank and v33/v34/v35/Sprite candidates are untouched.

## Per-card contract now attached to the actual reveal owner

HUD._new_card_reveal_stage passes its existing selected UI pack via OriginalMainGameHUD.source_role_pack(). Stage.present passes that same pack and its actual fusion/draw operation into **each** existing card instance, preserving result order, candidates, manual-reveal and timing. Image owner code can call:

```gdscript
var contract: Dictionary = card.original_result_card_contract()
```

This reads that instance's actual record and Face state. Back means waiting_for_press or actual Face.elapsed<0; front means elapsed>=duration; otherwise phase is transition. These are the current renderer's own predicates, not new source-frame or time policies. The method never chooses another card, modifies the result, starts a clip, resets a clock or changes user input. A transition contract exposes eligible front/back nodes but does not request a fabricated source animation or replace rolling candidates.

`source_result_role_contract.selected_card` uses the existing lineagem_base508.canonical API and requires the current523 snapshot, exact sourceId, raw BuffCard.ID/current card ID and raw GradeID/canonical grade agreement. Existing grade-family metadata and current523 Grade table both have SHA7ccc62ce1c95ff02cb833e09a68469a1f66ff739db0ada613e4fd498226984da. No localized label or sequential-grade-ID alias is used. **Myth32/Sole52/event/unknown do not get a default result variant**: these two result components serialize only the five listed families.

- Fusion member `UI/Change/Change_Card_Result.csb`, SHA846392b76ee58324528002be91665885a1466fb2b515e00e7d4c22ea69406ab1.
- Draw member `UI/Change/Change_Card_Gacha_Result.csb`, SHA7b083ccf01c6a5038fe05a5ddb2d107be7ce45aeb9ffaeab2c9a34b95cdd862e.

| Existing GradeID/family | Fusion front/back offsets | Draw front/back offsets | Exact FileData basename, front / back |
|---|---|---|---|
|1/Common|10856 /3136|16416 /12600|Card_Slot_Common.png /Card_Slot_Back_Common.png|
|2/Rare|10572 /2848|16112 /11996|Card_Slot_Rare.png /Card_Slot_Back_Rare.png|
|3/Unique|10288 /2560|15808 /11392|Card_Slot_Unique.png /Card_Slot_Back_Unique.png|
|4/Legend|10004 /2272|15508 /10792|Card_Slot_legend.png /Card_Slot_Back_legend.png|
|5/Epic|9720 /1984|15204 /10188|Card_Slot_Epic.png /Card_Slot_Back_Epic.png|

All FileData paths have exact prefix `ChangeImg/`, empty plistFile and resourceType0. Source name uses `Sp_Card_legend` lower-case l for that variant; no path case is rewritten. Source-parent registration is exposed as complete ancestor widget records, not a fabricated root→Sprite attachment assertion:

- Fusion front: Node84/Card_Result132/Nd_Character3984/Sp_Card_*; back: Node84/Card_Result132/CB_Change_Back972/Change_Card_Back1340/Sp_Card_*.
- Draw front: Node96/Card_Result8416/Nd_Character13888/Sp_Card_*; back: Node96/Card_Result8416/CB_Change_Back9176/Change_Card_Back9228/Sp_Card_*.
- Common front is authored105×125, anchor[.5,.5], position[0,0], scale[.9879000186920166,1.0556999444961548] for fusion and[1,1.0511000156402588] for draw. Common back is104×131, same anchor/position and scale[1,1]. Every variant's actual widget/ancestor options are returned, so consumers must not replace them with these example values.

Successful descriptors carry pack, manifest_sha256, member/source_sha256, unique node_offset/type/name, complete fileNameData, authored_widget, parent_chain and image_view fields. They contain no Texture2D. The image owner retains decoding/rendering and must retain original transforms rather than imposing a new fit/anchor. `pixels_assigned=false`, `source_animation_started=false` and `dynamic_csb_registration_asserted=false` distinguish the stages.

Original clip declarations are returned unchanged: fusion Fx_Idle0–149, Fx_Change_Card_Active150–240, Fx_Card_Back305–306; draw Fx_Card_Roultte_Start310–335, Fx_Card_Roultte_Stop390–550, Fx_Active0–25, Fx_Card_Skip200–240, Fx_Card_Back305–306, Fx_Card_Appear555–640. No loop, seconds conversion or original-client call sequence is inferred from those names.

## Whole fusion-stage background is separate

Image/UI consumers can call `stage.original_result_background_contract()`. It checks non-showcase/nonempty actual results and canonical identities in existing order. It returns a contract only for the actual fusion operation; a draw-stage parent contract is still unestablished.

Member `UI/Change/Change_WinResult.csb`, SHAc72f1dacbb855358c4ca25aa3326ffd565d4cd0bb6699ba02062521c7b153e7a, original title `합성 결과`, source parent Node88/Nd_BG7324:

1. ImageView8456 Img_BG: FileData ProductionImg/Sp_BG.png, position[0,0], anchor[.5,.5], size1200×675, scale[1,1], raw color[255,0,0,0] (black RGB), alpha255; scale9Enabled1/capInsets[3,3,4,4].
2. ImageView8124 Img_BG2: ProductionImg/ResultBG_B.png, position[0,10], anchor[.5,.5], size1200×380, scale[1,1.031999945640564], raw color[255,255,255,255], alpha255; original capInsets[0,0,1024,448] and scale9 properties returned.

This is a two-layer tinted/9-slice source background, not one stretched uncolored Texture2D. The old global reveal_background API does not express that whole contract, so it is **not** silently registered through that API. Source full-screen parent insertion is not proven by an empty standalone root; the API explicitly reports parent_registration_established=false. Card_Result inner backing11140 and its Card_Slot_BG.png are not used as whole-screen background. The reverse-reference search of the held3034-CSB inventory found no serialized ProjectNode parent for these result templates; that is a held-inventory limitation, not proof no client controller exists.

## Actual selected SpecialDungeon receiver boundary

The source is an actual content-card target, distinct from the category button and Party/Competition:

- `UI/Mission/Mission_DungeonSpecial_Btn.csb`, SHA289353c38b5f8efb7c3caf4913640819864f72c2868c327c71d97a5d4231462d.
- Node344/Panel392/**ImageView28700 Img_Special**: authored154×262, anchor[.5,.5], position[82.28150177001953,184.66709899902344], scale[.9883000254631042,.9921000003814697], white tint/alpha255, scale9Enabled0. Its source Mission_Dummy preview is never used as entrance art.
- Outer content component: Mission_Dungeon_All Project1696→Mission_Dungeon_Special.csb SHA90f9730962955075a2f24c095c950e5a4362805b8ef59b143eb00eda1effce3d, ListView_Daily2560. That list is empty in the held CSB; it does not serialize Special_Btn as a child.

The existing actual `source_dungeon_view` now exports:

```gdscript
var selected: Dictionary = view.original_selected_special_entrance()
# selected.actual_selected_entry is the original existing rows[selected],
# verified against a unique current world.source_dungeon_entries("special",false).
# Pixel owner can pass it unchanged to:
# source523_dungeon_images.describe_special(selected.actual_selected_entry)
```

HUD passes the same existing UI pack into that current view before configure. Query requires the visible live special-family owner, valid actual selected index, integral positive original row.ID/EntranceAssetID, unique current original row and exact row equality. It never chooses a first/representative dungeon or changes selection/transport. Existing listing.item_selected→_select owns selection; consumers query after that callback and refresh after family/list rebuild. Closing/family change/invalid or stale selection returns an explicit failure, so a previous entrance must be cleared. No popup/HelpBox/Party/Competition/stage/MapImageInfo join is substituted.

`original_ui_target` identifies the original ImageView and preserves all source geometry but says **runtime_target_registered=false**. The remaining precise UI receiver is **Panel392→ListView_Daily2560 insertion and an ImageView static-asset input**, not Sprite-only icon registration. Existing source external texture slots require Sprite; the original target must not be wrapped/renamed into a fake Sprite. The held reverse-reference inventory has no serialized Special_Btn parent relationship. Pixel provider PR283dac6fcd876e9e52e06c2246854c618a51898a9c9 removes asset identity/pixel prerequisites (EntranceAssetID→AssetView type11→Image/Mission154×262), not this registration. No new TextureRect, list thumbnail, guessed item spacing or render attachment is introduced.

## Quest search remains precise

Current quest projection preserves Reward relations/order and item identity; quest_service.entries supplies a filtered eligible payout plan with mixed kinds aggregated/separated. renewal_quests.selected is a category and up to30 Label-only panels are displayed. Neither the held source definitions nor that caller supplies a single selected quest plus a complete eligible mixed presentation/overflow registration for original five-slot layout. The previous exact missing receiver remains; no new UI choice, first row, first-five truncation, raw-order payout remap or representative image was created.

## Local v36 only

TWILIGHT_current523_main_game_original_UI_result_roles_v36_20261106.zip:14,200,105B; ZIP SHA2a8abfd506122d0bd8131420a045414090049cfbf3f946519e4a63741f88c9c4; manifest24cc72992ddbf878667fb022b1b2d5f601dc9ec0bc9e59d0575dd455939d1bfb. It retains v35, adds explicit static result front/back and fusion-background scopes, and holds Special_Btn **layout metadata only**, with no new Mission_Dummy pixels. Root proposal source-ui/current523-main-game-original-ui-v36; unchanged selected-pack schema/selector. Packaging99 original files/57 scenes/56 partial scopes/0 dependency blockers is not rendering, screen completion or a full-UI denominator. No remote ID, upload, installation or source bank/index update. Pending potion/ambiguous spell-stage/emoticon/sound work remains excluded without deletion of originals or shared systems.

## Follow-up: original ImageView receiver and selection lifetime implemented

The renderer now accepts an explicitly scoped **original ImageView**, as well as the existing Sprite, for `source_asset_slot`. The builder permits only those two authored classes and omits only that declared target's editor preview resource dependency. Original CSB/reference bytes and node metadata remain intact. No arbitrary display target, list thumbnail or new UI component is introduced. Source scene attachment remains Sprite-only; this change is static original-image reception, not CSB-root registration.

For a legitimately registered instance of the original component, the existing renderer contract is:

```gdscript
# At existing renderer configure: exact externally_bound_texture_nodes scope
# and binding {28700: {"role":"source_asset_slot", "visible":false}} required.
# This does NOT establish or perform the missing parent registration.
var assigned: Dictionary = player.set_bound_source_asset_result(28700, image_owner_result)
if assigned.get("ok", false) and assigned.get("texture_assigned", false):
    player.set_bound_visible(28700, true)
else:
    player.clear_bound_source_image(28700)
# Selection invalidation / family switch / owner exit:
player.clear_bound_source_image(28700)
```

The actual existing ImageView rendering block is shared with replacement reception. It retains authored widget size/position/anchor/rotation/scale, flip, tint cascade and the existing scale9/cap-inset renderer. `Img_Special` declares ignoreSize0, scale9Enabled0, size154×262; the existing image owner's154×262 PNG therefore needs no guessed fit, source map ratio or intrinsic-size migration. A non-scale9 ignoreSize1 node with different replacement dimensions is explicitly rejected until its child/input-size registration is established. Original Sprite replacement and CSB scene-attachment APIs retain their separate paths.

Replacement first removes/frees the previous original image and clears provenance/visibility. Failed/missing/excluded pixels leave the target empty and hidden. A successful replacement retains the image owner's evidence, reapplies source display tint, and remains hidden until the owner explicitly requests visibility. The existing hidden-slot guard now recognizes an actual populated ImageView. Clear and node destruction release its display object; no game state or saves are written.

`source_dungeon_view.original_special_selection_changed(selection)` now emits from the actual existing owner:

- `_refresh()` invalidates the previous selection before rebuilding rows;
- `_select(index)` publishes the existing selected row after assigning `selected`;
- `visibility_changed` re-queries the actual live/visible owner;
- `tree_exiting` emits an explicit invalidation.

Consumers connect to this signal and query `original_selected_special_entrance()` on initial registration. Invalid payloads require clearing the old picture. Valid payloads carry the unchanged actual entry for `source523_dungeon_images.describe_special()`. Existing owner selection/default policy, row ordering, gameplay actions and saves are unchanged. The signal does not choose a dungeon and does not create a receiver when none is registered.

Engine semantics were checked against the official Cocos2d-x3.6 source [UIImageView.cpp](https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/ui/UIImageView.cpp): loadTexture updates renderer texture/content size; nonintrinsic widgets scale their image to declared content extent; scale9 uses the declared preferred size. This establishes ImageView texture behavior, **not** the game's controller insertion/call sequence. A targeted reverse-reference search of the held3034-CSB inventory still contains no ProjectNode parent for Special_Btn, Change_Card_Result, Change_Card_Gacha_Result or Change_WinResult. Therefore **Panel392→ListView_Daily2560 insertion** and result-root→live-stage registration remain unestablished. No first-item placement, list margin, center attachment, clip repeat or phase timing is inferred from engine methods.

A separate v37 local candidate includes Special_Btn's explicit28700 ImageView scope, with the original Mission_Dummy preview dependency omitted through the declared external-input contract. It does not mount that scene or resolve the missing parent relation:

- `TWILIGHT_current523_main_game_original_UI_special_image_receiver_v37_20261106.zip`,14,200,821B.
- ZIP SHA256 `836740f82c37f7188c1347fcae4ff1b6a0d4afd766d6d94bca378c97af8eef12`.
- Manifest pin `267372d2e1453b70642013ae1e1c80db8940897ab4a22bb5da889b94936afc0f`.
- Proposed relative destination `source-ui/current523-main-game-original-ui-v37`;99 original files/58 scoped scenes/57 partial scopes are packaging quantities only.

v36 and all earlier packs remain preserved. No remote file ID/upload, phone source selection, distribution/index change, runtime attachment, test/compile/game/render/CI or PR merge. This receiver code is unexecuted and unverified.
