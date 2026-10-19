# TWILIGHT authored card presentation assets

`authored_atlas.webp` and `authored_background.webp` were generated specifically
for this TWILIGHT study with OpenAI ImageGen. The atlas contains original fantasy
figures, two dolls, a spear and a metal card back. These files are not original
NC/Lineage M sprites. Prompts and SHA-256 values are recorded in
`docs/card-reveal-20261019/`.

`impact.wav` and `upgrade.wav` were synthesized with deterministic noise,
oscillators and envelopes in the sample's `build.py`; no reference soundtrack
or source-game sound was sampled. Smoke/light textures and branched lightning
are generated in `card_reveal_effects.gd` at runtime.

The actual acquisition presentation resolves already-awarded stable IDs against
the existing game's catalog and uses that record's existing `image_path`.
The grade comparison uses the authored atlas for a controlled visual comparison.
No new third-party source-game textures are included by this change.
