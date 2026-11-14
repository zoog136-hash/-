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


Bitmap-font dependency handling now includes every declared page image in both
the pack builder and runtime validation. The rebuilt 183-entry snapshot has
894 original files, including two font pages absent from the earlier temporary
pack. The older incomplete temporary pack is superseded and rejected by the
runtime. Four original-pack checks confirm rejection and preservation of the
previous valid pack; nine decoder/provenance tests pass. The corrected new
183-entry render run accepted ten additional entries and explicitly rejected
173; this brings accepted inspection entries across the recorded sets to 96,
not completed service screens. Attendance's six-scene/33-file closure is now
complete; its runtime/control/service work remains outstanding.


### Original PNG alpha and sprite modulation

The renderer now follows Cocos PNG premultiplication and Sprite
`opacityModifyRGB` together, including the integer `(channel*(alpha+1))>>8`
conversion. Original files remain unchanged. The existing one-argument
`pack.texture(reference)` still returns the raw texture; the renderer opts into
Cocos pixels with its second argument. Materials explicitly support the three
previously accepted blend pairs and reject shader compilation failure.

Thirty original-pixel checks passed for source opacity and those three blend
pairs over opaque black in isolated Mesa OpenGL. The three original icon
scenes passed 82 playback checks, and seven original ImageView entries rendered
without errors after this change. These are regressions of already recorded
entries, not additional completed screens. This does not establish transparent
framebuffer alpha parity, device parity, or service integration.

The actual MainMenu Attendance and Pass components are now present in verified
UI155 originals. Their exact Button offsets are 1856 and 1488 respectively.
The public PR264 `source_ui.request_menu(106/116)` delegates to the existing
runtime presentation adapter; opening a menu is not a claim or save operation.
Control binding remains in progress; no service implementation was copied.

### Verified original menu controls (partial integration)

`source_menu_adapter.create(pack, button_id, source_ui)` accepts only original
menu IDs 106/116 and verifies the exact CSB SHA256 before binding node offsets.
It returns `{ok, scene, menu_button_id, content_presented:false}`; failures return
`{ok:false,error}`. The caller adds/frees the returned scene and supplies its
existing PR264-compatible `source_ui` service. The adapter calls only
`source_ui.request_menu(id)` and does not implement rewards, transactions or saves.
The original content root still requires the host's presentation adapter.

The exact original two-scene/seven-file private closure rendered eight captures
(normal, pressed, disabled and initial states). Viewport mouse-input dispatch
passed 22 checks for original press/release visuals, exact menu IDs, unchanged
service failure, hidden cancellation, disabled state and original disabled-overlay
blocking. These tests use a service probe; real host integration, touch/device
input and reward/save/restart behavior are still outstanding. These two menu
components are not automatically added to the 560-scene progress denominator.

Cocos `UIButton::onPressStateChangedToDisabled` uses its normal texture with
`ccShader_UI_Gray.frag` when the disabled path is empty. The renderer now follows
that explicit source behavior rather than requiring a nonexistent image. Its
luminance coefficients and intentional omission of vertex color passed three
additional original-pixel GL checks (33 total). The initial complete-zero inherited-alpha culling difference is resolved by
the source-display binding described below. No broad device pixel-parity claim
is made.
Source custom properties containing only string `soundid`/`touchsoundid` are
preserved as metadata but not played because sound is excluded from the current
scope. Other custom behavior remains rejected.

References:
- https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/ui/UIButton.cpp
- https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/renderer/ccShader_UI_Gray.frag

### LoadingBar and discrete anchor tracks

The original non-scale9 LoadingBar now crops its supplied texture using the
serialized percent/direction and preserves source geometry. AnchorPoint tracks
use their actual ScaleFrame payload and Cocos's discrete on-enter semantics.
Recovery_ProgressBar now renders its original frames 0, 5, 97 and 190. Six GL
checks cover original percent crops/clamps and strict rejection without a live
percent binding. This adds one accepted tracked inspection entry (97 total),
not an implemented recovery service. The separate original menu components are
not included in that count. The latest dependency snapshot is 504/560; all 14
newly dependency-complete entries were explicitly rejected for remaining source
features rather than rendered as incomplete screens.

References:
- https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/ui/UILoadingBar.cpp
- https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/editor-support/cocostudio/ActionTimeline/CCFrame.cpp

### Source easing and audio-excluded timelines

