# Exact quest-held materials in original shop payment

Local implementation only; untested and unpublished. The existing public PR281 checkpoint is af3ec2b35c533d98f21c6fc7949291c482d86b22. The preceding local d37af099955b4a8e93311f9ce318d2c88e4af848 (flat receiver plus multi-schema2 payment) remains preserved. No tests, compilation, game, rendering, CI, uploads, resource/phone changes or merge.

## Source and custody admission

The existing market/NPC quote must already select an original Unit4 ItemClass cost (directly or as an existing original Currency source). This is permission to pay that exact cost in the existing transaction, not permission to execute the material's own use effect. The current registered DTO must be a material, match the whole original ItemClass/archive, pass existing source server/service/deletion/date holds, and not be Test/dummy. No missing DTO/identity is synthesized. Non-materials stay outside this adapter, including excluded pending potion/spell-stage/emoticon work.

`_quest_material_payment_binding(original, amount)` obtains actual raw quest-held physical IDs and authenticates each using the EXISTING `quest_reward_ownership.proof`: source SHA, claimed quest, exact RewardID/ItemClass/full source row, normal blessing, immutable original quantity and actual remaining quantity. Immediate-use rewards, invalid/mixed proof, locks, equipped or selected-ammunition units do not fund payment. Competing funded canonical/specialized/legacy custody blocks the quote; it does not silently prioritize quest ownership. Same-source raw receipts may fund one cost in ascending physical-ID order, an explicit TWILIGHT custody policy, without merging or renaming any receipt. The existing shared debit limit128 is preserved; it is not a source stack quantity.

## Existing single-save owner

`_prepare_native_payment` freshly re-resolves the quote, then `_prepare_quest_material_payment` sends the existing five fields (physical_id, quantity, expected_quantity, expected_remaining, quest_reward_receipt) to `quest_reward_consumption.stage`. The consumer-data SHA fingerprints the actual original payment/item/archive plus current shop model/input identity; it is not a claimed source archive SHA. The shared owner retains the first-consumer pack proof and increments existing item_grants.used_quantity. Its use_authorized=false is never changed into effect authority.

The pending order stores the actual per-physical payment receipts plus the returned quest consumption evidence, including quest/reward/source/quantity/current-consumer proof. `_commit` re-stages from live ownership, compares the entire prepared debit and matches_payload, then writes quest_state, inventory, item_instances, pending order and purchase counter through ONE existing `_save_game` call. No candidate is blindly merged over another debit. Output receiving/claiming remains the separate existing paid-order owner and never debits payment again.

Only confirmed save success permits journal/balance adoption. Failed/uncertain save responses block both shop and quest owner and set the existing shared owner-state reload guard. A confirmed disk save followed by failed quest-state adoption is reported saved=true with reload_required and leaves further writes blocked; it is not an unsuccessful payment eligible for retry/refund. No disk outcome, transaction success or reconnect behavior is claimed without running the prohibited execution checks.

Historical grants, names, first quantities and receipts are unchanged; no batch conversion, regrant, blessed/normal alias merge, free reward or repeat payout is added. Old orders without the new quest-payment evidence are preserved. Native generic and schema2 payment continue using their own distinct proof fields and source owners.

## Separate map receiver boundary

Read-only comparison with public PR276 6b9cfc85f4113c7d054ae5057724225f0c7bd04d shows _attach_source_population runs after the field switch, changes live monster/population roots, shares the saved boss director and invokes configure. It is not an existing target-Land pre-save population/occupancy prepare/adopt/discard receiver. PR285 owns that follow-up; this candidate does not modify map/population files or use the departure world's occupancy as destination proof.
