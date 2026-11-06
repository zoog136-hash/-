# Actual card-frame registration and searched quest owner boundary

PR286 continuation after79821e1640c01fd86ac6ad8b29af3f425565f58e, main d758bcfc0424baa331fc4b954dbf50aa5343ba63. No tests/compile/game/render/CI, merge, resource upload, phone/index change or original deletion. Pending spell-stage/potion/emoticon targets are excluded; no recovery work or pending count is assigned to them.

## Implemented: existing grade-family roles reach the existing image owner

The authoritative existing UI family declarations are public repository files `data/ui/base508_card_atlas.json::grade_bindings` and `data/ui/base508_card_layout.json::screens`. Their Grade-table SHA is **7ccc62ce1c95ff02cb833e09a68469a1f66ff739db0ada613e4fd498226984da**, identical to `data/lineagem_base508/cards_patch523.json::source_table_sha256.Grade` (also the current523 collection projection's Grade SHA). Thus the existing explicit GradeID family mapping is reused, rather than deriving a family from a localized name, grade rank or coincident ID. The historical ColorTable evidence is ba341e95af631140245bf205131be24e062f37c72a45c96578185561cbe1673e; it is not newly asserted to be a current installed ColorTable.

`source_main_card_frames.gd::bind(pack)` pins each held current component's raw SHA and node, checks its name and complete resource reference against the existing declaration, then calls the image owner's existing `original_card_surfaces.bind("grade_frame",member,sha,node,grade_id)`. `renewal_hud.bind_original_main_ui` invokes this after a successful main-UI binding and refreshes an existing catalogue chrome. Pixels/decoding/canonical card identity/texture display remain in the image owner's APIs. No legacy atlas pixel loader is enabled; no dynamic CSB-root registration assertion is made.

All source members below are under **UI/Change/**. All FileData references have plistFile **UI_Resource/Atlas_Common.plist**, resourceType1 and the exact path shown. Every original Sprite is at position[0,0], anchor[0.5,0.5], authored size[110,134], under **Node/Panel_Root/Nd_Character**. This is static `fileNameData`→existing catalogue/selected-preview `grade_frame`, with no input callback or new attachment transform.

| GradeID | CSB member basename | SHA256 | Sprite offset/name | FileData path |
|---|---|---|---|---|
|1|Change_Card_A_Common.csb|a98120fedf60c03ed6b1a8347e3ce6ad8cd95b6ebdf4d87fb29b4bd1fc36b1e4|2520 Sp_Card_Common|Img_ChageCard_Common.png|
|2|Change_Card_A_Rare.csb|e1a45e737e107e49a6fbc87753dc56303883b9670d0a4cd06cd93db7169f88f2|2524 Sp_Card_Rare|Img_ChageCard_Rare.png|
|3|Change_Card_A_Unique.csb|80c492f2f35f9a021987a8366013e1b36df15a8ead6d224375f2279dbbd92ac8|2568 Sp_Card_Unique|Img_ChageCard_Unique.png|
|4|Change_Card_A_Legend.csb|dfdd5f57b20a100b321b3c97114e8e4fbb82960ec310f0ef894b8f47567348af|2568 Sp_Card_Legend|Img_ChageCard_Legend.png|
|5|Change_Card_A_Epic.csb|ff34c845841a818909497632ff6b1d485609039dede8ece1c03738346788613d|2568 Sp_Card_Epic|Img_ChageCard_Epic.png|
|32|Change_Card_A_Myth.csb|1dcc3c2bbe32ca9ca085af9611750bd329d9ddc0cc5665d6cd73ef450f52312a|2564 Sp_Card_Myth|Img_ChageCard_Myth.png|
|52|Change_Card_A_Sole.csb|675ef6e6628743034e2f19992b96354f1dfd00af6a445df676dea5a18350fe10|2596 Sp_Card_Sole|Img_ChageCard_Sole.png|

Parent offsets: Common Node228/Panel276/Nd_Character1928; Rare228/276/1932; Unique,Legend,Epic272/320/1976; Myth272/320/1972; Sole272/320/2004. Components are in the held current source index, not reconstructed from the old pack. The selected runtime pack must include each explicit partial Sprite scope; missing identities/scopes retain an optional unavailable result without breaking the main HUD. No new grade aliases/fallback are added. Registered status is not an observed render.

The local image receiver at the starting baseline rejected `record.source != lineagem_patch523` before canonicalization. The image owner has independently published the current523 saved-m508 ABI correction in PR28326201afcf. This UI change does not copy/rewrite that owner predicate or relabel saved records. Consumers need both owners' compatible code; registration alone does not prove every card record is accepted/displayed.

## Result-card nodes are a different role

`UI/Change/Change_Card_Result.csb`, SHA846392b76ee58324528002be91665885a1466fb2b515e00e7d4c22ea69406ab1, contains **Node/Card_Result/Nd_Character/Sp_Card_BG11140**, FileData ChangeImg/Card_Slot_BG.png. This is the **inner card backing**, preview-hidden; it is not the whole reveal-stage background consumed by `card_reveal_stage`'s `reveal_background`. Front variants10856/10572/10288/10004/9720 point to Card_Slot_Common/Rare/Unique/legend/Epic.png. Back variants3136/2848/2560/2272/1984 point to Card_Slot_Back_Common/Rare/Unique/legend/Epic.png;1416 is Card_Slot_Back_Line.png. These actual nodes are not substituted for the existing Card_A catalogue-frame declarations. The selected result scene/grade variant and whole-screen background registration still need their own real owner contract; no first-grade/default-back image is chosen here.

## Quest: exact owner search, not a fabricated selected reward model

The held hierarchy is:
`QuestScene476 → Quest_All1728 → Quest_Tab_Main3380 → Quest_Slot_Set → Slot1/2/3/4/5 Project1200/900/660/420/136 → Common_Slot Sprite15012`.

Source SHA values: Quest_All3991dae23f1aafb97a7cea17a7eeecc554ec7e0e9eba46c6ba35806e9b6ef2a8; Quest_Tab_Main99d98120e12f9c3e28f783fe66b6d99bb396656e617dc1d03826033c6f15674a; Quest_Slot_Set9a9a3f1a9b9100b86592db67da9024798d6a6780ec9544c711d40848689f3ab1; Common_Slot b0153e2324de4789e3a5f1d09030f370ed109583e893247656bee5affa3520d6. The last Sprite is the authored icon target; its sample/dummy preview is not a real reward image and must not be displayed as one.

Search results in actual current callers:

1. `source_quest523_projection.gd::build` traverses original QuestReward relations in source-table order, joins RewardID→Reward, retains the raw relation, joins RewardType and Item RewardClassID→ItemClass. This gives identities and source order, not a UI slot assignment.
2. `quest_service.gd::entries` supplies each quest's **eligible** `rewards` from `source.reward_plan(quest,context)`, using current class/received-grant context. That plan filters class/enhancement/exclusions, aggregates EXP/currency and separately retains ordered items/other reward kinds; it is not a five-element mixed display-slot model.
3. `renewal_quests.gd::refresh` displays up to30 quest panels per page. Its `selected` field is a **category**, not a selected quest ID. Each panel currently has title/description/reward/status Labels. There is no single selected quest callback or authored image-slot target. `_reward_text` walks raw source_rewards (including class annotations), not an authoritative currently eligible mixed-slot list.
4. `quest_reward_ownership.gd::proof` validates received physical ID→quest_reward_receipt.reward_id→unique source_rewards.ID→RewardClassID/source_original_item and exact source_reward_id/bless/quantity. This proves an owned reward identity, not selection of a pending quest or its display slot.

Consequently the exact remaining receiver input is **a real selected/displayed quest ID with the owner's ordered complete presentation model for all reward kinds, and its registration to the authored five slots/overflow behavior**. Mapping source_rewards[:5], plan.items[:5], the first visible quest, or a representative image would reorder/drop/misclassify data. No such mapping, new selection/payout policy or truncated reward list was implemented. The UI does not duplicate reward_plan or ownership/save behavior. The complete original definition ZIP was not identified among the held workspace inputs searched; this is not a global absence claim. No denied download was retried. Compiled current card metadata was sufficient for the independent frame connection above.

Public engine reference: Cocos2d-x3.6 CSLoader.cpp846-869 loads a ProjectNode's exact fileName and applies its nodeOptions;924-954 preserves explicit child hierarchy/ListView registration. ProjectNodeReader.cpp122-129 delegates original properties to NodeReader. These prove the engine's declared ProjectNode behavior, not a game-specific dynamic icon-root→Sprite or RewardID→slot relationship:
https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/editor-support/cocostudio/ActionTimeline/CSLoader.cpp
https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/editor-support/cocostudio/WidgetReader/ProjectNodeReader/ProjectNodeReader.cpp

## Local v35 candidate, never a phone update

TWILIGHT_current523_main_game_original_UI_card_frames_v35_20261106.zip:13,741,545B; ZIP SHA2e09f070f8bf7de1516bdb2e63e686388f1c731005965e13682e66c69b035322; manifest9dde8b3c3aea558c78fad71b20b5782ba292d582cbf26a28a7c85438dd77d23f. It retains v34 and adds seven current original Card_A Sprite scopes only. Proposed root source-ui/current523-main-game-original-ui-v35, same selected-pack pair and original_ui.json/receipt.json/originals/UI. Packaging81 files/54 scenes/53 partial scopes/0 dependency blockers is not game-use/completion evidence. No remote file ID or resource upload. v33/v34, frozen v30/62ZIP/index, source bank cf2677b3, Sprite delta, original files and saves are preserved. No new pixels, frames, art, dynamic registration assertions or tests were created/run.
