extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## An already committed card result. The original scene authors both outcome
## texts, the skill/card slot, option text, touch prompt and separate FX loops.
const ResultPack = preload("res://scripts/ui/original_ui/source_awakening_result_pack.gd")
const Cards = preload("res://scripts/ui/original_ui/source_main_change_page.gd")
const SourceText = preload("res://scripts/ui/original_ui/source_text.gd")
const Wrap = preload("res://scripts/ui/original_ui/source_text_wrap.gd")
var _source_cards: RefCounted
var _card: Dictionary
var _succeeded: bool
var _card_name: String
var _options: String
var _steady: bool
var _held: bool
var _in_loop: bool
var _pressed: bool
var _drag_distance: float
var _option_list: String
var _tree_ref: WeakRef

func _root_member() -> String:
	return ResultPack.MEMBER

func configure(active: RefCounted, host: Node) -> Dictionary:
	var selected: RefCounted = ResultPack.resolve(active)
	if selected == null:
		if active != null and not active.manifest.get("scenes", {}).has(ResultPack.MEMBER): return super.configure(active, host)
		return _fail("source_awakening_result_unavailable")
	_source_cards = Cards.new()
	_source_cards._pack = active
	return super.configure(selected, host)

func open(parent: Node, card: Dictionary, outcome: Dictionary, settings: Dictionary = {}) -> Dictionary:
	if is_open() or outcome.get("ok") != true or not outcome.get("success") is bool:
		return _fail("source_awakening_committed_result_required")
	_card = card
	_succeeded = outcome.success
	_card_name = str(outcome.get("skill_name", card.get("name", "")))
	var lines := PackedStringArray()
	for line: Variant in outcome.get("bonus_lines", []):
		if line is String: lines.append(line)
	_options = "\n".join(lines)
	_steady = settings.get("reduced_motion", false) or float(settings.get("impact_intensity", 1.0)) <= 0.0
	_held = false
	_in_loop = _steady
	_pressed = false
	_drag_distance = 0.0
	_option_list = ""
	var built: Dictionary = open_window(parent)
	if not built.get("ok", false): return built
	_scene.z_index = 180
	var clip: String = _clip("Loop" if _steady else "Active")
	if not _scene.play(clip, false).get("ok", false):
		close()
		return _fail("source_awakening_result_clip_missing")
	if _steady:
		_settle_text()
		_held = true
	else:
		_tree_ref = weakref(parent.get_tree())
		parent.get_tree().process_frame.connect(_after_frame)
	# Input coverage only. All visible pixels and text are the source scene.
	var input := Control.new()
	input.name = "AwakeningResultTouch"
	input.mouse_filter = Control.MOUSE_FILTER_STOP
	input.position = Vector2(-1800, -1200)
	input.size = Vector2(3600, 2400)
	input.gui_input.connect(_touch.bind(input))
	_scene.add_child(input)
	return built

func _spec() -> Dictionary:
	return {"Panel_Root/Btn_Plus":{"exclude":true}, "Nd_Card/Label_Skill":{"role":"source_text", "text":_card_name},
		"ListView/Label_Option":{"role":"source_text", "text":""},
		"Panel_Touch/Label":{"role":"static_source_text"}}

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var options_result: Dictionary = _fill_option_rows(root, out)
	if not options_result.ok: return options_result
	var grade: String = str(_card.get("grade", ""))
	if not Cards.GRADE_MEMBERS.has(grade) or _source_cards._pack == null: return {"ok":true}
	var member: String = Cards.GRADE_MEMBERS[grade]
	if not _source_cards._pack.manifest.get("scenes", {}).has(member): return {"ok":true}
	var card_row: Dictionary = _source_cards._card_row(_card, false, Callable(self, "_ignore"))
	var offsets: Dictionary = {}
	var built: Dictionary = _source_cards._scene_of(member, card_row.spec, offsets)
	if not built.get("ok", false): return {"ok":true}
	var anchor: Dictionary = _locate(root, out, "Nd_Skill/Nd_Card/Card")
	if not anchor.get("ok", false):
		built.scene.free()
		return {"ok":true}
	var host: Node2D = anchor.player.source_nodes[anchor.offset]
	var grade_scene: Node2D = built.scene
	host.add_child(grade_scene)
	return {"ok":true, "picture":_source_cards._card_picture(grade_scene, offsets, _card)}

## The ListView authors a single 155×14 label to repeat for awarded option
## lines. Use its font and original layout for every row of the saved result.
func _fill_option_rows(root: Node2D, out: Dictionary) -> Dictionary:
	if _options.is_empty(): return {"ok":true}
	var list: Dictionary = _list(root, out, "ListView")
	var located: Dictionary = _locate(root, out, "ListView/Label_Option")
	if not list.get("ok",false) or not located.get("ok",false): return _fail("source_awakening_option_list_missing")
	var template: Node2D = located.player.source_nodes[located.offset].get_meta("source_text")
	var font_size: int = template.original_options.fontSize
	var wrapped: Dictionary = Wrap.flow_lines(template.original_font, _options, font_size, template.original_size.x)
	if not wrapped.get("ok",false): return wrapped
	var pitch: float = maxf(template.original_size.y, template.original_font.get_height(font_size))
	var offset: float = 0.0
	for line: String in wrapped.lines:
		var label := SourceText.new()
		var options: Dictionary = template.original_options.duplicate()
		options.text = line
		var built: Dictionary = label.configure(template.original_font, options, template.original_size)
		if not built.ok:
			label.free()
			return built
		template.add_child(label)
		label.position.y = offset
		offset += pitch
	_option_list = str(list.key)
	_scrolls[_option_list] = {"content":list.content,"min":minf(0.0,list.size.y-offset),"value":0.0}
	return {"ok":true}

func _clip(phase: String) -> String:
	return "Fx_%s_%s" % ["Success" if _succeeded else "Fail", phase]

func _after_frame() -> void:
	if not is_open() or _held or _scene.playback_status().playing: return
	if _in_loop:
		_hold()
	else:
		_in_loop = true
		_scene.play(_clip("Loop"), false)

func _hold() -> void:
	if not _in_loop:
		_in_loop = true
		_scene.play(_clip("Loop"), false)
	_settle_text()
	_held = true
	_stop_checking()

## The authored last frame of both outcome loops keeps the text fully
## opaque. Reduced motion enters that frame immediately.
func _settle_text() -> void:
	var name: String = _clip("Loop")
	for clip: Dictionary in _scene.source_tree.animationList:
		if clip.name == name:
			_scene.seek_frame(float(clip.endIndex))
			_scene.stop()
			return

func advance_or_dismiss() -> void:
	if not is_open(): return
	if _held: close()
	else: _hold()

func _touch(event: InputEvent, input: Control) -> void:
	if _pressed and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		_drag_distance += absf(event.relative.y)
		if _scrolls.has(_option_list):
			_scroll_to(_option_list, float(_scrolls[_option_list].value) + event.relative.y)
		input.accept_event()
		return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		input.accept_event()
		if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION: return
		if event is InputEventScreenTouch and event.device == InputEvent.DEVICE_ID_EMULATION: return
		if event.pressed:
			_pressed = true
			_drag_distance = 0.0
		elif _pressed:
			_pressed = false
			if _drag_distance < 8.0: advance_or_dismiss()

func _stop_checking() -> void:
	var tree: Variant = _tree_ref.get_ref() if _tree_ref != null else null
	if is_instance_valid(tree) and tree.process_frame.is_connected(_after_frame):
		tree.process_frame.disconnect(_after_frame)
	_tree_ref = null

func close() -> void:
	_stop_checking()
	_card = {}
	super.close()
