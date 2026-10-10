extends VBoxContainer

# UI-only shop adapter: all payments go through the original shop signal.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Browser = preload("res://scripts/ui/renewal_browser.gd")
const SHOP_CATALOG = preload("res://scripts/shop/shop_catalog.gd")
const REVIEWED = preload("res://addons/twilight_l1j/twilight_reviewed_shops.gd")
static var selected_vendor_id: String = ""
var hud: Node
var wallet: Label
var search_field: LineEdit
var category_filter: OptionButton
var listing: ItemList
var detail: RichTextLabel
var purchase: Button
var purchase_quantity: SpinBox
var vendor_filter: OptionButton
var vendor_profiles: Array = []
var filtered: Array = []
var selected: Array = []
var list_touch_index: int = -1
var list_touch_travel: float = 0.0
var list_touch_dragging: bool = false
var list_mouse_dragging: bool = false
var list_mouse_travel: float = 0.0
# Native touches can be consumed by ItemList before its gui_input callback.
# Track taps at the regular input phase as a second selection path; never buy here.
var raw_touch_index: int = -1
var raw_touch_start: Vector2 = Vector2.ZERO
var raw_touch_travel: float = 0.0

func configure(controller: Node) -> void:
	hud = controller
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(UI.section("ADEN  /  상점",16))
	vendor_profiles = REVIEWED.profiles(hud.catalog_data.get("아이템", []))
	vendor_filter = OptionButton.new()
	vendor_filter.name = "ShopVendor"
	vendor_filter.add_item("잡화 상점")
	vendor_filter.set_item_metadata(0, "")
	var restored_index: int = 0
	for profile: Dictionary in vendor_profiles:
		vendor_filter.add_item(str(profile.name) + " · 무기 상점")
		var index: int = vendor_filter.item_count - 1
		vendor_filter.set_item_metadata(index, str(profile.source_npc_id))
		if str(profile.source_npc_id) == selected_vendor_id: restored_index = index
	vendor_filter.select(restored_index)
	selected_vendor_id = str(vendor_filter.get_item_metadata(restored_index))
	vendor_filter.item_selected.connect(_change_vendor)
	add_child(vendor_filter)
	wallet = UI.label("",15,UI.GOLD)
	add_child(wallet)
	var filters := HBoxContainer.new()
	add_child(filters)
	search_field = LineEdit.new()
	search_field.name = "ShopSearch"
	search_field.placeholder_text = "상품 이름 검색"
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_field.text_changed.connect(func(_value: String) -> void: _refresh())
	filters.add_child(search_field)
	category_filter = OptionButton.new()
	category_filter.name = "ShopCategory"
	for name: String in ["전체","물약","소모품","강화 주문서","무기"]:
		category_filter.add_item(name)
	category_filter.item_selected.connect(func(_index: int) -> void: _refresh())
	filters.add_child(category_filter)
	var row := Browser.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	listing = ItemList.new()
	listing.name = "ShopItems"
	listing.icon_mode = ItemList.ICON_MODE_TOP
	listing.fixed_icon_size = Vector2i(48,48)
	listing.max_columns = 3
	listing.fixed_column_width = 142
	listing.same_column_width = true
	listing.max_text_lines = 3
	listing.add_theme_font_size_override("font_size",12)
	listing.add_theme_constant_override("v_separation",10)
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(_select)
	listing.gui_input.connect(_on_listing_input)
	row.add_child(listing)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 315
	row.add_child(side)
	side.add_child(UI.label("선택한 상품",18,UI.GOLD))
	detail = UI.rich("")
	detail.fit_content = false
	detail.scroll_active = true
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(detail)
	var amount_row := HBoxContainer.new()
	side.add_child(amount_row)
	amount_row.add_child(UI.label("구매 수량",14,UI.TEXT))
	purchase_quantity = SpinBox.new()
	purchase_quantity.name = "ShopQuantity"
	purchase_quantity.min_value = 1
	purchase_quantity.max_value = SHOP_CATALOG.MAX_QUANTITY
	purchase_quantity.step = 1
	purchase_quantity.value = 1
	purchase_quantity.max_value = SHOP_CATALOG.MAX_QUANTITY if selected_vendor_id.is_empty() else 1
	purchase_quantity.editable = selected_vendor_id.is_empty()
	purchase_quantity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	purchase_quantity.value_changed.connect(func(_value: float) -> void: _refresh_selection())
	amount_row.add_child(purchase_quantity)
	purchase = UI.button("상품 선택",_buy,Vector2(0,54))
	purchase.name = "ShopBuy"
	side.add_child(purchase)
	side.add_child(UI.section("상품을 선택한 후 구매하세요.",11))
	row.configure(listing,side,278)
	_refresh()

