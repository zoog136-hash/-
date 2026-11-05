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

Explicit TextOptions line-height overflow now follows the already referenced
Cocos 3.6 LabelTextFormatter rule: use whole available font lines for vertical
alignment, then stop on a newline when the next line begins below one common
line height. Button titles retain their separate dimensionless-label behavior.
Unsupported automatic word wrapping remains unavailable. Nonzero serialized
shadow blur is retained as metadata; the pinned Cocos 3.6 Label::enableShadow
implementation forces the effective blur radius to zero. This implements that
source behavior rather than drawing a new blur. These changes remain untested
and do not increase render or gameplay-completion counts.

Button/checkbox node bindings may supply the existing source `displaystate`
boolean; checkbox bindings may also supply `selected`. These explicit values
come from the original caller's model/configuration, not UI-owned eligibility
or reward rules. `set_bound_displaystate(offset,value)` and
`set_bound_selected_state(offset,value)` update only those declared fields.
The original state renderers and input guards remain in use. These connectors
are implemented without a new run/test and do not change completion counts.

Named source button callbacks require an exact `callback_name` declaration in
addition to the existing node's button/checkbox activation callback. It must
match the serialized callBackName and Click/Event type; names are not looked up
or inferred as game functions.

A binding dictionary may include `frame_events`, keyed by the exact EventFrame
source offset with a Callable receiving the untouched event string. Event entry
uses the existing clip start/end and selected source frame, following the
already referenced EventFrame::onEnter guard. No new frame/event is authored.
Sound-only events remain excluded even if a callback is supplied. Inspection
mode does not dispatch events; an unbound event still blocks strict use. The
caller provides the original handler and remains responsible for its semantic
contract; the renderer does not auto-confirm or guess an event's effect.
These callback additions are also unexecuted under the no-new-checks instruction.

A source Panel/ImageView/Text/LoadingBar that already declares touchEnabled may
bind `input: Callable` to its existing game input handler. The handler receives
the untouched Control-local InputEvent through an invisible source-sized hit
area. Named Touch callbacks additionally require the exact serialized
callback_name. No click/drag, item choice or source touch phase is inferred by
the renderer. The input must have been declared by the original widget; this
path cannot activate an undeclared touch area. Source buttons/checkboxes keep
their separate activation paths, avoiding duplicate action dispatch. This
input-to-caller wiring is unexecuted and untested under the current instruction.

Session `close()` also emits `closed`; the runtime presenter removes only that
current session's original scene. Thus a source close button can bind the
session close callback without leaving its old pixels/input on screen. On HUD
teardown, `abandon()` cancels only that session's exact pending token before
invalidating local callbacks, and does not close a newer prepared page. Frame
event handlers dispatch only for mounted presentations; loader-initialization
seeks do not invoke game handlers before the original scene has entered the
game tree. These lifecycle connections have not been run/tested.

`session.action_binding(row_id, action_ref)` returns an exact-row Button binding
using only availability fields supplied by the existing service (`disabled` or
`choice_error`). An unavailable action retains the original disabled renderer
without installing an activation callback. Enabling a declared control later
requires an existing valid activation binding; the renderer cannot invent one.
This is presentation of the service's result, not a dummy classifier or a copy
of eligibility/cost rules. This helper and disabled-control path are unexecuted.

Explicit original dummy declarations must be filtered by their existing source
owner before content/action registration. No confirmed UI dummy-ID/declaration
list is supplied in the retained UI contracts. Empty containers, unfamiliar
names, placeholder strings and missing pixels are not classified as dummies.
Original files/receipts/packs and fixed inventory denominators remain retained;
dummy exclusion is never reported as actual source consumption. The separately
excluded undeclared 135 links remain separate from dummy classification.

## Existing equipment caller endpoint (unexecuted)

