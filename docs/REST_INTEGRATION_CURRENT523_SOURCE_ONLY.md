# Current original input and owned-material connections

This follow-up extends PR269 after `cf84141377f7b831e227445819e1e1454130325b`.
Changes are **unexecuted and unverified** under the user's instruction. No new
test, game run, render, integrity audit or CI was started. Earlier Main47 and
receipt735 results belong only to `ea838f6b`; the recorded 58/146 bounded item
paths and 88 remaining classes are unchanged.

## Adopted public input contracts

The card identity/catalog/skill input is from data271 `3febf333584b14670af5b532077b52b55135cb82`;
option, doll and relic inputs are from `1b0fffaad2355feec95a80a34ea154b0d514c3a2`.
Fishing inputs are from `7a17aa0b2ff71797aed998e87401f92700597afd`.
The existing shared original reader supplies the pinned current523 archive.
Saved m508/m523 identifiers are retained as save ABI, separate from definition
origin. Old card and NPC models are not missing-source defaults.

`current523_item_data.describe()` exposes original typed references only. Its
empty compiled-use fields do not authorize an effect. Historical sidecar files,
their saved provenance, existing ownership and saves remain preserved.

## Actual owned-input calls

`skill_awakening_runtime.request_operation(identity, materials)` now accepts
`materials.physical_id` and passes the current original book row, archive and
pool proof to `current523_owned_card_material.prepare`. It preserves paid fees,
one-book policy, progression, selection RNG and the existing original UI guard.
No original awakening scene/node binding was created or declared installed.

`option_awakening_runtime.use_native_unlock_item(item_name, selected_instance)`
uses the same selected ownership boundary and the original Item346901/Buff91531
unlock rules. World's real inventory activation forwards the selected ID before
the raw quest-reward fallback. The existing consumable entry forwards it too.
The current definition's patch523 origin and m508 saved item ID no longer
contradict the exact-identity guard.

The shared helper accepts authenticated quest receipts, existing typed awakening
supplies whose full original row matches, and current-origin individual physical
objects with exact source row and inventory count. Ambiguous selections, locks,
equipment, blessing/enchant mismatch, unsupported source class/server/date/region
conditions and unknown quantity namespaces preserve the input. It never grants a
temporary item, renames a raw key or converts historical saves.

Quest inputs use the existing five-field consumption ABI: physical ID, quantity,
expected quantity, expected remainder and immutable quest reward receipt. The
effect owner stages that debit/journal together with result and other costs and
commits once. It adopts live state only after save success; a failed save or
post-save journal adoption blocks retries until a normal reload. Implementation
is not evidence that failure/reconnect behavior has now been executed.

## NPC creation and visual owner boundary

`base508_monster_context` reads current original rows through the shared loader.
`base508_source_roster.record/for_spawn` resolve the requested exact NPC/spawn/
territory tuple without an old `PACK.actor` dependency. Existing source encounter
IDs, explicit host region requests, population/respawn and host combat values are
retained. Test/dummy, activation and server restrictions remain effective.

`base508_monster_spawn_port.apply` refreshes an already explicit source encounter
from current rows and uses the existing map admission followed by Sprite272's
published `current523_source_bank_selection.select(record, admission)` contract
at `c43076de27180c01073df7f637092eaa63f4bfd2`. It does not instantiate a duplicate
renderer or activate an old visual fallback. That separate module and actual new
bank configuration/bytes must be integrated by their owner; absence remains an
explicit hold, not observed spawning or pixel delivery.

NPC combat now configures the public original-input registry instead of selecting
an old NPC/effect manifest as default. Existing admitted actor/attack, host opt-in,
clock, damage, loot and save owners remain in place. New AI/probability semantics
are not inferred.

Awakening VFX forwards original SpellClass sprite fields to the existing source
preview overlay call only when its context identifies the pinned current source
bank. The old base508 overlay manifest and sparse renderer are reference-only.
An absent current effect child/action binding is explicitly unavailable. The
published Sprite272 overlay dispatcher still needs the exact effect-stage/action
binding to display these calls; successful skill damage is not visual completion.

## Other integrated consumer follow-ups

Fishing reads the public original projection when its explicit/default dedicated
input is absent. Contest start stores the exact admitted contest/rule/fish/rank/
reward/item/input contract. Claim rechecks current input failure and admission and
matches that saved contract before the existing single save. Older contests
without this proof are preserved and held; they are not deleted, restarted or
paid against replacement definitions. Existing time/weekly unavailable rows stay
unavailable.

The five-path map follow-up `d01758db57d46d2b7a57dafbbf6f4880daf8118e` is included:
three map input/coordinate/walk modules, its documentation, and only the bounded
World deferred registration/bind methods. Existing item/effect/save changes are
retained. UI267/PR270 inputs remain external dependencies with explicit waiting;
no original UI or image was created here. See `SOURCE523_WORLD_MAP_INPUT.md`.

No main merge, new PR/environment/installer, private data upload, source/pixel
generation, pack replacement, save conversion or original deletion occurred.
Sound and the existing user exclusions remain excluded. These code changes do
not establish a new whole-source gameplay usage percentage.
