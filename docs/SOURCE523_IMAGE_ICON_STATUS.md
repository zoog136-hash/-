# Source523 Image/icon connections — Draft PR270

This work connects exact private source523 images to existing presentation
paths. It remains incomplete: no 95% actual-game-use claim is made. The latest
instruction is to connect available originals to actual existing game callers
without starting further tests, runtime/render validation or quality audits.
Missing data relationships may use relevant references with estimates labelled
separately. Later changes remain unverified, and prior evidence is preserved.

## Complete-client source mode (2026-11-09)

The earlier handoff is no longer required. `client523_image_inputs.py` builds
the builder inputs directly from the complete 523 client: every
`Client/Data/Image*.dat` and `icon*.dat` listed in the 523 `files_info.json`
is checked against its SHA-1 and size there, then strictly decoded by the
existing decoder. The decoder summary carries `source_mode =
client523_files_info` and one component, `client523_files_info_verified`.
`build_source523_image_pack.py` accepts that mode without an inventory: each
member must carry the matching container SHA-1/SHA-256/size identity proof,
and handoff retained/changed identities cannot be mixed in.
`--hardlink-originals` links the verified originals into the pack on the same
filesystem instead of copying them. The runtime accepts the new component; the
manifest is still pinned by SHA-256 and lookups stay exact-path.

Measured on the private pack built this way (no images in Git):

| Measure | Count |
| --- | ---: |
| Containers SHA-1/size verified against files_info 523 | 101 / 101 |
| Strictly decoded originals (PNG 17,195, JPEG 79, BMP 4) | 17,278 |
| Strict failures | 0 |
| Pack members (previously 16,062 retained + changed) | 17,278 |
| AssetView image-type rows resolving to a verified original | 17,148 / 17,376 (98.7%) |
| AssetView image-type rows with no current member | 228 (1 differs only by case) |
| Icon rows: verified / CSB / missing / zero sentinel | 10,178 / 182 / 60 / 54 |
| ItemClass non-zero IconID: verified / CSB | 34,205 / 483 |
| SpellClass non-zero icon roles: verified / CSB / sentinel | 4,288 / 177 / 1 |
| BuffClass non-zero icon roles: verified / CSB / sentinel | 5,101 / 1 / 5 |

No ItemClass, SpellClass or BuffClass icon reference points at a missing
member; the remainder is source CSB (UI animation, owned elsewhere) or the
source zero sentinel. Matching stays exact: the single case-only difference is
reported, not folded. The real-pack Godot checks for items (41) and
skills/buffs (2,166) pass against this pack; the item probe skips source
`TestItem` rows, which the resolver already excludes.

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
- The existing enhancement list and selected target/scroll pictures retain the
  selected physical instance's native source record for image calls. Empty
  targets detach the previous scene. Enhancement references, eligibility,
  chances, debits and saves retain their existing inputs.
  The existing original-equipment information selectors also use the equipment
  book's explicit ItemClass identity for their equipment/scroll row icons,
  keeping physical selection IDs and action inputs separate.
- The selected-loot pickup button consumes the selected drop's native item
  record through the image loader. Selection changes and cancel clear its icon
  and provenance. This is an item UI icon; ground artwork is unchanged and
  still needs its own source-declared ground asset role.
- Monster-book reward-use and item-choice buttons consume complete original
  ItemClass rows matched against the pinned image pack. The owning cumulative523
  record and snapshot marker are preserved; no native-item flag is invented.
  RewardType, claim IDs and use actions remain with their existing service.
  The same supplier-qualified record now reaches the existing shared item
  resolver and selected-loot icon path. Its original supplier receipt must pass
  the existing contract, and its full ItemClass row must match the selected
  image pack. The strict native-item identity check is unchanged. Image metadata
  retains the caller's cumulative snapshot separately from the current image
  table identity; name aliases and gameplay flags are not created.
  Growth reward records and pending-use quest reward records likewise retain
  their producer's original shape and raw ItemClass row. The shared display
  route requires the exact producer identity plus full canonical row equality.
  The inventory physical-record image helper forwards these selected-pack
  presentations without changing catalog filtering, input, use or ownership.
