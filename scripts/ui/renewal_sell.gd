extends VBoxContainer
const UI = preload("res://scripts/ui/renewal_theme.gd")
const TransferSheet=preload("res://scripts/ui/transfer_detail_sheet.gd")
var transfer_sheet: RefCounted
const BUYBACK = preload("res://scripts/shop/local_buyback.gd")
var hud: Node
var world: Node
var search: LineEdit
var category: OptionButton
var listing: ItemList
var quantity: SpinBox
var details: Label
var action: Button
var entries: Array[Dictionary] = []
var selected: int = -1

func configure(controller: Node) -> void:
	hud = controller
	world = hud.get_parent()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "판매할 아이템을 선택하세요"
	add_child(title)
	var filters := HBoxContainer.new()
	add_child(filters)
	search = LineEdit.new()
	search.name = "SellSearch"
	search.placeholder_text = "매입 아이템 검색"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_query: String) -> void: _refresh())
	filters.add_child(search)
	category = OptionButton.new()
	category.name = "SellCategory"
	for name: String in ["전체","장비","소모품"]:
		category.add_item(name)
	category.item_selected.connect(func(_index: int) -> void: _refresh())
	filters.add_child(category)
	listing = ItemList.new()
	listing.set_script(preload("res://scripts/ui/native_touch_list.gd"))
	listing.name = "SellInventory"
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(_select)
	add_child(listing)
	var row := HBoxContainer.new()
	add_child(row)
	quantity = SpinBox.new()
	quantity.name = "SellQuantity"
	quantity.min_value = 1
	quantity.max_value = 99
	quantity.step = 1
	quantity.value = 1
	quantity.value_changed.connect(func(_value: float) -> void: _quote())
	row.add_child(quantity)
	action = UI.button("판매",Callable())
	action.name = "SellConfirm"
	action.text = "판매"
	UI.primary_button(action)
	action.pressed.connect(_sell)
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(action)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(details)
	transfer_sheet=TransferSheet.new();transfer_sheet.bind(self,false)
	_refresh()

func _refresh() -> void:
	listing.clear()
	entries.clear()
	selected = -1
	var inventory: Dictionary = world.get("inventory")
	var instances: Dictionary = world.get("item_instances")
	var source: Dictionary = (world.get("loot_catalog") as Dictionary).get("by_name",{})
	var names: Array = inventory.keys()
	names.sort()
	var filter_kind: String = category.get_item_text(category.selected)
	var query: String = search.text.strip_edges().to_lower()
	for raw_name: Variant in names:
		var name: String = str(raw_name)
		var count: int = int(inventory[raw_name])
		if count <= 0 or not source.has(name):
			continue
		if query != "" and not name.to_lower().contains(query):
			continue
		var record: Dictionary = source[name]
		var equipment: bool = str(record.get("slot","")) not in ["","currency","consumable"]
		if filter_kind == "장비" and not equipment:
			continue
		if filter_kind == "소모품" and equipment:
			continue
		if not equipment:
			_add_item(name,count,"","×%d" % count)
		else:
			var ids: Array[String] = []
			for raw_id: Variant in instances.keys():
				var id: String = str(raw_id)
				var value: Variant = instances[raw_id]
				if value is Dictionary and str((value as Dictionary).get("name","")) == name:
					if not bool(world.call("_is_instance_equipped",id)):
						ids.append(id)
			ids.sort()
			for id: String in ids:
				_add_item(name,1,id,"+%d" % int((instances[id] as Dictionary).get("level",0)))
	action.disabled = entries.is_empty()
	if not entries.is_empty():
		listing.select(0)
		_select(0)
	transfer_sheet.refresh({},true)

func _add_item(name: String, count: int, instance_id: String, suffix: String) -> void:
	entries.append({"name":name,"count":count,"instance_id":instance_id})
	var records: Dictionary = (world.get("loot_catalog") as Dictionary).get("by_name",{})
	var images: Dictionary = hud.item_image_index.get("아이템",{})
	listing.add_item(name + " · " + suffix,UI.item_icon(records[name],name,images))

func _select(index: int) -> void:
	if index < 0 or index >= entries.size():
		return
	selected = index
	var entry: Dictionary = entries[index]
	quantity.max_value = 1 if str(entry.get("instance_id","")) != "" else mini(99,int(entry["count"]))
	quantity.value = 1
	_quote()

func _quote() -> void:
	if selected < 0 or selected >= entries.size():
		return
	var entry: Dictionary = entries[selected]
	var report: Dictionary = BUYBACK.quote(
		str(entry["name"]),int(quantity.value),str(entry.get("instance_id","")),
		world.get("inventory"),(world.get("loot_catalog") as Dictionary).get("by_name",{}),
		world.get("item_instances"),world.get("equipped_items"),int(world.get("gold"))
	)
	details.text = "%s · %d개\n%s" % [
		str(entry["name"]),int(quantity.value),
		"매입 총액 %d 아데나" % int(report["payment"]) if bool(report.get("ok",false)) else str(report.get("reason","매입 불가"))
	]
	action.disabled = not bool(report.get("ok",false))
	transfer_sheet.refresh(report)

func _sell() -> void:
	if selected < 0 or selected >= entries.size():
		return
	var entry: Dictionary = entries[selected]
	var item: String = str(entry["name"])
	var count: int = int(quantity.value)
	var id: String = str(entry.get("instance_id",""))
	if world._item_locked(item,id):
		hud.show_message("잠긴 아이템은 판매할 수 없습니다")
		return
	hud.confirm_action("판매 확인",item+" ×%d\n" % count+details.text,"판매",func(_amount: int) -> void:
		hud.emit_signal("shop_sell_requested",item,count,id))

func request_drop(reference: String) -> void:
	var parts: PackedStringArray = reference.split("@@@")
	var item: String = parts[0]
	var id: String = parts[1] if parts.size() == 2 else ""
	for index: int in range(entries.size()):
		if str(entries[index].name) == item and str(entries[index].get("instance_id","")) == id:
			listing.select(index)
			_select(index)
			if action.disabled or world._item_locked(item,id):
				hud.show_message("판매할 수 없는 아이템입니다")
				return
			var maximum: int = int(quantity.max_value)
			hud.confirm_action("판매 수량",item+"\n다음 화면에서 최종 판매 금액을 확인합니다","금액 확인",func(count: int) -> void:
				quantity.value = count
				_sell(),maximum)
			return
	hud.show_message("장착 중이거나 판매할 수 없는 아이템입니다")
