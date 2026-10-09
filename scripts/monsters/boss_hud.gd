extends CanvasLayer

var panel: PanelContainer
var title: Label
var bar: ProgressBar
var controller: Node

func _ready() -> void:
	layer = 13
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("20151ee8")
	style.border_color = Color("bc8758")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color",Color("f5d49c"))
	title.add_theme_font_size_override("font_size",19)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(460,18)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("c74657")
	bar.add_theme_stylebox_override("fill",fill)
	column.add_child(bar)
	panel.hide()

func _process(_delta: float) -> void:
	if not is_instance_valid(controller): return
	var nearest: TwilightMonster = null
	var distance: float = 1000.0
	for slot: Dictionary in controller.slots:
		if str(slot.region.get("mode","")) != "boss": continue
		var monster: TwilightMonster = slot.monster as TwilightMonster if is_instance_valid(slot.monster) else null
		if not is_instance_valid(monster) or monster.dead: continue
		var d: float = monster.global_position.distance_to(controller.world.player.global_position)
		if d < distance: distance = d; nearest = monster
	panel.visible = is_instance_valid(nearest)
	if not panel.visible: return
	panel.position = Vector2((get_viewport().get_visible_rect().size.x-492)*.5,98)
	title.text = nearest.monster_name + (" · 격노" if nearest.hp*2<nearest.max_hp else "")
	bar.max_value = nearest.max_hp
	bar.value = nearest.hp
