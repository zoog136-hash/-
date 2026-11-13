# Stop dispatching inactive source UI clocks

## Scope and evidence

`original_ui/sprite_scene.gd` defines `_process` for every instantiated source scene. Before this change, static scenes and completed/stopped clips still received that callback and immediately returned. This includes nested source projects and item/icon scenes; no claim is made about the number resident on a particular Android device.

The playback flag now controls Godot process registration. `_ready` applies the flag after Godot's automatic script callback registration. Every existing write to the flag uses the same setter, including parent `ActionValue` tracks, explicit stop, natural completion and texture failure. Nodes, textures, authored frame state and events remain owned by their existing instances. Hidden **playing** scenes continue running; visibility does not suppress their clocks. Manual seek still works while stopped. No resources, image fidelity, save data, movement or combat behavior are changed.

Running source UI animation callbacks also receive an exclusive `ui_animation` hitch section (UI 애니메이션). Nested registered work is subtracted with the existing `add_self` contract. This attributes CPU wall time spent in the callback, not GPU work, rendering completion or every possible UI input/deferred callback. Existing thresholds and raw intervals are unchanged.

## Reproduction and results

`tests/source_ui_process_lifecycle_test.gd` instruments the actual renderer and reconstructs the old callback-registration behavior in memory. Under official Godot 4.7.2 on Linux, two groups of 128 static scenes over eight engine frames received **1,024 old callbacks versus zero candidate callbacks**. This is a dispatch-count result, not a frame-time, memory or Android speedup claim.

279 lifecycle assertions passed, covering play before/after tree entry, stop, manual seek, missing clip, terminal and looping frames, hidden playback, re-entry, all three nested action types, callback cancellation, texture failure and exclusive nested hitch accounting. The accounting test deliberately injects small waits and backdates a synthetic frame; its durations are not gameplay measurements.

Existing timeline selection equivalence: 1,773 checks across 196 comparisons. Existing hitch diagnostics: 205 + 26 checks. Headless material behavior: 27 checks. Software OpenGL regression: all seven groups passed, including source compositor 152 rendered cases, preview 12, lobby 8, UI copy policy 120 pixel comparisons, map layers 36, uniform display 24 and map refresh 24. These synthetic scenes do not establish real original-pack or Android fidelity. Python staging: 14 tests. Resource policy's historical `tools/check_resource_integrity.py` is absent in current main; the available `tools/check_no_legacy_resources.py --root .` passes for 20 tracked resources. This does not establish complete original-resource delivery.

The reported 523.435 photograph's 10,626 ms remainder remains unexplained. It is not evidence that inactive callbacks caused that stall. New Android records after deployment are required to determine the relative cost of active UI animation, process tail, drawing and other unregistered work. No Android device, original full UI pack or GPU measurement is available here. Original Android/Windows and XP Hero static observations remain architectural references, not performance baselines; no behavior or native timings are copied from those reports.
