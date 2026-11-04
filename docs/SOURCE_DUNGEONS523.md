# Latest523 dungeon declarations in the actual game menu

Base: `main` `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`.
Branch: `feature/source-dungeon523-ui-20261104`. No other PR is merged.

The existing Main/HUD now has **메뉴 → 던전**. Its six selections show normal/hard
Trial Tower, normal/hard Orim, special dungeons and time recharge items. A player
can select an entry, compare normal versus immediate-completion rewards, inspect
Orim's authored spawn schedule, check entry readiness, and import verified data
through the screen. Back navigation returns to the existing menu.

**The execution layer now implements Tower attempt payments, goal progress,
explicit exit failure, extra-attempt purchase, normal/immediate settlements,
receipt deduplication and save/load protection.** Its actual Main UI exposes
start, instant completion, purchase, claim, forfeit and progress-save retry.

**Production Tower entry/field combat remains blocked:** no current Main map
implements a verified latest523 dungeon-instance/clock/eligibility host. The
financial tests use an explicitly labelled completed-run fixture; they are not
original dungeon battle or map evidence. Orim stays closed and its unknown RNG
and Care rules are not implemented. Special-dungeon arrival/time-pool handlers
remain missing. Opening the inspection screen still spends/grants nothing and
preserves the save. Quests, pets, clans and sieges are not reintroduced.

## Source availability and preservation

The consumer environment formally materialized all four Library files using the
Library transfer helper, applied their identity metadata, read their actual bytes,
and checked whole-ZIP CRC and SHA256. No authentication refusal was bypassed.

| Library ID | Bytes | ZIP SHA256 |
| --- | ---: | --- |
| `libfile_f3e9e5b322cc8191ae441565bbd24c27` | 25031173 | `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832` |
| `libfile_31c5e1c8f9d48191b31e88937b9f9d99` | 397305 | `a5ff03f53e05b3fe23da88ccb033efbf080a3cf2c98535efeb43bef0e57eddd0` |
| `libfile_ca076d427f408191afadb516f2922621` | 122200 | `f7fc959ed78946af473f5ebdca6be45423d4e42e7274fae73729f27b51c5ea3d` |
| `libfile_17546907c6b48191baa524438b2ce38d` | 427593 | `470a4c59f0829ce98fd80e0e9e60b41a6b2579d0d6e8e8581bda77432ae8e945` |

The three depth reports were read to establish interpretation limits. Runtime
data is generated from the exact cumulative523 source, not report prose or508.
The original ZIPs are not modified. The 57 consumed tables are checked against
their original index byte lengths, CRC, row counts and SHA256.

## Private pack and reproducible build

Public Git contains code, tests and this description. The generated JSON and
original source archives remain outside Git. No new artwork is created.

```sh
python3 tools/build_dungeon523_pack.py SOURCE523.zip /absolute/private/new-pack
python3 tools/verify_dungeon523_projection.py SOURCE523.zip /absolute/private/new-pack
```

The builder refuses a different source ZIP, a destination within its repository,
or an existing destination. It atomically publishes a new directory containing
`manifest.json` and `dungeons.json`. The runtime pins the source SHA, exact payload
SHA, length, revision and fixed filename; rewriting both a payload and its
manifest does not make altered data acceptable.

Verified payload: `6050456` bytes,
`4edf50302106978f1779d885866889d646b992e329ccd53bf3dbb284dfc43f73`.
Private ZIP: `252966` bytes,
`5a95d6bbd5a8c92b62b508cd6695f8b7deea7fc52bbc576442c61a52069c5ac1`.
Durable Library copy: `libfile_927016feb2848191a7e36dda8ee8f02d`
(`TWILIGHT_523_dungeon_runtime_private_pack_20261104.zip`, version0).
This is a data pack, not the original-art release pack described by the resource
delivery ledger. It does not upgrade any original-art delivery status.

Extract that ZIP privately and choose its `manifest.json` through **자료 불러오기**.
Successful installation copies verified bytes into a content-addressed
`user://dungeon523/<payload-sha>/` directory. Failed replacements retain the
previous catalogue. Ordinary game save files are not used for installation.
An installed revision loads at next Main startup. An external read-only pack can
also be selected with `TWILIGHT_DUNGEON523_PACK=/path/to/manifest.json` or
`-- --dungeon523-pack=/path/to/manifest.json`.

## Connected declarations and boundaries

