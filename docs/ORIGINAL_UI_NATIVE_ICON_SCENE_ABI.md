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
