extends Control
## Uses the original two-button message box. Charge only when the player
## acknowledges the last page of the complete review.
const Kit = preload("res://scripts/ui/original_ui/source_main_window_kit.gd")
const Pack = preload("res://scripts/ui/original_ui/source_awakening_result_pack.gd")
const Wrap = preload("res://scripts/ui/original_ui/source_text_wrap.gd")
var confirm_button: Control
var cancel_button: Control
var _callback: Callable
var _scene: Node2D
var _design: Vector2
var _height: float
var _pages: PackedStringArray
var _page: int
var _title: String
var _title_label: Node2D
var _body_label: Node2D
var _action_label: Node2D

func configure(pack: RefCounted, design: Vector2, title: String, body: String, accept: Callable) -> bool:
	if pack == null or minf(design.x,design.y) <= 0.0: return false
	var kit := Kit.new()
	kit._pack = pack
	var offsets: Dictionary = {}
	var spec: Dictionary = {"Bg/Text_Title":{"role":"source_text","text":title},
		"Bg/Text_Info":{"role":"source_text","text":""},
		"Btn_Cancel":{"activate":Callable(self,"_cancel")}, "Btn_Yes":{"activate":Callable(self,"_accept")}}
	var built: Dictionary = kit._scene_of(Pack.REVIEW, spec, offsets)
	if not built.get("ok",false): return false
	_scene = built.scene
	add_child(_scene)
	confirm_button = _button(offsets, "Btn_Yes")
	cancel_button = _button(offsets, "Btn_Cancel")
	if confirm_button == null or cancel_button == null: return false
	_title = title
	_title_label = _node(offsets, "Bg/Text_Title").get_meta("source_text")
	_body_label = _node(offsets, "Bg/Text_Info").get_meta("source_text")
	_action_label = _node(offsets, "Btn_Yes").get_meta("source_button")._title
	if not is_instance_valid(_action_label): return false
	var font: FontFile = _body_label.original_font
	var font_size: int = _body_label.original_options.fontSize
	var wrapped: Dictionary = Wrap.flow_lines(font, body, font_size, _body_label.original_size.x)
	var per_page: int = floori(_body_label.original_size.y / font.get_height(font_size))
	if not wrapped.get("ok",false) or per_page <= 0: return false
	var lines: PackedStringArray = wrapped.lines
	for first: int in range(0,lines.size(),per_page):
		_pages.append("\n".join(lines.slice(first,first+per_page)))
	if _pages.is_empty() or not _show_page(): return false
	_callback = accept
	_design = design
	_height = kit._node_size(offsets, "Bg/Bg").y
	name = "TwilightConfirmation"
	z_index = 400
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_fit)
	_fit()
	return true

func _button(offsets: Dictionary, suffix: String) -> Control:
	var owner: Node2D = _node(offsets,suffix)
	if owner == null or not owner.has_meta("source_button"): return null
	return owner.get_meta("source_button")._input_area as Control

func _node(offsets: Dictionary, suffix: String) -> Node2D:
	var node: Dictionary = Kit._locate(_scene, offsets, suffix)
	if not node.ok: return null
	return node.player.source_nodes[node.offset]

func _show_page() -> bool:
	var title: String = _title if _pages.size() == 1 else "%s (%d/%d)" % [_title, _page+1, _pages.size()]
	return _title_label.set_source_text(title).ok and _body_label.set_source_text(_pages[_page]).ok and _action_label.set_source_text("다음" if _page+1 < _pages.size() else "확인").ok

func _fit() -> void:
	var scale_factor: float = minf(size.x/_design.x, size.y/_design.y)
	_scene.scale = Vector2.ONE * scale_factor
	_scene.position = (size - Vector2(0,_height*scale_factor)) / 2.0

func dismiss() -> void:
	_callback = Callable()
	hide()
	name = "CompletedConfirmation"
	queue_free()

func _cancel() -> Dictionary:
	dismiss()
	return {"ok":true}

func _accept() -> Dictionary:
	if _page+1 < _pages.size():
		_page += 1
		if not _show_page():
			dismiss()
			return {"ok":false}
		return {"ok":true}
	var apply: Callable = _callback
	dismiss()
	if apply.is_valid(): apply.call(1)
	return {"ok":true}

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		dismiss()
		get_viewport().set_input_as_handled()
