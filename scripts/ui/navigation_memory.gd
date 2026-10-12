extends RefCounted

# UI-only navigation memory. Never owns gameplay state or saved quickslot data.
var history: Array[String] = []
var states: Dictionary = {}
var returning: bool = false

func enter(previous: String, next: String) -> void:
	if returning or previous.is_empty() or previous == next:
		return
	if history.is_empty() or history.back() != previous:
		history.append(previous)
	if history.size() > 24:
		history.pop_front()

func back() -> String:
	return history.pop_back() if not history.is_empty() else ""

func has_history() -> bool:
	return not history.is_empty()

func clear_history() -> void:
	history.clear()

func capture(section: String, root: Node) -> void:
	if section.is_empty() or root == null:
		return
	var snapshot: Dictionary = {}
	for node: Node in root.find_children("*", "Control", true, false):
		var key: String = str(root.get_path_to(node))
		if node is LineEdit:
			snapshot[key] = {"type": "search", "value": (node as LineEdit).text}
		elif node is OptionButton:
			snapshot[key] = {"type": "option", "value": (node as OptionButton).selected}
		elif node is ItemList:
			snapshot[key] = {"type": "selection", "value": (node as ItemList).get_selected_items()}
		elif node is ScrollContainer:
			snapshot[key] = {"type": "scroll", "value": (node as ScrollContainer).scroll_vertical}
	states[section] = snapshot

func restore(section: String, root: Node) -> void:
	if root == null or not states.has(section):
		return
	var snapshot: Dictionary = states[section]
	# Populate filters first, then selection, then scroll position after relayout.
	for kind: String in ["search", "option", "selection", "scroll"]:
		for key: String in snapshot:
			var item: Dictionary = snapshot[key]
			if str(item.get("type", "")) != kind:
				continue
			var node: Node = root.get_node_or_null(NodePath(key))
			if node == null:
				continue
			match kind:
				"search":
					if node is LineEdit:
						var field: LineEdit = node
						field.text = str(item.get("value", ""))
						field.text_changed.emit(field.text)
				"option":
					if node is OptionButton:
						var choice: OptionButton = node
						var index: int = int(item.get("value", -1))
						if index >= 0 and index < choice.item_count:
							choice.select(index)
							choice.item_selected.emit(index)
				"selection":
					if node is ItemList:
						var listing: ItemList = node
						var indices: PackedInt32Array = item.get("value", PackedInt32Array())
						for index: int in indices:
							if index >= 0 and index < listing.item_count:
								listing.select(index)
				"scroll":
					if node is ScrollContainer:
						(node as ScrollContainer).scroll_vertical = int(item.get("value", 0))