All 31 standard Cocos 3.6 TweenType functions plus validated custom curves now
match 37,046 compiled upstream-reference checks. Source exponential endpoint
quirks and default elastic periods are retained. Parameter shapes outside the
verified contract are still rejected.

FrameEvent entries containing only a string EventSound are retained in
`excluded_audio_events` with original frame/tag/value while sound stays excluded.
Other events remain explicitly unbound and cannot pass strict consumption.
Malformed source custom properties are rejected without emitting parser errors.
The targeted 107-entry run accepted 55 and rejected 52 after this change, with
no script/shader/runtime error lines. CharacterSelect_List_Slot adds one further
inspection render after easing support. Across disjoint tracked entries, 153
now have inspection captures; this does not establish their service integration.

### Nested source actions and main integration

The branch now includes verified main `1333851bb2eb193a6ac1fc3e3b852787c08994ff`
without file conflicts; resource integrity still passes 723 atlases / 41,442
frames / 233,420,026 bytes. No integrated service was reimplemented.

ProjectNode ActionValue now resolves the source child player and preserves its
innerActionSpeed, named/all clip ranges, single-frame pause, loop/no-loop mode
and the parent-duration limit specified by Cocos InnerActionFrame. UpdateScene's
actual single-frame child action rendered seven captures. The other nine root
candidates exposed deeper unsupported source elements and remained rejected.
Loop/no-loop child action execution still needs representative full-source
render validation; this change does not mark those screens complete. The
tracked inspection render count is now 154.


### Original framebuffer blend and cascaded source display

The renderer now evaluates all 15 observed GL blend-factor pairs against the
actual copied destination framebuffer, including destination alpha/color. Each
source Sprite retains draw order and its original texture. Source NodeReader's
color/opacity cascades are computed with 8-bit truncation at each level and
bound to the visual shader, avoiding Godot's early culling at zero/tiny alpha.
This also resolves the earlier disabled-button gray shader's zero-alpha case.

720 GPU/CPU RGBA comparisons passed across all 15 pairs, three destination
alpha values, and source opacity 255/128/1/0. The gray/alpha test passed 33,
original icon playback/clipping 82, and original menu input 22 checks. Of 74
previously blend-blocked candidates, 34 rendered and 40 remained rejected for
other original features. All 34 were rendered again after the source-display
correction with no script/shader/runtime errors. The union of tracked inspection
entries is now 188; these counts still do not represent completed service UIs.

Reference: https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/editor-support/cocostudio/WidgetReader/NodeReader/NodeReader.cpp

### Explicitly empty original button states

An empty source image path now retains an empty visual and its original hit
extent; it is not treated as a missing nonempty asset and no image is invented.
When the pressed image alone is unspecified, the original UIButton normal
renderer and its documented 0.1 scale increment are used, with the original
center and title behavior. Supplied nonempty paths still require exact assets.
The 41 affected source candidates rendered 36 entries and rejected five for
remaining nested source contracts/features. The tracked inspection union is
224 entries, with original button-state captures; service bindings remain
separately reported.

### Explicit source text lines and complete container receipt

Explicit source newlines now draw with their supplied font, alignment, shadow
and outline. Multiline text requiring unimplemented word wrapping or clipping
is still rejected rather than silently rearranged. The targeted 52-entry run
rendered 19 and rejected 33, bringing the tracked inspection union to 243.

All 154 current523 UI containers completed exact expected size/SHA1 validation.
Their index contains 8,303 files and resolves 524/560 tracked dependency closures.
The 36 unresolved closures reference 25 absent file paths and/or 38 missing
atlas frame names. A search of every received original atlas found none of those
38 names, including aliases. Missing references remain explicit; no old or
similar-looking asset was substituted. This receipt is not full UI completion.

### Original particle simulation and fixed inventory scope

ParticleReader's GROUPED mode now consumes the original plist and PNG through
an exact-hash-checked pack. Gravity/radius motion, emission timing, particle
lifetime, color, size, rotation and swap-removal follow the Cocos 3.6 source.
The shader uses the original blend pair and the original particle vertex-color
premultiplication rule; node opacity is not substituted for particle color.
No particle images or effect parameters were authored.

All 168 provided particle dictionaries matched their original values in 673
checks. Four original configurations matched 23,612 comparisons against the
unmodified upstream C++ initParticle/update bodies with identical injected test
randomness. Three original CSB/plist/PNG scenes produced nine OpenGL captures;
all three displayed pixels during the sampled execution. These are inspection
results, not proof of the original client RNG seed, device parity or game-service
integration. The supplied embedded PNG now passes exact source hash, dimensions
and all 10,000 decoded PMA-pixel comparisons. Three source effects also pass
strict configuration and whole-presentation suspend/resume checks. Original
Particle BlendFunc timelines are connected through the source BlendProtocol
semantics; no service code is duplicated.

