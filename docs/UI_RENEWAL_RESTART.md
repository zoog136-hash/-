# TWILIGHT UI renewal restart

Base: `11894be09077f9f3c14c2d3814aec422b8e7c2c0`. Dedicated branch:
`feature/twilight-ui-renewal-restart-20261009`. Main is never merged automatically.

## Recovery and protected scope

Existing UI PR #3 and `sol-ui-rework` (`dfb2f44`) are preserved. The 23 UI icons
decode normally and have distinct file and pixel hashes. Main's 2367 images
decode normally. Its four duplicate groups are outside UI and predate this work.
Prior uncommitted image SHA values remain unavailable: no recovery is claimed.
No new image generation is needed for the planned Theme/vector interface.
`ui-renewal-assets.json` records reused image SHA-256 values.

Only UI scripts/resources, the HUD scene/control layout, UI tests/tools, UI CI,
and evidence/documentation may change. Gameplay/animation/map/save files must
remain byte-identical to the base. All interaction uses the existing HUD signals.

## Reference and design decisions

Reviewed NC's official current guidebook/index and 2026 update pages on
2026-10-09. Public text extraction of the UI guide did not expose its embedded
screenshots; exact latest in-game dimensions are therefore not claimed.
The repository's existing `reference_ui.jpg` was visually inspected.

- https://lineagem.plaync.com/guidebook/view?title=메뉴+및+UI+소개
- https://lineagem.plaync.com/guidebook/list
- https://lineagem.plaync.com/conts/260610_update
- https://lineagem.plaync.com/conts/260225_update

TWILIGHT design: compact portrait/vitals in the upper left, target in the upper
middle, minimap/location in the upper right, quest beneath the map, quickslots
along the bottom, and attack/AUTO on the right. Keep the central world clear.
Black slate, layered bronze borders, restrained gold, Korean Noto Sans,
consistent rarity colors and focus/hover feedback. Panels use a shared title,
navigation, searchable content and a fixed detail/action column.
No NC logos or website image assets are imported.

## Gameplay capabilities and honest UI states

Main supports inventory by name/count, name-based enhancement, catalog apply,
existing skill/quickslot AUTO/SELF, actual shop buying and quest progress.
It does NOT expose individual equipment IDs, generic equipment unequip,
catalog ownership/unlock, skill-learning purchases, quest reward claiming,
or a new crafting/server system. Prepare/label unavailable actions instead of
inventing transactions or ownership. Future per-instance snapshots may be
displayed when supplied, without migrating or writing inventory data.

## Checkpoints

1. Analysis/resource manifest: complete (`0a7e7fe`).
2. Common Theme and workspace: complete (`052aa60`).
3. HUD: connected; real GL screenshots captured at all four sizes.
   Original viewport input test passes all 399 checks. Corrected shared-panel
   reparenting and integer `wght` font axis; GUI click surfaces are preserved.
4. Inventory/character: connected. Fresh-game inventory now reads the existing
   quickslot snapshot; no gameplay initialization or inventory writes added.
5. Skills/catalogs: searchable card lists connected to original signals. Item
   catalog no longer invokes the legacy free acquisition action; only owned
   items can be used/equipped. Native catalog touch scroll smoke test passes.
6. Remaining panels and integration: in progress.
7. Regression, real GL renders at 1280x720/1600x900/1920x1080/2560x1440,
   verification evidence and PR: pending.

Resume from the last successful branch commit; never regenerate existing art.
Current checkpoint: HUD, inventory, character, catalog cards, skill cards and
current-region map are wired; finish shop/forge/quest/settings, then add full
functional UI assertions and final screenshot checks. No new image art created.
Image processing batches are limited to five, with SHA-256 deduplication and
commit/tree verification. Screenshots are test evidence, not generated UI art.
