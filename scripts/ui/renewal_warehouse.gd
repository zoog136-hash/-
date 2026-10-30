extends VBoxContainer
# Shop-style local UI. World owns transaction validation and persistence.
const UI = preload("res://scripts/ui/renewal_theme.gd")
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
	listing.add_item(label,UI.item_icon(record,item_name,hud.lineage_inventory_ui.item_image_index.get("아이템",{})))

func _refresh() -> void:
	listing.clear()
	entries.clear()
	selected_index = -1
	var is_deposit: bool = mode.selected == 0
	var storage: Object = world.get("warehouse")
	var stacks: Dictionary = storage.get("stacks")
	var physical: Dictionary = world.get("item_instances") if is_deposit else storage.get("instances")
	var amounts: Dictionary = world.get("inventory") if is_deposit else stacks
	var names: Array = amounts.keys()
	names.sort()
	for raw_name: Variant in names:
		var item_name: String = str(raw_name)
		var count: int = int(amounts[raw_name])
		if count <= 0 or item_name == "아데나":
			continue
		if not _is_equipment(item_name):
			_add_entry(item_name, count)
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
			_add_entry(item_name,1,id,"+%d" % int(entry.get("level",0)))
	action.disabled = entries.is_empty()
	summary.text = "보관하기: 장착 장비 제외 · 찾기: 무게 제한 적용 · 모든 변경은 자동 저장"
	if not entries.is_empty():
		listing.select(0)
		_selected(0)
	transfer_sheet.refresh({},true)

func _selected(index: int) -> void:
	if index < 0 or index >= entries.size():
		return
	selected_index = index
	var entry: Dictionary = entries[index]
	var is_physical: bool = str(entry.get("instance_id","")) != ""
	quantity.max_value = 1 if is_physical else mini(99,int(entry.get("count",1)))
	quantity.value = 1
	transfer_sheet.refresh()

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
	var parts: PackedStringArray = reference.split("@@@")
	var item: String = parts[0]
	var id: String = parts[1] if parts.size() == 2 else ""
	if not id.is_empty() and world._is_instance_equipped(id):
		hud.show_message("장착을 해제한 뒤 보관하세요")
		return
	var count: int = 1 if not id.is_empty() else mini(99,int(world.inventory.get(item,0)))
	if count <= 0: return
	hud.confirm_action("창고 보관",item+"\n보관할 수량을 선택하세요","보관",func(amount: int) -> void:
		hud.warehouse_transfer_requested.emit(item,amount,"deposit",id),count)

func request_withdraw(reference: String) -> void:
	var parts: PackedStringArray = reference.split("@@@")
	var item: String = parts[0]
	var id: String = parts[1] if parts.size() == 2 else ""
	if not id.is_empty() and (not world.warehouse.instances.has(id) or world.warehouse.instances[id].get("name","") != item): return
	var count: int = 1 if not id.is_empty() else mini(99,int(world.warehouse.stacks.get(item,0)))
	if count <= 0: return
	hud.confirm_action("창고 찾기",item+"\n찾을 수량을 선택하세요","찾기",func(amount: int) -> void:
		hud.warehouse_transfer_requested.emit(item,amount,"withdraw",id),count)
