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
