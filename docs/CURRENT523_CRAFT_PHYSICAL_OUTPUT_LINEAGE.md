# Complete physical output lineage for existing source crafting

Local-only, untested follow-up after67372d679a44273a316ca338498388316ee0e941. Public PR281 baseline remains af3ec2b35c533d98f21c6fc7949291c482d86b22. No tests, compilation, game, rendering, CI, remote write, merge, original upload or distribution/phone update.

## Actual connected boundary

The existing World._patch523_craft_requested calls the compiled execute→quest_material_inputs.join→current523_native_stack.join_craft_output pipeline and saves inventory, item_instances, crafting log, usage, optional quest_state and consumable_state together. Existing source outputs, amounts, material allocations, source restrictions, RNG and saved identities remain authoritative and unchanged.

Native stack stage_grant now legitimately returns several new physical IDs for an original nonstackable output quantity, while the old join_craft_output appended only granted.id (the first object) to source_quest_craft_receipts.output_physical_ids. This follow-up consumes the complete granted.ids array; the existing specialized supplier's one-ID result retains its established fallback [id]. No new copies are issued by the adapter.

`issued_ids(record,quantity,previous,granted,origin,typed)` validates every actual new ID, exact record/name/level, per-object quantity, original grant receipt and supplier origin. Generic native outputs require unused/untransferred proof_entry receipts; specialized outputs require their actual schema2 supply stamp. All output quantities must sum to the already selected NET quantity after existing exact retained refunds. Existing candidate objects must be unchanged, and every added object must be in the returned list. The existing65536 physical-output bound is reused, not declared as a native stack cap.

The source craft receipt must match recipe ID, rules SHA, selected output, output name and gross output quantity. Every issued ID is appended once to that same receipt; transaction.source_native_output_physical_ids exposes the exact complete new set. Existing selected quest requests are also copied into the already typed supplier origin beside native requests. Full immutable quest provenance stays in the source craft receipt; no raw-key conversion, regrant or invented ItemClass is added. Existing shop claim already enumerates all newly added IDs and needs no duplicate edit.

This pipeline still adopts only through the existing owner save. Candidate authentication is implementation, not runtime proof, failure/reconnect validation or all-original completion. The existing World's save-response/retry behavior has not been changed here because that file is concurrently owned.

## Local flat unit guard

The earlier local flat receiver maps FinalBlowAdditionalDmg to source_final_blow_flat with divisor1. The existing enhancement parser now explicitly leaves a row skipped if that BonusType's UnitID is not1, alongside its existing Unit3 probability/amplification guard. No source value, Test-item exclusion, combat order or extra enhancement operand is added.

## Precise existing +0 contract for data owner

patch523_enchantment_projection.build() selects each existing source group/blessing (exact blessing if supplied, otherwise0). For a supported +0 whole-value key, runtime.options or runtime.extra_options carries {total,base_key,scale}. The real function is patch523_enhancement.prepare(book,record,blessing), NOT apply. It requires blessing1/2 and book.catalog_identity_matches; unknown/custom saved enhancement data is preserved. It uses OPTIONS.annotate(book.record(id)) as base, then replaces a descriptor with total - base[base_key] * scale. Existing supported seal IDs30671/130551 preserve their separate owner contract. World._source_enhancement_extra_record adds the prepared exact-rank scalar extras and marks _patch523_effective_extras; it is not a general permission to add absolute whole totals again.

Data282 ea6b958149ba461ac038ae82d1f3edc3901b4883 scripts/resources/current523_equipment_extra_input.gd was read. Its _original_delta correctly holds +0 rows pending this baseline correspondence. The existing compiler's behavior establishes an ABI only for its already bound source groups and actual base fields/units, not proof that every additional raw group is whole-value or shares final-blow semantics. No data/world file is modified or missing base is assumed0 by this follow-up.

## Quest4141 handoff requirement

The reported Quest60401→Reward23581→Item4141(amount10)→CurrencyUnitClass2024 is original relationship evidence only. To extend the existing payment path, data should supply the exact original ItemClass row and current registered material DTO/archive/condition status, full CurrencyUnitClass row plus its owning Currency relation with sources versus for_give direction, and the original Reward fields ID/RewardClassID/Amount/ItemBlessCodeID/RewardEnhancementTypeID/ClanOnly/UseImmediately plus quest eligibility/date declarations. Integration independently authenticates current claimed state and the actual physical quest receipt with source SHA, immutable granted quantity, current remaining quantity and existing used_quantity ledger. No private path or name match substitutes for those inputs.

Sound, pending spell-stage/potion/emoticon targets remain excluded. No map/population, NPC identity, source skill-range conversion, image, resource bank, frozen62ZIP/v30/index or installer file is changed.

The later ground-acquisition follow-up reuses this same issued_ids validator for existing native quantity suppliers. It does not add a second physical factory or modify the compiled recipe.
