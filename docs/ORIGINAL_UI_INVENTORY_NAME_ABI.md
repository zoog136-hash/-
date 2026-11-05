# Original timed inventory name header

Existing native inventory selection called the existing bag name hint, but
that owner checked its hidden legacy slot and immediately removed the hint.
The owner now receives the actual native slot Control and original ScrollView
input bounds by physical item reference. It retains its own selection,
formatted name and five-second deadline. No new timer, item lookup, sorting,
use action or selected-reference construction is added.

`source_main_inventory_view.name_hint_context(reference)` supplies actual
controls from the existing committed native presentation. The HUD forwards it
through `original_inventory_name_hint_context`. The same `_show_item_name` /
`_update_item_name` checks the live source control, existing deadline, selection
and clipping. It does not reject a valid source slot because the legacy bag is
hidden. The original name header supplies source coordinates; the old tooltip
placement calculation does not position native content.

Exact held original inputs:

| Member | SHA256 | Node/scope |
| --- | --- | --- |
| `UI/ToolTipScene.csb` | `9304dcb5730fba9a155f73a291a6e87f96768156cee972929b003386e3904a1d` | Inventory_ToolTip_Layout Project1012, authored[1008,345], hidden/alpha255 |
| `UI/ToolTip/ToolTip_HudType_Right.csb` | `7aa63b5159335c1558e9bc83f8155979b1a9bf4ee37eaed24c7e2652c392c1ce` | Title Sprite44536, name Text44160, Close956 |

The caller activates that existing parent from the owner's explicit timed-name
visibility. Name44160 consumes `bag.item_name_hint.text`. Original Close956
calls the owner's `_hide_item_name()` and does not clear selected_item. Root
transforms, title decoration, fonts and close pixels remain original; no
opening animation, fitted layout or substitute image is created. Native touch
uses the existing source-button router. Inventory close also clears this same
owner hint, while a failed unrelated controller candidate does not clear a
hint it did not own.

This is a **partial name header**, not full item details. It never calls
`open_detail` or `_activate_selected`. Full detail body contains original
attribute rows, not a generic paragraph target; source item-type text also
cannot accept the current mixed selection/lock/type label. Those attribute,
comparison, icon and action contracts remain separate. Source class-row
title40928/value40580/comparison40232 and source type42456 have not been filled
with guessed values or the existing whole detail paragraph.

Missing source header inputs preserve the existing owner behavior instead of
creating a new UI. Expired names, removed/filtered references, clipped source
slots and real detail activation clear this native header. No new tests,
execution, rendering or CI were run; the connection is unverified. The exact
combined v14 installer input is in
[NPC portrait receiver](ORIGINAL_UI_NPC_PORTRAIT_ABI.md); older packs and all
user configs/saves are preserved. No full560 or actual game-use count advances.
