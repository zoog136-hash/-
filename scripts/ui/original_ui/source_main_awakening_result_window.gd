extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## An already committed card result. The original scene authors both outcome
## texts, the skill/card slot, option text, touch prompt and separate FX loops.
## Its timeline is the client's own two-touch flow (user request 2026-11-27
## "한 번 터치하세요가 나온 뒤에 결과"):
##  1. Start (5..50) then Fx_Loop (55..175, repeating): the card and
##     Panel_Touch "화면을 터치해 주세요." (UIStaticTextData
##     CHANGE_UPGRADE_SKILL_AWAKEN\PANEL_TOUCH\LABEL); no outcome yet.
##  2. A touch: Fx_Touch_Active (180..225) then Fx_Success_Active /
##     Fx_Fail_Active reveal the outcome text and the awarded options, and the
##     outcome loop settles on its fully opaque last frame with Panel_Touch
##     shown again.
##  3. Another touch closes it. Nothing closes it by itself.
## A touch while an animation runs jumps to the end of that step.
const ResultPack = preload("res://scripts/ui/original_ui/source_awakening_result_pack.gd")
const SourceCard = preload("res://scripts/ui/source_card_presentation.gd")
const GradeFx = preload("res://scripts/ui/original_ui/source_main_card_grade_fx.gd")
const SourceText = preload("res://scripts/ui/original_ui/source_text.gd")
const Wrap = preload("res://scripts/ui/original_ui/source_text_wrap.gd")
const CARD_SCALE: float = 1.25
const WAIT_INTRO = "Start"
const WAIT_LOOP = "Fx_Loop"
const TOUCH_CLIP = "Fx_Touch_Active"
var _card: Dictionary
var _succeeded: bool
var _card_name: String
## Label_Skill before the touch: the target card's own name (a skill
## awakening's new skill is part of the outcome).
var _target_name: String
var _options: String
var _steady: bool
## The outcome is on screen and settled; the next touch closes.
var _held: bool
## The touch prompt is up and the outcome is not shown yet.
var _waiting: bool
## Clips still to play after the running one (the reveal chain).
var _queue: Array[String] = []
var _pressed: bool
var _drag_distance: float
var _option_list: String
var _tree_ref: WeakRef
var _card_pack: RefCounted

func _root_member() -> String:
	return ResultPack.MEMBER

func configure(active: RefCounted, host: Node) -> Dictionary:
	# The narrow installed result pack has the animation. The active main
	# pack also carries the original grade card frames it can display.
	_card_pack = active
	var selected: RefCounted = ResultPack.resolve(active)
	if selected == null:
		if active != null and not active.manifest.get("scenes", {}).has(ResultPack.MEMBER): return super.configure(active, host)
		return _fail("source_awakening_result_unavailable")
	return super.configure(selected, host)