| Definition | Connected scope | Execution still missing |
| --- | --- | --- |
| Trial Tower | 200 Stage IDs; 200 territory/Land paths and goals; 1200 normal/1380 immediate reward links; 200 exact purchase/payment/product round trips | Verified source map/clock/eligibility host, transport and original NPC combat; ledger/payment/payout implementation is described below |
| Orim | 20 Stage IDs on10 shared Lands; 2110 exact spawn rows; 60 time sections; 80 base/60 Care/140 weighted lucky reward links | Relative/random/group placement, original NPC combat host, clock semantics, boundary inclusion, Care trigger and lucky RNG/count selection |
| Special dungeons | 22 definitions; exact teleport costs, currencies, prerequisites, destination territories, direct Land attributes and time-group links | Verified target map entry, all admission conditions, server/time-window combination and dedicated combat/reward handlers |
| Dungeon time | 176 independent groups; 317 direct Land links; 450 consumable recharge items into51 groups with an explicit3600-second effect | Cap/reset/carryover/offline policies and actual item consumption |

Stage ID and `IsHard` remain explicit. Land alone returns multiple candidates;
it never chooses Orim difficulty. Tower's static `IsOpen=false` rows are retained
and are not treated as permanently locked player stages. Orim's current control,
category and season closed flags remain visible. Server sets, shop windows and
season flags are not collapsed into a live-server availability claim.

Rewards retain the original type/class, amount, delivery-time raw type and bless
code. Normal, immediate, Care and lucky rows are never added together. Exp281 is
not joined as Item281. Immediate Tower payment is Currency764, not Gem4. Trial
entry currency174, additional-attempt purchase Gem4 and immediate payment remain
separate. Source constants and preparation buffs are retained as declarations;
unverified combat formulas and hard-mode ValidLand mismatches are not corrected.

Orim section boundaries return all candidates and `grantable=false`; no interval
precedence, RNG distribution or420/480 clock adjustment is invented. The UI
shows weights without asserting probabilities. Its1080 group-reference spawn
rows keep their group IDs and raw counts; the UI does not multiply group size or
claim that a group count is a resolved monster total. Item deletion conditions preserve
TargetDateTime versus raw Time encoding; Value0 is not interpreted as permanent.
Display of source dates does not claim a time zone or live event status.

Direct Land time-group relationships take priority in lookup. In particular,
Land47543 keeps31393 rather than representative30582, while lobby46952 receives
no inferred72 pool. Base time and recharge cap remain independent raw fields.
Link test item185124 is not mapped to an invented ordinary recharge group.

## Validation and remaining delivery work

Private test logs, exact code/input hashes and actual Main viewport captures
are retained in Library `libfile_76c3a981061081919d9c912846d96d6d`
(`TWILIGHT_523_dungeon_UI_local_evidence_20261104.zip`, version1,
12966511 bytes, SHA256
`79fc3fc95729b7edf3087179c8d94b05511ac91ede1ccbef3e14a1cc41274b99`).
Version1 preserves the initial evidence and adds execution logs, twelve exact
code hashes, six refreshed inspection captures and two explicitly fixture-labelled
payout captures. It contains neither source archives nor a dungeon execution build.

- Independent actual-source comparison: **11146 checks passed**.
- Godot4.7.2 real-pack runtime: **97 checks passed**, including mode identity,
  ambiguous boundaries, direct time groups, expiry, invalid replacement retention,
  persistent installation and restart.
- Committed resource audit: **723 atlases / 41442 frames / 233420026 bytes**,
  all expected hashes;1446 source/atlas files materialized from matching current
  Git blobs. No replacement images were synthesized.
- Historical `--source-dir` art audit fails because `a1.zip` is unavailable in
  this environment. This is separate from the four523 ZIPs above. No original-art
  transformation or full art delivery is claimed.
- Actual Main inspection OpenGL UI: **30 checks /0 failures**, six1280×720 viewport captures,
  including menu mouse input, mode selection, distinct rewards, readiness
  results, file-picker/import callback, invalid replacement, back navigation and
  unchanged save bytes/currency/inventory/map/position. No hardware touch or
  dungeon combat acceptance is claimed. Payout testing is described separately below.
- Actual Main without the optional pack: **11 checks passed**. The menu opens an
  empty, guarded screen and preserves save bytes, inventory, currency and map.
- Actual current-map/save core: **32 checks passed**; existing identical-save and
  deferred-save checks also passed. Python core stager checks: **7 passed**.
- The first UI run exposed one omitted current Git portrait in the disposable
  stage. Its exact blob `8ba48c3adeb3c88ef31dd929ffeea91aac2dc69e` was materialized,
  SHA256 `bd3e2b71fd8b98f228a0b9424377210ff6f8abf31b30c4f28cf7bc5feae275d8`,
  imported and the focused UI test rerun with runtime/resource error filtering.
  The final log has no parser, execution or missing-resource errors. This did
  not change source artwork or weaken a test.