- The existing warehouse/sale automatic-target registration button consumes
  the already selected row's preserved source record. Clearing the selection
  clears its image metadata without changing automatic inventory rules.
- Existing level-growth registration and unambiguous item-reward buttons,
  including their existing confirmation buttons, use their declared source
  ItemClass relation. Multi-item claims do not choose a representative image.
  The existing spell-group payment selector uses the same declared ItemClass
  payment IDs as its quote provider; SpellGroup IDs remain separate.
- Dungeon recharge-stone rows and their existing recharge/purchase buttons use
  the provider's original ItemClass row. Expedition storage rows, withdrawal,
  box-opening and exact completion-reward buttons use their existing ItemClass
  records and settlement view. No reward draw or claim is executed by these
  image calls. Missing/excluded/CSB states retain texture-free evidence, while
  clearing a selection removes its previous icon and evidence.
- Existing fishing rod/equipment lists and purchase/storage/use/transfer
  buttons now consume their declared ItemClass identity or preserved full row.
  Death recovery's existing item/certificate buttons use the ItemClass keys
  already established by the recovery service. Currency, Fish, territory and
  tournament identifiers are not promoted to item or image identities. These
  image calls do not change purchase, opening, recovery or persistence.
- Existing equipment-collection candidate rows use the same physical instance's
  preserved source record. Automatic inventory rule/held selectors use their
  declared ItemClass field, and actual equipment-category candidates use the
  saved record of the selected physical ID. Candidate selection/registration
  metadata, filters and sale rules are unchanged.
- Existing emblem/half-elixir recharge/reset controls, guardian skill controls,
  totem material/reset/craft controls and title donation controls consume the
  original item or spell role already used by their owning action. Confirmation
  buttons retain the same identity. Group IDs, card IDs, Bonus IDs, multi-item
  candidates and name-only costs do not become guessed image identities.
- NPC attack/environment-buff ItemList rows consume their already supplied
  full SpellClass/BuffClass rows after canonical row and namespace checks.
  TestSpell/dummy exclusions remain applied. Unsupported CSB entries stay
  missing because those ItemList rows have no original scene target; no
  replacement node is created.

The existing NPC shop's source-qualified consumable/ammunition records also use
their provider-declared `source523_shop_item_id` in the ItemClass namespace.
Their normal inventory/shop/quickslot calls reach the same image loader without
inventing a native flag or rewriting an absent snapshot. The strict native
predicate remains unchanged; source image lookup does not alter buying, use,
ammunition effects or ownership.

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

## Final asset selection

The latest user instruction excludes the previous card and monster packs from
final asset use. This image lane's prior card portrait/atlas entry points now
return no legacy-pack pixels, including cached atlas textures and old decorative
card surfaces. Current523 card roles continue through the new image pack. Missing
current assets do not request the previous pack or promote it to final artwork.
The existing card loader/ABI, old packs, metadata, code and saves are preserved.
Actor/monster Sprite selection remains with its existing owner; this image pack
does not replace or declare completion of that separate input.

The new image pack is independently selected and needs no old card/monster
graphics pack. Its declared dummy table supplement is required alongside the
base delivery. Original CSB subset data is a separate conditional dependency
for those scene icons; a selection-metadata ZIP alone does not contain that
source data. Optional map relations likewise do not supply map-screen nodes,
coordinate registration or automatic World selection. New caller and final-use
policy changes remain unexecuted and unverified.

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
| Map-screen images and buttons | UI267's published map caller and RefCounted-field correction, map owner's post-merge registration/input consumer, and their explicit private selection; see the map handoff below |
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
and source files remain unchanged. UI267 now publishes the original map target,
explicit row selection and native image-pixel ABI at
`44a3f960a8c185d1f2cdc9878dfa4b2e6147aa05`, with the actual RefCounted-field
boundary corrected at `2c970ee1ea5a7a0009b14623447c7103f6633b0b`.
The map owner's post-merge consumer at
`d01758db57d46d2b7a57dafbbf6f4880daf8118e` owns registration, context, input,
its explicitly labelled OWN coordinate policy and existing movement calls.
Integration269 includes those five follow-up files at
`b37e5b941d189351906a4a60e411ad1d07566aeb`. The image adapter accepts the
actual field Object and returns the existing original image and source relation
provenance; it adds no second HUD registration or movement implementation.
Both owner code changes, their original private packs and explicit runtime
selections must be integrated. This connection remains unexecuted and unverified.

