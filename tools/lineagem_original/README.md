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

## Complete current523 client as the source (new)

`client523_source.py` turns the user's own complete client into the inputs above, selecting every file by exact SHA-1 from the 523 `files_info.json`. The base client ZIP can be given as one file or as raw byte-split parts in order; per-version patch ZIPs supply the files changed after the base. Outputs go to a new private directory outside the repository:

```sh
python tools/lineagem_original/client523_source.py \
  --files-info files_info.json.523 \
  --client-zip part1 --client-zip part2 ... \
  --patch-zip patch509.zip --patch-zip patch510.zip ... \
  --content-password-b64-file PRIVATE_KEY_FILE \
  --output PRIVATE_SOURCE_523
```

* `sp2/` is the exact `Sprite/*.sp2` namespace (`--original-root`); `spr/` holds `list_*.spr` (`--spr-root`/`--spr-dir`); `tables/current523_content_tables.zip` is a deterministic ZIP of the decoded `content/*.json`.
* `client523_receipt.json` records the SHA-1 and origin (base or patch) of each used file and lists anything missing; a file with no exact candidate is never substituted. The content password is never written anywhere.
* `client523_connection_report.json` resolves table sprite references directly or through `list_*.spr` sprite aliases. This is reference resolution only, not proof of playback or gameplay use.
* `--no-extract-sp2` produces the receipt and report without writing ~7 GB of SP2 files.

Verified on 2026-11-08 against a complete 523 client (26 raw parts + patches 509–523): 679 files used, 0 missing; 74,656 SP2 members; 1,065 tables; of 6,479 table-referenced sprite IDs, 4,877 direct, 1,471 via alias, 131 unresolved. `original_spr.read` accepts all 30 extracted 523 `list_*.spr` files (29,491 declarations). The new tables ZIP has a different SHA-256 from the earlier private `d5192c3c…` ZIP, so runtime configuration that pins that SHA is not yet switched to this source.

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

Overlay declarations can have their own105.clothes attachments. The overlay compiler now runs the same alias/address/attr attachment path used by actors; formerly it emitted only the overlay body. Existing source effects20889,28559 and28583 declare seven additional layers. Their exact original SP2s are tracked as required input rather than replaced with generated graphics. ConstantData31131 also identifies global PolymorphEffectSpriteID6082 with clothes6129; the local transition trigger is wired in compatibility mode, while exact M trigger placement and source clock remain unverified.

## Small verified effect addon

After installing the v2 full pack and restarting, select `TWILIGHT_base508_effects_addon_v1.zip` through the same Settings ZIP picker, then restart again. The addon pins the exact base manifest SHA256, verifies its own inventory/pixels, writes a separate version and records the existing base as its immutable fallback. Body actors, UI and unchanged pixels resolve through that base; old packs/saves and strict-mode preferences remain preserved. Missing/wrong bases are rejected. No1GB re-download, full base extraction or manual file overwrite is required. Keep the base installed. The installer bounds the ancestry chain and rejects paths outside trusted pack directories.

The addon contains111 literal original pixel files and corrected metadata, not a new motion set. It restores the seven105.clothes layers on effects20889/28559/28583 and the6082 transition effect with its6129 layer. ConstantData31131 provides the exact transition identity. Local native-form application triggers it in compatibility mode; repeated application of the same identity preserves its animation/effect clock. This placement and its unspecified24Hz host fallback remain unverified M semantics. All newly available attrs8/128 retain their original values and the separately labelled compatibility compositor.

Build only the delta from the staged effect records and existing base using `package_effect_addon.py --stage STAGE --base PRIVATE_BASE --output PRIVATE_ADDON.zip`. Pixel bytes are never committed to public Git. The addon requires an updated game containing the resolver/installer code; a Draft PR does not update an old APK automatically.

Native body15759 itself declares104.attr8. The common renderer now retains that source flag for its body in compatibility mode without applying it to the separate shadow; strict mode keeps literal RGBA inspection. This does not establish an exact M blend equation.

## Independent original monster component

The same offline ZIP picker accepts `TWILIGHT_base508_monsters_4_install_v1.zip`. It does not require or overwrite the1GB collectible pack. New versions are verified under `user://lineagem_base508_monsters_versions/`, activated after validation and selected after restart. The previous monster pack and card versions/saves remain intact. Manifest NPC/sprite/spawn-view/territory/Land tuples must match the game bindings; all five motions, eight direction arrays, referenced PNG hashes and original positive tick sums are verified before activation. Older nested `monsters/` and `user://lineagem_base508_monsters/` packs remain readable fallbacks.

The four enabled source identities are NPC248→SPR1110,249→1108,281→145,286→152. They replace only the declared legacy signatures in host `aden_world` slots using exact source contexts. Source HP/MP/AC/MR/Exp and context level apply; host coordinates/counts/respawn and remaining combat adapters are compatibility. Native geographic spawns remain0; Curtz is not activated. Unverified source loot is not invented. These20 monster motion clocks currently use the separately labelled compatible default, not a recovered M rate. Card strict settings are inherited unless the monster component has its own setting.

The integration imports only delegated commit7b6405b3509ae85ef885039b5745ae02bf122c8f onto the current feature branch. Shared worker files changed by the installer integration are `base508_monster_bindings.gd` (managed component path selection) and `base508_monster_view.gd` (shared strict-setting inheritance); the incoming `monster.gd` hooks remain unchanged. Future worker changes should retain these integrations. The compressed `monster_contexts.bin` is runtime JSON metadata and is already included by the export/updater filters; the1600 original PNGs remain private.
