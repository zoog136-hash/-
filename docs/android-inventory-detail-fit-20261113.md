# Remove repeated class-list preparation in inventory details

Based on main `02504f9f02e6fc3257967b271c34c7989001440c`, including #474 loading changes and #476 bitmap-font lookup optimization. Original assets and game/save ownership remain unchanged.

## Observed code path

The native HUD calls `source_main_inventory_lock_view.refresh` for the visible inventory detail. With the original optional class-list nodes in scope, refresh called `_fitting_class_text` before checking whether its native view was already mounted, then `_apply` called the same function again. Each fit retrieves `pack.scene(ToolTip_HudType_Right.csb)`, recursively finds offset 40580, gets its FontFile and measures the string. Baked source-pack scene retrieval decodes a record with `get_var`; the unbaked path duplicates its manifest tree. An empty class string still paid both lookups and returned an empty string.

The warm mounted-view path now fits once in `_apply`. Initial construction still fits for its initial text binding, and still fits the fresh post-mount owner model independently. Empty text returns empty immediately: none of the prior lookup outcomes could add visible text to that input. Nonempty strings continue to read the current source options/font and measure on every refresh; no result cache or source identity/mtime shortcut is introduced. Overlong class lists remain completely hidden rather than truncated.

`ui.inventory_class_fit` is a fixed-name inclusive diagnostic for fitting attempts. It is not an independent top-level frame cost and must not be added to the enclosing HUD measurement. Page/font loading and source construction validation outside this empty-fit decision remain unchanged.

## Validation

Godot 4.7.2 new regression: **138 checks passed**. It compiles the previous refresh routing into a test-only oracle and exercises the actual new view configuration, owner model, refresh, `_apply`, lock action and close action. It uses a real FontFile for measurement. Pack records, the already-mounted scene setters and bag owner are synthetic; it does not claim full original CSB mounting or Android rendering.

| Synthetic mounted detail | Refreshes | Previous scene reads / font lookups | New scene reads / font lookups |
| --- | ---: | ---: | ---: |
| Empty class text | 12 | 24 / 24 | 0 / 0 |
| Fitting nonempty text | 12 | 24 / 24 | 12 / 12 |
| Overlong nonempty text | 12 | 24 / 24 | 12 / 12 |

Each comparison checks return values, displayed strings/visibility/button state and physical selection/lock ownership. The test also changes source width, font availability and nonempty text between refreshes to prove live reevaluation; it checks no-class scope, hidden/non-detail owner, invalid parent, rejected text binding, disabled action, changed selection and detail close. Refresh never performs a lock transaction. Explicit activation still calls the existing owner once, and invalid/stale presentations retire as before.

These are verified operation counts on synthetic owners, not Android timing/RSS results or a measured size of the original tooltip scene. The production source lookup path is a static explanation of what each eliminated call would have done.

Twelve final focused suites passed after integrating main `02504f9`: the new regression, inventory header/selection/snapshot, bitmap font lookup/update/reuse, pack-memory/menu-retirement, frame logging, equipment-binding fusion and actual Main save/reload. The first combination with #476 also passed eleven focused suites. Main covers available absent-install handling, not full original private-pack gameplay. Python staging: 14 passed. Clean Godot import and `NO_LEGACY_RESOURCES ok tracked=20` passed. The historical `check_resource_integrity.py` and delivery ledger are still absent in current main; its attempted invocation reports file-not-found. No resource files were added or changed.

Private executor evidence: `/workspace/twilight-inventory-detail-fit-validation/`, including initial `class-fit.log` and the final `final/headless-summary.json`, `final/import.log`, per-suite logs and `final-stage/` project. The new suite is registered in `tools/ci_core.py`; the final PR head's checks establish integrated remote status.

## Reference and device limits

Original Windows cache evidence (`01C74AB0` hit without parser/reader and retained Graphics ownership) and Android cache/read/parse separation remain useful static references for avoiding repeated preparation. Neither establishes this Godot class-list algorithm or a native benchmark. XP Hero metadata does not prove its scheduling or frame costs. This change follows the actual TWILIGHT owner and source-text contract.

There is no new Android device trace. The previously verified photo's 523.445 execution had a 9,213 ms frame and an 8,949 ms post-callback interval. We cannot attribute that gap to this detail window, GPU, GC, teardown or any single engine stage. The new timer permits checking this path in a future matching frame record. Initial full detail construction, nonempty source lookup once per refresh, text setters, and the other scene/node/texture costs remain; no blanket lag/crash-resolution claim is made.
