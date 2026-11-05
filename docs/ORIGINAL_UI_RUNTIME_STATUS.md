# Original UI connection status

This is a partial implementation, not delivery of all original UI. No authored
replacement UI, game rules, service mutations, save changes, or installed pack
changes are included. Image and animation work precedes sound.

The branch began at `918c8e84e6a5ecbe7a071b263751e10899c282a1`. The next
verified upstream integration base is `00b84cfe19c05e01d30208384bf7fbcc4ae6bbf2`
(PR266). Its eight changed files do not overlap this work. Remote publishing
and CI are intentionally not performed under the delegation restrictions.

## Implemented locally

- `tools/ui/read_source_csb.py` reads source CSB options, resource references,
  timelines and animation clips without projecting them into generic forms.
  Unknown fields are explicit blockers. Its schema follows the inspected
  Cocos 3.6 generated header, blob `7a553be9bb9a3c7b1296d494e4cbfd0fb4e1d4dd`,
  with the appended BlendFrame field verified against upstream commit
  `7a5282a301a13e467bdcc3466d3cd3883862aadf`. Newer text/button layouts are
  not substituted for the layouts in the supplied source bytes.
- `build_original_ui_pack.py` resolves exact child CSBs, frame names, atlas
  pages and other resource references from an explicitly verified private
  source index. Missing dependencies and malformed original PLISTs block
  activation. Outputs must remain outside the public checkout.
- `scripts/ui/original_ui/source_pack.gd` requires the manifest hash, verifies
  original file hashes, and refuses incomplete packs. Failed replacement
  preserves a previously loaded pack. This is explicit loading only; it does
  not change the existing installer or select a user's active pack.
- `atlas_pixels.gd` extracts original trimmed/rotated frames. The existing
  static `source_ui_atlas.gd` uses the same extraction helper.
- `sprite_scene.gd` supports only source Node/SingleNode/Sprite hierarchies,
  discrete FileData/VisibleForFrame tracks, and named source clips. Other
  classes/tracks/layout constraints are rejected. It is not a full Cocos UI
  renderer. No buttons or gameplay services have been connected by this code.

## Evidence available in the private workspace

The supplied catalog is a subset: 2,301 distinct CSB names. Qualified received
inputs contain 560 CSBs; all 560 decode without errors or unknown fields.
This does not establish complete dependency or runtime coverage. Old base508
members are used for current523 only when the supplied container comparison
proves they were retained unchanged; 68 unqualified old members stay excluded.
Full dependency traversal of these 560 entries found 25 closed dependency sets.
Most are empty roots/list containers; none contains a Button. Three additional
icon effects need source Panel clipping support and are not silently flattened.

- `python3 tests/test_original_ui_decoder.py`: seven rejection/provenance tests
  passed. Synthetic structural inputs are not original-art evidence.
- `tests/original_ui_pack_test.gd`: 3,596 checks passed against 897 original
  atlas frames (89 rotated), independently compared with Pillow raw RGBA
  hashes. Also verifies incomplete/tampered pack rejection.
- `tests/original_ui_sprite_render_test.gd`: 52 checks and 12 actual OpenGL
  captures passed for the supplied Common/Rare/Unique Change effect leaves,
  using their exact source frame references, hierarchy, transforms and clips.
  These are isolated three-node effect scenes, not complete card screens.
  Cocos-vs-Godot compositing equivalence has not been independently compared.
- Repository resource integrity passed: 723 atlases, 41,442 frames,
  233,420,026 bytes. This verifies tracked repository resources only.

Private output manifests (not public Git):

| Pack | Manifest SHA-256 | Status |
| --- | --- | --- |
| atlas-primitives-01 | cf616b4d1e5860f1545cdf75e9a511ed173085b5c7f284a1235880185b5b5808 | frame pixel checks passed |
| card-fx-closure-01 | 667c13157f0043baa2bd264cd6ba5726c8ab0fcd91da22a408d2b1bbec4495e2 | three leaf scenes rendered |
| alchemy-closure-01 | 12a465b4991fa7e351338c2d2f81a3ac6c3dbf78d209f374150eae57c274783a | 41 blockers; activation refused |

