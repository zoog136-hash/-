# Existing specialized-supply shop payment bridge

Local implementation, untested. No tests, compilation, game, rendering, CI, publication or merge.

Market/NPC payment reuses the existing `native_awakening_supply` owner rather than manufacturing generic receipts. Admission requires the existing owner's exact current-source record, the shop's whole original ItemClass row, the same source archive and an actually registered current typed DTO with its existing server/service/date/deletion holds intact. Only existing schema2 `source_awakening_supply` physical ownership is admitted here. The owner's supported-ID list is not a completed-content count; source wallets, absent registrations and unsupported source conditions remain under their existing owners.

`_special_payment_binding(original, amount)` selects an unlocked, unequipped, non-selected-ammunition actual physical ID whose existing quantity alone covers payment. Ascending physical ID is the explicit TWILIGHT custody policy. A name does not confer ownership. Same-key mixed provenance and a competing funded legacy key block payment. No aggregation, alias, raw quest conversion, historical schema upgrade or regrant is performed.

`_prepare_native_payment` calls the existing `prepare_debit(world, item_id, amount, selected_physical_id)` and `matches_payload`. Its result must consume only that one source-owned object and contain no quest debit step. The shop preserves the distinct `source_awakening_supply` receipt and selected physical ID in `payment_native_inputs`; it does not rename this into `source_native_stack_receipt`.

The existing `_commit` re-resolves and stages the same selected debit against live ownership. Inventory, physical quantity, pending order and purchase counter are written in one save. The generic native path additionally includes its consumption ledger. Save response errors keep the existing reload lock and do not authorize a second purchase. Prices, source quantities, receipt schema and old saves are unchanged.

Still pending: exact multiple-receipt batch debit owner, mixed quest/legacy-origin selection, and specialized output suppliers. Existing `native_awakening_supply.prepare_debit` supports broader origin choices for other callers, but this bridge deliberately does not assume those choices are authorized shop payment semantics.
