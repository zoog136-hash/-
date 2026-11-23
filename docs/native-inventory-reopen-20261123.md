# Original inventory open/reopen budget

The 523.824 Android sample attributed 465 ms of a 1,669 ms frame to `ui.inventory_stage`. This work does not attribute or claim to fix the rest of that frame. New counters distinguish whole native/fallback opening from authored scene staging, retained-panel reopen and dirty-row refresh.

- A native open no longer constructs the fallback inventory's slot nodes and icons first. A rejected original route still calls the old fallback open.
- One original native shell and its bounded virtual rows can remain hidden for up to five seconds (at most 80 mounted item hits). Its processing, hit testing and item actions are disabled. Expiry, backgrounding, icon/pack refresh, changed branch (4/8), and controller replacement release it. It follows the existing first-open source clip and scroll starting position when reused.
- An unchanged owner revision skips rebuilding the whole owner list; dirty counts/selection over the same layout patch mounted slots after validation. Search, reorder, or physical identity changes that alter the layout still stage a fresh original tree before showing it. Pack, item icon and asset replacements invalidate the prior visual key. Explicit ownership/selection/use checks always use the current owner, never cached hits.
- A cold or dirty owner model can hand its just-built entries to the original view instead of enumerating them a second time. Chrome-only refresh does not copy complete ownership and legacy row structures.

Use Godot 4.7.2 after project import:

```sh
godot --headless --path . --script res://tests/source_inventory_reopen_test.gd
godot --headless --path . --script res://tests/source_inventory_virtual_rows_test.gd
```

The first script verifies real cache, chrome bindings, per-slot updates and current reference guards on a fixture with synthetic initial scene construction (no original asset images). It reports first open, warm reopen and one-row refresh separately; elapsed times are not assertions. The second can check the actual native CSBs and mount cost with the installed original pack by setting `TWILIGHT_SOURCE_UI_PACK` to its root containing `source523_addons.json`. There is no private pack or Android measurement on the available executor.