The fully received UI inventory is 8,303 members / 1,160,252,897 original member
bytes. It contains 3,034 CSBs (53,839,932 original bytes), all decoded without
parser blockers. The historical 560 tracked roots reach 1,400 of those CSBs;
1,634 other supplied CSBs remain outside that root graph. Thus 560 is not the
whole-source usage denominator. Container bytes, decoded caches, source receipt,
inspection and actual game consumption must remain separate. No 95% actual-game
usage claim is established by these inventories or inspection runs.

References:
- https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/2d/CCParticleSystem.cpp
- https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/2d/CCParticleSystemQuad.cpp
- https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/editor-support/cocostudio/WidgetReader/ParticleReader/ParticleReader.cpp

The 102 particle-bearing tracked candidates produced 46 accepted inspection
entries and 56 explicit rejections. Original particle BlendFunc support then
resolved all 10 targeted timeline rejections. The deduplicated tracked inspection
union is 299/560. Remaining unsupported controls, list layout/data, text layout,
custom properties, missing dependencies and gameplay bindings are not complete.
These runs do not establish 299 working game-service screens.

### Supplied panel backgrounds

Panel/inspection ListView backgrounds now read the original solid-color and
image fields, native-image centering, nine-slice size/cap insets and clipping.
Only source color types 0/1 are enabled: all 2,883 supplied Panel descriptors
contained those types, with no gradient descriptors. No background artwork or
colors were authored. Three original solid backgrounds passed 39 OpenGL
geometry/RGBA checks. Of ten previously panel-blocked roots, four rendered and
six exposed missing original fonts or unbound lists. The tracked inspection
union is 303/560. Existing original attendance/pass menu input still passes
22 checks after this change. The six image-bearing original Panels need their
own representative render coverage; this checkpoint does not claim that test.

Reference: https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/ui/UILayout.cpp

### Original authored list rows

Inspection now mounts the original Widget rows in supplied ListViews, using
ListViewReader direction/gravity, ListView margins/order and initial inner size,
and LinearLayoutManager anchor-based placement. No rows or data were invented.
All 205 nonempty lists from the 918 supplied ListView descriptors matched 1,915
checks against unmodified compiled upstream functions. Scene mounting/order and
strict rejection of unbound lists passed 167 further checks. Eleven of fourteen
targeted roots rendered, bringing the inspection union to 314/560; three still
fail for custom properties, missing source fonts or text clipping.

This covers initial authored-row layout, not scroll input, live row population,
selection or game-service completion. AddUpExp inspection visibly retains
supplied overlapping variant layers before caller visibility/data bindings;
it is not an approved usable game screen. Source fields were not changed to
hide those layers. Animated row-layout timing still requires representative
source/client validation.

References:
- https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/ui/UIListView.cpp
- https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/ui/UILayoutManager.cpp
- https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/editor-support/cocostudio/WidgetReader/ListViewReader/ListViewReader.cpp

### Original checkbox renderers and input

CheckBox now preserves the five supplied renderers, original selection flag,
normal/pressed/disabled transitions, default zoom and gray-shader rules,
including partially absent disabled images. No substitute cross or background
is drawn. All 107 supplied checkbox descriptors use explicit sizes and no flips;
unverified intrinsic sizes/flips remain rejected.

Ninety-three isolated source components had complete texture dependencies;
fourteen remain blocked by exact missing atlas references. Those 93 matched
11,382 compiled upstream-state comparisons and passed 891 OpenGL/input checks
with 372 state captures. Mouse release toggles the original selection and calls
the supplied boolean callback once. Duplicate release, hidden cancellation,
disabled input and a returned service failure were checked with a probe.
Strict consumption requires an exact-offset checkbox callback binding; no game
service or save handling was copied. Of fifteen full-root candidates, three
rendered and twelve remained rejected for original fonts or custom properties.
The tracked inspection union is 317/560, separate from the 93 component probes.

Reference: https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/ui/UICheckBox.cpp

### Prepared service-model wiring — not executed

