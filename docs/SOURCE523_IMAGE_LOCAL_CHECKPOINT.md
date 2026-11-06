# Image/icon sector handover — 2026-11-06

This checkpoint preserves completed Image-owner code and source research on
`feature/original-image-consumers-next-20261105`, starting at public PR283
`becdee85ee18d45459bcff44d5f9ec51e7b5ba40`. It is a local commit only: no push,
merge, resource delivery, selected-pack change or observed rendering is claimed.
The last supplied main comparison is e1513f7da10d6282f1ea7b8bdabe9606843b52fa;
this checkpoint does not replace its actor/GPU changes or claim a fresh main read.

## Current instruction and repository state

Status: PAUSED after this documentation/local-save checkpoint. UI, Map,
Integration, Image and Data must remain paused; only the independently owned,
already-scoped Sprite work may continue. This document is not restart approval.
Future image work is limited to item, polymorph, relic and doll. Preserve all
normal existing functions and source files even where new work is excluded.
Do not reopen quest rewards/slots, potion, ambiguous spell-stage, emoticon,
sound, new NPC/attendance/pass/dungeon image work, ground-loot replacement,
Sprite28, Rosemary12 or the excluded unknown98+dummy identities. GPU/general
Godot/Android/phone diagnosis remains paused. Spell-stage exclusion does not
mean every skill or transformation effect is removed.

Repository: zoog136-hash/-, current checkout /workspace/-, existing Draft PR283:
https://github.com/zoog136-hash/-/pull/283 . The local continuation has not been
pushed; do not describe unpushed commits as GitHub URLs or merged main.

| Commit | Local checkpoint scope |
| --- | --- |
| becdee85ee18d45459bcff44d5f9ec51e7b5ba40 | Starting public PR283 head; earlier collection/confirmation consumers already present. |
| f96493baed4cff4b4b7d72042bd1744a36f28e1e | Five Image-owner source files and initial source/research index. |
| 13b113f2819a00bf633aa8d77266de5eec0cb850 | Documented held-code retention. A normal add omitted the new sparse-excluded artifacts; this commit is documentation only. |
| f5b14516c823afce85ae85c751c78106e1ecf0e5 | Exact held patch/index explicitly staged with --sparse. No sparse rules changed. |

The handover update is a subsequent documentation-only commit, identified in
its delivery response and Git log. Prior commits must not be amended/rebased.
At the start of this handover write, the owned worktree was clean and there
were no pre-existing dirty/untracked project files. Check again before any
future authorized edit. No active commit hooks were configured; only sample
hooks existed at checkpoint time. All local commits retain [skip ci].

## Resumption and code-only restoration (not authorized to run now)

1. Obtain this branch/commit chain through an approved transfer. Verify the
   held JSON's checkpoint_base_commit and patch SHA before reconstruction.
   The artifact is source code only; it is not a runtime resource package.
2. Use a new empty isolated code directory, not the active game/phone root.
   For every snapshot_files entry with a non-null base_blob, read that path
   from f96493ba with git show and materialize it under the same relative
   path. Require its Git blob to equal base_blob. Missing/new paths are left
   absent. Do not fetch large history or invent a file if the base is missing.
3. Apply the held unified patch with strip level1 and zero fuzz in that
   isolated directory. Require every reconstructed member's bytes, SHA256
   and Git blob to match snapshot_files, including the three unchanged
   Image files. These byte comparisons are not parser/game validation.
4. Stop at INCOMPLETE/HELD. The index's unapplied_action_patch is evidence,
   not part of the applied snapshot. It requires the exact earlier producer
   base identified below or its exact final complete source. Do not apply it
   to the older local Action, substitute a stub or omit lifecycle calls.
5. The preserved UI owner code is a dependency candidate. Future approved
   integration must compare latest real main and the active UI owner's work,
   then preserve unrelated changes with narrow hunks. Do not replace the
   owner renderer/HUD wholesale with this snapshot. Current e151 actor/GPU
   work must not be reverted or enabled by this image task.
