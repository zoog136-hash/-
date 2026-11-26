# Original equipment enhancement feedback after a committed roll

The stock call chain is Forge.request_target → HUD enhancement_requested → World._attempt_enhancement → _save_game → HUD.show_enhancement_result. The official stock start button remains one touch; this change does not add a confirmation dialog, alter rates, choose/consume an item, or change save ownership.

Two native presentation faults: the window used to claim a committed result and block touches even if neither original clip mounted, suppressing the existing HUD fallback; then the immediate post-save candidate refresh restaged the entire window, causing successfully started native feedback to play again on another tree (which could show a new physical target after destruction).

Now the exact original projections, both clip starts and the outcome text binding must succeed before native handling is acknowledged. A partially started result is stopped and hidden, and the unchanged HUD uses its existing fallback. While an accepted original result plays, the window retains its original physical target/slot and queues the committed candidate rows. Once feedback finishes or a skip is accepted, those rows are applied once, without replay. A stale completion token cannot clear another result. The original fail clip presents different maintained, lowered and destroyed text.

## Original source evidence

Official `pack-63fb1355` UI add-on ZIP SHA-256 `3b972a5c0d54a03a713407b7bbd3321f6ee2e0d27644426a78354799cc7b68b6`, ZIP CRC checked. Its original UI manifest SHA is `5263d92594e8f44248ad799d6b56ba7816fc5f30bdc4ead0bafaf0bf2dd0b94c`. The referenced source members are:

- `UI/Effect/Effect_Source/Fx_Enchant_Start.csb`, SHA-256 `aea348d2ea1e9225d71e20ab3745e19c3c58109d4aa740bb61f878dfd292450f`, original generic clip frames 5–115 at the existing original player timeline; Enchant_All project offset 7116.
- `UI/FloatingUi/Enchant_Popup_Message.csb`, SHA-256 `fbc0450f0d629c743f8485b7afd6e45a4c1fb13efcff8913b6fa95f311c78b91`, original `Success` 0–80 and `Fail` 100–165; Enchant_All offset 6848. Maintained/decreased/destroyed Korean strings are presentation of the existing distinct result states, not new original source strings.

No artwork, ZIP or set of pixels is included in this commit. No change to launch initialisation or Android installation.

Verification: actual Main with the released UI add-on passed 49/49 checks. The stock start action drove the usual World transaction; exact +1 / scroll debit was present in the save before the original start + success clips played on an unchanged scene. No second debit/RNG or replay occurred; refreshed rows appeared after finishing. Partial-project failure, failure clip / loss text, and other result text distinctions are exercised with renderer doubles, not a real PC or phone frame capture. The fixture does not require unrelated original maps and actors. Set TWILIGHT_ENCHANT_WINDOW_TEST_PACK to the verified extracted add-on when reproducing with an isolated XDG profile.