`hud.bind_original_equipment_callbacks(preview_handler, commit_handler)` returns
a nonvisual `source_equipment_adapter.gd` endpoint with PR265's existing
`preview_requested(action)` / `commit_requested(action)` and
`set_snapshot(data)` / `show_quote(quote)` / `show_result(result)` interface.
Reference service/view head: `6957f1a5ca3901c416a0cb63629f839e6a7ebe0a`.
The integration owner supplies its existing handlers and the original controls'
canonical selection dictionary. This endpoint does not instantiate the former
VBoxContainer form, choose a recipe/material, calculate costs or execute saves.
Original controls can bind `select_action`, `request_preview`,
`set_confirmation`, `request_commit`, `cancel` and `close`; quote/result signals
forward the existing host's dictionaries without invented display messages.
A request acknowledgement is not an operation result.

The retained Alchemy_All source declares Btn_Alchemy and quantity controls
Btn_10 / Btn_100 / Btn_1000 / Btn_Max. The current equipment view's request shape
contains kind, target_id, material_ids, recipe_type and slot. No confirmed
mapping of those original quantity controls to that request is supplied here;
they are not assigned guessed batch behavior or hidden to make a scene pass.
Source root/node/selection/confirmation mappings remain required before that
whole screen can be mounted in strict mode. No new run or test was performed.

The equipment endpoint requires `bind_source_scene(scene)` with the strict
original CSB player before preview or commit. Requests remain unavailable while
that original scene is unmounted, hidden, queued for disposal, or inspection
only. This does not create a replacement form when a complete source mapping
is missing. This gate is implemented but has not been executed/tested.

The concrete `source_alchemy_bindings.gd` factory binds source Alchemy_All's
exact Btn_Close offset 19568 to the equipment endpoint's close method and
Btn_Alchemy offset 4084 to `request_preview_for("alchemy")`. It checks the
retained source member SHA and preserves caller-supplied bindings for the rest
of the original hierarchy. The endpoint requires a canonical selected alchemy
action and a mounted strict source scene. Closing disables/removes that bound
original scene. No quantity, recipe or material selection is inferred.
The source child ProjectNode paths/offsets are retained in that factory.
`complete_screen_contract:false` remains explicit: the quantity/help/child/data
contracts are still required, and strict loading still rejects missing ones.
This concrete mapping has not been executed or tested.

The Alchemy binding factory now wires all five serialized ProjectNode references
through the original child loader: Alchemy_Item (3828), Alchemy_Inventory (3564),
the two Fx_Alchemy_MagicBall instances (3292/3016), and Alchemy_Roulette (2720).
Caller-provided child bindings are retained; absent ones start as empty strict
binding maps. Interactive/dynamic child content still fails without its real
contract. This mounts no source-free replacement and is unexecuted/untested.

`source_event_screen_bindings.gd` now retains exact supplied Attendance_All and
Pass_All component identities and wires their serialized child ProjectNode
scopes. For the pass component, original close node 29652 uses session.close.
Explicit caller assignments for source action nodes 16964/13548/7352 resolve
only an exact row_id/action_ref in the prepared pass model. The factory does
not choose a pass, premium tier, reward or claim-all behavior. Attendance reward
actions remain in their original child-slot contract, not inferred from dates
or labels. Both factories return complete_screen_contract:false; unresolved
child/list/tab/data handlers still prevent strict presentation. They do not
establish a MainMenu-to-content invocation contract on their own.

`declared_pass_node(pack, row.source_ui)` consumes the existing ABI's exact
PassSystem namespace/ID, source_records.PassSystem.PassImageNode and matching
native_fields.PassImageNode string. It resolves only one identically named node
in the retained Pass_All source and returns its original descriptor and asset
roles. A missing/ambiguous node fails. No image role or child filename is guessed,
and this resolver does not claim the three pass asset roles are fully mapped.
These source-component connections are implemented without new execution/tests.

## Original child controls and presentation handles (unexecuted)

`source_pass_child_bindings.gd` covers the received Mission_All and Daily/Final/
Start SlotSet CSBs. `source_attendance_child_bindings.gd` covers Daily/Promotion
and their original Slot/SlotBonus CSBs. Each factory checks its retained source
member SHA, preserves ProjectNode binding scopes, and connects only explicitly
supplied original button offsets to an exact `row_id`/`action_ref` from the
existing service model. Source labels and list indexes do not assign rewards,
days, premium tiers or tab behavior. Missing declarations remain explicit and
all factories retain `complete_screen_contract:false`.

