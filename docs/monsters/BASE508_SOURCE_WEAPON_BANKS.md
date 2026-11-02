# Source weapon action selection: Halpas correction

The displayed missing weapon was not a shader/crop failure. Raw body28439 and
color bodies28514/28519/28524 show no held weapon in generic Breath3/group24.
The same original bodies contain the sword in Breath7/group80, axe in14/120,
large sword in53/248 and scythe in151/448. The previous compiler selected only
Walk0/Attack1/Breath3, and World did not pass equipment WeaponType to that native
renderer. The player's earlier weapon selector updated only the older SPX view.
No separate weapon image, invented rig, crop correction or new motion is needed.

The common selector now reads the current normalized equipment category, joins
its named source WeaponType enum and selects supplied source action banks. Raw
WeaponType/ListSprAction rows and hashes are retained publicly. Rifle is native34
and HandCannon54, despite differing ListSprAction animation labels; IDs are not
guessed from action names. Unknown local types and unsupplied banks have explicit
generic-source fallback status. Native card/option identity selection happens
first. Existing single-bank/unprepared actors keep their original frames.

The delivered compact pack includes four source weapon types1/2/7/84 across all
four Halpas bodies (16banks). Idle/walk/attack use original exact action IDs,
frames, offsets, timing, shadow and matching source clothes addresses. Base28439
uses its real28443 run alias/weapon override; colors have no source run alias,
so no run track is fabricated. Weapon equip refresh updates the actual native
Player view even when card and color option remain unchanged. Gameplay attack
clock, motion attack elapsed/sequence and strike signal remain separate.

Metadata inspection found398 of434 available source transformation actors declare
different weapon banks. This is not proof every bank's pixels are installed.
Only supplied, source-row/hash-validated banks activate; this release does not
claim all398 actors' weapon resources are integrated. Wider local compilation was
kept separate from the compact user delivery; no other actor is forced into a
Halpas bank or a fixed great-sword type.

Godot4.7.2 targeted checks:488 pass across all four bodies/four families/eight
stored directions, source primary action IDs, real Player weapon switching,
unchanged hit sequence/clock, correct color option, native run preservation and
Girtas/unrecognized-type fallback regression. Final managed ZIP installation also
loads Girtas, UI and existing event effects. No whole-CI rerun/Android approval.

Private v4 combined addon: TWILIGHT_base508_weapon_banks_addon_v4.zip,
38,163,585bytes, SHA256 f8868c408d7b556c3aa0f8dd7780cdf332ac62357889a28d4f4ff6dd39fc9079.
Library libfile_bf6505af67f081918436c119ffad8dcb v0. Select it with the current
offline installer and restart; preceding effects/awakening files are included.
Original pixel files are not committed to public Git.

Actual before/after: Library libfile_e29b1c0dc4288191883e65e5fbcc5c75 v0,
Halpas_무기선택_수정전후_기본과3색상.mp4,6s/180frames/1920x840/30FPS,
2,284,588bytes. Same front/source direction5, previous generic versus explicit
one-hand sword type1, both1x and2x. Current compatible source layers remain;
color-option sc/mu gaps and unverified exact composition are labelled on-screen.
This is deterministic engine-frame output, not real-time Main/Android footage.
