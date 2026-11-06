# Extract the complete manual distribution once

This optional local helper accepts the exact downloaded Bootstrap ZIP and its
separately supplied ZIP SHA256 and index SHA256. Keep all 62 original ZIP names
in Android Download. A `(1)` suffix is not accepted as a substitute. No ZIP needs
to be unpacked by hand. There is no glob extraction, Drive call, rclone setup,
authorization, source download, resource copy, deletion or automatic retry.

Use a published extractor commit in `TWILIGHT_EXTRACTOR_REF`, then run
`tools/android/extract_manual_sources.sh` with
`--manual-bootstrap-zip-sha256 <ZIP SHA256>` and
`--manual-bootstrap-sha256 <bootstrap.json SHA256>`.
`--project` defaults to `~/storage/downloads/TWILIGHT_Play_Source523_Manual`;
`--manual-archives` defaults to its parent. The Bootstrap basename defaults to
`TWILIGHT_Source523_Manual_Bootstrap_20261106.zip` and can be selected explicitly
with `--manual-bootstrap-zip`. Never confuse the two hashes.

The helper authenticates the Bootstrap ZIP and index, then all 61 exact ZIPs.
Before creating the resource root it checks the full central-directory inventory,
original Bootstrap file pins, producer totals, safe relative paths, encryption,
file types, duplicate files, file/directory collisions, case/Unicode aliases and
space. Only stored/deflated regular ZIP members in the declared resource tree
are supported. Unsupported input stops safely. All archive handles remain open;
their identity/size/time are checked again around each extraction.

The resource folder must be absent, or match this helper's private extraction
receipt in Termux's cache, including root device/inode and both pins. An existing
unmanaged folder, missing old root, unknown file/directory, symlink or changed
complete file stops without adoption or overwrite. Keep that cache receipt to
resume. The journal is outside the project; the only new content inside the root
is `source523_resources`, preserving the existing manual adoption boundary.

Files are created exclusively at their final owned paths, so shared storage does
not need atomic rename support. A partial is not truncated or replaced. Resume
compares its entire existing prefix to the authenticated ZIP before appending.
Complete files must match their declared length/CRC. No file is removed. Receipt
replacement happens only in the private Termux cache. A creation interrupted
before the root receipt is saved fails closed rather than taking over the root.

After extraction, the helper invokes the **unchanged published manual installer
768dd49388c99b8c9e87df9a07d1adbffd6f6fa6**. Its resource/manifest/owner/code guards
run normally before minimal GitHub runtime publication. The existing private
Bootstrap/index and its `installer_commit` remain unchanged. The extractor's
commit is a separate public helper pin, not a replacement resource contract.
No local followup patch or unmerged game code is implicitly adopted.

The current ZIPs occupy 5,416,453,962 bytes and expand to 7,833,739,317 bytes
(121,381 files): 13,250,193,279 logical bytes together. Code, Git, existing caches,
filesystem allocation and temporary app/import space are additional. Before
resource writes, the helper requires remaining declared extraction bytes plus
8,192 bytes per file and a 512 MiB code/allocation reserve. This reserve does not
measure or guarantee final Git/runtime space. The existing installer also checks
actual code staging space. Originals are extracted once in place, never into a
second 8 GB staging copy. Retain ZIPs for the manual installer's verification.

Implementation is statically reviewed only. No phone installation, extraction,
application test, compilation, game, rendering or CI execution is claimed.
