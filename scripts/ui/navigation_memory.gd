extends RefCounted

# Presentation state only. Never replay arbitrary control signals: the skill
# school and summon-order OptionButtons perform gameplay writes and saves.
const ROUTES := ["menu", "inventory", "skills", "character", "shop", "npc_shop",
	"teleport", "map", "settings", "auto", "log", "enhance", "warehouse",
	"crafting", "sell", "변신", "마법인형", "성물", "아이템"]
var history: Array[String] = []
var states: Dictionary = {}
var returning: bool = false
var revision: int = 0

func enter(previous: String, next: String) -> void:
	revision += 1
	if returning or previous not in ROUTES or previous == next:
		return
	if history.is_empty() or history.back() != previous:
		history.append(previous)
	if history.size() > 24:
		history.pop_front()

func back() -> String:
	while not history.is_empty():
		var section: String = history.pop_back()
		if section in ROUTES:
			return section
	return ""

func has_history() -> bool:
	return not history.is_empty()

func clear_history() -> void:
	history.clear()
	revision += 1

func _view(root: Node, section: String) -> Node:
	if not is_instance_valid(root):
		return null
	var path := "res://scripts/ui/renewal_%s.gd" % section
	for child: Node in root.find_children("*", "Control", true, false):
		var script: Script = child.get_script() as Script
		if script != null and script.resource_path == path:
			return child
	return null

func capture(section: String, root: Node) -> void:
	# Catalogs already have their own PR91 ID/page/grade memory. Transaction
	# quantities, settings, school selection and summon commands are not UI filters.
	if section not in ["inventory", "skills"]:
		return
	var view: Node = _view(root, section)
	if view == null:
		return
	if section == "inventory":
		var search: LineEdit = view.get("search_line") as LineEdit
		var scroll: ScrollContainer = view.get("grid_scroll") as ScrollContainer
		var row: Control = view.get("search_row") as Control
		states[section] = {"query": search.text,
			"category": str(view.get("category_filter")),
			"sort": int(view.get("sort_mode")),
			"id": str(view.get("selected_item")),
			"detail": bool(view.get("detail_active")),
			"search_visible": row.visible, "scroll": scroll.scroll_vertical}
	else:
		var search: LineEdit = view.get("search") as LineEdit
		var type_filter: OptionButton = view.get("type_filter") as OptionButton
		var class_filter: OptionButton = view.get("class_filter") as OptionButton
		var grade_filter: OptionButton = view.get("grade_filter") as OptionButton
		var selected: Dictionary = view.get("selected")
		var cards: ItemList = view.get("cards") as ItemList
		var browser: Node = cards.get_parent().get_parent()
		states[section] = {"query": search.text, "type": type_filter.selected,
			"class": class_filter.selected, "grade": grade_filter.selected,
			"id": str(selected.get("id", selected.get("name", ""))),
			"detail": bool(browser.get("detail_active")),
			"scroll": cards.get_v_scroll_bar().value}

func _select_filter(control: OptionButton, index: int) -> void:
	if control != null and control.item_count > 0:
		control.select(clampi(index, 0, control.item_count - 1))

func restore(section: String, root: Node) -> void:
	if section not in ["inventory", "skills"] or not states.has(section):
		return
	var view: Node = _view(root, section)
	if view == null:
		return
	var state: Dictionary = states[section].duplicate(true)
	if section == "inventory":
		var search: LineEdit = view.get("search_line") as LineEdit
		search.text = str(state.get("query", ""))
		var category: String = str(state.get("category", "전체"))
		var tabs: Dictionary = view.get("tab_buttons")
		if not tabs.has(category):
			category = "전체"
		view.set("category_filter", category)
		for key: String in tabs:
			(tabs[key] as Button).set_pressed_no_signal(key == category)
		var sort_mode: int = clampi(int(state.get("sort", 0)), 0, 3)
		view.set("sort_mode", sort_mode)
		_select_filter(view.find_child("InventorySort", true, false) as OptionButton, sort_mode)
		(view.get("search_row") as Control).visible = bool(state.get("search_visible", false))
		view.set("selected_item", "")
		view.set("detail_active", false)
		view.call("_refresh_inventory_grid")
		var identity: String = str(state.get("id", ""))
		var slots: Dictionary = view.get("slot_buttons")
		# Exact physical item reference only; a sold item must not select its neighbor.
		if slots.has(identity):
			view.call("_select_item", identity)
			# Restoring a retained selection is not a fresh user tap.
			view.call("_hide_item_name")
			view.set("detail_active", bool(state.get("detail", false)))
		view.call("_reflow")
	else:
		(view.get("search") as LineEdit).text = str(state.get("query", ""))
		_select_filter(view.get("type_filter") as OptionButton, int(state.get("type", 0)))
		_select_filter(view.get("class_filter") as OptionButton, int(state.get("class", 0)))
		_select_filter(view.get("grade_filter") as OptionButton, int(state.get("grade", 0)))
		# refresh resolves by stable skill ID and updates both selection and details.
		view.set("selected", {"id": str(state.get("id", ""))})
		view.call("refresh")
		var cards: ItemList = view.get("cards") as ItemList
		var browser: Node = cards.get_parent().get_parent()
		browser.set("detail_active", bool(state.get("detail", false)) and cards.item_count > 0)
		browser.call("reflow")
	_restore_scroll(section, root, view, state, revision)

func _restore_scroll(section: String, root: Node, view: Node, state: Dictionary, ticket: int) -> void:
	if not root.is_inside_tree():
		return
	var tree: SceneTree = root.get_tree()
	# Containers and the existing view refresh use deferred layout. Do not apply
	# an obsolete scroll after another navigation, close, or a freed screen.
	await tree.process_frame
	await tree.process_frame
	if ticket != revision or not is_instance_valid(root) or not is_instance_valid(view):
		return
	if not root.is_inside_tree() or not root.is_ancestor_of(view):
		return
	if not (view as Control).is_visible_in_tree():
		return
	if section == "inventory":
		var scroll: ScrollContainer = view.get("grid_scroll") as ScrollContainer
		scroll.scroll_vertical = int(state.get("scroll", 0))
	else:
		var cards: ItemList = view.get("cards") as ItemList
		cards.get_v_scroll_bar().value = float(state.get("scroll", 0))
