# Original CSB player contract for item icons

This describes the existing local UI branch API. It is not permission to copy
unpublished work or a statement that these classes have merged into main.
The UI owner maintains the loader/player; the item owner supplies the verified
ItemClass → IconID → exact original CSB mapping and existing item presentation
entry point. No second CSB engine or inferred filename mapping is needed.

## Implemented API

`res://scripts/ui/original_ui/source_pack.gd` extends RefCounted:

- `open(pack_root: String, expected_sha256: String) -> Dictionary`: expects
  `original_ui.json` and `originals/UI/...` inside a private directory. SHA256
  must come from the verified pack handoff, not an untrusted replaced receipt.
  Verifies manifest hash, every original file's bytes/hash, scene provenance,
  and absence of dependency/decoder blockers. Returns `ok`, `scene_count`,
  `rendered:false`; errors include manifest/hash/schema/path/source failures
  and `unresolved_source_dependencies`. Failed replacement preserves the
  previously loaded pack.
- `scene(member: String) -> Dictionary`: exact `UI/...csb` entry, empty if absent.
- `nodes_named(member, source_name)`: original descriptors, not live controls.
- `texture(original_resource_data)`: original frame/direct-image Texture2D,
  null on unavailable/unsupported input. Do not fabricate replacement pixels.

`res://scripts/ui/original_ui/sprite_scene.gd` extends Node2D:

- `configure(pack, member, inspect_only=false) -> Dictionary`: call once before
  mounting. Default strict mode is required for item consumers. On success,
  add the scene under the existing item's presentation node. The original
  nodes, transforms, frame references and clips are retained. Caller placement
  is external to the original hierarchy; do not rewrite node layout or add
  arbitrary imagery. Failure returns `ok:false`, `error`, and sometimes
  `details`; free the failed node.
- `play(source_clip: String, repeat=false) -> Dictionary`: exact original name,
  starts at its serialized start frame and speed. Unknown names fail. Caller
  must obtain clip/loop choice from original mapping, not assume `normal` or
  loop every clip. Supports multiple named source clips.
- `seek_frame(frame_number: float)`: absolute original frame number.
- `stop()`: freezes the current frame without replacing/clearing pixels.
- `playback_status()`: `playing`, `frame`, `loop`, `source`, `clip`,
  `inspection_only`. Stop/status are added in this follow-up and locally tested
  in this checkpoint; consumers must use the corresponding revision.
- `queue_free()`: standard Godot deferred disposal; `free()` is appropriate for
  a failed, unmounted instance. RefCounted pack lifetime follows its holders.
- `source_nodes`: original CSB offset → live node. It is for inspected exact
  bindings; a name suffix is not a unique identity.

The previous committed player supports Node/SingleNode/Sprite, limited
transparent Panel clipping, discrete FileData/VisibleForFrame, numeric Position,
Scale/RotationSkew/Alpha and Linear/Sine-In easing. Current follow-up adds
CColor/limited BlendFunc and ImageView (ordinary/nine-slice). These additions
have a separate local render scope; they do not establish support for every
item CSB. Supported blend pairs are `770:1`, `770:771`, `1:771`; other pairs
fail. Invalid/unsupported cap insets fail instead of being silently corrected.
Text is available for inspection only with the exact source font and supported
single-line layout; it still requires live data binding. Button state textures
are inspection-only and have no service callbacks. CheckBox, Particle and
nonempty nested ProjectNode are not yet supported. Inspect-only list/empty ProjectNode rendering is **not** a usable
item presentation and must not be enabled to suppress errors.

## Data still required from item owner

Provide the verified IconID and exact CSB path, the original clip and repeat
contract when animated, intended existing host/slot lifecycle, and provenance
for the mapping. UI owns dependency closure and pixel/animation validation.
ItemClass ownership, item instance IDs, selection, consumption and saves remain
with existing item services. This player changes none of them.

The private AssetView/AssetType tables can prove asset-to-scene mappings, but
that alone does not establish the ItemClass association. Do not infer the
association from filenames.

## Remaining integration work

No existing inventory/crafting/selection host is connected by this API document.
Save/restart and actual item-slot lifecycle must be tested after the item owner
supplies the exact mapping and host contract. The three already rendered icon
effects are not evidence that all 123 item CSBs or 560 UI entries are supported.

The v2 open/configure/play/seek call signatures are unchanged. No completion
signal was added. All inspection-only acceptance remains unavailable to strict
item consumers. The supported numeric easing IDs are 0–5, 25, 27 and 29.
