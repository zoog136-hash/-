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

## Runtime service bridge (implementation only, not newly tested)

`renewal_hud.gd` now exposes `bind_original_ui_runtime(runtime, source_pack)`,
`register_original_ui_content(section, focus_kind, member, source_sha256,
mount: Node2D, binding_factory: Callable)` and `close_original_ui_content()`.
The runtime is PR264's public ABI at
`8488ada80cb0d0d647be9aa15986e82b059afb86`. The integration owner can call the
first method after its existing `unconfirmed523.configure(world)` and register
only exact original content roots. There is no automatic source-pack install,
inferred root filename or invented mount transform. The supplied existing game
mount owns the original screen-coordinate contract. The current main base does
not contain that runtime, so this branch does not add a duplicate service.

`source_runtime_presenter.gd` registers its callback through
`runtime.bind_presentation()`. When `request_presentation()` has prepared a
model, the bridge reads `runtime.source_ui.snapshot()`, selects an explicitly
registered `(section, focus.kind)` route, and calls
`binding_factory(model, source_service_session) -> Dictionary`. The returned
exact-offset bindings configure the original CSB in strict mode. Unsupported
or unbound content still returns failure to the runtime. The two MainMenu
components are explicitly rejected as content roots. No substitute screen is
created if a declaration or source dependency is missing.

The session exposes `action_callback(row_id, action_ref) -> Callable` only for
one exact opaque reference supplied in that row. Its `begin(action_ref)`,
`choose(key, option_indices)`, `confirm()`, `cancel()` and `close()` delegate to
the existing source_ui service. The service retains all choice validation,
revision/fingerprint, single-save and reward logic. `action_result` forwards
the returned dictionary for the original result-state adapter. The UI does
not auto-confirm, retry a failed save, select an option or generate a request.
Replacing a scene invalidates its old callbacks without closing the newer
model that the runtime already prepared.

A ProjectNode binding may declare `{"role":"project","bindings":{...}}`.
Those child bindings use offsets from that exact referenced CSB and recurse
through the original loader. Strict mode still rejects unconnected child
controls/content. No generic form is introduced by this path.

These bridge and recursive-binding changes were implemented after the user's
instruction to stop new checks/tests. They have not been executed or validated,
and do not increase gameplay-completion or inspection-render counts. Actual
content-root/node mappings, caller registration and source-coordinate mounts
must be provided by their existing source contracts before a screen can open.

The source-row `action_callback` is a zero-argument Button callback. Checkbox
callbacks accept the selected boolean; their original caller must map that
value to the provided choice key/indices and invoke `choose`. There is no
implicit checkbox-to-reward or numeric-ID mapping.

Exact node bindings can also supply `{"role":"source_text","text":value}`,
`{"role":"source_percent","percent":value}`, and an explicit `visible` boolean.
The existing caller supplies those values from its source model. No balances,
progress formula or variant choice is calculated by this renderer. Text retains
its source font/layout and percent retains its original LoadingBar texture,
crop/clamping and direction. `set_bound_text(offset,value)`,
`set_bound_percent(offset,value)` and `set_bound_visible(offset,value)` update
only previously declared bindings. Text updates stage their fields before
commit so an unsupported font glyph/layout leaves the prior display data.
These live-binding changes have not been run or tested under the latest user
instruction; they do not increase any completion or render count.

`hud.mount_original_ui_menu(button_id, existing_source_mount)` connects the
already declared original menu components 106/116 to that same runtime's
`source_ui.request_menu()`. Only one mounted component per original menu ID is
retained by the presenter; replacing or rebinding disables/frees the old one.
The caller supplies its existing original-coordinate mount. Unsupported menu
IDs still fail. This implementation path uses the existing menu adapter and
contains no generic menu or new pixels. It is also unexecuted/unverified under
the latest instruction.

ScrollView now retains its serialized inner size and original initial top-left
position within the source clipping/background hierarchy. A strict
`{"role":"source_scroll","input":Callable,"position":Vector2}` binding forwards
Control-local input events to the existing original scroll controller. The
position is optional and uses original Cocos coordinates. The caller owns
original direction, drag, bounce/inertia and child-event arbitration; no Godot
scrolling behavior or estimated motion is substituted. Without that input
controller, strict presentation is unavailable. The caller can use
`set_bound_scroll_position(offset, cocos_position)` for its original motion.
This addition is implementation only and has not been run or checked.

For source Text/Button nodes with an explicitly empty `fontResource`, the
renderer can resolve the serialized `fontName` through
`source_pack.declared_system_font(family)`. It accepts only an exactly named
installed family and its matching FontFile, with glyph fallback disabled. A
nonempty missing original font path still fails. No font is downloaded,
generated or substituted. Host-system font bytes are not original UI inventory
member bytes and must not be counted toward source usage. This path has not
been executed under the current no-new-checks instruction.