These outputs and captures currently reside under `/workspace/private-ui-inputs`;
local existence does not establish durable artifact or executable delivery.

## Remaining work

Current523 UI38/39/41/46/48/51/120/141/158 containers have been requested through
the parent's private Library transfer workflow. Atlas_Alchemy, Atlas_Pass and
Atlas_Texture4 require a full supplied-corpus lookup; their absence from a
partial catalog is not proof of absence. The original malformed
`UI/Effect/CharSelectEffectFire_Blue.plist` remains unmodified and blocked.

Full screens, popups, tabs, selections, disabled/result states, nested scenes,
fonts, scale-nine components and additional animation types remain to connect
and verify from complete original dependencies. The 61 inspected code entry
points are an intermediate inventory, not the definition of all original UI.
Service actions, costs/consumption/results, save failure/restart behavior, whole
game boot, device execution and source screenshot comparison remain unverified
for this implementation. PR264/265 generic forms have not been presented as
original UI. No source-free replacement screens are supplied.

## Follow-up: transparent source clipping and further source lookup

The same branch now supports the supplied transparent, noninteractive Panel
clipping used by three additional icon effects. Background fills, scale-nine
panels, interactive panels and source callbacks remain rejected. This adds no
invented pixels or item identity mappings. The original icon scenes are:

- `UI/CsbFile/icon/Fx_Item_Armor_Pants_Myth_Eodin.csb`
- `UI/CsbFile/icon/Fx_Item_Armor_Shield_Myth_Eir.csb`
- `UI/CsbFile/icon/Fx_Myth_Saintpaladin_Incarnation.csb`

Their closure contains three CSBs and nine files, manifest SHA-256
`566a4a66e894abdb3a761e8c0cca51d95799c52989a097030cab76839d99fb19`.
OpenGL verification passed 76 checks and saved 12 unchanged-source captures.
A separate clipping probe moves existing source pixels within the viewport:
they disappear outside the source Panel and reappear when clipping is disabled.
This probe is behavioral verification, not a source appearance comparison.
Six source effect leaves have now rendered. Item-to-effect binding still needs
verified source identity references; filenames alone do not authorize a mapping.

Both supplied split-archive terminal ZIPs were materialized in this environment.
Central-directory inspection read all 21,553 entries of `111.zip` and 12,390
entries of `12.zip`. Neither list contains direct CSB, UI*.dat, Atlas_Alchemy or
Atlas_Pass entries. These archives list older PC-client trees. Nested container
contents were not inspected, and no current523 equivalence is asserted. Split
parts were not downloaded without a relevant member identified.

| Received archive | Bytes | SHA-256 |
| --- | --- | --- |
| 111.zip | 72419795 | d05875c0d63da43b890128ae97a556d30f8d790be4bf5bd2f77e61b84f41c49d |
| 12.zip | 58117920 | b96c6b9a7837a195469c0c6842d807a22f1fd654fd429dc50984d3def3e0145a |

Library title search identified three further candidates, not verified inputs:
`base508-identity-ui-originals-001.zip` (libfile_11c367e8c1e081918837dc203d15d787),
`TWILIGHT_523_dungeon_UI_local_evidence_20261104.zip`
(libfile_76c3a981061081919d9c912846d96d6d), and
`TWILIGHT_latest523_global_map_UI_world_area_coordinates_zoom_hierarchy_20261104.zip`
(libfile_99ea256c6f2c8191a0a1b337cf665c14).
The required Library search-result download helper failed before transfer with
`hosted apps tools/list request failed with HTTP status 401`. This is an
**authentication failure**, not an automatic approval denial or proof of missing
source. No bypass or identical retry was attempted. Their contents remain
unavailable; earlier received bundles remain usable. The requested 560-item
scope and remaining 535 dependency-blocked entries are unchanged.

## Remaining 19 follow-up

See [per-item contracts and execution evidence](ORIGINAL_UI_REMAINING19.md).
The 19 remaining dependency-closed entries now instantiate in explicit read-only
inspection mode and passed 129 OpenGL/execution checks. All outputs are
transparent source containers or unbound animation attachment nodes; this does
not increase the count of fully connected gameplay screens. Numeric source
timelines now execute for the two attachment scenes. Interactive/list/ProjectNode
contracts remain blocked in ordinary runtime mode. No 401 download was retried.

