extends VBoxContainer

# Enhancement probabilities and transactions are supplied by the world.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Browser = preload("res://scripts/ui/renewal_browser.gd")
const Stage = preload("res://scripts/ui/renewal_stage.gd")

var hud: Node
var mode: String = "scroll"
var scroll_name: String = ""
var values: Array = []
var listing: ItemList
var detail: RichTextLabel
var action: Button
var selected_index: int = -1
var preview: TextureRect

func configure_scrolls(controller: Node) -> void:
	hud = controller
	mode = "scroll"
	scroll_name = ""
	values.clear()
	for name: String in hud.lineage_inventory_ui.inventory:
		if int(hud.lineage_inventory_ui.inventory[name]) <= 0: continue
		if not name.contains("주문서"): continue
		if not (name.contains("무기") or name.contains("갑옷") or name.contains("장신구") or name.contains("축복 부여")): continue
		values.append({"name":name,"count":int(hud.lineage_inventory_ui.inventory[name])})
	values.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	_build()

func configure_targets(controller: Node, scroll: String, candidates: Array) -> void:
	hud = controller
	mode = "target"
	scroll_name = scroll
	values = candidates.duplicate(true)
	_build()

func _build() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(UI.label("강화 주문서 선택" if mode == "scroll" else "강화할 장비 선택",21,UI.GOLD))
	add_child(UI.label("강화 실패 시 장비가 하락하거나 소실될 수 있습니다." if mode == "target" else "보유한 주문서만 표시합니다.",12,UI.MUTED))
	var body := Browser.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	listing = ItemList.new()
	listing.name = "EnhancementChoices"
	listing.icon_mode = ItemList.ICON_MODE_TOP
	listing.fixed_icon_size = Vector2i(54,54)
	listing.max_columns = 3
	listing.fixed_column_width = 140
	listing.same_column_width = true
	listing.max_text_lines = 2
	listing.add_theme_font_size_override("font_size",12)
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(_select)
	body.add_child(listing)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 320
	body.add_child(side)
	side.add_child(UI.label("상세 정보",18,UI.GOLD))
	var stage := Stage.new()
	stage.custom_minimum_size.y = 130
	side.add_child(stage)
	preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_left = 65
	preview.offset_right = -65
	preview.offset_top = 14
	preview.offset_bottom = -14
	detail = UI.rich("")
	detail.fit_content = false
	detail.scroll_active = true
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(detail)
	action = UI.button("선택",_execute,Vector2(0,54))
	action.name = "EnhanceAction"
	side.add_child(action)
	if mode == "target":
		side.add_child(UI.button("다른 주문서 선택",func() -> void: hud._open_enhance_chooser()))
	for entry: Dictionary in values:
		if mode == "scroll":
			listing.add_item("%s  ×%d" % [str(entry.get("name","")),int(entry.get("count",0))])
		else:
			listing.add_item("%s  +%d%s" % [
				str(entry.get("name","")) + (" [ID:%s]" % str(entry.get("instance_id", "")) if str(entry.get("instance_id", "")) != "" else ""), int(entry.get("level",0)),
				"  [장착]" if bool(entry.get("equipped",false)) else ""
			])
		var reference: String = str(entry.get("target_id",entry.get("name","")))
		var info: Dictionary = hud.lineage_inventory_ui._find_item_record(reference)
		listing.set_item_icon(listing.item_count-1,UI.item_icon(info,str(entry.get("name","")),hud.item_image_index.get("아이템",{})))
		listing.set_item_custom_fg_color(listing.item_count-1,UI.grade(str(info.get("grade","일반"))))
		listing.set_item_tooltip(listing.item_count-1,str(entry.get("name",""))+" · 장비 ID "+str(entry.get("instance_id","")))
	body.configure(listing,side,290)
	body.enable_item_touch()
	if values.is_empty():
		detail.text = "보유 강화 주문서가 없습니다. 상점에서 구매하세요." if mode == "scroll" else "이 주문서로 강화 가능한 장비가 없습니다."
		action.disabled = true
	else:
		listing.select(0)
		_select(0)

func _select(index: int) -> void:
	if index < 0 or index >= values.size(): return
	selected_index = index
	var entry: Dictionary = values[index]
	var reference: String = str(entry.get("target_id",entry.get("name","")))
	preview.texture = UI.item_icon(hud.lineage_inventory_ui._find_item_record(reference),str(entry.get("name","")),hud.item_image_index.get("아이템",{}))
	if mode == "scroll":
		detail.text = "[font_size=20][color=#d8b878]%s[/color][/font_size]\n\n보유 수량: %d\n\n장비 선택 화면에서 기존 게임 규칙에 따라 확률이 표시됩니다." % [UI.safe(entry.get("name","")),int(entry.get("count",0))]
		action.text = "장비 선택하기"
	else:
		var chance_success := float(entry.get("success_chance",0.0))
		var chance_stay := float(entry.get("no_change_chance",0.0))
		var chance_down := float(entry.get("decrease_chance",0.0))
		var chance_destroy := float(entry.get("destroy_chance",0.0))
		detail.text = "[font_size=21][color=#d8b878]%s  +%d[/color][/font_size]\n%s\n\n안전강화 +%d\n\n성공: %.1f%%\n유지: %.1f%%\n하락: %.1f%%\n소실: %.1f%%\n\n성공 강화폭: %s\n%s\n\n강화 시 주문서 1장 소모" % [
			UI.safe(entry.get("name","")),int(entry.get("level",0)),
			"장착 중" if bool(entry.get("equipped",false)) else "인벤토리 보관",
			int(entry.get("safe_level",0)),chance_success,chance_stay,chance_down,chance_destroy,
			UI.safe(entry.get("gain_text","+1")),UI.safe(entry.get("bonus_text","능력치 상승"))
		]
		action.text = "강화 시도 · 주문서 1장"
	action.disabled = false

func _execute() -> void:
	if selected_index < 0 or selected_index >= values.size(): return
	var entry: Dictionary = values[selected_index]
	if mode == "scroll":
		var item := str(entry.get("name",""))
		if int(hud.lineage_inventory_ui.inventory.get(item,0)) > 0:
			hud.inventory_item_activated.emit(item)
	else:
		var target := str(entry.get("target_id", entry.get("name","")))
		if target != "":
			hud.enhancement_requested.emit(scroll_name,target)