6. Only after explicit restart/integration/resource-selection authorization
   should an owner complete dependencies or select packs. Tests, parsers,
   compiler, game/render, CI, push/merge/upload and phone operations remain
   prohibited until separately authorized. This handover runs none of them.

## Completed Image-owner code

| Path | Result Git blob | Conditional behavior |
| --- | --- | --- |
| scripts/resources/source523_image_pack.gd | 8f1548696fce46b1163c720976bc0230813c8c64 | Admit only the exact pinned 1,216-member retained-original supplement; preserve decoder identity and reject missing/conflicting extent. No automatic root selection or old-pack fallback. |
| scripts/ui/source_card_presentation.gd | 28e60fa8d7e5ff3574c6b6fa7fc38f25edc19abd | Actual selected deck1/2/98 application button uses admitted DisplayBaseAssetID pixels; texture ObjectID and expand_icon ownership guard preserves later writers. |
| scripts/ui/relic_reference_view.gd | 54bb0dceebac1be8fcc7b0034ec9fbcb038b3687 | Same actual selected HolyStuff/deck98 image on the existing secondary action, with guarded clear/refresh. No summon/transaction rule changes. |
| scripts/ui/source523_image_assets.gd | 8af861459c4f63e1c661c8af141702b422f91d7e | Explicit ok=true only after original static Texture2D resolution; pending/CSB results remain false. |
| scripts/ui/source523_original_ui_icons.gd | 180733119a945d2546acac74aacf84e1b663bf84 | Separate typed live Forge equipment host descriptor, actual Script identity and receiver validation required; existing original-registration branch preserved. Empty bindings, no playback, original_registration_confirmed=false. |

Button.icon additions are explicit host indicators, not recovered original CSB
button-image roles or original-controller registration. No authored layout,
transaction, quantity, ownership, save or click implementation is changed.

## Durable private research and candidates

Retained in this executor under the existing project-private sibling
`/workspace/image-icon-private/`, outside the Git allowlist:

- `audit/four-scope-20261106/`: source path/hash/size ledger, source joins,
  excluded/shared roles, source searches, code witnesses, patches and exact
  artifact receipts. `file-ledger.json` distinguishes conditional footprints
  from unknown consumers and runtime use.
- Complete five-item source hierarchy/timeline contract:
  `compact-five-item-complete-contract.jsonl`, 33,661 bytes, SHA256
  bcc170c66e19c395fc947e82c59b79fcba5b467e29bdc035268de8ea2f82f3df.
  The ten ItemClass IDs are source-linked candidates, not observed owned or
  currently selected records. Full original clip/blend/transform declarations
  are retained; no trigger/repeat policy was invented.
- Original-only supplement ZIP: 36,827,042 bytes, SHA256
  4ef8330922c499d9aaf0ca7a7f973495041ef1d0d97fb6041cac13f3cfe3cc9c;
  1,216 unchanged PNGs / 39,385,255 original bytes. Supplement manifest pin
  5855a8b82d675e8697d3585b37482e183c26a7e8ca9d42d453bb16d416eaceea.
- Separate combined root `source523-original-image-pack-combined-four-scope-20261106`:
  manifest pin 26639a29bbd6231655159ad219955c8448316fd619f4514b5fa85e89bb072466;
  17,291 payload files / 824,992,561 bytes, including 17,278 original image
  members / 680,508,571 bytes. Application contract SHA256
  e65ff8eec6e2abecf0e67790c769afcbdbfbd04e6cc768a7cb6fa15c2459f531.
  This root is not delivered, selected, installed or counted as main use.
- `integration/typed-item-host-20261106/`: separate partial UI/Image composition,
  exact producer baselines, full received source files, cumulative patches,
  immutable public dependencies and file-by-file receipts in
  `composition-state.json`. UI-owned worktree files were not overwritten.

