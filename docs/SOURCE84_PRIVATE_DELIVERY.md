# Source84 private runtime pack

PR #191 contains the game code, reviewed monster/transform/NPC outputs and the
local correction layer. The complete map pack is a separate private input:
**2,140 files, 2,015,563,672 bytes**. The per-file size/SHA contract is
`data/maps/source84_delivery_manifest.json`. No public download endpoint or
Android network downloader is configured. A Library reference is not an APK
download service. This document does not declare the private archive delivered.

The complete pack contains 1,920 original WebPs, 31 base collision files,
36 equality-collision files, 84 map definitions, two base metadata files and
67 local correction files. Required index SHA-256 values:

| Index | SHA-256 |
|---|---|
| `index.json` | `16f3d61b97cfe4ce6b21e1f0eab738e06f17f5bfee30dd48a32b6369269a4474` |
| `equal-collision-v1/index.json` | `0b79b95687d484a53d13b371e909425b96314e4d5fbfe70dd6246a20f6498fd9` |
| `local-interpretation-v1/index.json` | `c89ce64fe14a2961013747786847763a2693c7c14c7b9fe7496b188938779c43` |

## Existing Space inputs: primary installation path

A newly uploaded 2 GB ZIP is **not required**. Reuse the eight existing
`map84_fullres_assets_01_of_08.zip` … `_08_of_08.zip` inputs, or the existing
14 files `.zip.001`/`.zip.002` for 01–07 plus the unchanged ZIP08. Keep the
original filenames together in one folder. Do not unzip or concatenate the
split files. Their original and part sizes/SHA, versions and existing Library
references are recorded in `data/maps/source84_input_archives.json`.

The eight artwork ZIPs alone do not contain map definitions/collision grids.
Also reuse the already delivered `maps_source3_linkage_90maps_20261029.zip`
**version 3**, SHA `33e0b552f1cbd75aef1d299886603107185df1e89cd76432268f94c5bd3b5c77`.
Its existing reference is in the same input specification. No new external
equality audit download is needed: the reviewed equality index is tracked in
Git, the original compressed grids come from the pinned linkage ZIP, and all
final bytes must match the full 2,140-file manifest.

With Python 3.11+ and Pillow installed, from the matching checkout:

```bash
python3 tools/source84_inputs.py rebuild --inputs /path/to/Space-downloads --linkage /path/to/maps_source3_linkage_90maps_20261029.zip --project /path/to/checkout
```

This accepts full original ZIPs or split parts directly, verifies original
archive SHA/CRC, stages all 1,920 image bytes, regenerates map definitions and
the collision layers using existing code, installs tracked local corrections,
checks all 2,140 final size/SHA entries and only then publishes the new pack.
It does not make another delivery ZIP, download anything or delete input files.
Allow about 2.1 GB additional working space besides the existing downloads.
Temporary image/build paths use hardlinks internally to avoid two full copies.
An existing install is preserved and must already match the pinned manifest.

### Phone: Godot Android editor and the ZIP updater

The old updater reads **main**. Until PR191 is merged, running that unchanged
updater will not receive this PR. Obtain the updated
`tools/android/termux_update_zip.py` from PR191, then explicitly select its ref.
The default remains main; this change does not merge or retarget main.

On the phone, save the existing Space attachments to a directory Termux can
already read. The updater obtains code, the four scoped installer scripts,
metadata and the tracked correction layer from the selected Git commit. It
does **not** obtain the private original artwork from GitHub or Library.
Run with the actual paths to the extracted Godot project and downloaded files:

```bash
python termux_update_zip.py /path/to/TWILIGHT_Play --ref integration/source-recovery-20261030 --source84-inputs /path/to/Space-downloads --source84-linkage /path/to/maps_source3_linkage_90maps_20261029.zip
```

