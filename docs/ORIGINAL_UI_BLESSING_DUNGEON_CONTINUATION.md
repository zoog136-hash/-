# Main game blessing and dungeon input continuation

These are additional partial original connections after PR280 `5340c462db7e000e1d32bcb9024636cb479d2b9d`, based on main `5db920332f9298b4fc1f70713dde11740c91a7d2`. No new image, layout, original animation policy, sound or gameplay service is implemented. No tests, compile, game, render or CI were run; the changes are unverified and are not completed560-root/game-use counts.

## Actual blessing owner and original display

The existing world publishes AinhasadService.snapshot to HUD.set_ain_state. `source_main_blessing_bindings.gd` reads that same current `v20_ain_state.blessing` integer without a preview/default200. It mounts through actual HUDScene Project1540 → Hud_PayLayout Project184 → Hud_BlessPoint Project9056 → Hud_EinSlot Text792. Original Sp_Slot3496, font18 Font/font_B.ttf, position/anchor/color and parent transforms are preserved. The current owner's count updates after regeneration, consumption, charging or save restoration without a second UI service.

Original Hud_BlessPoint Button9336 calls the same HUD._toggle_ain_window used by the existing Ainhasad entry. It retains the actual owner's disabled state. Original tooltip title6656, captions6324/5992 and values4560/4232 display the owner's actual exp_rate/adena_rate using the existing integer-percent conversion. Tooltip visibility follows the existing Ainhasad detail panel's open/close state; no second toggle or dismissal policy is introduced. Missing actual rates hide that partial original tooltip; they do not display serialized700%/100% previews.

The existing detail owner and its recharge-item buttons, auto checkbox, reduction/regeneration/orb explanations remain available. The partial source readouts do not claim that whole detail screen has been replaced. The old main HUD leaf/count controls are hidden only after their original count/entry mounts and are restored on source failure, release or selection of a smaller pack. Stage icons0–4, caution, infinity, glow, slider and recharge-threshold semantics remain unbound. No numeric threshold chooses an original icon. This scope shows the actual count and authored frame without inventing that missing icon relationship. Sound metadata is retained under the existing sound exclusion.

| Original | SHA256 | Connected nodes |
| --- | --- | --- |
| UI/Main/Hud_PayLayout.csb | 74289dc69d7c3a53d9f48206f16d8ff0b9b30ce13b8b69153165663d844f61bf | Project184 |
| UI/Main/Hud_BlessPoint.csb | 97c33507483cdb6517a9d6b671ffad92b757a62e79c3269b590316722dafd2a1 | Button9336, Project9056, tooltip8312/7924/6656/6324/5992/4560/4232 |
| UI/Main/Hud_EinSlot.csb | 8b8e324d39da49f2ff9d2fc23dfd3e7953eccd2dea8b2caec57b18b0be0df168 | Sp_Slot3496, Text792 |

The controller exposes `source_blessing_status()` for this partial connection and preserves original control visibility across replacement controllers. v23 stays usable without these optional source scopes. v25 supplies count/entry; v26 adds the source rate readouts; v27 retains both and adds dungeon close below. v24 is an unshipped local construction intermediate, not an installer input or delivery claim.

## Dungeon original outside-close input

`source_main_dungeon_controls.gd` connects only the actual source MissionScene Project2384 → Mission_Dungeon_All Button5540. The parent SHA is `dd8ecf3272d9ef3484bdd7eea2336abc54923553d3019c6888706872a5b76142`; child SHA is `d95b96227ea95d38e95b4d351977f6b3794cc237f4ef194457959e8626ba2be3`. Parent position600/337.5 and original alpha0, and the authored1600x675 close rectangle, anchor.5/.5, alpha0, original Default button textures are retained. Its invisible editor title is omitted only by the existing proven-alpha0 renderer behavior; no visible close button is fabricated.

The control exists only while the real scripts/dungeons/source_dungeon_view.gd owner is mounted and visible in the actual `source_dungeons` workspace. Release rechecks that same owner before invoking HUD._close_workspace. It does not invoke leave/stop/claim/cancel services or discard a pending save. The original full-screen outside-close control is deliberately absent from the workspace action override list: current workspace rows, entry controls and modal inputs retain their existing precedence. Outside those controls, the existing native button router supplies Android touch and the original Control supplies mouse input. PointerTransfer yields inside this actual source rectangle. No runtime/device success is claimed.

Other original dungeon panels, category/mode selection, entrance/popup target roles and source row/reward assignments remain independent missing contracts. This close input does not repurpose the existing ItemList into an entrance image or infer Party/Competition/Special identity joins.

## Private combined input

Latest v27 file: `TWILIGHT_current523_main_game_original_UI_combined_v27_20261105.zip`,13,531,760B, ZIP SHA256 `04c285a11833ba49057aeb19cd6f617fe46e484776c177ab32f3469b02ecbaae`, manifest pin `dc2baf2fddd082c28fed5578a8dad276c56003cc637f09c6c5388b7139e27b45`. Relative directory `source-ui/current523-main-game-original-ui-v27`. Structure original_ui.json/receipt.json/originals/UI and the single TWILIGHT_SOURCE_UI/TWILIGHT_SOURCE_UI_SHA256 selector remain unchanged. No overlay whitelist or installer-list/config write is added.64 original files/41 scene trees/40 partial scopes are packaging units, not completed screens or observed game consumption. Existing v23, later candidates, originals and saves are preserved.

Official private v27 Drive ID: `1exd0vv8MxMrLkXCXvLCNn-7nFqF7IEvU`. Upload succeeded; metadata readback reports13,531,760B and only the owner's user permission. Consumer installation/operation is unconfirmed. Earlier delivered v25 ID `1PQHC2bPuamogbjv0D_wKltruOPOO0HSr` and v26 ID `1xbmjUMoLxD-VotZXibUEBZkq--dxbSog` remain preserved; v27 is their combined optional successor, not an automatic installed selection change.

The original MapScene/Map_All/Map_Tab_Area/Map_List_Button scopes remain retained. The separate relation-file pin and W_aden.png pixels are still separate contracts. CSB-root registration, quest reward target assignment, authoritative dialogue NPC ID and36 dependency gaps are not resolved by these new connections.
