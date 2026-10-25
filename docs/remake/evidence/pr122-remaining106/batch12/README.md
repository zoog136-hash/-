# PR122 batch12 — native source construction and actual Main, still HOLD

**498-species work is unfinished. New approvals:0.** Historical392 completions,
394 in-scope runtime bindings and the existing approved production bytes stay
preserved. Remaining106 = CI-wait2 + source-HOLD18 + not-started86. The two
native donor bodies below are UNMAPPED and receive no target/species credit.
Deer/Monk and the older16 HOLDs, including quality follow-up14, remain in the
continuation state. No requirement or source-import threshold was lowered.

## Actual construction and execution

The already-existing Drive source kit was restored, without requesting another
upload. Its pinned26,775,284-byte ZIP SHA is
`99dd0cb2f02da039b56923b9f3b947ed7ef4f73843d7f4e0c0dcdd7006b98a98`.
All45 extracted files match the actual pinned ZIP members. All3,512 native body
RGBA frames reconstruct exactly, including original transparent padding.

The existing A2002 four-part Drive archive was also restored:150,480,291 bytes,
SHA `d5438f74b486e42481ad34badb527794bbda10a591388c2177e580f2af8c34d7`.
Original ZIP/patch CRC,1,700 SPX file hashes,14,534 frame records,14,304 nonempty
RGBA hashes and230 empty records match the earlier source-kit audit. The two
bodies21624/21653 and their six shadow/clothes layers are **two bodies**, not
eight species. This does not supply the other498 actors. Files are read as data;
uploaded executables, DLLs and scripts were not executed.

The mandatory legacy six-archive source-dir check still FAILS on missing
`a1.zip` in that selected directory. Its complete output is retained. The
separately pinned A2002 verification is not presented as a six-archive PASS or
as delivery of all original resources. The public723-atlas/41,442-frame gate
passes and the original delivery ledger is unchanged.

Native source frames were actually assembled into in-memory SpriteFrames and
connected to an isolated candidate in the **real Main** scene, not installed in
the production catalog. Both bodies exercised all8 directions,9 chosen native
roles and0.75/1/1.5 playback ratios. Roles: idle,walk,runL,runR,attack,hit,death,
directional cast and alternate chain attack. Each walk/run track has8 distinct
native RGBA poses; the three gait sets have no cross-role duplicate hashes in
any direction. Running is a separate source sequence, not faster walking.

| Native donor | Main technical checks | Full1280×720 PNG bodies | Real Input directions |
|---|---:|---:|---:|
|21624|91,020|1,976|8|
|21653|92,858|1,976|8|

Godot:4.7.2.stable.official.ed1daf0bf. OpenGL: Mesa llvmpipe software rendering.
Physical GPU and Android device: **NOT_RUN**. Candidate scale keeps X0.90/Y1.00;
original source pixels, regions, native offsets and relative ticks are retained.
Real keyboard movement uses the existing physics/controller and collision shape.
Native donor AI/HP/contact, all-skill compatibility and independent final visual
approval are **NOT_RUN**; these source previews do not satisfy final approval.

Temporal samples use the existing production motion controller at120Hz and
atomic Main readback. They are not wall-time performance recordings. The MP4s
replay those actual Main captures in source order and relative ticks at an
illustrative24tick/s baseline; this is not a measured original-client clock.
Videos preserve the whole1280×720 Main with a separate64px subtitle band.
PNG bytes stay unchanged; CRF22 applies only to the companion video encoding.

The Main renderer script SHA is
`00ecf4a8226dcf8ccc976bb845185bccf6f19aa038591d850669d073f3b0ab13`.
Actual process receipts preserve the exact runner/render hashes used. After
those runs, only the Python source preflight was strengthened: extracted files
must equal the pinned ZIP bytes and walk/run sources must be disjoint. Its
fresh source-only PASS explicitly reports **Main NOT_RUN**. A forged run plus
forged local SHA manifest, a corrupt pinned ZIP and a public output path all
fail before Main. No fresh Main result is invented for that preflight.

## Why these candidates remain HOLD

The project142/411 portraits look related to the donors, but an authoritative
identity mapping has not been established. A limited exact3×3 RGB5 patch search
in native idle frames found no match; it does not rule out rescaling, lighting
or a version difference and is not an identity decision. Do not bind a named
transform based only on a numeric filename or resemblance.

Literal A3 death action8 begins with the terminal physical frame before the
upright frame. Actual Main shows the resulting discontinuity. Native extra
layers also require their real blend semantics; do not assume every clothes
layer is additive. Source ticks/order are preserved as evidence, not silently
reordered to hide the problem. The upstream viewer was read at
`tony1223/PakViewer@fbad69239e3e3c12ec18dfc7722bed284be093cc`; a viewer starting
at frame0 does not establish the original client's transition rules.

Early failures remain: initial GDScript parse failure; a starter transformation
covering the candidate during the first real-input probe; and a fixed diagnostic
crop cutting off some SW death poses. The latter run was stopped with return-15.
The corrected run saves the full Main viewport, retaining the same whole-body
viewport criterion. All failure logs/receipts are stored alongside successes.

## Private delivery, with no public original pixels

Source game art and native Main pixels stay outside the public checkout.
The new evidence folders were checked as unshared, owner-only; no sharing
permissions were granted:

- 21624: https://drive.google.com/drive/folders/17kP7hV4W94rcxJuS3MZ2gPFXMfNHli6I
- 21653: https://drive.google.com/drive/folders/1BpHUx2_aZOyYSE_6uzPOdM9Gzk2LBRu0

The Git manifests preserve every Main PNG SHA/size and the exact archive/part
hashes. Local archives were fully decompressed and every member re-hashed.
At this checkpoint, male60/60 parts are uploaded with all60 remote names/sizes
matched; part001 was actually downloaded and SHA matched. Full remote reassembly
is NOT_RUN. Female61-part transfer is still IN_PROGRESS; do not report it
delivered. The connector's100MB input limit caused a rejected whole-archive/
CRF16-video attempt, so28MiB chunks and an85.6MB CRF22 video are used. Binary
delivery status must be updated from actual transfer results, not local files.

## Resume with the actual Git checkpoint

Read the actual PR122 remote HEAD, `continuation-state.json`, the latest transfer
receipts and the prior full498 roster. Keep45 authored PNGs/85,840,707bytes and
all approved original bindings. Native donors are not new approved species.
Use an isolated worktree and fresh private output directories. For example:

```bash
python3 tools/check_resource_integrity.py --root .
python3 tools/verify_pr122_native_source_archive.py --archive /private/a2002.zip --source-kit /private/kit --output /private/new-native-archive-check.json
python3 tools/run_pr122_native_tick_preview.py --source-kit /private/kit --source-zip /private/TWILIGHT_animation_source_kit_20261013.zip --godot /private/Godot_v4.7.2-stable_linux.x86_64 --output /private/new-native-Main
python3 tools/pack_pr122_native_main_evidence.py --preview /private/new-native-Main --output-dir /private/new-native-delivery
```

Dependencies: Pillow,numpy,zstandard plus `zstd`,`ffmpeg`,Godot4.7.2 and a usable
OpenGL display. All private paths must be outside the public checkout. The source
kit and A2002 already exist in Drive; reuse their recorded IDs/hashes instead of
asking for re-upload. Final approvals require exact-commit mandatory CI and
independent visual review. Do not merge main, force-push, reset or overwrite an
approved asset. Continue genuine missing source matrices while individual
subjects remain HOLD; a checkpoint/CI queue is not completion of this task.
