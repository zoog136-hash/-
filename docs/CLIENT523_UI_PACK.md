# Original UI from the complete 523 client

The original-UI pipeline (`tools/ui/build_original_ui_pack.py`,
`read_source_csb.py`, runtime `scripts/ui/original_ui/`) now takes its inputs
directly from the complete 523 client. No earlier Library/handoff subset is
needed. Every output is private and stays outside Git.

## Commands

```sh
# 1. Verified source index (UI*.dat SHA-1/size vs files_info 523)
python3 tools/ui/client523_ui_inputs.py --files-info files_info.json.523 \
  --dat-dir <client>/Client/Data --output <private>/ui523/inputs

# 2a. Icon CSB pack (every UI/CsbFile/icon/*.csb and its closure)
grep '^UI/CsbFile/icon/' <private>/ui523/inputs/csb-scenes.txt > icon-scenes.txt
python3 tools/ui/build_original_ui_pack.py --source-index <inputs>/source-index.json \
  --scene-list icon-scenes.txt --link-originals --output <private>/ui523/icon_pack

# 2b. Every CSB scene whose whole closure resolves (inventory / later scopes)
python3 tools/ui/build_original_ui_pack.py --source-index <inputs>/source-index.json \
  --scene-list <inputs>/csb-scenes.txt --complete-scenes-only --link-originals \
  --output <private>/ui523/complete_pack

# 3. Icon CSB selection for the source523 image route
python3 tools/ui/build_client523_icon_scene_selection.py \
  --image-manifest <image pack>/manifest.json --ui-pack <private>/ui523/icon_pack \
  --output <private>/ui523/icon-selection.json
# game: --source523-ui-icons=<selection> --source523-ui-icons-sha256=<pin>
```

* `client523_ui_inputs.py` checks each `Client/Data/UI*.dat` listed in files_info
  523 by SHA-1 and size, requires plain (unencrypted) ZIP members, stops on a
  member path present in two DATs, and writes members unchanged (mode 0400)
  for hardlinking. `source-index.json` keeps container, container SHA-1 and
  files_info version per member.
* `build_original_ui_pack.py` gains `--scene-list`, `--link-originals`
  (hardlink unchanged originals from plain-file origins) and
  `--complete-scenes-only`. The last one computes each entry scene's own
  closure with shared verified caches, keeps only complete ones and lists the
  others under `incomplete_source_scenes` with their own blockers. Nothing is
  substituted; the runtime still refuses a pack with blockers.
* `build_client523_icon_scene_selection.py` writes the existing
  `source523-original-ui-icon-selection-v1` document. Playback follows the
  client: the common icon setter (`0x00C381A0`) attaches the AssetType 101 CSB
  to the slot Sprite and calls `timeline.play("normal", true)` (`0x00C386B1`),
  which starts at the clip's start frame and never picks another clip. Each
  binding is therefore `clip normal`, `repeat true`,
  `original_repeat_declared true`, `original_policy_confirmed true`, with the
  evidence in `policy_source`; `estimate_missing_repeat` stays false. A scene
  without exactly one `normal` clip is reported, not given another clip.

## Measured on the complete 523 client (2026-11-09)

| Measure | Count |
| --- | ---: |
| UI DATs SHA-1/size verified against files_info 523 | 154 / 154 |
| Verified members (PNG 3,909, CSB 3,034, plist 550, JSON 394, atlas 393, other 23) | 8,303 |
| CSB scenes decoded by `read_source_csb.py` (all schema 2.1.0.0, no unsupported field) | 3,034 / 3,034 |
| Scenes whose whole closure resolves | 2,903 / 3,034 (95.7%) |
| Icon CSB scenes (`UI/CsbFile/icon/`) with a unique `normal` clip | 183 / 183 |
| Icon pack: scenes / files / blockers | 183 / 474 / 0 |
| CSB icons bound (1 AssetView CSB is absent from the client) | 181 / 182 |
| ItemClass / SpellClass / BuffClass icon references bound | 483 / 177 / 1 (all 661) |

