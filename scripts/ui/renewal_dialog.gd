extends Control

signal confirmed
signal canceled
const UI = preload("res://scripts/ui/renewal_theme.gd")
var title_text: String = "확인"
var message_text: String = ""
var card: PanelContainer

func _ready() -> void:
	name = "TwilightConfirmation"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 250
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UI.make_theme()
	var dim := ColorRect.new()
	dim.color = Color(0,0,0,.72)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel",UI.chrome_panel(Color("10131a"),UI.GOLD,18))
	add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",16)
	card.add_child(stack)
	stack.add_child(UI.section(title_text,20))
	stack.add_child(HSeparator.new())
	var copy := UI.label(message_text,14)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.custom_minimum_size.y = 64
	stack.add_child(copy)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	stack.add_child(actions)
	actions.add_child(UI.button("취소",func() -> void: canceled.emit(); queue_free(),Vector2(110,42)))
	actions.add_child(UI.button("확인",func() -> void: confirmed.emit(); queue_free(),Vector2(110,42)))
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	var stretch: float = maxf(.01,get_viewport().get_final_transform().get_scale().x)
	card.scale = Vector2.ONE/maxf(.01,minf(1.0,stretch))
	card.size = Vector2(minf(500,size.x/card.scale.x-24),220)
	card.position = (size-card.size*card.scale)*.5

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		canceled.emit()
		queue_free()
		get_viewport().set_input_as_handled()
