# Qualified current-source blessing lookup — UNVERIFIED

The actual World source-ID lookup now resolves an absent m523:item:ID:bless:2/3
through the existing variant factory only when its normal base is already
registered as the exact current original non-equipment item. The actual current_original_native_projection registration must include the
ItemClassID with no pending ambiguity, and must identify the same archive. The full original
row and ItemBlessCode row must exist and must not be excluded. Existing explicit
variant entries, including conflicts, are never repaired or replaced.

The shared supplier and its floor/shop/craft/reward callers use this existing
source-ID lookup. An explicit producer blessing can therefore match the actual
source-qualified definition without relying on historical BIN sidecars or
registering every possible variant as an owned item. Source IDs, source rows,
name suffixes, stats and initial blessing come from the established factory.
No new probability/quantity/eligibility is introduced. Acquisition and execution
still pass their original producer, selected ownership and single-save gates.

This is read-only definition resolution. No live catalog/ownership mutation,
old-save conversion, legacy alias merge, second grant or source permission is
created. Equipment and specialized owners retain their existing namespace.
Unknown effects stay blocked and all original conditions remain represented.

No new parsing/compiler/tests/game/rendering/CI execution. UNVERIFIED, not a
verified usage-count increase, installation claim or full-original completion.
