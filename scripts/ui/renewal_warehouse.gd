extends VBoxContainer
# Shop-style local UI. World owns transaction validation and persistence.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const AutoInventory = preload("res://scripts/ui/renewal_auto_inventory.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
var auto_controls
const TransferSheet=preload("res://scripts/ui/transfer_detail_sheet.gd")
var transfer_sheet: RefCounted
var hud: Node
var world: Node
var mode: OptionButton
var listing: ItemList
var quantity: SpinBox
var action: Button
var summary: Label
var entries: Array[Dictionary] = []
var selected_index: int = -1

func configure(controller: Node) -> void:
	hud = controller
	world = hud.get_parent()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var heading := Label.new()
	heading.text = "창고 보관 / 찾기"
	add_child(heading)
	var row := HBoxContainer.new()
	add_child(row)
	mode = OptionButton.new()
	mode.name = "WarehouseMode"
	mode.add_item("보관")
	mode.add_item("찾기")
	mode.item_selected.connect(func(_index: int) -> void: _refresh())
	row.add_child(mode)
	quantity = SpinBox.new()
	quantity.name = "WarehouseQuantity"
	quantity.min_value = 1
	quantity.max_value = 99
	quantity.step = 1
	quantity.value = 1
	quantity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(quantity)
	action = UI.button("선택 아이템 이동",Callable())
	action.name = "WarehouseTransfer"
	action.text = "선택 아이템 이동"
	UI.primary_button(action)
	action.pressed.connect(_transfer)
	listing = ItemList.new()
	listing.set_script(preload("res://scripts/ui/native_touch_list.gd"))
	listing.name = "WarehouseItems"
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.fixed_icon_size = Vector2i(32,32)
	listing.item_selected.connect(_selected)
	add_child(listing)
	add_child(action)
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size",12)
	add_child(summary)
	transfer_sheet=TransferSheet.new();transfer_sheet.bind(self,true)
	_refresh()
	auto_controls = AutoInventory.new()
	add_child(auto_controls)
	auto_controls.configure(self,"deposit")

func _is_equipment(item_name: String) -> bool:
	var record: Dictionary = world.call("_find_catalog_item_record", item_name)
	if record.is_empty():
		return false
	return str(world.call("_enhancement_kind_for_record", record)) != ""

func _add_entry(item_name: String, count: int, instance_id: String = "", description: String = "") -> void:
	entries.append({"name":item_name,"count":count,"instance_id":instance_id})
	var label: String = item_name + (" · " + description if description != "" else "") + "  ×" + str(count)
	var record: Dictionary = world._find_catalog_item_record(item_name)
	var physical: Dictionary = world.item_instances if mode.selected == 0 else world.warehouse.instances
	if not instance_id.is_empty() and physical.has(instance_id): record = physical[instance_id].get("record",record)
	# Carry the same authoritative record into the existing selection picture.
	# Reconstructing it from the label would lose native source identity.
	entries[entries.size()-1]["record"] = record.duplicate(true)
	listing.add_item(label,UI.item_icon(record,item_name,hud.lineage_inventory_ui.item_image_index.get("아이템",{})))

