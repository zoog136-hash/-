# Original current523 SP2 connections

This change connects original source actions to a private action-bank registry and
Main's existing transformation, magic-doll and relic consumer. It keeps the
existing installed actor first, uses the current source tables to select an
actor, and reuses the existing SP2 decoder, source clock and layer renderer.
It does not create images, sprites, frames, directions or game locations.

The branch starts at `1333851bb2eb193a6ac1fc3e3b852787c08994ff`.
Original pixels, packs, source tables, saves and private configuration are kept
outside the public repository.

## Scope and accounting

| Original inventory | Files | Original member bytes |
| --- | ---: | ---: |
| Fixed SP2 inventory | 74,656 | 7,038,394,450 |
| Previously audited ten-pack lineage | 20,272 | 1,368,277,068 |
| Difference under this handoff | 54,384 | 5,670,117,382 |
| Priority: nonempty source-family categories | 45,990 | 4,824,334,813 |
| Follow-up before explicit exclusions | 8,394 | 845,782,569 |
| Approved exclusion: no declaration | 135 | 3,730,859 |
| Approved exclusion: no supplied caller | 549 | 70,448,356 |
| Remaining follow-up | 7,710 | 771,603,354 |

The 135 and 549 exclusions are disjoint and outside the priority 45,990. Their
original files and historical inventory are preserved. Source-family categories
overlap; adding category counts would double count files.

The parent's recorded eligible global lower bound, after sound and these 684
approved exclusions and before the later dummy instruction, is 119,409 files /
10,677,195,898 original bytes. Its recorded 95% thresholds
are 113,439 files and 10,143,336,104 bytes. Image44/47/48 and icon53 internal
inventories are still missing from that denominator. None of these scope
figures is an actual game-use rate. Original member bytes remain separate from
compressed ZIP bytes, expanded JSON, decoded images and caches.

Later source-declared dummy exclusions preserve the fixed original inventory
and bytes. Only explicit original declaration evidence can classify a dummy;
an unfamiliar name, missing input or failed lookup cannot. The connection
registry records these exclusions separately, including their source locations,
and never counts an exclusion as resource use. Raw files and previous outputs
remain intact.

Receipt, compilation, registry connection, selection, installation and observed
playback are recorded separately. A registered file or an inspected frame does
not establish whole-file use or actual Main gameplay consumption.

## Source reader and compiler

The reader now accepts the literal `105.clothe` spelling alongside
`105.clothes`, retaining the original spelling. Five declarations in
`list_24.spr` explicitly connect 24117→24118, 24119→24120, 24121→24122,
24123→24124 and 24125→24126. Existing plural/shadow serialization and declared
child counts remain intact.

`reference_sp2_inventory.py` writes a private ledger for all 45,990 exact paths,
including original archive/container/version, bytes/CRC/available SHA evidence,
source table and action links, alias/parent-child context, existing connections,
compiler requests and separate unobserved runtime stages. It retains the other
8,394 records separately. Metadata registration never implies installed pixels.

`build_reference_sp2_bank.py` reuses the existing identity compiler's source
resolver, actor construction and compact role format. It expands source-family
actions and records each exact actor/action separately. Alias overrides, literal
body/shadow/clothes declarations, source frame selectors, stored directions,
duration ticks and attributes are retained. Each raw action has `loop: null`;
the actual caller supplies its own explicit loop policy.

The optional host-timing path preserves a missing source FPS as null and lets
the existing playback policy select its labelled compatible rate. It never
writes that fallback into the source proof or overrides an explicit source FPS.
Unsupported or ambiguous source relationships remain concrete outcomes; they
are not replaced by invented parents, frames or artwork.

The receipt-based connection mode constructs the actual output from already
supplied originals and existing source proofs, without starting another input,
frame or quality audit:

```sh
python3 tools/lineagem_original/build_reference_sp2_bank.py \
  --connect-received --allow-host-timing \
  --metadata /private/source-metadata \
  --saved-plan /private/existing-source-plan \
  --source-receipt /private/existing-spr-receipt.json \
  --input-receipt /private/original-input-receipts.jsonl.gz \
  --input-receipt /private/additional-source-connections.jsonl \
  --spr-root /private/original-spr \
  --original-root /private/original-sp2 \
  --output /private/new-source-bank
```

