# Aden regional art, 2026-10-16

Four independently generated PNG atlases extend the approved Giran visual style.
`structures.png` and `nature.png` each contain 16 sprites. `terrain.png` contains
16 material swatches; `landmarks.png` adds four complete building/shrine sprites.
The renderer keeps the approved Giran atlas for materials
0–3 and uses this new atlas for 4–15. `sprites.json` indexes actual connected
sprites because generated sheets are not perfectly regular grids. The integer
`*_ids.png` lookups isolate those sprites in the shader; original generated PNG
bytes are preserved. This prevents cropped roots and neighboring sprite bleed.

These are TWILIGHT interpretations, not recovered Lineage/Lineage M pixels.
Public game screenshots and map images are research references, never imported
as game art. Redistribution rights for the absent original TIL archive have not
been established. The existing allowed Aden private pack is unchanged.

Structure slots 16–31: coastal cottage, Kent house, Heine house, Oren lodge,
Aden townhouse, rustic hut, desert house, woodland pavilion, gray keep, coastal
keep, chapel, market, gate, NE wall, SE wall, rocky dungeon entrance.
Nature slots 32–47: oak, birch, swamp tree, snow pine, ancient tree, palm,
dead tree, shrub, two cliff directions, snow rocks, volcanic rocks, riverbank,
sandy bank, reeds, fence.
Landmark slots 48–51: independent mage tower, desert keep, royal palace, shrine.
The tower is a visual interpretation at an S32 target75 record. The two placed
castle landmarks use A3 control-tower coordinates, not identified building feet.
The fourth shrine is unused and is not counted as implemented scenery.

Artwork availability does not prove placement. The build manifest lists the
actually placed slots/kinds; unused sprites are not counted as implemented
structures. Source object identities remain interpretations because A3 lacks
TIL images. Reference dates and PC/M differences are recorded in the expansion
report beside actual Godot captures.
