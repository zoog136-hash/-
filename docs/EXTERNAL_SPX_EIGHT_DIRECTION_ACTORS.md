# TWILIGHT external SPX actor animation: verified eight-direction opt-in

## Source evidence and exact coverage

The user-supplied `a2(1).zip/appcenter/connector/patch/patch_1.zip` contains 1,700 `.spx` sequence files across 44 base sprite IDs. **It does not contain 1,700 different monsters.** Eight base sprite IDs contain 208 sequences each, with additional graphics/effect layers. This branch implements two inspected humanoid actors (`21624`, `21653`) rather than misidentifying effects as independent monster animations.

Using the repository's bounded `tools/l1j/spx_decode.py`, the optional pack decodes **488 PNG frames total**:
- `21624`: 232 frames, 32 action/direction sequences
- `21653`: 256 frames, 32 action/direction sequences

Both are mapped into `idle_0..7`, `walk_0..7`, `attack_0..7`, and `hit_0..7` SpriteFrames animations. The source contains different action ordering for each reviewed actor. Source direction order is N,NW,W,SW,S,SE,E,NE; conversion to TWILIGHT's E,SE,S,SW,W,NW,N,NE is **source = (6 - facing) mod 8**. The first visual preview exposed an inverted north/south mapping, now corrected before delivery. Hit and attack semantics derive from inspected frame progression, not from a filename alone. **This is an appearance option, not automatic class identification.**

## Use on an offline PC

1. Extract `twilight_external_spx_actor_pack.zip` at the **Godot project root**. The archive contains `assets/external_spx/actors/21624/SpriteFrames.tres`, `.../21653/SpriteFrames.tres`, respective PNGs, and a manifest.
2. Open the project in Godot so the PNGs are imported.
3. In TWILIGHT **설정 → 캐릭터 8방향 애니메이션**, choose `21624` or `21653`. If the art pack is absent or incomplete, those options are disabled and the existing character is retained.
4. Return to **기본 TWILIGHT 캐릭터** whenever desired.

The selection is held only in existing `user://twilight_ui_settings.cfg` as a visual preference. It does not alter the game save schema. It does not replace transformation/doll graphics or monster AI, player attacks, hit markers, statistics, inventory, collision, map coordinates or paths. Existing original four-class art remains the zero-asset fallback. Only the display part of the player changes.

## Reproduce locally

```sh
python -m pip install Pillow numpy
python tools/l1j/build_external_spx_actor_pack.py --source '/path/to/a2(1).zip' --output '/path/to/twilight_external_spx_actor_pack.zip'
```

CI runs `tools/l1j/make_synthetic_spx_fixture.py` to generate 128 tiny replacement PNGs covering the same 64 named animations, then runs Godot on the real `scenes/Player.tscn` against the synthetic assets. No original art, source binaries, user-provided SQL account data or private assets are committed publicly.

## Remaining gaps

- The other six 208-sequence sprite families include effects/shadow/overlay layers. They are **not yet safely composed into full in-game playable art**.
- Source pose alignment is normalized to a consistent height per actor, not exact individual-origin bone alignment.
- The A3 older monster/NPC identifiers do not reliably identify the newer 216xx SPX actor. Automatic bulk substitution is intentionally disabled.
- Source art has third-party origin; permission to redistribute or use commercially must be confirmed.
- CI verifies synthetic resources and runtime state selection, not hands-on native Android hardware performance.
