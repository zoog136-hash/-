# Reusing startup data after an OTA

The release can include a small `startup_bake_reuse.json` alongside the existing
`startup_bake_pin.json`. It proves equivalence to particular prior cache files.
With matching original inputs, a player who already has those device caches
can use them after the update. A fresh profile still builds missing data from
its installed originals. An absent, unreadable or inapplicable proof uses the
usual regeneration path.

## Generate the release metadata offline

1. Export the previous and candidate versions with the production Godot and
   AndroidUpdatePack preset. Run each compiled version against the same verified
   original input selection and an isolated app profile. Let the original boot
   and field preparation finish. For the candidate run, start with a fresh
   profile and no installed seed, compatibility proof or imported device bakes.
   For the previous run, use the supported build's verified device cache. Keep
   the boot receipts and SHA-256s of both exports. The benchmark under
   tools/boot/benchmark_full_startup.gd can be run as an external SceneTree
   script against the compiled build. For a PCK overlay, start with its matching
   base resources and mount the verified update via the updater before selecting
   the original inputs. Record first accepted field movement when timing the
   full start.
2. Use the selected pack's tables SHA and effective manifest pin for each
   selected section, including any add-ons. `Source523Pack._startup_source_key`
   hashes this sorted JSON dictionary. For a release without that helper,
   derive the same fingerprint from its verified source descriptors. Use
   the compiled runtime engine version string and commit hash joined by `|`.
3. For Android OTA packaging, prepare a device-cache ticket from the exact
   previous official feed and PCK, the candidate PCK before adding a proof,
   and the two quiescent cache directories. The tool streams and checks every
   cache file it compares. The ticket contains SHA-256 metadata only.

   ```bash
   python3 tools/android/startup_ota.py prepare \
     --previous-feed "$PREVIOUS_FEED" --previous-pack "$PREVIOUS_PCK" \
     --previous-cache "$PREVIOUS_USER_DIR/current523_bake" --previous-source "$PREVIOUS_SOURCE_SHA" \
     --candidate-pack "$PLAIN_PCK" --candidate-cache "$CURRENT_USER_DIR/current523_bake" \
     --candidate-source "$CURRENT_SOURCE_SHA" --engine "$ENGINE_IDENTITY" \
     --output "$OUT/startup-ota-ticket.json"
   ```

If the actual preceding pinned seed archive is available and should also
be reusable, the separate seed workflow uses the sealed outputs of
`build_startup_bakes.py` with `build_startup_bake_reuse.py`. The Android OTA
ticket here covers device caches. It cannot change the keys of an installed seed.

## Validate an unpublished OTA

The standard Android release workflow currently uses the plain export. The
packaging tool can run in an isolated checkout with the regular Android
export preset and its normal `build_info.json` already generated. An approved
handoff of the SHA-only ticket to the release runner is still needed. Keep the
ticket outside the checkout and pass its path with `--ticket`. Keep the
originals, saves and generated cache files in the approved build environment.

Use the same staged project and build identity for the plain export, for the
ticket preparation above, and for the no-publish test below. Use a staging URL
in the generated feed for local verification.

```bash
godot --headless --path . --export-pack AndroidUpdatePack "$PLAIN_PCK"
```

```bash
python3 tools/android/startup_ota.py export \
  --ticket "$OUT/startup-ota-ticket.json" --output "$OUT/twilight-update.pck" \
  --status "$OUT/startup-ota-status.json"
python3 tools/android/update_pack.py feed --pack "$OUT/twilight-update.pck" \
  --base-url "$OTA_BASE_URL" --output "$OUT/update.json"
```

The exporter first creates a plain PCK. It matches the ticket to the exact
compiled member digests and compatibility key. The two version-stamped
members, `build_info.json` and `project.binary`, can differ from the ticket's
original export. The compatibility key covers the project configuration
without its version line. During the same packaging run, every member of the
plain PCK, including the build metadata and seed pin, must have the same bytes
in the second PCK. The second PCK must add exactly the approved proof JSON.
Only that verified result is eligible for the `included` status.

The `omitted` or `rejected` status accompanies the unchanged plain PCK. This
keeps the normal regeneration path when there is no reviewed ticket, the
packaged content differs, or the second export does not match. The status
JSON records which PCK was selected. An included status describes packaging.
Startup improvement depends on the player's stored keys and original input
selection. Retain the ticket only for the verified source selection and
compiled content.

For an unpublished PCK, verify the full member set and compare the embedded
proof against the exact previous published build:

```bash
python3 tools/android/startup_ota.py verify \
  --ticket "$OUT/startup-ota-ticket.json" --plain "$PLAIN_PCK" \
  --pack "$OUT/twilight-update.pck" --previous-feed "$PREVIOUS_FEED" \
  --previous-pack "$PREVIOUS_PCK"
```

## Check the resulting export

Run the packaging regression tests from the repository root.

```bash
python3 -m unittest discover -s tools/android -p 'test_startup_ota.py' -v
```

These tests exercise packaging with synthetic fixtures. Measure first install
separately with an empty profile and the normal game entry point.

Use the same saved profile snapshot to compare the official OTA and candidate.
Test a second profile with no prepared pack or local caches. Confirm candidate
cache hits with `reused=true` in `boot_progress.log` and check that the existing
save remains readable. A missing or wrong proof, changed producer key or
damaged cache must use the normal miss path. A damaged original must still
fail its original verification. Removing the candidate OTA should allow the
previous release to load an untouched matching generation. Repeat with the
actual target APK/OTA and original selection before making device performance
claims.
