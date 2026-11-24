# Avoid repeating the native bag's chrome input work during open

Build 523.843 Android capture, retained frame 6982:
`ui.inventory_open.native` 1,126 ms; stage 1,028 ms; owner model 359 ms;
visible lines 409 ms; bindings 131 ms; authored tree 84 ms. The 302 ms
across 20 icon-owner calls overlaps those spans. This change affects **only
the chrome substep inside bindings and its post-pose header copies**. It is
not a fix for the owner-model, icon decode, overall 131 ms span, rendering,
or whole-frame 16 ms target.

The normal Inventory_All source is one pinned scene used for both layout
and active control admission. The previous chrome producer read it twice:
once for layout geometry and once for expand/search offsets. The new
producer reads it once and checks both exact controls in one traversal.
If the selected pack supplies separate layout geometry, the active scene
still exclusively determines whether expand/search are permitted. Mandatory
geometry offsets are checked for exact uniqueness and kept in the same
source-order traversal. No persistent tree or header cache is added.

The native view already obtains an independent complete model from the
slot producer. Its chrome configure/build/post-pose refresh just needs
category, selection, gold and capacity; they no longer deep-copy the
unused full rows. The public/default chrome APIs still return detached
full models. Owner filters, gestures, offsets, glyph/text sources, animation,
item selection, original asset validation and fallback remain unchanged.
The trace now includes `ui.inventory_chrome_bindings` for this substep.

## Verification

```sh
godot --headless --path . --script res://tests/source_inventory_chrome_stage_budget_test.gd -- --benchmark
godot --headless --path . --script res://tests/source_inventory_chrome_stage_budget_test.gd -- --main
```

Fixture geometry and decoded bytes are synthetic (not original art or an
installed Android pack). No images are generated or included. The Main
probe opens the real native view with Main's current bag owner; it reaches
the changed stage, checks the single chrome read, and confirms the absent
parent is rejected without opening a fallback prematurely. It does not
claim original-screen rendering without the private selected addon.

Matched Godot 4.7.2 Linux headless A/B/B/A/A/B, 13 builds per fixture in
each process. Median of the three per-process medians:

| Serialized synthetic fixture | Before | After |
| --- | ---: | ---: |
| 450 legacy rows and 180 two-node filler branches | 15.79 ms | 5.93 ms |
| Stress: 450 rows and 1,200 two-node filler branches | 111.72 ms | 45.74 ms |

Both fixture sizes produced exactly the same authored passive binding
signature across processes: `75f9a1c4e9a40b9cafcb3a11ead785a6e24ceaa133ce2fd9cc095a9bb62fee35`.
Each 13-build run decoded 26 scene values before, 13 after. The fixture tests
also check active callback identity and the allowable controls explicitly;
the hash omits bound object instance IDs, which change between processes.
Filler count is neither a measured production tree size nor per-frame work.
