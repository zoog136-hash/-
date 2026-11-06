# Original warehouse batch receiver boundary

Read-only handoff to the transaction/integration owner; no batch execution or UI action binding is implemented here. Existing single transfers remain unchanged.

Source parent: UI/StorageScene.csb SHA0df424e7ed29a314e112ef618d40f89806c9df6ad6ce56df7dedd5e08e9ebde7 Project132 -> UI/Storage/Storage_All.csb SHAeb4ddfa71dc9be978fd03948ff938c12e2366f6542ff5844509c47f110b38328. In the latter original:

- Button43992 Node/Btn_Confirm_On, Text44324 Label = `모두 찾기`; widget position[0,-268.9999084472656], size[204,49], anchor[.5,.5], visible1/alpha255.
- Button42648 Node/Btn_Sell_On, Text42980 Label = `모두 맡기기`; position[0,-268.9997863769531], same extent/anchor/visibility.
- Both have empty callBackType/callBackName. Original Fx_Btn_Activation Projects44044/42700 are actual button descendants, not new effects. Parent Inventory46840 and Cart46564 are separate declared components; the labels do not by themselves establish whether all means the source cart, current displayed eligible list or entire holdings. Neither both-visible defaults nor button names define a runtime mode sequence.

Actual current host: renewal_warehouse.gd `_transfer()` captures exactly one `entries[selected_index]`, quantity.value, mode deposit/withdraw, then confirm_action and `hud.warehouse_transfer_requested(item,count,direction,id)`. `world.gd::_warehouse_transfer(item_name,quantity,direction,instance_id)` is the actual existing receiver. It guards1..99, current lock/storable/native-instance rules, stages inventory/instances/warehouse, and owns persistence. UI must not bypass it, duplicate those rules, loop the single action while calling it an atomic batch, silently split quantities or treat partial saves as one transaction.

Required integration receiver: accept an explicit authoritative caller batch of exact source/physical identities and quantities, plus actual direction, and expose its existing quote/confirmation/result/save-failure contract. The integration owner must define atomicity/revalidation/save handling. UI also needs the real batch/cart owner and its selected entries; source labels alone do not authorize inventing all-of-inventory selection or ordering. No signature for such an API is fabricated here. Once the actual receiver/model exists, the UI owner can bind the original43992/42648 nodes with those precise capabilities and preserve their source parent geometry.

This boundary is independent of the newly implemented ordinary-enhancement slot host adapter. It changes no prices, ownership, warehouse99 limit, source files, candidates, phone, saves or settings. No tests, parser checks, compile, game, render, CI, publication or merge was run.
