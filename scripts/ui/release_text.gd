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

## Release words removed inside a sentence that stays (a cost or a rule the
## player needs): "TWILIGHT 추가 비용 500 아데나" -> "추가 비용 500 아데나".
const INLINE_WORDS: Array[String] = [" (TWILIGHT 근사)", "(TWILIGHT 근사)", "TWILIGHT 자체 ", "TWILIGHT ", "원본 "]
## A line still naming how a value was decided (estimates, policies) is a
## developer note on release screens and is dropped.
const NOTE_WORDS: Array[String] = ["추정", "근사", "정책", "우선하"]

## One line of a dialog or notice as a release (phone) screen shows it, or ""
## when the whole line is a developer note.
static func line(text: String, developer: bool = FLAGS.developer_ui()) -> String:
	if developer: return text
	var value: String = IDENTITY.strip_build_tags(text)
	var had_word: bool = false
	for word: String in INLINE_WORDS:
		if value.contains(word):
			had_word = true
			value = value.replace(word, "")
	value = value.strip_edges()
	if IDENTITY.developer_wording(value): return ""
	if had_word:
		for word: String in NOTE_WORDS:
			if value.contains(word): return ""
	return value

## A multi-line body: each line through line(); dropped lines disappear.
static func body(text: String, developer: bool = FLAGS.developer_ui()) -> String:
	if developer: return text
	var kept: Array[String] = []
	for part: String in text.split("\n"):
		var shown: String = line(part, false)
		if not shown.is_empty() or part.strip_edges().is_empty(): kept.append(shown)
	return "\n".join(kept).strip_edges()