Real-pack Godot check (`tests/source523_icon_scene_selection_test.gd` with the
image pack and the selection) through the game's own routes
(`describe_item_class`, skill/buff `describe_*_class_row`,
`attach_original_icon`): 638 of 661 references link with the client `normal`
loop (`explicit_caller_repeat`, `original_policy_confirmed`). The other 23:

* 21 ItemClass rows are source `TestItem` rows that the game already excludes;
* 2 items (`Fx_Item_Master_Coupon_Change.csb`, `Fx_Item_Master_Coupon_HolyStuff.csb`)
  have a touch-enabled `Panel_Shining`; the strict player refuses an
  unconnected input, and no client evidence states how that input is handled.

The 131 incomplete scenes name members absent from the 523 client (unique
members: 304 PNG, 100 atlas frames, 27 nested CSB, 4 plist). For an absent
nested CSB the client's ProjectNode loader makes an empty Node (static analysis
P11, `Node::create` fallback); that fallback is not implemented in the strict
player yet, so those scenes stay listed rather than packed. The complete pack
manifest is about 194 MB, above the runtime's 128 MB manifest limit, so it is
an inventory and a source for scoped packs, not a runtime selection.

## Main HUD pack and the UI add-on (2026-11-09)

The original main HUD (`scripts/ui/original_ui/source_main_hud.gd`, bound by
`renewal_hud._bind_selected_original_main_ui`) now comes from the 523 client
as a resource-pack add-on, so an installed 31-part pack is not reinstalled.

```sh
python3 tools/ui/build_client523_main_ui_pack.py \
  --source-index <private>/ui523/inputs/source-index.json --output <private>/ui523/main_pack
python3 tools/android/build_client523_addon.py --ui <private>/ui523/main_pack --output <private>/addon-ui
# -> twilight523-addon-ui.zip, picked in the same installer ("리소스 팩(.zip) 선택")
```

* Scenes: every scene the main HUD code names whose whole 523 closure resolves
  (42), the parents it reads as geometry (`MainScene`, `HUDScene`, workspace
  parents) as layout sources, and explicit node scopes for the incomplete ones
  (`ToolTip_HudType_Right`, `ToolTipScene`, `Storage_All`, `Store_All`) plus
  `Hud_CharInfo` (so the poison bar and level label are in scope).
  `UI/FloatingUi/FloatingUiScene.csb` is left out (its closure names absent members).
* All 53 SHA-256 pins in the main HUD code match the 523 client files.
* Measured: 269 scenes, 594 originals, 0 blockers, manifest 24.4 MB
  (`1d4e0ad4e5c5…`), add-on ZIP 94 MB. The repo tool reproduces the same
  manifest SHA.
* The add-on's `ui` section becomes `TWILIGHT_SOURCE_UI`/`_SHA256`
  (`scripts/boot/source523_pack.gd` `selections()`); the installer asks for any
  missing add-on (`missing_addons()`: world_links, ui) and can be postponed.

Fixes found while connecting:

* `source_pack.gd` now stores node scopes, partial-scene offsets and external
  texture nodes as ints. JSON loads them as floats and `[1012.0].has(1012)` is
  false in Godot 4.7, so every partial scope was refused.
* Vitals and blessing buttons used `Callable(local_input, ...)`; a Callable does
  not keep a RefCounted alive, so the input was freed and the button refused
  as unconnected. They now use lambdas that hold the input.

Real pack boot (`tests/current523_main_ui_test.gd`, 523 Aden): EXP, HP/MP,
primary stats, attack pad, top menu, wallet, blessing, map name, target,
auto message, character, inventory and item name mount. Not mounted:
system message (523 `Text_Line` carries `customProperty {"transfer":"false"}`,
which the strict player does not interpret), quickslot (needs owner visuals),
inventory lock (mounts when an item detail is open).