Repeat `--input-receipt` for explicit dependency inputs. Optional
`--followup-receipt` and `--normal-visual-context` connect separately admitted
follow-up inputs and source calls. `--resume-bank` reuses already written raw
members. The writer retains supplied provenance and records serialized output
content addresses; those are not additional original-input verification.

Outputs containing originals must be private. A member outside the supplied
identity inventory requires its own original identity/provenance entry; a
filename or an older snapshot alone is insufficient.

## Actual Main call path

`original_source_preview.configure` first retains its existing successful
consumer. Its source-bank fallback follows the pinned current523 source tables
through card/buff/bonus/polymorph/entity relationships. Display sprites are not
substituted for in-world actors. Class/gender and active custom options remain
explicit inputs. Missing original actor data cannot borrow a legacy image.
Indirect summons use the typed `BuffCardSummonNPCClassID`/`NPCClassID` relation
to `NpcClass.Sprite`. Reusing a known stable conditional appearance requires
the complete current chain, NPC and preserved application condition to match.
Server/slot conditions stay uninterpreted; this path does not admit a new card
or apply its gameplay buffs.

The new `current523_source_bank` selector is enabled by a private configuration:

```sh
python3 tools/lineagem_original/configure_current523_source_bank.py \
  --tables-zip /private/current523-tables.zip \
  --manifest /private/source-bank/manifest.json \
  --manifest-sha256 <bank-manifest-content-address> \
  --output /private/current523-source-bank.json
```

Start the existing game with:

```sh
--current523-source-bank-config=/private/current523-source-bank.json
```

The normal player/follower/relic requests and motion state call the connected
loader and player. This configuration selects resources; it does not create
cards, change ownership, activate excluded content, or modify saved progression.
Without a command-line override, the loader can read an already installed
`user://current523_source_bank.json`; an absent configuration preserves the
existing behavior. Configuration generation does not write GameData or saves.
The fixed existing identity-pack loader keeps its own snapshot and manifest
checks. Source selection and presentation policy remain distinct from combat
and game-event authority.

The NPC fallback follows the two existing `patch523_spawn_policy.admit` gates
and preserves a successful base508 view. Only an admitted record whose old view
cannot load reaches the current source-bank view. It requires the exact
NPC/Sprite, spawn-view and territory tuple and the current unchanged-field gate;
it does not create a spawn or bypass map admission. Its existing hit/death and
attack-sequence state drives the same source preview.

`reference_sp2_bank.gd` reads the pinned bank and exact actor/action entries,
then resolves original member/bit/frame addresses through the existing decoder.
Known member SHA values remain pinned. Newly received originals without a
member SHA retain null and their supplied exact source domain, archive/member,
bytes/CRC and receipt identity. Their received status is not relabelled as
additional verification. Ordinary runtime integrity guards remain in the loader.

The later local connection delta also carries the complete original action
domain for every registered actor. An effect with one compiled action is not
assumed to have only one original action. Identical repeated literal layer
references retain their original ordered instance IDs and declaration origins,
while sharing one canonical frame/resource binding. They do not create extra
poses, clocks, drawing passes or a claim about native draw multiplicity.

Exact `SpriteRun.WalkSpriteID → RunSpriteID` relationships can supply an
optional RUN actor. Its frames, source clock and attributes come from that
actual actor and the existing primary weapon WALK-action policy. Missing RUN
input leaves the established WALK policy and an explicit status; it is not
reported as an original RUN animation. Cards, followers, relics, subslots and
admitted NPCs request this role only on their existing RUN state.

Existing spell and global presentation requests can fall through to the same
bank using `current523_source_effect_selection`. Legacy Spell rows must match
the complete current source definition. Current callers pass their actual
current Spell row to `notify_current_source_spell_event`; it selects the exact
SPR field and `EffectSpriteActionNo`, or requires the sole original action for
fields with no action selector. The global polymorph path uses the exact
`ConstantData.Name = PolymorphEffectSpriteID` relation and the existing apply
event. These methods do not admit spells, apply damage, change slots, add
gameplay triggers or interpret server conditions.

The existing skill service's cast/impact visual callback also passes its already
loaded, pinned `source523.profiles[skill.id].row` to this current-row entry.
Legacy source-ID calls keep their existing route. This is a presentation
delegation at the established event boundary; learning, cooldowns, costs,
damage and saved skill identities remain with their existing owners.

