# Native original CSB icon slots (unexecuted)

UI267 exposes a scene-consumption path for the actual Common_Slot15012 and
Slot_Skill18488 original Sprite nodes. PR270 retains canonical Item/Spell/Buff/
Guardian identity, source pack selection and original registration evidence.
No second image/CSB engine or new icon/host geometry is introduced.

## Image owner registration and request

The existing image owner registers once through:

```gdscript
hud.bind_original_icon_scene_provider(provider: Callable) -> Dictionary
```

The callable receives `(info: Dictionary, context: Dictionary)` when the existing
describe_item/describe_skill/describe_guardian_skill result has
route=source523_images and reason=unsupported_csb. `info` is that unchanged owner
descriptor/provenance. `context` retains the original owned reference or game
slot index and adds `source_slot_contract`: member, source_sha256,
manifest_sha256, node_offset, exact original widget options/blend and the
registration space authored_sprite_anchor. These are original fields, not a
fit/offset inferred from a TextureRect or placeholder picture.

The owner returns `{ok:true, descriptor:<below>}` only for the same canonical
source identity. Missing source registration or original repeat policy must
remain pending; setting a boolean without its actual source evidence is not a
completed original contract.

```text
descriptor:
  pack: the existing opened source_pack.gd instance for this CSB
  manifest_sha256: that pack's exact original_ui.json pin
  member: the original CSB member
  source_sha256: the exact original CSB hash
  bindings: optional existing strict source bindings
  registration:
    space: authored_sprite_anchor
    original_registration_confirmed: true
    source_basis: actual original registration evidence
    target:
      member: context.source_slot_contract.member
      source_sha256: context.source_slot_contract.source_sha256
      manifest_sha256: context.source_slot_contract.manifest_sha256
      node_offset: context.source_slot_contract.node_offset
  playback: optional explicit ORIGINAL policy only
    clip: exact unique original animationList name
    repeat: an original declared boolean
    original_repeat_declared: true
    original_policy_confirmed: true
```

The bounded scene path currently accepts only an original Node root with
position0/size0/anchor0/rotation0, scale1, no flips. Other original root types or
transforms need their exact registration contract; they are not resized or
centered. A missing playback declaration causes no added seek/play/loop: the
strict loader's serialized source state is stopped. A declared clip with an
unknown repeat is rejected. An estimated single-pass host policy from the
older TextureRect adapter is not silently accepted as original playback.

## Actual renderer boundary and lifetime

`sprite_scene.gd` exposes:

```text
static external_scene_slot_contract(pack, member, offset) -> Dictionary
set_bound_source_visual_result(offset, owner_result) -> Dictionary
set_bound_source_scene_result(offset, descriptor) -> Dictionary
bound_source_scene(offset) -> {ok, player, evidence}
clear_bound_source_scene(offset) -> Dictionary
```

`set_bound_source_visual_result` keeps the current Texture2D path or consumes
`owner_result.source_scene_descriptor`. Both native inventory and quickslot
staging now use it. `source_asset_scene.gd.prepare(descriptor)` reuses the
existing source_pack and strict sprite_scene.configure; it supplies no asset
joins, fallback pictures, source edits or replacement renderer.

A prepared source player is attached directly to the actual original Sprite
anchor Node2D after exact target registration. It is not attached to the editor
sample's bottom-left origin, stretched into its64x64 preview, or moved to a new
offset. The target and original identity root transforms remain unchanged;
original child sprites/frames/blends remain owned by that source player.
The hidden sample texture is cleared and never substituted. Native slots
accept the scene only after strict preparation; a missing contract preserves
the existing complete game view.

`bound_source_scene` exposes that actual player for its existing play/stop/
seek_frame/playback_status API; no new completed/loop signal is invented.
Replacing/clearing a scene stops/disables/removes/frees the old player. Closing
or rebuilding the native inventory/quickslot presenter frees its source child
hierarchy without changing the item/skill, ownership, effects or saves.
Re-registering the image provider refreshes active native consumers; it does
not overwrite source packs or cfg. Native CSB drag thumbnails are not supplied
by this contract; existing transfer identities/actions remain the same and no
fake snapshot is generated.

