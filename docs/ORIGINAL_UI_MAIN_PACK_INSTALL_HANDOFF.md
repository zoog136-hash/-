# Main game original UI pack handoff

This is an installer input contract for the existing private UI loader, not a
second installer. No source assets, old packs or save files are deleted. The
old card/monster packs are not a prerequisite or a fallback for this selection.
Attendance/pass are deferred. No new test, render, game run or CI was executed.

The latest single combined input is **v17**, documented in
[Original inventory search input](ORIGINAL_UI_INVENTORY_SEARCH_ABI.md).
It retains every v16 input and adds the authored extension search entry and
original input bar, borrowing the same bag query editor/filter. No new editor,
result row, clear action or sorting rule is created. Private delivery succeeded;
installation, input behavior and rendering remain unconfirmed.

The retained **v16** input is documented in
[Original enhancement-start control](ORIGINAL_UI_ENHANCE_ACTION_ABI.md).
It retains every v15 input and adds only the original enhancement action
subtree wired to the existing target forge execution/confirmation. Full
enhancement modes, slots, rates/cost display and result FX remain separate.
Private delivery succeeded; no install, execution or rendering is claimed.

The retained **v15** input is Drive
`1zVsaYliOBAl0Ryei7pOAMBTtrX1AUe_N`,13,353,312 bytes, ZIP SHA256
`74e6266aba52fce9f64553adcbcba900471bdb6150dff7fb9d795e72f8861371`,
manifest pin `2505fb5e40c5e77954fb978b5ad7e5b486956bc0a2a07ed02d61236ed4380db4`.
Filename is `TWILIGHT_current523_main_game_original_UI_combined_v15_20261105.zip`;
relative destination `source-ui/current523-main-game-original-ui-v15`.
Private upload succeeded with matching size/owner-user metadata. It retains
every v14 input and adds original minimap Text13992. World already produces
` · 안전 지역` in `set_map_name` for its actual safety branch; the UI separates
that exact existing suffix into Text13992 and keeps the name in14376. It does
not classify regions, map `combat` to Normal/PvP, invent a zone string, or add
coordinates. Unavailable optional text/font keeps the complete owner name.
Older pack scopes continue to render the unsplit name. Raw source geometry,
map image selection/click registration, costs and saves stay with their owners.
The53 files/33 scene trees/32 partial scopes are packaging counts; no new test,
execution, render or whole560/game-use completion is claimed.

The retained **v14** input is documented in
[NPC portrait receiver](ORIGINAL_UI_NPC_PORTRAIT_ABI.md). Private delivery
succeeded. It retains v12 and adds the original timed inventory name header
and explicitly declared NPC Sprite4912 target for authoritative typed providers.
There is no current dialogue-ID inference or portrait display claim. The
inventory addition is a name header, not a completed item detail screen.

The retained system-message extension is the combined **v12** input in
[Original system-message caller ABI](ORIGINAL_UI_SYSTEM_MESSAGE_CALLER_ABI.md).
It retains every v11 scope and its private delivery succeeded. Current owner
messages/timing feed the original text; the local priority2 connection is an
explicit TWILIGHT numeric estimate, not a confirmed original routing rule.

The retained NPC dialogue extension is the combined **v11** input in
[Original NPC dialogue caller ABI](ORIGINAL_UI_NPC_DIALOGUE_CALLER_ABI.md).
Its private delivery succeeded and retains every v10 scope. Original name/body,
close and unambiguous next-only conversation callers are connected; portraits,
multiple/action choices and loop policy remain explicit gaps. Game consumption
has not been executed or claimed.

The retained character-stats extension is the combined **v10** input in
[Original character caller ABI](ORIGINAL_UI_CHARACTER_CALLER_ABI.md). Its
private Drive delivery succeeded; it retains the v8 main/map/inventory/
quickslot/auto-message scopes and adds actual character stats tab/close/detail
callers. This does not change user selection/config or prove game consumption.
The earlier delivered inputs below remain preserved.

## Retained current checkpoint

The private Library operation succeeded for this exact existing file identity:

- Library ID: `libfile_22ce42630a508191a9e63e18c3712cf0`, returned version **5**.
- File ID: `file_000000008cf08211a010077f16a1475b`.
- Canonical filename: `TWILIGHT_current523_main_game_world_map_original_pack_20261105.zip`.
- ZIP size: **9,038,622 bytes**.
- ZIP SHA256: `0881022f018f52910ec658ca743c97c54e4694a51a21f1ab97344f58e88d26fc`.
- `original_ui.json` SHA256: `b85f32b8662bb9b79a3cf9200d95efb96369b1d65d974e23fa7ce10d14b0131c`.
- Corresponding published code: `f399eb1e862becb6187789ae2211fe9ca68816c7`.
- Canonical installer Drive file ID: `1JtVbeBUvq_IZpxAP1lBVOJZrKoT1JUko`.
- The parent confirmed this official private handoff and its same size/ZIP SHA/
  manifest pin for installer275. No further upload is performed. The existing
  Library identity and earlier private copies are preserved; no source or
  save deletion is authorized by this handoff.