## Source acquisition and renderer follow-up

The received UI551 handoff contains an original public-archive acquisition plan.
Its independently accessible archive metadata and ZIP central directories give
path/size candidates for all 154 expected current523 UI containers. This uses
that original source evidence, not a retry or authentication/URL change for the
failed Library downloads. New DATs are accepted only after exact expected size,
SHA1 and inner ZIP CRC checks; originals remain private and unmodified.

With UI38, UI39, UI5 and further priority containers received, the 2026-11-05 traversal
found 292 closed entries out of 560. This is dependency
availability, not gameplay completion. The acquisition process and full-corpus
lookup continue; missing Atlas_Pass and child CSBs remain explicit pending
references until found. No filename similarity is used to replace them.

Current local renderer additions: RGB and limited blend tracks, original
ImageView geometry, source cap-inset slicing (including negative center scales
for small controls), original-font single-line Text inspection, and explicit
stop/status methods. The scale-nine implementation follows the corner/center
geometry and drawing order in upstream Cocos 3.6 `UIScale9Sprite.cpp`. Cases
where both cap dimensions overrun the source and disable upstream clipping
remain unsupported because outside-source pixels are unproven. Blend pairs
`772:1` and `1:1` also remain explicit blockers.

Three newly resolved effects passed 46 actual OpenGL/clock/stop checks. Seven
image-view entries passed their render run after source cap-inset behavior was
implemented; default-hidden states remain hidden. Original font files are
hash-checked and system font fallback is disabled. Serialized examples such
as `888%` are inspection data only; strict runtime mode refuses Text without a
live-value binding contract. Font shaping and engine-wide Cocos/Godot pixel
parity have not been independently approved.

See [item consumer contract](ORIGINAL_UI_ITEM_CONSUMER_CONTRACT.md) for actual
API and ownership boundaries. A private, standalone three-icon source pack was
saved as Library `libfile_14f7b43c4b5081918875b5b52f702815` (356727 bytes, ZIP
SHA256 `637dff33fcfbb9d00b57ed4d746bc882597bdadb4ac6541f1a7c36ed7df4f407`).
It contains nine verified original files and the manifest whose SHA256 is
`566a4a66e894abdb3a761e8c0cca51d95799c52989a097030cab76839d99fb19`.
Consumer receipt, ItemClass mapping, live slot use and saves remain separate
checks; the handoff is not a claim of all item icons installed.


### Follow-up render checkpoint (not gameplay completion)

The explicitly assembled 288-entry private snapshot produced 75 accepted
inspection scenes and 213 explicit rejections, with 299 OpenGL capture records.
55 accepted entries produced visible pixels; 20 were empty/default-hidden
containers. This is not 75 completed screens or a passing all-UI suite. The
runner exits nonzero when any source is rejected and records every reason.
Six accepted entries include original Button state textures. Their normal,
pressed and disabled states can be inspected; input remains disabled until an
existing service binding is implemented. No synthetic button press is counted
as a service operation. Original fonts are required; unavailable fonts and
unsupported text layout fail instead of receiving substitutes.

The source numeric easing IDs 0–5, 25, 27 and 29 are supported. 9,009 samples
matched separately compiled Cocos 3.6 functions within 0.000002. Custom curves
and other easing IDs still fail explicitly. Source `1:771` blend now selects
premultiplied-alpha mode instead of ordinary mix; unsupported blend targets
fail before a scene is mounted. The three original item effects passed 82
checks in the follow-up renderer, including clipping, playback and stopping.
Decoder/provenance tests: 7 passed. Checkout integrity: 723 atlases / 41,442
frames / 233,420,026 bytes. No full CI, installation, service save/restart or
Cocos-versus-Godot full pixel-parity result is implied.

Sources for the renderer behavior:
- https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/ui/UIScale9Sprite.cpp
- https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/2d/CCTweenFunction.cpp
- https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/editor-support/cocostudio/WidgetReader/ButtonReader/ButtonReader.cpp
- https://docs.godotengine.org/en/stable/classes/class_canvasitemmaterial.html


