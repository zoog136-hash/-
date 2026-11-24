# Exact repeated source UI reads

Audit against main `ccd0b43a`: 155 GDScript files under
`scripts/ui/original_ui`. The search
`(layout_source|\.scene\(|_stage_trees|\.nodes_named\()` returned 106
lines in 33 files. In these call chains, only the same pack object, same
active member and one uninterrupted binding/geometry operation are shared.
This batch excludes Inventory_All chrome (#876).

| Binding phase | Verified former repeated active reads removed |
| --- | --- |
| Top menu | Up to three same-scene reads (layout fallback, weight label and background) become one; separate layout still stays separate. |
| Minimap | Zone and card-replacement project use one active record instead of two; no decode if neither is requested. |
| Shop | Root scope/touch and page scope/touch each use one record; category tabs borrow the same page record; each card's scope/touch share one read. |
| Card change window | Four mandatory Detail subtrees, optional sort/keypad subtrees, touch and grade-list geometry share the same record; grade rows share one read for their binding/placement geometry. Root scope/touch and type popup pairs share their exact record. |
| Quest list row | The touch owner and panel anchor geometry use one active row record. |
| Named/routine/domination tree | Repeated ProjectNodes may borrow one active member record, but generate separate chain/offset bindings per instance. |
| Routine/status lists | During a single fill, bound list sizes and placements borrow their exact source geometry; a second routine row bind with empty spec is unnecessary. |
| Help page open | Page count, wrap discovery and binding share the same help member, with a new scratch scope on subsequent page changes. |
| Combat/equipment | An absent active file is no longer read twice before the same missing-layout result. |

The temporary dictionary is bounded to eight member reads (same count as
the existing WindowKit stage memo). It never spans a frame, is not attached
to a mounted node, and is not used to render or to bypass source admission.
SpriteScene retains its independent scoped decode, partial-scope checks,
parent transforms, per-instance state and timeline validation. Separate
layout/active RAW members, parent/child members, later interactions, newly
selected packs, image/provenance checks and the existing scoped renderer
cache were not folded together. Unchanged geometry reads of previously
mounted rows in other windows remain independent; they aren't covered by a
global or persistent cache.

## Evidence and limits

```sh
godot --headless --path . --script res://tests/original_ui_stage_scene_reads_test.gd -- --benchmark
godot --headless --path . --script res://tests/original_ui_stage_scene_reads_test.gd -- --main
```

The test presents serialized synthetic node records to the real binders
and separately constructs both project instances with SpriteScene. It
checks independent bindings, fresh source on the next operation, exact
layout/active selection, and routes the menu/minimap contract through the
real Main owners. It does not display any received original art, generate
images, measure Android FPS, or establish a sub-16-ms frame.

Godot 4.7.2 Linux headless, same serialized child member referenced by 12
projects, 140 additional synthetic child nodes, nine binds in each of
four A/B/B/A processes. Median of per-process medians: **61.17 → 19.92 ms**
for the shared bind phase, 108 → 9 reads of the child member in each run
(root reads unchanged at nine). Passive authored scope and path/instance
binding digest `402c4f6bbbb2009d1c68be475ff2a910d6f23dce6281a0ad7750077b62b3b5b4`
matched the entire before/after block; separate checks cover real live
binding object/instance separation. This is not timing for every window
above or a device benchmark.
