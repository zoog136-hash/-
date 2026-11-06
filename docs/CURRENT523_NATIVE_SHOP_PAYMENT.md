# Current-source physical shop payment — local follow-up

Status: implementation only, untested. No compilation, game, rendering or CI was run. This candidate is not a published PR281 change.

The existing market and NPC purchase paths resolve an original Unit4 ItemClass payment (including an existing Currency source) to an admitted current523 original DTO. Wallet balances, specialized awakening receipts, equipment costs, raw quest stacks and intangible owners retain their existing separate contracts. No original price, quantity, save identity or ownership is converted.

`_native_payment_snapshot(record, amount)` selects actual generic native physical receipts, preserving source archive, full original ItemClass, normal blessing and granted-versus-remaining proof. Locked, equipped and selected ammunition objects cannot fund payment. Mixed ownership under the same key and competing funded legacy origins are held. Physical-ID sorting is explicitly a TWILIGHT custody policy, not a native spending priority. Missing/invalid proof cannot fall through a Currency source to another payment owner.

`_prepare_native_payment(binding, token)` uses the existing `current523_native_stack.stage_debit` five-field selected-ownership API. Purchase creates a pending order with immutable selected receipts and consumed amounts. `_commit(..., extra, owned_payment)` re-resolves the source payment and stages the exact debit again against live ownership. It accepts only the identical inventory, physical objects and consumption-ledger candidate, then saves those fields with the order and purchase counter once. The private payment argument cannot be combined with ticket-effect extra fields.

Live consumable state and balances are adopted only after the existing save returns OK. An error retains the existing shop save-blocked/reload requirement because disk outcome may be uncertain. Claiming the paid order remains a separate existing receiving transaction; no second payment debit is added. Historical orders lacking the new `payment_native_inputs` field are preserved.

No new UI, artwork, source packs, transfer, remote branch update or merge is included. The preserved full local candidate remains 8eba68ea3027911fc64bc750a85cf4225f7d39bb; the prior rejected 40f3ad24 ref publication has not been retried.
