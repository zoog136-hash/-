# Aden palace plaza / east garden modular pilot — 2026-10-24

This delivers newly generated, position-registered **review art for one 3072×2048 region**, not a completed Aden rebuild or production replacement. Earlier generic town art remains a style reference only. PR155 Faith, Escaros, lightning and CI recovery changes are preserved.

## Deliverables and coordinates

- [Full new PNG](../../assets/maps/aden_modular_pilot/compiled/palace_gardens_3072x2048.png)
- [Before, actual Main](evidence/before-1280.png) / [After, actual Main](evidence/after-1280.png)
- [East garden view](evidence/garden-1280.png) / [854×480 view](evidence/after-854.png)
- Layout and generated source provenance: [SOURCES](../../assets/maps/aden_modular_pilot/SOURCES.md).

World bounds (69600,16800,3072,2048); reference PNG origin (11600,2800), scale 6. Current full Aden world: 72240×45708 = 3,301,945,920 square world units. Pilot: 6,291,456 (0.1905%). Remaining unauthored visual area: 3,295,654,464. Production replacement coverage is **0%**: preview is opt-in. The garden screenshot moves the camera, not the character into blocked garden terrain.

Logical camera viewport is 1280×720 at zoom 1. Old PNG provides 1 pixel per 6 world units; new compiled art provides 1 per world unit. Generated sprites/materials are downsampled, never enlarged old art. Seven object types and four material types are reused in a spatial layout, with 41 placements. This replaces the rejected thousands-of-independent-images plan. A full-world district count cannot be inferred from this one courtyard: coast, cliffs, forest and towns still require separate layout authoring and art.

## Verification

Actual Main.tscn, Godot 4.7.2 Compatibility, Linux llvmpipe; no actual Android device. Isolated test save. [51 checks passed](evidence/result.json): all 38 portal approach points, five existing plaza routes, real player walking, unchanged navigation/spawn candidates and portal coordinates, fountain foreground occlusion. Behind fountain 2584 actor-difference pixels vs 3347 in front. Fountain ground pivot equals the existing collider center. Additional palace bottom-contact scan: 75 samples, zero on existing walkable area ([script and result](evidence/contact.txt); reproducible script beside it). This does not prove all object footprints.

Lossless ground chunk and foreground-composite round trips pass. 24 ground chunks of 512×512; view culling observed 12 MiB peak resident ground texture bytes plus 5,399,568 bytes unique foreground RGBA. These are texture accounting, **not process RAM, FPS, or Android performance measurements**. The full PNG is an export, never loaded as a giant runtime texture by the preview. Actual capture harness: `tests/capture_aden_modular_pilot.gd` with `ADEN_MODULAR_OUTPUT` set and a real display. Production renderer and geometry are not edited.

## Remaining work / review findings

- This pilot retains broad palace/plaza/garden relationships and exact fountain anchor, but does not certify every wall, hedge and door footprint against the old PNG. No extra invisible colliders were added. Existing hidden-area navigation rules remain unchanged pending the user's answer.
- Chunk boundaries reconstruct without pixel loss; **external joins to the old surrounding map are not artistically resolved**. The camera can expose the pilot edge. Integrating this as production now would be premature.
- Paving and grass still show mirrored repetition; grass-to-stone edges need painted transitions. A reversed wall has mirrored baked lighting. Further art polish and a proper opposite-facing wall are required.
- Fountain occlusion verified; palace/hedge/gate occlusion and playable entrance alignment still need per-object review. Preserve current traversable routes while adjusting art.
- No full-world creation, Android-device result, or performance improvement is claimed. No main merge/deploy.
- Library upload remains blocked from the earlier attempt: `hosted apps tools/list request failed with HTTP status 401`; no Library file IDs exist. No alternate authentication route attempted. Repository assets and evidence are preserved for delivery through the authorized feature branch.

Next: review visual scale/style and remaining edge defects, correct the small asset set, align all contact footprints to verified routes, then connect this region through the normal production renderer and author adjacent districts using the same modules. Do not mass-produce new districts before this geometry/art fit is satisfactory.

Final integration: import and boot both passed (2/2) with writable workspace XDG configuration/cache. Initial import failure was unwritable default `/home/agent/.config` and `.cache`; both attempts preserved in evidence. No full CI rerun claimed. All PNGs are tracked and SHA256 matched; see evidence/tracked-assets.txt.
