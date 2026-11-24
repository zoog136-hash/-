# Pickup stack proof: avoid work on receipts which cannot merge

The Android 523.837 capture had one 834 ms automatic pickup, including a
278 ms native-stack save validation. Those are nested durations. It does not
show how much was spent folding stacks separately or prove that an
outstanding autosave was the bottleneck.

- In the inventory merge planner, any original receipt with no same-name,
  enchant-zero, receipted peer cannot merge. Skip proof and grouping for such
  receipts. Supply the exact cheap candidate scan already performed by the
  production caller, in the same call. Actual merging still checks original
  item ID, bless, cap, lock, remaining quantity, ownership and receipts.
- Initial floor acquisition used to check the same supply profile once to
  choose an owner and again inside grant staging. The floor owner makes that
  decision once and still fails closed on an invalid claimed grant.
- The later HUD pass can see intervening changes, so it still runs, but
  without singleton receipt proofs. Do not skip validation on a guess that
  the bag didn't change. The save writer wait and transaction boundary are
  unchanged. New details distinguish immediate stack fold, HUD stack fold,
  and staged pickup validation (which can contain save.wait).

The synthetic 303-entry planner fixture performs only two receipt proofs for
the one possible name, and admitting a new receipt is picked up by a later
scan. Source 523 cap and save checks remain covered by existing tests. This
does not measure Android pickup latency or prove a frame target. No original
pack or assets are changed.

## Owned original card ticket

After a successful ticket save the same synchronous world publication still
updates the real gameplay values, ownership/RNG and card collection. The
Renewal bag accepts intermediate inputs but materializes its rows once, from
the final ticket count and physical ownership together. Only row/detail work
is batched. The reveal is still invoked in the same call afterward; any
failure returns without publishing or revealing. No change to weights,
eligibility, effect timing, save ordering or other draw entry points.

The regression runs the real Renewal ticket renderer and inventory row
model with controlled quote/save boundaries. It observes one grid rebuild
rather than two when both inputs change, successful/failed reveal ordering,
and exact final ownership, ticket count and RNG. This is not a phone latency
measurement. `card.ticket_hud_publish` adds a timing point for retesting.