These are consumer-local retention locations, not proof of transfer to another
executor or durable external delivery. Original sources, historical packs and
all candidates remain intact; no large asset copies are included in Git.

## Committed held code snapshot

`docs/checkpoints/image-ui-integration-20261106.held.patch` and its adjacent
`.held.json` retain the exact separate 14-file code snapshot against checkpoint
f96493baed4cff4b4b7d72042bd1744a36f28e1e: eleven changed files are encoded in
the patch, three unchanged files are recoverable from that commit. Patch size
72,206 bytes; SHA256 e449d2fbea8b56c4f9ee2d37ffac1f13e83af38f6c26142c5a814a7f5eb34bfe.
The index includes every baseline/result blob, byte count/SHA, and the received
but unapplied Action delta. It explicitly marks INCOMPLETE/HELD and the missing
Action producer; it contains no raw resource datasets or media. These are
retention artifacts, not files applied to active game paths. Earlier private
copies remain preserved; reconstruction no longer depends on those paths.

## Static accounting and integration gates

The existing audit identifies a four-scope field-join subset of 5,155 original
members / 71,287,359 bytes within the 17,278-member catalog. Its earlier main
conditional-consumer lower bound is 55 members / 1,484,167 bytes of file
footprint, not full-file use or newly observed progress. The new code is not
assigned a runtime numerator. Shared files and partially consumed files must
not be added as independent whole-file use across sectors.

The separate UI composition has exact producer-result matches for:

- source_asset_scene.gd: 8e86de5eb8b3b85e7d358a42c564328e9c18ff6b
- sprite_scene.gd: 38f65793140ddc5054ef5905409d8a95a688df33
- source_main_enhance_slots.gd: 50a9a1fd58d76b45f1702b7630484acceb9a6421
- source_item_scene_receiver.gd: a2b985d54e5f2f038711519078256d8327b898f5
- source_main_hud.gd: 546fc7e7f02d242d297a7fd94d242bc4333be51f
- card_reveal_card.gd: 223ef427ac6840e4e37ad1160bb566e6090e5f4e
- source_result_face_host.gd: c3478da151fc0a04dc25918940b2c9c7d335ca8e

Forge integration still needs the producer's source_main_enhance_action.gd:
required patch base c3fb8e0c9ca0de1fb30713d48b6f79db8cc5f335 is unavailable
locally; actual worktree blob is 2fee775a1178a15bf3c75eb12f50d44531f7f7cf.
The supplied final identity is 625d5adbc198de07159471e29fbb3782df39f3e6,
14,937 bytes, SHA256 0e9330ffc33a13c2329f79e7fd15decd60d0e67c0b29a528fc2798dd2754e3eb.
No mismatched baseline was patched and no stub was substituted.

The existing result-card provider 4faf1dcb3cf3e5eecd0a541a6ac3512fe57f1bc8
matches the received BACK helper's actual record/phase/provenance shape.
The helper retains complete original back ancestry beneath an explicit host
Face-centre affine bridge; it does not prove original FRONT insertion.
Front portrait registration, absent Myth/Sole/event back variants, source
transition playback and whole-stage background remain separate unproved roles.

New image scope is item/polymorph/relic/doll only. Quest new work, sound,
potion, spell-stage and emoticon work remain excluded; physical originals and
existing shared systems are preserved. Sprite28 and the other sector exclusions
are not reopened. GPU/general Godot/phone work remain paused.

No tests, GDScript parser, compiler, game, renderer or CI were run, as explicitly
instructed. Static text composition and artifact byte/hash checks are not
runtime validation. Frozen phone v30/62ZIP/index/source bank, active selections,
settings and saves were not changed.

## Exact runtime contracts and owner boundaries for a future restart

