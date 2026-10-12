# TWILIGHT PvE-only scope — 2026-10-12

## Explicitly excluded from the product

1. **PvP-only skills**. Exclude their skill definitions, learn/acquisition rules, quickslots, auto-cast, and presentation. Do not reinterpret player-targeted PvP skills as monster attacks.
2. **PvP, clans and castle siege**. No player-target combat, clan membership, clan warehouses, or siege scheduling.
3. **Player-to-player trades, marketplace and auctions**. Retain NPC shops, local buyback, crafting and the personal warehouse.
4. **Parties and user chat**. Retain offline combat/system logs; these are not network chat.
5. **Quests**. Remove quest progress counters, HUD and menu routes, NPC quest conditions/actions, and writing new quest save fields. Older saved `quest_kills` fields are simply ignored; all other save data remains loadable.

## Implementation facts and remaining boundaries

- As of main `2f5ae1013da5c7281d3020719d8a723a23adb8cc`, the base 257 skill definitions contain no explicitly marked PvP-exclusive skill. No PvP, clan, siege, trade exchange, marketplace, auction, networking, party or user-chat gameplay service exists in main.
- Draft PR #59 separately reports **two `PVP_EXCLUDED` entries** in its source research catalog. Do not merge those into executable skill data; when integrating that PR, remove those entries from shipped runtime catalogs and regenerate inventories/statistics. This change does **not** mutate the in-progress PR #59 branch.
- Archival source catalog text and legacy PvP-to-PvE **numeric equipment-option conversions** remain for compatibility and pre-existing single-player balance; these are not a PvP subsystem. An independent balance migration would be needed before removing them. Do not delete PvE combat mitigation.
- Retain existing PvE combat, monster AI, class skills, bosses, NPC trading, ground drops, item instances, crafting, warehouse, save/load, auto-hunting, and offline combat logs.
- This branch removes the active quest implementation and its obsolete UI source. Source/history documentation and archival `legacy/` files are retained for audit rather than rewritten.

## Verification required before merging

- Static audit: no `open_quest_info`, `quest_kills`, `set_quest_progress`, `QuestTracker`, `open_chat_info` or PvP-exclusive skill record in shipped runtime files.
- Godot parse/import and complete regression suite `python3 tools/test_project.py` on Godot 4.7.2, plus NPC dialogue, UI renewal and HUD fidelity tests; no result claimed without a run.
- Manually inspect menu and touchscreen HUD for removed tiles, and verify NPC shop, crafting, PvE combat/EXP, AUTO, combat log, old saves and new saves.
- Keep `main`, PR #59, PR #83 and PR #84 untouched until approval and successful testing.
