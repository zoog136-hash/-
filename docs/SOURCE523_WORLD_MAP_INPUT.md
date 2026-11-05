# Original world-map cell and movement consumer

This post-merge follow-up uses main `63a85a7314aea705872b76df34cfcf89c5b54a3e`.
Merged PR222's collision, Aden return, always-open and SPR decisions are retained.
No original image, UI node, source row, asset pack or save is included here.
The changes are **unexecuted and unverified**. No tests, game execution, render,
integrity checker, quality audit or CI were run under the current instruction.

## Existing game call chain

At normal World startup, the deferred map registration reads the optional private
`user://current523_world_map.cfg`. It opens the relation through PR270's existing
adapter and registers `hud.bind_original_world_map(adapter, context, input)`.
The existing map button/hotkey opens UI267's original presenter. Its existing row
buttons explicitly select the offered World. A real Scroll44388 tap invokes
`submit_world_image_click`; the HUD's emitted original pixel payload is consumed
by the map controller, projected to source components, and sent through the
existing field `point_clear`, World `find_world_path` and player
`set_manual_click_path` APIs. No NPC click dispatch, teleport, fee, item or save
transaction is added by a map image click.

The caller can alternatively use
`world.bind_current523_world_map(opened_image_adapter, offered_worlds, options)`.
`options.contract_sha256` must identify that opened private relation. The map
owner neither duplicates the image loader nor configures an old card/monster
pack. Original UI/image packs retain their existing owners' installation and
selection contracts.

## Private selection

The configuration's `[world_map]` section accepts:

- `enabled`: explicit selection, default false.
- `contract_path`, `contract_sha256`: existing private relation file and its pin.
- `offered_worlds`: dictionary keyed by the exact decimal `Land.ID`; each value
  has an explicit `world_id` in `UIMapWorld.ID` and optionally the actual `label`.
  Without a supplied label, only that exact source World's `Name` is used.
- `coordinate_policy`: `OWN_SOURCE_CELL_CENTER_FIELD_RATIO_V1` by default.
- `ratio_scale`: positive OWN multiplier, default 1.0.
- `source_anchor_offset`: OWN source-cell anchor, default `[0.5, 0.5]`.

No offer is inferred from Land's numeric ID or a first candidate, even if only
one World matches. Zero/missing image declarations are not made selectable.
Opening presents the original row; it does not select or display its image.
Absent configuration leaves this optional integration unselected. Missing owner
modules or invalid private selections return a status without changing the
current field, old images, packs or saves.

## Explicit OWN coordinate registration

The original relation supplies `Ratio`, `BaseLocX/Y`, `BasePixelX/Y`. Neither the
relation nor UI267 supplies their native axes/units/formula. A bounded primary
public search for the exact ImageInfo/anchor fields returned no formula. The
following is a configurable TWILIGHT interpretation, not original M evidence:

```text
R = source Ratio * own ratio_scale
D = (intrinsic texture pixel - source BasePixel) * R
source components = source BaseLoc + own source_anchor_offset
                    + inverse(current field basis) * D
world target = existing field coordinates.components_to_world(source components)
```

The basis is the current already configured OWN field's `basis_x/basis_y`.
Image axes are assumed to follow that field's canvas axes; Ratio is interpreted
as field canvas units per image pixel, and BaseLoc as a cell-center anchor by
default. Raw source values, original pixels, display transforms and source
coordinates are not rewritten. Returned metadata and the existing HUD message
identify OWN behavior. Degenerate bases, nonpositive Ratio, nonfinite/outside
pixels and unsupported policies are rejected. No nearest-cell snapping or
image stretching fills a registration error.

## Existing input and movement ownership

`OWN_EXISTING_WORLD_TAP10PX_PAN_V1` reuses the existing world input's 10-pixel tap
threshold. Native input-control transforms convert actual drag deltas to the
existing Cocos source scroll position; `set_scroll_position` remains the UI
owner. Drag and tap are separate outcomes. Canceled touches, focus loss and
viewport changes discard pending input. Emulated duplicate events are ignored.

Each actual press holds the source session, field/renderer/physics/provider,
definition generation, source/geometry/coordinate identity, selected original
image/pack, current actor position and existing manual/loot/selection intent.
New map opens, changed contexts and stale releases cannot authorize movement.
An accepted destination must have an exact supported path endpoint. A current
blocked/outside/unreachable destination cancels the previous manual intent;
stale and actor-state failures preserve it. Existing movement status locks and
collision stay active. The click changes neither map admission nor portal,
return, always-open, fee or save semantics.

## Exact integration dependency

Owner versions read for this connection:

- UI267 caller `44a3f960a8c185d1f2cdc9878dfa4b2e6147aa05`; its later
  `82469106f7974c600afdf4a3400433ecf9eb4ba5` retains the same field type guard.
- Image270 adapter `69808a0a4d85b13617935a68faf3c9d74d3e587e` and its private
  relation contract, already held in the consumer environment.

**UI267 must accept the actual field object in `source_main_world_map.open()`.**
Its current guard requires `field_map is Node`. Actual `current523_source_field`
inherits `PlayableField extends RefCounted`; it is not a scene Node. The rest of
the supplied image/presenter ABI uses Object/WeakRef-compatible field access.
The map caller supplies the actual RefCounted, not a fabricated Node proxy.
The UI owner needs to relax that one guard to accept this real field type.
Until that change and both owner modules/private selections are integrated,
the normal original-map opening path remains blocked. This branch does not
copy another owner's unmerged files or modify the merged222 branch.

After integration, actual open, explicit row selection, click/drag, supported
and blocked movement, stale/close/reopen input and existing save/reentry flows
remain unverified under the user's present execution ban. Source95% usage,
original coordinate equivalence and whole-map completion are not claimed.
The existing 229 placements, eleven SPR IDs and explicit dummy exclusions remain
unchanged; sound and other user exclusions remain unchanged.