The existing HUD now exposes a nonvisual original-UI runtime bridge for PR264's
public `8488ada80cb0d0d647be9aa15986e82b059afb86` ABI. Explicit source root/hash,
existing game mount and exact-offset binding factories connect prepared models
to strict CSB scenes. Menu components cannot be registered as content roots.
Nested ProjectNode bindings can carry their own exact child bindings. UI action
callbacks delegate begin/choose/confirm/cancel/close to the existing service;
no cost, reward, random choice or save code is duplicated. Replacing a displayed
scene invalidates old callbacks without closing the newer prepared model.

Original Text/LoadingBar/visibility bindings can consume values supplied by that
caller, without deriving balances, progress formulas or source-variant choices.
The integration owner still needs to call the HUD bridge after configuring its
runtime and supply each original content-root/node/coordinate contract. Missing
or unsupported content remains unavailable; the UI creates no substitute form.

These edits follow the latest user instruction to implement connections without
starting further checks, audits or tests. They have not been executed, compiled
or rendered. The previous inspection count remains 317/560, dependencies remain
524/560, and no new actual game-consumption or 95% usage claim is made. Sound and
the separately excluded undeclared 135 links are not activated by this adapter.

Source ScrollView inner-container fields and explicit original-controller input
forwarding were added to the same bridge. Original drag/bounce/inertia remains
the declared caller's responsibility; strict presentation rejects a missing
controller. Text/Button nodes with no fontResource can resolve only their
serialized fontName as an exactly matching installed host font, without glyph
fallback. Missing nonempty original font paths still fail. No font asset is
created, downloaded or counted as original inventory bytes. These additions
are unexecuted/unverified and add no completed/rendered entries.

## Main gameplay continuation after8486e6f5 (unexecuted)

The original default-visible Hud_CharInfo MD18556/AC15372 text now reads the
existing character_state.melee_damage/ac integers. Its existing icon nodes,
source size/position/default mode and Header Project1800 parent are retained.
No attack/AC formula, zero fallback, mode sequence or portrait/rank is added.
The original Attack/Defense parent buttons remain explicitly unavailable;
read-only values do not claim those actions complete. A later combined scope
must actually include18508/18556/15324/15372; smaller v6 scopes are preserved.

The native source-button router connects existing HUD/inventory chrome button
instances while retaining modal/workspace precedence and PointerTransfer's
exclusive item/quickslot capture. It creates no controls, mouse emulation,
gesture thresholds or game rules. The world-map controller remains separate.

The native icon ABI now publishes exact UI component hashes, original Sprite
positions/anchors/sizes/blends and ancestor offsets. Image270 owns its selected
CSB root/identity/playback; only the root-origin-to-slot-anchor relation and
unknown original repeat remain pending, rather than either entire contract.
No new tests, game execution, render, audit or CI were run. Frozen dependency/
inspection counts and unknown whole560/game-consumption numerators are unchanged.

The held MainScene14564 -> Hud_AutoMessage root is now connected to the
existing player's actual auto_enabled boolean. Root76 visibility follows that
state; Text124 stays the exact original '자동 전투 중' at its original position,
alpha/color/font. This dedicated auto message is not used as a generic
show_message/text/2.6-second notification. Fx_Loop5..95 remains original metadata;
its repeat/autoplay policy is undeclared and no play/seek/loop is inferred.
This is unexecuted code; no render/game-consumption count advances.

## Original 523 feature windows: decisions of 2026-11-14

- 변신 파견 (`Change_DispatchView`, `source_main_card_dispatch_window.gd`):
  connected to the existing expedition runtime (prepare / start / resurrect /
  claim) for the 변신 deck. The spot coordinates
  (`MagicDollExpeditionSpot.CoordinateX/Y`) have no conversion to the page,
  so the original `Change_Dispatch_Btn` spots are laid out as a list grid
  inside `Panel_Map` instead of being placed by coordinate. The card state
  overlay and the set/info popups are the original scenes. Not connected:
  보관함 사용, 일괄 재파견, daily count, reset, and the popups' reward, item,
  exp and log lists (the TWILIGHT expedition view keeps them).
- 조합 (`UI/Compose/Compose_All.csb`): not connected; the current window
  stays. The original screen is 재료 선택 -> 제 작 -> 아데나로 결과 변경
  (`Compose_Production`, `Compose_Inventory`, `Compose_Roulette`). The
  TWILIGHT 조합 feature (`scripts/combinations`) applies and releases
  변신·인형·장비 combination sets, a different rule, and no TWILIGHT runtime
  performs that material crafting, so there is nothing for the original
  screen to show or call.
