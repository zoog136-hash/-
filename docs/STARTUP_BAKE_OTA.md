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
3. From the repo checkout, generate the device-cache proof:

   ```bash
   python3 tools/boot/build_startup_bake_reuse.py --device-caches \
     --previous "$PREVIOUS_USER_DIR/current523_bake" \
     --current "$CURRENT_USER_DIR/current523_bake" \
     --previous-source "$PREVIOUS_SOURCE_SHA" --current-source "$CURRENT_SOURCE_SHA" \
     --engine "$ENGINE_IDENTITY" --output "$STAGE/startup_bake_reuse.json"
   ```

   The profiles must be quiescent. The script streams and hashes each eligible
   cache file and includes entries with identical output bytes under different
   keys. The output includes metadata only. If the actual preceding pinned
   archive is available and should also work as a seed, provide the two sealed
   bundle directories made by `build_startup_bakes.py` and omit `--device-caches`.
   The installed seed must then match the verified previous index. Device-only
   metadata never changes the key of an installed seed.
4. Export from that same release staging directory with the same build
   identity. Keep the JSON at the staging root so the preset includes it.

   ```bash
   (cd "$STAGE" && godot --headless --export-pack AndroidUpdatePack "$OUT/twilight-update.pck")
   (cd "$STAGE" && python3 tools/android/update_pack.py feed \
     --pack "$OUT/twilight-update.pck" --base-url "$OTA_BASE_URL" --output "$OUT/update.json")
   ```

   Keep `startup_bake_pin.json` unchanged. The standard runner does not have
   the private original inputs needed to generate this metadata. The release
   job taking this opt-in needs staging with the verified proof before export.
   The updater still applies the feed's package SHA and compatibility checks.
   Regenerate the proof when the exported producer inputs, engine or original
   selection change. Keep original payloads and generated ZIPs in the private
   build environment.

## Check the resulting export

Use the same saved profile snapshot to compare the official OTA and candidate.
Test a second profile with no prepared pack or local caches. Confirm candidate
cache hits with `reused=true` in `boot_progress.log` and check that the existing
save remains readable. A missing or wrong proof, changed producer key or
damaged cache must use the normal miss path. A damaged original must still
fail its original verification. Removing the candidate OTA should allow the
previous release to load an untouched matching generation. Repeat with the
actual target APK/OTA and original selection before making device performance
claims.
