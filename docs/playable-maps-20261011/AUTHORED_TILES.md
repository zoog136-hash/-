# First-map authored terrain v1

The user authorized creating replacement tiles after the original tile bytes
could not be found. This is newly generated TWILIGHT art, not Lineage original
art and not ORIGINAL_RESTORED. Only `l1_4` uses it. Remaining-map production is
still gated on explicit user approval of actual Godot screenshots.

## Runtime implementation

Two generated 1254×1254 atlases are shipped in
`assets/maps/authored_mainland_v1/`: four ground materials and four transparent
obstacle sprites. `generation.json` contains the complete prompts and built-in
image generation provenance; `asset_manifest.json` contains exact SHA-256,
sizes, and enabled map IDs. All quadrants are selected in Godot; source images
are unmodified. They are public project assets authored for this request.

`source_renderer.gd` enables this style only for `l1_4`. Shared atlas textures
and one shader serve the existing maximum of nine streamed chunks. Each chunk
builds a textured mesh in the existing 48×24 source projection. UV coordinates
are world-continuous across chunk edges; mirrored repeats prevent atlas bleed.
The S32 tile/index pair affects subtle surface variation. It does not assign
unverified semantic meanings to original tile IDs.

Material design: navigable safe-zone cells use limestone pavement; ordinary
navigable cells use grass; combat-zone cells use soil; non-navigable cells use
dark rock. These are authored visual choices based on known navigation flags.
Navigation does not distinguish water, buildings, roofs or trees. Such features
have not been reconstructed or inferred. Small rocks/brambles/ruined wall
segments decorate source-blocked boundary cells, with a maximum of 96 per chunk.
They add no new colliders and do not change navigation masks or source doors.

The old diagnostic dot field is suppressed in this style. Original S32 object
art/layers remain unresolved; newly drawn props are not presented as those
original objects. The original tile mapping JSON remains untouched and empty
of real images. The minimap and map menu explicitly label the authored style.

## Validation and approval

The existing `source_first_map_test.gd` runs the actual Main scene with the
private verified A3 pack. Added checks prove that textured geometry and S32
variation are mounted, props are on source-blocked cells, and the destination
map does not receive this style. Existing click movement, collision, A*, NPC,
boss, AUTO, portal, minimap, map selector, save/reconnect and missing-pack save
protection checks remain.

First visual run: 35 checks passed on Godot 4.7.2 Linux software OpenGL. A final
run also checked the unexpanded destination map: **36/36 PASS**, zero failures.
The exact log is `evidence/authored-first-map-gl.log`; the result and image hashes
are in `evidence/authored-first-map-result.json`. Two actual screenshots are in
`authored-screenshots/`. These are not Windows
device results. Other source maps and the old 25 TWILIGHT maps are not restyled.

Resume from the current PR83 branch head. To reproduce, follow INSTALL.md for
the private A3 data pack, open `l1_4` through the map menu, or run
`tests/source_first_map_test.gd` using `tools/run_visual_capture.py`. Keep the
user's save directory isolated for automated tests. Await screenshot OK before
extending this art to any further map.
