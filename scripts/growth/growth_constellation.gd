extends Control
const Art = preload("res://scripts/growth/growth_art.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
var runtime
var nodes: Array = []
var buttons: Dictionary = {}
var centers: Dictionary = {}
var selected: String = ""
var time: float = 0.0
var pulse: float = 0.0
func configure(rt, rows: Array, hud: Node, scroll: ScrollContainer, chosen: String, on_select: Callable) -> void:
	runtime=rt; nodes=rows; selected=chosen
	custom_minimum_size.y=ceilf(float(nodes.size())/4)*108+24
	for row: Dictionary in nodes:
		var id: String = str(row.id)
		var button := preload("res://scripts/growth/growth_touch_button.gd").new()
		button.name="GuardianNode_"+id
		button.scroll_host=hud.workspace; button.scroll_area=scroll
		button.size=Vector2(76,76)
		button.modulate=Color.WHITE if runtime.state.nodes.has(id) else Color(.48,.48,.6)
		button.icon=Art.sigil(8 if runtime.state.nodes.has(id) else 7)
		button.expand_icon=true
		button.add_theme_constant_override("icon_max_width",38 if row.kind=="stat" else 60)
		button.add_theme_stylebox_override("normal",UI.box(Color(0,0,0,0),Color(0,0,0,0),2))
		button.pressed.connect(func() -> void: on_select.call(id))
		button.tooltip_text=str(row.name)
		add_child(button); buttons[id]=button
		var label:=UI.label(str(row.name).replace(" · 배치 미확인",""),14)
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
func reveal() -> void:
	pulse=1
	create_tween().tween_property(self,"pulse",0.0,1.0)
func _process(delta: float) -> void:
	time+=delta
	queue_redraw()
func _draw() -> void:
	if runtime==null: return
	for row: Dictionary in nodes:
		if not centers.has(row.id): continue
		var center: Vector2=centers[row.id]
		var opened: bool=runtime.state.nodes.has(row.id)
		var radius: float=22 if row.kind=="stat" else 34
		if opened or selected==row.id:
			var tint:=Color("a5e7ed") if selected==row.id else Color("e5c78c")
			for i: int in range(3): draw_circle(center,radius+4+i*3,Color(tint,.025+pulse*.06))
			draw_arc(center,radius+3,0,TAU,48,Color(tint,.6),1.5,true)
			if selected==row.id: draw_arc(center,radius+7,time,time+PI*1.3,48,Color(tint,.8),2,true)
		if not row.get("prerequisites") is Array: continue
		for prerequisite: String in row.prerequisites:
			if not centers.has(prerequisite): continue
			var active: bool=runtime.state.nodes.has(prerequisite)
			var origin: Vector2=centers[prerequisite]
			var direction: Vector2=(center-origin).normalized()
			var start: Vector2=origin+direction*36
			var end: Vector2=center-direction*(radius+3)
			var color:=Color("bd9c62") if active else Color("423c4a")
			draw_line(start,end,color.darkened(.6),5,true)
			draw_line(start,end,color,1.5,true)
			if active:
				var spark: Vector2=start.lerp(end,fmod(time*.35,1.0))
				draw_circle(spark,4,Color("b9dce6" ,.12))
				draw_circle(spark,1.6,Color("f4e7c2"))
