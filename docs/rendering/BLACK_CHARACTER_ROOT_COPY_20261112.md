# Black source-character regression: root Window copy coordinates

Base main: `4fffefd09bd6c3973b2e064a96945e4b1972b3d7`.
Branch: `feature/black-character-regression-20261112`. Draft PR #432.

## Finding

A source compositor regression is reproduced in actual Godot 4.7.2 Compatibility
OpenGL pixels when the root Window uses the game's `canvas_items / keep`
letterboxing. The bounded background copy included the Window's final
letterbox/blit transform, while the shader reads the render target before that
blit. The copy therefore missed the source sprite's framebuffer pixels.

The incorrect expression was introduced in `bb166f49a7` in PR #418 and remains
in latest main. The later attachment ownership/own104/instance changes and packed
SP2 pixel optimization do not correct this coordinate boundary. Their policies
and resources are preserved.

The original source for the engine establishes the boundary:

- [Window::_update_viewport_size and Window::get_final_transform, 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/window.cpp#L1222):
  the final Window transform includes the letterbox margin and, for viewport
  mode, the final presentation scale.
- [CanvasItem::get_viewport_transform, 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/canvas_item.cpp#L1509)
  uses that final transform. It is unsuitable as a render-target copy transform.
- [Viewport::get_final_transform, 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/viewport.cpp#L1287)
  distinguishes stretch/global canvas from Window presentation.

## Pixel evidence

The definitive reduced regression uses procedural test texels, not replacement art:

| State | Window | Render target | Copy origin | Covered black shadow over white |
|---|---|---|---|---|
| Unchanged main compositor | 1024×460 | 817×460 | (512,230) | (0,0,0,1), incorrect |
| Corrected compositor | 1024×460 | 817×460 | (408,230) | RGB565 0x7BEF, correct |

The framebuffer sample is (418,240); the 104-pixel displacement is exactly the
Window's horizontal margin. Camera-only movement reproduces and fixes the same
error without changing source-frame geometry.

- [Failing baseline, corrected in-bounds sample, commit 1d8a0704](https://github.com/zoog136-hash/-/actions/runs/43202874350):
  130 GPU cases, exactly the two root-window cases fail; actual source pixels
  are black. An earlier diagnostic revision sampled outside the 2×2 fixture;
  it is not the basis for the finding.
- [Passing production fix, commit c660317b](https://github.com/zoog136-hash/-/actions/runs/43203037166):
  same 130 GPU cases, 22,751 checks, zero errors; both source samples equal
  the expected RGB565 average.

This establishes a real renderer defect using synthetic regression inputs.
Android GPU and any particular installed actor bank remain unverified.

## Change and preservation

Compose the render-target transform directly from viewport stretch, global canvas,
the sprite's canvas (including CanvasLayer), and its global transform. Continue
rounding outward, clipping to the framebuffer, cancelling the inherited copy
transform and refreshing before each draw. Copies remain sprite-sized and ordered
immediately before their existing source draw.

No source layer is deleted or reordered. No palette, alpha coverage, decoder,
texture cache, original resource, character choice, frame, scale, combat or save
format changes. The existing shader's alpha discard, source modulation and
RGB565 average/screen/multiply equations remain byte-for-byte unchanged.
Shader SHA256 remains
`02295e0fdd4307aa56193aec3729b43dcac7848d46b572e0dc55733d1fc6db11`.
Screen and multiply still discard the sixth green bit by their existing static
compatibility rule. This fix concerns the destination sampling coordinates,
not a newly inferred native blend formula.

Final pixel regression covers separate shadow/body/clothes Z order, camera motion,
horizontal and vertical letterboxing, equal-aspect canvas expansion, viewport
presentation, all three kernels and a nonidentity global canvas transform.
Prior SubViewport/camera/stretch/reparent/reset/coverage cases remain enabled.

## Validation boundary

Local Godot 4.7.2 baseline: compositor 22,617 checks, production attachment
projection 21 checks, packed frame renderer differential 2,775 checks, zero errors.
These headless checks have zero GPU pixel cases; GPU results above are from Mesa
llvmpipe CI. Local display connection was unavailable and is not counted as a
render pass. Final commit CI is recorded in the PR.

Repository AGENTS.md, project rules and resource policy were read before edits.
Checkout and parent .agents directories have no applicable skill files.
The historical `tools/check_resource_integrity.py` no longer exists on latest
main; the current `tools/check_no_legacy_resources.py` passes (tracked=20), and
the current required resource workflow is used. No original-art integration,
redistribution or pack delivery is claimed. The existing static blend compatibility assumptions are unchanged; they are
not Android or native523 visual proof.

Only code, procedural tests and this engine-coordinate explanation belong to
this change. Private images, their identifying metadata and original resources
are excluded.
No merge is authorized or performed.
