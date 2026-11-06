# Existing map information caller and original DTH display

Continuation in PR286 after integrating main `d758bcfc0424baa331fc4b954dbf50aa5343ba63`. The local integration preserved PR286's prior fields/production/settings work and main's startup, owner and parser fixes; no main branch write or PR merge was performed. `.agents/skills` is absent from this checkout and `/workspace/.agents`. Repository AGENTS/rules/integrity policy were read. The existing explicit user prohibition on tests/compilation/game/render/CI remains in force; no such commands were run and no runtime pass is claimed.

## Map owner handoff

| Field | Actual source/caller |
|---|---|
| Root | `UI/MapScene.csb`, SHA256 `52334e683d2691c1f4e623933c26e6ea5f94add6485b636ad47b92e02816eafb`, Project132 |
| Component | `UI/Map/Map_All.csb`, SHA256 `f3ed7282f1030de466fdb1c11335889e7d31218eafbed262642f5b84ca0bb46c` |
| Target | Original root `Node/Btn_AreaInfo`, offset2032, `Button`, authored200×42 |
| Original role | Normal3856/Label3916 and Disabled2084/Label2148 both serialize `지역 정보` |
| Input | Existing source_button activation callable; mouse release and source_main_world_map native Android touch routing |
| UI callable | `source_main_map_bindings.gd::open_area_info()` |
| Existing consumer | `patch523_world_panel.gd::open(hud)` |
| Existing owner transition | Panel.open → HUD._open_window("map_links",...) → close_world_map, normal cancellation/disposal, existing WorldLinksPanel.configure(hud.get_parent()) |

`build_map_scene` adds this button only when the activated original Map_All scene contains every exact selected node, the original SHA matches, and the button name and both original labels match. Scope is `[2032,4612,4280,3916,3300,2864,2528,2148]`; the original Normal/Disabled containers and ancestor transforms are retained. No new target, texture, button coordinates, legend or layer is created.

Activation rechecks the current presented map scene and live HUD/field. It opens the existing panel for its existing **current gameplay world** context. It does not pass the selected UIMapWorld ID as a Land/Field/portal ID, select a destination, travel, consume currency or save. The existing panel retains its original current/Aden/portal/spawn modes and service checks; the UI does not duplicate map285 consumers. This is a host information entry attached to the authored region-information button, not evidence that the current host panel reproduces every original client information screen.

Official v30 lacks this button's active scope. Its map remains unchanged. The source pixels/CSB are already held; local candidate v33 adds this permitted scope. **Code publication alone does not make the button available to a v30 installation.** No v33 remote upload or installer selection change was authorized/performed in this continuation.

## Current DTH value reaches its original text pair

The same retained `UI/FloatingUi/CharacterInfo_StatInfo.csb` SHA256 `75e7ad019977077a5e447bba55a5b6f7d15794ad0bca8807143dc275abba620c` has authored SingleNode15320 `Nd_Stat_Dth`, Text15712 title `DTH`, Text15392 value. The stats binder optionally includes that exact pair only when the active source scope contains it. It reads an actual integer `hud.character_state.combination_death_stat`, already produced in World._update_hud by `_effective_attribute("DTH")` and the existing combination dthFlat rules. No bonus calculation, stat allocation, reset, point consumption or save is duplicated.

Changes in the value are tracked by the existing stats view model/refresh path. If that owner integer is absent/wrongly typed, the original DTH group is hidden; zero is never supplied as a missing value. Older source scopes retain their six-field behavior. LFE, elixir counts/actions and original stat-detail semantics remain unconnected; none is inferred from DTH or the half-elixir feature.

## Local candidate only

`TWILIGHT_current523_main_game_original_UI_area_info_dth_v33_20261106.zip` retains v32 (including the unchanged v30 scopes) and adds these original map/stats nodes. ZIP13,693,901B, SHA256 `d6080cb1257f77e64971e0e386ab72e01107401118c895aeecfef30fc696a7ee`; manifest pin `14ed978c9905480c1277929a89099f3bb2c91b9a9d82b024aa22d049736888be`. Candidate relative root is `source-ui/current523-main-game-original-ui-v33`; selector remains TWILIGHT_SOURCE_UI + TWILIGHT_SOURCE_UI_SHA256 (or equivalent CLI), with original_ui.json/receipt.json/originals/UI. There is no remote file ID, installation or selection update. Packaging reports74 original files,47 scene trees,46 partial scopes,0 dependency blockers; these are packaging units, not completed560 roots or game use.

Prior packs, manual-v30 delivery, settings and saves remain preserved. No original resources enter Git. The36 outstanding dependency scopes and previously unestablished CSB-root/Sprite registration, reward/emoticon/dungeon image targets, row repetition, production progress/cancel and batch-transfer contracts are not filled by these additions. No art, Sprite, timing or source relationship was fabricated.