func _refresh() -> void:
	filtered.clear()
	listing.clear()
	selected = []
	wallet.text = "보유 아데나  %d" % int(hud.character_state.get("gold",0))
	var query := search_field.text.strip_edges().to_lower()
	var category := category_filter.get_item_text(category_filter.selected)
	for entry: Array in _goods():
		var name := str(entry[0])
		if category != "전체" and str(entry[2]) != category: continue
		if query != "" and not name.to_lower().contains(query): continue
		filtered.append(entry)
		var count: int = int(hud.lineage_inventory_ui.inventory.get(name,0))
		listing.add_item("%s\n%d 아데나\n보유 %d" % [name,int(entry[1]),count],UI.item_icon(hud.lineage_inventory_ui._find_item_record(name),name,hud.item_image_index.get("아이템",{})))
	if filtered.is_empty():
		detail.text = "검색 조건에 맞는 상품이 없습니다."
		purchase.disabled = true
	else:
		listing.select(0)
		_select(0)

func _change_vendor(index: int) -> void:
	selected_vendor_id = str(vendor_filter.get_item_metadata(index))
	search_field.text = ""
	category_filter.select(0)
	purchase_quantity.value = 1
	purchase_quantity.max_value = SHOP_CATALOG.MAX_QUANTITY if selected_vendor_id.is_empty() else 1
	purchase_quantity.editable = selected_vendor_id.is_empty()
	_refresh()

func _goods() -> Array:
	if selected_vendor_id.is_empty(): return SHOP_CATALOG.GOODS.duplicate(true)
	var result: Array = []
	for profile: Dictionary in vendor_profiles:
		if str(profile.source_npc_id) != selected_vendor_id: continue
		for offer: Dictionary in profile.goods:
			result.append([str(offer.game_name), int(offer.price), str(offer.category)])
	return result

func _raw_touch_local(point: Vector2) -> Vector2:
	return listing.get_global_transform_with_canvas().affine_inverse() * point

func _input(event: InputEvent) -> void:
	if listing == null or not is_visible_in_tree() or not listing.visible:
		raw_touch_index = -1
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.device == InputEvent.DEVICE_ID_EMULATION: return
		if touch.pressed and not touch.canceled and raw_touch_index == -1:
			var local: Vector2 = _raw_touch_local(touch.position)
			if Rect2(Vector2.ZERO, listing.size).has_point(local):
				raw_touch_index = touch.index
				raw_touch_start = touch.position
				raw_touch_travel = 0.0
		elif touch.index == raw_touch_index and (not touch.pressed or touch.canceled):
			var local: Vector2 = _raw_touch_local(touch.position)
			var is_tap: bool = not touch.canceled and raw_touch_travel < 12.0 and raw_touch_start.distance_to(touch.position) < 18.0
			raw_touch_index = -1
			if is_tap and Rect2(Vector2.ZERO, listing.size).has_point(local):
				_select_at_position(local)
	elif event is InputEventScreenDrag and event.index == raw_touch_index:
		raw_touch_travel += event.relative.length()

# ItemList mouse selection works in the editor but a native Android
# InputEventScreenTouch does not necessarily emit item_selected. Treat a tap
# as a selection and a swipe as scrolling, never as an item purchase.
func _select_at_position(local_point: Vector2) -> void:
	var index: int = listing.get_item_at_position(local_point,true)
	if index >= 0 and index < filtered.size():
		listing.select(index)
		_select(index)

