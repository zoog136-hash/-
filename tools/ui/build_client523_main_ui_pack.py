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
# Storage_All / Store_All: workspace close/title controls (source_main_workspace_controls).
NODE_SCOPES = [
    ("UI/ToolTip/ToolTip_HudType_Right.csb", [37228, 37860, 37284, 36120, 36708, 36176, 44536, 44160, 956]),
    ("UI/ToolTipScene.csb", [1012]),
    ("UI/Main/Hud_CharInfo.csb", [46576, 40620, 37172, 35464, 35528, 20552, 20060, 39796, 34940, 18508, 18556, 15324, 15372]),
    ("UI/Storage/Storage_All.csb", [47160, 48640, 47920]),
    ("UI/Store/Store_All.csb", [67396]),
    # World map (source_main_map_bindings.build_map_scene): row, area with the
    # World image slot 44440 (pixels come from the 523 image pack), Map_All, MapScene.
    ("UI/Map/Map_List_Button.csb", [7440, 4508, 7492, 4560]),
    ("UI/Map/Map_Tab_Area.csb", [44440, 37316]),
    ("UI/Map/Map_All.csb", [35332, 34904, 30312, 29552, 29228, 31656]),
    ("UI/MapScene.csb", [132]),
]
EXTERNAL_TEXTURE_NODES = {"UI/Map/Map_Tab_Area.csb": [44440]}
# Whole original scenes minus the subtrees whose closure names a member the
# 523 client lacks (or that the code does not mount), nested members first:
# DominationStone_Inventory references QuickSlotEdit_SlotSet.csb, absent from
# the client, so the domination window (source_main_domination_stone_window)
# leaves its inventory ProjectNodes (and the dismantle tab and probability
# popup it does not connect) out. Every other node is kept.
WHOLE_SCOPES = [
    ("UI/DominationStone/DominationStone_Power_Effect.csb", [176]),
    ("UI/DominationStone/DominationStone_Tab_Power.csb", []),
    ("UI/DominationStone/DominationStone_Tab_Fusion.csb", [41780]),
    ("UI/DominationStone/DominationStone_All.csb", [15692, 332]),
    ("UI/DominationStoneScene.csb", []),
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
    receipt = builder.build(entries, output)
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
