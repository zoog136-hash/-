# Integration owner handover — 2026-11-06

## 1. Current goal and STOP state

The project goal is source-backed integration of original game data with actual skill, combat, crafting, acquisition, shop, warehouse and collection consumers while preserving physical ownership and existing save policies. This document records completed local work and precise continuation dependencies. It does not authorize another implementation step.

Current user state: save/commit and hand over, then PAUSE UI, Map, Integration, Image and Data. Only the Sprite owner may continue its separately scoped work. Do not resume Integration automatically after reading this file. GPU/general Godot/Android/phone investigation remains paused.

Keep originals, existing user files, candidates, explicit model/environment pins, saves, settings and phone installation unchanged. No public push, PR creation/edit, merge, upload/share, workflow, tests, compiler, GDScript parser, game or renderer was run for the preservation/documentation task. Do not delete files to reclaim disk space.

Exclusions remain: Sprite28 auxiliary/class members; Rosemary12 parts; 98 unproved Sprite identities plus one dummy; NEW quest investigation/implementation, sound, potion, spell-stage and emoticon work. Existing quest functions/saves are retained. Ground-loot visual replacement/rules remain unchanged. New image work is limited to item, polymorph, relic and doll families; this is not deletion of other original files.

## 2. Repository and checkpoint identity

Last confirmed main reference used in the investigation: e1513f7da10d6282f1ea7b8bdabe9606843b52fa, confirmed on 2026-11-06. This is a dated comparison baseline, not a claim about the current remote HEAD. PR292/293 actor/GPU/import changes must not be overwritten with older World/Monster/preview files. Do not fetch full asset history merely to reopen this checkpoint.

Public PR281 reference: 462e76fdd1faa9b326530c36edcb3725de65a95e. Its approved twelve-file tree equals local f71ec28aa5fb48157429131d8097bf6fbda987ae, tree c4ca3bd03e77fb6145b48207d614178590a9a64c. That publication is already complete; no further publication is authorized. Historical cleanup run42195066302 succeeded; this task did not run it again.

Existing local commits retained, not rewritten:

- f71ec28aa5fb48157429131d8097bf6fbda987ae: fixed twelve-file item/crafting/ground/shop candidate, now public through462e.
- fe90888ae11c71ab6b5b2ee63a777f750ddce422: separate player range receiver.
- 83efbca87a643a8f5d328115c8c62a81d0d1aca9: separate direct NoSpell/area follow-up. Do not assume all listed commits form one linear branch.
- f2df01f2566f0d25dc61d17ce7d3197a604d0c6d: four equipment percentage reduction-ignore inputs, parent f71.
- 87f67573a584526d7ddc9957d0090fdead0801a7: original equipment model refresh owner boundary, parent f2df.
- d6386ff761b9473f35d90656f73acca2868fc48c: preservation checkpoint, parent87f67573, branch feature/integration-checkpoint-20261106. It adds21 project records:18 exact code patches plus README/manifest/research. Later candidates are preserved as PATCHES, not adopted wholesale into active gameplay files.

This handover is added in a subsequent normal local commit on the same checkpoint branch. Obtain its exact SHA from the final delivery or `git log -1`; no invented public URL exists for these local commits. Existing commits, original branches and public refs are unchanged.

## 3. Local locations and Git access

Project worktree: /tmp/integration-checkpoint. Project-relative records: docs/checkpoints/integration-20261106/{README.md,manifest.json,research.json,HANDOVER.md,patches/}. The manifest is the exact18-patch allowlist with byte counts and SHA256 for every patch. Its SHA256 is5aa19621435ce2564913c5c36b151d2a35ac83fcaf27251bdb4f0d3807a43013. research.json SHA256 is4edc301320335bad895012288db817505d9d883102a55f49488f14998f8f42a3.

The existing repository uses bare metadata at /tmp/q262-finalize/git, objects at /tmp/q262git/objects, and an alternate object store at /workspace/-/.git/objects. To inspect the existing local worktree without fetching missing assets:

```bash
export GIT_OBJECT_DIRECTORY=/tmp/q262git/objects
export GIT_ALTERNATE_OBJECT_DIRECTORIES=/workspace/-/.git/objects
export GIT_NO_LAZY_FETCH=1
git -C /tmp/integration-checkpoint status --short --branch
git -C /tmp/integration-checkpoint log -3 --oneline
```

Most inherited paths are deliberately unmaterialized/skip-worktree. A clean checkpoint status does NOT establish a full runnable checkout or validate missing original assets. The unrelated /workspace/- work checkout remains at cba19558d and was clean and unchanged when checked; do not mistake it for current main or the Integration working tree.

Private code/research retention: /tmp/integration-private-checkpoint,196 selected files/28,292,938B plus its manifest. The manifest is39,215B, SHA256 e24037488c72028f35478adc560bc3bbf92f6c3b6a1649d2ff28c09795a2cff8. It retains complete candidate/base source views, detailed source-member ledgers, official guide research and collection fingerprints. Source-rich evidence stays outside Git.

IMPORTANT: /workspace was full (ENOSPC) when a new worktree was attempted. No user/original file was deleted. All new preservation artifacts remain in /tmp in this environment; this is NOT durable external delivery. A future authorized durable save must report its actual confirmed destination/identity. There is currently no persistent Library/Space link for these artifacts.

## 4. Completed code boundaries, in separate preserved groups

### Combat, items and original model refresh

The published fixed12 scope supplies flat FinalBlow policy, native physical crafting/ground lineage and multi/quest-material special-shop payment boundaries. Its71334B patch SHA256 is f2ee588229ad9ba2e11ef143b7013084f8d505a66b8d2e1074bfa94e30e2deb0. Whole private Item4141 source rows were excluded. Its ItemClass.Cost is not a proven shop payment price, and empty scoped payment queries establish no activated route.

The local equipment-ignore group consumes BonusType4952/5681/5691/5701, respectively general/melee/ranged/magic percentage reduction-ignore. Exact Unit3 Percentage divides by10000 once in the base reader/compiler. `guardian_combat.outgoing` adds `EQUIPMENT_IGNORE.sum_equipped(world,kind)` once after flat reduction restoration and before the existing percentage-budget calculation. Do not add it to World/collection amplification or rescale it again. Physical UID/source/archive/full-row/condition/mapped-ID/overlay/blessing/0..20 level/model/prepared-value guards remain mandatory. +0 whole-value ambiguity and unsupported conditions stay held. Compatible five-file patch23812B SHA3495a0480df2167782620bb240f46d6406da1d3f3740b228138f388d369a9e11.

The World model-refresh+57 hunk is6292B SHA cdd317ec953d188958ed0510e2ffe7fb03674fb226f4c732a60784d0e2ea430d; World027c4bc00e901d8dce554e2201aee0626e83856f -> fc11bc34fc0784b0645c20a76e957969bc8ebd8d. Actual call: catalog install/register/index -> prepare a fresh original equipment owner -> source/catalog/binding/selection recheck -> existing apply owner. Explicit environment/index model selections are NEVER auto-replaced or deleted. Existing-instance load_original early return is not a refresh. No model compiler was run; actual selected nonfixture binding/rules/model artifacts and adoption remain unobserved.

### Range and direct skill region/area

The six-file cumulative range/NoSpell/area packet is38604B; exact hashes/bases are in patches/range-region-area.patch and the private q262-finalize/pr281-range-region-area-cumulative/candidate.json. Direct SkillService readiness/cast invokes the actual map-owned `world.current523_source_spell_cast_reason(record)->String`; nonempty rejects before its own cost/effect writes. Main-only coverage was not claimed as all direct requests. Requires Map PR285 callback and admitted exact current523 identity; legacy/local IDs are not guessed. The gate does not grant Land admission or invent NPC/passive/proc/child restrictions.