This publishes an implemented consumer contract, not proof that PR270 has
provided its per-icon original registration/repeat inputs or that a CSB icon
has executed in the game. Unknown source registration/repeat remains explicitly
pending. No new test, game run, render, audit or CI was performed.

## Rebuilding an unchanged native row

`reuse_bound_source_scene_from(offset, previous_renderer, previous_offset)` is
called only at the final native presenter commit for the same owned reference
or unchanged absolute quickslot. Identical source member/manifest/CSB hashes,
registration, source bindings and declared playback retain the actual existing
player instance. Quickslots also retain the same entry identity; AUTO is a
separate marker.
The temporary staged player is stopped/freed and the original instance moves
to the new original anchor node. The same player is kept, without an explicit
timeline restart or frame-state reconstruction; actual runtime preservation has
not been verified. No
new start/loop policy or frame-only reconstruction is inferred. A changed
source descriptor receives its newly prepared instance instead. This handoff
has not been executed or tested.

## UI-owned original target values for image270

These exact values are from the already retained current523 original component
records. UI267 owns this half of the registration; image270 need not invent or
reconstruct the slot placement from its selected icon scene.

| Field | Inventory | Quickslot |
| --- | --- | --- |
| Component | `UI/CommonUi/Common_Slot.csb` | `UI/MainFloating/Slot_Skill.csb` |
| Component SHA256 | `b0153e2324de4789e3a5f1d09030f370ed109583e893247656bee5affa3520d6` | `a2ef732cf9cee265b9dab0cee379ffab47fab6c2cc3b520d4d0cfd3eb3ad2c81` |
| Sprite offset/name | `15012 / Sp_IconSample` | `18488 / Sp_IconSample` |
| Original position, x-right/y-up | `(0,0)` | `(-0.5,1)` |
| Original anchor | `(0.5,0.5)` | `(0.5,0.5)` |
| Original size | `(64,64)` | `(64,64)` |
| Original scale / rotation / flips | `(1,1) / (0,0) / false,false` | `(1,1) / (0,0) / false,false` |
| Native local anchor position, y-down | `(0,0)` | `(-0.5,-1)` |
| Native preview content origin | `(-32,32)` | `(-32,32)` |
| Original Sprite blend | `(770,771)` | `(770,1)` |
| Original ancestor offsets | `Node220 -> Sprite15012` | `Node232 -> Nd_Skill_1:16896 -> Sprite18488` |

The Common_Slot root is position0/anchor0/size0/scale1/rotation0. The Slot_Skill
root has the same identity fields; its original Nd_Skill_1 has position
`(-0.0003000000142492354,0)`, anchor0/size0/scale1/rotation0. This small serialized
translation is preserved, not rounded away. Inventory slot-set and quickslot
page/project ancestors remain the actual original instances. Their transforms
are already applied by the UI player; an image owner must not apply them again.

The actual attachment parent is `slot_player.source_nodes[15012 or18488]`,
the authored Sprite anchor Node2D. It is not the preview content origin and
there is no64x64 fitting operation. The callback receives this original target
in `context.source_slot_contract`: its existing four target identity fields,
exact original_widget_options/blend, stable_component_target and
ui_attachment_frame are now supplied by UI267. Runtime manifest_sha256 is the
selected UI pack's pin (combined v6 is
`3e775a796e2d1d1e14775313e587f870d7d0773b03da9a18803a78c4afe63304`);
the component/hash/node tuple is separately stable across compositions.

Image270 e50c6abf owns the canonical selected CSB member/hash/opened pack,
original root declaration and any original clip/repeat declaration. UI267
owns the target point above, actual attachment, lifecycle and input. Neither
side needs to wait for the other's complete contract.

The remaining narrow relation is **selected CSB root origin -> authored Sprite
anchor**, expressed by actual original `registration.source_basis` and
original_registration_confirmed. The slot's source anchor, an identity CSB root
or a canonical AssetView path alone does not prove the original client's
cross-component relation. UI metadata therefore declares
ui_target_declared_by_original=true but
ui_attachment_frame.root_relation_to_csb_origin_confirmed=false. No confirmation
or relative offset is fabricated. Unknown repeat remains a separate per-scene
playback field. These inputs remain pending; this target declaration is not
proof of a rendered or game-consumed CSB icon.
