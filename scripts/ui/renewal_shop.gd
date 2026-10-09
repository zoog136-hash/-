extends VBoxContainer

# UI-only shop adapter: all payments go through the original shop signal.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Browser = preload("res://scripts/ui/renewal_browser.gd")
const GOODS = [
	["HP 물약", 50, "물약"],
	["강력 HP 물약", 180, "물약"],
	["축복받은 HP 물약", 450, "물약"],
	["초록 잎", 100, "소모품"],
	["드래곤의 루비", 15000, "소모품"], # TWILIGHT local economy, not an official shop price
	["드래곤의 사파이어", 25000, "소모품"],
	["드래곤의 다이아몬드", 50000, "소모품"],
	["드래곤의 고급 다이아몬드", 250000, "소모품"],
	["드래곤의 성수", 600000, "소모품"],
	["드래곤의 용옥", 1000000, "소모품"], # 2021 Adena purchase reference
	["무기 마법 주문서 (각인)", 25000, "강화 주문서"],
	["갑옷 마법 주문서 (각인)", 18000, "강화 주문서"],
	["장신구 마법 주문서 (각인)", 35000, "강화 주문서"],
	["축복 부여 주문서 (각인)", 250000, "강화 주문서"],
	["축복받은 무기 마법 주문서 (각인)", 120000, "강화 주문서"],
	["축복받은 갑옷 마법 주문서 (각인)", 90000, "강화 주문서"],
	["장인의 무기 마법 주문서 (각인)", 350000, "강화 주문서"],
	["장인의 갑옷 마법 주문서 (각인)", 300000, "강화 주문서"],
	["오림의 장신구 마법 주문서 (각인)", 150000, "강화 주문서"],
	["축복받은 오림의 장신구 마법 주문서 (각인)", 450000, "강화 주문서"]
]

var hud: Node
var wallet: Label
var search_field: LineEdit
var category_filter: OptionButton
var listing: ItemList
var detail: RichTextLabel
var purchase: Button
var filtered: Array = []
var selected: Array = []
var list_touch_index: int = -1
var list_touch_travel: float = 0.0
var list_touch_dragging: bool = false
var list_mouse_dragging: bool = false
var list_mouse_travel: float = 0.0

func configure(controller: Node) -> void:
	hud = controller
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(UI.section("ADEN  /  잡화 상점",16))
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
	for name: String in ["전체","물약","소모품","강화 주문서"]:
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
	purchase = UI.button("상품 선택",_buy,Vector2(0,54))
	purchase.name = "ShopBuy"
	side.add_child(purchase)
	side.add_child(UI.section("상품을 선택한 후 구매하세요.",11))
	row.configure(listing,side,278)
	_refresh()

func _refresh() -> void:
	filtered.clear()
	listing.clear()
	selected.clear()
	wallet.text = "보유 아데나  %d" % int(hud.character_state.get("gold",0))
	var query := search_field.text.strip_edges().to_lower()
	var category := category_filter.get_item_text(category_filter.selected)
	for entry: Array in GOODS:
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
	selected = filtered[index]
	var name := str(selected[0])
	var price := int(selected[1])
	var available := int(hud.character_state.get("gold",0))
	var info: Dictionary = {}
	for record: Variant in hud.catalog_data.get("아이템",[]):
		if record is Dictionary and str(record.get("name","")) == name:
			info = record
			break
	var count := int(hud.lineage_inventory_ui.inventory.get(name,0))
	detail.text = "[color=#d8b878][font_size=22]%s[/font_size][/color]\n%s\n\n가격: %d 아데나\n보유 수량: %d\n보유 아데나: %d\n\n%s" % [
		UI.safe(name), UI.safe(selected[2]), price, count, available,
		UI.safe(info.get("desc",info.get("description","기존 게임 데이터의 소모품 / 강화 주문서")))
	]
	purchase.disabled = available < price
	purchase.text = "아데나 부족" if available < price else "1개 구매 · %d 아데나" % price

func _buy() -> void:
	if selected.is_empty(): return
	var name := str(selected[0])
	var price := int(selected[1])
	if price > 0 and int(hud.character_state.get("gold",0)) >= price:
		hud.shop_buy_requested.emit(name,price)
