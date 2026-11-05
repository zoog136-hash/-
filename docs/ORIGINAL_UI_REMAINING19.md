# Remaining 19 source containers

All 19 entries were instantiated and inspected in an actual OpenGL viewport. The 129 checks passed across 39 capture records. All captured outputs were transparent, consistent with empty source containers, unbound model attachment nodes, and the one source sprite (`Sp_line`) being explicitly invisible. These results do not count as completed gameplay screens.

No generated placeholder pixels, row items, models, callbacks, or service rules were added. Input and list population remain disabled in explicit inspection mode; ordinary runtime configuration rejects those unresolved contracts. Position, scale, rotation-skew and alpha tracks now execute for the supplied attachment scenes, with source Linear/Sine-In easing only. Unsupported easing still fails.

Source behavior references: [Cocos 3.6 frames](https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/editor-support/cocostudio/ActionTimeline/CCFrame.cpp), [tween functions](https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/2d/CCTweenFunction.cpp).

| Original member | Verified execution | Remaining connection contract |
| --- | --- | --- |
| `UI/EmptyScene.csb` | Empty source root instantiated; transparent output | No child/content or invocation contract serialized in this CSB |
| `UI/LightScene.csb` | Empty source root instantiated; transparent output | No child/content or invocation contract serialized in this CSB |
| `UI/Alchemy/Alchemy_List_Material.csb` | Original hierarchy, dimensions, clipping, invisible/transparent state | ListView:source_input; ListView:original_item_template_and_data_binding |
| `UI/CardChange/CardChange_List_Popup_CollectionView_OptionCard.csb` | Original hierarchy, dimensions, clipping, invisible/transparent state | Panel_Card:source_input; ListView:original_item_template_and_data_binding |
| `UI/Change/Change_Card_Result_Set.csb` | Original hierarchy, dimensions, clipping, invisible/transparent state | Panel_CardSet_Result:source_input; Favorite_1:project_scene_binding |
| `UI/Change/Change_Folder_ListView.csb` | Original hierarchy, dimensions, clipping, invisible/transparent state | Panel_CollectionList:source_input; ListView:original_item_template_and_data_binding |
| `UI/CharacterSelect/Character_Spine.csb` | Empty source root instantiated; transparent output | No child/content or invocation contract serialized in this CSB |
| `UI/CharacterSelect/ChracterAppear.csb` | Named clip, source start frame 5, frame 18 position 150, frame 28 alpha 85/255, clock progression | Character model/Spine attachment and caller identity absent from this CSB |
| `UI/Clan/Clan_List_Rental_SelectCard.csb` | Original hierarchy, dimensions, clipping, invisible/transparent state | ListView:original_item_template_and_data_binding |
| `UI/Clan/Clan_Tab_Mark.csb` | Original hierarchy, dimensions, clipping, invisible/transparent state | ListView_List:source_input; ListView_List:original_item_template_and_data_binding |
| `UI/Clan/Clan_Tab_Mark_Request.csb` | Original hierarchy, dimensions, clipping, invisible/transparent state | ListView_List:source_input; ListView_List:original_item_template_and_data_binding |
| `UI/CommonUi/Common_Reward_RandomSlot_Set.csb` | Original hierarchy, dimensions, clipping, invisible/transparent state | Panel:source_input; ListView:callBackType:Touch; ListView:original_item_template_and_data_binding |
| `UI/Compose/Fx_Compose_Spine.csb` | Three named clips and endpoint execution | Spine asset/animation binding and fusion-result caller contract absent from this CSB |
| `UI/Main/Hud_Signal.csb` | Original hierarchy, dimensions, clipping, invisible/transparent state | ListView:original_item_template_and_data_binding |
| `UI/CommonUi/Common_Reward_MixSlot_Set.csb` | Original hierarchy, dimensions, clipping, invisible/transparent state | ListView:callBackType:Touch; ListView:original_item_template_and_data_binding |
| `UI/Main/Hud_CompetitionDungeon.csb` | Empty source root instantiated; transparent output | No child/content or invocation contract serialized in this CSB |
| `UI/Main/Set_L_Top_TrialListView.csb` | Original hierarchy, dimensions, clipping, invisible/transparent state | ListView_PartyList:original_item_template_and_data_binding |
| `UI/Change/Change_Card_Collection_Set.csb` | Original hierarchy, dimensions, clipping, invisible/transparent state | ListView:original_item_template_and_data_binding |
| `UI/Change/Change_Card_List_Set.csb` | Original hierarchy, dimensions, clipping, invisible/transparent state | ListView_1:original_item_template_and_data_binding |

Current main contains `renewal_hud.open_normal_card_collections`, `present_card_reveal`, and `world._on_card_fusion_requested`, but no inspected source mapping establishes which original list row, empty ProjectNode, or Spine asset those callers must populate. No guessed wiring or duplicated service implementation was added. Save/restart tests remain inapplicable until a real service connection exists.

Private pack: `/workspace/private-ui-inputs/remaining19-closure-02`, manifest SHA-256 `d47c414be3148f9c5fec153700e177bd70bed612c213cd27c0a51c08c33a1f6f`. Per-item evidence: `/workspace/private-ui-inputs/remaining19-render-03/result.json`. No blocked download was retried, and no authentication/environment/URL changes were made.
