# Original system-message caller

The existing main-game `hud.show_message(text)` now sends its actual owner text
to a held original system-message node. This adds no text, image, gameplay rule,
timer or queue. No new tests, execution, rendering or CI were run.

## Source, missing routing and explicit estimate

Original `UI/SystemMessageScene.csb`, SHA
`26fa5e9e1ef875f3e3aa8fbd68a77641a8c69a198a765f4d56e182d427128759`,
declares two actual Project targets:

| Priority | Child member / SHA256 | Project / original position |
| --- | --- | --- |
|1|`UI/SystemMessage/MessBoxHUDTopLayout.csb` / `a10604343f1c0c6dbb01eb68be3c9a7c44c2abcf8cbb9883656a515153c427a3`|4768 /[600,601]|
|2|`UI/SystemMessage/MessBoxHUDBotLayout.csb` / `707a598e106c5107d631295b30fb90f164a411919ad0ed2498a0df7d747838d0`|5048 /[600,140]|

Each child is original root76→Text124 `Text_Line`, visible1/alpha255. The
original literals explicitly name priorities1 and2. Their source does not
assign this game's existing `show_message` API to either priority. Targeted
official LineageM site searches for system-message priority did not establish
that routing either; no unrelated result is treated as proof.

Under the user's source→search→explicit numeric estimate policy,
`renewal_hud.LOCAL_SYSTEM_MESSAGE_PRIORITY_ESTIMATE=2` connects local feedback
to priority2. This is a **TWILIGHT numeric connection estimate**, not an
original-client confirmed rule. Code status and private selection metadata
record `kind:TWILIGHT_ESTIMATE`, value2 and `original_rule_confirmed:false`.
No original coordinate or image was estimated.

`hud.show_source_system_message(text, explicit_priority)` accepts only1/2 for
an explicit caller. The bindings have no default and never choose a first
target. Priority1 is available through this API; no current priority1 game-use
claim is made.

## Actual owner lifetime

The same base `show_message` updates `hud.message_label.text` and its existing
2.6-second timer. Base `_process` still clears the actual label on expiry.
The original controller observes that string and updates Text124; it does not
decrement another timer or reproduce formatting. Same-text messages keep the
renderer while the real owner resets its timer.

Original parent geometry, colors, font and text extent are unchanged. Source
`Ani_Off`5–25 is retained but not played without its original timing policy.
No opening/fade animation, queue or preemption rule is invented. Missing scope
or an unsupported string keeps the existing label visible and hides stale
original text. Label availability is preserved across replacement and release.

## Combined private v12 input

This one pack retains delivered v11/v10/v8 scopes; no base installation is
required. Consumer installation and game execution remain unconfirmed.

- Drive ID: `1xSoJs_ulHBQdc3FuY0auP5x2ib_1t3IZ`.
- Filename: `TWILIGHT_current523_main_game_original_UI_combined_v12_20261105.zip`.
- ZIP size: **13,313,500 bytes**.
- ZIP SHA256: `5b95cd9d278141769b387aabbce5f4280b3eccdbff72c7e588a9ff8a554074a3`.
- Manifest pin: `55a0f9100c726c587fa17b8e99cb044744fd7c10f66434858bfa5e3180b214a0`.
- Relative destination: `source-ui/current523-main-game-original-ui-v12`.
- Root: `original_ui.json`, `receipt.json`, `originals/UI/...`.
- 51 raw original files/31 scene trees/30 partial scopes; producer static
  blockers0. These are packaging units, not completed UI roots.

The existing `--source-ui=<root>` / `--source-ui-sha256=<manifest pin>` and
`TWILIGHT_SOURCE_UI` / `TWILIGHT_SOURCE_UI_SHA256` contract is unchanged. Earlier
packs, configs and saves are preserved. No image/UI is generated or publicly
uploaded. Whole560 and game-use percentages do not advance from packaging or
unexecuted connection code.
Private upload succeeded; returned metadata matches13,313,500 bytes and reports
owner-user-only permissions. This does not establish consumer installation.
