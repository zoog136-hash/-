# Current523 source maps in the existing game

This is the whole-map continuation of PR232. The immutable Aden-only packs and
[earlier installation evidence](CURRENT523_ADEN_SOURCE_RUNTIME.md) remain valid
for their stated scope. This document does not claim complete original-game
restoration or verified native collision, portal activation, actor-foot placement,
alpha, combat, NPC placement, or every-cell play coverage.

## Exact input scope and local outputs

The authenticated whole-map handoff ZIP has SHA256
`ef9728b3ff364a3930668f80ab8c6edae93c86d036b7c0772760c25305e86366`.
Its CRC and payload identity were checked and `HANDOFF_PR232_KO.txt` and the
priority rows read. It is a source-location/declaration index, not 6,570 received
original packets.

| Layer | Full scope | Received and built current scope |
| --- | --- | --- |
| Native logical Land rows | 1,065, including68 excluded Lands | All original declarations retained;997 ordinary Lands classified |
| Literal native AssetPaths |619 total;577 ordinary physical roots | Every ordinary root has its exact original S32 inputs |
| Ordinary original members |6,570:6,558 S32 and12 SEG | All6,570 original byte identities received;795,660,419 original bytes |
| Placed S32 |6,558 original S32 |6,557 candidate placements; one literal nine-character Aden name retained unplaced |
| Required TI2 |7,557, derived from every actual ordinary S32 floor/cover/object reference | All7,557 received, strictly decoded and included; no missing tile/frame reference |

The complete source pack is `current523-normal-source-pack-all6570-v5/` under
`/workspace/aden-validation/`:6,571 files /312,374,868 stored bytes.
`source523.json`:17,260,837 bytes, SHA256
`6b71f4adb533b7acae6a7327e83af1b1322001a0f67c417bb3fae1bec35d96ca`.
Original map inventory SHA256:
`95d3dac855d422c866ecbc4cf21612802944c246d099278870ed87dee2b1cd39`.
All6,558 S32 use lossless gzip with independent stored/original identity checks;
12 SEG are preserved as unsupported alternatives, each with a same-stem S32.

The full required tile pack is `current523-all7557-ti2-runtime-pack-v2/`:
7,558 files /282,369,476 bytes. `tilepack523.json`:21,156,382 bytes, SHA256
`8a954372eed28e360dc3c7c77f361fba1e0fcc7ee1daa7ffa204f6a679e28482`.
It retains261,213,094 original TI2 bytes and renders coverage atlases on demand,
without storing several gigabytes of derived PNGs. TI2 physical block counts are
preserved:5282 has60,5293 has108,7211 has107. Unused atlas storage slots are
transparent padding and are never accepted as original frames.

Current input qualification compares exact original SHA256/size/ZIP CRC with the
523 member index.293 unchanged TI2 members were obtained from a retained DAT
whose whole hash differs from the current selected DAT. Both DAT hashes and the
independent current member proof are retained; those old containers are not
reported as current whole-DAT downloads. The remaining7,264 TI2 have matching
selected-DAT provenance.30 otherwise missing S32 and286 TI2 were recovered from
only the exact named normal-resource DATs and checked against current container
and member hashes. No engine/APK was read. Archive selection is per container;
523 does not imply every container changed after508.

The primary build folders remain local immutable outputs. Their complete runtime
payload is now durably stored as the latest private Drive application bundle:

- `TWILIGHT_Current523_AllMaps_application_20261104.zip`:565,562,974 bytes,
  SHA256 `1fadd8a079012b4449da5ad08cda5403ec7b486a1f22c51e40316f72477347dc`.
- 17 ordered parts:16×33,554,432 bytes and a final28,692,062 bytes.
  Each uploaded part was downloaded and checked against its exact SHA256;
  owner-only permissions and the application-folder parent were read back.
