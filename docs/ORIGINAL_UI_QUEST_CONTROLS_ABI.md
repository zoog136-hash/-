# Original quest category and close controls

The existing quest caller now consumes its original Main/Achievement tabs and
screen-close button. Existing filters, other categories, rows, pagination,
automatic progression and reward ownership stay in the existing owner. This is
partial chrome, not a completed original quest screen or reward-image target.
No new test, execution, rendering or CI was run.

## Exact source and caller

`UI/QuestScene.csb` SHA256
`d11ff59b60b9e80d953358ac50b740ab2858548577deede67b5847e706cae717`
declares Quest_All_Layout Project476 at[600,337.5], visible1/alpha255. It
references `UI/Quest/Quest_All.csb`, SHA256
`3991dae23f1aafb97a7cea17a7eeecc554ec7e0e9eba46c6ba35806e9b6ef2a8`.
Original parents, transforms, sprites, fonts, literals and On/Off faces remain
unchanged. The parent declares Select_Popup_On5–15; this adapter infers no
autoplay or repetition policy and does not play it.

| Actual category | Original On / Off | Source literal nodes |
| --- | --- | --- |
| main |26500 /25048|26952 /25100, `메 인`|
| achievement |18928 /17520|19380 /17572, `업 적`|

Original screen Close2412 remains its source button/pixels. The active scope
also retains only the buttons' actual icon/background descendants:
27408/26556/25428/19708/18984/17900. No content root or dynamic row is fabricated.

`hud.open_quests()` configures the actual existing quest_view and then calls
`original_main_ui_controller.bind_quest_controls(view)`. Native Main/Achievement
call the same current owner `_select(category)` used by its existing buttons.
That owner still resets its own page and refreshes its own data; this adapter
adds no category classifier, reward/quest selection or claim operation.
Close calls the existing `hud._close_workspace()`.

Freshness requires the actual quests section, identical current quest_view,
visible owner and existing matching category buttons. Original On/Off visibility
follows **owner.selected**. Common/other show both original pairs Off; Sub is
not equated with common. Disabled state follows the existing owner buttons.
The owner emits `source_category_changed` after its existing selection refresh,
so both source clicks and the still-available other categories update the same
source state. No quest ID is chosen by this adapter.

Only after source mount succeeds are the existing Main/Achievement buttons
hidden. Closing, owner hiding, replacing the controller or source failure
restores their captured visibility. The existing common/other buttons, filters,
list, installer and pagination stay accessible. The source wrapper is hosted
above the existing workspace, below existing detail/companion/confirmation;
Android uses its actual original hit controls and the existing source router.
The current workspace filter may keep text focus while those same source
actions are touched; only that focus is excepted. Detail/companion/map,
starting-character, death/result, confirmation and pointer guards remain.
No source positions are moved to align with a different layout.

## Remaining original quest content

The original main page has empty lists; a dynamic quest row/template assignment,
actual selected canonical QuestID, goal/state field mapping, claim target and
reward→original slot assignment remain unestablished. These category controls
do not establish those inputs or an image target. The independent original
reward target handoff and image owner boundary are unchanged.

SpecialDungeon's newly supplied `selected row.EntranceAssetID` is a different
caller. The current source_dungeon_view has no authored entrance target or
component bridge; its ItemList is not converted into one. Party/Competition
IDs and HelpBox roles are not substituted. Image270's merged consumer stays
with its owner and is not reimplemented here.

## Combined private input

The combined **v18** retains every v17 input and adds only the exact quest
controls above. Root structure is `original_ui.json`, `receipt.json`,
`originals/UI/...`, selected through the unchanged single-pack CLI/env contract
at `source-ui/current523-main-game-original-ui-v18`. Earlier packs, configs,
originals, fixed denominators and saves remain preserved.

ZIP: `TWILIGHT_current523_main_game_original_UI_combined_v18_20261105.zip`,
Drive ID `1sxHpeLcIS7TL_FgbZ_8t--dWbhztfCn4` (private upload succeeded),
**13,485,574** bytes; SHA256
`fce45123bd26d0750c13cb3b9dff0ea7fade179f907aa2b62fdfc1d36e812d42`;
manifest pin
`228afdd21003bb8da99f1fc4857c9103a005f6b2451286011c13a3cdf7ad9b9d`.
The58 raw originals/38 scene trees/37 partial scopes and producer blockers0 are
packaging facts, not completed roots or actual game use. Consumer installation,
button interaction and rendering remain unconfirmed.

The initial same-branch git push failed with
`could not read Username for 'https://github.com': No such device or address`.
No authentication/URL change or git-push retry was made. Following the user's
explicit instruction to finish and merge this work, the existing connected
GitHub API published the integrated code at
`0e413bd3e3c6e7c46f0928cc3b9fdc623eca2f71`. The earlier public b21c3b27 used
v17; current v19 retains this v18 quest scope together with the newer lock
controls. Pack delivery, installation and verified operation remain distinct.
