# Card skill awakening follow-up

PR221 retains source growth on skill reroll; paid operations remain disabled.

## Fee and book quantity evidence (not activated rules)

All three source decks — transformation1, doll2, relic98 — repeat these values:

| Source grade | Name | ValueType1 | Type1 row IDs (deck1/2/98) | Book ItemClassID |
|---|---|---:|---|---:|
| 3 | 희귀 | 100000 | 544 / 274 / 1068 | 75184 |
| 4 | 영웅 | 300000 | 554 / 284 / 1078 | 75194 |
| 5 | 전설 | 500000 | 564 / 294 / 1088 | 95624 |
| 32 | 신화 | 1000000 | 574 / 304 / 1098 | 118992 |
| 52 | 유일 | 3000000 | 1063 / 1463 / 1561 | 243043 |

Type3 repeats the same15 values; Type2 repeats rare/hero/legend values in9rows.
The missing ValueType enum prevents assigning initial/reroll/EXP operations to
these rows. Matching historical rare/hero fees is a clue, not current fee proof.
Types5/6 contain100–300/100–120, Type16 is50; no source unit authorizes treating
these as consumed book counts. Named pool bonuses explicitly use Unit10874 and
resolve to group IDs, not quantities. Each of507 book crafting output rows has
Amount1: **one is a produced-book quantity candidate only**, not evidence that
awakening consumes one book. Combat SpellMaterialItemAmount0 is unrelated.

## Source VFX integration and input gap

`skill_awakening_source_vfx.gd` dispatches exact base508 SpellClassID and its
nonzero cast/effect/impact/success fields to PR217's existing
`original_source_preview.notify_source_spell_event`. It does not alias learned
spell names or create substitute art. Points are copied before damage; local
successful-hit placement remains compatibility behavior, not recovered travel
or server timing. Missing compositor/manifest/record is reported unavailable.
Death, player death, unequip and cooldown paths cannot create extra proc events.

UI v10 does not supply these first-priority original screen files:

| Container | Member | Bytes | CRC32 |
|---|---|---:|---|
| Client/Data/UI117.dat | UI/Change/Change_Awaken_Skill.csb | 52292 | 77cf6bf9 |
| Client/Data/UI117.dat | UI/Change/Change_Awaken_SkillExp.csb | 87632 | e939b3dc |

First real fire-bolt resource pair: `Client/Data/Sprite80.dat` →
`Sprite/1583-0.sp2`; `Client/Data/Sprite208.dat` → `Sprite/218-0.sp2`.
The private exact request lists95 SP2 files covering93 of95 referenced SpriteIDs
(6324903 compressed member bytes); IDs1085/10705 have no matching file in the
provided structure registry. This does not prove absence in the original client.
UI atlas dependencies must be read from the CSBs, not guessed from filenames.

The request is delivered privately:
https://drive.google.com/file/d/1d-iXUW6Vx1QWxivUmMNCvND148XmVLkk/view

## Validation

Godot4.6.3:61 service/transaction/source-event checks,45 real World/UI checks.
The latter instantiate the production Monster scene, inflict lethal damage,
run `retire_for_pool`/`setup`, verify clean life_id and per-card cooldown, then
verify a new hit on the reused body. Source-event unit checks use a clearly
labelled mock compositor; they do not prove original pixel playback. Installed
original skill art and screen CSBs remain pending. Existing exit-time resource
warnings remain; no script/parse errors. Android/Godot4.7.2 unverified.

## Source UI material checkpoint

Original UI batches001/002/003 were materialized with Library identity, ZIP CRC
and supplied SHA verified. The final contract is
`libfile_0cf358c0d4e881919dbdee4a3e2d3700` v0, SHA
`74c804540c498821cbe9a563a3d0ffa6b36edf599245eae9a7fea660c90111b6`.
All10CSBs/487nodes are normalized. Combined card/inventory/skill metadata now
resolves12 atlas pages/138 unique requested frame keys, with no missing plist.
Independent Pillow and Godot pixels match for all138 keys, including rotation
and trim restoration. Original producer count594 includes repeated bindings;
it is not the number of unique cropped frames.

