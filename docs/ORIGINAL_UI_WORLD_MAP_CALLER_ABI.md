# Original world-map UI caller ABI (unexecuted)

PR267 owns these original nodes/presentation/input registration. Existing
PR270 map images and the map owner's coordinate/movement logic remain their
owners'. No new image, template, view layout or map projection is introduced.

## Actual game entry

With the explicit original UI pack already selected, register the existing
opened image adapter and existing map caller on `renewal_hud`:

```gdscript
hud.bind_original_world_map(image_adapter, context_provider, input_handler)
```

`image_adapter` is the existing PR270 object exposing `world_candidates` and
`apply_field_world`; its owner opens its original relation/image contract.
This UI does not create another adapter or open an old card/monster pack.
Registration before the deferred main HUD selection is retained for that bind.

The existing `World -> hud.map_pressed -> hud.toggle_map()` and map hotkey entry
now use the original map presenter when this registration exists. The original
close button and existing Escape handling close it; another existing window
also closes it. No minimap Size/Point/On/Off button is repurposed as map-open.

`context_provider()` returns existing source data, not guessed numeric joins:

```gdscript
{
    "field_map": current_original_field_node,
    "offered_world_id": exact_world_id, # int, UIMapWorld.ID namespace
    "world_label": existing_localized_label,
    "role_declaration": {
        "member": "UI/Map/Map_Tab_Area.csb",
        "sha256": "709e406c6a67199fcec3b998f5ac032ce833ad0ea79e3981327dadea689ffd84",
        "node_offset": 44440,
        "world_image_display": true
    }
}
```

The original authored row offers that World; opening the map does **not**
select it. Buttons7440/4508 select the offered ID, rechecking exactly one
matching current `world_candidates` entry with `world_namespace=UIMapWorld.ID`.
No first-candidate/Map.ID/Land.ID substitution occurs. No extra list rows or
page positions are manufactured. The caller supplies the actual label.

The role declaration is the caller's explicit binding of an original image
node to this game's World-image operation. The source node's editor image is
`UI_Draft/V_talkingisland.png`; it is **not** evidence that it equals a World
asset such as `Image/Map/W_talkingisland.png`. Without this declaration, the
real selection is recorded but the image remains unavailable/hidden.

## Native input and pixel registration

`input_handler(event, context)` receives the actual original Scroll44388 GUI
event. `context.map_ui` is the existing source presenter. For mouse/touch/drag
events, context also contains:

- `event_space`: `original_scroll_input_control_local`.
- `viewport_point`: the actual input control's canvas transform applied to its
  local event position.
- `world_image_pixel`: the result of the native Sprite pixel conversion, or
  an explicit error before a real World image has been displayed.

The existing input owner decides click/drag/release and movement. The UI does
not add drag thresholds, pan physics, bounce, inertia or an automatic click.
That owner can use these real presenter methods:

```text
image_pixel_at(viewport_point: Vector2) -> Dictionary
submit_world_image_click(viewport_point: Vector2, actual_event_metadata: Dictionary={}) -> Dictionary
set_scroll_position(source_position: Vector2) -> Dictionary
scroll_geometry() -> Dictionary
select_offered_world(world_id: int, source_cell: Variant=null) -> Dictionary
```

`select_offered_world` is an explicit caller operation, restricted to the
currently presented offer. Open never calls it. Native row buttons use the
same existing image operation after an actual selection.

`image_pixel_at` uses the final native Sprite2D's
`get_global_transform_with_canvas().affine_inverse()` and actual texture rect,
centered/offset/flip fields. It rejects missing/hidden/stale images, out-of-bounds
points, regions, animation frames, mismatched textures and points outside the
actual source scroll viewport/ancestor clips. Inspection scenes cannot bind as
this game presenter. `raw_pixel` means
continuous intrinsic texture-edge coordinates: top-left origin, +X right,
+Y down, before display flips. A flipped edge can equal width/height; no
clamping or texel-center convention is guessed. Successful raw conversion
sets `native_texture_pixel_registration_complete:true`; ImageInfo/cell
registration still remains with the map owner.

Submitting a real click emits `hud.original_world_map_image_clicked(payload)`.
The payload includes World namespace/ID, raw/display pixel, final texture size,
native UI identity, original `source_world`, original `source_image_info`, and
the existing owner's verified image metadata. Ratio/BaseLocX/BaseLocY/
BasePixelX/BasePixelY are forwarded unchanged. The map owner must register their
axes/units/formula and perform any cell conversion/movement. The UI pixel
space is not asserted to equal those source field units.

## Exact original component identities

| Member | SHA256 | Native role |
| --- | --- | --- |
| UI/MapScene.csb | 52334e683d2691c1f4e623933c26e6ea5f94add6485b636ad47b92e02816eafb | Root72, Project132 |
| UI/Map/Map_All.csb | f3ed7282f1030de466fdb1c11335889e7d31218eafbed262642f5b84ca0bb46c | Close29552, Area Project31656 |
| UI/Map/Map_Tab_Area.csb | 709e406c6a67199fcec3b998f5ac032ce833ad0ea79e3981327dadea689ffd84 | Sprite44440, Scroll44388, row Project37316 |
| UI/Map/Map_List_Button.csb | a3d55dcab8f9385870916e6df5d1cd30b47f1da5417d60a764cbcffbe1e0f3f4 | Buttons7440/4508, labels7492/4560 |

MapScene has serialized 1200x675 design coordinates. Project132 supplies
position600,337.5 with white color/alpha255 and anchor0; animation clips are
empty. The existing main source coordinate carrier fits this same basis.
Source positions/sizes/anchors and node ancestry remain authored. World
overview31372/Sp_WorldMap17368 (`MapImg/WorldMap.png`) is separate and is not
replaced by the Area picture. No entire-map or whole-560 completion is claimed.

Low-level presenter consumers use `sprite_scene.configure_nodes` with the
`build_map_scene(...)` contract, then bind the actual nested renderer with
`root_scene.project_player([132,31656]).player`. `source_nodes[project_offset]`
is the native root Node2D, not the renderer. Row updates use
`area_scene.project_player([37316]).player` for the same reason.

## Runtime image slot and remaining inputs

The pack declares only Area44440 in `externally_bound_texture_nodes`. Its raw
CSB, node and editor reference remain intact, but its editor preview is not a
runtime required image or fallback. The renderer requires explicit
`{role:"source_asset_slot",visible:false}` and refuses visibility until the
existing owner returns actual original pixels. `set_bound_source_asset_result`
shares the existing PNG upload conversion, original blend/display color, and
native texture content-size/anchor update. It changes no guessed image-fit,
source node position/scale, World ratio or cell bounds.

The combined private producer result has 27 originals, EXP entry1, explicit
partial scopes11, blockers0, and status
`STATIC_DEPENDENCIES_RESOLVED_REQUIRES_IMAGE_OWNER`. That is not external image
receipt, actual gameplay use or render proof. The fixed 560-root/8303-file
denominators and prior counters are unchanged.

Still needed from the existing consumer: registration with the opened PR270
adapter, actual offered ID/label/role declaration, its input handler, actual
selected original image availability, cell/ImageInfo registration, and any
additional original candidate-list layout. Missing inputs are not filled with
new nodes, preview art or inferred formulas. All code here remains unexecuted
and unverified; no new tests, game run, render, audit or CI were performed.