The ZIP has `original_ui.json`, `receipt.json` and `originals/UI/...` at its
root. An installer may use the relative destination
`source-ui/current523-main-game-world-map`; no absolute install location is embedded
in the pack or loader. The loader root is the extracted directory containing
`original_ui.json`, not its `originals` subdirectory. The caller must supply
the manifest pin above separately from the ZIP hash.

Runtime selection uses both of:

```text
--source-ui=<extracted-root>
--source-ui-sha256=b85f32b8662bb9b79a3cf9200d95efb96369b1d65d974e23fa7ce10d14b0131c
```

Equivalent environment keys are `TWILIGHT_SOURCE_UI` and
`TWILIGHT_SOURCE_UI_SHA256`. `source_main_selection.gd` static `selected_pack()` opens this
selection; `renewal_hud.bind_original_main_ui(pack)` accepts an already opened
pack. Missing/incorrect supplied inputs are reported; another asset pack is not
selected as a substitute. No image pack, animation clip or repeat argument is
needed for these static native HUD controls. Item/Spell/Buff image selection
remains the separate PR270 consumer contract.

## Actual packaged scope

There are 27 original files, one EXP entry and eleven explicit partial node
scopes: CharInfo HP/MP/status/inventory, its normal-branch level child, PayLayout
gold/diamond icons/text, minimap name, selected-target name/backdrop, AttackPad
attack/auto/target/self/selected-pickup and TopMenu All/Inventory/Skill/Store/Quest;
and original MapScene/Map_All/Area/map-list-row scopes. Full original
MainScene/HUDScene parent metadata is retained separately. Full parent metadata does not activate their other children.
The exact partial scope lists remain in `receipt.json`/`original_ui.json`.

The builder receipt is STATIC_DEPENDENCIES_RESOLVED_REQUIRES_IMAGE_OWNER and explicitly sets
`whole_scene_completion_claimed:false`. This package is not all 560 UI roots,
full main UI completion or evidence of actual game consumption. Later optional
node bindings in code need a later pack that actually includes their inputs;
smaller checkpoints preserve their corresponding fields. In particular, older
combat scopes without authored sibling icons are rejected for that component
before prior controls are hidden. The prior EXP, vitals, core, fields and pickup
archives are preserved locally; this update replaces the same Library
identity instead of creating a competing final asset selection.

## Original map selection and image inputs

The current pack includes the actual MapScene/Map_All/Map_Tab_Area/map-list-row
originals and authored scopes, separate from the minimap name. Its only external
texture slot is `UI/Map/Map_Tab_Area.csb:44440`: the original CSB/editor reference
is retained, but no draft preview is shown or required as a runtime image.
The existing PR270 image owner must supply the actual selected World texture.
This is an additional input for map-image use, not an old card/monster pack.

The actual game entry is `hud.bind_original_world_map(image_adapter,
context_provider,input_handler)`. The existing map signal/hotkey/toggle then
opens the original map presentation. The caller supplies the exact offered
UIMapWorld.ID, original label, role declaration and existing input controller;
open never selects a first candidate. Native source buttons perform selection.

[World map caller ABI](ORIGINAL_UI_WORLD_MAP_CALLER_ABI.md) contains the exact
component hashes, image node, selection/input APIs, actual viewport-to-texture
pixel registration and unchanged ImageInfo handoff. Its raw pixel conversion
does not supply Ratio/BaseLoc/BasePixel cell-axis/formula or movement rules.
No native minimap preview or Size/Point/On/Off button is repurposed.

The UI pack alone is sufficient for these static HUD/source map controls, but
it is not proof that the separate image-owner pack, source relation document,
caller registration or cell conversion are installed. These inputs remain
explicit; missing originals are not replaced or claimed as game consumption.

## Separate normal4 inventory candidate (private delivery succeeded)

This new candidate is separate from the canonical v5 selection above. Its
successful private Drive upload and metadata readback do not change the
installer's selected v5 input or prove consumer installation/game execution.

- Drive file ID: `1RIdxVtVA3q9cWsrr3FWq8Kea6_ceNeTV`.
- Filename: `TWILIGHT_current523_main_game_inventory_candidate_original_pack_20261105.zip`.
- ZIP size: **11,935,660 bytes**.
- ZIP SHA256: `40abf0125a370a12e1ebe24638c504e98b683711cec051c5184174711fef99fb`.
- `original_ui.json` pin: `4f5bffdd6ad96917ac8795f3313e4da0ace4a59821f9439783a410509931e4c1`.
- Corresponding code: `e091ef68bc95644e0941598fff5d88b3b1ad8e42`.
- Scope: 33 originals / 16 scene trees / 15 partial scopes; normal four-slot
  inventory plus the retained main/map subset. Later expanded8/weight/quickslot
  code is not activated by this candidate's smaller source scopes.

