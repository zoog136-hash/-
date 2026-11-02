# base508 source monster roster handoff

Base: bc1ae0c5d96e75e1a19b2c3d16286c09874e4bf6; first handoff commit 7be4331621577fcfae83dfd4c65a1be40860ec39. Managed monster install precedence and card strict-setting inheritance are preserved. No original pixels go in Git, no main push/merge, no old asset removal.

## Registration and runtime

The complete catalog registers 9,470 original NPC identities and 2,596 source model declarations, retaining test flags, source categories, UI-boss links and contextual variants. The exact source world-context index contains 56,482 class/view/territory pairs. Classification does not automatically enable a world enemy.

The full private pack contains **671 monster classes / 344 unique monster models / 13,740 exact source-context pairs**. It also preserves other supplied source models for a total of **604 models / 15,432 action tracks / 14,383 lossless source SP2 packets**. All previous 34 source classes are retained. Of the 671 classes, 110 carry literal contextual evidence and require explicit `source_m_allow_contextual=true`; tests and noncombat actors remain excluded from enemy factories. Source keys address exact class/view/territory identities rather than legacy name joins.

Four original plus ten additional guarded host ports apply native HP/MP/AC/MR/Exp and exact spawn-view level, retaining existing host positions/counts/respawns. This is an authored migration, not cross-game identity equality. Other combat parameters remain labeled host compatibility. No source loot probability, quantity or gold is invented. Explicit host regions can use one exact `source_m_key` and matching single-key `monster_types`; available records fail closed when assets or identity/context checks fail. **Native geographic placements: zero.** Do not report the 671 registrations as 671 automatically placed world encounters.

The renderer samples unchanged source packet pixels lazily, keeping exact original offsets and separate body/shadow/clothes layers. All known action codes are preserved; only source-mapped standard actions and explicit SpriteRun are selected by gameplay. Native timing stays null when unproven. Compatible mode labels PC24/inherited rates as compatibility; strict mode retains pending timing. Existing card playback settings are inherited.

## Validation

Full metadata audit: 14,987 file hashes, 3,682,528 layer addresses, 15,432 source action tracks, 13,740 exact context pairs. Forty real source RGBA/offset samples match the independent original Python decoder. Godot loads twelve representative models from the full pack and validates contextual opt-in. Actual Monster scene creation, native stats/body replacement and pool reset pass for fourteen guarded ports. The small 34-class PNG pack also passes bounded installation and wrong-context/sprite rejection. Full packet-pack installation has its own log in the final handoff. Device and per-item visual equivalence checks remain deferred.

Some pre-existing shaders/awakening PNG/audio imports were absent in this sparse checkout. They were restored from the base commit only in a local worktree overlay for actual scene testing; they are not code changes in this handoff.

## Remaining source inputs and unresolved interpretation

Library libfile_e8693ec0b3288191aaf23f20cbc132cd v1 contains the full known extraction queue: **18,287 monster-scope SP2 members / 2,980,993,887 bytes / 441 DAT archives**, including SpriteRun dependencies. Exact DAT/member/size/CRC are recorded.

Forty available model candidates lack a valid core action/reference interpretation; four installed models have optional-action issues. `model_build_issues.json` records those issues, including 196 SPR-referenced member names absent from the inventory. No archive, CRC or existence is invented for these 196 names. They need original provenance/interpretation work rather than blind extraction assumptions. Source-coordinate to host-map transforms, native timing/blend equations, remaining combat semantics, and unavailable pixels are not marked complete.

Old assets remain required by shared UI/atlases, other maps and fallback encounters. Even the replaced werewolf, lycanthrope, skeleton and bugbear profiles remain referenced outside these guarded ports. No old path is declared safe to delete.

## PR217 consumer integration (2026-11-02)

The exact handoff commits7be4331621577fcfae83dfd4c65a1be40860ec39 and
0cfccb8498f63fa8957db435640c291faa9d2253 were cherry-picked onto the current
card branch. Managed installation, card strict-setting inheritance, Girtas blend,
sparse diagnostics and companion presentation observations remain preserved.
Companion observations are gated away from monster consumer clocks.

All40 private Drive parts were independently fetched and SHA-verified, yielding
1339066288 bytes/SHA25688b3f4470664571f1f6b2894602fa7a6895cc0443a9ac2f5c914f206ba2b876e.
The common installer accepted14988 files/2441258451 bytes into a new managed
version; source-context/sprite rejections passed. Fresh Godot4.7.2 processes
loaded12 representative models and all14 actual Monster scenes passed native
replacement/stats/context/pool-reset/fallback checks. Card strict inheritance
and both companion presentation checks passed after integration. No pack rebuild,
public pixels, Android execution, full CI rerun or671-character visual approval.

A negative test reproduced an installer cache defect: valid NPC249/Sprite1108
could reuse NPC248/Sprite1110's already-checked model path/hash and skip the
expected-sprite test. Runtime already rejected it; installation must reject it
before activation. The cache key now includes expected sprite ID. The same
focused test accepts the valid pair and rejects the cross-sprite reference.

The next431-input compilation and diagnostic commitd24c66f are outside this671
checkpoint. Unknown clocks/blends,40 failed candidates, remaining source inputs
and native geographic placement (still0) are not marked complete. Old resources,
packs and saves remain preserved.
