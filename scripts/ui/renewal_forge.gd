extends VBoxContainer

# Enhancement probabilities and transactions are supplied by the world.
const UI = preload("res://scripts/ui/renewal_theme.gd")

var hud: Node
var mode: String = "scroll"
var scroll_name: String = ""
var values: Array = []
var listing: ItemList
var detail: RichTextLabel
var action: Button
var selected_index: int = -1

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
	add_child(UI.label("게임의 강화 확률과 소모 처리는 변경하지 않습니다. 실패 시 장비 하락 또는 소실 가능" if mode == "target" else "보유한 주문서만 표시합니다.",12,UI.MUTED))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	listing = ItemList.new()
	listing.name = "EnhancementChoices"
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(_select)
	body.add_child(listing)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 320
	body.add_child(side)
	side.add_child(UI.label("상세 정보",18,UI.GOLD))
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
