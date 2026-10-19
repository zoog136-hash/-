**2026-10-19 follow-up:** all 125 active skill IDs now have licensed 64×64 alternate fallback SVG images, with source credits, as detailed in `docs/skills/STYLED_ICON_ASSETS_20261019.md`. No original NCSOFT skill images are installed; private exact-ID PNGs still take priority over the styled fallback.

# TWILIGHT private skill icon binding — 2026-10-19

The live catalog contains **125 skills** across 13 job classes plus common. They currently point to 125 locally generated SVG icons. This branch adds an exact-ID private PNG override only; every absent icon keeps its current SVG.

## Source and rights

The official Japanese Lineage M site offers a representative original skill icon kit for **fansite use**, not a general game redistribution grant: https://lineagem-jp.com/treasure/sitekit . Its specific permission notice is at https://terms.ncsoft.jp/lm/lm-fansitekit/ . Slight graphic changes do not resolve the rights issue. Do not upload NC original or adapted icon bitmaps to a public GitHub repository without authorization.

## Opt-in local installation

Source folder/ZIP: PNG, JPG, WebP icons. Names may be the exact immutable `lm_<16hex>` ID, the Korean skill name or `직업_스킬명`. When names differ, supply `--mapping /private/map.json` containing JSON such as `{"lm_0f78dd70d9994d34":"folder/icon.png"}`.

```bash
python tools/skills/install_private_skill_icons.py --source /private/skills.zip --mapping /private/map.json --dry-run
python tools/skills/install_private_skill_icons.py --source /private/skills.zip --mapping /private/map.json --rights-confirmed
godot --headless --path . --script res://tests/skill_private_icon_binding_test.gd
```

The installer performs a very small 1.5% saturation adjustment, 64px aspect-preserving normalization and faint one-pixel border. It saves only under gitignored `assets/skills/private_icons/`. It never downloads original art. The resolver prefers `<skill_id>.png` over the existing generated SVG and is used through `record.icon` by both skill lists and gameplay quickslots. No skill ID, class/learn restriction, visual effect/SPX, combat data, sound, save schema, or animation is changed.

**Status:** Repository binding code prepared; authorized original icon files obtained 0/125, installed 0/125, individual icon recognition and Android in-game rendering NOT_RUN. No claim of full 125/125 installation. PR #122 and #127 untouched, no merge.