Root entries remain `original_ui.json`, `receipt.json`, `originals/UI/...`.
The separate relative destination is
`source-ui/current523-main-game-inventory-candidate`; select the extracted
root and this candidate's manifest pin through the same CLI/environment keys.
Area44440 and Common_Slot15012 still require their existing PR270 image owner.
No old card/monster pack is required. The Drive metadata returned the exact
filename/size and owner-user permission; no permission was changed. A consumer
has not yet confirmed materialization. No new test/render/CI was performed.

## Separate expanded8 + quickslot candidate

A later candidate includes the original extension row, optional existing weight
text and original QuickSlotScene/PageViews/slot template. The earlier normal4
candidate and canonical v5 are preserved, with no automatic installer switch.

- Drive file ID: `1yJmX2l-4w3FdwcW4CGCZRDveqf9zKBKM`.
- Filename: `TWILIGHT_current523_main_game_quickslot_inventory_candidate_original_pack_20261105.zip`.
- ZIP size: **11,972,925 bytes**.
- ZIP SHA256: `aa0fcb3e5772d9feca8aadf6df6dcda8880c0757ef68d2857c2707a323932182`.
- `original_ui.json` pin: `dd4785a6764ad5d50e83720e139f8da99279593e85b3a8cccba104a7b1cc69ee`.
- Scope: 37 original files / 20 scene trees / 19 explicit partial scopes.
- Relative destination: `source-ui/current523-main-game-quickslot-inventory-candidate`.
- The same extracted-root structure, CLI/env selection and explicit manifest-pin
  contract apply. No separate installer or automatic old-pack fallback.

Production returned STATIC_DEPENDENCIES_RESOLVED_REQUIRES_IMAGE_OWNER,
blockers0. External inputs are map Area44440, inventory Common_Slot15012 and
quickslot Slot_Skill18488. Actual PR270 original pixels remain mandatory for
filled inventory/quickslots. Code-only later changes need their actual scopes;
this producer result does not claim full inventory/HUD/560-root completion.
Private Drive upload succeeded and metadata returned the exact filename/size
with owner-user permission. Consumer installation is unconfirmed. No new game
execution, test, render, quality assessment, audit or CI was performed.

## Combined v6: one complete selection for simultaneous main UI components

The source-ui selector selects an entire main-UI composition, not a separate
per-window pack. Combined v6 includes the retained v5 main HUD and world-map
scope together with normal4/expanded8 inventory, original quickslots and
original equipped/locked markers. Installing/selecting this one extracted root
provides those components together. Installing v5 alongside it or inventing a
second inventory/quickslot selection key is unnecessary.

- Drive file ID: `1pGrQ_iktV8w4Bjsw1R6i8gmtY-b7OJqv`.
- Filename: `TWILIGHT_current523_main_game_original_UI_combined_v6_20261105.zip`.
- ZIP size: **11,977,144 bytes**.
- ZIP SHA256: `110920439176d0ac3a74d86acf6596bdc4f896ef478dba632a5f0ae07d67d27e`.
- Manifest pin: `3e775a796e2d1d1e14775313e587f870d7d0773b03da9a18803a78c4afe63304`.
- Relative destination: `source-ui/current523-main-game-original-ui-v6`.
- 37 original files /20 scene trees /19 partial scopes; production blockers0,
  STATIC_DEPENDENCIES_RESOLVED_REQUIRES_IMAGE_OWNER.

The manifest's `selection_contract` schema is
`twilight-main-original-ui-composition-v1`, mode
`single_combined_original_ui_pack`. Its extends_manifest_sha256 records v5's
pin and retained_base_files records that base's original member sizes/hashes;
retained_base_node_scopes preserves its explicit scopes. The new composition
adds scopes without creating/repainting/changing original CSB/atlas bytes.
All original members are included in this ZIP. Earlier v5/candidate files are
preserved, and this handoff does not delete them or alter their pins.

Use both arguments for the one combined root:

```text
--source-ui=<extracted-combined-v6-root>
--source-ui-sha256=3e775a796e2d1d1e14775313e587f870d7d0773b03da9a18803a78c4afe63304
```

