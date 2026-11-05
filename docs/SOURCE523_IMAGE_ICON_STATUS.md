# Source523 Image/icon connections — Draft PR270

This work connects exact private source523 images to existing presentation
paths. It remains incomplete: no 95% actual-game-use claim is made. The latest
instruction is to connect available originals to actual existing game callers
without starting further tests, runtime/render validation or quality audits.
Missing data relationships may use relevant references with estimates labelled
separately. Later changes remain unverified, and prior evidence is preserved.

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
  The existing sale list likewise retains the selected native physical record
  for its original icon and the shared transfer-selection picture; price,
  quantity, eligibility and sale/save calls keep their existing inputs.
- Existing inventory slots and the detail icon retain the selected physical
  instance's full native523 source record for presentation. The existing native
  identity guard remains required; catalog filtering and item actions retain
  their current records. Slot reuse tracks source-record replacement.
- Data271's read-only item references can supply an image identity without
  installing a game item. The image hub requires the published contract kind,
  read-only/activation/ownership flags and exact ItemClass canonical row SHA
  from the selected image pack. It preserves owner exclusions and consumes
  the existing IconID loader. Incomplete Bonus/reference joins do not become
  invented effects or prevent an independently established image identity.
- Existing crafting result/material pictures use `recipe_definition(...).items`
  for the already selected recipe when that public owner API is available.
  NPC shop rows use the existing quote's `source_reference.item` and declared
  MerchantGoods ItemClassID. Market product pictures retain their own declared
  AssetID. No recipe, supplier, transaction, effect or ownership is admitted by
  these image calls. The data contract is the public Data271 checkpoint
  `6622063ee90806c1c753c695978f586ef7906cc3`.
- The existing compiled source crafting calls also consume their declared
  ItemClass `source_id` directly from the already selected image pack. Recipe
  list icons, the result picture and material pictures use this path while the
  optional Data271 reader API is unavailable. They require the existing
  patch523 recipe identity, preserve zero/missing states without substitute
  images, and use the same original exclusions and presentation loader. Game
  native-item flags are not created. Available owner read-only references keep
  priority in result/material pictures. These direct display calls have not
  been executed or validated.
  Existing NPC listing rows also use this direct pinned ItemClass presentation
  path, retaining the same source exclusions before any optional quote data.
- The existing reward-choice ItemList consumes its already declared
  `reward.item_class_id` for the original image. Its claim metadata remains the
  separate `source_entity_id`; choice validation, quantity and grant/save calls
  stay with the existing supplier. Missing/excluded/unsupported images remain
  empty with their original reason. This display hook is unexecuted.
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
- Existing skill-detail pictures, HUD skill quickslots and active buff icons
  now share the original CSB display adapter using their exact SpellClass or
  BuffClass icon role. ItemClass, SpellClass and BuffClass IDs remain distinct.
  Same-identity mounts are reused without restarting their original clip.
  Buff countdown changes update the existing labels while retaining the icon
  nodes; role changes and removal detach the previous presentation.

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
generated from the image inventory. The received six-scene subsets use the UI
owner's published player dependency recorded below. Other scene packs and their
exact caller bindings remain explicit inputs; absent inputs return an explicit
missing result.
The later warehouse/transfer-selection record and presentation hooks are also
unexecuted and unverified.
The physical-instance inventory slot/detail hooks are likewise unexecuted.
The read-only item-reference image path, crafting/NPC image consumers and
multiple-subset original UI registration are also unexecuted and unverified.

## Received original icon subsets

Two original UI subsets have been received through the official Library
resolved-reference flow and extracted in the consumer environment. Their
existing receipts declare three scenes/nine originals and three scenes/eleven
originals, with dependencies resolved and no rendered/runtime approval. Those
are UI-owner source subsets, separate from the fixed Image/icon inventory above.
Library identities, originals and source-relation documents remain private.

