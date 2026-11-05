# Source523 Image/icon connection status

This dedicated Draft is incomplete. The current changes verify private inputs
and compile exact source image references. No original image pixels have been
decoded, installed, connected to gameplay, or newly observed in game by this
work. The 95% actual-use goal remains unverified.

## Fixed scope and evidence

The retained inventory contains 16,180 members. Removing the 1,216 entries
with the specified historical card-pack lineage leaves the assigned 14,964
members: 609,061,968 original encrypted member bytes and 608,934,161 decoded
file bytes in inherited metadata. These measures remain separate. This does
not prove that the assigned files were unused by every other implementation.

Current Image44.dat, Image47.dat, Image48.dat and icon53.dat are additional
inputs. Their combined outer-container size is 32,256,740 bytes; their current
member counts and payload sums remain unknown. Their outer bytes are never
added to the retained-member denominator. Complete current523 file/byte
denominators and actual game-use percentages remain unknown.

Six supplied private input archives were locally materialized and checked for
size, SHA-256 and ZIP CRC. The principal handoff's 27 payload hashes and sizes
also match. Original source files and derived source records stay outside Git.
Original image directory decoding still requires the previously reviewed
decoder and its approved parameters. No keys or parameters were guessed.

## Implemented preparation

- `tools/images/audit_source523_image_inputs.py` verifies the handoff, fixed
  inventory, exact AssetView/AssetType mappings and local original DAT copies.
  Identical copies are deduplicated; conflicting bytes, stale-container
  identities and unsafe paths fail. Optional already-decoded input checking
  verifies original file hashes, format, dimensions and full image decoding;
  it does not install files or establish game rendering/use.
- `tools/images/build_source523_image_references.py` compiles a curated set of
  image roles through `table.field -> AssetView.AssetId -> AssetType.ID ->
  Path + FilePath`, preserving source table hashes and original row indexes.
  Missing source keys and unresolved current members remain explicit. Source
  tables are not changed. Generated output must stay outside the repository.
- The audited image roles include product artwork, mission mini/full/entrance
  art, card portraits, NPC illustrations, pass artwork, Promotion attendance
  artwork, map images/backgrounds and ordered emoticon frames. Icon-type
  item/skill/buff roles remain a separate existing-code handoff boundary.
  The compiler is a metadata preparation tool, not a consumer implementation.
- Emoticon image order follows source `Order`, preserving raw `Delay` values.
  Filename sorting is not used. Delay units, playback formula and repeat
  semantics remain unresolved.

The current compiler finds 98 image fields across 64 tables and 12,898 static
reference occurrences. Deduplicated references cover 3,342 assigned retained
files and 306,255,328 original encrypted member bytes. Another 469 referenced
paths are outside retained inventory: 322 replaced-container references and
147 missing-catalog paths. These are source-reference results; no loading,
inspection rendering, or gameplay-use credit is assigned to them.

## Existing owners and integration boundary

The branch begins from main `1333851bb2eb193a6ac1fc3e3b852787c08994ff`.
It owns only the new tools, tests and this status document. It does not change
UI267, Map222, rest-system services, definition-data tooling, or actor motions.
Sound remains excluded. Test, inactive, closed and user-excluded content stays
in the inventory without being enabled or removed to improve percentages.

UI267's published source pack/player APIs were inspected at
`6c15bd07241ac2b271963815b4b7d49ae3a8394a`. Its pack paths are UI-only and the
existing installed card resolver is base508-only. A future current523 image
pack must have its own verified identity contract and feed existing consumers;
it must not relax either existing pack's identity rules. UI hierarchy, original
animation playback and node assignment stay with the UI owner. Services retain
eligibility, selections, costs/results and confirmed save transactions.

## Validation and remaining work

The two structural suites pass 45 tests. Fixtures are metadata/opaque bytes;
they contain no generated images and provide no original-art evidence.
Both tools also passed against the received original metadata and local DAT
inputs in this checkout. The repository integrity check passes 723 atlases,
41,442 frames and 233,420,026 bytes. Its historical `--source-dir` check remains
blocked by unavailable legacy `a1.zip`; the six current private archives have
their own separately verified hashes/ZIP CRCs and do not replace that ledger.
No complete Godot import, Main/UI execution or original-pixel render was run
for this preparation-only change. Required CI is unrun, not passed.

Run the intake tool with the private source523 package root (containing
`index.json` and `content/`), inventory handoff, compact historical catalog,
and repeatable local original roots. Then run the reference compiler with the
package's `content/` directory. Both require an explicit private output path.
Run tests with `python3 tests/test_source523_image_inputs.py` and
`python3 tests/test_build_source523_image_references.py`.

Remaining inputs and execution work:

- The reviewed image decoder, approved parameters, and exact current member
  identity for the four changed DATs; historical508 records do not substitute.
- Verified original pixels for all assigned leaves, including current identity,
  before implementing image presentation and animation consumption.
- Exact remaining UI/node assignment, MapBG selection and emoticon timing
  contracts. Preserve unknowns instead of inventing layout or behavior.
- Actual item/equipment, skill/buff, shop/package, map screen, mission, card,
  NPC, pass/attendance and emoticon consumer integration, followed by applicable
  display/input/effect/save/restart checks. No full-runtime completion is claimed.

Two separate reference-archive downloads were blocked by HTTP401 in the official
Library helper's discovery stage, before any bytes were transferred. They were
not retried or fetched by another route. This block is separate from the six
successfully received inputs. No CI, workflow/protection changes, merge,
auto-merge or deployment was performed. Commits use `[skip ci]`.
