extends Control
const Art = preload("res://scripts/growth/growth_art.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
var runtime
var nodes: Array = []
var buttons: Dictionary = {}
var centers: Dictionary = {}
var selected: String = ""
func configure(rt, rows: Array, hud: Node, scroll: ScrollContainer, chosen: String, on_select: Callable) -> void:
	runtime=rt; nodes=rows; selected=chosen
	custom_minimum_size.y=ceilf(float(nodes.size())/4)*108+24
	for row: Dictionary in nodes:
		var id: String = str(row.id)
		var button := preload("res://scripts/growth/growth_touch_button.gd").new()
		button.name="GuardianNode_"+id
		button.scroll_host=hud.workspace; button.scroll_area=scroll
		button.size=Vector2(76,76)
		button.icon=Art.sigil(8 if runtime.state.nodes.has(id) else 7)
		button.expand_icon=true
		button.add_theme_constant_override("icon_max_width",70)
		button.add_theme_stylebox_override("normal",UI.box(Color(0,0,0,.25),UI.GOLD if selected==id else Color("554638"),2))
		button.pressed.connect(func() -> void: on_select.call(id))
		button.tooltip_text=str(row.name)
		add_child(button); buttons[id]=button
		var label:=UI.label(str(row.name).replace(" · 배치 미확인",""),12)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		label.position=Vector2(-22,78);label.size=Vector2(120,22)
		button.add_child(label)
	resized.connect(_layout)
	_layout()
func _layout() -> void:
	centers.clear()
	for i: int in range(nodes.size()):
		var row_index: int = i/4
		var col: int = i%4 if row_index%2==0 else 3-i%4
		var center := Vector2((float(col)+.5)*size.x/4,55+row_index*108)
		centers[nodes[i].id]=center
		buttons[nodes[i].id].position=center-Vector2(38,38)
	queue_redraw()
func _draw() -> void:
	if runtime==null: return
	for row: Dictionary in nodes:
		if not row.get("prerequisites") is Array: continue
		for prerequisite: String in row.prerequisites:
			if not centers.has(prerequisite): continue
			var active: bool=runtime.state.nodes.has(prerequisite)
			var color:=Color("d4b36c") if active else Color("534951")
			draw_line(centers[prerequisite],centers[row.id],color.darkened(.6),7,true)
			draw_line(centers[prerequisite],centers[row.id],color,2,true)
