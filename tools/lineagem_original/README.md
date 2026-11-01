# Native base508 resource connections

The active catalogs use701 verified source definitions:388 transformations,167 dolls and146 relics. Source names, grades and in-world identities are preserved separately from the former registry. Class/gender and explicit active-option rules select conditional appearances; Halpas has a declared base, and Taco's indirect summon identity preserves application type461/target11 without inventing its gameplay meaning. NPC values remain keyed by exact source NpcClass IDs.

The common2D player/follower/relic path samples decoded source poses and offsets directly. It preserves native token order, zero-time events and separate Walk/Run declarations. The gameplay hit clock remains independent. No limb repair, interpolated frames, canvas resizing or procedural actor motion is added to native poses.

## Required private resources

This branch contains code and source metadata, **not the source pixel/UI pack**. A clean checkout or exported game cannot display the new native appearances until an authorized private pack is installed using the offline pack action below (legacy `user://lineagem_base508/manifest.json` remains supported). No raw SP2, source-derived PNG, capture video or personal backup is committed here. Redistribution rights for the third-party art have not been established; the10GB original archive must not be published with this PR.

The private pack contains relative actor/pixel/UI paths and must be accompanied by its original input provenance. Library/local backup receipts are delivery records, not proof that public Git or an APK contains those files. Existing repository resource-integrity checks concern the previously tracked atlases; they do not approve this source pack.

## Build from authorized local inputs

Use the pinned `requirements.txt` in an isolated Python environment. Inputs are the validated base508 tables, original SPR declarations, and exact original SP2/UI files. Preserve original ZIPs and conflicting bytes; do not substitute nearby file suffixes.

```sh
python tools/lineagem_original/build_verified_registry.py --inputs INPUTS --output data/lineagem_base508
python tools/lineagem_original/build_native_pack.py --inputs INPUTS --registry data/lineagem_base508 --output PRIVATE_PACK
python tools/lineagem_original/attach_native_layers.py --inputs INPUTS --pack PRIVATE_PACK
python tools/lineagem_original/build_connection_report.py --inputs INPUTS --registry data/lineagem_base508 --pack PRIVATE_PACK --report PRIVATE_REPORTS
python tools/lineagem_original/build_native_overlays.py --inputs INPUTS --pack PRIVATE_PACK
python tools/lineagem_original/build_playback_policy.py --inputs INPUTS --pack PRIVATE_PACK --output data/lineagem_base508/playback_policy.json
```

Copy the authorized UI files into `PRIVATE_PACK/ui` with original relative paths. Install the complete pack into the game's user-data location, or use `--lineagem-original-preview=/absolute/path/manifest.json` for an isolated local inspection. The builders support targeted sprite refreshes so new inputs do not require converting the entire pack again.

## Runtime policy and current limits

The default policy is **unverified compatibility playback**, not proven M-client equivalence. Explicit SPR rates take precedence. Missing clocks use separately identified candidates; attr8 additive and attr128 alpha0.5 are declared host approximations. `--lineagem-source-strict` preserves unresolved clocks as static and disables unverified blending. See [COMPATIBILITY.md](COMPATIBILITY.md) for evidence, scope and controls.

At the latest local checkpoint743 sprite records serve701 card definitions.697 default appearances can be selected; four class/gender cards await an explicit declared pair when player gender is unknown.994 available attachment layers can be composited in compatibility mode;188 exact attachment addresses and seven frame-event source effects remain unavailable. Two body-track and two attachment-track address/frame exceptions are retained rather than filled with generated art. Source origin and eight-direction mapping still require visual review.

Godot4.7.2 headless import/loading checked the player route, strict/compatible separation, a source caster effect, a native frame-event overlay, and conditional identity selection. Android execution, per-character visual equivalence and full-game source-pack restoration remain unverified. Existing capture/validation helpers are isolated diagnostics, not evidence that all originals have been delivered.

## Offline installation on Android or desktop

Use **환경 설정 → 리니지M 원본 팩 → 원본 팩 ZIP 선택**, select the received `TWILIGHT_base508_runtime_install_v2.zip`, wait for the completion message, then fully close and reopen the game. Godot's native `FileDialog` uses filesystem access and the ZIP MIME type; no account, download URL, server, or embedded credential is required. Android device execution is still unverified. A plain source ZIP or the old checkpoint delta is not an install ZIP.

The installer checks schema2/base508,701 card definitions,743 sprite declarations, required runtime JSON, bounded ZIP central-directory entries, inventory/payload SHA256, every extracted file's size/SHA256 and exact totals. These hashes detect corruption; they are not a publisher signature. Inventories and original-byte payloads are sharded to keep memory bounded and avoid ZIPReader's linear file lookup over573,000 individual ZIP entries. Existing source timing/blend limitations are retained.

New files go into a unique staging directory under `user://lineagem_base508_versions/`. Only a fully checked directory receives an atomically renamed completion marker. The next process selects the most recently committed version; the current session freezes its previous root so textures cannot mix during installation. Old versions, legacy packs and saves are never overwritten or deleted. Cancellation/failure leaves unselected staging files, which consume space but never activate. Allow at least the declared bytes plus4KiB per file and64MiB headroom for a fresh install; the previous pack also remains on disk.

The source84 map exporter/Termux updater does not deliver this private pack. The updater can receive the code using its existing `--ref` option, but an APK must be rebuilt with the installer code before it has this action. Public Git contains no private pixels; a user must receive the install ZIP separately through an authorized private channel. A locally produced ZIP is **not delivered** until that transfer actually succeeds.

Build locally from the preserved backups, without image conversion:

```sh
python tools/lineagem_original/package_install_zip.py --base BASE_BACKUP.tar.gz --delta TWILIGHT_base508_connection_checkpoint_v3.zip --output PRIVATE_INSTALL.zip
```

The builder checks the baseline hash against `RESTORE.json`, retains original relative paths and bytes, and writes a receipt with the final ZIP SHA256. Preserve both inputs. No automatic external upload occurs.

Minimal checks (isolated user-data profile required; no whole-game/visual approval):

```sh
python tests/generate_lineagem_install_fixtures.py /tmp/lineagem-install-fixtures
XDG_DATA_HOME=/tmp/lineagem-safety godot --headless --path . --script tests/lineagem_pack_install_smoke.gd -- --fixtures=/tmp/lineagem-install-fixtures
XDG_DATA_HOME=/tmp/lineagem-real godot --headless --path . --script tests/lineagem_pack_install_local.gd -- --pack=/absolute/private/PRIVATE_INSTALL.zip
```

## Corrected source clock parsing

The `110.frame rate(...)` spelling is now recognized alongside `110.framerate(...)`. All49 formerly pending transformation tracks across13 identities recover explicit source clocks; no transformation clock remains unspecified.331 doll tracks across164 sprite IDs and eight compiled overlay clocks remain unspecified. Existing v2 install ZIPs do not need a1GB redownload: updated code uses the SHA-guarded source correction table automatically in both modes. A private metadata-only delta preserves corrected actor JSON for pack maintenance. This fixes cached interpretation, without editing source images, token order/ticks, offsets or blending.

Overlay declarations can have their own105.clothes attachments. The overlay compiler now runs the same alias/address/attr attachment path used by actors; formerly it emitted only the overlay body. Existing source effects20889,28559 and28583 declare seven additional layers. Their exact original SP2s are tracked as required input rather than replaced with generated graphics. ConstantData31131 also identifies global PolymorphEffectSpriteID6082 with clothes6129; identity registration does not claim the local transition trigger or source clock is already verified.