func open(parent: Node, card: Dictionary, outcome: Dictionary, settings: Dictionary = {}) -> Dictionary:
	if is_open() or outcome.get("ok") != true or not outcome.get("success") is bool:
		return _fail("source_awakening_committed_result_required")
	_card = card
	_succeeded = outcome.success
	_card_name = str(outcome.get("skill_name", card.get("name", "")))
	_target_name = str(card.get("name", _card_name))
	var lines := PackedStringArray()
	for line: Variant in outcome.get("bonus_lines", []):
		if line is String: lines.append(line)
	_options = "\n".join(lines)
	_steady = settings.get("reduced_motion", false) or float(settings.get("impact_intensity", 1.0)) <= 0.0
	_held = false
	_waiting = true
	_queue = []
	_pressed = false
	_drag_distance = 0.0
	_option_list = ""
	var built: Dictionary = open_window(parent)
	if not built.get("ok", false): return built
	_scene.z_index = 180
	for clip: String in [WAIT_INTRO, WAIT_LOOP, TOUCH_CLIP, _clip("Active"), _clip("Loop")]:
		if _clip_range(clip).is_empty():
			close()
			return _fail("source_awakening_result_clip_missing")
	if _steady:
		_settle(WAIT_LOOP)
	else:
		_scene.play(WAIT_INTRO, false)
		_queue = [WAIT_LOOP]
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
	return {"Panel_Root/Btn_Plus":{"exclude":true}, "Nd_Card/Label_Skill":{"role":"source_text", "text":_target_name},
		"Nd_Skill/Nd_Card/Card":{"visible":false},
		"ListView/Label_Option":{"role":"source_text", "text":""},
		"Panel_Touch/Label":{"role":"static_source_text"}}

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var options_result: Dictionary = _fill_option_rows(root, out)
	if not options_result.ok: return options_result
	var art: Dictionary = SourceCard.detail(_card, true, false)
	var texture: Texture2D = art.get("texture") as Texture2D
	if texture == null: return {"ok":true, "picture":false}
	var grade: String = str(_card.get("grade", ""))
	var frame: Texture2D = GradeFx.card_frame(_card_pack,grade)
	var picture_area := Vector2(170,198)
	# This card remains centered and opaque through the authored success and
	# failure effects. Their animated empty skill slot has its own visibility.
	if frame != null:
		var center_card := Sprite2D.new()
		center_card.name = "AwakeningTargetCard"
		center_card.texture = frame
		center_card.scale = Vector2.ONE * CARD_SCALE
		center_card.z_index = 1
		center_card.set_meta("source_card_id", SourceCard.CARDS.card_id(_card))
		root.add_child(center_card)
		picture_area = frame.get_size() * CARD_SCALE * Vector2(0.84,0.82)
	var portrait := Sprite2D.new()
	portrait.name = "AwakeningTargetPortrait"
	portrait.texture = texture
	portrait.scale = Vector2.ONE * minf(picture_area.x / texture.get_width(), picture_area.y / texture.get_height())
	portrait.z_index = 2 if frame!=null else 1
	portrait.set_meta("source_card_id", SourceCard.CARDS.card_id(_card))
	root.add_child(portrait)
	return {"ok":true, "picture":true, "card_frame":frame!=null}

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

## Plays the queued clips in order. The touch prompt loop repeats until a
## touch; the reveal chain ends held on the outcome loop's last frame.
func _after_frame() -> void:
	if not is_open() or _held or _scene.playback_status().playing: return
	if _queue.is_empty():
		# Only a touch ends the prompt; a finished prompt clip starts again.
		if _waiting: _scene.play(WAIT_LOOP, true)
		else: _hold()
		return
	var next: String = _queue.pop_front()
	_scene.play(next, next == WAIT_LOOP)

## The touch prompt is up; the outcome starts (Fx_Touch_Active, then the
## committed branch).
func _reveal() -> void:
	_waiting = false
	var label: Dictionary = _locate(_scene, _out, "Nd_Card/Label_Skill")
	if label.get("ok", false): label.player.set_bound_text(label.offset, _card_name)
	if _steady:
		_hold()
		return
	_queue = [_clip("Active"), _clip("Loop")]
	_scene.play(TOUCH_CLIP, false)

func _hold() -> void:
	_waiting = false
	_queue = []
	_settle(_clip("Loop"))
	_held = true
	_stop_checking()

## Enters the authored last frame of `name`. The last frame of both outcome
## loops keeps the text fully opaque; Fx_Loop's keeps the prompt opaque.
func _settle(name: String) -> void:
	var span: Dictionary = _clip_range(name)
	if span.is_empty(): return
	_scene.seek_frame(float(span.endIndex))
	_scene.stop()

func _settle_text() -> void:
	_settle(_clip("Loop"))

func _clip_range(name: String) -> Dictionary:
	for clip: Dictionary in _scene.source_tree.get("animationList", []):
		if clip.name == name: return clip
	return {}

## {waiting, revealed, held, clip}: where the two-touch flow stands.
func phase() -> Dictionary:
	var status: Dictionary = _scene.playback_status() if is_open() else {}
	return {"waiting":_waiting, "revealed":not _waiting, "held":_held, "clip":str(status.get("clip", ""))}

## One touch: prompt -> outcome, running outcome -> settled, settled -> close.
func advance_or_dismiss() -> void:
	if not is_open(): return
	if _held: close()
	elif _waiting: _reveal()
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