Pillow must be available in that Python environment (install it through the
device's normal package setup if absent). The command updates pinned Git files
using the existing backup mechanism and then performs the same offline rebuild
into `TWILIGHT_Play/external_map_packs/source84_v3`. Reopen that project's
`project.godot` in Godot Android afterward. Missing local inputs cause an
explicit stop; private assets are never guessed or fetched with Library IDs.

An already installed standalone APK is a different application. This updater
edits a Godot project; it cannot inject files into another APK's private data
directory or patch that APK. Use the bundled private APK build path below for
that target. Actual phone download, Godot Android startup and APK device tests
remain unverified; successful cloud reconstruction does not mark them delivered.

## Optional recipient path: separately received combined archive

Only if a combined archive was separately received, use
`TWILIGHT-source84-v3-private.zip` from that authorized private handoff.
The archive is **2,016,074,522 bytes**, SHA-256
`fe5a04ba5459ad20f470e267ae483ffae05662ee6392cba3cc48ad25eedb86d4`.
There is currently no automatic remote retrieval. Keep its access restrictions;
do not publish it in this public Git repository or a public Release.

From the matching checkout, with Python 3.11+:

```bash
python3 tools/source84_delivery.py check-archive --archive /private/TWILIGHT-source84-v3-private.zip
python3 tools/source84_delivery.py install --archive /private/TWILIGHT-source84-v3-private.zip --project /path/to/checkout
python3 tools/source84_delivery.py verify --pack-root /path/to/checkout/external_map_packs/source84_v3
```

The installer checks every file's pinned SHA and size, reads all ZIP members to
verify CRC, rejects extra/duplicate paths, stages a new directory and renames it
only after complete verification. A different existing install is preserved and
rejected. It does not write character saves. Allow at least 2.1 GB additional
free disk space besides the received archive. An identical existing install is
verified without overwriting it.

For an existing desktop executable, install with `--user-root` instead of
`--project`, specifying the actual Godot application user-data directory. This
creates its `source_maps_v3` child. Do not guess another app's user-data path.
On Android, app-private storage may be inaccessible to a normal file manager;
use the bundled APK build path below rather than assuming an external ZIP can
be opened by the APK. No Android in-app file picker is implemented here.

Runtime precedence is explicit `TWILIGHT_SOURCE_MAP_PACK`, an existing user
pack, then `res://external_map_packs/source84_v3`. A damaged override/user pack
is rejected by the existing integrity checks, without silently substituting
another copy. Missing art blocks affected maps and preserves saves.

## Private Android/Godot build

Install the pack in the project as above **before** export. Keep it ignored by
Git. The enabled `addons/source84_export` plugin verifies and adds every raw WebP
and `.u8.gz` file to Godot's export. The include filter alone cannot traverse
`external_map_packs/.gdignore`; the export plugin is required. The ignore file
continues to keep these raw files out of texture import.
The game reads these raw files and checks pinned identities when loading maps.

```bash
python3 tools/source84_delivery.py export --project /path/to/checkout --godot /path/to/godot --preset Android --output /private/TWILIGHT-source84-debug.apk
```

This verifies all 2,140 files before invoking Godot. Without the pack it fails
before starting export. Godot 4.7.2 export templates, Android SDK/Java and the
existing debug signing configuration must already be installed. This wrapper
does not create credentials, install an SDK, run CI, upload or distribute the
APK. The resulting APK contains private third-party art: its sharing requires
the same authorization as the source pack. Total APK size and Android device
storage limits must be tested on the intended device. Android APK creation,
device startup and FPS remain unverified in this environment.

For the mobile Godot project updater, `source84_v3` is a permitted runtime pack
and its `.gz` collision files are retained. The updater does not download this
private pack from Library or clean it up. Install the separately received
archive into the extracted project. An ordinary Git-only update cannot supply
the absent original artwork.

## Producer: package an already verified complete install

```bash
python3 tools/source84_delivery.py package --pack-root /private/verified/source84 --output /private/TWILIGHT-source84-v3-private.zip
```

The archive contains only the 2,140 pinned runtime files at its root. Packaging
checks input bytes, then ZIP CRC and every archived SHA, and prints the complete
archive size/SHA. It performs no network operation. Send the private archive,
its printed receipt and this checkout through an authorized, accessible private
channel. Until actual recipient access is confirmed, delivery remains pending.

`install --source-dir /private/verified/source84 --project /path/to/build` also
supports a local verified directory. `--hardlink` is an optional space-saving
mode for immutable build inputs on one filesystem. Never edit either linked
copy; use the default independent copy for a normal recipient installation.

The 19 original monster input packages and the historic whole-resource six-ZIP
ledger are separate from this map-runtime delivery. Fairy45153 remains held.
The scoped map tests do not mean every map was manually played or that all
historic original resources have been distributed.

## Validation performed

- Six bounded installer tests: missing input, complete archive round trip,
  idempotence, preservation of an existing different directory, tampered data,
  traversal/extra inventory and symlink rejection.
- Android preset supplemental PCK export with the enabled raw-file plugin; a
  separate cold project with no installed directory mounted that PCK, checked
  SHA for all 2,140 files and decoded a real 3120×1680 WebP.
- Bundled-path runtime field regression: 108 checks, no engine errors.
- Mobile updater scope: 13 tests; Android authoring/export scope: 12 tests.
- Complete private ZIP: exact inventory, all file SHA/size and ZIP CRC verified.

The supplemental PCK proof is not an APK. The local Android SDK build-tools
are absent; no APK export, device install or FPS measurement was performed.

- Existing-input integration: all eight original ZIP size/SHA/CRC checks and
  all 1,920 image SHA checks passed using the existing 14 Space split files
  plus ZIP08. Together with the existing linkage v3 and tracked correction
  files, the installer produced the exact 2,140-file, 2,015,563,672-byte manifest
  in a new consumer directory. No new combined archive or upload was used.
- Joined-file unit tests cover full-ZIP/split-ZIP equivalence, seeking across
  split boundaries and rejection of a tampered part.
