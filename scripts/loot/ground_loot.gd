extends Button
class_name TwilightGroundLoot

const VISUAL = preload("res://scripts/loot/drop_visual.gd")
const GROUND_SOURCE_VIEW = preload("res://scripts/loot/current523_ground_source_view.gd")
const DROP_EFFECT = preload("res://scripts/loot/current523_ground_drop_effect.gd")
const GRADE = preload("res://scripts/loot/current523_item_grade.gd")
const FIELD_CAMERA = preload("res://scripts/maps/field_camera_scale.gd")
var source_drop_effect: Node2D
var source_name_label: Label
var loot_id: String = ""
var visible_since: int = 0
var visual: TwilightDropVisual
var source_ground_view: Node2D
var source_ground_label: Label
var source_ground_status: Dictionary = {}
## Original inventory icon (ItemClass IconID) used when no original floor body
## can be drawn, so a dropped item is never an invisible floor record.
var fallback_icon: Texture2D
var fallback_icon_source: Callable
var fallback_sprite: Sprite2D
var fallback_name_label: Label
var _name_font: FontFile

func configure(record: Dictionary, icon: Texture2D, slot: String, source_ground: Dictionary = {}, inventory_icon: Callable = Callable(), name_font: FontFile = null) -> void:
	fallback_icon_source = inventory_icon
	_name_font = name_font
	loot_id = str(record["id"])
	name = "GroundLoot_" + loot_id
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(56, 52)
	size = custom_minimum_size
	position = Vector2(float(record["position"][0]), float(record["position"][1])) - Vector2(28, 36)
	z_index = 20
	visible_since = Time.get_ticks_msec()
	for key: String in ["id", "item_name", "grade", "quantity"]:
		set_meta(key, record[key])
	var item_record: Variant = record.get("item_record")
	if item_record is Dictionary and item_record.get("source_m_native_item") == true:
		set_meta("source_display_name",str(preload("res://scripts/loot/current523_native_fields.gd").field(item_record,"source_display_name","")))
	elif source_ground.get("identity_only",false):
		set_meta("source_display_name",preload("res://scripts/ui/source523_item_identity.gd").display_name(item_record if item_record is Dictionary else {},str(record["item_name"])))
	set_meta("world_position", Vector2(float(record["position"][0]), float(record["position"][1])))
	tooltip_text = "%s ×%d" % [preload("res://scripts/ui/source523_item_identity.gd").plain_text(str(record["item_name"])), record["quantity"]]
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, empty)
	visual = VISUAL.new()
	visual.position = Vector2(28, 36)
	visual.configure(str(record["grade"]), null if source_ground.get("required",false) else icon, slot)
	visual.source_missing=not source_ground.get("required",false) and icon==null and record.get("item_record") is Dictionary and preload("res://scripts/cards/source_awakening_items.gd").recognized(record.item_record)
	if visual.source_missing:
		pass # No developer text on the floor (2026-11-20); the slot stays empty.
	add_child(visual)
	if source_ground.get("required",false): configure_source_ground(source_ground)
	_refresh_fallback()

func configure_source_ground(request: Dictionary) -> void:
	if not request.get("required",false) or not is_instance_valid(visual): return
	# Keep the existing grade beam, selection ring and Button hit target. The
	# source item body comes only from ItemClass.SpriteID in the pinned SP2 bank.
	visual.source_missing = true
	visual.procedural_beam = false
	visual.set_process(false)
	visual.texture = null
	if is_instance_valid(visual.source_icon):
		visual.source_icon.queue_free()
		visual.source_icon = null
	visual.queue_redraw()
	if is_instance_valid(source_ground_view): source_ground_view.free()
	source_ground_view = GROUND_SOURCE_VIEW.new()
	source_ground_view.connect("source_status_changed",_on_source_ground_status)
	visual.add_child(source_ground_view)
	var configured: bool = source_ground_view.call("configure_ground_source",request.get("original_item",{}),request.get("source_bank_context",{}),request.get("source_binding",{}),request.get("source_owner_context",{}),loot_id)
	source_ground_status = source_ground_view.get("selection_status").duplicate(true)
	if not configured and source_ground_status.get("reason") == "current523_ground_original_member_and_renderer_role_unresolved":
		var body := DROP_EFFECT.new()
		visual.add_child(body)
		if body.configure_body(request.get("original_item",{}),request.get("source_bank_context",{})):
			configured = true
			source_ground_status = {"ok":true,"status":"selected_body_action","sprite_id":body.status.sprite_id,"action":body.status.action,"basis":body.status.basis,"static_picture_status":source_ground_status.get("static_picture_status",{})}
		else:
			source_ground_status["body_action_status"] = body.status.duplicate(true)
			body.queue_free()
	if not is_instance_valid(source_ground_label):
		source_ground_label = Label.new()
		source_ground_label.text = "" # No developer text on the floor (2026-11-20).
		source_ground_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		source_ground_label.position = Vector2(20,46)
		source_ground_label.add_theme_font_size_override("font_size",10)
		add_child(source_ground_label)
	source_ground_label.visible = not configured
	_configure_source_presentation(request)

