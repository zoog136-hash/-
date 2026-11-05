extends Node2D
## Borrows an existing owner editor; never creates another input or owns its query.
signal unsupported_input(result: Dictionary)
var _editor: LineEdit
var _font: FontFile
var _options: Dictionary
var _extent: Vector2
var _saved: Dictionary = {}
var _parent: WeakRef
var _index: int
var _attached: bool = false
const PROPERTIES = ["position","size","custom_minimum_size","rotation","scale","pivot_offset","anchor_left","anchor_top","anchor_right","anchor_bottom","offset_left","offset_top","offset_right","offset_bottom","grow_horizontal","grow_vertical","size_flags_horizontal","size_flags_vertical","layout_mode","mouse_filter","focus_mode","visible","modulate","self_modulate","z_index","z_as_relative","clip_contents","theme","theme_type_variation","editable","placeholder_text","max_length","secret","secret_character","alignment","expand_to_text_length","clear_button_enabled","select_all_on_focus","caret_blink","caret_force_displayed","context_menu_enabled","shortcut_keys_enabled","virtual_keyboard_enabled","virtual_keyboard_type","mouse_default_cursor_shape","tooltip_text"]

func configure(font: FontFile, options: Dictionary, extent: Vector2, editor: LineEdit) -> Dictionary:
	if _attached: return _fail("source_text_field_already_attached")
	if not is_instance_valid(editor) or editor.is_queued_for_deletion(): return _fail("source_text_field_existing_editor_required")
	if font == null or extent.x <= 0 or extent.y <= 0 or not extent.is_finite(): return _fail("source_text_field_original_font_and_extent_required")
	if options.get("passwordEnabled",false): return _fail("source_text_field_password_not_implemented")
	if int(options.get("fontSize",0)) <= 0: return _fail("source_text_field_font_size_required")
	var widget: Dictionary = options.get("widgetOptions",{})
	for key: String in ["callBackName","callBackType","frameEvent"]:
		if not str(widget.get(key,"")).is_empty(): return _fail("source_text_field_custom_callback_not_implemented")
	if bool(widget.get("flipX",false)) or bool(widget.get("flipY",false)): return _fail("source_text_field_flip_not_implemented")
	if bool(options.get("maxLengthEnabled",false)) and (int(options.get("maxLength",0)) <= 0 or editor.text.length() > int(options.maxLength)):
		return _fail("source_text_field_owner_query_exceeds_original_limit")
	for value: String in [editor.text,str(options.get("placeHolder",""))]:
		for index: int in range(value.length()):
			if not value[index].strip_edges().is_empty() and not font.has_char(value.unicode_at(index)): return _fail("source_text_field_original_glyph_missing")
	_editor = editor
	_font = font
	_options = options.duplicate(true)
	_extent = extent
	return {"ok":true,"editor_moved":false}

func attach_editor() -> Dictionary:
	if _attached: return {"ok":true,"attached":true}
	if not is_inside_tree() or not is_instance_valid(_editor) or _editor.get_parent() == null: return _fail("source_text_field_live_mount_and_owner_parent_required")
	var prepared: Dictionary = configure(_font,_options,_extent,_editor)
	if not prepared.get("ok",false): return prepared
	_parent = weakref(_editor.get_parent())
	_index = _editor.get_index()
	_saved = {"properties":{},"overrides":{},"focused":_editor.has_focus(),"caret":_editor.caret_column,"selection":_editor.has_selection(),"selection_from":_editor.get_selection_from_column(),"selection_to":_editor.get_selection_to_column()}
	for property: String in PROPERTIES: _saved.properties[property] = _editor.get(property)
	for property: Dictionary in _editor.get_property_list():
		var key: String = property.name
		if key.begins_with("theme_override_"): _saved.overrides[key] = _editor.get(key)
	_editor.reparent(self,false)
	_attached = true
	_editor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_editor.custom_minimum_size = Vector2.ZERO
	_editor.position = Vector2(0,-_extent.y)
	_editor.size = _extent
	_editor.rotation = 0
	_editor.scale = Vector2.ONE
	_editor.pivot_offset = Vector2.ZERO
	_editor.visible = true
	_editor.modulate = Color.WHITE
	_editor.self_modulate = Color.WHITE
	_editor.z_index = 0
	_editor.z_as_relative = true
	_editor.theme = null
	_editor.theme_type_variation = ""
	_editor.add_theme_font_override("font",_font)
	_editor.add_theme_font_size_override("font_size",int(_options.fontSize))
	var empty := StyleBoxEmpty.new()
	for key: String in ["normal","focus","read_only"]: _editor.add_theme_stylebox_override(key,empty)
	var color: Color = Color.WHITE
	_editor.add_theme_color_override("font_color",color)
	# Cocos 3.6 TextFieldTTF's original default placeholder is opaque 127 gray.
	_editor.add_theme_color_override("font_placeholder_color",Color(127.0/255.0,127.0/255.0,127.0/255.0,1.0))
	_editor.add_theme_color_override("font_outline_color",Color.TRANSPARENT)
	_editor.add_theme_constant_override("outline_size",0)
	_editor.placeholder_text = str(_options.get("placeHolder",""))
	_editor.max_length = int(_options.maxLength) if bool(_options.get("maxLengthEnabled",false)) else 0
	_editor.secret = false
	_editor.clear_button_enabled = false
	_editor.context_menu_enabled = false
	_editor.expand_to_text_length = false
	_editor.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_editor.mouse_filter = Control.MOUSE_FILTER_STOP
	_editor.focus_mode = Control.FOCUS_ALL
	_editor.editable = true
	if not _editor.text_changed.is_connected(_text_changed): _editor.text_changed.connect(_text_changed)
	if not tree_exiting.is_connected(release_editor): tree_exiting.connect(release_editor)
	return {"ok":true,"attached":true,"editor":_editor,"extent":_extent,"owner_signals_preserved":true}

func release_editor() -> void:
	if not _attached: return
	_attached = false
	if not is_instance_valid(_editor): return
	if _editor.text_changed.is_connected(_text_changed): _editor.text_changed.disconnect(_text_changed)
	var original: Object = _parent.get_ref() if _parent != null else null
	if is_instance_valid(original):
		_editor.reparent(original,false)
		original.move_child(_editor,mini(_index,original.get_child_count()-1))
	else:
		# Do not let this temporary scene destroy an independently owned editor.
		if _editor.get_parent() == self: remove_child(_editor)
	for property: Dictionary in _editor.get_property_list():
		var key: String = property.name
		if key.begins_with("theme_override_"): _editor.set(key,null)
	for key: String in _saved.overrides: _editor.set(key,_saved.overrides[key])
	for key: String in PROPERTIES: _editor.set(key,_saved.properties[key])
	_editor.caret_column = mini(int(_saved.caret),_editor.text.length())
	if _saved.selection: _editor.select(int(_saved.selection_from),int(_saved.selection_to))
	else: _editor.deselect()
	if not _saved.focused and _editor.has_focus(): _editor.release_focus()
	if _saved.focused and _editor.is_inside_tree() and _editor.is_visible_in_tree(): _editor.grab_focus()
	_parent = null
	_saved.clear()

func _text_changed(value: String) -> void:
	for index: int in range(value.length()):
		if not value[index].strip_edges().is_empty() and not _font.has_char(value.unicode_at(index)):
			release_editor()
			unsupported_input.emit(_fail("source_text_field_original_glyph_missing"))
			return

func input_control() -> Control:
	return _editor if _attached and is_instance_valid(_editor) else null

static func _fail(error: String) -> Dictionary:
	return {"ok":false,"error":error}