### Additional existing gameplay image calls

Existing card fusion rows/material pictures, reveal candidates/results and
option-awakening result pictures now use the shared current-source card
presenter. The existing reveal caller forwards original candidate records through
the stage to each picture instead of supplying unidentified old image paths.
Current cards keep their declared portrait/list asset roles and source IDs;
missing current artwork does not select the previous card pack. Existing result
order, candidate shuffle/limit, frame timing and award/save behavior are preserved.

The existing shared item presenter additionally accepts the restoration,
wisdom, skill-book and ticket shop producers' explicit ItemClass declarations.
The symbol-material producer retains its whole original ItemClass row for the
same canonical-row presentation check. No native execution flag, missing snapshot
or gameplay identity is manufactured for these display calls.

Protection use/craft buttons use their actual ItemClass/ItemCraftOutputView
output. Source-shop reward selectors and claim buttons join the declared
cumulative reward through RewardType before treating RewardClassID as ItemClass.
Single-item stored orders use their provider's explicit unit-4/class_id relation;
bundles and other reward types receive no invented representative image.
The existing skill-awakening candidate list consumes its complete source_spell
row through the shared SpellClass IconID reader. A label-only awakening book
does not gain a fabricated image control or action-button image role.
Existing recovery/progression skill-setting selectors reuse the shared pinned
host-skill-to-SpellClass IconID binding. Their numeric inputs and saved policy
values are unchanged. ItemList and OptionButton hosts retain missing/unsupported
CSB evidence where no original scene target is supplied.

The existing ItemCraft material-candidate OptionButton now displays each
candidate's declared ItemClass icon, retaining the separate material row ID used
for selection. The selected reward's existing confirmation button reuses that
row's source image and evidence; source entity IDs remain transaction metadata.
The NPC policy's existing BuffClass and explicitly typed drop-item selectors
likewise use canonical source icons without changing their selected targets.

The actual native card-catalog page now calls the current card presenter directly
for its declared list role. Missing or excluded current art clears that row's
picture and keeps its source status instead of loading the old image_path.

Existing remembered-location confirmation buttons show the selected source
scroll or original skill's icon. The travel quote remains the authority for
costs and movement; job-only or unqualified records supply no original image.
Guardian skill-browser cast/registration buttons use a single current-level
source spell reward. The existing live quickslot image call additionally uses
`Source523SkillImages.describe_guardian_skill(existing_record, world.growth)`.
This reader requires the existing `TWILIGHT_GUARDIAN523` record and its exact
`guardian:<node>` producer identity, one current-level spell reward, and the
shared complete-canonical-SpellClass check. It does not reinterpret that ID as
an `lm_*` binding. UI267 may reuse this read-only image API on its existing
quickslot targets; image playback remains with its shared player. Existing
registration IDs, cooldowns, costs, actions and saves are preserved.

Expedition-issued inventory items now retain their original ItemClass row in
the shared presenter. Their exact issued ItemClass/bless/enchant key remains
separate from ownership and consumer admission. The selected image pack still
requires full canonical ItemClass equality and its original exclusion rules.
The equipment window also preserves the source record from the same equipped
physical instance ID when its presentation snapshot omits that identity.
The existing skill-awakening book producer's preserved base508 ItemClass row
uses that same complete-current-row equality route in inventory and shared
item views. A changed or incomplete row remains unavailable. Its `m508:item`
identity and gameplay snapshot are retained; image bytes come only from the
selected current source pack, with no old card graphics dependency.

