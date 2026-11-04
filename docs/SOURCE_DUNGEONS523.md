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
original dungeon battle or map evidence. Original Orim's closed flags remain
unchanged. A further local continuation implements explicitly separate Orim
execution and special-dungeon time pools, described below; original target-map
arrival/collision is excluded by the user's instruction. Opening the inspection screen still spends/grants nothing and
preserves the save. Quests, pets, clans and sieges are not reintroduced.

Local continuation after the separately approved ten-file publication adds an
explicit opt-in **TWILIGHT 현재 지역 도전 · 자체 규칙**. It uses the actual current
field, resident monster combat/deaths and floor pickup; it never transports to
or pretends to restore an original M523 Land. The same PR includes this
continuation and the Orim/time adaptation described below.

## Source availability and preservation

The consumer environment formally received the latest523 source archive and
three analysis reports, read their actual bytes, and verified ZIP integrity and
content hashes. No authentication refusal was bypassed. Private source identities
and transfer receipts are retained separately from public Git.

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

The latest execution pack adds `orim_execution.json` alongside the unchanged
base manifest and payload. `tools/build_orim523_execution.py` verifies the source
archive, index byte counts, CRC, row counts and SHA before selecting its nine
output tables. It scopes NPC definitions, attacks and names to Orim; raw source
data is never committed. The runtime validates the pinned sidecar and backs up
the previous known revision before activation. Original archives, prior pack
backups and the current installable pack are preserved separately in private
storage. Detailed transfer receipts remain private.
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

Detailed logs, code/input hashes, viewport captures and storage receipts are
retained in the private handoff. Public verification aggregates follow; fixtures
and actual current-region execution are identified separately.

- Independent actual-source comparison: **11146 checks passed**.
- Godot4.7.2 real-pack runtime: **97 checks passed**, including mode identity,
  ambiguous boundaries, direct time groups, expiry, invalid replacement retention,
  persistent installation and restart.
- Committed resource audit: **723 atlases / 41442 frames / 233420026 bytes**,
  all expected hashes;1446 source/atlas files materialized from matching current
  Git blobs. No replacement images were synthesized.
- Historical `--source-dir` art audit fails because `a1.zip` is unavailable in
  this environment. This is separate from the latest523 inputs. No original-art
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
- Disposable-stage portrait omissions were restored from the exact current Git
  resources before rerunning the focused UI checks. Final logs have no parser,
  execution or missing-resource errors; source artwork and assertions were not
  changed.
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

For original-instance mode, only a current field's compiled
`dungeon523_context(stage_id)` method can supply the host. Existing source84/PC
fields expose no such method. No debug switch,
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

## Separate local adaptation after publication

The user subsequently allowed internally estimated game behavior after checking
source, reports and public material. The original523 payload and reports were
retained unchanged. Public searches found the official site's Tower-hard-mode
announcement (`https://lineagem.plaync.com/conts/250604_update`) but did not
resolve all current instance/eligibility handlers. The local adaptation does
not present those missing handlers as recovered originals.

The new menu toggle defaults off. Turning it on is an atomic save, with a failed
write reverting the control; the setting and a configurable1–10 time multiplier
survive reload. They cannot change during a paid run or unclaimed completion.
Own behavior is stated in the UI: freely select a floor, no live event-season
restriction, use current-region normal monsters (bosses only on BreakThrough),
and deliver eligible source completion rows directly to inventory. The normal
source goals, level70, entry/payment rows and separate reward amounts remain.
Bonus floors generate one clearly local objective floor drop per actual monster
death; collecting it uses the real delayed floor-pickup/ownership path. These
are neither original chest placement nor original dungeon NPC/spawn restoration.
The objective is a local non-sellable material, not a fabricated M523 reward ID.

The original table's raw TimeLimit is interpreted as seconds for this own mode,
multiplied by the visible own setting. Its absolute deadline counts time while
the game is closed, consistent with existing system-clock use. Timeout, actual
player respawn, explicit forfeit and leaving the current map fail without refund.
Failed expiry writes block further combat credit until retry commits failure.
Automatic damage in the integration test accelerates actual resident actor deaths;
it does not represent manual play or an original-dungeon combat comparison.

