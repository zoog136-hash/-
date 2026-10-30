extends VBoxContainer
## Read-only presentation of permanent unlocks and spendable duplicates.
## Every fusion still goes through the World signal and confirmation dialog.
signal fuse_requested(category: String, grade: String)

const UI = preload("res://scripts/ui/renewal_theme.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const SourceButton = preload("res://scripts/ui/native_touch_button.gd")
const SourceList = preload("res://scripts/ui/native_touch_list.gd")
const MATERIAL_GRADES: Array[String] = ["일반", "고급", "희귀", "영웅", "전설", "신화"]

var catalog: Dictionary = {}
var collection: Dictionary = {}
var category: String = "변신"
var grade: String = "고급"
var _built: bool = false
var _tabs: Dictionary = {}
var _grade_select: OptionButton
var _overall: Label
var _materials: Label
var _cards: ItemList
var _empty: Label
var _fuse: Button
var _note: Label
var _last_result: Label

func configure(catalog_value: Dictionary, collection_value: Dictionary, initial_category: String) -> void:
	catalog = catalog_value
	collection = collection_value.duplicate(true)
	_build()
	set_category(initial_category)

func set_collection_state(value: Dictionary) -> void:
	collection = value.duplicate(true)
	_refresh()

func set_category(value: String) -> void:
	if not Cards.CATEGORIES.has(value):
		return
	category = value
	_refresh()

func set_result(category_name: String, value: String) -> void:
	if category_name == category and is_instance_valid(_last_result):
		_last_result.text = value

func _touch(label: String, method: Callable) -> Button:
	var button: Button = SourceButton.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(method)
	return button

func _build() -> void:
	if _built: return
	_built = true
	name = "CardFusionView"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	var headline: Label = UI.section("카드 합성 · 보유/중복 확인", 18)
	headline.name = "CardFusionHeadline"
	add_child(headline)
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.name = "CardFusionCategoryTabs"
	add_child(tabs)
	for key: String in Cards.CATEGORIES:
		var chosen: String = key
		var button: Button = _touch(key, func() -> void: set_category(chosen))
		button.name = "FusionCategory" + key
		button.toggle_mode = true
		tabs.add_child(button)
		_tabs[key] = button
	_overall = UI.label("", 14, UI.GOLD)
	_overall.name = "CardFusionOverall"
	_overall.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_overall)
	var grade_row: HBoxContainer = HBoxContainer.new()
	add_child(grade_row)
	_grade_select = OptionButton.new()
	_grade_select.name = "CardFusionSelectGrade"
	_grade_select.custom_minimum_size.y = 44
	_grade_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for current_grade: String in MATERIAL_GRADES:
		var next_grade: String = str(Cards.FUSION_NEXT[current_grade])
		_grade_select.add_item("%s → %s" % [current_grade, next_grade])
	_grade_select.select(1)
	_grade_select.item_selected.connect(func(index: int) -> void:
		grade = MATERIAL_GRADES[index]
		_refresh())
	grade_row.add_child(_grade_select)
	_materials = UI.label("", 14, UI.TEXT)
	_materials.name = "CardFusionMaterialsCount"
	_materials.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_materials)
	_cards = SourceList.new()
	_cards.name = "CardFusionOwnedList"
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards.custom_minimum_size = Vector2(0, 100)
	_cards.icon_mode = ItemList.ICON_MODE_LEFT
	_cards.fixed_icon_size = Vector2i(40, 50)
	_cards.max_columns = 1
	_cards.max_text_lines = 2
	add_child(_cards)
	_empty = UI.label("", 13, UI.MUTED)
	_empty.name = "CardFusionEmpty"
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_empty)
	_note = UI.label("처음 얻은 카드 1장은 도감에 영구 보관됩니다. 중복 카드만 합성에 소비합니다.", 12, UI.MUTED)
	_note.name = "CardFusionRule"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_note)
	_fuse = _touch("합성 확인", _request)
	_fuse.name = "CardFusionConfirm"
	add_child(_fuse)
	_last_result = UI.label("", 12, UI.GOLD)
	_last_result.name = "CardFusionResult"
	_last_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_last_result)
	resized.connect(func() -> void:headline.visible=size.y>=400)
	# Keep the authoritative confirmation inside the existing window at short
	# landscape sizes. Category, grade, ownership and the real card list scroll.
	var scroll := ScrollContainer.new()
	scroll.name = "CardFusionContentScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	scroll.add_child(content)
	for child: Node in get_children():
		if child != _fuse and child != _last_result: child.reparent(content)
	add_child(scroll)
	move_child(scroll,0)
	var host: Node = get_parent()
	while host != null:
		if host.has_method("register_scroll_drag"):
			host.call("register_scroll_drag",scroll,content)
			break
		host = host.get_parent()