`world.original_skills.current_source_weapon_context()->Dictionary` is an actual read-only equipped-identity helper, not permission or a source range formula. Helper03a9e321420e64963c1365e5f02f2a0f3e1ddc51; caller fa0c3f58522a71eb6bb0195355595b32740be2fc ->9cd4ca4b9b40c0fe27cd56b503adeb14abf8232c. Re-read current physical/source context at delayed execution. Positive MinCastRange and unknown weapon-relative combination remain held. FoeSlayer source122992 has IsAttackRange=true; add/replace/cap relative to WeaponType range is NOT established.

The separately reviewed repeat/static/aura child-distance candidate preserves selected child identity and the actual existing target/LoS/queue/cost path. Final progression blob26cb0020f76d0120b6120b541c7384c599d4c202, policy40f60056adcac2a01152cbf0b68e2bdf5b565a28. Source raw distances10/3/10 are confirmed; host multipliers32/48 remain labelled adjustable TWILIGHT estimates, not recovered original units/server formula. This is preserved code, not executed gameplay or permission for new spell-stage work.

### NPC lifetime, environment registration and travel

NPC self-buff lifetime/source guard, registered environment enumeration and actor retirement are narrow overlays. Enumeration uses actual `catalog.environment_attributes()` for explicitly registered original roots, not a fallback scan of all source rows. It preserves custom behavior and map/actor/field/territory/opt-in/suppression/generation guards. It does not turn custom radius behavior into native Land admission.

The travel receiver replaces broad combat clearing at a committed transition. APIs owned by World are `prepare_current523_transition_actions`, `begin_current523_transition_attempt`, `cancel_current523_transition_actions`, and `discard_current523_transition_actions`. Exact helper base0ab2fca4b488767abbe8b7e9dbde9d74c02e56b4 ->7f8a2e262482265b3fba1fc56bdd13719c187f98 after discard extension. Travel patch7477B SHA48bb3886089c7872cb97b3e843d839910ef7d180d8ef356756ae5579498570b1; discard8852B SHA752c0393dae661172c82c59da17d3f3ee67d3b46ccb02b6ed889c6662092c16c.

Keep the World combat epoch unchanged so NPC player buffs, skill statuses/shields, cooldowns and prepared boss actors keep their legitimate lifetime. Cancel only departed transient attacks/casts/projectiles/chase/target actions through actual owners. Capture exact weak old-owner/actor-life identities before replacement. After actual save evidence and catalog finish, require explicit cleanup success/context/epoch match BEFORE enabling new actors. Failed/uncertain cleanup retains receipts and disables automatic retries/refunds.

Discard is allowed ONLY for the proved registered-route rejection before OPTIONS.write/session switch/owner adoption/save, AFTER successful catalog restoration with unchanged old context/lives/epoch. Map owns monotone attempt history and the exact callback proof; begin must precede the first external mutation. Never insert discard in every rollback, erase started/uncertain/completed receipts or recycle tokens.

Map owner reported actual composition1dc969b9de75ecc7810e783ea7513ef873b13af7 over2b75ecf9189628f6816d9ff014d742e51b0efed9; combined Worldf9d2a1f654f8151fbb95f3e10691bf3e6beacf16. This is an owner-reported separate local integration, not a remote/main change or a file available automatically in this executor. Its World is not a replacement for later warehouse World changes. Request its exact narrow delta if a future authorized central composition needs it.

### Warehouse atomic transaction and recovery

Actual World APIs are `quote_warehouse_batch(direction,entries)` and `confirm_warehouse_batch(quote_id,request_id)`. Inputs are explicit reviewed exact item/source/physical identities, record and integer quantity1..99, with one direction. No all-of-inventory policy is inferred from original button labels. Entire-list custody/revision/source/lock/capacity/weight checks are revalidated and staged; confirmation uses ONE joint save, then adopts only confirmed state. Never loop live single-transfer saves and call it atomic.

