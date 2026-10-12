extends RefCounted

# Navigation history and presentation state only. Gameplay belongs to world.gd.
var history: Array[String] = []
var states: Dictionary = {}
var returning: bool = false

func enter(previous: String, next: String) -> void:
	if not returning and previous != "" and previous != next:
		history.append(previous)
		if history.size() > 24: history.pop_front()

func previous() -> String:
	return history.pop_back() if not history.is_empty() else ""

func clear() -> void:
	history.clear()

func capture(section: String, root: Node) -> void:
	if section.is_empty(): return
	var state: Dictionary = {}
	_capture(root, state)
	states[section] = state

func _capture(root: Node, state: Dictionary) -> void:
	for node: Node in root.get_children():
		var key := str(node.name)
		if node is LineEdit: state[key] = node.text
		elif node is OptionButton: state[key] = node.selected
		elif node is ItemList: state[key] = node.get_selected_items()
		elif node is ScrollContainer: state[key] = node.scroll_vertical
		if node.has_method("capture_navigation_state"):
			state["view:"+key] = node.call("capture_navigation_state")
		_capture(node, state)

func restore(section: String, root: Node) -> void:
	if states.has(section): _restore(root, states[section])

func _restore(root: Node, state: Dictionary) -> void:
	for node: Node in root.get_children():
		var key := str(node.name)
		if state.has(key):
			if node is LineEdit:
				node.text = str(state[key])
				node.text_changed.emit(node.text)
			elif node is OptionButton and int(state[key]) < node.item_count:
				node.select(int(state[key]))
				node.item_selected.emit(node.selected)
			elif node is ItemList:
				for index: int in state[key]:
					if index < node.item_count:
						node.select(index)
						node.item_selected.emit(index)
			elif node is ScrollContainer: node.scroll_vertical = int(state[key])
		_restore(node, state)
		if state.has("view:"+key) and node.has_method("restore_navigation_state"):
			node.call("restore_navigation_state",state["view:"+key])
