# Existing skill selection to original detail controls and tooltip

PR286 continuation afteraf132a2dbb679b2a696db0d9663c5d80c8e99690. This adds a coherent partial original skill screen path: main close, original details input, actual selected skill name/class, tooltip close, refresh/invalidation and native touch. It does not replace the entire skills screen or implement learning, casting, quickslot registration, costs, cooldowns, images, locks or saves. Code is unexecuted/unverified; tests/compile/game/render/fullCI/upload/merge were not performed.

## Actual caller and data

The existing `renewal_hud.open_skills()` opens workspace section `skills`, mounts `renewal_skills` and configures it with that HUD. That view's existing `select(index)` sets `selected=filtered[index]`; its original selection sheet already displays that record's name/class and retains all use/learning/image callbacks.

New `source_main_skill_controls.gd` accepts only the live visible exact renewal_skills script, its actual HUD/workspace ancestor and active `skills` section. A valid detail requires the actual nonempty String `selected.id`, a unique row with that ID in the current filtered list, complete row equality and an actual nonempty String name. No display-name lookup, numeric-ID alias, first row or selection mutation is introduced. Class text is passed from that same existing selected record; it is not derived from an icon, job name or a new table join. Missing class hides its original row; absent/invalid selection disables the original details control and closes the tooltip. Existing owner presentation remains available for unsupported IDs.

`source_main_workspace_controls` now admits this actual skills owner alongside the existing warehouse/crafting/shop owners. Its original main close calls the existing HUD workspace close. The new helper owns only the original additional detail control and original tooltip. Other feature owners' data/providers/consumer files were not changed.

## Exact authored source hierarchy

| Member | SHA256 | Proven parent |
|---|---|---|
|UI/FloatingUi/Skill_All.csb|5f2f800c5e461c372cc2b9de13b9c742f9879115fb1028c937668f054e00f099|UI/FloatingUiScene.csb SHA b689e91a9fc15eda9c35bed5b1073588a33a416a57890c293c531fe5c69ccbc8, Project10236 Skill_All_Layout|
|UI/ToolTip/ToolTip_HudType_Skill.csb|1d7512e791b02975dc6be141f443d5f98c746c752ab6c7717ef3998013b32dc2|UI/ToolTipScene.csb SHA9304dcb5730fba9a155f73a291a6e87f96768156cee972929b003386e3904a1d, Project728 Skill_ToolTip_Layout|

Both original Project parents are position[1008,345], scale[1,1], anchor[0,0], rotation[0,0], size[0,0], alpha255. Main parent preview is visible1; tooltip preview is visible0. The user's actual original details-button activation controls tooltip visibility, preserving those parent coordinates. No centering, viewport fit, rewritten anchor, clip selection or frame/seconds timing is supplied.

Main partial scope:

- Skill_All root Node220/Btn_Close16260 → existing HUD._close_workspace.
- Node220/Menu_Button2144/Btn_Search11160 has literal `상세 보기` in Normal12120/Text12172 and Disabled11212/Text11264. Original button enable/Normal/Disabled branches follow whether the actual owner has a valid selected row. This source literal establishes the details action; the Search name is not reinterpreted as name filtering.

Tooltip partial scope:

- Node256/Title18372/Sprite18856 is retained original title decoration.
- Node256/Title18372/Text18428 Label → actual selected record.name.
- Node256/ItemInfo1000/ListView_BasicInfo15176/Panel_set15228/Text15964 Text_Title retains literal `클래스`; Text16328 Text_Desc → that same selected record's class. The single authored row and ListView geometry are retained; no clone, reorder, synthetic rows or replacement form is added. Its touch area consumes its existing read-only input.
- Node256/Btn_Close316 → close only this source tooltip; selected skill and game state are preserved.

The generic Text17476 preview, set-effect list, lock/unlock, help, target buttons and learn/cast/register meanings are outside the scope. A suggestive name or generic preview does not establish those roles. No new image receiver is created and no original pixel/provider contract changes.

## Receiver methods and lifetime

`SourceMainSkillControls.configure(pack: RefCounted, owner: Control) -> Dictionary` checks exact component/parent SHA and activated source offsets. `refresh(parent: Node)` mounts the original detail control on the real source-coordinate parent supplied by the existing UI controller and updates selection availability. A rejected static mount is not retried every frame.

`open_detail() -> Dictionary` is bound to original11160. It re-reads the actual selected row, configures the original Project728 subtree and stores the exact selected ID. `close_detail() -> Dictionary` clears/releases only that source tooltip. `refresh` updates name/class for the same ID, and closes it when selection changes/disappears. It does not automatically open a new tooltip for a replacement selection. Owner hide/exit and workspace close release both original scenes and disconnect callbacks.

`presentation()` exposes `additional_scenes`, `foreground_scenes`, `selected_id` and partial-scope state. The existing main HUD collects these actual source button objects into its native touch router. The open tooltip's close control receives foreground priority over overlapping main close controls, consistent with its actual displayed layer; existing router capture/release rules remain. `blocks_point` uses the actual original button/input controls, not guessed screen rectangles. Mouse handling remains the existing source renderer's.

The existing main skills view, selection sheet, preview, source identity, image providers, cast/learning/quickslot controls, prices, transactions and saves remain their current owners'. This is source-backed view/control connection, not observed runtime or full-screen completion.

## Separate local v40

v40 retains v39 and adds two supplied source CSBs with nine explicit selected offsets: Skill_All[16260,11160,12172,11264], Skill tooltip[18856,18428,16328,15964,316]. Source bytes/pixels are unchanged.

- `TWILIGHT_current523_main_game_original_UI_skill_details_v40_20261106.zip`,14,233,819B.
- ZIP SHA256 `81f3e97cb9280f7f24fbf1024107a93b74ad6d6e3426def885004e4a32810bee`.
- Manifest pin `2896eacfabc114d3c4d3f989cce7997b42e2b163da2bec8452c6622e111f244c`.
- Proposed relative root `source-ui/current523-main-game-original-ui-v40`.
-101 original files/60 scoped scenes/59 partial scopes are packaging quantities, not UI completion or game-use counters.

No remote ID, upload, installation, phone/index/bank change. Frozen v30/62ZIP and all earlier local candidates/configs/saves/originals are preserved. No excluded spell-stage/potion/emoticon/sound work was resumed. Known result-parent, dungeon insertion and mixed quest-reward presentation dependencies remain separate; current-target portrait source absence was not re-audited or repurposed.
