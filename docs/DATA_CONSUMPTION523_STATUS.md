# Current523 definition consumption audit

This Draft adds a private consumption audit tool and one bounded source-data
connection. It does not complete all original definitions or establish 95% use.
The reviewed baseline is main `1333851bb2eb193a6ac1fc3e3b852787c08994ff`.

## Fixed input and evidence

The existing private current523 archive was received through authenticated Drive
after the Library transfer helper failed at tools/list with HTTP401 before byte
transfer. The received archive is 25,031,173 bytes, SHA256
`d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`;
all ZIP CRCs and its index, CSV inventory and summary match independently read
content: **1,065 tables, 2,323,700 rows, 457,729,872 uncompressed JSON bytes**.
Archive bytes, compressed members, JSON bytes and generated cache bytes remain
separate. No original tables, private delivery references, packs or saves are
included in this PR.

The private ledger retains every table, parser/compiler candidates, consumer,
caller, owner, storage contract and remaining uncertainty. Reviewed code chains
currently cover selected rows/fields in 122 tables. This is static connection
evidence, not normal gameplay observation or full-table completion. The prior
57-table parsing observation was a limited PR264 run; the other 1,008 tables
must not be labeled unused from that result.

The audit tool leaves missing evidence unresolved. Static mentions, loading,
registration, installation, fixtures and inspection renders cannot establish
gameplay coverage. A full-table claim requires a retained runtime artifact,
source/table SHA, original row indices, consumed fields and reviewed caller.
Partial tables never add their entire JSON size to the full-use numerator.

The first scope review identifies 50 empty tables and 102 nonempty tables for
explicitly excluded features or stopped/test content. These remain in the fixed
denominator. Under this classification the theoretical full-table ceiling is
913/1,065 (85.73%), even before other unresolved work. Exclusion is a scope
decision, not a claim that shared metadata has no reader. Original row-level
scope and mixed-use tables still require review; this ceiling is provisional.

## Bounded connection

The death source reader now validates `ConstantData.NoDeathPenaltyLevel` and
uses it in the existing local **item-loss exemption**. The pinned source value
and previous reviewed default are both 30. Missing source retains the existing
reviewed local policy. Invalid or duplicate source constants fail before active
rules are replaced. The save schema, ownership and recovery receipts are retained.

Experience loss keeps its separate boundary: the original Experience table has
loss at level30, while item DropRate is zero at30 and positive at31. The scalar
is applied to the existing local item policy; it does not certify the original
server's global interpretation. Only one of ConstantData's 490 rows is newly
connected; its entire 57,677-byte table is not counted as used.

## Ownership and unresolved candidates

PR269 owns remaining integration, source item ownership/effects and the latest
231/248/265 handoffs. PR264 owns attendance/pass, source reward consumption,
jade/grail and ordinary trial backend. PR265 owns its equipment systems. PR267
owns original UI, PR222 maps, and existing Sprite/image work remains separate.
Sound, clan/siege, pets, arena/ziggurat, stopped content and cancelled work stay
excluded. Shared Item/Bonus/Spell/Reward tables cannot be assigned wholly to one
completed feature.

Consumer gaps found in reviewed modules include `CombinationConstants`,
`SymbolPayment`, `SymbolEnchant` and `TotemConstant`. A compiler output alone is
not gameplay use. Missing type meanings or existing UI/owner contracts prevent
inventing a new transaction or interface. `GachaCraft` supply, material and final
cost definitions were found by following the associated Unit/Bonus/ItemBonus
joins beyond its five tables. These are book-crafting records; the source
category is not directly activatable, and its candidate refresh cost must not
be used as the final crafting cost. Individual recipe costs also differ, so a
global default cannot replace them. The current-candidate, confirmation and
ownership transaction contract remains a PR269 handoff; weights or drop-view
references do not establish normal acquisition. Class change,
domination stones, symbols, guardian slots and mastery already have partial
consumers and must not be reported wholly unused.

## Validation status

Completed before the latest instruction to stop starting new validation work:
Python audit21, existing Core staging10, world links5, codec18 (one separate
skip), pinned-source scalar21, and the committed723-sheet integrity check.
The production-resource import completed. Its first policy check exposed an
outdated test host; the fixture now uses the current real star-combat service
and checks charging/frozen gates. Production skill behavior is unchanged.

The controlled Main run exercised the new30/31 item boundary and two fresh Main
processes using the default installed pack, with17/17 checks in each process.
The entire death suite **failed**:119 checks,14 failures and one Script Error in
the later recovery UI/certificate/expiry coverage. The cause is not classified
as pre-existing or a regression. Logs are retained privately. No further
investigation or rerun is started under the latest scope instruction.

The already-running Core continuation retains its original check set and error
rules; pending checks are not passes. Controlled ownership fixtures are distinct
from normal acquisition or gameplay coverage. Resource checks verify the existing
723 sheets, not complete original art delivery. No remote/manual CI, main merge,
workflow change, new art or source pack publication is part of this Draft.