Patch order: warehouse-batch20717B SHAb46ca93cb915804d4ef79bb2ec52f8e2ebd8de95b303fe9487eba5decb4c4bce -> warehouse-owner-load2669B SHAe2465ef7802b8fa4dae4976d8d6727d3ff0f2697c07eaac15c2e882c5b029a14 -> warehouse-native-partitions24473B SHAc9b4ee576405073b3be2d3c680acee323c6316678019ba52ca838941c409d8ef -> warehouse-ui-load5294B SHAee9a88624b78e251133f7d7edd1f1f4755ea24bb1eba6c918d5d755218ea6f54.

Native staged partitions support existing source-native receipt schema1/2 only. Conservation: parent granted = used + transferred + remaining; split quantity increments parent transferred/decrements remaining and creates one fresh child UID/schema2 receipt with exact immutable parent/event lineage. Do not copy the same unmodified consumable grant into two balances. Frozen partition IDs and the complete candidate are revalidated before save. Awakening partial stacks remain HELD: no admitted child partition ledger/UID contract exists for their stamp. Full supported moves retain existing rules. Uncertain save/adoption preserves request receipts and rejects automatic retry; saved:null is not reinterpreted by later load.

Final UI-load World base6e00b43624b14e789190d15f1f1dadf1a0e79bb8 ->2f6e8def1d35ac99254c1840975de5cf237846db; batch baseee886df5c1d64a3c52ac6e30b1f023257dfd09da ->444f284095a8ff8e09d3e22b9b1e4fe6662e72b4. Only World._load_game's actual final accepted_load(self) success invokes the UI bridge. New `owner_load_receipt_matches(world,receipt)->bool` compares actual World/batch IDs, load generation, combat epoch, full current custody state and preserved prior request receipts. Delivery result is separate from actual live-cart success.

UI owner reported reviewed cart9954971c752406f5215fabd337a77580b90759f4 and closed-cart bridge484053d65c35fba510bc92c23274bcbd87da0703. Cart211dbf8d151317069020228045c27423767f1f33 ->2797a81e40861d253efc3981890713800770fb76. `WarehouseReviewedCart.accept_successful_owner_load(world,receipt)` reconciles World-held closed snapshots and reports live_cart_result separately; it does not replay, refund or silently discard. Hidden/freed views are not reported restored. The UI owner's full patch is not locally incorporated by this checkpoint.

REMAINING UI contract: add the actual batch.owner_load_receipt_matches guard at BOTH static and live recovery entrypoints before metadata/phase mutation. Also reconcile quote capability: UI currently requires native_partial_partition_supported=false, whereas the finished native partition candidate returns true with exact scope; it therefore rejects that quote until the UI owner explicitly accepts its proven scope. Do not silently remove the check. Original43992/42648 controls use only deliberately staged rows, not entire holdings.

### Prospective collection source evidence

Collection consumer patch11141B SHAa88b7129e69854af0e82fbc40aba26d80465561fd0d80ac514cbee9bf90a98aa requires Data's read-only `current523_owned_item_witness.inspect(book,selected,physical_id,physical)->Dictionary`, final producer blobfb65f1cc69e2757ce1d382b9827740a866f5cfb0, SHA107685be8c80f29da56594e229332eea81c660453b18b34825b474c9e34a24eb. The item witness grants neither custody nor native collection identity. Require ok AND ready_for_owner_recheck AND empty pending, then actual live owner/lock/revision/membership checks.

New-native guard7472B SHA70143d779a8ecb0026deee1dd040fb10f09a3cc950d95f84ea3dc2e8b3393c11 blocks pending native evidence at eligibility and the fresh pre-consumption/save snapshot. Legacy saved absent/pending receipts remain readable; do not globally tighten their validator or reset completion/bonuses. Full current witness is recaptured and compared before joint save; verified receipt evidence is immutable.

Owned-blessing correction2461B SHA538ec83a749f13ce5a66d96d561f87c1c6791535e19ae46c37f83de15cbe696b: provenance9c085e1d8c502994c7a1e2186c438dcf572cbaeb ->f4f9106d40a4354b03bfacb13f3f79e990102a0c. Catalog source_bless_raw is a template default; compare physical source_bless_code with its own pinned source_bless_raw and successful producer/book proof, not catalog default1. No missing blessing is inferred. This correction is local and awaits actual consumer-owner combination.

