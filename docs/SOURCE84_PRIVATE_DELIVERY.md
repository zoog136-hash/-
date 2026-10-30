# Source84: tracked runtime delivery

PR191 now contains the **complete 2,140-file / 2,015,563,672-byte map pack** at
`external_map_packs/source84_v3/`. A normal checkout supplies the actual image,
collision, map-definition and correction bytes. No Space download, private
Library login, separate 2 GB archive or external map directory is required.
The existing 67 correction files were moved into this single pack, preserving
their bytes; the missing 2,073 files were added without duplicate archives.

The largest file is 4,984,310 bytes. Ordinary Git blobs are used, not Git LFS.
`external_map_packs/.gitattributes` preserves exact bytes across checkouts.
The metadata manifest is `data/maps/source84_delivery_manifest.json` and its
2,140 per-file size/SHA entries are the completeness contract.

| Content | Files |
|---|---:|
| Original WebP chunks | 1,920 |
| Selected base collision grids | 31 |
| Equality collision layer | 36 |
| Map definitions | 84 |
| Base index and safety metadata | 2 |
| Local correction layer | 67 |

The three fixed index SHA-256 values remain unchanged:

| Index | SHA-256 |
|---|---|
| `index.json` | `16f3d61b97cfe4ce6b21e1f0eab738e06f17f5bfee30dd48a32b6369269a4474` |
| `equal-collision-v1/index.json` | `0b79b95687d484a53d13b371e909425b96314e4d5fbfe70dd6246a20f6498fd9` |
| `local-interpretation-v1/index.json` | `c89ce64fe14a2961013747786847763a2693c7c14c7b9fe7496b188938779c43` |

## Clean checkout

```bash
python3 tools/source84_delivery.py verify --pack-root external_map_packs/source84_v3
```

Then open this checkout's `project.godot` normally. The bundled pack is selected
without environment variables when no existing user-installed pack is present.
Explicit `TWILIGHT_SOURCE_MAP_PACK` and existing `user://source_maps_v3` installs
retain precedence. A damaged override is rejected rather than silently hidden;
use a clean user-data directory when proving checkout-only behavior. Character
saves are not removed or overwritten by the verifier.

## Phone: ZIP-installed project and existing updater

The old updater reads **main**. PR191 remains unmerged, so that unchanged
updater cannot receive this PR automatically. Obtain the new
`tools/android/termux_update_zip.py` from PR191 and select this branch or its
final commit explicitly:

```bash
python termux_update_zip.py /path/to/TWILIGHT_Play --ref integration/source-recovery-20261030
```

This downloads the actual source84 image/grid/definition/correction files from
the pinned Git commit through the existing incremental GitHub byte-download
path. Git blob length/SHA are checked, updates retain backups, and the complete
2,140-file SHA verifier runs afterward. No `--source84-inputs` or
`--source84-linkage` is needed for an ordinary update. Pillow is not required
for this Git-only installation path. Large images and `.u8.gz` files are
runtime inventory entries, not LFS pointers. The existing `oman_v2` topology
is also retained: source84 Oman replacements need that tracked legacy gameplay
input. Cleanup must not remove it.

Reopen the updated extracted project in Godot Android. This updates a Godot
project; it does not patch a previously installed standalone APK or inject
files into another application's private storage. Actual phone update,
Godot Android startup and FPS remain untested in this cloud environment.

## Godot and Android export

The enabled `addons/source84_export` plugin verifies and adds all raw map
files to exports. The ordinary include filter alone cannot traverse the
parent `.gdignore`; the plugin preserves that import exclusion while exporting
the real bytes. No separate original-pack installation is needed first.

```bash
python3 tools/source84_delivery.py export --project /path/to/checkout --godot /path/to/godot --preset Android --output /path/to/TWILIGHT-debug.apk
```

The wrapper verifies every map file before invoking Godot. Godot 4.7.2 export
templates, SDK/Java and the existing signing configuration must be installed.
It does not create credentials, run CI or publish an APK. APK export, size
limits, device installation and device FPS are not verified here: local
Android SDK build-tools are absent. Supplemental PCK verification is not APK
or Android-device verification.

## Provenance retained for the source123 audit

- `data/maps/source84_delivery_manifest.json`: all 2,140 runtime paths,
  sizes and SHA-256 values.
- `data/maps/source84_input_archives.json`: original eight ZIP and split-file
  names, fixed bytes/SHA, existing source references, and exact archive-to-used
  chunk membership. These historical inputs are optional for consumers.
- `external_map_packs/source84_v3/maps/*.json`: source folder/ID, original
  chunk references, geometry identity and placement for each map.
- `data/maps/source84_local_files.json`: unchanged correction inventory and
  original source commit/archive association, moved out of the runtime root.
- `data/maps/source_map_review_pack.json`, `source_map_equal_collision_pack.json`
  and `source_map_local_pack.json`: pinned provenance/index receipts.
- Other scope manifests remain in `data/source_transform_visuals.json`,
  `data/monsters/reviewed_source_monsters.json`, `data/npc/source_six.json` and
  `data/l1j/source3_item_identities.json`.

Original source inputs and Space items have not been deleted. Optional
`tools/source84_inputs.py` still supports reconstructing the identical pack
from the existing eight artwork ZIPs (or 14 split files plus ZIP08), linkage
v3 and tracked corrections. That recovery path requires Pillow, but is not a
prerequisite for checkout, phone updating or ordinary export.

## Validation scope

- All 2,140 actual tracked bytes match both their Git blob IDs and pinned
  size/SHA entries; no LFS pointers or missing files.
- Cold sparse worktree, new import cache and empty user-data directory, no
  external pack settings or Space inputs: every 1,920 WebP decoded, 84 actual
  fields loaded, entry/verified-return paths and six NPC art/feet/proximity
  bindings checked: **4,322 checks, zero errors**. The sparse test includes the tracked baseline dependencies
  needed by these fields; unrelated actor artwork is omitted to fit disk.
- The updater's real GitHub byte-download function fetched a WebP, compressed
  collision grid and correction PNG at the committed ref and verified their
  Git blob and runtime SHA values.
- Earlier supplemental PCK proof mounted all 2,140 exported files in a separate
  cold project and decoded a real 3120×1680 WebP. Map pixels/geometry are
  unchanged by tracking or relocating the correction files.
- Full Android APK/device tests and manual play across every map are not
  claimed. Historic whole-resource six-ZIP ledger checks and Fairy45153's
  appearance HOLD remain separate from this map delivery.
