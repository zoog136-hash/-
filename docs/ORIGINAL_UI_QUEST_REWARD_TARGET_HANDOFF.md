# Original quest reward image target boundary

Current game quest presentation has Labels, not an existing image target. This
handoff records original targets already held/read; it does not create a new
TextureRect, choose a representative reward or activate a different mission.
No new test, game run, render, audit or CI was performed.

## Existing original reward-slot chain

| Original member | SHA256 | Authored target |
| --- | --- | --- |
| `UI/Quest/Quest_Tab_Main.csb` | `99d98120e12f9c3e28f783fe66b6d99bb396656e617dc1d03826033c6f15674a` | Project3380 references Quest_Slot_Set |
| `UI/Quest/Quest_Slot_Set.csb` | `9a9a3f1a9b9100b86592db67da9024798d6a6780ec9544c711d40848689f3ab1` | Projects1200/900/660/420/136 reference Common_Slot |
| `UI/CommonUi/Common_Slot.csb` | `b0153e2324de4789e3a5f1d09030f370ed109583e893247656bee5affa3520d6` | Original Sprite15012, Sp_IconSample |

Original slot positions stay inside these CSBs; the host must not invent slot
pitch or reorder them from this table. Common_Slot15012's exact authored anchor
frame and native scene-consumption API are in
[the native icon scene ABI](ORIGINAL_UI_NATIVE_ICON_SCENE_ABI.md).
These are candidate original quest-browser targets, not proof that the current
main quest Labels already correspond to this component/row.

MainScene80c174a87caf5cfbf910336b64616334ac560ed477f7a663aec58ada70d4285f
contains actual Project18200 -> UI/Main/Hud_PartyQuest_Menu.csb,
Project17348 -> UI/Mission/Mission_Slot.csb and
Project13676 -> UI/Main/Hud_Mission_Mimic_RewardBoard.csb. They have party/event
roles and are not silently treated as the current general Quest. The held
HUDScene969fbd4afc2897f7f6f19dc19abafc5960fb982abb4d24c7aa5c0576e8e16b09
has no direct Quest/Mission Project reference in the already-read metadata.

## Narrow caller inputs still missing

The integration/quest owner must supply the actual source Quest identity and
its selected row/content-role relationship to this original browser, together
with the unchanged source_rewards records. UI needs an explicit assignment of
those exact RewardID/alternative entries to original slot instances
1200/900/660/420/136. A numeric ID equality, array order, shared name or first
reward is not that relationship. Neither reward ownership/effects nor reward
selection is implemented by this UI handoff.

Once that role/assignment exists, UI267 owns loading the declared original
component at its original parent, accessing the specified child slot player
and giving its Common_Slot15012 contract to image270. Image270 owns the
canonical reward ItemClass/Icon/Asset result and selected original pixels/CSB;
integration269 retains completion/claim/receipt/save. Existing source renderer
and native icon provider are reused, with no duplicate reward-image decoder.
No current quest caller is redirected or counted connected by this document.

The additional narrow read of those MainScene children/current open_quests
caller failed before process creation with `exec-server transport disconnected`.
No new child hash/node claims were made from that failed action. Existing source
files and code were preserved; no download, UI construction or execution ran.
