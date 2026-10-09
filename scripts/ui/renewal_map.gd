extends "res://scripts/maps/field_minimap.gd"

const UI = preload("res://scripts/ui/renewal_theme.gd")

func _ready() -> void:
	super._ready()
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var room := size-Vector2(24,88)
	var extent := Vector2(room.x,minf(room.y,room.x*bounds.size.y/bounds.size.x))
	extent.x=minf(extent.x,extent.y*bounds.size.x/bounds.size.y)
	area=Rect2(Vector2((size.x-extent.x)*.5,42),extent)
	queue_redraw()

func configure(controller: Node, value: PlayableField) -> void:
	super.configure(controller,value)
	_layout()

func _draw() -> void:
	if world==null or field==null: return
	draw_style_box(UI.box(Color("111a1c"),UI.BRONZE,0),Rect2(Vector2.ZERO,size))
	draw_rect(area,Color("24362e"))
	var font := get_theme_default_font()
	draw_string(font,Vector2(14,26),"현재 지역 상세 지도",HORIZONTAL_ALIGNMENT_LEFT,size.x-28,17,UI.GOLD)
	for surface: Dictionary in field.data.get("surfaces",[]):
		var rect: Array=surface["rect"]
		var top := _point(Vector2(float(rect[0]),float(rect[1])))
		var end := _point(Vector2(float(rect[0])+float(rect[2]),float(rect[1])+float(rect[3])))
		draw_rect(Rect2(top,end-top),Color("4b5156"))
	for region: Dictionary in field.data.get("regions",[]):
		var point := _point(COORD.array_vector(region["center"]))
		var radius := float(region["radius"])/bounds.size.x*area.size.x
		var color := Color(str(region["color"]),.25)
		draw_circle(point,radius,color)
		draw_arc(point,radius,0,TAU,48,Color(color,.65),1,true)
	for water: Dictionary in field.data.get("water",[]):
		var points := PackedVector2Array()
		for value: Array in water["polygon"]: points.append(_point(COORD.array_vector(value)))
		draw_colored_polygon(points,Color(str(water.get("shallow_color","4c7e84"))))
	for road: Dictionary in field.data.get("roads",[]):
		var points := PackedVector2Array()
		for value: Array in road["points"]: points.append(_point(COORD.array_vector(value)))
		draw_polyline(points,Color("b7a378"),3,true)
	for pair: Array in [["npc_spawn",Color("e6c16f")],["portal",Color("7fddd1")]]:
		for entry: Dictionary in field.data.get(str(pair[0]),[]):
			var point := _point(COORD.array_vector(entry["position"]))
			draw_circle(point,5,pair[1])
			draw_arc(point,8,0,TAU,24,Color(pair[1],.6),1,true)
	for monster: TwilightMonster in world.monsters_root.get_children():
		if not monster.dead: draw_circle(_point(monster.global_position),2,Color("cf7967"))
	var player_point := _point(world.player.global_position)
	draw_circle(player_point,8,Color("0a171b"))
	draw_circle(player_point,4,Color("faf0bb"))
	draw_line(player_point-Vector2(12,0),player_point+Vector2(12,0),UI.GOLD,1)
	draw_line(player_point-Vector2(0,12),player_point+Vector2(0,12),UI.GOLD,1)
	var region: Dictionary=field.region_at(world.player.global_position)
	draw_string(font,Vector2(14,size.y-15),str(region.get("name",""))+"  ·  지도 클릭: 기존 이동 경로 지정",HORIZONTAL_ALIGNMENT_LEFT,size.x-28,12,UI.MUTED)