`source_pass_receive_popup_bindings.gd` binds only the supplied Receive_All
cancel/confirm controls, after the original caller explicitly declares those
operations and supplies a popup-only dismissal callback. The hidden original
popup can be configured before an action exists. Its caller invokes
`bind_pending()` when presenting it; this captures the service's existing opaque
token and returns its unchanged plan. No action begins and no visibility changes
as a side effect. Success clears that popup's captured token and calls the
supplied dismissal callback, leaving the source session open. Teardown uses
`invalidate()`; it does not cancel another pending action.

Session `pending_plan()` exposes a deep copy of the existing service plan.
`choose_pending(token,key,option_indices)`, `confirm_pending(token)` and
`cancel_pending(token)` require that exact current opaque token. Thus an older
popup or nested choice control cannot operate on a newer action. For an already
ready plan, the local token is consumed before the synchronous service confirm,
including save failure; unresolved choices remain delegated to the service.
The original `choose`, `confirm` and `cancel` entry points remain available.
The UI adds no choice values, costs, RNG, requests or saves.

The runtime presenter's `attach()` result now includes its `presenter` handle.
Its `content_presented(scene,session)` signal supplies the strict original scene
and existing session after mounting, so the caller can attach its original
controller and service-result handlers. `scene.project_player(offset_path)`
resolves only the declared sequence of original ProjectNodes; repeated child
CSBs retain distinct identities. The returned player's existing bound-field
setters update that child's original text/progress/state without searching by
labels or creating another tree.

A ListView can consume its existing authored rows in strict mode only with an
explicit `{role:"source_list",row_offsets:[...],input:existing_callable}` binding.
`row_offsets` must exactly equal the serialized child order; every child still
passes its own strict data/action bindings. Input is required only when the
original list declares touchEnabled. This does not populate an empty list with
invented rows or supply an unknown original item-template contract. Optional
Cocos-space `position` and `set_bound_list_position(offset,position)` forward
only controller-supplied coordinates; drag/bounce/selection remain that original
controller's responsibility. Inspection behavior is not a gameplay completion.

CSLoader's existing callback-name lookup is also respected: a default callback
*type* with an empty callback name does not introduce a named handler on a
passive original node. Actual buttons, touches and nonempty named callbacks
retain their separate required bindings.

All additions in this section are unexecuted and untested under the user's
no-new-checks instruction. Existing dependency/inspection counts and actual-game
consumption claims remain unchanged. Still required are the per-screen caller's
content-root entry/mount, row-to-node/data mapping, tab/variant visibility,
original scroll controller and confirmation/tooltip presentation contracts.

Registered binding factories may return either the exact-offset binding map or
the concrete helpers' `{ok,member,sha256,bindings}` descriptor. The presenter
propagates a factory failure unchanged and requires descriptor member/hash to
match the already registered original root. An incomplete-screen marker never
bypasses strict node/data/input validation. This integration is also unexecuted.

## Concrete event and game callers (unexecuted)

`hud.register_original_event_content(kind,mount,remaining_factory)` now registers
Attendance_All or Pass_All through `source_event_controller.gd` with the runtime
presenter. The existing source menu's request_menu -> prepared service model ->
strict source scene path therefore consumes concrete event model adapters.
The factory receives `(model,model_adapter)` and supplies the remaining original
node bindings. An explicitly requested pass_id/version_id is retained; a sole
available source identity can be selected without choosing an arbitrary first
record. Multiple identities still need their original selection controls.
The controller forwards service action_result without automatically confirming.
The known daily/promotion source tab buttons switch their actual ProjectNodes;
second-promotion version routing and decorative On/Off variants are not guessed.

