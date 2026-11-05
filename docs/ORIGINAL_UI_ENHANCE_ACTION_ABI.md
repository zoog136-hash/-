# Original enhancement-start control

The existing target forge now consumes the original enhancement-start button.
This is one partial control, not a completed Enchant_All screen. Existing
selection, target details, probabilities, costs and confirmation stay available
in their current owner. No new form, image, enhancement rule or save operation
is created. No tests, execution, rendering or CI were run.

## Real caller and fresh selection

After existing `hud.open_enhancement(scroll,candidates)` configures or refreshes
its target forge, it calls `original_main_ui_controller.bind_enhance_action`.
The owner must be visible, in `mode=="target"`, with an actual current
`values[selected_index].target_id` string, nonempty `scroll_name` and the same
existing `forge.action` control. Source selection changes reuse that current
owner; no item, source row or first candidate is selected by this adapter.

The source button fresh-checks the current owner, selected physical reference,
scroll and actual disabled state, then calls **only `forge._execute()`**.
That existing function opens the existing one-shot confirmation and sends
`hud.enhancement_requested(scroll,target)` after acceptance. This adapter does
not quote, calculate chance/cost/count, debit, roll, save or claim an outcome.
Scroll selection, blessing, automatic enhancement and smelting are separate.

## Exact original geometry and states

| Original member | SHA256 | Scope |
| --- | --- | --- |
| `UI/EnchantScene.csb` | `1b44bd8b15833b44a902b0033c47969cf237ea18bc4c9f210af3505738420326` | Project724 at[603,343.50750732421875], alpha255 |
| `UI/FloatingUi/Enchant_All.csb` | `5a22899447b7b750c01e500beba49d80d081d65669bfc77c91309fe58946face` |15656,16276,16328,15708,15760|

The retained hierarchy is root2100→Nd_Enchant_Btn11336→Nd_Enchant14536→
Btn_Enchant15656. Both ancestors are default-visible. Normal16276 / label16328
and Disabled15708 / label15760 retain original `강 화 시 작` literals, fonts
and pixels. Their visibility follows the existing action's disabled state;
refresh preserves a pressed texture while that state remains enabled.

The same source renderer mounts the original parent/project coordinates. Its
wrapper is hosted above the existing workspace, below existing companion,
detail and confirmation windows; original node transforms and source z fields
are unchanged. Android uses the actual original hit Control and existing
source-button router before the workspace consumes that point. Existing modal,
gesture and enhancement-result guards retain precedence.

Only after successful source construction with the original input, current
source visibility and nonzero display alpha does the adapter hide the owner's
old action control. Failure, owner hiding, closing or controller replacement
restores the captured visibility. These runtime checks are not a pixel or
gameplay verification claim. No opening animation or hidden mode is forced.

## Remaining enhancement source inputs

This scope does not assign the two common slots145044/144788 to target/scroll,
fill generic paragraph fields, interpret BlessedCost or show a probability
table in Enchant_Text_Set. The source single/mode selection and broader data
roles remain unestablished.

The held start FX `UI/Effect/Effect_Source/Fx_Enchant_Start.csb`
(`aea348d2ea1e9225d71e20ab3745e19c3c58109d4aa740bb61f878dfd292450f`)
has generic5–115 and elemental clips, but parent Project7116/actionTag481505410
contains no serialized start/repeat/stop instruction. It is not played on
confirmation entry or treated as success. Current `success/maintain/decrease/
destroy` outcomes also lack an established source-result clip relation. No
repeat/ending policy or new animation is created to fill that gap. Sound stays
excluded.

## Single combined v16 private input

- Drive ID: `1aENTbi1Se0m7cy3rnmFCgI6jhmQdKYOb`.
- Filename: `TWILIGHT_current523_main_game_original_UI_combined_v16_20261105.zip`.
- ZIP bytes: **13,453,862**.
- ZIP SHA256: `19e2accc9dc1f60551981c4c1a00adc226ea7d65cdf3f5be716a761a3544cdd5`.
- Manifest pin: `8fbd1e8fc17ee7a3f4b723d83a009cdf74f47d2ea0e4228d876c78033105f18a`.
- Relative destination: `source-ui/current523-main-game-original-ui-v16`.
- Root: `original_ui.json`, `receipt.json`, `originals/UI/...`.
- 55 raw original files/35 scene trees/34 partial scopes; producer static
  blockers0. These counts are not completed roots or actual game use.

The existing one-pack CLI/env selection is unchanged, and no earlier pack is
required as an installed base. v16 retains v15 safety text, v14 typed NPC
portrait receiver/inventory name header and prior combined scopes. The private
upload succeeded with matching size and owner-user metadata. Consumer install,
button operation and rendering remain unconfirmed. All prior packs, configs and
saves are preserved; whole560 and95% completion are not claimed.
