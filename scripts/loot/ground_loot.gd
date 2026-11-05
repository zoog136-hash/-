extends Button
class_name TwilightGroundLoot

const VISUAL = preload("res://scripts/loot/drop_visual.gd")
const GROUND_SOURCE_VIEW = preload("res://scripts/loot/current523_ground_source_view.gd")
var loot_id: String = ""
var visible_since: int = 0
var visual: TwilightDropVisual
var source_ground_view: Node2D
var source_ground_label: Label
var source_ground_status: Dictionary = {}

func configure(record: Dictionary, icon: Texture2D, slot: String, source_ground: Dictionary = {}) -> void:
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
	set_meta("world_position", Vector2(float(record["position"][0]), float(record["position"][1])))
	tooltip_text = "%s · %s ×%d · 선택 후 다시 눌러 줍기" % [record["item_name"], record["grade"], record["quantity"]]
	var proof: Dictionary = record.get("item_record", {}).get("source_m_drop_proof", {})
	if proof.get("source_snapshot") == "patch523":
		tooltip_text += "\n523 드랍원 #%d · %s · TWILIGHT 확률·수량" % [int(proof.get("source_npc_id", 0)), {1:"일반", 2:"축복", 3:"저주"}.get(int(proof.get("bless_raw", 0)), "미지원 상태")]
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, empty)
	visual = VISUAL.new()
	visual.position = Vector2(28, 36)
	visual.configure(str(record["grade"]), null if source_ground.get("required",false) else icon, slot)
	visual.source_missing=not source_ground.get("required",false) and icon==null and record.get("item_record") is Dictionary and preload("res://scripts/cards/source_awakening_items.gd").recognized(record.item_record)
	if visual.source_missing:
		var missing:=Label.new();missing.text="원본 미설치";missing.mouse_filter=Control.MOUSE_FILTER_IGNORE
		missing.position=Vector2(-8,10);missing.add_theme_font_size_override("font_size",10);add_child(missing)
	add_child(visual)
	if source_ground.get("required",false): configure_source_ground(source_ground)

func configure_source_ground(request: Dictionary) -> void:
	if not request.get("required",false) or not is_instance_valid(visual): return
	# Keep the existing grade beam, selection ring and Button hit target. The
	# source item body comes only from ItemClass.SpriteID in the pinned SP2 bank.
	visual.source_missing = true
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
	if not is_instance_valid(source_ground_label):
		source_ground_label = Label.new()
		source_ground_label.text = "원본 지면 표시 대기"
		source_ground_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		source_ground_label.position = Vector2(20,46)
		source_ground_label.add_theme_font_size_override("font_size",10)
		add_child(source_ground_label)
	source_ground_label.visible = not configured

func _on_source_ground_status(status: Dictionary) -> void:
	source_ground_status = status.duplicate(true)
	if is_instance_valid(source_ground_label): source_ground_label.visible = not status.get("ok",false)

func set_selected(value: bool) -> void:
	visual.selected = value
	visual.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	# Native touch is independent of desktop mouse emulation.
	if event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and not event.canceled:
			pressed.emit()
		accept_event()