The six original named clip/frame/speed declarations are retained in the private
handoff. The source does not declare repeat behavior. API default `repeat=false`
and a serialized animation name do not establish the original caller policy.
The available source and targeted public searches supplied no game caller
repeat policy. An explicitly selected `estimate_missing_repeat` host option now
allows one pass of a received clip whose source explicitly declares repeat as
not supplied. This is `estimated_single_pass_icon_host`, not an original
LineageM policy. Its result records `original_policy_confirmed:false` and the
existing view-bind trigger. Explicit caller repeat values take priority.
The original clip, source frame range, full Action duration and speed remain
unchanged. The
[Cocos API](https://docs.cocos2d-x.org/api-ref/cplusplus/V3.5/d7/d2f/class_action_timeline.html)
documents caller-controlled looping and end-frame behavior; it does not supply
the original game's missing policy. The skill/buff scene uses its own exact
source roles instead of being assigned an ItemClass identity.

The existing UI267 loader/player and its declared code dependencies are reused
unchanged from published commit `d719912b6b9fdf65b145a559bebc3056d40ef8fa`.
Their source Git blob identities are recorded in
`docs/SOURCE523_UI_PLAYER_DEPENDENCY.json`; no previous file was overwritten.
This is an existing renderer dependency, with ownership retained by UI267.

`register_original_ui(document, root, manifest_sha256)` can retain independently
pinned subsets without replacing other icons' declarations. Each icon selects
the manifest explicitly named by its own source binding. Identity conflicts
fail explicitly, and replacement does not inherit a previous repeat value.
The original UI loader/player remains separately owned. No registration,
render, playback or gameplay run was started to validate this new code.

Actual item/skill/buff image callers lazily load a complete explicitly pinned
selection pair only when a source CSB is needed:

```text
--source523-ui-icons=<private-selection-json>
--source523-ui-icons-sha256=<selection-sha256>
```

The environment equivalents are `TWILIGHT_SOURCE523_UI_ICONS` and
`TWILIGHT_SOURCE523_UI_ICONS_SHA256`. The private selection declares each pack
root and manifest pin plus exact source icon bindings. All packs are prepared
before committing the selection, and estimated playback permission is scoped
to that selection's icons. The private runtime environment file is prepared
but has not been sourced or used to launch a game. These loader, caller and
lifecycle changes are unexecuted and unverified.

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

An additive private runtime-selection handoff contains the explicit six-scene
pack selection, producer-local environment example, source playback declarations
and dependency provenance. It has been transferred to the same existing private
Drive folder without adding sharing permissions or reuploading the 18 base ZIPs.
The environment example has not been sourced, and transfer does not establish
runtime registration, playback or game consumption.

The earlier official Library upload stopped at tools/list HTTP401 before byte
transfer. That path and the two earlier reference-archive downloads were not
retried. The independent public format reference resolved the decoder input gap
without retrying them.

The UI267 caller contract was read at `d719912b6b9fdf65b145a559bebc3056d40ef8fa`; its renderer and
original layout remain owned there. Source-map terrain, rest-system transactions,
definition-data work and Sprite actor motion remain separate owners. Source
CSB icons have an item-slot caller adapter and the received six-scene subsets.
Remaining scenes and original caller policies still require their owner
handoff; the received subset can use the explicitly tagged host estimate. Full
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
| Item CSB icons | Original caller repeat/trigger policy and required node bindings remain unconfirmed; received clips have a separately tagged host estimate; remaining scenes still need source inputs |
| Map-screen images and buttons | Caller-declared current field/screen to original World/ImageInfo identity, original content root/SHA, existing mount, exact image/button node offsets and original map/area selection callbacks; terrain placement is a separate owner |
| Mission and NPC images | Original content root/SHA, exact image node offsets, source-model asset roles and existing action callbacks |
| Pass and attendance images | Original content root/SHA, exact image node offsets and caller-provided season/day/reward-row bindings and actions |
| Emoticons | Original selection/display caller, exact node/asset association and original frame order, timing, repeat and start/stop contract |
| Other source UI images | Exact original root/node declarations and caller-provided typed asset references; a filename category is not a screen contract |

The earlier UI code/state handoff remains distinct from the two newly received
original subsets. Node offsets, loop policies and callbacks still require their
explicit caller declarations. Existing image-pack and Drive-delivery identities
remain unchanged. Reading supplied contracts and materializing their original
inputs are implementation handoff work; no new test or validation was run.

The existing `renewal_map.gd`/`field_minimap.gd` call path consumes the field's
`overview_texture()`. The supplied all-world contract provides exact
`UIMapWorld.LandID`-to-World-to-ImageInfo-to-AssetView relationships, source ratios
and base locations. `scripts/maps/source523_map_image_adapter.gd` now reads that
existing private relationship document with its supplied pin, joins an explicitly
marked mobile field's Land ID, and requires the caller to choose the exact World.
Its apply API passes the original texture to a caller-supplied existing image
node through the current asset loader. It creates no node or coordinate rule.
The API and ownership boundary are recorded in
[`SOURCE523_MAP_IMAGE_HANDOFF.md`](SOURCE523_MAP_IMAGE_HANDOFF.md).

The relationship document and its source manifest were transferred as an
additive input ZIP to the existing private Drive folder. The 18 original ZIPs
and source files remain unchanged. Connecting the current overview still needs
the actual World selection, original target/rectangle and coordinate/input
registration; the field overview is preserved while those inputs are absent.
The new bridge is unexecuted and unverified.

Actual acquisition/display/input/effect/save/restart coverage and deduplicated
actual-use percentages remain unverified. Inventory presence, metadata joins,
loads, component renders and delivery bytes do not count as that completion.
