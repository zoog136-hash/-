#!/usr/bin/env python3
"""Build the original main HUD pack from the complete 523 client UI index.

The scenes are the ones the game's main HUD code names
(scripts/ui/original_ui/source_main_*.gd): every one whose whole closure
resolves in the 523 client is packed whole. Parents the code reads only as
geometry are layout sources. Scenes whose closure names members absent from
the 523 client are packed as the explicit node scopes the code mounts.
Nothing is substituted; the pack must have zero blockers.

    python3 tools/ui/client523_ui_inputs.py --files-info files_info.json.523 \\
        --dat-dir <client>/Client/Data --output <private>/ui523/inputs
    python3 tools/ui/build_client523_main_ui_pack.py \\
        --source-index <private>/ui523/inputs/source-index.json \\
        --output <private>/ui523/main_pack
    python3 tools/android/build_client523_addon.py \\
        --ui <private>/ui523/main_pack --output <private>/addon-ui

The output holds original client files: keep it private.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(HERE))
from build_original_ui_pack import Builder  # noqa: E402

CODE = ["scripts/ui/original_ui/source_main_*.gd", "scripts/ui/original_ui/sprite_scene.gd",
        "scripts/ui/original_ui/source_button_router.gd", "scripts/ui/original_ui/source_node_scope.gd"]
# Parents read through pack.layout_source() (geometry for configure_project).
LAYOUT_SOURCES = ["UI/MainScene.csb", "UI/HUDScene.csb", "UI/MissionScene.csb", "UI/StorageScene.csb",
                  "UI/ProductionScene.csb", "UI/ShopScene.csb", "UI/StoreScene.csb", "UI/SystemMessageScene.csb",
                  "UI/MapScene.csb", "UI/FloatingUiScene.csb", "UI/QuickSlotScene.csb", "UI/NpcDialogueScene.csb",
                  "UI/QuestScene.csb", "UI/EnchantScene.csb"]
# Parents used only as geometry: not packed as whole scenes.
LAYOUT_ONLY = {"UI/MainScene.csb", "UI/HUDScene.csb", "UI/MissionScene.csb", "UI/StorageScene.csb",
               "UI/ProductionScene.csb", "UI/ShopScene.csb", "UI/StoreScene.csb"}
# Explicit node scopes, nested members first (a parent's ProjectNode then
# reuses the scoped child). Offsets are the ones the HUD code mounts:
# ToolTip_HudType_Right: inventory lock view + item name (source_main_inventory_*).
# ToolTipScene: their parent ProjectNode 1012.
# Hud_CharInfo: vitals (CHAR_NODE_OFFSETS, POISON_BAR, CLASS_PROJECT) + primary stats.
# Store_All: workspace close/title controls (source_main_workspace_controls).
NODE_SCOPES = [
    ("UI/ToolTip/ToolTip_HudType_Right.csb", [37228, 37860, 37284, 36120, 36708, 36176, 44536, 44160, 956]),
    ("UI/ToolTipScene.csb", [1012]),
    ("UI/Main/Hud_CharInfo.csb", [46576, 40620, 37172, 35464, 35528, 20552, 20060, 39796, 34940, 18508, 18556, 15324, 15372]),
    ("UI/Store/Store_All.csb", [67396]),
    # World map (source_main_map_bindings.build_map_scene): row, area with the
    # World image slot 44440 (pixels come from the 523 image pack), Map_All, MapScene.
    ("UI/Map/Map_Tab_Area.csb", [44440, 37316]),
    ("UI/MapScene.csb", [132]),
]
# Clan_Slot_Join_Donate_Item Sp_IconSample 4788: the weekly donation reward's
# item picture comes from the image owner (source_main_clan_window).
# Map_Tab_Teleport Payment/Icon 7356: the 지역 이동 fee is Adena, so the
# teleport window (source_main_teleport_window) shows Atlas_Common's
# Com_Icn_Adena there instead of the authored diamond.
EXTERNAL_TEXTURE_NODES = {"UI/Map/Map_Tab_Area.csb": [44440], "UI/Map/Map_Tab_Teleport.csb": [7356], "UI/Clan/Clan_Slot_Join_Donate_Item.csb": [4788]}
# Plain original pictures the code loads by path from the pack (not named by a
# scene): the clan emblem PNGs of AssetType 111 "Emblem" (Path UI/Emblem/),
# shown by source_main_emblem_window through Emblem.EmblemLargeID/AssetView.
PICTURE_PREFIXES = [("UI/Emblem/", ".png")]
# Whole original scenes minus the subtrees whose closure names a member the
# 523 client lacks (or that the code does not mount), nested members first:
# DominationStone_Inventory references QuickSlotEdit_SlotSet.csb, absent from
# the client, so the domination window (source_main_domination_stone_window)
# leaves its inventory ProjectNodes (and the dismantle tab and probability
# popup it does not connect) out. Every other node is kept.
WHOLE_SCOPES = [
    # The storage window (source_main_storage_window): Storage_All without the
    # cart, 자동 보관, list mode, 모두 찾기/맡기기, batch count buttons, help,
    # dungeon message, particle and spine it leaves out. Storage_Inventory's
    # SlotSet names QuickSlotEdit_SlotSet, absent from the 523 client: the
    # window shows Inventory_Slot_Set lines there instead (user decision A안).
    ("UI/Storage/Storage_Inventory.csb", [13764, 396]),
    ("UI/Storage/Storage_AccountInvGridMode.csb", [6672, 412]),
    ("UI/Storage/Storage_All.csb", [46564, 46252, 45968, 45420, 43992, 42648, 34968, 16280, 2384, 900, 640, 51812, 50252]),
    # Clan_Slot_Join_Donate_Item whole; its Sp_IconSample is external (above).
    ("UI/Clan/Clan_Slot_Join_Donate_Item.csb", []),
    # The clan window (source_main_clan_window) mounts the 창설 / 혈맹 정보
    # tabs and the 기부 popup only: the online-only relation lists, attendance,
    # notice input, donation ranking and shop detail are left out.
    ("UI/Clan/Clan_Tab_Join_Info.csb", [23488, 23204, 22940, 848, 588]),
    ("UI/Clan/Clan_Popup_Join_Donate.csb", [840, 572]),
    ("UI/Clan/Clan_All.csb", [6780, 6260, 6020, 5720, 5464, 5216, 4960, 4456, 4200, 3956, 3700, 3460, 3208, 2912, 2396, 2152, 1880, 1636, 1372, 1116, 868, 600, 336]),
    # Map_Tab_Teleport (source_main_teleport_window) without the destination
    # preview, open effect, particle, spine, list filters and tax it leaves out;
    # Payment/Icon 7356 is an external texture node (see above).
    ("UI/Map/Map_Tab_Teleport.csb", [14968, 14368, 17432, 11104, 1560, 664]),
    # Map_List_Button rows (world map and teleport list) without the bookmark
    # star (Btn_CheckBox) neither window connects; the world map's
    # 7440/4508/7492/4560 scope stays covered (Android world-map contract).
    ("UI/Map/Map_List_Button.csb", [1784]),
    # Map_All: the world map (source_main_map_bindings, Map_Tab_Area) and the
    # teleport tab (source_main_teleport_window, Map_Tab_Teleport) with the
    # frame and tab bar; the world / dungeon / siege tabs and the skill slots
    # are not mounted. It keeps the world map's 35332/34904/30312/29552/29228/
    # 31656 scope (Android world-map contract).
    ("UI/Map/Map_All.csb", [31940, 31372, 30868, 512, 7648]),
    ("UI/DominationStone/DominationStone_Power_Effect.csb", [176]),
    ("UI/DominationStone/DominationStone_Tab_Power.csb", []),
    ("UI/DominationStone/DominationStone_Tab_Fusion.csb", [41780]),
    ("UI/DominationStone/DominationStone_All.csb", [15692, 332]),
    ("UI/DominationStoneScene.csb", []),
    # Change_Awaken_Skill names the same absent QuickSlotEdit_SlotSet for its
    # 각성서 inventory; the card awakening window
    # (source_main_card_awakening_window) leaves that ProjectNode out.
    ("UI/Change/Change_Awaken_Skill.csb", [23400]),
    ("UI/Change/Change_Awaken_All.csb", []),
    # ItemBook_All's trade purchase popup (Trade_Popup_Purchase_Batch) names
    # an Atlas_Hud frame absent from the 523 client; the item book window
    # (source_main_item_book_window) leaves that ProjectNode out.
    ("UI/ItemBook/ItemBook_All.csb", [1784]),
]


def whole_scope_offsets(builder: Builder, member: str, excluded: list[int]) -> list[int]:
    """Every node offset of the original scene except the excluded subtrees."""
    builder.layout_source(member)
    tree = builder.layout_sources.get(member)
    if tree is None:
        raise ValueError('Whole scope source missing: ' + member)
    found, offsets = set(), []

    def walk(node):
        if node['_offset'] in excluded:
            found.add(node['_offset'])
            return
        offsets.append(node['_offset'])
        if node.get('classname') == 'ProjectNode':
            return
        for child in node.get('children', []):
            walk(child)
    walk(tree['nodeTree'])
    if found != set(excluded):
        raise ValueError('Excluded offset not present: ' + member)
    return offsets


def code_members(repo: Path) -> list[str]:
    found = set()
    for pattern in CODE:
        for path in sorted(repo.glob(pattern)):
            found.update(re.findall(r'"(UI/[A-Za-z0-9_/]+\.csb)"', path.read_text(encoding="utf-8")))
    return sorted(found)


def build(source_index: Path, output: Path, repo: Path = REPO) -> dict:
    index = json.loads(source_index.read_text())
    files = index.get("source_files", index)
    # Completeness probes share read caches with each other, not with the
    # pack: an incomplete scene's files never reach the output.
    prober = Builder(files, link_originals=True)
    # Parents of a whole scope resolve their scoped children in the probe too.
    for member, excluded in WHOLE_SCOPES:
        prober.node_scene(member, whole_scope_offsets(prober, member, excluded))
    scoped = {member for member, _ in NODE_SCOPES} | {member for member, _ in WHOLE_SCOPES}
    entries, skipped = [], {}
    for member in code_members(repo):
        if member in scoped or member in LAYOUT_ONLY:
            continue
        if member not in files:
            skipped[member] = "absent_from_client"
            continue
        probe = prober.closure(member)
        if probe.blockers:
            skipped[member] = "closure_incomplete"
            continue
        entries.append(member)
    builder = Builder(files, link_originals=True)
    for member, offsets in EXTERNAL_TEXTURE_NODES.items():
        builder.external_texture_nodes[member] = list(offsets)
    for member in LAYOUT_SOURCES:
        builder.layout_source(member)
    for member, offsets in NODE_SCOPES:
        builder.node_scene(member, offsets)
    for member, excluded in WHOLE_SCOPES:
        builder.node_scene(member, whole_scope_offsets(builder, member, excluded))
    pictures = sorted(m for m in files for prefix, suffix in PICTURE_PREFIXES
                      if m.startswith(prefix) and m.endswith(suffix))
    for member in pictures:
        builder.read(member)
    receipt = builder.build(entries, output)
    receipt["pictures"] = len(pictures)
    receipt["entries"] = len(entries)
    receipt["skipped_code_scenes"] = skipped
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    return receipt


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--source-index", type=Path, required=True, help="client523_ui_inputs.py source-index.json")
    parser.add_argument("--output", type=Path, required=True, help="new private directory")
    args = parser.parse_args(argv)
    if args.output.resolve().is_relative_to(REPO):
        parser.error("Original UI packs must stay outside the public checkout")
    receipt = build(args.source_index, args.output)
    print(json.dumps(receipt, ensure_ascii=False))
    return 0 if receipt["blockers"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
