# Copy only retained source animation tracks

Base: main `3fbfab95df3f5ef7beb3912a9e6591453601b4fd`, the approved merge of #473. That PR's exact head `c368ca9` passed core (203 unique `CORE_CHECK_OK` suites), resources, exchange and SP2 pixels before merge. Backup: `backup/main-before-pr473-20261113` at `7884db9`.

## Remaining work found in native UI construction

`source_main_inventory_view._stage_impl` constructs Inventory_All and each additional Inventory_Slot_Set row. `sprite_scene.configure_nodes` and nested ProjectNode construction call `source_node_scope.select`. This shared selector had already been optimized to avoid repeatedly copying pruned node descendants. However, it still deep-copied the complete top-level action, including every timeline's frame payloads, before discarding timelines whose tags were outside the selected nodes/ancestors.

This change moves that existing timeline filter before the deep copy. A shallow action copy keeps field order and metadata while its timeline array is projected. The final deep copy still detaches all retained tracks, frames, other action fields, clips and top-level metadata. Node selection, ancestors, order, source scope guards, duplicates/errors and the already optimized node-pruning path are unchanged. No shared scene cache or immutable-data assumption is added. Live scene/playback state remains per instance.

`ui.scene_scope` now measures the whole selector invocation, including failed selections. It is an inclusive diagnostic with call count and maximum call duration, not a new top-level frame section. It can overlap an inventory-stage/HUD cost and must not be added to those values.

This applies wherever the runtime selects a partial UI scene, including initial bag construction and structural refresh; it does not change full scene retrieval. In particular, baked `RecordFile.read` still decodes a scene record with `file.get_var()`, while an unbaked `source_pack.scene` still deep-copies its manifest entry. Record loading, actual node/texture construction and deletion remain potential costs and are not claimed to be fixed here.

## Regression and operation-count evidence

Godot 4.7.2 `source_scope_track_copies_test`: 147 checks passed. Test-only in-memory scripts run the actual old/new selector blocks and count the timeline/frame entries passed to the actual top-level deep copy. No production counters or timing threshold are injected.

| Synthetic input | Selected tracks | Previous copied timeline frames | New copied timeline frames |
| --- | ---: | ---: | ---: |
| 4 tracks × 64 frames | 1 | 256 | 64 |
| 32 tracks × 64 frames | 1 | 2,048 | 64 |
| 128 tracks × 64 frames | 1 | 8,192 | 64 |

These are synthetic input counts, not measurements of a particular original Inventory_All file, Android milliseconds, retained heap, RSS or GPU usage. The returned scene data is unchanged; the eliminated cost is temporary work on data the old result already discarded.

The regression compares complete serialized result bytes and errors, ancestor/root-only/multiple selections, request order, duplicate/missing nodes, unusual action shapes, duplicate action tags, retained metadata and packed-byte mutation isolation. It also builds two actual `sprite_scene` instances from previous/current projections, comparing source data, node order, transforms, visibility, alpha at six frame positions and independent playback state. That scene fixture uses synthetic Node records; it is not original CSB pixel validation.

Existing tests passed separately: scope 26, timeline selection 1,773, process lifecycle 279, inventory header 341 / selection 907 / snapshot 983, UI memory 210 / retirement 12, frame diagnostics 26 / draw phases 205 and actual Main save/reload 33. The Main run verifies the available absent-install handling; it is not a complete private-pack traversal. Python staging tests: 14 passed. Current tracked-resource guard: `NO_LEGACY_RESOURCES ok tracked=20`. Clean staging import succeeds. The older mandated `tools/check_resource_integrity.py` and resource-delivery ledger remain absent in current main; the attempted command reports file-not-found. No resources, source-pack identities, save format/data or game rules are changed.

Executor evidence: `/workspace/twilight-source-scope-validation/` contains `scope-final.log`, `focused.log`, `headless-summary.json`, import log and staged project. The new test is registered in `tools/ci_core.py`; the PR checks provide exact committed-head remote validation.

## Reference and device limits

Retained original Windows analysis traces raw-cache hit `01C74AB0` without reader/parser and completed Graphics ownership reuse after raw expiry; prior Android analysis similarly separates path/cache lookup, read/parse and decode/upload. Those static findings motivate avoiding repeated preparation but do not prove this particular source-scope algorithm or Android performance. This is a TWILIGHT-specific equivalent projection change. XP Hero metadata is structural cache/pool evidence only; its modified APK was not executed and Unity policies were not copied.

The verified 523.447 loading photo reports a previous 523.445 execution: 9,213 ms frame, 8,866 ms unmeasured, inclusive inventory stage 337 ms once, callback-after interval 8,949 ms. This patch does not attribute that gap to inventory, GPU, GC or engine waiting, nor demonstrate that it resolves the gap. No Android device, matching full hitch JSON/logcat/Perfetto capture or complete installed original UI pack is available for this validation. Source pixels/quality and all requested content are preserved; device improvement remains to be measured.