- The [delivery manifest](https://drive.google.com/file/d/1j3fb_H18eH-iWsxELmukF2-vHvT9orMN/view?usp=drivesdk)
  lists every part's exact order/name/size/SHA/file link. It is7,527 bytes,
  SHA256 `9360e40160af7d0bc10c44cc3d9694125edd96c802d2461a7df4231ee300dc05`.
- Destination: the existing private
  [actual application-pack folder](https://drive.google.com/drive/folders/13CrR_W4xStDNSW0KZ9Z91OgGkSX7-zmO).
  Existing files and sharing were preserved.

A fresh authenticated consumer downloaded all17 parts, logically reassembled the
ZIP in memory and verified the whole archive SHA, every ZIP CRC and all14,131
payload identities. The fresh installation contains597,200,350 bytes at
`/workspace/aden-validation/fresh-Drive-wholemap-consumer-v1/`.
Only after each downloaded member matched did installation link the identical
private immutable payload into the new consumer folder. This is a fresh verified
install with physical deduplication, not an independent physical copy or a single
ZIP persisted to disk. Actual Main loaded this new folder and passed34 entry,
walking, blocked motion, return and save checks in109.29s; a new process then
restored the same installed source folder/cursor with8 checks in68.97s.

Installation is manual ordered-part concatenation / SHA+CRC verification / ZIP
extraction / folder selection. Select `source523` and `tiles523` and enter their
manifest pins above in the whole-map controls. There is no automatic Drive
downloader. The old Aden-only ZIP install button is incompatible with this bundle.
Use PR232 code `464dae43145b821e735f628a386ec4c8845b9dfd` or its continuation;
the new generic readers are not present in the older Aden-only revision or merged
main. Embedded manifests retain their conservative creation-time
`PRIVATE_LOCAL_ONLY` field; separate authenticated transfer/install receipts
establish the subsequent delivery stage without rewriting immutable pins.

The preceding Aden application ZIP remains intact:399,316,785 bytes, SHA256
`f926e1513c552b60ed5deb6c9b1fddf18a6e59ab4e916575b9dc88206b05f952`.
Its five-part download/Main success is separate evidence for that older scope.
Separate original backups in the existing private
[original-preservation folder](https://drive.google.com/drive/folders/1SFucZ3Lt2OxZUTv8K-0MDIP6Rsz7tHjk)
remain:

| Backup | Bytes | SHA256 |
| --- | ---: | --- |
|[Aden S32 originals v1](https://drive.google.com/file/d/1byeN61WZskhpdzrcASK15ol4xSD94isv/view?usp=drivesdk)|31,385,092|`fde68ad6caa92ede3eeb1c4dd8cca39b304abae310ac7ef535ba17f082e5007b`|
|[Aden TI2 originals v1](https://drive.google.com/file/d/1EOvXo3DBfN9HkxWnWkkjf-OO6sQIJkby/view?usp=drivesdk)|97,836,926|`cf94af7173e7b1d915d9960c61502d2b7f6b17f7c3295004302acd590e7bd28a`|

These separate backups cover Aden, not the new entire-map scope. The new complete
application bundle itself preserves all current original map/TI2 identities.
No additional standalone raw-source backup, investigation report or screenshot
was uploaded. Original resources and derived atlases never enter public Git.

## Build and use

`build_current523_source_pack.py --help` describes the caller-pinned original
inventory, complete native Land table, and optional verified whole-map handoff
normalization. It rejects unsafe paths, a wrong current member identity,
misdeclared local availability, symlinks and existing output directories. A file
from a retained508 container qualifies as current523 only when its exact bytes
match the current selection proof; a base508 label alone is insufficient.

The normal source pipeline retains every expected ordinary member. Missing,
malformed and unsupported members remain explicit and never become zero-filled
walkable cells. The generic reader validates the supplied manifest SHA, original
whole-file SHA, section layout and section SHA before a chunk can participate.
The old fixed Aden reader is not relaxed or relabelled as a generic reader.

```sh
python3 tools/map_restore/build_current523_source_pack.py \
  --source-dir /private/current523_sources \
  --land-table /private/current523-tables/Land.json \
  --inventory /private/normalized-current-inventory.json \
  --expected-inventory-sha256 <verified-inventory-sha256> \
  --output /private/source-pack --storage-mode hardlink

python3 tools/map_restore/build_current523_tile_pack.py \
  --source-dir /private/current523_sources \
  --inventory /private/verified-ti2-inventory.json \
  --expected-inventory-sha256 <verified-inventory-sha256> \
  --output /private/tile-pack --atlas-storage runtime_ti2
```

The source builder's hardlink mode is explicit, limited to private immutable
originals, and checks source/destination hashes without changing shared file
permissions or contents. Tile reuse also checks source identity and freshly
decoded coverage pixels. Link failures do not silently copy or publish a partial
pack. Prior versions remain intact.

In the existing game, open settings and the original-map controls. Select
**전체 맵 카탈로그 · 논리 Land 선택**. Supply the generic source and tile directories
and their exact manifest hashes, then use **카탈로그 확인 · 지역 목록 읽기**.
The list shows classified ordinary logical Lands and raw available/expected
counts. A listed declaration is not proof of installed terrain or tile coverage.

Choose the logical Land and an explicit original cell using **원문 좌표로 입장**.
Coordinates from another Land are never inherited implicitly. Without an explicit
entry, only a saved cursor for the same logical Land, source root and manifest
can be reused. The field and arrival frame must validate before replacing the
current field. Missing tile coverage, invalid placement or blocked entry preserves
the existing map and position. **기존 지도로 복귀** restores the initial host field.
This setup consumes existing private folders; it is not a new whole-map installer
or a claim that the older Aden ZIP includes these additional regions.

## Identity, coordinates and own movement

Logical identity is native `Land.ID` plus the exact `AssetPath`. Numeric physical
folders are not implicitly Land IDs. Land47443's literal `13341` is retained with
an explicit `Map/13341/` physical binding. Native Lands0 and12156 share `0/` but
remain separate logical fields, cursors and declaration namespaces. `TalkingIsland_pc`
is a native M row name; the source packets were qualified as M, not PC resources.
The nine mixed ordinary/excluded roots retain per-logical-Land admission policy.

The eight-hex filename placement and 24/-12,24/12 display bases are explicit
coordinate hypotheses. The nine-character Aden original remains losslessly
registered but unplaced. Native integer source cells and fractional saved actor
components are distinct: `to_world(integer_cell)` centers once;
`components_to_world(already_centered_components)` does not center again.

The default own allowlist is `[0,4,8,12,32]`, configurable in settings. Both raw
u16 halves must be allowed and both raw u32 floor references must exist.
`0xffff` attributes, `0xffffffff` floor sentinels, missing/corrupt/unplaced chunks,
unknown cells and diagonal corner cutting are refused. Raw words and all original
packet bytes are preserved. This is TWILIGHT's explicitly labelled interpretation,
not a recovered native M passability bit. Existing A3 navigation grids, old map
geometry, NPCs and monster positions do not supply the new field's geography.
Raw chunk caches are bounded to48 and persistent tile atlases to32.

Original object/cover records may extend beyond a packet's64×64 floor chunks.
Generic source rendering now retains those decorations at their projected source
coordinates instead of inheriting the old host-overlay intersection clip. This
adds no floor or navigation cells; original storage coordinates and collision
policy are unchanged. Legacy overlay clipping is retained. Frame metrics expose
`off_floor_decoration_records` separately.

Black and white stored pixels are preserved. Candidate RGB565/24x24 coverage
atlases distinguish stored and unstored pixels; native layer blend/alpha and
actor-foot alignment remain unverified.

The literal `Map/Aden/800f7ff3e.s32` remains unplaced:147,158 bytes, SHA256
`bc79ea23c3ba0443f57f45bff55cce72390d9011c3db50b79c8c21359e143e11`.
Its two-byte tail declares zero portal records, so it supplies no tail-coordinate
anchor. No exact whole-file duplicate or matching nontrivial section identity was
found among the other676 Aden originals. The similarly named eight-character
`800f7ff3.s32` has a different original hash and all8,192 floor references differ;
it is not substituted or overwritten. Existing reports and public search did not
establish a source-backed origin. Neither truncating its name nor interpreting
effect fields as dimensions is accepted. The blocker is unresolved placement,
not missing received bytes or an access denial.

## Native portal definition boundary

PR230 owns native Portal/Territory/Land definitions and their verification.
PR232 adds no second native definition catalog or compiler. The optional bridge
accepts a caller-owned verified provider through:

```gdscript
world.bind_current523_source_portal_provider(provider, verified_manifest_sha256)
```

The expected existing definition pack SHA256 is
`2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90`.
The lower-level caller-owned provider API still requires external authentication;
passing the expected hash string does not authenticate an arbitrary provider.
Required methods return copied full original rows:

```gdscript
portal_evidence_for_land(native_land_id, exact_asset_path) # raw Portal rows
portal_context_for_land(native_land_id, exact_asset_path, portal_id)
# Portal, SourceLand, TargetTerritory, TargetLand
```

The production path now uses `world.bind_current523_source_definition_pack()`
and the owner's existing `--patch523-world-links` /
`--patch523-world-links-sha256` arguments. PR230's loader is reused unchanged
from commit`5d1b1bdb0b00b855ffd87036a2e5f6b274ffa3eb` / Git blob
`0fcb00cba1d6ca7e5f2ea2e12aee187d622551e0`; no second compiler or source catalog
is introduced. The adapter verifies the pinned manifest and delegates original
Land shard and condition-table verification to that owner. An invalid requested
pack blocks optional source entry; a rejected update preserves the valid binding.

The existing private [PR230 contract15 resource bundle](https://drive.google.com/file/d/1B5IpjTvxvElDxxnGCsgGD3M4PILcDW7Z/view?usp=drivesdk)
was read through authenticated Drive:13,600,935 bytes, whole SHA256
`9a4eccc9c1bb99d5edea7663f8594e6657aeed601cafa9905369ebf9cc596421`.
Only its `world-links/` payload was extracted:1,067 files /22,859,928 bytes,
all CRCs and1,066 payload hashes checked, with the exact manifest pin above.
Other resource payloads in that bundle were not installed. The local definition
consumer is `/workspace/aden-validation/pr230-production-definitions`.
No resources were uploaded again or included in public Git.

The adapter preserves the owner's full native contract and a bounded4-Land
cache. Original Land attributes, unresolved time/weekly/competition conditions,
unknown rule scopes/types and region arrival policy hold the own manual action.
The existing Settings list displays **원문 조건 보류** for such routes. Raw separate
LandTeleport cost/prerequisite rows are preserved without applying them to a
Portal merely because they share a destination. The native owner still reports
`activation_known=false`, `portal_cost_known=false`, `travel_enabled=false`.
The explicit generic button remains **TWILIGHT 자체 수동 이동 · 원작 활성 조건 미확정**;
it does not prove native automatic activation/admission.

The pure planner checks exact joins, complete native Land rows, both fields'
manifest/per-asset inventories, actual endpoint member/SHA/attributes/floors,
ordinary logical scope and the actor's exact declared source cell. Only singleton
Territories qualify. Rectangles/inverted bounds, unknown rules, missing fields
and blocked cells are held without selecting a center, nearby cell or replacement
coordinate. No reverse edge, trigger radius, cost or LandTeleport rule is inferred.

Cross-field travel prepares a fresh hidden renderer/field/disabled physics,
validates the arrival frame and writes the target Land/cursor atomically before
publishing runtime references. Failures retain the previous field, renderer,
position and preference bytes. All successful hops retain the original host
snapshot for return and existing save compatibility. A missing native rule is
not silently called native behavior.

Portal1101 is a clear directed candidate under the default own policy:
Land1 `(32668,32803)` to Territory173094's exact point Land0 `(32477,32855)`.
Both original endpoint pairs are `[0,0]`. Portal523's declared807/808 endpoints
both contain `[0,1]`; the default own policy rejects them. Declaration coordinates
are preserved rather than changed to force travel.

## Walk to a declared source point

The existing Settings portal list now has **원문 출발점까지 걷기 · 자동 포탈 활성 없음**.
It queues the ordinary player-physics path to the original `Portal.SourceX/Y`
in the current exact Land. It never sets the actor position, selects a nearby
replacement, spends a separate route's fee, grants admission or invokes a portal.
Arrival still leaves native automatic activation unimplemented. The explicit own
manual transition button and its native-condition holds remain separate.

The UI stores an ephemeral navigation ticket with field instance, source manifest,
definition-binding generation, original Portal row and actor world position.
Requests recheck that identity before and after path preparation. Same-Land
close/reopen, definition rebind and even a changed actor position invalidate an
old request. Active auto-hunting/charge/impairments, already-at-source, blocked
source endpoints, missing/partial routes and absent tickets are refused before
changing a queued route. Geometry, raw-word collision, renderer, packet bytes,
source checkpoints and game-save formats are unchanged.

`tests/current523_source_portal_walk_main_test.gd` uses the genuine definition
pack and actual Settings/player physics:67 checks pass in132.47s. It walks from
a verified own QA neighbor to native Portal313's exact Land1 source cell, invokes
the real Main trigger updater after arrival, confirms no automatic transition,
and checks stale actor/provider/field requests and blocked native523 endpoints.
Rejected requests preserve existing movement, field, renderer, physics,
preferences, stored save bytes and protected state. The test's capture and logs
remain local under `display/source-portal-walk-walk02/`. The original577-root /
12,558-check checkpoint remains evidence for its stated full physical-map scope;
this focused UI/navigation change does not rerun that24-minute suite.
The default-off Main/save gate also passes35 checks in72.65s on this continuation
(`current523-portalwalk-core-save-receipt.json`). Focused walk log SHA256 is
`c2bca6eb8b610036093fe67fe4b939d59697a7ac2a07574f3746571efaff662c`.

## Bounded long-route search

The existing source field already bounds A* storage to8,192 cells by default
and at most65,536. That is an own algorithm budget, not a terrain collision bit.
The default is unchanged. Settings now exposes **자체 경로 검색 한도**, stored as
`path_search_limit` in the separate play preferences (integer1..65536). Old
preferences read as8192. Choose the budget before source entry; a live change is
rejected without altering the accepted field/preferences. Reentry validates the
same original geometry. The selected budget follows genuine source-field manual
transitions and survives a new process. Failed route queries display their
selected budget; no route is replaced by a partial path or guessed passage.

A new reproducible case uses native Portal1431's Land4 source `(32939,32283)`
and Portal1481's source `(33139,33358)`. Their independently verified original
endpoints are:

| Endpoint | Original member | SHA256 | Attribute pair offset/raw | Floor pair offset/raw |
| --- | --- | --- | --- | --- |
|1431|`Map/Aden/80027ff8.s32`|`c5e5a847380e9c356f21d6c61cad7fd5ca147634c716a7db8dcd57f7a3aa0c2d`|42254 / `[0,0]`|14168 / `[1003567,1003568]`|
|1481|`Map/Aden/80058009.s32`|`d473699610ae9bb94bb77bc782565b1ecb43f4f40b06873ed9b547e0cb825ece`|36558 / `[0,0]`|7576 / `[137,140]`|

An independent raw-cell four-neighbor analysis places those points in the same
1,823,897-cell component under the existing own exact-word rule. Actual Godot
field queries return no path with8192 storage, then1,077 points in3.687s with
65536; every returned segment passes the same field's collision predicate.
The native filename projection and raw-word interpretation remain labelled own
hypotheses. This analysis does not prove native collision or authorize a portal.
Other long connected pairs can still exceed the finite cap; failure remains
explicit and safe, rather than being called proof of an original wall.

`current523_long_source_route_main_test.gd` uses the actual Settings UI and
player physics to walk the **entire**1,077-point route:174.579s,1,129 visited cells
and28 original S32 members, with no denied cell entered. Main41 checks pass,
including original endpoint bytes, default-budget refusal, stale old-field
requests, rejected live-policy edits, actual blocked-edge physics, unchanged
progress/save bytes and no automatic portal activation on arrival. A separate
new process passes16 checks for exact restored arrival, saved budget, genuine
manual1101 Land1→0 policy propagation and host return. The preference guard
passes58 checks, including old defaults, bounded validation and exact readback.
The required default-off Main/save gate passes35 checks in61.55s.

This continuation changes no S32/TI2 bytes, cell passability, coordinates,
renderer or save schema. The original577-root/12,558-check evidence is preserved;
focused tests cover this selected budget and route instead of rerunning that
full suite. The17-part application bundle is unchanged. Logs/frames remain local
under `display/long-source-route-long02/`. Original endpoint proof SHA256 is
`4000d53e60a48cfd7a87dd6895ba6ea5f2d5b5b3d097ad10a5bced731e469e40`;
raw connectivity/search analysis SHA256 is
`fc4e23a378b7e41fdad36da98fe295c4a9eb33a1cb114aef9f499a2ac10533dd`.
The compact complete-route receipt is `current523-complete-long-route-final-evidence.json`,
SHA256`9bac026cfc8b7bd4fe2fc98098c082e4f730a82be7b38a4070b39845312f96e4`.
The first Main run compared raw integers to unnormalized JSON numbers; its two
fixture comparison failures are retained, and it was stopped before physical
route execution. The corrected complete run passes. No source value or collision
check was relaxed to resolve those fixture comparisons.

## Remaining native evidence reviewed

The nine-character original is still the only non-eight-character S32 name in
all8,311 entries of the previously received original-member index. Its exact
SHA occurs only in its own entry, including across the complete ordinary6,570
scope; it is not an exact payload duplicate in those indices. The complete
index SHA256 is`eed9bf9379e83af4e43ae325138e732b7e7fdab55c01b4f8215c9cbbe97a01a2`.
This metadata comparison reads no additional excluded-mode original bytes.
The original two-byte zero tail supplies no portal coordinate anchor.

The previously referenced public viewer was checked at pinned revision
`364fcff15ea019e5a9329170aaf7e245404ebba6`. Its
[M data-source reader](https://github.com/tony1223/L1MapViewer/blob/364fcff15ea019e5a9329170aaf7e245404ebba6/Sources/LineageMDataSource.cs)
accepts eight-hex map names and contains no selector/placement contract for this
suffix. Its [attribute decoder](https://github.com/tony1223/L1MapViewer/blob/364fcff15ea019e5a9329170aaf7e245404ebba6/Helper/Layer3AttributeDecoder.cs)
and direction service document that tool's own flag interpretation, not verified
M movement semantics. None of those source observations supplies native origin,
variant selection, actor-foot, collision or automatic-portal authority.
The existing typed movement, obstacle, interaction-cell and portal reports were
reviewed; their separate terrain/occupancy/actor-state namespaces and explicit
counterexamples remain intact.

The held1,150 original Portal rows expose only `AssetID`, `ID`, `SourceLandID`,
`SourceX`, `SourceY`, `TargetTerritoryID`. The source ledger identifies
`content/Portal.json` as198,209 bytes, SHA256
`af434065337cfd2b8c3fab9887ce5d3569ce6651d122a05288769d487df78a45`.
Those fields provide no trigger extent, activation clock or Portal fee contract;
separate LandTeleport definitions do not fill that gap automatically.

The prior local materialization gap was resolved using the already-held
private [current523 Content archive](https://drive.google.com/file/d/1EJGI2VV4u4P2yNlrMAlp0H2U28jjUH6K/view?usp=drivesdk)
through official authenticated Drive fetch, then consuming its returned file
reference in this executor. No producer-local path or guessed URL was used.
The local file is now
`/workspace/aden-validation/current523-content-verified/lineagem_patch523_all_content_validated_and_508_520_deltas.zip`:
25,031,173 bytes, SHA256
`d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`.
All1,075 ZIP entries passed CRC. Every actual Content table was checked against
both the real index and package manifest:1,065 tables,2,323,700 rows,
457,729,872 original JSON bytes. Original JSON SHA/size/CRC, strict JSON keys and
constants, actual row counts and complete field sets agree. All26 production
condition tables match the original rows with numeric/boolean types preserved.
The original archive remains private; this is analysis input, not a new runtime
map pack or a claim that the table ZIP is automatically installed in game.

Reproduce without extracting the457MB original JSON:

```sh
python3 tools/map_restore/verify_current523_content_tables.py /private/content523.zip \
  --production-conditions /private/world-links/conditions.json \
  --output /private/new-content-verification.json
```

The full-schema and typed-reference review found:

- Portal1,150 rows have no direct fee/activation column. The only other
  Portal-named field is `ClanRaidClass.PortalEarthObjectClassID`, a different
  object-class namespace. This field-name review does not prove that all runtime
  relationships are explicit foreign keys or that original activation is absent.
- LandTeleport has674 routes,691 separate territory links and278 prerequisite
  links. The checked Portal/Land/Attribute/Type/Unit and
  LandTeleport/Currency/Territory/Prerequisite references have no missing keys.
  Only5 Portal rows share a target Territory with an independent LandTeleport;
  that equality does not transfer its admission or fee contract.
- Territories.ID0 is a declared `None` sentinel. Land.ID0 and LandTeleport.ID0
  are real definitions; the latter costs100,000 Currency1. Zero IDs must not be
  discarded globally or interpreted as a free route.
- Cells882 rows reference Location/CellSubGroup; CellSubGroup154 rows reference
  Land/CellGroup. Their schema provides no S32 terrain passability truth table.
  This does not reopen excluded minigame/guild/siege gameplay.
- LandAttributeType8 is `NoTeleport`, Unit20 `TrueFalse`; three original global
  rows explicitly haveValue0 andParam1/2/3zero. One belongs to ordinary
  Land47111 (`13313/`); the other two remain excluded siege Lands. No current
  type is named `NoTeleportGo`. Unknown names/units, missing or nonzero
  parameters and unknown scopes remain held.

The correction separates these explicitly false teleport restrictions
from active/unresolved holds. Contexts retain copied raw type/attribute evidence
and source/target scope as `declared_inactive_restrictions`; the existing Settings
list displays `원문 NoTeleport=false` alongside remaining `원문 조건 보류`.
This grants no travel permission. Land47111 still retainsBlockLoginEnter,
LandTimeLimitGroup41 and other unresolved original conditions. Native
`activation_known` and `travel_enabled` remainfalse. The unused compatibility
check for nonexistentNoTeleportGo was removed; missing parameter values are no
longer implicitly considered zero for a false restriction.

Local analysis receipts under `current523-content-verified/` are
`all1065_actual_table_validation_and_reference_columns.json` SHA256
`48a38bd97495659fa5ccf5ce5dc5b0f6dacb26193ab053fba4b0999cceaa1639`,
and `typed_map_relations_source_review.json` SHA256
`02c9a7d892f172a7231beacf812fa1d0a73415a4c851728d57eb1032a6c31941`.
They remain local; no report/resource/capture was uploaded. The historical
missing-path receipt is retained as historical evidence, not a current blocker.
Original JSON row byte offsets were independently checked before normalization:
Unit20 at963, LandAttributeType8 at600, LandAttribute152191 at548,721,
Land47111 at183,062 and Portal18111 at163,680 in their respective original
Content members (including original BOM bytes). Original S32 source-neighbor,
source, destination and blocked-cell pairs were checked by byte offsets/hash as
well. The local `inactive_original_row_and_cell_byte_proofs.json` receipt has
SHA256 `48f0ae84020cbcf561757a683f15566f9d86cb3792bd7db6fb6c03e74f7213bf`.
This proves bytes and declarations, not native activation or collision semantics.


Only the newly received Content input was additionally scanned for the exact
case-insensitive literal `800f7ff3e`:all1,065 original table payloads, no match.
This supplies no placement rule. The prior8,311-member duplicate/placement
investigation was not repeated. The new local receipt
`new_content_exact_unplaced_literal_search.json` has SHA256
`b8982955b066f585f20de4d8dd229c6ab6458e3030e4b5f399e78c183140d3e3`.


Precisely missing are a trusted origin/variant selector for the literal member,
a native movement truth table separating static terrain from occupancy and actor
state, and native portal trigger geometry plus runtime activation/admission/fee
semantics. Empty condition rows provide none of those facts. No grounded
placement or automatic activation policy was established, so the source remains
losslessly unplaced and native automatic activation held. This is an evidence
limit, not an access denial. No original engine/APK/XAPK, unrecognized binary or
additional resource upload was used in that earlier placement investigation.
Its historical local evidence receipt SHA256 is
`486f1604d0d702dbd9206aa16df8f8c28b57680c112a6236384939ad9ff7abcf`.

## Additional public parser evidence, kept separate from M rules

The held nine-character original is147,158 bytes with SHA256
`bc79ea23c3ba0443f57f45bff55cce72390d9011c3db50b79c8c21359e143e11`.
Its standard Git blob hash (`blob <length>\0` plus original bytes) is
`e59b6e941ce13091f8945edb3b4dd2c798b47e35`, matching the public tree metadata
for `data/4/800F7FF3E.s32` atL1MapGen revision
`9b94e284585ae9717dd4aa858fe7b249c4d1fc70`. This is a byte-identity/provenance
observation using held M bytes and public metadata; no PC asset was fetched or
installed. That revision's [MapFileName parser](https://github.com/zajako/L1MapGen/blob/9b94e284585ae9717dd4aa858fe7b249c4d1fc70/src/jp/mapgen/MapFileName.java)
requires a full eight-hex match, and its [filter](https://github.com/zajako/L1MapGen/blob/9b94e284585ae9717dd4aa858fe7b249c4d1fc70/src/jp/mapgen/MapFileFilter.java)
rejects invalid names. Thus shared historical bytes do not supply a ninth-digit
selector or origin. The original stays unplaced and unchanged. Local comparison
receipt `current523-nine-character-public-blob-comparison.json` SHA256:
`4f6436590561c19a341d3f3a1eaef3cfbf801efeb7b527d1242ebf40e5434c44`.

The same project's [PC writer](https://github.com/zajako/L1MapGen/blob/9b94e284585ae9717dd4aa858fe7b249c4d1fc70/src/jp/mapgen/writer/V1MapWriter.java)
separates movement and arrow-passage tests, includes an explicitly uncertain
zero-upper-bits fallback and rewrites some complete output chunks as margins.
Its [loader](https://github.com/zajako/L1MapGen/blob/9b94e284585ae9717dd4aa858fe7b249c4d1fc70/src/jp/mapgen/L1MapPart.java)
reads8,192 16-bit S32 values, while the [V2 writer](https://github.com/zajako/L1MapGen/blob/9b94e284585ae9717dd4aa858fe7b249c4d1fc70/src/jp/mapgen/writer/V2MapWriter.java)
writes one byte per value. This lossy PC conversion cannot authorize a change
to M collision, safe/combat zones or original high bits. The own allowlist stays
separate and unchanged; no new tool binary or original engine was run.

PakViewer's [MTil correction](https://github.com/tony1223/PakViewer/commit/d77d720bb35f24fa695bea98efb150ebc0b90305)
and [pinned parser](https://github.com/tony1223/PakViewer/blob/d77d720bb35f24fa695bea98efb150ebc0b90305/src/Lin.Helper.Core/Tile/MTil.cs)
were compared narrowly with the existing decoder:the0x40 default and0x01 table
selection agree; conversion preserves lower flag bits except adding its separate
compression bit. Our decoder already preserves original flags and never adds an
overlay-specific alpha rule. Four held originals, TI2 IDs0/141/1211/3599, passed
raw SHA/strict decode/byte roundtrip and their existing coverage RGBA hashes.
Tile141 has44 nonempty special-flag frames;3599 has8, including raw0x12. This
checks retained bytes and current coverage, not native compositing or a run of
the public viewer. No pixel counterexample justified changing the decoder or
packs. The7557 full suite was not repeated. Local narrow receipt
`new_mtil_d77d720_narrow_actual_samples.json` SHA256:
`90cd2e9a5356417173da236284b5db2dd44322760b88934b5e6640fadde977c2`.

## Remaining logical identities: actual Main delta

The577-root play evidence originally visited577 logical IDs. Earlier11-region,
portal, long-route and inactive-restriction Main checks used those same IDs;
the separate997-field audit was static source-class verification. Exactly420
ordinary logical IDs on107 already-tested physical roots therefore remained.
The new QA plan subtracts actual passed IDs, verifies source/physical-proof pins
and every selected PR230 shard/condition-file identity, and reuses the existing
original clear/blocked/outside probes for each exact declared AssetPath. These
are explicitly labelled own QA coordinates, not natural entries or admission.
No input or geometry pack was rebuilt/downloaded.

All420 were actually selected through existing Settings and opened in Main.
Checks cover exact Land declaration/field map ID/HUD/minimap, separate field
state, genuine owning definition shard, complete raw Land attributes/time/weekly/
competition links and all own Portal rows, physical walking and blocked motion,
outside refusal, failed-entry preservation, actual save, teardown/reentry and
exact pose/identity restoration. Portal-less siblings do not inherit a shared
root's Portal.405 IDs have attributes,91 have time-limit links and2 have
competition links; those rows remain raw/held rather than granting admission.
Land49722 and49752 each retain14 attributes and three different Portals. Their
cross-logical stale-request rejection was verified even with identical actor
position on the same geometry. Same-logical teardown/reentry also rejects the
old request.

The three-ID pilot passes116 checks in66.466 Godot seconds; the remaining417
pass17,466 checks in1,215.915 seconds, with70-entry progress checkpoints and no
failed ID. These17,582 new checks are distinct from the preserved12,558 physical
checks. Their disjoint ID union equals all997 ordinary IDs, with no excluded
Land added. This establishes representative QA execution per logical identity,
not every cell, logical entrance, server/event period, original NPC/combat state
or native admission. Per-ID restore uses the actual restore method after
teardown within the process; it is not997 new OS processes. Previous separate
new-process evidence remains valid for its stated scope.

The existing UI was reparsing its17MB catalog on every source entry/restore.
It now caches one verified identity and rehashes current bytes before reuse.
A rejected candidate cannot replace the valid parsed cache or show its stale
listing. Runtime and UI caches are separate; each parsed its catalog once per
bulk process. Independent reproduction also found refresh changed12582 toLand0
while retaining the old explicit-coordinate checkbox, and a rejected pin left
that checkbox active. Refresh now retains the selected ID for the same verified
catalog; a different identity/selection or rejected candidate clears that input.
This changes no source coordinates, stored cursor, geography, allowlist or fee.
The focused real-Settings tests distinguish component checks from actual Main.
After the final selection/input guard,8 actual-Settings component checks pass in
53.31s and a deliberately focused three-ID Main regression passes119 checks in
73.671 Godot seconds. Those repeated IDs are not counted as additional coverage.
The final default-off Main/save gate passes35 checks in61.13s. Combined local
receipt `current523-logical-scope-final-evidence.json` SHA256 is
`563fb9dd79a3433697268dfe9a28e26e57db14b24f061fa3dcd762da3fc06396`;
it records code hashes, source/provenance receipts and individual test results.
The environment transport lost a wait handle during refresh, but the original
Main process and flushed progress survived; its successful result was recovered
without launching another copy or repeating completed logical slices.


The local delta receipt `current523-remaining420-actual-main-delta.json` has
SHA256 `6ca73f585ec2102ecb640863505e20b45f2bb87d11f2318f3146ce34471e2bc0`.
It includes exact old/new/combined ID sets and the individual row/result hashes.
The420-ID set SHA256 (sorted compact JSON) is
`9cd891e6a453a40dfdb5e2ea9924eae597b4a375bc9c3dc3c8af3e5bab1f4e34`.
Recreate the private input with `tools/map_restore/make_current523_logical_cases.py`
using the exact source/physical-case/passed-row/owner pins above; its output
matches2,260,219 bytes/SHA256
`a51c280da5c9015b62ec654e7440d340362e9b0796f1571a44d7e1d9fe3dcc90`.
The generator refuses a destination within Git or the original source tree and
creates owner-only output. Original rows/probes and screenshots remain private.
Run `tests/current523_logical_lands_main_test.gd` with an explicit bounded
`--start`/`--limit`, source/tile/definition pins and new local progress destination;
completed ID slices need not be repeated.

Exact additionally checked logical IDs (no new physical roots):

```text
12156 12362 12372 12442 12582 12592 22582 22592 22821 22961 42851 42861 42983 43014 43043
43053 43073 43083 43093 43103 43112 43123 43163 43173 43383 43413 43423 43433 43443 43453
43722 43752 43762 43772 43782 43792 43812 43822 43832 43842 43981 44183 44193 44203 44213
44222 44223 44232 44233 44242 44243 44262 44272 44282 44292 44302 44312 44322 44332 44342
44352 44362 44372 44382 44392 44413 44431 44441 44461 44471 44481 44494 44514 44521 44542
44671 44763 44773 44783 44793 44803 44813 44823 44833 44843 44853 44863 44873 44883 44893
44903 44913 44923 44933 44943 44953 44973 45003 45111 45121 45141 45151 45181 45213 45231
45374 45384 45394 45404 45414 45434 45444 45454 45464 45484 45494 45504 45514 45524 45534
45544 45554 45564 45584 45594 45604 45614 45624 45634 45644 45654 45664 45684 45694 45704
45714 45724 45734 45744 45754 45764 45784 45794 45804 45814 45824 45834 45844 45854 45864
45884 45894 45904 45914 45924 45934 45944 45954 45964 45984 45994 46004 46014 46024 46034
46044 46054 46064 46084 46094 46104 46114 46124 46134 46144 46154 46164 46184 46194 46204
46214 46224 46234 46244 46254 46264 46284 46294 46304 46314 46324 46334 46344 46354 46382
46383 46423 46443 46463 46473 46503 46541 46591 46623 46713 46723 46733 46761 46803 46823
46843 46853 46893 46903 46913 46964 46983 47001 47002 47211 47222 47272 47283 47433 47671
47693 47783 47911 47921 47931 48024 48044 48063 48073 48152 48262 48272 48282 48292 48302
48313 48332 48378 48403 48443 48458 48473 48494 48504 48611 48622 48633 48644 48654 48664
48674 48684 48694 48704 48714 48724 48734 48748 48758 48908 48928 48952 48973 49144 49154
49212 49252 49262 49274 49293 49338 49392 49402 49412 49422 49502 49521 49593 49604 49653
49658 49663 49693 49703 49721 49722 49732 49742 49752 49762 49772 49788 49811 49821 49834
49844 49854 49864 49874 49884 49894 49904 49914 49924 49934 49944 49954 49964 49974 49984
49994 50004 50014 50024 50034 50044 50054 50064 50074 50084 50094 50104 50114 50124 50134
50144 50154 50164 50174 50184 50194 50204 50214 50224 50234 50244 50254 50264 50274 50284
50294 50304 50314 50324 50334 50344 50354 50364 50374 50384 50394 50404 50414 50424 50434
50444 50454 50464 50474 50484 50494 50504 50514 50524 50534 50544 50554 50564 50574 50584
50594 50604 50614 50624 50634 50644 50654 50664 50674 50684 50694 50704 50714 50724 50734
50744 50754 50764 50774 50784 50794 50804 50814 50824 50921 50941 50951 50971 50981 51011
51031 51041 51051 51068 51084 51094 51108 51132 51142 51152 51162 51172 51218 51242 51253
```

## Interrupted movement and pending input

A focused gap remained after the representative visits:invalid destination
clicks had been checked from rest, but not while an accepted route was moving.
Actual Main reproduced an old path continuing about30.01 world pixels during
eight subsequent physics ticks after a new blocked or outside destination.
The held blocked probe is `(32316,33594)`, raw pair`[1,0]`, from
`Map/Aden/7ff8800c.s32`, SHA256
`f736c0e91008bb2f035e8d8994871ab6f0ed8d848c5c4cb7b5225af17992da89`.

Source fields now stop the superseded click route and show a no-confirmed-path
message when the new direct destination has no complete own-policy route.
They do not snap to another cell, enlarge the search bound, change collision or
invent native passability. Other map input behavior is unchanged. Rejected stale
Portal walk tickets still preserve an already accepted route:they are not new
direct destination clicks.

A second actual reproduction held a touch across source close. Because the
source mode preserves the original host `active_map_id`, the legacy gesture's
map-string guard did not notice the changed field/camera. Releasing the old
touch started a one-point host route. Source close and successful generic manual
Portal commit now cancel that pending gesture. Cancellation occurs only when
the field really changes; a refused atomic-checkpoint commit preserves the old
field, accepted path and touch. No Portal/admission/cost rule changes.

Focused actual Main checks cover starting the existing1,077-point long route,
blocked/outside retargeting during motion, six rapid valid destination changes,
manual cancellation without later route resumption, definition-generation stale
requests while another valid walk is queued, original seam movement with exact
source/world/camera consistency, invalid restore followed by valid exact-pose
restore, and held input during failed/successful manual1101 transition. The
first fixed run passes62 checks. The final strengthened run passes63 and retains
the actual physically reached fractional seam pose through later field visits:
source`(32320.0592447917,33595.5)`, world`(41365.421875,19913.2890625)`.
Its camera inverse error is0 and source/world roundtrip is exact. The full old
174.579-second route was not repeated; the same original route/probes were reused
for interruption tests. Blocked/outside continued distance is now0 pixels, and
release after source close queues no host path.

Initial diagnostic logs are retained. The open long-route start had no blocked
cell within the small probe radius, so that negative setup was discarded in
favor of the already verified original wall probe. A clear short route correctly
compresses to one point; an initial point-count expectation was corrected to
require a nonempty complete route with the exact goal and actual movement.
Those setup assertions are not reported as product defects or clean passes.
No original cell/geometry was invented to satisfy them.

The separate new-process check passes12 checks in71.14s:the physically reached
fractional pose is restored exactly, no cancelled path/touch resumes, and
progress/rewards/save bytes plus host lives remain protected. This is additional
focused interruption coverage, not another997/577 run or native collision proof.
The final default-off Main/save gate passes35 checks in61.09s. Local combined
evidence `current523-movement-quality-final-evidence.json` SHA256 is
`0a8d4a7ed9a627dfa80e3e1eeb8efe28027a72479f7b2fe5bfdefa2ada60723d`. It retains the reproduction, final
63+12+35 results and exact code hashes. Original source/tile packs, restrictions,
search bounds and the17-part Drive application bundle are unchanged.



## Execution evidence and limits

Latest complete-input checks use the source and tile pins above:

- Current523 explicit inactive restriction correction:37 actual Main/UI checks in
  106.85s and19 new-process checks in71.91s on nativeLand47111 (`13313/`).
  The existing Settings scroller visibly exposesNoTeleport=false and remaining
  conditions. Ordinary player physics reachesPortal18111's exact declared
  source; an original raw[1,0] neighbor rejects path and physical entry. Stale
  definition requests and held transitions preserve field/state/save bytes;
  new-process restoration retains exact cursor, raw inactive evidence, all
  remaining holds and safe initial-host return. This is focused regression of
  an already covered root, not additional577-root or native activation coverage.
- The genuine provider passes26 unit checks with the unchanged original owner
  and pinned definition pack, including copied raw inactive rows and safeguards
  for missing/nonzero parameters, wrong units, unknown types and scoped rules.
  An initial stateless invocation emitted unwritable default log/data-directory
  errors; it is not counted as a clean run. The recorded rerun uses an isolated
  writable XDG profile and has no runtime/parsing errors.

- Final default-off Main/save regression passes35 checks in87.90s. Existing
  tracked resource integrity remains723 atlases /41,442 frames /233,420,026 bytes.
  The combined local receipt `current523-inactive-restriction-final-evidence.json`
  has SHA256 `ad98d8c2589898bb293d57ae789a2b3621bfea2d2e8a73df5a540542d6835348`;
  it pins code file hashes and individual entry/reconnect/provider/core receipts.
  No full577-root rerun or full/manual CI was invoked for this bounded change.

- Final actual Main run on the already authenticated Drive fresh-consumer
  installation:all577 distinct ordinary physical roots pass12,558 checks in
  1,436.192 Godot seconds (1,450.89s outer runtime). The visited AssetPath set
  exactly equals the577-root normal catalog; those fields contain all6,557 placed
  S32 packets. These are representative probes per physical root, not by themselves997 distinct
  logical-Land gameplay visits or every-cell/every-portal/native admission tests.
  The separately recorded420-ID delta above fills representative logical-ID QA.
- Every root checks actual entry/GL frame/HUD/minimap, player-physics walking,
  blocked-cell physical refusal, outside-field path denial, original host return,
  actual game save, field teardown and the real source-restore entry method.
  All577 retain the exact runtime world position and source cell on restoration;
  computed world-position error is0 pixels, without an epsilon comparison.
  This bulk restore runs in one OS process; separate new-process tests are listed
  below. The bulk GL resolution is640×360, software OpenGL/Godot4.7.2.
- 482 roots physically cross an original chunk edge;5 exercise a closed edge with
  physical refusal;36 have both sampled edge cells denied by the own policy;
  54 have no adjacent original chunks and retain outside-path denial.139 QA
  entries use an exact native Portal.Source coordinate,438 explicitly use an own
  first-clear-cardinal-edge position. Neither is original admission proof.
- The final run covers the off-floor artwork fix in161 roots. There are no
  unresolved visible tile references, budget skips or safe-return failures in
  the recorded probes. Source and tile catalogs each parse once, with a32-atlas
  persistent cache. Existing source/metadata bytes and private Drive packs are
  unchanged; this test reuses the verified fresh installation, without another
  download, upload or independent physical-copy claim.
- All997 ordinary logical fields /577 physical roots:55,747 Godot assertions,
  with every available original's SHA and independent raw word/floor probes.
  All6,558 originals are registered;6,557 are placed and one remains unplaced.
  Every logical row is checked, including shared physical roots and high IDs.
- All26,861,568 original S32 cells were independently examined under the current
  own allowlist.7,930,810 cells qualify; every one of577 roots has at least one
  clear cardinal adjacency. This is an own-policy data audit, not native collision
  validation or an actual player visit to every cell.
- All7,557 actual TI2:15,235 Godot checks, every expected Python coverage hash,
  bounded native Brotli decoding, physical last-frame/padding rejection and32-atlas
  LRU checks.4,457,299,968 RGBA bytes were independently compared by hash;
  all actual S32 reference frame indices are within their original physical count.
- Complete gzip/source and runtime-TI2 packs in actual Main:34 checks in142.05s
  for settings997-Land listing, Land1 entry, walking, physical blocked-cell refusal,
  outside-region denial, exact return, failed-switch preservation and save safety.
  A new process restores the same source cursor with8 checks in66.75s.
  The copied geographic contract and explicit safe-region landing policy are
  exercised separately from native arrival/admission semantics.
- Complete-input manual portal adapter:54 actual Main checks in118.22s for
  clear1101 Land1→Land0, blocked523, missing arrival textures and checkpoint-write
  failure rollback. New-process target restoration and initial-host return:31
  checks in81.85s. The provider is an explicitly pinned TEST adapter, not genuine
  PR230 production binding or native automatic activation. Two previously
  uninitialized ready host bosses reconstructed as exactly one healthy actor each;
  cooldown/progress/rewards and stored save bytes stayed unchanged.
- Genuine PR230 production binding:27 actual Main/UI checks in122.13s;
  new-process source restoration, definition rebind/status, stale-route refusal,
  initial-host return and exact progress/save preservation:14 checks in70.90s.
  This uses the unchanged production owner and authenticated definition pack,
  not the earlier TEST provider. Portal330's clear physical endpoints remain
  held by original target MinLevel70 and LandTimeLimit; the UI reports the hold.
  Explicit own manual1101 crosses Land1 to the exact native Land0 point.
  Native automatic activation/admission is still not verified.
- Focused regressions:input-cache10 checks; provider18 checks (authored scoped
  condition guards plus actual owner-pack declarations); travel69 checks;
  renderer105 authored display/guard checks. Authored cases are not original-M
  behavior evidence. All original native Portal350 coordinates remain unchanged.
- Default-off actual Main/core save preservation:35 checks, rerun on the final
  full-map checkpoint in66.06s (`current523-followup-core-save-receipt.json`);
  the portal-walk continuation passes again in72.65s as recorded above. Tracked resource
  integrity:723 atlases /41,442 frames /233,420,026 bytes, unchanged.
- Python source builder11, TI2 builder21 and core harness8 focused tests pass.
  Source-pack snapshot isolation and matching external-pin checks also pass.

The actual play controller now shares one verified source catalog and one tile
catalog too, across entry/restore/hops. It rehashes current manifest bytes before
reuse, retains the last valid cache after a rejected candidate, and keeps
independent per-field registries and original-byte checks. Atlas LRU remains32.
The31-region exact-pose recheck parsed source/tile catalogs once each.

The earlier31 cursor mismatches were ConfigFile decimal f64 representations,
not changed game positions. Requiring exact decoded runtime Vector2 and the same
source cell passes all31 targeted checks (672 assertions), then the final full
577-root run. No save schema, source value or movement coordinate was changed to
make the checks pass. Failed/diagnostic logs are preserved.

The full logical-field audit shares a verified immutable catalog snapshot rather
than reparsing the same17MB JSON997 times. Every selected field owns separate
registries/caches and still checks original bytes before use. Wrong pins and
clearing one copied catalog cannot clear its parent or sibling. The earlier slow
repeated-parse run was stopped as PARTIAL_NOT_PASS; its log is retained.

Historical actual Godot4.7.2/OpenGL checks on earlier immutable packs:

- Initial generic Land1 UI entry/movement/blocked-cell/return/save:28 checks,
  102.42 seconds; new-process reconnect:8 checks,59.68 seconds. Source v2 and
  exact73-TI2 subset were used; this does not describe the later v4 pack.
- Generic source v3 and3027-TI2 v2: native0/1/2/3/807 entry, walking, raw denied
  cells, distinct original chunk seams, return and unchanged progress/save:
  89 checks,164.26 seconds. Lands808/809/810:55 checks,142.11 seconds;
  Lands811/812/813:55 checks,121.86 seconds. Every run kept the180-second limit.
  All11 physical roots were rendered and moved through, including one two-member
  seam per root. This is not every-cell, every-portal or all577-root coverage.
- Original source v4 field:4,060 checks across all20 available logical Lands and
 905 distinct source files, with original file SHA and three independent raw-pair
 probes per placed chunk. Generic pack57 checks; private builder7 tests.
- Tile v2:3,109 Godot checks across all3027 actual originals/PNG/RGBA records;
 12 Python tests. Actual originals are separated from authored fixture assertions.
- Pure travel planner:80 checks with pinned actual source/handoff input, including
 clear1101 and blocked523; no native activation or Main travel claim from this test.

The first regional test run failed because its helper centered already-centered
coordinates again and compared parsed numeric arrays without normalizing numeric
types. The corrected helper checks the actual source-cell round trip and compares
numeric values; the original failed logs are retained. Production coordinate
conversion did not need changing for this harness error.

Local logs/screenshots and receipts live under `/workspace/aden-validation/`.
`CURRENT523_GENERIC_SOURCE_V4_EVIDENCE.json` and
`current523-unified-ti2-validation-v2.json` separate raw byte verification from
runtime claims. Latest compact receipts are
`current523-all997-fields-verified-snapshot-v5-receipt.json`,
`current523-all7557-runtime-ti2-validation-receipt.json`,
`current523-all6558-own-cell-audit.json`,
`current523-all577-actual-main-final-evidence.json` and the Main logs under
`display/all577-final-fresh02/` and `display/production-portal-production02/`.
The final compact evidence receipt SHA256 is
`fbbf76b958363d1bd20ec995230433187d2d4399919365ea175521325d600f6c`;
577 per-root JSONL SHA256 is
`82ee7504349e97c4cebd3643531164f828d14a09def4826a12a19590361c3d35`;
actual Main log SHA256 is
`859b51c4618abfe796724872e603a2eb8f2c042f09b44d565fe85cae7fd321e2`.
These logs/frames/receipts remain local, not newly uploaded reports or captures.
The original acquisition and normal-map TI2 closure are complete. Native
collision/activation/admission, unplaced Aden geometry, SEG decoding and
every-cell/every-portal play coverage remain separate limits. SEG alternatives
do not represent12 missing regions.

The deferred seven-region harness completed43974 before its two-region180s run
timed out; it is not a passed seven-region suite. The local harness/log/capture
are retained. The user's later whole-map-first priority deferred further Totem
integration, including EXP/growth/admission/UI feature work.

Tracked resource integrity remains723 atlases/41,442 frames/233,420,026 bytes.
Code goes to the same draft PR232 with `[skip ci]`; no other branch/main merge,
manual CI dispatch, M engine/APK/XAPK work, or excluded arena/ziggurat/guild/siege
content was introduced. Latest-main overlap and integration conflicts are reported
separately; this continuation does not merge those changes silently.

## Reproduce the independent physical-region probes

The code-only `tools/map_restore/make_current523_gameplay_cases.py` reads the
pinned private source pack and existing1,150-Portal handoff, verifies original
stored/raw SHA identities, and derives clear/blocked/seam probes independently
from raw bytes. It requires NumPy and refuses to replace existing output. Its
output contains original evidence and stays in private storage, outside Git.
Reproduction from the received whole input is byte-identical:2,890,183 bytes,
SHA256`8ec55062637bd48eb122e18cfe81d1993b914b8921ef71e4a0a02aad5f50e5b6`.

```sh
python3 tools/map_restore/make_current523_gameplay_cases.py \
  --source-root /private/source523 \
  --source-sha256 6b71f4adb533b7acae6a7327e83af1b1322001a0f67c417bb3fae1bec35d96ca \
  --portal-rows /private/all1150_portal_source_target_rows_with_scope.json \
  --portal-sha256 ba3619ad35f72cf49c271605b32c7a0e516fddeb5fc2c17d33da2c16d05eacea \
  --output /private/all577-gameplay-cases.json
```

`tests/current523_all_regions_main_test.gd` takes `--source-root`, `--source-sha`,
`--tile-root`, `--tile-sha`, `--cases`, `--cases-sha` and a private `--progress`
JSONL path. Optional `--start`, `--limit` or unique bounded `--indices` select a
subset without changing the exact original cases. Run on the warmed Main project
with the existing verified host source pack, isolated XDG profile, Godot4.7.2,
X11/software OpenGL and Dummy audio. It has an explicit30-minute budget,
per-region progress flush and bounded local frame contact sheet. It never
instantiates the inherited TEST provider. The production portal Main test is
separate and requires the actual pinned PR230 pack and independent held-route
proof; neither source QA positioning nor fixture assertions count as admission.

The initial genuine-provider new-process helper wrote its comparison JSON with
rounded default precision for large boss wall-clock values. The real saved bytes
and SHA were unchanged. Recording that expected state with the same full-precision
JSON as the real writer fixed the helper; the subsequent27+14 actual checks pass
with exact state/save comparisons intact. Failed helper logs are retained and
are not reported as passing runs.
