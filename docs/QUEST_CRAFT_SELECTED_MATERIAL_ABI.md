# Selected quest-held material input for existing crafting

Implementation-only; no new tests, parsing or game execution. The current old execution counts do not validate this delta.

`world.patch523_set_owned_materials(recipe_id: String, batches: int, selections: Array) -> Dictionary` installs a session-only selection for an already compiled ordinary patch523 recipe. It returns `{ok, recipe_id, batch, selected, saved:false, use_authorized:false}` or `{ok:false, reason}`. It grants nothing, spends nothing, and does not authorize an effect. Delegated protection recipes keep their own owner. `world.patch523_clear_owned_materials(recipe_id)` cancels the session selection. Installing another equipment rules file clears these selections.

Each selection has exactly six fields:

- `physical_id`: the actual selected existing quest-held item_instances key.
- `quantity`: the total units to consume from this physical stack.
- `expected_quantity`: the current physical quantity before use.
- `expected_remaining`: expected_quantity minus quantity.
- `quest_reward_receipt`: the exact immutable saved original quest/reward/source receipt.
- `material_allocations`: array of exact `{material_row_id, quantity}` dictionaries, summing to quantity. Use one physical selection with multiple allocations, never duplicate that physical ID in the request.

`material_row_id` is the original ItemCraftInput row selected by the existing SlotIndex -> source row mapping. It is not a physical UUID. This adapter supports only non-wallet, non-equipment +0 materials whose original full ItemClass row and blessing match the selected quest receipt and the compiled recipe input. Missing row IDs, locks, Test/dummy declarations, uncertain saves, expiry, changed ownership or quantity, changed batch, over-allocation and different output identity preserve the material. Existing recipe/source limits and user cost/RNG policies remain in the original executor.

The original UI caller sets the existing source row choices, submits this physical selection, then invokes the existing crafting quote/confirm path. That path re-reads the actual owned item and receipt, selects these inputs first within each declared row allocation, and joins the unchanged common consumption ABI into the final executor candidate. Native/expedition inputs keep their existing paths. No source-only reference recipe becomes executable. Original node offsets/layout binding are not supplied or invented by this adapter.

The save includes inventory, item_instances, quest_state.item_grants.used_quantity, gold, next physical ID, crafting usage/log, the existing persisted RNG and consumable_state.source_quest_craft_receipts. The permanent receipt keeps the compiled rules SHA, source recipe, selected input proof/allocation and the actual selected output/physical IDs. Fresh canonical native equipment outputs also retain the associated supply receipt without rewriting an older object. Live ownership and receipt state are adopted after confirmed save. Failed/uncertain storage obeys the shared save/reload lock; a no-material-consumption failure policy leaves the input and quest use ledger untouched.

The unchanged quest_reward_consumption and quest_reward_ownership modules remain the selected-input ownership authority. This adapter is not a new crafting engine, an original UI completion, a material count completion or evidence that all original recipes/effects operate.