`source_pass_model_adapter.gd` uses the public events service's actual
request.action fields. Original Btn_Buy_Common 16964 begins the selected pass's
pass_purchase/premium=false ref, and Btn_BuyPremium 13548 uses premium=true.
Original Mission_All receive button 7736 begins pass_quest_claim for its selected
quest. Missing offers use the original disabled renderer with no activation;
prices, entitlement and eligibility are not recomputed. Tier claimed markers
use the service's exact `<tier ID>:base|premium` keys. Original literal labels
remain source text. The supplied purchase branches have no unambiguous price
text nodes, so cost arrays remain available as original service data without
inventing a new price label or currency icon. Root claim-all 7352, dynamic list
placement and the original confirmation presentation remain incomplete.

`source_attendance_model_adapter.gd` binds source version/reward-index identities
to the service's existing progress key and claimed markers. Daily's stack-day
text reads that progress count. Daily/Promotion Btn_Close dismiss the session.
Special attendance purchase has no action in this ABI and remains disabled;
it is not reused as a claim control. Original Slot/SlotBonus buttons are
Button_Tooltip: they forward their exact row and server reward alternatives to
the existing tooltip handler, never begin a reward claim. A slot requires an
actual reward image reference and quantity binding, so source sample icons and
888 placeholders cannot be presented as its real reward. The actual source
claim presentation event still needs its matching original caller.

`hud.present_original_alchemy(pack,mount,remaining_bindings,selected_action)`
now configures and mounts the exact Alchemy_All root, binds the existing
PR265 equipment endpoint to that strict scene, and forwards its canonical
selected alchemy action. The host's existing preview_requested/commit_requested
handlers remain the sole service entry. A rejected new source contract preserves
the previous scene; successful replacement/close disables the old input.
Unknown quantity/recipe/material/result mappings are not supplied or hidden.

## Original bitmap text and existing image-owner consumption (unexecuted)

The supplied TextBMFont nodes can now consume their original text .fnt and page
PNG through source_pack.bitmap_font(), source_bitmap_font_data.gd and
source_bitmap_text.gd. Glyph rectangles, offsets, xAdvance, kerning, native line
height and final-glyph width come from the descriptor and retained Cocos
LabelTextFormatter code. Original page regions are displayed directly, with the
source widget transform and color cascade; no glyph image or substitute font is
created. The current subset requires fixed widget size, no flips, unpacked
channel-15 glyphs and a single BMP text line. Other formats remain explicit
failures. Attendance's original Text_day now receives its native reward index
through the existing set_bound_text path.

A Sprite/ImageView binding `{role:"source_asset",asset_ref:row_asset_reference}`
now calls PR270's existing `source523_source_ui_images.resolve(reference)` API.
The public contract read for this connection is
`da175ceb5696e061029512e4f203a77949f5ec9a`, file
`scripts/ui/source523_source_ui_images.gd` (blob
`23ae5eeabbf3909e8ddad875fb609caa92da078d`). Its owner validates AssetView,
AssetType, declared path, selected pack, bytes and source exclusions. The UI
retains original hierarchy, transforms, clipping and blend tracks. PNG pixels
receive the existing Cocos upload premultiplication; the original source files
are not changed. Missing owner API/pack/assets fail without using the CSB sample
as replacement. Explicit owner source_dummy_excluded results omit only those
pixels while retaining original nodes/records; they are not usage successes.
No ItemClass, reward, transaction or image-pack implementation is copied.

These are code connections only, not newly observed game actions or pixels.
No new test, render, audit, quality run or CI was executed. The previous
524/560 dependency and 317/560 inspection checkpoints remain unchanged; there
is no updated full-screen completion numerator or 95% actual-use claim.

## Main gameplay priority (unexecuted)

Attendance and season pass work is preserved and deferred by the latest user
instruction. Main gameplay is now the active priority.

`renewal_hud.update_player(...)` forwards the existing World HP/MP/level/EXP/
threshold/gold snapshot to `source_main_hud.gd`. The first concrete mounted
component is the original `UI/Main/Hud_ExpBar.csb`. Its bar and percent text use
the same existing HUD presentation formula; no experience progression, reward
or save logic changes. Repeated HP-only updates do not rebuild unchanged EXP
text. Original hidden milestone reward controls remain unavailable because no
matching current-game action is supplied; they are not assigned another action.

