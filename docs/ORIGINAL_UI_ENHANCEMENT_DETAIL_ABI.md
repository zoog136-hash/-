# Actual ordinary-enhancement target, fee and probability input

PR286 continuation after578f382ebc8af2029043005e88a707adf230bd5b. This extends the already mounted original ordinary-enhancement action with a coherent selected-target detail group. It changes no candidate generation, prices, probabilities, scroll count, confirmation, transaction, selection ordering or save logic. New code is unexecuted/unverified; no tests/compile/game/render/fullCI/merge/upload were performed.

## Existing actual owner

`renewal_forge.configure_targets(hud,scroll,candidates)` owns mode `target`, the actual scroll and candidate rows. `_select(index)` stores selected_index, renders selected_name and the current candidate's cost/chances. The existing `world._enhancement_candidates` supplies target_id, instance_id, name, level, cost, count and basis; its existing source/host rule distinction is retained. UI does not reclassify these costs as recovered original numbers or compute new prices.

`source_main_enhance_action` continues to require the live visible target-mode Forge, a valid actual selected index, nonempty target_id/scroll, and the original action. It now carries the actual selected target reference through presentation. Action/info activation reject a target that differs from the currently presented reference until the source presentation refreshes. No ID parsing, name-based physical lookup, first candidate, new selection or payout rule is added.

## Proven original parent and targets

The existing source mount remains `UI/EnchantScene.csb` SHA1b44bd8b15833b44a902b0033c47969cf237ea18bc4c9f210af3505738420326 Project724 → `UI/FloatingUi/Enchant_All.csb` SHA5a22899447b7b750c01e500beba49d80d081d65669bfc77c91309fe58946face. Existing authored parent position[603,343.50750732421875], alpha255, source root, transforms and native input are preserved. No new mount, centering, fit or playback policy is introduced.

| Existing owner value/action | Original receiver | Actual parent/role |
|---|---|---|
|Forge.selected_name.text|Text145444 Label_Title|Node2100/Nd_Common142656; position[.47589999437332153,178], size400×18. Only the preview equipment string is replaced by the actual existing selected-name text.|
|Actual selected candidate.cost, integer>=0|Text138568 Text_Price|Node2100/Nd_Enchant132556/Nd_Money138172; position[129.99989318847656,-135.9998016357422], size80×21. Unknown/malformed fee hides this group.|
|Original fee label/art|Text138240 `수수료`, ImageView139568 Price_Bg, Sprite139232 Sp_Icon_Money|FileData `Img_Bg_Radius0.png` and **Com_Icn_Adena.png**, both original UI_Resource/Atlas_Common.plist. The currency is explicitly adena, not a clan/mileage/diamond remap.|
|Existing Forge Browser `강화 정보` tab callback|Button134084 Btn_Probability + literal Text134136 `강화 확률`|Node2100/Nd_Enchant132556. Dispatches the actual second Browser tab's already connected pressed callback. No new probability form, rates or source popup is invented.|

`configure` widens its runtime scope only when those exact original offsets are present in the selected pack. Smaller old packs retain the old action-only scope. `refresh` updates title/fee and the information button's availability from the same actual selected owner. The current button pressed texture is retained during ordinary unchanged availability. Missing title/fee/info owner clears or hides that optional field; unknown cost is not displayed as zero. Returned `presentation()` exposes actual `source_node_offsets`, `bound_detail_fields`, source renderer/control and the existing parent scene.

The information action uses the actual current Forge browser, its real two-tab container and exact `강화 정보` button. It opens that existing detail path, which already contains success/maintain/decrease/destroy rates, counts, costs and basis. It invokes no enhancement, payment or confirmation. That owner keeps its responsive tab state/layout. Main HUD native touch now collects the actual mounted enhancement scene's source buttons, so both original action and probability controls use the existing source button router; no emulated mouse/new hit rectangle is added.

Source Safe/Unsafe labels are deliberately not inferred from safe_level or success rate. Blessing/refining/magic/automatic/multi/dissolve/delete modes and the ambiguous two original Common_Slot target-vs-scroll registration are not activated. Existing Forge._execute still owns the original ordinary confirmation and enhancement_requested signal; the source action only dispatches it.

## Separate local v39 candidate

The candidate retains v38 and adds seven explicit original offsets145444,139568,139232,138568,138240,134084,134136 in Enchant_All. No art or source bytes are edited.

- `TWILIGHT_current523_main_game_original_UI_enhancement_detail_v39_20261106.zip`,14,204,079B.
- ZIP SHA256 `66400e274e291f68e444f18baeb8a7a4edd91cf03a8f8229b82bf951f6aa140a`.
- Manifest pin `3d21b66ab7aa29ed15653a71b550fe9dcf58fcf8a3910af8e04ac10c2ddcea03`.
- Proposed relative root `source-ui/current523-main-game-original-ui-v39`;99 originals/58 scoped scenes/57 partial scopes describe packaging only, not actual game consumption/full-UI completion.

No remote ID, upload, source selection, phone/install/index/source-bank change. Frozen v30/62ZIP, v33–v38/Sprite candidates, source files, cfg and saves are preserved. Excluded spell-stage/potion/emoticon/sound work was not resumed. No image-provider or card-consumer files were modified.

## Current-target portrait request: precise source absence

Image PR283becdee85ee18d45459bcff44d5f9ec51e7b5ba40 requested an original HUD current-target portrait receiver. The held full `UI/Main/Set_T_Cen_TargetLayout.csb` SHAbf0da029e6bc3ce8fd4d4a89ff65c47b5c906b5b75776e8581414f2a2961f9ad contains target Text8876 plus authored backgrounds, lawful/chaotic/neutral, PK/clan/rank/chat/signal/arrow icons. Its Sp_Clan_Icon5864 is explicitly a guild emblem, and its Icon nodes have explicit social/chat resources. No NPC/monster portrait role is established in that component; those unrelated icons are not repurposed. This is a component-scoped finding, not a claim that all originals lack a portrait. Actual actor source_m_npc_id/source_m_original identity does not create a missing UI target. The separate dialogue Sp_Char4912 role is not stolen for the HUD target. No portrait target or registration callback was invented.

Result-parent→Face, SpecialDungeon Panel392→ListView2560 insertion and selected mixed quest-reward presentation remain separate exact pending inputs. The published image binding can consume a legitimate registered receiver when available; this enhancement work does not fabricate one or duplicate image-owner adapters.