The admitted NPC view delegates the same typed presentation API. Its combat
owner retains event admission, timing, targeting, effect limits and lifetime.
Data, effect, transaction and save-owner logic is not copied into this bridge.

The existing NPC `emit_effect` rendering branch can also request an unparented
current-source one-shot when its legacy overlay cannot handle the exact source
action. A working candidate or legacy renderer remains first. The existing
caller still supplies the admitted Spell row, field, actor, point, facing and
effect limit, adopts the returned node and owns its cleanup. Cast, hit, damage,
proc, costs, target selection and rewards are unchanged. The source view uses
a shared texture-cache budget across its independent child layers, and the
caller conservatively reserves its existing available effect-byte budget.
Original member-byte progress is not mixed with that runtime texture budget.

The skill service also delegates its existing non-damage impact presentation
sites to the same source helper: cleanse, mana conversion, teleport, taunt,
successful status and turn-undead results, healing, stacks, marks and mana
procs. Each call uses the existing event point and the service's already loaded
source profile. It adds no success/failure mapping or new gameplay event.
The successful counter's existing impact callback uses the same delegation.
Current spell reads and provenance use the original ZIP member
`content/SpellClass.json` and its `SpellClass` table key.
The existing native-option spell presenter also delegates its already selected
full spell row and existing effect/success events after the legacy renderer.
Current source selection must match that whole row; the generic Sprite-only
fallback and invoke activation, probabilities and combat logic are unchanged.

The subsequent local aura bridge follows the existing World/subslot
`source_awakening_aura.configure` and process calls. Its activation still comes
only from the existing ownership/status service. It matches the bounded twelve
legacy awakening rules against the full current `BuffCardAwakenEffect` and
`StatusEffectAttr` rows, including the original gender-neutral attribute48
reference; it does not make attribute48 a general enum. Original idle3 and
optional walk0 keep their own source clocks. A missing walk hides this visual
while moving; idle pixels are not substituted as movement frames. The existing
legacy visual remains preferred when it succeeds.

Card selection also uses the actual typed deck rows: transform1,
MagicDollCardDeck2 and HolyStuffCardDeck98. The previous untested relic3
assumption is corrected; a guessed deck value cannot stand in for canonical
card/deck/category agreement. These local changes have not been tested,
rendered, pushed or used as evidence of game consumption.

Literal `]SpriteID` calls use the project's existing host overlay compatibility
contract. `build_reference_sp2_overlay_calls.py` connects only supplied normal
visual parent/action/token relationships to a single source child action.
Production dispatch requires that exact parent/action/token and literal call,
uses the same bank and renderer, and emits no native damage, sound or other
annotation callbacks. Identity-only, unknown-parent, pet and held test paths do
not become draw commands. Native M dispatch and compositor equivalence are not
claimed.

## Current inputs and execution boundary

The subsequent local checkpoint is
`sp2-bank-reference-instance-connections/summary.json`. Existing source receipts
now record 21,546 priority inputs / 3,213,387,753 original bytes. Its active
priority raw registry contains 18,744 unique files / 2,939,773,032 original
bytes. Across all registered scopes the bank has 18,831 raw members /
2,957,866,666 bytes and 24,438 actor/action records. The separately admitted
follow-up input scope has 91 received files, with 81 connected in the bank.
Those are bank-output figures; actual service selection and whole-file or
whole-frame gameplay use are not inferred from them.

This delta includes current checkpoints 01–03 from the already approved Drive
source manifest: 2,477 normal priority originals / 151,681,392 bytes, 64
separate follow-up originals / 16,860,019 bytes and 22 explicit dependencies /
1,550,102 bytes. They remain `received_not_additionally_validated`. Raw parts,
DATs, ZIPs and prior checkpoints are preserved. No additional input, pixel,
direction, timing, regression or CI checks were run for this delta.

The original dummy exclusion checkpoint below records 476 source paths. The
current constructor also corrects a source-owner context variable collision:
its saved path-exclusion counter is 550 priority files / 13,088,719 bytes,
including those 476. The two shared normal files remain preserved. This is an
implementation correction using the same literal source declarations, not a
classification based on missing pixels or unfamiliar names. Per-file outcome
states and path counters remain distinct and must not be added together.