MainScene's original root design extent is 1200 x 675. Its exact ProjectNode
23080 supplies EXP's placement/properties. `configure_project()` reads that
parent reference instead of applying renewal layout coordinates. One outer
viewport fit preserves source coordinates and letterboxes a different aspect
ratio. This adapter policy has not been validated as the original client's
window-resize policy. It does not rearrange individual source nodes.

The private pack builder's optional `--layout-source UI/MainScene.csb` retains
that original file and read-only parent geometry separately from activated
entry scenes. It does not claim the parent's other referenced scenes have
resolved dependencies or have been used. The runtime accepts this geometry only
with its original file identity; it remains separate from scene registration.

The existing HUD now reads an explicit original UI selection on game startup:
`--source-ui=<private-pack-directory>` together with
`--source-ui-sha256=<manifest-sha256>`, or `TWILIGHT_SOURCE_UI` and
`TWILIGHT_SOURCE_UI_SHA256`. `hud.bind_original_main_ui(pack)` is the direct
existing-game entry for an already opened pack. An accepted original EXP
presentation replaces only the prior EXP gauge/readout; a rejected replacement
preserves the previous accepted presentation. Source packs, images, saves and
other source selections are not written by this adapter.

`source_main_combat_bindings.gd` connects exact original attack/auto controls to
existing HUD signals and World handlers. The actual Hud_AttackPad additionally
connects native target/self controls; existing auto/self state updates their
original effects. Pickup remains distinct: the current game requires an exact
selected ground-drop node and supplies no generic HUD pickup signal, so automatic
loot is not substituted. `source_main_menu_bindings.gd` maps the original
inventory/skill/store controls to existing game entry points. These combat/menu
bindings still require their remaining original controls/data to mount in strict
mode; no full main HUD completion is claimed.

The main EXP runtime pack was assembled from already held originals with one
entry scene and eight original files, including MainScene as geometry only.
Its builder result is dependencies-resolved/not-rendered. This is packaging for
the game consumer, not a new test or a game-consumption observation. No game
boot, test, verification suite, render, quality assessment or CI was executed.
Fixed inventory denominators and prior checkpoint counts remain unchanged.

### Main HP/MP node scope — unexecuted

The existing update_player path also forwards raw hp/max_hp/mp/max_mp into the
original CharInfo bars/text. Its actual parent is UI/HUDScene.csb, ProjectNode
1800, using the same serialized 1200 x 675 coordinate basis. Original status
and inventory hit controls delegate to existing HUD entry points; their returned
acknowledgement is distinct from transaction success.

This is an explicitly partial source-node scope, not full Hud_CharInfo or
HUDScene completion. Selected original offsets are 46576 (base background),
40620/37172 (HP bar/text), 35464/35528 (MP bar/text), and 20552/20060 (status and
inventory controls). Their unchanged ancestor chain/order/transforms remain.
Other original nodes remain in the full read-only source metadata and raw CSB.
In particular, clipping node 37544 contains customProperty clipping=0.5; this
value is not interpreted as HP progress. Its meaning, HP trail timing, poison,
weight, lawful and other stat roles remain unresolved rather than fabricated.

The private builder can package an explicit `--node-scene member:offset,offset`
scope alongside entry scenes. `source_node_scope.gd` selects only those original
nodes plus ancestors and retains only their original action-tag tracks, with
unchanged clips/frame values. It authors no geometry, nodes, textures or timing.
The tree is marked `_partial_source_scene` with exact selected offsets. Ordinary
whole-scene configure refuses such a scoped pack; configure_nodes or the explicit
configure_project node-scope argument is required. No scoped member is counted
as a wholly connected file or its full original bytes as actual gameplay use.

The native vitals package contains one EXP entry and a partial CharInfo scope,
12 original files and separate MainScene/HUDScene/full CharInfo source metadata.
It is dependency-resolved/not-rendered. Pack assembly and delivery metadata do
not replace a game run. No new test, render, quality assessment or CI was run;
these code paths and viewport behavior remain unexecuted and unverified.