Image owns original asset resolution, provenance and consumer adapters.
UI owns original renderer/control geometry, hierarchy, input and mounting;
Integration owns physical IDs, transactions, effect/save logic and real caller
identity; Data owns original FK readers. Do not copy another owner's engine,
choose representative multi-item art, map matching numbers or filenames, or
invent a missing role/parent to make progress appear complete.

The five Item-CSB admission cases are:

| Original ItemClass IDs | IconID / AssetView ID | Original CSB basename |
| --- | --- | --- |
| 242761 / 243271 | 83331 / 320181 | Fx_Item_Armor_Pants_Myth_Eodin.csb |
| 253282 / 253292 | 83762 / 321512 | Fx_Item_Armor_Shield_Myth_Eir.csb |
| 239911 / 239941 | 83063 / 319133 | Fx_Item_Weapon_Bow_Myth_Alice.csb |
| 239971 / 239981 | 83073 / 319143 | Fx_Item_Weapon_Staff_Myth_Alice.csb |
| 253302 / 253312 | 83992 / 321782 | Fx_Item_Weapon_Sword_Myth_Alice.csb |

All members have prefix UI/CsbFile/icon/ and AssetType101=UI_CsbFile.
The first two source packs use manifest pin
566a4a66e894abdb3a761e8c0cca51d95799c52989a097030cab76839d99fb19;
the Alice cases use
ebf14ad21218b6ac7d5a9e9e68ef3c81f366b78e0e725df04e2ec69f2a5894f0.
The full ItemClass/Icon/Asset source rows, scene/atlas/PNG hashes, every
ancestor/transform/blend, clipping Panels, Glow layers and timelines are in
the retained compact contract and typed receiver constants. No owned profile
or actual selected instance of these ten IDs was observed. Source linkage
alone does not satisfy the live receiver.

Future Forge dependency order:

1. Exact selected UI destination pack must admit EnchantScene Project724,
   Enchant_All Project144788 (equipment) and the nested Common_Slot
   Sprite15012. Slot0 Project145044 is the actual scroll host. v45/v46 are
   separate UI-local candidates, not the phone's v30 or an installed update.
2. The missing EnhanceAction lifecycle implementation must create SlotPair,
   bind its nested renderer, refresh on actual owner changes and close/restore
   matching legacy views. The cumulative HUD candidate exposes
   original_enhance_slot_receiver(role) and source_role_pack(). These method
   names do not by themselves prove the missing Action exists.
3. Source_main_enhance_slots calls Images.describe_item(actual raw record).
   PNG success goes through the existing static uploader and explicit ok
   field. For unsupported_csb equipment only, Receiver.capture_forge(hud,
   "equipment") issues an actual typed RefCounted. No JSON token authorizes it.
4. NativeScenes.request forwards source_slot_contract plus
   source_host_registration to Image.native_scene_descriptor(info,context).
   Image verifies the exact receiver Script, ItemClass.IconID role, target
   identity and validate_descriptor(). It returns selected source pack/member
   pins, image_owner_identity, empty bindings and no playback key.
5. source_asset_scene.prepare revalidates, constructs the entire strict
   original scene, retains its identity root and revalidates again. The
   destination player calls validate_attachment(self,15012,descriptor)
   immediately before mounting. A required unsupported clip/blend/transform
   fails the complete assignment; nothing is flattened or replaced.
6. The receiver re-queries actual selected physical instance, raw record,
   ItemClass table/row SHA, Icon/Asset, current source/destination packs,
   complete node set and parent offsets. Freed/hidden/replaced/stale owners
   fail. Cached Forge refreshes revalidate. Clear detaches the owned scene,
   clears stale pixels and restores only the corresponding legacy preview.

This is explicit TWILIGHT_host_registration, with
original_registration_confirmed=false. The official paired-slot visual evidence
and current Forge inputs do not recover the private original controller.
The five original normal clips remain metadata only: Eodin5-154/duration154,
Eir5-161/161, Bow5-203/203, Staff5-203/203, Sword5-116/duration170; speed1.
No original trigger or repeat policy was provided. No play/seek/loop is added.