### Post-draft continuation

UI-only draft PR #267 preserves the work at the same branch/workspace. A later
307/560 dependency snapshot added 19 inspectable candidates; five rendered
(three exact Alice weapon-icon effects and two original dash effects), while
14 retained explicit runtime blockers. The three icon effects also passed 46
strict OpenGL/playback checks. Their separate private pack has manifest SHA256
`ebf14ad21218b6ac7d5a9e9e68ef3c81f366b78e0e725df04e2ec69f2a5894f0`.

Six four-point custom easing curves are now evaluated with the original Cocos
customEase Y-ordinate formula, not CSS bezier inversion. Standard plus custom
reference validation passed 15,024 checks; malformed curves remain rejected.
This allowed two additional original party-dungeon cutscenes to render (eight
captures). A third custom-curve entry still fails custom-property/nested-scene
checks. Across these disjoint/previously-rejected sets, 82 entries have accepted
inspection renders; this remains zero claimed completed service screens.

PR264's public source UI ABI at `8488ada80cb0d0d647be9aa15986e82b059afb86`
was compared with actual attendance/pass trees. Attendance has 58 nodes and
repeated button names: names alone cannot identify bindings. Its current exact
missing references include `Attendance_Tab_Promotion.csb`,
`Fx_Glow_Loop_07.plist`, `Hud_Icon_Sample_001.png`, and
`Font_Damage_Kill_Set.fnt`. Pass has 98 nodes; Atlas_Pass, StepUp and receive-all
popup references remain pending, and its original fire particle plist contains
trailing malformed XML. Original bytes are not rewritten to make it parse.
The ABI's MainMenu component paths have not yet been received in this source
index and are not substituted with content-root CSBs. No PR264 service code was
copied or independently reimplemented.


The follow-up ProjectNode inspector resolves the exact referenced CSB and
applies the outer source Node properties to its root, matching CSLoader's
create-then-apply behavior. It initially pauses the inner timeline at frame 0;
it does not invent autoplay. Recursion, missing children, non-Node referenced
roots, unsupported nested controls and ActionValue tracks remain explicit
failures. Strict consumer mode still rejects unbound ProjectNodes. The original
288-entry snapshot now accepts 81 inspection entries with no regressions from
the earlier 75; four are newly resolved nested scenes and two are the previously
recorded custom-easing scenes. Together with the disjoint five later entries,
86 entries have inspection renders, not completed service screens.

Reference: https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/editor-support/cocostudio/ActionTimeline/CSLoader.cpp


### Particle parser compatibility correction

The earlier `unreadable_particle_plist` reports were Python parser failures,
not proof that the original Cocos client could not read those files. Cocos 3.6
pins external `v3-deps-47`; its SAXParser visits TinyXML2's DOM without checking
the parse return code. The exact pinned TinyXML2 sources were compiled in an
isolated reference probe (only the export macro was stubbed). All 44 observed
trailing-data particle files produced a complete root dictionary identical to
our compatible first-complete-plist interpretation. Original file bytes/hashes
remain unchanged; malformed/incomplete root dictionaries still fail and atlas
parsing is not relaxed. Packs record each compatibility use and original hash.
Eight decoder/provenance/compatibility tests passed. Particle rendering itself
remains unsupported and is not declared complete by this parser correction.

With newly received originals and this source-proven parser behavior, the latest
completed dependency snapshot resolves 490/560 entries (6,434 indexed files).
This is separate from the 86 accepted inspection renders recorded above.
The complete 8,303-file parent catalog was officially received and its handoff
ZIP size/SHA256 verified. The old 68-render pack's 396 hash-read files all match
catalog paths, sizes and CRC32; 349 also have matching supplied SHA256 values.
The other 47 retain locally observed SHA256, not invented catalog hashes.

References:
- https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/external/config.json
- https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/platform/CCSAXParser.cpp
- https://github.com/cocos2d/cocos2d-x-3rd-party-libs-bin/tree/v3-deps-47/tinyxml2
