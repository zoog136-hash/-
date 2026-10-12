# Aden riverbank and shallows — second PR84 resume unit

The actual north-bridge frame showed a narrow, sharp bank immediately touching
flat opaque water. The new Aden-only shader keeps the existing terrain texture
visible below shallow water, darkens the wet edge and transitions into deep green
water. A faint animated lapping edge and softer outer shoulder tie water to land.
The existing authored atlas is reused; no new third-party art is packaged.

All three existing 66-vertex river polygons keep their exact vertices. Explicit
triangle strips interpolate depth between paired bank samples without crossing
river bends. Each section remains one Polygon2D; no per-frame shoreline geometry
or collision bodies are generated. Other maps retain their previous water shader.

Actual Godot 4.7.2 Linux llvmpipe OpenGL verification:

- 25 Main-scene checks PASS after this change: actual click movement, river-blocked
  manual movement, routes, canopy fade/recovery, NPC shop, save/load and portals.
- 23 additional checks PASS: all three original outlines, equal polygon/triangle
  areas, loaded depth shader, original bridge clearance and blocked adjacent water.
- Three unedited runtime views are tracked: north bridge (6180,3000), south bridge
  (5712,5712), and curved bank (5520,4368). The north-bridge before image is reused
  from `../aden-polish-v3/after/03-bridge.png`, at the identical camera position.
- Source map, navigation, spawn, portals, world gameplay and both existing atlases
  remain byte-for-byte identical to `28b9978`; hashes are in validation-summary.json.
- Required 723 resource sheets pass integrity verification.

The small ripple animation can differ in phase between screenshots. The old
25-map suite was reused, not rerun. No Windows/Android device execution, exact
original-art restoration, Lineage M parity or main merge is claimed.

Remaining visual work: reduce the regular courtyard outline and mirrored paving
pattern, improve building detail/scale, and refine non-Aden regions independently.
