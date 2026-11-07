# Exact selected items in existing confirmation buttons

PR283 continues the existing item-image consumers into their final confirmation
buttons. No display controls or original layouts are created.

| Existing owner | Confirmed item's source | Existing receiver |
|---|---|---|
| Fishing cast | Selected rod ID, original rules.items ItemClass row | Shared confirmation confirm_button |
| Fishing rod purchase | Actual MerchantGoods.ItemClassID | Shared confirmation confirm_button |
| Fishing card use | Actual selected CARD_ITEMS inventory key | Shared confirmation confirm_button |
| Fishing treasure use | Actual selected bag ItemClass inventory key | Shared confirmation confirm_button |
| Expedition box opening | Selected storage row.item, full original ItemClass | Shared confirmation confirm_button |
| Expedition withdrawal | Selected storage row.item, full original ItemClass | Shared confirmation confirm_button |
| TJ retry | Actual selected coupon definition.item, full original ItemClass | This action's ConfirmationDialog OK button |

These seven call paths reuse the same original image provider already used by
their existing list/action buttons. Canonical ItemClass matching, source pack
selection, exclusions, original pixel lookup and unavailable results remain
with that provider. Missing pixels leave an empty icon; no representative
candidate or replacement artwork is chosen. Metadata retains the provider's
file identity and status without serializing Texture2D into evidence.

The shared confirmation can return another action's existing dialog. Fishing
and expedition compare its callback with this exact action before touching its
button. They retain their captured selection, quantity, revision, request token,
storage-change guard and original transaction callback. TJ uses the coupon
being spent, never a card from its multiple candidate sets. Multiple-equipment
exchange, combined expedition departure/rewards and generic item transfer are
not assigned representative icons.

This is published caller wiring, not seven observed renders or a source-file
usage percentage. No tests, compilation, game, rendering, CI, uploads or merges
were run. No resource pack or installed phone selection was changed. Pending
spell stages, potions, emoticons and sound remain excluded.