The same environment pair TWILIGHT_SOURCE_UI / TWILIGHT_SOURCE_UI_SHA256 applies.
The loader returns `selection_mode` and the composition metadata; its existing
main controller mounts main/map/inventory/quickslots from that same pack.
`bind_original_world_map(...)` retains the existing map/image owner registration.
No second world registrar, cfg rewrite, save migration or old card/monster pack
is added. Installers must preserve user cfg and explicit user selections; this
contract is the complete input for a new installation or explicit update.

PR270 image inputs, exact CSB-icon registration/playback inputs and the existing
map context/input owner remain independent required consumers. Native Android
row/close/scroll support is code981d38e4, requiring no project touch-emulation
setting change. Private upload succeeded; consumer installation and simultaneous
actual game execution are unconfirmed. No new test/render/game/CI was run.

Combined v6's published code checkpoint is
`a8c6ed6a8b2d2d6f3b62fa1c76c7d0d20a29b966`. The subsequent native icon CSB
consumer contract is code `06600e0a72811b4ea32e056a6861f49e97b1ff0d` and
[its exact ABI](ORIGINAL_UI_NATIVE_ICON_SCENE_ABI.md). Those icon scenes remain
image-owner packs/registrations; no second main-UI selection key is required.

## Combined v7: original default MD/AC values and native main-button input

This next composition retains the complete v6 selection and adds only original
CharInfo18508/18556/15324/15372 default MD/AC icon/text scopes. The same existing
integer character-state producer supplies those values. Their original parent
button actions/mode switches remain explicitly unavailable; no source mode or
formula is invented. Main HUD/inventory chrome use the original native-touch
button router; item/quickslot gestures remain PointerTransfer-owned.

- Drive file ID: `1aeQmN-bnYBWlc0Vz4z2B-csMRzSIFOB4`.
- Filename: `TWILIGHT_current523_main_game_original_UI_combined_v7_20261105.zip`.
- ZIP size: **11,978,798 bytes**.
- ZIP SHA256: `adc890b687f9e56c376350b621ec927a9d0596ab55a88279657919ecb380baeb`.
- Manifest pin: `563bebe2a849bf6359b318500467bd89d1425f1e455485b2cb0e9ae89f69ae0e`.
- Relative destination: `source-ui/current523-main-game-original-ui-v7`.
- 37 originals /20 scene trees /19 widened partial scopes; production
  blockers0, STATIC_DEPENDENCIES_RESOLVED_REQUIRES_IMAGE_OWNER.

Use the same one source-ui root/pin pair for this entire composition. Main,
world map, inventory and quickslots stay together. V6 and earlier packs are
preserved; no simultaneous v6 installation, second per-window selector, cfg
rewrite, save migration or original-file deletion is introduced. Private upload
and filename/size metadata readback succeeded; consumer installation and game
execution are unconfirmed. No test, run, render, audit or CI was started.

The actual UI component/hash/node identities of the two native icon targets
are unchanged. Their selected UI manifest pin is v7's pin when v7 is selected;
that package pin is not evidence of the unknown CSB-root-to-anchor relation.
The exact original target positions and narrow pending relation are recorded
in [the native icon scene ABI](ORIGINAL_UI_NATIVE_ICON_SCENE_ABI.md).

## Combined v8: dedicated original auto-combat text

This composition preserves all v7 main/map/inventory/quickslot inputs and adds
only the actual original Hud_AutoMessage Text124 dependency scope. Its source
text follows existing player.auto_enabled, with no new timer/clip-loop policy.

- Drive file ID: `1OaX2KvnUNZox-O6o2hfU1Mn_WeLhhQJT`.
- Filename: `TWILIGHT_current523_main_game_original_UI_combined_v8_20261105.zip`.
- ZIP size: **11,980,497 bytes**.
- ZIP SHA256: `42fd0af7c72353ca4d6ecd3cf7168a3f50135d11ef3bbf115e3031c01bfb87da`.
- Manifest pin: `ddd99fe88b49e8ec5d13ceb24a3303d730d2475cfdd785be9f8dd56bd1c6b8d6`.
- Relative destination: `source-ui/current523-main-game-original-ui-v8`.
- 38 originals /21 scene trees /20 explicit partial scopes; production
  blockers0, STATIC_DEPENDENCIES_RESOLVED_REQUIRES_IMAGE_OWNER.

Select this one extracted root plus its pin through the same CLI/env pair.
No previous version must be installed alongside it; all prior packs/candidates,
user cfg and saves remain preserved. The native icon component/hash/node stays
unchanged; its selected package pin is this v8 pin when v8 is selected.

Private upload and filename/size metadata readback succeeded. Consumer receipt,
installation, actual game use and original AutoMessage animation remain
unconfirmed. The dedicated component/caller contract is in
[the auto message ABI](ORIGINAL_UI_MAIN_AUTO_MESSAGE_ABI.md). No test, game run,
render, audit or CI was started. This is not whole560 completion.