func _refresh() -> void:
	if not _built or not Cards.CATEGORIES.has(category): return
	for key: String in _tabs:
		(_tabs[key] as Button).button_pressed = key == category
	var owned: Dictionary = (collection.get("owned", {}) as Dictionary).get(category, {}) as Dictionary
	var spare: Dictionary = (collection.get("spare", {}) as Dictionary).get(category, {}) as Dictionary
	var total_duplicates: int = 0
	for identity: String in spare:
		total_duplicates += maxi(0, int(spare[identity]))
	_overall.text = "%s · 보유 %d종 / 총 %d장 · 중복 %d장" % [category, owned.size(), owned.size() + total_duplicates, total_duplicates]
	_cards.clear()
	var available: int = 0
	var displayed: int = 0
	var target_exists: bool = false
	var source_exists: bool = false
	var seen: Dictionary = {}
	for raw: Variant in catalog.get(category, []) as Array:
		if not (raw is Dictionary): continue
		var record: Dictionary = raw
		var current_grade: String = str(record.get("grade", ""))
		if current_grade == str(Cards.FUSION_NEXT[grade]):
			target_exists = true
		if current_grade != grade: continue
		source_exists = true
		var identity: String = Cards.card_id(record)
		if identity.is_empty() or seen.has(identity): continue
		seen[identity] = true
		var copies: int = (1 if owned.has(identity) else 0) + maxi(0, int(spare.get(identity, 0)))
		if copies == 0: continue
		var duplicates: int = maxi(0, int(spare.get(identity, 0)))
		available += duplicates
		displayed += 1
		var label: String = "%s · 보유 %d장 / 합성 재료 %d장" % [str(record.get("name", "")), copies, duplicates]
		var path: String = str(record.get("image_path", ""))
		var texture: Texture2D = null
		if not path.is_empty() and ResourceLoader.exists(path):
			texture = load(path) as Texture2D
		_cards.add_item(label, texture)
		_cards.set_item_custom_fg_color(_cards.item_count-1, UI.grade(current_grade))
	var required: int = int(Cards.FUSION_MATERIALS[grade])
	var probability: float = float(Cards.FUSION_WEIGHTS[grade]) / 100.0
	_materials.text = "%s 중복 카드 %d / %d장 · %s 합성 성공률 %.2f%%" % [grade, available, required, str(Cards.FUSION_NEXT[grade]), probability]
	_empty.visible = displayed == 0
	_empty.text = "%s에서 보유한 %s 카드가 없습니다. 획득한 카드를 다시 뽑으면 중복이 쌓입니다." % [category, grade]
	_fuse.disabled = available < required or not target_exists or not source_exists
	_fuse.text = "재료 %d장 부족" % (required - available) if available < required else "합성 불가 · 결과 카드 없음" if not target_exists else "%s → %s 합성" % [grade, str(Cards.FUSION_NEXT[grade])]

func _request() -> void:
	if not _fuse.disabled and Cards.CATEGORIES.has(category) and Cards.FUSION_NEXT.has(grade):
		fuse_requested.emit(category, grade)
