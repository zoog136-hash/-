# Actual quest-held inventory and quick-use routing — UNVERIFIED

Inventory/quick-use item keys now select a real issued physical object before
calling the same try_use_held owner as explicit activation. All same-key quest
proofs are validated, including raw identity, source row, original grant, receipt,
claimed quest and aggregate physical/inventory remainder. A locked or invalid
proof never falls through to generic name-only native/legacy consumption.

Among actual issued objects the host explicitly chooses the first unlocked
sorted physical ID; this is a local deterministic selection policy, not source
acquisition order. Existing automatic-use registration and effect eligibility
are not changed. The selected actual ID is passed to the original-use API and
common effect/debit/single-save path. No canonical rename or live grant occurs.

This extends actual service callers for the shared current-original HP/MP/buff,
bag/selection/book and exact return/cure owners already connected in PR281.
Unresolved effects and all original source restrictions remain held. No new
execution, tests, compilation, rendering or CI; code is UNVERIFIED and historical
completion counters are unchanged. Original inputs, saved identities and refs
remain preserved.
