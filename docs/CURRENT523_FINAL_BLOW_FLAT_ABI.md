# Native final-blow flat receiver — local, unverified

Explicit user decision (2026-11-06): follow the success probability, add flat before amplification, and integerize only a positive flat value. No original server formula is asserted.

Input: `_equipment_inven_sum("source_final_blow_flat")`, raw damage units from exact `FinalBlowAdditionalDmg` / Unit.Value (Unit1), divisor1. `totals(world,target)` returns `flat` alongside existing `chance_pct` and `amp_pct`. Existing book base/enhancement readers use the same field. The data owner may supply missing original ItemBonus operands through the established equipment sum, preserving its exact row/condition/mapped-ID and double-count guards. This ABI does not itself claim every original row is supplied.

`damage(world, amount, by_spell, target)` preserves the existing admitted hit scope and chance threshold. Sum flat first; a positive finite total becomes `int(raw_flat)` (truncate toward zero); other values contribute zero. Use the same single success roll as percentage amplification. On success, return `amount + flat + existing_round((amount + flat) * max(amp_pct,0) / 100)`. Existing floor/nearest policy applies only to amplification. With amplification0, positive integer flat still uses that chance and adds flat. Without positive flat or amplification, no roll occurs. Chance0 never triggers; a failed roll returns the input amount. No extra hit, second roll, recursive event or different card engine is added.

Current location remains after existing amplification/growth and before separate elemental/undead additions. Existing source_final_blow_scope, possession/application restrictions, equipment identity/blessing and +0-family baseline handling remain. No saved identity, physical quantity, source row, original price or receipt is changed. This does not reintroduce excluded spell-stage/potion/emoticon work.

No tests, compilation, game, rendering, CI, remote publication or merge. Public PR281 checkpoint af3ec2b35c533d98f21c6fc7949291c482d86b22 and the retained local candidate81de5e6aba4b7fb412e2654d0f7d2ff510a3d25b have the same parent tree for this follow-up; original local commit ancestry is preserved.
