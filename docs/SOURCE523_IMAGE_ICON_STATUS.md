# Source523 Image/icon connections — Draft PR270

This work connects exact private source523 images to existing presentation
paths. It remains incomplete: no 95% actual-game-use claim is made. The latest
instruction is to continue connection implementation without starting further
research, comparisons, tests or validation. Changes made after that instruction
are unverified; the already-running import and prior evidence are preserved.

## Original inventory and private pack

The completed source inventory contains 101 DATs and 17,278 original images:
14,964 assigned retained members, 1,216 historical card-lineage members, and
1,098 members from changed Image44/Image47/Image48/icon53. The retained scope
remains fixed; it is not a claim that every assigned file was unused elsewhere.

| Component | Files | Original encrypted member bytes | Decoded file bytes |
| --- | ---: | ---: | ---: |
| Assigned retained | 14,964 | 609,061,968 | 608,934,161 |
| Changed current DAT members | 1,098 | 32,198,416 | 32,189,155 |
| This private runtime pack | 16,062 | 641,260,384 | 641,123,316 |
| Whole current image inventory | 17,278 | 680,655,904 | 680,508,571 |

Whole DAT containers total 681,510,173 bytes. Container/directory/footer bytes,
original encrypted member bytes, decoded files and generated import caches are
separate measures. Historical card members stay outside this pack and its
assigned-scope totals. Excluded/test/closed content is preserved as source data;
no gameplay eligibility is enabled to increase a percentage. Sound and the
separate actor/Sprite lane remain excluded.

Strict decoding completed before the latest no-new-validation instruction:
101 containers, 17,278 images, zero strict failures, duplicate paths or payload
gaps. Retained members matched their prior source catalog. All images passed
full decoding; PNG chunks passed CRC checks. Formats are 17,195 PNG, 79 JPEG
and four BMP, including original suffixes that differ from their actual format.
Exact current DAT bytes establish the changed-member identities.

