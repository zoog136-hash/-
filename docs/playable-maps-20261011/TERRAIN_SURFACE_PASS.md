# Common terrain surface pass

Continue from PR #84 commit `ffccc82fbb0f550ec08291668239f0a0b68e158b`.
The previous connected road meshes, map data, collisions, props and authored
atlases are preserved. This pass changes the common terrain rendering used by
all 25 entries in the existing map data: Aden, Oman 1–10, Domination Summit,
Escaros 1–5, Albino 1–4 and Faith 1–4.

## Implementation

- Reuse the existing 16-material authored atlas. Three continuous texture
  phases on a triangular lattice reduce the large mirrored tile repetitions.
  Sharpened blend weights retain leaf, gravel and masonry detail.
- Use finer organic grain, larger masonry blocks and stable per-map weathering.
- Replace the ground shader's two fixed forest ellipses for these maps with
  the existing map-wide biome system, now using domain-warped boundary weights.
- Use a 256-unit indexed terrain grid. Shared positions and noise evaluations
  provide finer boundary interpolation without duplicating triangle vertices.
- Give regional overlay materials continuous edge variation and preserve their
  runtime classic/TWILIGHT palette switching.

No new commercial textures or map layouts are imported. Existing family material
profiles remain authoritative. These procedural surface changes are not a
reconstruction of exact Lineage M coordinates or a completed environment pass.
Town courtyard footprints, several simplified terrain/room shapes, density,
architecture and reference fidelity still require subsequent work.

## Reproducible validation

Local Godot 4.6.3 geometry verification passes 377 assertions across 25 maps;
the previous road geometry passes 321 assertions. Shader parameter reflection,
Python compilation and workflow YAML/shell parsing pass locally. Actual OpenGL
compilation and viewport acceptance are performed by the PR84 GitHub workflow.

`terrain_surface_render_test.gd` captures the actual Main scene at three existing
region centers in each map. The baseline and current revision use the same test,
camera positions and zoom values. HUD and moving actors are hidden to expose
the ground. Movement, portals, UI and collision are verified separately with
the existing tests. Water animation time can differ between captures.

`build_terrain_surface_evidence.py` verifies all 75 camera pairs, records hashes,
creates contact sheets and a slider review, and calculates the union of sampled
camera rectangles. This sampled area is **not** a map completion percentage.
Original-layout fidelity and overall visual quality remain unscored until
reviewed. Timing and memory measurements from software OpenGL are observations
from one CI runner, not mobile performance acceptance.

The complete test runner keeps logic tests headless and uses the real display
for tests awaiting `frame_post_draw`. It accepts explicit successful structured
result reports as well as `_OK` markers, while retaining exit-code, error and
failure checks. The complete regression step is required, not diagnostic-only.

Workflow artifacts separate before/after images, review files and validation
logs to stay within the workspace's 32 MiB per-file transfer limit. Inspect the
workflow for the exact current commit; do not treat this document as a claim
that an unexecuted run has passed.

## Resume

Recheck PR #84 HEAD and its matching workflow results. Review the 25-map contact
sheets and representative close views before changing assets. Resolve any
rendering or gameplay regression, then address simplified map footprints and
regional composition using available reference evidence. Do not repeat source
archive downloads already verified in the source handoff.
