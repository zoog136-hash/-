# Catalog first-open budget

The Android trace from build 523.824 logged 2,886 ms under one `ui.catalog_open` label. The label did not identify the category or UI route. It also did not measure the separate inventory view. The next trace uses bounded category/route labels: e.g. `ui.catalog_open.item.browser` or `ui.catalog_open.transform.native`.

- Original Change_WinTotal: keep all filtered card identities and the existing list extent, selection and authored coordinates. Mount scenes only for visible rows plus overscan; retain overlapping nodes during scroll. Keep the pressed row's initial viewport alive until touch release so the original input router does not lose the captured checkbox. Offscreen cards are not evicted during the GUI callback itself.
- Fallback browser: restore the last query, grade, page and selected source ID before binding. This replaces the refresh of an unfiltered first page, the refresh of a filtered first page and the mount of the restored page with one filtered mount. An empty query no longer constructs a searchable string for every candidate. Obsolete asynchronous icon fill and scroll callbacks cannot write into a newer page.
- No source asset replacement, ownership or equip/save change. The original UI pack is still required for device confirmation of the visual route.

Run from the checkout after project import:

```sh
godot --headless --path . --script res://tests/original_ui_change_window_test.gd
godot --headless --path . --script res://tests/catalog_open_budget_test.gd
```

The fallback benchmark uses the real Main scene with a 33,258-row synthetic item catalog and no icon resource pack. It cannot predict Android p95. The native regression checks viewport allocation, original row positioning behavior, scroll cancellation/preservation and identity retention with synthetic node fixtures. Use the first command with `-- --pack=<installed-original-UI-pack>` to also check original assets on an authorized executor.
