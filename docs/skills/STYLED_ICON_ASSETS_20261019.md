# TWILIGHT skill icon visual integration · 2026-10-19

**Icon fidelity follow-up (2026-10-19):** 125 license-permitted vector icons revised to use skill-theme-specific palettes (fire, electric, ice, earth, heal, blood, shadow, holy, arcane, nature, wind, weapon) and advancement pips. They remain independent alternative designs, NOT traced/pixel-matched NCSOFT originals.\n\n**Active game icon slot coverage:** 125/125 assigned to real SVG images. Each SVG is built from a CC-BY Game-icons pictogram and TWILIGHT-styled frame. They are **fantasy alternate images, not original Lineage M icon copies**. The per-ID 125-entry ledger is `data/skills/styled_icon_provenance.json` (87 source glyphs).

**Actual publisher icon acquisition:** 0/125. The official [Japanese Lineage M fansite kit](https://lineagem-jp.com/treasure/sitekit) references representative skill icons but the ZIP could not be fetched in this environment, and stated fansite use does not verify permission to redistribute in a separate game. Do not claim publisher-original art was installed.

## In-game path

`scripts/skills/skill_catalog.gd` resolves by *exact* skill ID: (1) private authorized PNG at `res://assets/skills/private_icons/<id>.png`, (2) CC-BY fallback art `res://assets/skills/styled_icons/<id>.svg`, (3) unchanged original generated SVG fallback at `res://assets/skills/icons/<id>.svg`. The skill book and both existing quickslot HUDs read `record.icon`; no combat or persisted skill fields changed.

## Checks

- 125 skill rows aligned to 125 ordered `data/skills/vfx.json` IDs with 125/125 effect motif matches before the conversion.
- 87/87 distinct glyph SVGs actually read from `game-icons/icons` public repository.
- 125 named SVG assets generated and committed on the PR129 branch.
- Commands for verification (run in a full Godot clone):
  - `python tools/skills/verify_styled_skill_icons.py`
  - `godot --headless --path . --script res://tests/skill_private_icon_binding_test.gd`
  - `godot --headless --path . --script res://tests/skill_icon_asset_integrity_test.gd`
- Local/Godot/Android runtime checks in this tool session: **NOT RUN** (GitHub connector has no executable project checkout).
- PR #122 animation, #127 SPX, and main untouched. Public PR remains Draft; no merge or full CI requested.