The independent decoder is grounded in the supplied public
[PakViewer source](https://github.com/tony1223/PakViewer/blob/fbad69239e3e3c12ec18dfc7722bed284be093cc/src/Lin.Helper.Core/Dat/DatFile.cs),
Git blob `3fa549cc17de9853dbc35d0263edce670f3e2f7a`. Runtime parameters are an
explicit private input. No parameters, pixels, source rows, private links,
Library identities or saves are included in Git.

## Connected code

- `decode_source523_image_dat.py` strictly extracts original file bytes.
  `build_source523_image_pack.py` copies exact originals and source metadata
  to an explicit private destination; neither creates replacement art.
- `source523_image_pack.gd` opens a manifest pinned by SHA-256. It checks exact
  AssetView/AssetType/Icon and native class bindings and returns original
  textures with provenance or an explicit missing/unsupported result.
- `source523_image_assets.gd` owns an independent, explicit selection. Existing
  base508 card and actor pack settings are unchanged. ItemClass/IconID is read
  before legacy catalog canonicalization, preserving physical record IDs.
- Inventory, equipment, item detail, lists, quickslots and drag views consume
  the shared item resolver. Collection and protection views use that resolver
  for source523 records. Selected original icons bypass authored rarity motion,
  foreground extraction and fallback artwork. Ground art stays a separate path.
- Warehouse entries retain the same authoritative item record used by their
  list icon. The existing transfer-selection picture consumes that record or
  the exact physical instance record through ItemVisual, preserving source
  identity, exclusion metadata and the original-CSB caller when available.
  Empty/reused selections clear the previous presentation. Transfer/sale
  transactions, quantities, ownership and physical IDs remain unchanged.
- Existing inventory slots and the detail icon retain the selected physical
  instance's full native523 source record for presentation. The existing native
  identity guard remains required; catalog filtering and item actions retain
  their current records. Slot reuse tracks source-record replacement.
- Skill browsing and skill quickslots use exact public host-to-SpellClass
  bindings, then the source IconID. Active buff rows use explicit native
  BuffClass OnIconID. ActivateIconID and OffIconID remain distinct roles;
  missing/ambiguous native relations do not borrow host rune artwork.
- Current card detail/list/awakening portraits use their declared source asset
  roles in the existing image controls. Source originals bypass host grayscale
  generation and unverified portrait composition.
- Existing source-shop product rows consume MarketPurchase_Korean.AssetID;
  NPC goods use ItemClass.IconID, and currency rows use Currency.AssetID.
  Source filters, prices, eligibility, transactions and saves are unchanged.
- `source523_source_ui_images.gd` binds a structured source-UI asset reference
  to an existing TextureRect/Sprite2D/NinePatchRect. It leaves source hierarchy,
  position, clipping, color/blend tracks, input and service callbacks to the UI
  owner. It creates no widgets, layout, clock or animation engine.
- `source523_original_ui_icons.gd` connects the existing item-slot lifecycle to
  the separately owned original UI pack/player. Scene identity must match the
  current ItemClass/Icon/AssetView path and the supplied scene binding. Original
  pack and scene hashes, clip name and repeat policy remain explicit inputs.
  Slot reuse, clearing and disposal detach the old source scene.

Selection uses a complete explicit pair:

```text
--source523-images=<private-pack-directory>
--source523-images-sha256=<manifest-sha256>
```

The environment equivalents are `TWILIGHT_SOURCE523_IMAGES` and
`TWILIGHT_SOURCE523_IMAGES_SHA256`. Unselected packs preserve existing behavior;
a selected pack's missing source image is not replaced with authored art.

## Existing evidence and limits

Before the latest instruction, 131 Python structural/rejection tests passed
(36 intake, nine references, 67 decoder, 19 pack), along with the Godot pack
contract and real PNG/JPEG/BMP reader probes. The focused item presentation
check passed 41 checks against the real private pack. These are component,
source and texture checks, not full gameplay-use evidence. Repository resource
integrity passed 723 atlases / 41,442 frames / 233,420,026 bytes. The historical
source-dir audit still lacks legacy a1.zip; current source archives have separate
size/SHA/CRC evidence and do not replace that old ledger.

The later skill/card/shop/source-UI binding changes have not been executed or
validated. The newly written skill/buff test is preserved and unrun. No new
validation is started under the latest instruction. Required CI is unrun, not
passed. Commits use [skip ci]; no workflow/protection changes, merge, auto-merge
or deployment are performed.

The item CSB lifecycle connection and `configure_original_ui(document, root,
manifest_sha256)` handoff are also unexecuted. The latter accepts the existing
`source_icon_scenes` document (`patch523-original-ui-icon-scenes-v1`) and opens
the UI owner's pack before replacing scene bindings. No scene/clip bindings are
generated from the image inventory. The UI player's code and exact scene pack
must be installed separately; absent inputs remain an explicit missing result.
The later warehouse/transfer-selection record and presentation hooks are also
unexecuted and unverified.
The physical-instance inventory slot/detail hooks are likewise unexecuted.

## Explicit original dummy-image exclusions

`UIBuffCardDummyImagePath` is the original declaration used for this exclusion.
Its full-source-index identity is 42 declaration rows / 4,577 bytes, SHA-256
`31d596dd086deac145dd7db8e7d24bc4db4c2cc6f558577a1f0871e460286a41`.
The reader consumes the exact table's `AssetID` entries and excludes their
canonical typed paths from image connection, including exact path aliases.
It records the original table hash, row/index, declared asset ID and exclusion
reason in provenance and returns `source_dummy_excluded` with no texture.

Item and card consumers preserve that result in their existing status metadata
and clear the image. Normal item/card identity, ownership, eligibility and
transactions remain with their existing services. The existing TestItem rule
is a separate source declaration. Names, missing pixels and missing caller
inputs do not establish a dummy classification.

The source index already pinned by the private base manifest identifies this
table. The exact original `source/UIBuffCardDummyImagePath.json` is an additive
private supplement; the base manifest, original images and 18 delivery ZIPs
are preserved. If the source index declares the table but its exact bytes are
unavailable, the new reader cannot open that pack for image connection. The
builder includes the declaration table when present in the original index.

All inventory rows and original byte denominators above remain fixed. Excluded
dummy resources remain preserved, and exclusion does not count as gameplay
use. Unique excluded-file/byte totals have not been newly measured. These code
changes and the supplement have not been executed or newly validated.
The additive declaration ZIP was delivered to the same existing private Drive
folder. No base ZIP was reuploaded and no sharing permission was added.

## Delivery and remaining connections

The exact private runtime pack and 18 ZIP delivery parts are preserved locally.
All 18 parts (773,979,412 archive bytes) and the delivery manifest were transferred
to the user's existing private Google Drive delivery folder. Transfer metadata
records the existing parent and unshared status; no sharing permissions were
added. Archive transfer does not establish installation or gameplay consumption.
Private destination and file identities remain outside Git.

The earlier official Library upload stopped at tools/list HTTP401 before byte
transfer. That path and the two earlier reference-archive downloads were not
retried. The independent public format reference resolved the decoder input gap
without retrying them.

UI267 was read at `6c15bd07241ac2b271963815b4b7d49ae3a8394a`; its renderer and
original layout remain owned there. Source-map terrain, rest-system transactions,
definition-data work and Sprite actor motion remain separate owners. Source
CSB icons have an item-slot caller adapter but still require the existing UI
player's exact scene closures and explicit clip/repeat bindings. Full
mission/NPC/pass/attendance/map-screen/emoticon consumption still needs the
corresponding existing original UI callers and exact node/selection/timing
contracts. The adapter API does not establish that those consumers are active.
No new UI layout, image, Sprite frame, fallback or animation timing is invented.

### Current caller contract and required handoffs

The current UI267 caller contract was read from
[`docs/ORIGINAL_UI_ITEM_CONSUMER_CONTRACT.md`](https://github.com/zoog136-hash/-/blob/d719912b6b9fdf65b145a559bebc3056d40ef8fa/docs/ORIGINAL_UI_ITEM_CONSUMER_CONTRACT.md),
Git blob `67fdf09dd276ab9fcfaa7e84e82a1c714872e6e3`. Its strict player accepts
`configure(pack, member, false, bindings)`, followed by the caller's exact
`play(clip, repeat)`. It has no completion signal. `source_nodes` is keyed by
exact original CSB offsets; names or suffixes do not establish node identity.

The existing `UI.apply_item_visual` and ItemVisual caller path accepts an
optional `original_ui_bindings` dictionary and forwards it to this strict
player contract. The caller supplies exact source offsets and existing
handlers/values, including named callbacks and original frame-event handlers.
No binding, action reference, callback name or event meaning is generated.
The UI owner retains input, timeline/event dispatch and service-session
lifecycle. Nonempty bindings require the corresponding player API; they are
not discarded for an older player. This forwarding is unexecuted and does not
register a screen or establish new original-data consumption.

The UI-owned runtime presenter additionally accepts explicit content routes,
an existing original-coordinate mount and a caller binding factory. That API
does not supply a screen-to-data mapping. UI267 retains ownership of that
presenter, HUD registration and renderer; this lane does not recreate them.

| Target | Required original input before further connection |
| --- | --- |
| Item CSB icons | Current private UI pack identity and manifest pin, exact scene SHA, original clip/repeat binding; corresponding UI player code |
| Map-screen images and buttons | Caller-declared current field/screen to original World/ImageInfo identity, original content root/SHA, existing mount, exact image/button node offsets and original map/area selection callbacks; terrain placement is a separate owner |
| Mission and NPC images | Original content root/SHA, exact image node offsets, source-model asset roles and existing action callbacks |
| Pass and attendance images | Original content root/SHA, exact image node offsets and caller-provided season/day/reward-row bindings and actions |
| Emoticons | Original selection/display caller, exact node/asset association and original frame order, timing, repeat and start/stop contract |
| Other source UI images | Exact original root/node declarations and caller-provided typed asset references; a filename category is not a screen contract |

The known UI Library handoff is player code/state, not the private original CSB
pack. No original pack, node offsets, clip names, loop policies or callbacks are
inferred from that identity. Existing image-pack and Drive-delivery identities
remain unchanged while those inputs are pending. Reading this supplied caller
contract is implementation handoff work; no new test or validation was run.

The existing `renewal_map.gd`/`field_minimap.gd` call path consumes the field's
`overview_texture()`. The supplied all-world contract provides exact
World-to-ImageInfo-to-AssetView relationships, source ratios and base locations.
Connecting that contract to the current screen requires its caller-declared
native World/ImageInfo identity and original map-screen coordinate/input
contract. The current field overview remains preserved while those are absent.

Actual acquisition/display/input/effect/save/restart coverage and deduplicated
actual-use percentages remain unverified. Inventory presence, metadata joins,
loads, component renders and delivery bytes do not count as that completion.