## The rows the transfer list shows: bag rows to deposit (deposit) or
## warehouse rows to withdraw, one row per physical equipment instance.
## The original storage window (source_main_storage_window) lists the same.
func rows_for(is_deposit: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	var storage: Object = world.get("warehouse")
	var stacks: Dictionary = storage.get("stacks")
	var physical: Dictionary = world.get("item_instances") if is_deposit else storage.get("instances")
	var amounts: Dictionary = world.get("inventory") if is_deposit else stacks
	var receipt_ids: Dictionary = {}
	for id: String in physical:
		var entry: Variant = physical[id]
		if entry is Dictionary and entry.has(STACK.RECEIPT):
			var name_value: String = str(entry.get("name", ""))
			if not receipt_ids.has(name_value): receipt_ids[name_value] = []
			(receipt_ids[name_value] as Array).append(id)
	var names: Array = amounts.keys()
	names.sort()
	for raw_name: Variant in names:
		var item_name: String = str(raw_name)
		var count: int = int(amounts[raw_name])
		if count <= 0 or item_name == "아데나":
			continue
		var source_record: Dictionary = world._find_catalog_item_record(item_name)
		if is_deposit and source_record.has("growth96_item_id") and not bool(source_record.get("storable",false)): continue
		if receipt_ids.has(item_name):
			var owned_ids: Array = receipt_ids[item_name]
			owned_ids.sort()
			for id: String in owned_ids:
				var owned: Dictionary = STACK.proof_entry(physical[id], id)
				if owned.is_empty() or physical[id].has(STACK.TOKEN_RANK): continue
				if is_deposit and (not STACK.warehouse_storable(owned) or world._is_instance_equipped(id)): continue
				rows.append({"name":item_name,"count":int(owned.remaining),"instance_id":id,"description":"","native_stack":true})
			continue # An aggregate row cannot debit a receipt-owned stack.
		if is_deposit and not preload("res://scripts/cards/source_awakening_items.gd").storage_allowed(item_name,source_record,physical):continue
		if not _is_equipment(item_name) and not preload("res://scripts/cards/source_awakening_items.gd").has_physical_item(item_name,physical):
			rows.append({"name":item_name,"count":count,"instance_id":"","description":""})
			continue
		var ids: Array[String] = []
		for raw_id: Variant in physical.keys():
			var id: String = str(raw_id)
			var entry: Variant = physical[raw_id]
			if not (entry is Dictionary):
				continue
			if str((entry as Dictionary).get("name", "")) != item_name:
				continue
			if is_deposit and bool(world.call("_is_instance_equipped", id)):
				continue
			ids.append(id)
		ids.sort()
		for id: String in ids:
			var entry: Dictionary = physical[id]
			rows.append({"name":item_name,"count":1,"instance_id":id,"description":"+%d" % int(entry.get("level",0)),"level":int(entry.get("level",0))})
	return rows

func _refresh() -> void:
	listing.clear()
	entries.clear()
	selected_index = -1
	for row: Dictionary in rows_for(mode.selected == 0):
		_add_entry(str(row.name),int(row.count),str(row.instance_id),str(row.description))
		entries[-1]["native_stack"] = row.get("native_stack", false)
	action.disabled = entries.is_empty()
	summary.text = "보관하기: 장착 장비 제외 · 찾기: 무게 제한 적용 · 모든 변경은 자동 저장"
	if not entries.is_empty():
		listing.select(0)
		_selected(0)
	transfer_sheet.refresh({},true)
	if auto_controls != null: auto_controls.refresh()

func _selected(index: int) -> void:
	if index < 0 or index >= entries.size():
		return
	selected_index = index
	var entry: Dictionary = entries[index]
	quantity.max_value = mini(99,int(entry.get("count",1)))
	quantity.value = 1
	transfer_sheet.refresh()
	if auto_controls != null: auto_controls.refresh()

func _transfer() -> void:
	if selected_index < 0 or selected_index >= entries.size():
		return
	var entry: Dictionary = entries[selected_index]
	var direction: String = "deposit" if mode.selected == 0 else "withdraw"
	var count: int = int(quantity.value)
	if count < 1 or count > int(entry.get("count",0)):
		return
	var item: String = str(entry["name"])
	var id: String = str(entry.get("instance_id",""))
	hud.confirm_action("보관 확인" if direction == "deposit" else "찾기 확인","%s ×%d" % [item,count],"이동",func(_amount: int) -> void:
		hud.emit_signal("warehouse_transfer_requested",item,count,direction,id))

func request_drop(reference: String) -> void:
	_request_slot_transfer(reference,true)

func request_withdraw(reference: String) -> void:
	_request_slot_transfer(reference,false)

func _request_slot_transfer(reference: String, deposit: bool) -> void:
	var item: String=reference.get_slice("@@@",0)
	var id: String=reference.get_slice("@@@",1)
	if deposit and not id.is_empty() and world._is_instance_equipped(id):
		hud.show_message("장착을 해제한 뒤 보관하세요")
		return
	var count: int=_transfer_limit(item,id,deposit)
	if count <= 0: return
	var direction: String="deposit" if deposit else "withdraw"
	var transfer: Callable=func(amount: int) -> void:
		hud.warehouse_transfer_requested.emit(item,amount,direction,id)
	var controller: Variant=hud.get("original_main_ui_controller")
	if is_instance_valid(controller) and controller.storage_window_is_open():
		var instances: Dictionary=world.item_instances if deposit else world.warehouse.instances
		var record: Dictionary=instances.get(id,{}).get("record",{})
		if record.is_empty():record=world._find_catalog_item_record(item)
		var identity=preload("res://scripts/ui/source523_item_identity.gd")
		var can_confirm: Callable=func() -> bool: return is_instance_valid(world) and not world.background_save_pending()
		var original: Dictionary=controller.try_open_storage_transfer(identity.clean_message(item),int(record.get("source_item_class_id",0)),count,transfer,direction,can_confirm)
		if not original.get("handled",false) and not controller.drop_confirm_is_open():
			hud._report_original_window_unavailable("창고 이동 확인",original)
		return
	var action: String="보관" if deposit else "찾기"
	var instructions: String="보관할 수량을 선택하세요" if deposit else "찾을 수량을 선택하세요"
	hud.confirm_action("창고 "+action,item+"\n"+instructions,action,transfer,count)

func _transfer_limit(item: String, id: String, deposit: bool) -> int:
	var amounts: Dictionary = world.inventory if deposit else world.warehouse.stacks
	if id.is_empty(): return mini(99,int(amounts.get(item,0)))
	var instances: Dictionary = world.item_instances if deposit else world.warehouse.instances
	var entry: Dictionary = instances.get(id,{})
	if entry.get("name") != item: return 0
	if not entry.has(STACK.RECEIPT): return 1
	return mini(99, int(STACK.proof_entry(entry,id).get("remaining",0)))