## 5. Research authority and unresolved source inputs

Original source pin: current523-source.zip,25,031,173 compressed bytes, SHA256 d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832. Original archive/media are NOT included in the checkpoint backup. Actual source row/table identity and declared exclusions outrank display names or numerical coincidences. Native registration still requires actual source selection/model availability, not just code or a manifest row.

Existing equipment collections model came from c2785575c75183b08e6967f37d8e3ade255a0acd; path data/collections/equipment_collections.json,1,033,150B, SHAff46658683134ea7314637ef3c5b2eeec6c36a2ce8029b01a0a76cbe168b1a55. It preserves447 eqc digest keys/slot keys and NC_GUIDE_4474 aliases, not native ItemBook row identities. Official guide research established guide aliases; it did not establish a same-version native identity join. Retained fingerprint comparison has94 single display-only candidates,46 multiple candidates and307 without supported display match. Native saved bindings PROVEN=0; do not automatically bind the94 or migrate saved progress. Requirement/slot/ItemClass/engraving/blessing/enchant/quantity/effect multisets and same-version identity must uniquely agree.

The ItemBook source relationship examined was Collection -> CardForCollection -> CardForItem -> ItemBookItem, with CollectionSlot and SlotBonus relationships; a bonus SlotNo is not automatically a material slot. Related Library artifact TWILIGHT_Equipment_Collections_System_20261020.zip had metadata but transfer failed before materialization with tools/list HTTP401. Its unreceived contents were not inspected; do not claim it contains or lacks a creator manifest. Do not retry or use another route without new supported authorization/evidence. Detailed public/official query results and source fingerprints are in the private retention index. They are research evidence, not native admission.

Official guide URLs retained in code/research include https://lineagem.plaync.com/guidebook/view?title=%EA%B8%B0%EC%82%AC+%EB%A7%88%EB%B2%95 and https://lineagem.plaync.com/guidebook/view?title=%EB%A7%88%EB%B2%95%EC%82%AC+%EB%A7%88%EB%B2%95 . Their named distances do not establish patch523 internal IDs or universal raw-unit scale. Actual code is the authority for existing host queue/selection semantics.

Data reported a separate held Spell95542 chain: SpellBonus608132 -> Bonus1760852 -> SpellAttackType3401/Unit10431/Value1 -> AttackType1 Melee, while current balance channel is magic. Its proposed4014B candidate was NOT applied: current attack_type also controls cast restriction/queue dispatch. A future authorized task needs exact full Data patch/row proof and a separately typed damage-channel receiver that preserves cast selection/timing/cost/queue/NoSpell/target/LoS/life guards. Do not simply change attack_type. This is not authorized to implement during the pause.

QuestGoal activation/namespace/aggregation gaps are historical notes only; NEW quest work was withdrawn. Do not restart them or invent immediate-completion/save policy. Existing quest behavior is preserved.

## 6. Dated coverage, not a new completion percentage

Last source-consumer measurement was2026-11-06 against main e151 and public PR281462e, reusing confirmed d758 source-consumer blobs where unchanged. Shared source denominator:1065 JSON members/457,729,872 uncompressed bytes. Sector3 conditional/partial callable-consumer footprint:61 unique members/254,035,215 source-file bytes. These are complete member FILE SIZES touched by partial row consumers, NOT measured bytes used or whole-file completion. Another23 members/22,398,136B were possible/unresolved references;981/181,296,521B were not yet traced in this sector. Do not label untraced files proven unconnected.

Data132/Integration61 union was146 members/295,662,234 source-file bytes, intersection47, keyed by exact archive SHA/member. Never add132+61. No fresh measurement, runtime usage observation or100% connection claim was made during preservation. Excluded-row per-file exclusive byte splits and actual consumed byte counts remain unknown. GPU .import metadata is not another original source JSON connection.