## Original drop effect behind the item body, and the item name over it in
## the original grade color (Grade.ColorID -> ColorTable). Nothing is shown
## in place of a missing original effect or color.
func _configure_source_presentation(request: Dictionary) -> void:
	var original: Dictionary = request.get("original_item",{})
	if is_instance_valid(source_drop_effect): source_drop_effect.free()
	source_drop_effect = DROP_EFFECT.new()
	source_drop_effect.z_index = -1
	visual.add_child(source_drop_effect)
	visual.move_child(source_drop_effect,0)
	source_drop_effect.configure(original,request.get("source_bank_context",{}))
	set_meta("source_drop_effect",source_drop_effect.status.duplicate(true))
	var color: Dictionary = GRADE.color_info({"source_grade_id":original.get("GradeID")})
	var title: String = str(get_meta("source_display_name",""))
	set_meta("source_name_color",color.duplicate(true))
	if title.is_empty() or not color.get("ok",false):
		if is_instance_valid(source_name_label): source_name_label.hide()
		return
	if not is_instance_valid(source_name_label):
		source_name_label = Label.new()
		source_name_label.name = "SourceItemName"
		source_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		source_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if _name_font != null: source_name_label.add_theme_font_override("font",_name_font)
		source_name_label.add_theme_font_size_override("font_size",11)
		source_name_label.add_theme_constant_override("outline_size",3)
		source_name_label.add_theme_color_override("font_outline_color",Color(0,0,0,0.9))
		add_child(source_name_label)
	source_name_label.text = title if int(get_meta("quantity",1)) <= 1 else "%s (%d)" % [title,int(get_meta("quantity",1))]
	source_name_label.add_theme_color_override("font_color",color.color)
	source_name_label.size = Vector2(160,16)
	source_name_label.position = Vector2(28-80,-14)
	FIELD_CAMERA.keep_screen_size(source_name_label, Vector2(80,8))
	source_name_label.show()

func _on_source_ground_status(status: Dictionary) -> void:
	source_ground_status = status.duplicate(true)
	if is_instance_valid(source_ground_label): source_ground_label.visible = not status.get("ok",false)
	_refresh_fallback()

## True when the floor shows a picture of the item (original floor body or an
## original texture on the visual).
func body_drawn() -> bool:
	if not is_instance_valid(visual): return false
	if visual.texture != null and not visual.source_missing: return true
	return source_ground_status.get("ok",false) == true or source_ground_status.get("status") == "selected_body_action"

## An item whose original floor body cannot be drawn (no ItemClass row for a
## legacy catalog name, a missing SP2 sprite ...) still shows its original
## inventory icon and its name, so the floor record can be seen and picked up
## (user 2026-11-20: "바닥에 안떨어지고 삭제되고").
func _refresh_fallback() -> void:
	var drawn: bool = body_drawn()
	if not drawn and fallback_icon == null and fallback_icon_source.is_valid():
		var resolved: Variant = fallback_icon_source.call()
		fallback_icon_source = Callable()
		if resolved is Texture2D: fallback_icon = resolved
	if not drawn and fallback_icon != null and not is_instance_valid(fallback_sprite) and is_instance_valid(visual):
		fallback_sprite = Sprite2D.new()
		fallback_sprite.name = "InventoryIconFallback"
		fallback_sprite.texture = fallback_icon
		fallback_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fallback_sprite.position = Vector2(0,-14)
		var size: Vector2 = fallback_icon.get_size()
		if size.x > 0 and size.y > 0: fallback_sprite.scale = Vector2.ONE * (32.0 / maxf(size.x,size.y))
		visual.add_child(fallback_sprite)
	if is_instance_valid(fallback_sprite): fallback_sprite.visible = not drawn
	var named: bool = is_instance_valid(source_name_label) and source_name_label.visible
	if not drawn and not named and not is_instance_valid(fallback_name_label):
		fallback_name_label = Label.new()
		fallback_name_label.name = "FloorItemName"
		fallback_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if _name_font != null: fallback_name_label.add_theme_font_override("font",_name_font)
		fallback_name_label.add_theme_font_size_override("font_size",11)
		fallback_name_label.add_theme_constant_override("outline_size",3)
		fallback_name_label.add_theme_color_override("font_outline_color",Color(0,0,0,0.9))
		var title: String = str(get_meta("source_display_name",""))
		if title.is_empty(): title = preload("res://scripts/ui/source523_item_identity.gd").plain_text(str(get_meta("item_name","")))
		var quantity: int = int(get_meta("quantity",1))
		fallback_name_label.text = title if quantity <= 1 else "%s (%d)" % [title,quantity]
		fallback_name_label.add_theme_color_override("font_color",VISUAL.grade_color(str(get_meta("grade","일반"))))
		fallback_name_label.size = Vector2(160,16)
		fallback_name_label.position = Vector2(28-80,-14)
		add_child(fallback_name_label)
		FIELD_CAMERA.keep_screen_size(fallback_name_label, Vector2(80,8))
	if is_instance_valid(fallback_name_label): fallback_name_label.visible = not drawn and not named

func set_selected(value: bool) -> void:
	visual.selected = value
	visual.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	# Native touch is independent of desktop mouse emulation.
	if event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and not event.canceled:
			pressed.emit()
		accept_event()
