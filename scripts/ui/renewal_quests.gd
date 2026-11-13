extends VBoxContainer
## Lightweight text list. Only individual acceptance invokes a transaction.
signal claim_requested(quest_id: String)
signal source_category_changed(category: String)
const UI = preload("res://scripts/ui/renewal_theme.gd")
const CATEGORIES = {"main":"메인", "common":"일반", "achievement":"업적", "other":"기타"}
const STATES: Array[String] = ["all","waiting","done","history"]
const PAGE_SIZE = 30
var world: Node
var selected: String = "main"
var tab_buttons: Dictionary = {}
var listing: VBoxContainer
var summary: Label
var search: LineEdit
var page: int = 0
var page_label: Label
var previous: Button
var next: Button
var state_filter: OptionButton
var _refresh_pending: bool = false
var _accept_pending: bool = false
var _refresh_tree: WeakRef

func configure(owner_world: Node) -> void:
	world = owner_world
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",6)
	add_child(UI.label("수락하면 즉시 완료됩니다.",12,UI.MUTED))
	var tabs := HBoxContainer.new()
	add_child(tabs)
	for category: String in CATEGORIES:
		var button := Button.new()
		button.text = CATEGORIES[category]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 35
		button.pressed.connect(_select.bind(category))
		tabs.add_child(button)
		tab_buttons[category] = button
	var filters := HBoxContainer.new()
	add_child(filters)
	search = LineEdit.new()
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.placeholder_text = "퀘스트 이름 · ID 검색"
	search.text_changed.connect(func(_value: String) -> void: page=0;refresh())
	filters.add_child(search)
	state_filter = OptionButton.new()
	for label: String in ["전체","미완료","완료","기존 완료 이력"]: state_filter.add_item(label)
	state_filter.item_selected.connect(func(_value: int) -> void: page=0;refresh())
	filters.add_child(state_filter)
	summary = UI.label("",12,UI.GOLD)
	add_child(summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	listing = VBoxContainer.new()
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(listing)
	var pages := HBoxContainer.new()
	add_child(pages)
	previous = Button.new();previous.text = "이전"
	previous.pressed.connect(func() -> void: page-=1;refresh())
	pages.add_child(previous)
	page_label = UI.label("",12,UI.MUTED)
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(page_label)
	next = Button.new();next.text = "다음"
	next.pressed.connect(func() -> void: page+=1;refresh())
	pages.add_child(next)
	_render()

func _select(category: String) -> void:
	selected = category
	page = 0
	refresh()
	source_category_changed.emit(category)

func refresh() -> void:
	if not is_inside_tree() or _refresh_pending: return
	_refresh_pending = true
	_refresh_tree = weakref(get_tree())
	get_tree().process_frame.connect(_flush_refresh,CONNECT_ONE_SHOT)

func _flush_refresh() -> void:
	_refresh_pending = false
	_refresh_tree = null
	_accept_pending = false
	if is_inside_tree() and not is_queued_for_deletion(): _render()

func _exit_tree() -> void:
	var tree: SceneTree = _refresh_tree.get_ref() as SceneTree if _refresh_tree!=null else null
	if tree!=null and tree.process_frame.is_connected(_flush_refresh): tree.process_frame.disconnect(_flush_refresh)
	_refresh_pending = false
	_refresh_tree = null
	_accept_pending = false

func _accept(id: String) -> void:
	if _accept_pending or not is_instance_valid(world): return
	var service: Variant = world.get("quest_service")
	if service==null or bool(service.claimed.get(id,false)) or service.save_blocked: return
	_accept_pending = true
	# Existing world._claim_quest -> quest_auto.claim -> atomic save. No bulk
	# completion or reward preview; a refused write stays uncompleted.
	claim_requested.emit(id)
	refresh()

func _render() -> void:
	if listing==null or not is_instance_valid(world): return
	var service: Variant = world.get("quest_service")
	if service==null: return
	var model: Dictionary = service.text_page(int(world.level),selected,page,PAGE_SIZE,search.text,STATES[state_filter.selected],-1,int(service.source.class_ids.get(str(world.get("job_class")),-1)))
	page = model.page
	for child: Node in listing.get_children():
		listing.remove_child(child)
		child.queue_free()
	for quest: Dictionary in model.rows:
		var row := HBoxContainer.new()
		listing.add_child(row)
		var title := UI.label(str(quest.title),14,UI.TEXT)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(title)
		var status := UI.label(str(quest.status),12,UI.GOLD if quest.completed else UI.MUTED)
		status.custom_minimum_size.x = 95
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(status)
		if not quest.completed:
			var accept := Button.new()
			accept.text = "수락"
			accept.custom_minimum_size = Vector2(80,34)
			accept.disabled = not quest.can_accept
			accept.pressed.connect(_accept.bind(str(quest.id)))
			row.add_child(accept)
	summary.text = "%s · %d개" % [CATEGORIES[selected],model.matches]
	page_label.text = "%d / %d 페이지" % [page+1,model.pages]
	previous.disabled = page==0
	next.disabled = page==model.pages-1
	for category: String in tab_buttons: tab_buttons[category].modulate = Color.WHITE if category==selected else Color(0.65,0.65,0.65)