Result BACK dependency order: renewal_hud passes the already selected controller
pack to the real reveal stage; stage supplies the same pack and actual
fusion/draw operation to every real result card. The card derives phase from
its existing waiting_for_press and Face.elapsed/duration and calls the exact
source role contract. ResultImages.describe(actual_card) resolves that node's
literal fileNameData pixels with current sourceId/BuffCard.ID/GradeID checks.
ResultFaceHost accepts only deck1/2/98 and BACK, checks source provenance and
parents again, mounts the full declared back hierarchy below the existing FX
through the explicit Face-centre affine bridge, and preserves original scales.
Checkbox ancestors must have selectedState0 and empty state-image paths; input
stays with the existing RevealCard. A helper success flag would only be set
if that code actually executes; no such attachment has been observed here.

Held public dependencies were read at immutable PR286 commit
c27ee71ffe37702cc37057530951afb089fc816b:

- scripts/ui/original_ui/source_result_role_contract.gd:
  9329075ad3bec2d5edb86f98fda019a58e0fca3e.
- scripts/ui/original_ui/source_main_card_frames.gd:
  9759199b7ea7cae3a14c2e0a6dbaca6e1d0933d1.
- scripts/ui/card_reveal_stage.gd:
  44b325f502b220910b9308b6069bbcd621a9d554.
- renewal_hud producer was retained separately; only its narrow existing
  source-pack handoff was composed against the Image checkout. Full producer
  renewal_hud was not substituted for the existing one.

## Original data, search evidence and accounting limits

The source table archive identity is SHA256
d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832.
The full original image catalog identity is SHA256
026002bfa1c91a6e2c1e40b8a35d78bd40201da7ceb05ccc3539a573ff35c63d.
Use original path + SHA + uncompressed bytes, never pack count, generated-cache
size, source row count or compressed transport bytes as the image denominator.
The prior 2026-11-06 d758/e151 comparison audit measured:

| Scope/stage | Original member count | Original member bytes |
| --- | ---: | ---: |
| Whole confirmed source catalog | 17,278 | 680,508,571 |
| Distinct content SHA subset (not path count) | 16,920 | 665,388,205 |
| Current base-pack originals, possession only | 16,062 | 641,123,316 |
| Four-family confirmed field-join subset | 5,155 | 71,287,359 |
| That subset held in current base pack | 3,939 | 31,902,104 |
| That subset absent from base, now separate retained supplement | 1,216 | 39,385,255 |
| Earlier main static conditional lower bound | 55 | 1,484,167 footprint |
| Eligible members without proven consumer in that comparison | 5,100 | 69,803,192 footprint |

Unknown consumers are not proven unconnected. Partial/conditional footprints
are not whole-file use or measured consumed bytes. Local code candidates do
not update main counts. Outside the confirmed field joins,12,123 members /
609,221,212 bytes remain outside this eligible-subset proof; that is not proof
every one lacks another four-family role. Shared role paths must not be summed.
The 55 lower bound is Item6, polymorph28, doll11, HolyStuff10; it is historical
static evidence, not a fresh completion percentage or a runtime denominator.

Source-role exclusions also overlap legitimate roles: source TestItem=true
references1,159 files/8,469,514B with575 shared eligible paths; Potion category3
references163/1,200,396B with21 shared eligible paths. Do not drop the shared
file's other normal role. Explicit dummy table evidence covered14 files /
252,200B; emoticon new-work exclusions covered581/7,027,369B. Sound is outside
this image denominator. No fresh excluded-count recomputation was performed
for this handover. Full role witnesses remain in the private audit ledgers.