Daily identity reuses the existing game's pure `korean_daily_key` function from
the already present service:05:00 KST, fixed UTC offset. It adds no quest content
or quest grants and imports no separate local-time branch. A saved high-water
cycle prevents device-clock rollback from regaining used attempts. A live run
retains its admission cycle across the daily boundary. The contract namespace
`twilight-local-kst05-v1` keeps own clear eligibility separate from a future
verified original-instance clock, and own receipts carry `host_kind` provenance.
Each runtime session prefixes monster-life event identities, so a new process's
reused numeric object IDs cannot collide with earlier credited kills.

Actual Main/current-map adaptation checks: **34 passed**, including42 resident
actor deaths through their real damage/death signals, duplicate callback guards,
actual floor-object pickup, both atomic settlements, settings save/reload,
failed settings rollback, daily reuse rejection, mode separation, timeout write
failure/retry and actual respawn failure. The test accelerates lethal damage;
only timeout checking uses an explicitly shortened deadline. It never supplies
a synthetic completed run or replacement instance host. Two OpenGL captures show
the opt-in own-rule UI. The boss-only branch and original M523 geometry/combat
fidelity were not tested end to end. A missing staged portrait was restored from its exact current Git bytes before
the passing run; no original image was generated, replaced or added to the PR.

After this local continuation, all focused regressions were rerun successfully:
source-backed fixture-host76, actual Main synthetic-clear payout28, inspection
UI30, current-map/save core32, identical-save and deferred-save guards. The local
mode's actual-play evidence and the older fixture evidence remain distinct.

Original M523 map/landing/collision reconstruction remains excluded. The further
Orim/time adaptation is described next; it does not upgrade original-art delivery.

## Orim and time continuation, excluding map movement/collision

The later instruction explicitly excludes map movement/collision and asks to
finish the remaining work. `dungeon_play_service.gd` adds a separate versioned
`source_dungeon_play` ledger and **자체 실행 설정** in the existing dungeon panel.
No new game mode, environment or other PR is merged. Current-field play is clearly
labelled TWILIGHT adaptation; source closed-season flags and territory coordinates
are preserved and never relabelled as a restored M instance.

Orim admission enforces the source stage's level attributes and keeps normal/hard
IDs/budgets separate. Missing entry-currency semantics become visible own settings
(default Ain10, one attempt per mode/day), rather than interpreting unnamed enums.
The existing game's pure05:00 KST daily function is reused; no deferred local-time
branch or quest content is brought in. Saved daily high-water prevents rewinding
the device clock from regaining already used attempts.

All20 source Orim stage definitions drive the own scheduler. Authored seconds,
counts, NPC IDs, group references and type names remain inspectable. The new
verified sidecar supplies244 NPC type/definition/name records,243 basic attacks,
group memberships and reward-item effects. Confirmed HP/MP/AC/MR override the
borrowed visual template. Basic attacks roll the actual declared DiceCount,
DiceSpots and DiceBonus (43 rows use dice; all243 are non-spell, one per NPC).
TWILIGHT's hit/critical/mitigation and default combat timing remain its existing
engine behavior, not a claimed recovery of a complete M combat formula.

Only visual identity/profile is borrowed from an actual current-region monster;
its unrelated skills/poison/combat stats are not copied. Source names, own visual
labels and HP bars identify the actors. The source-typed final boss gets a
priority slot so the bounded normal-wave queue cannot starve completion. Default
normal live limit16, group size1 and HP/hard multipliers1 are configurable own
settings. Random placement consults current walkability/path APIs before creating
an actor, rejects nonfinite/unreachable results, and keeps the wave pending when
there is no valid space. It uses the existing current-field body contract without
changing geometry, terrain, portals or collision definitions.

The own clock treats Stage.TimeLimit420 as seconds, with configurable duration
and proportional wave timing. Source rows beyond420 remain raw declarations and
are not invented into a preparation60-second period. Closed-season restrictions
are bypassed only for the explicitly opted-in own mode, never in the source data.
Actual boss death freezes a deterministic seeded reward plan in the save. Shared
time endpoints choose the higher-minimum interval in this own rule; the selected
section's lucky count is uniform over its declared min/max, followed by source
weights (390 total) with configurable replacement. Care defaults to timeout-only;
always/off are choices. Base, Care and lucky rows are not blindly summed. The
actual frozen result is shown before **보상 받기**. Timeout, forfeit and player
respawn use their own explicit result paths; leaving the current map forfeits
without fabricating a teleport or receiving timeout Care.