func _scroll_listing(delta_y: float) -> void:
	var bar: VScrollBar = listing.get_v_scroll_bar()
	if bar != null:
		bar.value = clampf(bar.value-delta_y,bar.min_value,maxf(bar.min_value,bar.max_value-bar.page))

func _on_listing_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and not touch.canceled and list_touch_index == -1:
			list_touch_index = touch.index
			list_touch_travel = 0.0
			list_touch_dragging = false
		elif (not touch.pressed or touch.canceled) and touch.index == list_touch_index:
			if not touch.canceled and not list_touch_dragging:
				_select_at_position(touch.position)
			list_touch_index = -1
			listing.accept_event()
	elif event is InputEventScreenDrag and event.index == list_touch_index:
		var drag: InputEventScreenDrag = event
		list_touch_travel += absf(drag.relative.y)
		if list_touch_travel > 8.0:
			list_touch_dragging = true
			_scroll_listing(drag.relative.y)
			listing.accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			list_mouse_dragging = true
			list_mouse_travel = 0.0
		else:
			if list_mouse_dragging and list_mouse_travel <= 8.0:
				_select_at_position(event.position)
			list_mouse_dragging = false
	elif event is InputEventMouseMotion and list_mouse_dragging and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		list_mouse_travel += absf(event.relative.y)
		if list_mouse_travel > 8.0:
			_scroll_listing(event.relative.y)
			listing.accept_event()

func _select(index: int) -> void:
	if index < 0 or index >= filtered.size(): return
	selected = filtered[index].duplicate(true)
	_refresh_selection()

func _refresh_selection() -> void:
	if selected.is_empty() or purchase_quantity == null: return
	var name: String = str(selected[0])
	var price: int = SHOP_CATALOG.price_for(name)
	if not selected_vendor_id.is_empty():
		var offer: Dictionary = REVIEWED.offer_for(selected_vendor_id, name, hud.catalog_data.get("아이템", []))
		price = int(offer.get("price", -1))
	var quantity: int = int(purchase_quantity.value)
	var available: int = int(hud.character_state.get("gold",0))
	var info: Dictionary = {}
	for record: Variant in hud.catalog_data.get("아이템",[]):
		if record is Dictionary and str(record.get("name","")) == name:
			info = record
			break
	var count: int = int(hud.lineage_inventory_ui.inventory.get(name,0))
	var total: int = maxi(0, price) * quantity
	detail.text = "[color=#d8b878][font_size=22]%s[/font_size][/color]\n%s\n\n단가: %d 아데나\n수량: %d개\n합계: %d 아데나\n보유: %d개\n아데나: %d\n\n%s" % [
		UI.safe(name), UI.safe(selected[2]), price, quantity, total, count, available,
		UI.safe(info.get("desc",info.get("description","기존 게임 데이터의 소모품 / 강화 주문서")))
	]
	if not selected_vendor_id.is_empty():
		detail.text += "\n\n기본 판매가 · 1개 · 강화 +0 · 세금 없음"
	purchase.disabled = price <= 0 or available < total or (name == "드래곤의 용옥" and quantity != 1)
	purchase.text = "구매 불가" if purchase.disabled else "%d개 구매 · %d 아데나" % [quantity,total]

func _buy() -> void:
	if selected.is_empty(): return
	var name: String = str(selected[0])
	var quantity: int = int(purchase_quantity.value)
	# Never send a payment amount from the UI. World rechecks the price, stock
	# rules, wallet, weight and special consumable restrictions atomically.
	if not selected_vendor_id.is_empty() and hud.has_signal("reviewed_shop_buy_requested"):
		hud.emit_signal("reviewed_shop_buy_requested", selected_vendor_id, name, quantity)
	elif hud.has_signal("shop_bulk_buy_requested"):
		hud.emit_signal("shop_bulk_buy_requested", name, quantity)