Search results are preserved in search-evidence.json, not redone here. Queries
included exact Enchant_All.csb/controller, Inventory_Slot0/scroll,
Change_Card_Result.csb/controller, official transformation/fusion, HolyStuff
and doll guides. The official guide evidence is:
https://lm.ncsoft.jp/guides/lm/guides/item_enchant and before/after weapon images
k003_003_003.jpg/004.jpg and armor010.jpg/011.jpg under
https://st.ncjapan.co.jp/ncjapan/ncsoft/lm/official/guide/item_enchant/ .
Those pixels support left-scroll/right-equipment visual roles, not exact
current523 ProjectIDs or original lifecycle. The UI owner therefore supplied
an explicit host contract rather than claiming recovered native registration.

Other previously consulted sources:
https://lineagem-jp.com/guides/lm/guides/card_system and
https://lineagem-jp.com/guides/lm/guides/beginner_community distinguish card
systems but do not supply exact current523 dynamic result-parent relations.
https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/editor-support/cocostudio/ActionTimeline/CSLoader.cpp
explains declared ProjectNode engine behavior, not the private game controller.
Exact-name searches did not recover that controller; a matching position/name
must not be promoted to authored role proof. The later explicit UI host adapter
resolves the supported host path, not every original-client question.

Earlier Library tools/list HTTP401 reference downloads received zero bytes.
They were not retried or bypassed. Existing source files and approved packs
were used instead. No missing identity/hash/relationship was estimated. Public
guides support interpretations only at their stated version/evidence level.

## Pack locations and explicit selection contract

Consumer-local existing base root is
/workspace/image-icon-private/source523-original-image-pack-final, manifest pin
b743a3f192ff5c4196bcd5d1775935068fe22a10a108334080be2e2fc8a1e58c.
Keep the original18ZIPs and final8part manual delivery archives in their existing
private locations; they are not code inputs to stage in Git. No new archive
was made for this documentation task.

The supplement is under project-private
`delivery/four-scope-supplement-local-20261106/`, basename
TWILIGHT_current523_four_scope_original_images_supplement_1216_20261106.zip.
Its application contract SHA is
54c41ff897d90bbd3417aa0845908c19c8248914d71cbcadb756e11a9a3feb6b.
The combined root's exact contract is
`audit/four-scope-20261106/COMBINED_ROOT_APPLICATION_CONTRACT.json`.
That fresh candidate copied originals without hardlink-modifying base metadata;
conflicting same-path content and unsafe paths were rejected during its prior
packaging. Original-byte hash/readback is packaging evidence, not game loading.

The existing explicit loader pair, only when separately authorized, is
`--source523-images=<consumer-local root>` plus
`--source523-images-sha256=<exact manifest pin>`, or
TWILIGHT_SOURCE523_IMAGES / TWILIGHT_SOURCE523_IMAGES_SHA256.
A receiving environment must actually possess the root before setting it;
there is no automatic root adoption or fallback to old self-authored packs.
The separate UI selector/pin is not this image selector. Source-CSB packs must
also be explicitly opened with their own manifest pins and exact dependencies.
No config, selected pin, phone receipt or installation changed here.

## Remaining work and stop condition

Current required action is documentation/save, then remain PAUSED. If a later
user explicitly resumes image work, first obtain the exact missing Action
producer from UI, compare source and dependency hashes, and finish only the
held narrow lifecycle composition. Confirm actual source pack admission and
caller/provider registration without auto-selecting or replacing active roots.
UI must separately supply source-backed FRONT/whole-background/transition
contracts if those tasks are later admitted. Missing high-grade original
variants must remain unavailable; never choose a lower-grade fallback.

The combined original image candidate still needs separately authorized
transfer/selection; another executor must not assume these local bytes exist.
Its loader candidate and exact supplement pin are prerequisites; base manifests
and active settings must remain unchanged. Restore code and resource stages
separately. No safe next implementation, resource update or test is implicitly
authorized by this handover. No original media/archive/save was added to Git,
no raw user data is in the held patch, and no private resource link is exposed.