The four preparation payments use their confirmed source currencies/costs.
Effects use configurable own percentages25/10; token-drop boost applies to the
own optional floor drop, not every completion reward. Reroll cost10/20 comes from
the source table, while currency (default Gem4) and the move/attack/basic-boss-hit
bonus are labelled own behavior. These are not claims that original Orim's
character/skill-selection system is reproduced. Existing TWILIGHT player skills
continue to operate. Own wave actors use the existing summoned-helper policy so
they do not farm ordinary monster EXP/equipment in addition to declared rewards.
Own token drops go through floor pickup. Healing-object effect is configurable
own20 percent.

Event-item identities are clearly prefixed `TWILIGHT ·`, separate from expired
original event items. Preserve-own-items is configurable; source-date enforcement
uses the existing game's KST interpretation when selected. Normal/blessed scrolls
share declared Item232352 but retain separate names, physical records and bless
codes. Their actual inventory/enhancement UI uses the existing TWILIGHT Orim
probabilities and failure semantics, with atomic physical-scroll consumption.
Holy-water inventory activation consumes one exact own physical ID; a repeated
stale ID cannot consume a different legitimate copy. The verified source
Experience30400000 effect is used; blessing conversion900 is an exposed own value.
Durable XP credit normalizes through existing level-up rules on immediate use or
reload and never grants the consumed item's effect twice.

Special definitions22 start logical time sessions on the current map, retaining
source min/max levels and actual declaration entry currencies/costs. Existing
ordinary field combat/rewards are preserved. The first declared destination's
direct time groups are used, not representative dungeon groups or guessed map
IDs. A missing direct group gets a labelled own per-session pool (default3600).
Base and recharged balances stay separate, deplete base first, and save every
five elapsed seconds/explicit stop. Offline time counts in this own policy.
Daily/WeeklyMon/WeeklyWed/Monthly use the existing05 KST convention; Specific's
daily fallback is configurable. Active sessions retain their admission period;
reset is applied at the next idle/session boundary. Bonus carry is configurable.
Group raw time units default to one second with an exposed own scale; raw0 cap
uses the explicit own86400-second setting, never infinity. Recharge adds the
confirmed3600 seconds and checks the separate recharge cap before consuming.

Recharge accepts only exact current523 physical provenance or a distinct own
recharger. Name-only lookalikes and locked instances are preserved. The own shop
(default100000 Adena, configurable) provides a real player acquisition path with
an own namespace; it never fabricates original current523 ownership. The same
panel displays balances, buys, consumes, stops and retries actual saves.

Every transaction stages inventory, physical IDs, gold/XP/blessing, equipment
result and its ledger through the existing atomic writer. An uncertain committed
candidate blocks until reload; a confirmed failed transaction can be retried or
cancelled. Retry merges its fixed delta into current inventory, preserving loot
earned after the failure and refusing changed/locked target IDs. Actor HP/MP,
issued IDs and credited deaths persist across actual save/reload. The package
installer refuses corrupted sidecars, preserves old catalogues, and backs up the
previous known sidecar before activating the latest one.

Focused checks:62 passed in actual Main/current field with actual own wave actor
damage/death, explicit accelerated clock and inventory/cap fixtures;6 passed in
a second actual Main process using only the persisted installation, without an
external pack argument. These are neither manual-play nor original-map tests.
The latest v2 ZIP was downloaded normally from the private Drive copy into a new
consumer folder, byte/SHA/CRC checked, installed through the actual UI, then
loaded at restart. Source archives, v0/v1 backup packs and latest v2 are stored
separately; Drive storage alone does not install anything into the game.
Fresh focused regressions also passed: original runtime97, fixture-host76,
current-map/save32, identical-save/deferred-save guards, actual current-region
Tower34 and inspection UI30. The runtime's existing97-check test prints a plain
summary rather than JSON; its exit0, zero errors and exact97/0 summary were checked
without changing the test. Historical full suites and device runs remain unrun.