- Full historical UI/gameplay suites and Windows/Android device testing are not
  run. User instruction forbids unnecessary remote CI: no manual CI run/retry;
  the task commit uses `[skip ci]`. Unrun remote CI is not reported as passing.

Resume production entry only after the actual latest523 instance host and
remaining execution evidence are connected. Runtime metadata/JSON flags alone
must never authorize spending or rewards.


## Execution and settlement continuation

`dungeon_run_service.gd` owns a versioned `source_dungeon523` save ledger. It binds
Stage ID, normal/hard mode, monotonic run ID and a reviewed clock-contract/cycle.
A successful normal entry consumes one Ain10 payment, not both cost constants.
A separate source-declared Gem4×50 purchase adds one attempt per mode-cycle.
Normal/hard counts remain separate; static Stage.IsOpen is not used as player
progression. Earlier-cycle clears qualify immediate completion only with the
same clock contract and a verified host's exact eligible reward-ID list.

Only a current field's compiled `dungeon523_context(stage_id)` method can supply
the host. Existing source84/PC fields expose no such method. No debug switch,
user-supplied manifest boolean, shared AssetPath or Land number can activate it.
The host must verify the M523 source identity, Stage/Land/mode, current instance,
landing/collision, admission/season restrictions, daily cycle, combat/timer state,
and exact normal/immediate reward eligibility. Current production host count is
**zero**, including coincidentally equal numeric map IDs. Tower has200 distinct
Lands sharing12 AssetPaths (`13246/` through `13257/`); Orim has10 distinct Lands
sharing10 paths (`13459/` through `13468/`). Geometry reuse must not merge stages.

The run service accepts only events from the active run. Main's kill callback
requires a dead actor in the current monster root, with the matching run ID and
a host-assigned stable actor identity plus pooled life ID. Goal pickups require
an actual consumed floor drop with matching run/current523 item identity. Item
135434 is the collection goal, not the327824 reward token. Duplicate event tokens
are ignored; pending save failures are retried with their original run ID and
cannot leak into a later run. Explicit map exit/forfeit stores failure without
refunding the entry payment. Disconnect/restart exceptions are not guessed.

Completion requires both the table goals and host-confirmed combat/time and
reward eligibility. A persisted cleared run enables **보상 받기**. Normal and
immediate reward plans use the exact separate source rows. Raw delivery types
1/2 stay in receipts; this code does not assign them invented server meanings.
Unknown delivery eligibility is a host blocker. Orim RNG, Care combination and
its missing admission currency enum are not synthesized.

`dungeon_economy.gd` binds source Adena26 to existing gold and the explicitly
mapped coin/token IDs to existing currency inventory. It registers the two Tower
token definitions without gifting any. Currency764 consumes only physical
Item549 records with a current523 namespaced identity; anonymous diamonds and
Item113892 remain untouched. EXP281 uses the existing TWILIGHT progression
service after durable credit; a reload normalizes any already credited pending
level-ups without awarding the settlement again. This is existing local balance,
not a newly claimed original EXP formula.

Payment, inventory/physical IDs, gold/EXP and the updated ledger are submitted to
the existing Main atomic writer together. Live economics publish only after
success. A failed write preserves the prior live state and receipt. If a save
candidate reached disk but migration activation failed, further transactions
block until reload reconciles it; the code does not falsely report rollback or
blindly repeat a monetary delta. Malformed schema, unknown stages, incomplete
clears, invalid budgets or altered reward rows reject before character mutation.
Old saves gain an empty ledger; original map/equipment/card/boss/save guards stay.

Focused continuation checks:

- Source-backed host/clock contract tests:76 passed. **The host/clock are fixtures**,
  including source goal42/Item135434, payment rollback, duplicate lives/claims,
  next-cycle eligibility, exact Item549 consumption, distinct rewards/EXP, extra
  purchase limit and failure without refund.
- Actual Main/UI/atomic-save checks:28 passed with two fixture-labelled captures.
  These exercise real inventory/gold payout, persistence, failed-save retry,
  replay after reload, uncertain candidate reconciliation, stale event discard
  and corrupt-ledger preservation. **The cleared-run evidence is synthetic**;
  actual original-map entry or dungeon combat is not counted as tested.
- Actual inspection UI:30 checks and six refreshed OpenGL captures passed.
- Current-map/save core:32 passed after the new save integration; existing
  identical-save and deferred-save guards also passed without errors.

Remaining production blockers are concrete: the22 original M asset roots need a
real reviewed instance/arrival/collision/NPC host; the05:00 cycle time zone and
season/admission/timer semantics need evidence; reward timing eligibility must
come from that host; Orim's closed controls and missing server rules and the
special-dungeon time cap/reset/carryover handlers remain unresolved. This is a
continuation beyond UI-only code, not completion of all requested dungeons.
