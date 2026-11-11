# Original NPC dialogue caller

This connects an existing main-game conversation to held original nodes. It
adds no dialogue content, choice, reward, portrait, service or save behavior.
Attendance/pass remain deferred. No new tests, execution, rendering or CI were
run; this code and its actual game consumption are unverified.

## Original 523 input (2026-11-11)

TWILIGHT's own dialogue data (`dialogue_service`, `twilight_dialogues.json`,
the old six L1J NPCs) is removed. Talk comes only from the original 523 town
NPCs placed by `scripts/npc/source523_town_npcs.gd` (EarthObjectSpawn →
one-cell Territories row of the field's Land; name from DescData_Korean;
functions from EarthObjectDialogActions/DialogActionType). Page text is the
original DialogData_Korean row named in `data/npc/source523_npc_dialog_links.json`
(row ID + Name only; built by `tools/npc/build_source523_npc_dialog_links.py`
because the client tables have no NPC→dialog column). Unlinked NPCs show
their original name and an empty text.

`renewal_dialogue._show_node` (a non-drawing owner) resolves one page and
emits `source_dialogue_resolved(resolved)`. Page *i* has one choice `next=p(i+1)`;
the last page has one choice `action=<function>` when the NPC has a connected
original function (shop, buyback, craft, teleport, warehouse).

`source_main_npc_dialogue_view.open(parent,owner,resolved)` shows name/text and
the close button. The window's only advance control, full-screen Btn_Next,
dispatches the single choice through the owner's `_choice_picked`: the next
page, or on the last page the function request, which World checks again
(distance, page, function) before opening the existing screen. There is no
TWILIGHT dialogue screen: when this window cannot open, the talk closes with
its reason.

## Exact originals

| Member | SHA256 | Parent/project |
| --- | --- | --- |
| `UI/NpcDialogueScene.csb` | `6626721d95d1ca4c2b097730b44d97ce8aa8afb371b5e7806158db788f043765` | Project132, position[0,0], alpha255 |
| `UI/NpcDialogue/NpcDialogue_All.csb` | `f27872592f0f7f6b74b81308bc64f98f4bc337beff60c030f4f1ac060aed4ccf` | root132→Nd_Npc184 |

| Original node | Existing data/caller |
| --- | --- |
| Text3512 `Text_Char_Name` | current successful `npc_name` |
| Text3940 `Text_NpcTalk` | current successful `text` |
| Button272 `Btn_TalkEnd` / literal324 | existing workspace close / `대화 끝내기` |
| Button1872 `Btn_Next` | next original page, or the NPC's function on the last page |
| Image6800 `Black_BG` | original touch-enabled full-screen backdrop |
| Image6172 `Talk_BG`, Image780 | original dialogue/close backdrops |

The opening caller plays actual `Npc_On`5–45 once. Original `Npc_Loop`50–80 is
retained in source metadata and not started without a loop policy. All authored
positions, alpha, fonts, original design1200×675 and source animation frames
remain with the existing renderer. Native touch uses the same source-button
router and the original full-screen backdrop owns its input. This adds no mouse
emulation setting or generated hit layout.

## NPC image owner boundary

The later v14 optional receiver is documented in
[NPC portrait ABI](ORIGINAL_UI_NPC_PORTRAIT_ABI.md). It supersedes the v11
excluded-scope boundary only when the actual current dialogue context and
image-owner inputs are present. It does not establish those IDs by itself.

The actually authored portrait target is Sprite4912 `Sp_Char`, under
Nd_Char4860 at[-3.086400032043457,-2.2193000316619873]. Sprite4912 has original
position[0,0], size500×500 and anchor[0,0]. Its editor reference is
`Effect/Common_Effect_texture/Npc_Dummy_Lala.png` without an atlas. That reference
does not establish the actual current NPC→portrait asset role or identity.
It is excluded from this native scope, along with unrelated static preview
labels/icons. No dummy classification is made from the filename alone, no
original is deleted and no preview is used as an NPC's real image. The image270
consumer can use this exact target identity when the real producer role arrives.
The generic native CSB root→Sprite registration gap is unchanged.

## Single combined v11 installer input

This includes delivered v10 character scopes and all earlier combined main,
world-map, inventory, quickslot and auto-message inputs. It needs no installed
base pack. Consumer installation/game execution remain unconfirmed.

- Drive ID: `1EjhcL6LVJaZQwQ31c4wRiFLemOTpmMFx`.
- Filename: `TWILIGHT_current523_main_game_original_UI_combined_v11_20261105.zip`.
- ZIP size: **13,305,246 bytes**.
- ZIP SHA256: `76d41ae11a3344c353bb58185ad7eb9dcf708386c1cba602c51ae4ca1398d87c`.
- Manifest pin: `344cd7a0669ab04c5e500be3220f525758b2e1ea3fce71873cbca0f6d3690a59`.
- Relative destination: `source-ui/current523-main-game-original-ui-v11`.
- Extracted root: `original_ui.json`, `receipt.json`, `originals/UI/...`.
- 48 raw original files,28 scene trees,27 partial scopes; producer static
  dependency blockers0. These are packaging units, not completed UI roots.

Use the same existing `--source-ui=<root>` /
`--source-ui-sha256=<manifest pin>` or `TWILIGHT_SOURCE_UI` /
`TWILIGHT_SOURCE_UI_SHA256` selection. The private Drive upload succeeded;
metadata reports the same size and owner-user-only permission. Earlier packs,
configs, source data and saves are preserved. There is no old card/monster pack
requirement, automatic config switch or public original asset upload.
