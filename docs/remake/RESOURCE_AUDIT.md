# Reproducing the resource audit

The only resource status ledger is [`data/resource_delivery_ledger.json`](../../data/resource_delivery_ledger.json). Its `current_id_audit` section contains the current runtime IDs, independent source/motion/link evidence, path and SHA-256 observations, rights and delivery qualifications, and summary counts. The older `original_monsters_items` and `original_map_tiles` entries remain unchanged. This document describes the method, rather than maintaining another set of completion statuses.

Use the project’s required Godot 4.7.2 engine and Python with Pillow. Import the real repository resources first, then regenerate the ledger:

```sh
python3 tools/check_resource_integrity.py --root .
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --headless --editor --path . --import
python3 tools/remake_resource_audit.py --root . --godot "$GODOT" \
  --reference-dir /workspace/research
python3 -m unittest discover -s tests -p test_remake_resource_audit.py -v
```

Use `--check` to compare a fresh export and measurements with the committed ledger. When the private references are not mounted, omit `--reference-dir`: the previous, hashed reference observations are retained as historical evidence, without claiming to have rechecked their availability. The audit does not install, redistribute, or substitute those references. Existing repository scripts and data are fingerprinted so runtime changes require a fresh audit. A previous export can be supplied with `--runtime-export PATH`; it must come from the same working tree. `--godot` is preferable for release evidence.

The exporter calls `world._load_data()` without putting the world in the scene tree. This obtains the actual merged item catalog, current class selection, expanded monster registry, skill registry and map registry. It uses `item_visual_resolver` when present, recording both inventory and ground resolution; otherwise it follows the older external/manifest/catalog/fallback precedence. It loads actor resources and the map definition’s declared image layers. It calls `MonsterCatalog.apply_map` to enumerate effective spawn references. It never boots a world scene or reads/writes a player save.

Monster and boss counts partition the expanded monster registry. Their stable runtime identity is the monster name; the audit does not manufacture numeric source IDs. Items with a `sourceId` retain that ID; locally authored items use an explicitly marked `local:` name identity. Legacy item rows are listed separately because the runtime maintains that lookup alongside the merged catalog. Neither registry is silently deduplicated by display name.

Configured spawn capacity is the sum of region `max_count` values. It is not a live actor count, and a multi-species region’s entire capacity is not credited to every species. The per-species evidence contains map/region references and the shared region capacity. Unknown referenced names fail the audit. Live instance counts are explicitly unobserved.

Every generated catalog atlas is read from disk. Per action and direction, the audit counts declared cells, exact visible RGBA diversity, and diversity after trimming transparent margins. Empty frames are distinguished, repeated cells are not counted as new pixels, and pure translation does not increase the cropped diversity count. None of these measurements proves articulated animation, correct anatomical poses, genuine source timing, eight original views, or original-art delivery. Declared directions are recorded separately from distinct pixel sequences. Current generated tracks remain identified as generated derivatives with TWILIGHT timing and flattened layers.

The private reference actors have separate metadata: actual atlas hashes, source-action ticks and hit markers, pixel diversity by action/direction, declared body/shadow/clothes IDs, and independent structural verification. Source direction indices are not assumed to be compass directions. The preview’s ticks-per-second value remains unverified. A source actor number is not a verified binding to a current game class or transform ID, so these references do not increase the game’s dedicated original-motion count.

All item mappings include their selected path and hash, their declared catalog image, the selection route, and any reviewed manifest binding. Duplicate reports distinguish shared paths, identical file bytes at different paths, and identical loaded pixel images. A procedural fallback records the generating script as its source and the rendered image separately; a shared script hash alone does not mean its output symbols are identical. Shared images are reported for review; duplication alone does not prove an ID error. Resolver identity statuses do not supersede the ledger’s rights or original-delivery status. A valid generic fallback is recorded as such, rather than as an exact original icon match. Procedural skill effects similarly retain their preset ID and timing basis without being counted as source animation frames.

`runtime_load_tested` proves only the described resource load or registration. Every per-ID `runtime_visually_tested` starts false; headless loading and pixel hashing cannot turn it true. Screenshot/playtest evidence should be attached only after an explicit per-ID review, with a corresponding generator extension that preserves its provenance. Repository file presence does not resolve source-art redistribution rights or constitute delivery of an original resource pack.