The figures below describe the preceding checkpoint, before that local delta.

The original 82 monster ZIPs supplied 17,719 priority SP2 members /
2,949,427,158 original bytes. They were received and checked before the user's
instruction to stop additional verification. Already received checkpoint04 and
magic-doll sources subsequently supplied 1,350 more priority members /
112,279,203 bytes for connection, with the explicit stage
`received_not_additionally_validated`. Thus supplied priority inputs total
19,069 members / 3,061,706,361 bytes; 26,921 members / 1,762,628,452 bytes still
lack local original input in this snapshot. The full missing container/member
list remains private. Existing raw ZIPs, parts and saves are preserved.

The receipt-based writer has produced 21,048 active actor/action records for
2,584 source actor definitions after the dummy exclusion. Its raw registry contains 16,978 files /
2,821,826,819 original bytes: 16,952 priority files, 23 separately admitted
follow-up files and three dependency files outside the difference inventory.
The priority members account for 2,818,161,303 original bytes. The prior
21,049-record snapshot and its inactive record remain preserved separately.
The 16 separately supplied dependency inputs do not add to either target
denominator. Four received follow-up files still need their parent
dependency closure. These are output-construction figures, not played resources
or a quality guarantee. The complete priority file outcomes retain input,
output, selection, installation and playback as separate stages.

The bank-scoped registry retains proof for all 1,243 literal dummy declaration
IDs in the held complete SPR snapshot, including `list_17.spr:8334`:
`#17560 1 dummy 102.type(0)`. The priority scope records 476 excluded dummy
connection paths / 9,241,415 original bytes and preserves two shared normal
files / 60,517 bytes. These counts are not additive resource use. Production
consumers require the source-dummy policy marker, reject excluded active
actor/alias/layer endpoints and preserve inactive edge proofs separately from
the normal active projection. Shared physical files are not globally banned.

Remaining source-construction outcomes identify repeated layer edges, literal
counts not resolved by this reader, ambiguous/missing declarations, cycles and
14 zero-total-tick actions. They retain exact source action keys and previous
blocker history. Zero ticks are not replaced by a fabricated animation duration,
and reader limitations are not presented as defects in the native client.
Missing current dependency identities and original member closures remain
separate input blockers. In particular, the received 28615/28619 follow-up
actions still need original 28617/28618/28621/28622 member inputs.

All 30 complete original SPR files are available. The current source table ZIP
and the follow-up metadata version 1 are also received. The historical Library
search-result helper's HTTP 401 remains separate from successful, authorized
Drive receipt and resolved-reference metadata materialization; that failed
operation was not retried or bypassed.

Before the stop instruction, the nine-action original-input diagnostic passed
770 Godot checks; the earlier Python source-bank tests also passed. Those are
historical, bounded diagnostic results. The later production caller, host-timing
and overlay changes have not been tested or replayed. No new hash/CRC audit,
frame/quality check, regression test or CI run was started for those changes.
Compilation/output writing after that instruction is labelled accordingly.
Actual Main playback, transitions and save/restart preservation are not claimed
from the diagnostic or from code connection alone. The 95% use goal is not
established.

Map-family originals receive asset/action support only. Map placement, TI2
geometry and map-event activation remain with the map lane; UI screens remain
with the UI lane. Sound, arena, Ziggurat, clan, siege, pets and LineageM
engine/APK work remain excluded. Shared original references do not authorize
activating these features.

The map placement exclusion also retains the explicitly excluded SPR IDs 1850,
1886, 1887, 3977–3980 and 3996–3999 (the map lane's 229 placements). It does
not remove originals or blacklist matching numeric IDs in other namespaces or
normal non-map consumers. This action bank does not own placement activation.

## Local publication boundary

PR272 was created at `c43076de27180c01073df7f637092eaa63f4bfd2`.
The later source-instance, RUN and current-spell changes are local. A push to
this open PR triggers the repository's
`cancel-superseded-pr-ci.yml` `pull_request_target: synchronize` workflow, which
is not suppressed by the ordinary skip-CI commit token. With additional CI
forbidden, this work does not push that update, close/reopen the PR to avoid
the event, or change workflow/security settings. Local source and private
outputs remain preserved for the existing publication contract to be resolved.