The skill screen uses original CSB references for the target magic ring, plus,
book slot, skill-list panel and awakening-button states. The target area retains
original card/slot centers; adaptive controls retain44px touches. The remaining
layout is adaptive, not a literal full-CSB screen reconstruction. The book slot
stays empty because no verified book-icon/owned-count binding is installed; no
item ownership is invented. The raw CSB widget color was then read with the existing bounded FlatBuffer
reader and verified against each of487 node identities. Its mask-panel tint
is black, and the ring also retains its exact source tint; these are now applied. Particle/timeline and full EXP screen
controls are not claimed implemented merely because their sources are present.
51 actual World/UI checks pass at1280x720/854x480, including material bindings
and preserved states. Original pixel screenshots stay in the private handoff.

## Real priority spell pixels

The existing Library transfer manifest resolved the missing SPR source metadata
without a new extraction: `libfile_44951912853c8191936fbe5da3abd2e9` v0, SHA
`eb01668a69a6c0a8531147be4c05e4f9b559f0440fbbff92375ef99e8377b778`.
Original1583 action0 declares source frames3,0,1,2 with ticks3,2,3,2; original218
declares9,0,0,1..8 with ticks1,4,1,1..1. Both FPS fields are absent. Existing
compatible PC24 clock/blend policy is retained and explicitly unverified for M.

The private builder reuses PR217 SPR/SP2 readers, verifies raw member SHA/CRC,
retains exact offsets/RGB565 pixels, and records missing direction addresses.
1583 has16 actual direction/frame PNGs (source bits0–3); bits4–7 are absent.
Its sparse adapter refuses those directions instead of inventing reflections.
218 has10 stored frames and its fixed SPR source direction supports all host
facings through the existing compositor. No shared PR217 source file is replaced.
The bounded partial-only adapter caches96 textures and pools at most32 sprites.
A freed-overlay typed-filter error in PR217 was exposed by real repeat playback;
the card adapter prunes invalid handles before calling that existing API.

16 real compositor/pixel checks pass: original first/next frames and pixels,
completion, resource release, sprite reuse/reset, fixed effect position across
target movement, and refusal of missing1583 directions. These are actual source
pixels, separate from the earlier mock event tests. No original flight/server
timing or missing-direction behavior is claimed recovered.

## Expanded source effects checkpoint

All95 requested direct SP2 files are now materialized and size/SHA/CRC checked,
including19 exact members from the three verified preexisting Library ZIPs.
The compiler also reuses only SPR101/105 child members already available in those
ZIPs; there is no new source acquisition.90 effects compile for all directions,
plus1583 for its four stored directions.51 effects have all declared layers;
39 of the90 full-direction bodies still miss declared child layers. Private
readiness metadata preserves exact missing-member names; the public readiness
manifest records only status/counts and requires the private pack.

49 child member names remain:46 have exact original registry matches totaling
3275720 compressed member bytes;3 have no matching row in the supplied structural
registry. Sprite6 has no frame action;25942 has a literal inline#header at
list_25.spr:16262 that the shared parser does not accept. These are precise
parser/dependency holds, not a claim that the direct95 files were not supplied.
Source-only body playback is labelled incomplete in diagnostics/combat feedback.

Validation:305 compiled-effect consumer checks pass for90 full-direction and
one sparse-direction clips, including124 exact body/shadow/clothes texture
comparisons.16 original priority pixel/render/pool checks and61 service/atomic
checks pass.52 real World/UI checks include a lethal actual Monster skill proc
that emits both original1583/218 stages. All logs have no script/parse errors.
The two old exit-time CanvasItem/resource warnings remain on World teardown.

A local integration-stage ZIP is prepared (not a standalone installer and not
a substitute for merging against the installed base manifest). External artifact
delivery is pending specific authorization after automatic review rejected the
private child-request metadata upload. Original pixels remain outside Git.
