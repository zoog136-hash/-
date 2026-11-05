# Exact selected quest-reward consumption ABI

This is the receipt/quantity boundary for an existing effect owner such as265. It changes no source costs, probabilities, effect values, Test restrictions or UI. It neither grants an item nor authorizes an effect.49 previously verified bounded item paths and97 remaining classes are unchanged; ownership-layer batching is not new processing/effect completion.

The module is `scripts/quests/quest_reward_consumption.gd`. Its ABI is:

```gdscript
available(world: Node) -> bool
stage(world: Node, requests: Array, consumer_data_sha256: String) -> Dictionary
current(world: Node, candidate: Dictionary) -> bool
matches_payload(world: Node, candidate: Dictionary, payload: Dictionary) -> bool
```

Each request has exactly these five fields:

```gdscript
{
    "physical_id": selected_actual_id,
    "quantity": amount_to_consume,
    "expected_quantity": observed_current_remaining,
    "expected_remaining": observed_current_remaining - amount_to_consume,
    "quest_reward_receipt": observed_original_receipt.duplicate(true)
}
```

`expected_quantity` is the current physical remaining BEFORE consumption, not `quest_reward_receipt.quantity`. That receipt quantity is the immutable original grant. `expected_remaining` is the exact expected AFTER value, including0. Only finite whole numeric quantities are accepted. Duplicate physical IDs must be explicitly combined into one request. Different IDs sharing an inventory key are debited independently and the inventory sum is reduced by their total.

On success, stage returns `ok`, `kind`, `base_stamp`, original `requests`, `consumer_data_sha256`, `selections`, and `overrides={inventory,item_instances,quest_state}`. It always returns `use_authorized=false`. The returned selections include the original quest/reward/ItemClass/blessing/source SHA, immutable original quantity, before/after quantity, immutable receipt and first-consumer/current-consumer data digests. Failure returns `ok=false,reason,use_authorized=false` with no live mutation or save.

The caller verifies its actual installed source/rules digest, original processing recipe/slot/input selection, target identity/blessing/enchant/lock/life/expiry and all source conditions. Pass that VERIFIED consumer data SHA (for public265's documented input, e2a51dce910799ee31c7943b84a6b44d3c84dfb964b25fe8962f39522cafd700). This SHA does not authorize an effect by itself. The first held-use receipt's existing pack_sha256 is preserved across compatible later owners, while the current consumer digest is returned separately for that owner's transaction log. Existing history must match the original ItemClass, blessing, quantity, used count, source proof and inventory key. No old proof is relabelled as238 or265.

The effect owner must build ONE final save candidate from `step.overrides.duplicate(true)`, then apply its own verified other debits, outputs, target modifications, costs, effect state, ledger and RNG candidate. Do not blindly merge another full inventory/item_instances baseline over these selected debits. Immediately before the single save, call `matches_payload(world,step,final_payload)`. It includes the stale-candidate check and rejects old-ledger/inventory overwrites, another selected quantity, consumed-ID resurrection, changed unselected quest receipts, invented new quest receipts, malformed physical values and inconsistent selected-key totals. Legitimate canonical target/output/legacy records remain the effect owner's responsibility; this is not a master authorization for arbitrary extra outputs or costs.

Save once using the existing owner writer. Only after confirmed success adopt inventory/item_instances and `quest_service.import_state(final_payload.quest_state)` together with the owner's other states. A write-then-error must be checked against the actual durable candidate. Changed/unconfirmed output must block retry pending reload. Do not debit, grant or save again around a successful consumer. Do not infer transaction success from handled/ok staging alone. A zero remaining quantity removes the selected physical ID; partial use keeps its exact immutable receipt and remaining physical record. Original quantity is never rewritten.

`available` checks ABI shape only. Stage still needs the real262 quest-service source/index/claimed/item_grants/validator/export state plus exact current inventory/item_instances and lock helper. The private source quest graph must actually be installed/loaded and SHA verified; mere receipt fields or an empty/fabricated source index are insufficient. Missing old-main support is refused; no name alias, fake native flag or legacy conversion is supplied. Empty source-request lists should remain in the other owner's existing non-quest path. The128-request cap is a bounded serialization/transaction guard, not a new source cost or gameplay rule.

At integration main00b84cfe19c05e01d30208384bf7fbcc4ae6bbf2, the exact existing dependencies match this worker byte-for-byte: OWN blob708c5816f59464427a08e085adb569160c18b740, quest_service b7dd0ea22b16df056480c0522f3edf6b94ef2595 and old held consumer8bd5580ce8ac3a34e17d279aa82ea3a2ce7398ab. The delta therefore needs the new module plus the small held-consumer call bridge, not an entire old branch or replacement engine. Another active owner's branch/files must not be overwritten.

The existing real238 held consumer is already wired to this ABI. Actual quest-produced potion ownership -> selected partial debit -> original effect -> source ledger -> confirmed save/failure/uncertain result/reconnect passed. Batch tests also use genuinely issued same-name material313 records and validate selected IDs, totals, immutable grants, stale/lock/tamper/wrong history, first-proof preservation across owners, failure and reconnect, including full consumption to zero with physical deletion, the fully-used immutable receipt, failure preservation and reconnect. The batch save is explicitly ownership-layer QA, not a completed265 processing operation. 2236 focused assertions passed, including repeated unchanged-object assertions. Additional historical guards were separately verified on actual partially consumed state. Core and resource integrity passed. No whole/manual CI, source/pack upload, other-branch/main merge, original UI,264, honing or218 change was performed.
