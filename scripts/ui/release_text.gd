extends RefCounted
## Release (phone) screens: developer wording left in the text of older
## TWILIGHT panels (settings sections, workspace windows) is filtered once the
## panel is built. Labels use IDENTITY.screen_note (version tag dropped, a
## developer note hidden); buttons keep their action and only lose version
## tags. Debug and twilight_dev_ui builds are untouched.
const IDENTITY = preload("res://scripts/ui/source523_item_identity.gd")
const FLAGS = preload("res://scripts/boot/build_flags.gd")

static func scrub(root: Node, developer: bool = FLAGS.developer_ui()) -> int:
	if developer or root == null or not is_instance_valid(root): return 0
	var changed: int = 0
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Label or node is RichTextLabel:
			var text: String = node.text
			if not text.is_empty():
				var shown: String = IDENTITY.screen_note(text, false)
				if shown != text:
					node.text = shown
					if shown.is_empty(): node.visible = false
					changed += 1
		elif node is Button:
			var label: String = node.text
			if not label.is_empty():
				var stripped: String = IDENTITY.strip_build_tags(label)
				if stripped != label and not stripped.is_empty():
					node.text = stripped
					changed += 1
		if node is Control and not (node as Control).tooltip_text.is_empty() and IDENTITY.developer_wording((node as Control).tooltip_text):
			(node as Control).tooltip_text = ""
			changed += 1
		for child: Node in node.get_children(): pending.append(child)
	return changed
