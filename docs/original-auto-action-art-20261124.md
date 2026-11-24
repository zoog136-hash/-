# Original artwork on actual auto-hunting entry and status
The normal full-menu 자동사냥 tile and the auto status banner previously used
TWILIGHT artwork. Both now mount the **same live texture and material** as
the authored normal AUTO Sprite (Hud_AttackPad.csb offset 29664,
Hud_Btn_Pad_Auto.png from Atlas_Hud.plist). The transparent touch button and
animation effect are not used as an icon. There is no new image, atlas
decode, hardware readback, or alternative artwork. When the original
scope is unavailable, the existing two captions and button remain.

Actual Main with distributed UI44 manifest
5263d92594e8f44248ad799d6b56ba7816fc5f30bdc4ead0bafaf0bf2dd0b94c:
9/9 (identical Texture2D/material, real tile opens status view, original
AUTO icon present on both, existing toggle changes the world player state).
Without original source: 7/7, usable text/status/action, no substitute.
This is the authored HUD icon used in an existing TWILIGHT menu and banner,
not a claim that the entire auto-settings screen matches the client. Phone
visual comparison remains untested.