## 7. Backup inventory and restore limits

Existing fixed archive (NOT replaced by this document): /tmp/integration-backup-ready-20261106/TWILIGHT_Integration_d6386ff7_PrivateCheckpoint_20261106.zip,5,280,271B, SHA2563d7a44739d7105fd0372242913bc221a1c5ef23040a2e3880aa582247f115d5f. Associated commit d6386ff761b9473f35d90656f73acca2868fc48c. It has222 members/28,676,895 uncompressed bytes:21 committed project records,196 private code/research files, their existing private manifest, exact commit object/metadata, backup README and embedded content manifest.

Private196 types:123 .gd,22 .patch,41 .json,4 .py,2 .jsonl,1 .txt,3 .md. Categories are owned game-project code/base/candidate snapshots, source-relation fingerprints, source-member/provenance ledgers, official/public research receipts and patch identities. Ordinary Git author name/email occurs in commit metadata. No actual personal/player data, secrets, SP2/SPX/images, DAT/ZIP source packs, saves or raw chat/system instruction dumps were selected. Reviewed allowlist/credential and chat/home-path marker scans found no held category; this is a scope review, not a public redistribution decision. These materials remain PRIVATE.

External content manifest: /tmp/integration-backup-ready-20261106/content-manifest.json,63,526B, SHA256e1d99fccb5185b91b1339908c67e73bf080d470daf194e5aefa140dc85ca2b27. Its entries inventory221 payload files; the222nd ZIP member is the manifest itself. backup-receipt.json in the same directory records association and limits. No .bundle was created: inherited base history is large/partial; no --all bundle or history fetch was attempted.

Restore: inspect archive names first; extract into a NEW private empty directory, never over originals/current work. Compare each selected file's bytes/SHA to CONTENT_MANIFEST.json. This reconstructs all selected records and retained source snapshots exactly. It does NOT reconstruct all inherited Git objects, original assets/source archives, runtime model, saves or a runnable game. To recover the entire d638 Git tree, obtain the already-authorized original parent87f67573 and its existing object dependencies through a supported owner path, then use the retained exact commit metadata. Do not fabricate missing blobs or fetch full assets just to satisfy Git.

This HANDOVER.md is a NEW post-d638 record and is NOT in the old fixed ZIP. Keep its subsequent commit/hash separately. No upload session or Library write was started, no destination/share approval is implied, and no persistent delivery reference exists. The original ZIP/hash must remain fixed if a separately authorized later backup includes this document.

## 8. Continuation checklist — ONLY after a new user resume instruction

1. First resolve at-risk /tmp retention through an explicitly authorized private destination/payload; record confirmed persistent identities and exact hashes. Do not treat local links as delivery. Preserve the fixed archive and this later handover separately.
2. Re-establish exact current main/owner code bases only as needed. Reuse existing research and compare narrow hunks; never overwrite modern actor/GPU/Map code with old World/Monster snapshots. Keep active pins, originals and user work intact.
3. Obtain the actual Map/UI/Data owner deltas listed above. Compose travel cancellation + Map monotone begin/discard + World model57 narrowly. UI recovery needs the new authoritative receipt guard at both entrypoints; partial-native quote capability needs explicit scoped acceptance. No broad rollback cleanup or automatic retry.
4. Compose collection Data producer -> prospective consumer -> new-native fail-closed guard -> owned-blessing correction, with exact source/physical/model/revision/save checks. Legacy receipts and eqc keys stay unchanged. No native collection mapping is established by this order.
5. For equipment inputs, prepare/adopt only through existing explicit selection/model owners after source/catalog/binding pins are available. Missing artifacts remain a hold; code registration alone is not activation. FoeSlayer formula and separately typed damage channel remain distinct source/host-policy dependencies.
6. Plan any execution validation/publication separately with the user; none is authorized by this handover. Record static code composition versus actual build/game/save verification and source/member coverage separately.

END STATE: documentation and local preservation only. Integration/UI/Map/Image/Data PAUSED; no automatic restart.
