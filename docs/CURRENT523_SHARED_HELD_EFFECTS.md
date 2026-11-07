# Shared original held-effect consumer connection — UNVERIFIED

Continues PR281 from67d88ebf. Actual inventory activation and the original-use
five-field API now reuse existing source-validated HP/MP/finite-buff effect
owners for genuine quest-held quantities rather than requiring a fixed reviewed
ItemClass list. Unknown effects, source restrictions and unproven profile inputs
remain blocked. No new ItemClass identity, effect formula or supply is invented.

The existing HP consumer accepts an explicit current-original mode, using the
same metadata as the native physical owner: exact233 metadata, the existing
236/237 restoration contract, or existing hp_use_metadata. The old two-argument
233 interface remains. Existing poison/HP/MP/buff restrictions and the current
single Sprite event/full ItemClass invocation are preserved.

An isolated view holds candidate inventory, HP/MP/buffs/cooldowns and RNG. The
selected immutable quest proof, expected quantity/remainder and locks are
rechecked; the existing common receipt/debit stage joins those effects in one
confirmed save. Live adoption still follows confirmation; uncertainty blocks
retry. This is not a transient live native grant or raw-key conversion. Ordinary
bags/selection and source310/239 retain their separate existing owners.

No new tests, parsing, compilation, game, rendering or CI. New code is UNVERIFIED;
historical58/146 and88 remaining are unchanged. Original inputs/packs/saves and
old worktrees remain preserved. No main merge or new asset delivery is claimed.
