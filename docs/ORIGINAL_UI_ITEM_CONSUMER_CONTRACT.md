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

- `configure(pack, member, inspect_only=false, bindings={}) -> Dictionary`: call once before
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
- `stop()`: pauses this player's action timeline at its current frame. It does
  not pause independent nested actions or particle simulation. To suspend the
  whole mounted presentation, set its Godot `process_mode` to
  `Node.PROCESS_MODE_DISABLED`; disposal remains `queue_free()`.
- `playback_status()`: `playing`, `frame`, `loop`, `source`, `clip`,
  `inspection_only`. Stop/status are added in this follow-up and locally tested
  in this checkpoint; consumers must use the corresponding revision.
- `queue_free()`: standard Godot deferred disposal; `free()` is appropriate for
  a failed, unmounted instance. RefCounted pack lifetime follows its holders.
- `source_nodes`: original CSB offset → live node. It is for inspected exact
  bindings; a name suffix is not a unique identity.

The current player supports Node/SingleNode/Sprite, transparent Panel clipping,
ImageView/nine-slice, original button states, explicit source text lines,
LoadingBar inspection, and original ParticleReader GROUPED particles using
supplied plist/PNG resources. CheckBox, Slider, PageView and other unimplemented
widget classes remain rejected. Unsupported text wrapping/clipping or blur also
fails explicitly. Particle playback uses original emission/physics parameters;
the original client's random seed is not known. The supplied embedded RGBA8 PNG is also decoded from its exact original
plist bytes; unsupported embedded formats remain rejected.

All 15 observed Sprite GL blend pairs and standard Cocos easing IDs 0–30 are
supported, as are the validated original four-point custom curves (-1).
Source timelines include texture, visibility, position, scale, rotation/skew,
color, alpha, anchor, blend and nested ActionValue. Sound-only FrameEvents are
retained as excluded metadata. Other events require a caller contract.

Bindings use exact source node offsets. Existing button callbacks and declared
static source text can pass strict validation; live percent/list content and
unbound nested ProjectNodes still cannot. Nonempty ProjectNodes with Node roots
are available for recursive inspection. Inspection mode must never be used to
suppress a consumer failure. The original menu adapter's two source menu buttons
are separate from the content-screen and save/restart contracts.

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
item consumers.
