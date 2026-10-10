extends VBoxContainer
# Shop-style local UI. World owns transaction validation and persistence.
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
	heading.text = "아덴 창고 · 장비 강화/속성/개체 ID 보존"
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
	action = Button.new()
	action.name = "WarehouseTransfer"
	action.text = "선택 아이템 이동"
	action.pressed.connect(_transfer)
	row.add_child(action)
	listing = ItemList.new()
	listing.name = "WarehouseItems"
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(_selected)
	add_child(listing)
	summary = Label.new()
	add_child(summary)
	_refresh()

func _is_equipment(item_name: String) -> bool:
	var record: Dictionary = world.call("_find_catalog_item_record", item_name)
	if record.is_empty():
		return false
	return str(world.call("_enhancement_kind_for_record", record)) != ""

func _add_entry(item_name: String, count: int, instance_id: String = "", description: String = "") -> void:
	entries.append({"name":item_name,"count":count,"instance_id":instance_id})
	var label: String = item_name + (" · " + description if description != "" else "") + "  ×" + str(count)
	listing.add_item(label)

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
			_add_entry(item_name, 1, id, "+%d · #%s" % [int(entry.get("level",0)),id])
	action.disabled = entries.is_empty()
	summary.text = "보관하기: 장착 장비 제외 · 찾기: 무게 제한 적용 · 모든 변경은 자동 저장"
	if not entries.is_empty():
		listing.select(0)
		_selected(0)

func _selected(index: int) -> void:
	if index < 0 or index >= entries.size():
		return
	selected_index = index
	var entry: Dictionary = entries[index]
	var is_physical: bool = str(entry.get("instance_id","")) != ""
	quantity.max_value = 1 if is_physical else mini(99,int(entry.get("count",1)))
	quantity.value = 1

func _transfer() -> void:
	if selected_index < 0 or selected_index >= entries.size():
		return
	var entry: Dictionary = entries[selected_index]
	var direction: String = "deposit" if mode.selected == 0 else "withdraw"
	var count: int = int(quantity.value)
	if count < 1 or count > int(entry.get("count",0)):
		return
	if hud.has_signal("warehouse_transfer_requested"):
		hud.emit_signal("warehouse_transfer_requested",str(entry["name"]),count,direction,str(entry.get("instance_id","")))