Existing expedition card supplements retain a complete original BuffCard row
without the catalog's structured source_ui_assets. The current card presenter
now consumes that issuer's exact card/deck/grade identity and the original
DisplayBaseAssetID/IllustrationAssetID/HidedIllustrationAssetID declarations.
Existing structured role declarations retain priority. Asset IDs resolve through
the current original-image pack; no card ID or filename substitutes for them.
This records the preserved supplier row as input provenance, not a new canonical
BuffCard-table validation by the image pack. Missing, zero, excluded and
unsupported assets retain their own status.

The existing TJ coupon selector and selected-coupon action consume the pinned
producer's complete ItemClass rows through the shared canonical item reader.
Its success/failure card lists consume that producer's original BuffCard
DisplayBaseAssetID, keeping the independent candidate card ID and deck intact.
Original ZIP identity belongs to the existing TJ parser; the image pack validates
the selected asset and original bytes. This adds no candidate, failure history,
coupon activation, redemption rule or save change.

The expedition's existing owned-card selection list also uses the opened source
catalog's exact BuffCard ID, actual spot deck and declared DisplayBaseAssetID.
Its existing identity metadata and dispatch inputs stay unchanged. The image
metadata retains both the source catalog's selected pack pin and the image
loader's provenance. A loaded source image removes the old missing-image suffix
from that row's text without rewriting its source definition-only marker.

Existing mastery operation/confirmation buttons and the reset-payment selector
now display the actual quoted payment image. Ordinary Currency rows supply only
their declared AssetID. The existing ticket definition and point-purchase
material supplier instead supply their complete ItemClass rows to the current
canonical item reader. Currency IDs and weapon/group IDs are not ItemClass
aliases. Missing fields remain unavailable; costs, payment choice, quotes,
execution and saves are unchanged.
The existing Orim preparation buttons now read their single matching original
OrimsTrailBuff.BuffClassID declaration and the current canonical BuffClass
OnIconID consumer. No ItemClass/Spell ID alias or partial raw buff row is made.
The existing reroll button has no such source buff image. Original declaration
and loader evidence are retained without changing purchase or buff behavior.

These are written caller connections, not observations of game consumption.
No additional tests, execution, rendering, CI, source recount or quality audit
was performed for these changes.

### Original inventory and quickslot caller handoff

UI267's published caller at `87eaa3e809ce02d9a63179630aaff37cb23e09d8`
uses this lane's existing image APIs on its actual original target nodes:

- Inventory Common_Slot15012: the bag's existing `_item_visual_record(reference,
  fallback)` preserves the selected physical record, followed by
  `source523_image_assets.describe_item(record, title)`.
- Quickslot Slot_Skill18488: item records use `describe_item`; existing skill
  records use `describe_skill`; guardian records use
  `describe_guardian_skill(record, world.growth, "IconID")`.

The exact public contracts are the owner's
[inventory ABI](https://github.com/zoog136-hash/-/blob/87eaa3e809ce02d9a63179630aaff37cb23e09d8/docs/ORIGINAL_UI_INVENTORY_CALLER_ABI.md)
and
[quickslot ABI](https://github.com/zoog136-hash/-/blob/87eaa3e809ce02d9a63179630aaff37cb23e09d8/docs/ORIGINAL_UI_QUICKSLOT_CALLER_ABI.md).
The owner requires an actual Texture2D, `route:source523_images`,
`status:original_linked`, `original_bytes_unchanged:true` and the existing
format/provenance before its source Sprite upload. This lane's existing
supplier-qualified item, skill and guardian descriptors supply that contract;
no second source-slot renderer or identity join is added.

The normal-four candidate and the later expanded-eight/quickslot candidate are
separate original pack inputs, preserved alongside canonical v5. Their source
roots and manifest selections remain explicit installer inputs; neither changes
the user's selected pack automatically. The original row/page/gesture/state
implementation remains UI267's. Additional inventory rows and full-screen
acceptance are not established by image availability alone.
The native inventory/quickslot controllers require that owner's current code;
this lane's earlier icon-player dependency snapshot is not the complete main-UI
consumer. Its renderer files remain unchanged by this handoff.

The later UI267 combined-v6 contract at
`a8c6ed6a8b2d2d6f3b62fa1c76c7d0d20a29b966` supplies one main-UI composition
for retained main/map, inventory, quickslots and equipped/locked source markers.
Its `twilight-main-original-ui-composition-v1` selection contract records the
retained v5 base. It uses the existing single `--source-ui`/`--source-ui-sha256`
or `TWILIGHT_SOURCE_UI`/`TWILIGHT_SOURCE_UI_SHA256` pair. The image/CSB-icon
selection and map consumer remain independent inputs; no second per-window
main-UI selector or automatic cfg rewrite is added. The earlier candidates and
v5 remain preserved. This composition is source input, not whole-560 completion.

The later UI267 native-CSB boundary is published at
`8486e6f59358d0066baad2163ff428cda6ed6d31` in
[ORIGINAL_UI_NATIVE_ICON_SCENE_ABI.md](https://github.com/zoog136-hash/-/blob/8486e6f59358d0066baad2163ff428cda6ed6d31/docs/ORIGINAL_UI_NATIVE_ICON_SCENE_ABI.md).
The HUD's existing `_ready()` now calls this lane's
`source523_image_assets.bind_native_original_icon_scenes(self)` once. That
function registers `native_original_icon_scene(info, context)` through the
owner's `bind_original_icon_scene_provider` when installed. It adds no native
UI methods or renderer files; integrating the current UI owner code remains
required. This single call is the shared HUD-file integration seam.

Both native and existing TextureRect requests now share the same canonical
consumer, Icon, AssetView, original path and selected CSB-pack resolver. Native
descriptors contain that opened pack and exact original member/manifest/CSB
identity. Their target must match all four identity fields of the actual
`source_slot_contract`. UI267 retains scene preparation, original Sprite
attachment, source transforms, same-player reuse, teardown and all input.

Per-icon `source_icon_scenes.icons[icon_id].native_registrations` supplies an
array of explicit declarations with these fields:

- `registration`: `space:authored_sprite_anchor`, actual original
  `source_basis`, boolean `original_registration_confirmed:true`, and
  `target` containing the exact `member`, `source_sha256`, `manifest_sha256`
  and `node_offset` supplied by the actual source slot.
- Optional `bindings`: the existing strict source-player bindings.
- Optional `playback`: an exact unique original `clip`, boolean `repeat`,
  `original_repeat_declared:true` and `original_policy_confirmed:true`.

Exactly one declaration must match the actual target. Registration evidence
must establish the original client's relationship, rather than merely name
the slot or restate an identity root. The received scene-selection document
does not supply those per-icon native registration declarations. They remain
`source_scene_original_native_registration_pending`; no confirmation flag or
new source evidence is manufactured. The full native consumer contract is now
available; this is a narrower missing source-registration input.

Omitting native playback retains the strict player's serialized source state
stopped, without adding seek/play/loop. Declaring a clip with unknown repeat
remains pending. The separately labelled TextureRect single-pass estimate is
never promoted into native original playback. No replacement nodes, source
geometry or animation policy are inferred. Missing/dummy/test assets retain
their original state; old samples and previous packs are not source success.
Candidate receipt and source-node declarations are not executed presentation,
game consumption, a new source inventory or a 95% usage result.
The native provider and HUD registration changes are unexecuted and unverified;
no additional tests, game execution, rendering or CI were started.

UI267 subsequently published the exact original component/hash/node, authored
anchor/position/size, ancestor transforms and attachment frame at
`dca051179a94e2b2150575904278fd9addb63604` in the same
[native icon ABI](https://github.com/zoog136-hash/-/blob/dca051179a94e2b2150575904278fd9addb63604/docs/ORIGINAL_UI_NATIVE_ICON_SCENE_ABI.md).
Its additional `stable_component_target` and `ui_attachment_frame` accompany
the existing four target identity fields; the current provider uses that exact
runtime target. The selected UI composition's manifest pin remains separate
from its stable component/hash/node identity. The existing source and target
transforms are not applied again by the image provider.
Both halves of the handoff are now present: the selected six CSB identities,
original roots and clips, and the actual original UI slot values. The missing
relation is specifically that CSB root origin's registration at that authored
Sprite anchor. Neither a known slot position nor an identity source root
confirms it. The private handoff preserves both endpoints without altering the
selected pack or setting a fabricated confirmation flag.

The existing Halphas charging start/release buttons now display the exact
executing skill's original `IconID`. Start reads the same existing
`record_for` result as `combat.start_charge`; release uses the preserved
`combat.charge.skill` record. Rebuilding/updating these existing buttons clears
their previous image metadata, and cancellation clears the inactive release
image. This is a skill-display role, with no ActivateIconID effect, new node,
playback, cost, charge-state or cast change. This hookup is unexecuted and
unverified.

The existing auto-hunting destination move button also consumes the selected
entry's original `Currency.AssetID`, the same field the pinned schedule provider
returns as `currency_asset_id` for that move request. The existing landing
selection clears the prior icon and retains the schedule/currency/teleport
source context, landing-link identity and provider/source pins without a texture
in its metadata. Currency IDs remain payment IDs. Missing, zero, excluded and
unsupported assets retain the existing loader result. Region selection, movement
assessment, costs, coordinate policy, settings and saves keep their existing
calls. This image hookup is unexecuted and unverified.

The existing skill browser's learn, use and quickslot-registration buttons now
consume the same selected skill record and canonical SpellClass `IconID` as
their existing source list/detail image path. Selection changes and an empty
filtered list clear the previous icons and texture-free image metadata. The
lookup runs on selection, outside the existing cooldown polling loop. Skill
learning, casting, registration eligibility, preview and save calls retain
their existing records and behavior. Book and reagent controls are separate
item roles and receive no guessed skill or representative-item image. This
hookup is unexecuted and unverified.

The existing source-shop purchase button and its existing confirmation button
also retain the selected product/NPC listing's already resolved original icon
and texture-free image evidence. An owner-quoted NPC exclusion or identity
result updates the same selection image and action image together. Clearing or
changing a selection removes the prior presentation; dismissal frees the
existing confirmation button. Product quantities, quote/transaction arguments,
IDs and owner exclusions retain their existing behavior. This adds no category
representative image or second image lookup. These action hookups are
unexecuted and unverified.

### Explicit NPC illustration consumer

The held original NPC definition declares `NpcClass.IllustAssetID`. This is an
AssetView key, resolved through that row's actual AssetType and literal path.
It is not restricted to the `Image/NPC` asset type. NpcClass IDs, actor Sprite
IDs, names, `UINpcClassAssetMapping.ScreenMessageImgAssetId` and
`ImmediatelyCombinationImgAssetId` remain separate identities/roles.

The existing NPC skill inspector now passes each existing NPC selector row's
exact `NpcClass.ID` and its original `IllustAssetID` from the pinned NPC catalog
to the shared original-image resolver. Its existing OptionButton receives the
resulting texture; source row, snapshot/archive and declared field remain in
texture-free metadata. Switching to the existing Land/environment selector
clears the NPC images and does not interpret Land IDs as NPCs. Zero, absent,
excluded and unsupported assets retain their own result, without another image.
The image pack validates the asset and original bytes; it does not claim a
canonical NpcClass-table check. The inspector's IDs, attack selection, combat,
effects, spawning, input and saves retain their existing behavior.

This establishes a source-backed illustration role and an existing selector
consumer, not every NPC portrait or actual game-use counts. The installed
source-NPC dialogue records use L1J identities; the current resolved model does
not supply an authoritative current523 `NpcClassID` relation. The original
`NpcDialogue_All` Sprite4912 was outside the earlier published dialogue
text/button scope. The later UI267 receiver/v14 contract below now supplies
that original target; the typed caller identity remains an input. The source
editor preview is not substituted. NpcInteraction arguments
are not interpreted without their missing type contract; a DescId or text/name
match is not a dialogue/portrait relation.

This NPC selector connection is unexecuted and unverified. No additional tests,
game execution, rendering, CI, source-byte audit or original pixel creation was
performed.

The later UI267 NPC portrait receiver at
`3b9821b10096667449eb34b4aa1fe015095b6c67` supplies the original Sprite4912
boundary and v14 external-pixel scope. `source523_npc_images.gd` now owns the
shared pinned-NPC-row/IllustAssetID resolver used by the existing NPC selector
and its new `dialogue_image(context,target,catalog=null)` callback. It returns the
receiver's exact static-original descriptor with the existing source status and
provenance. `bind_dialogue(hud,context_provider,catalog=null)` registers it through
the owner's published HUD API when integration269 provides the real current
dialogue/mobile-NPC context. No default or name-based context provider is added.
The default dialogue callback reuses Data271's existing full original-definition
reader and exact archive/unique-row identity for town NPCs, without applying a
combat category filter. An explicitly passed NPC catalog retains its narrower
extent. Missing readers/archives/rows remain unavailable rather than silently
changing suppliers. Original `TestNPC:true` rows are excluded from image
connection. No new source table pack, source importer, inferred row proof or
extra archive selection is added.
See [the consumer contract](SOURCE523_NPC_PORTRAIT_CONSUMER_CONTRACT.md) for the
exact arguments, return fields, source-provider scope and remaining input.
This written connection is unexecuted and unverified; registration, delivery of
the v14 selection and actual portrait display are separate stages.

### Class/gender main HUD portrait

Original ClassAssets declares distinct HUD/BigHUD/MainHUDPortraitID/Icon roles
with the composite `(ClassID, GenderID)` key and no single ID. The existing main
HUD portrait now uses the actual world's native class/gender context and only
the declared `MainHUDPortraitID`. Data271's original-definition reader supplies
the exact Class/Gender and unique ClassAssets pair; the existing original-image
loader supplies the declared asset and original pixel provenance. There is no
first-row or default-gender choice, ClassID-to-AssetID alias, role substitution,
new importer, source pack or source UI construction. Character-selection
portraits remain separate and receive no HUD image by inference.

The shared-file image seam is `hud_v20.gd.set_character_state` and its existing
portrait TextureRect, without layout/input changes. Successful portraits retain
their original texture while class/gender and source selection are unchanged.
Unknown gender, missing/ambiguous source rows and unsupported/excluded assets
remain unavailable. The existing gender-selection action already refreshes the
HUD; its state/save behavior is preserved. See
[the class image contract](SOURCE523_CLASS_IMAGE_CONSUMER_CONTRACT.md) for the
exact existing data API and source-role limits. These changes are unexecuted
and unverified; no new tests, game runs, renders, CI or usage counts were added.

The existing monster-book stage claim button also uses its original reward
image when the owning `levels()` result has exactly one reward row and that
row's original RewardType declares Item. Its `RewardClassID` then supplies the
full ItemClass row to the existing canonical original item-image helper.
Multi-reward and non-item claims receive no representative image; NpcGroupID
does not select a portrait. Existing claim arguments, status, quantities,
ownership, storage and detail lifecycle retain their current calls. This image
hookup is unexecuted and unverified, with no additional tests/game/render/CI.

Existing spell-group review and confirmation buttons additionally consume the
quote's declared GameClassSpellGroupCostView.ItemClassID image, preserving the
independent SpellGroup choice and payment/commit data. Shared item views also
accept a preserved current source_original_item when its explicit m523:item
identity and ItemClass key agree and the complete row equals the selected
pack's canonical row. This covers material consumers without granting a native
execution flag or rewriting their record. Incomplete/changed source rows and
source exclusions remain unavailable.

Actual acquisition/display/input/effect/save/restart coverage and deduplicated
actual-use percentages remain unverified. Inventory presence, metadata joins,
loads, component renders and delivery bytes do not count as that completion.
