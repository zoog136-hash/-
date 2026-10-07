extends Control
class_name FieldMinimap

const COORD = preload("res://scripts/maps/world_coordinates.gd")
var world: Node
var field: PlayableField
var bounds := Rect2(0,0,1,1)
var clock: float = 0.0
var area := Rect2(9,27,204,136)

func configure(controller: Node, value: PlayableField) -> void:
	world = controller
	field = value
	bounds = field.bounds if field != null else Rect2(Vector2.ZERO,world.world_size)
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	tooltip_text = "클릭: 이동 경로 · 청록: 이동석 · 금색: 마을 · 빨강: 보스"

func _process(delta: float) -> void:
	clock -= delta
	if clock <= 0.0:
		clock = .12
		queue_redraw()

func _point(p: Vector2) -> Vector2:
	return COORD.world_to_minimap(p,bounds,area)

func _draw() -> void:
	if world == null:
		return
	draw_style_box(_panel(),Rect2(Vector2.ZERO,size))
	draw_rect(area,Color("202e27"))
	var font: Font = get_theme_default_font()
	draw_string(font,Vector2(10,18),"ADEN  /  WORLD" if field != null else "REGION  /  MAP",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("decfae"))
	if field != null:
		for region: Dictionary in field.data["regions"]:
			var p: Vector2 = _point(COORD.array_vector(region["center"]))
			var r: float = float(region["radius"])/bounds.size.x*area.size.x
			var color := Color(str(region["color"]),.3)
			draw_circle(p,r,color)
			draw_arc(p,r,0,TAU,24,Color(color,.5),1,true)
		for water: Dictionary in field.data["water"]:
			var points := PackedVector2Array()
			for p: Array in water["polygon"]:
				points.append(_point(COORD.array_vector(p)))
			draw_colored_polygon(points,Color("4c7e84"))
		for road: Dictionary in field.data["roads"]:
			var points := PackedVector2Array()
			for p: Array in road["points"]:
				points.append(_point(COORD.array_vector(p)))
			draw_polyline(points,Color("b7a378"),1.7,true)
		for npc: Dictionary in field.data["npc_spawn"]:
			draw_circle(_point(COORD.array_vector(npc["position"])),2.0,Color("e6c16f"))
		for portal: Dictionary in field.data["portal"]:
			draw_circle(_point(COORD.array_vector(portal["position"])),3.0,Color("7fddd1"))
		for region: Dictionary in field.data["regions"]:
			if str(region["type"]) in ["safe","boss"]:
				draw_circle(_point(COORD.array_vector(region["center"])),3.0,Color("e6c16f") if str(region["type"])=="safe" else Color("dd7762"))
	for monster: TwilightMonster in world.monsters_root.get_children():
		if monster.global_position.distance_squared_to(world.player.global_position) < 1600000:
			draw_circle(_point(monster.global_position),1.3,Color("d68b73"))
	var camera: Camera2D = world.player.camera
	var extent: Vector2 = get_viewport_rect().size / camera.zoom
	var top: Vector2 = _point(camera.get_screen_center_position()-extent*.5)
	var bottom: Vector2 = _point(camera.get_screen_center_position()+extent*.5)
	draw_rect(Rect2(top,bottom-top).intersection(area),Color(1,1,1,.18),false,1)
	var p: Vector2 = _point(world.player.global_position)
	var direction: Vector2 = [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT][world.player.facing]
	var side := Vector2(-direction.y,direction.x)
	draw_circle(p,5,Color("101a18"))
	draw_colored_polygon(PackedVector2Array([p+direction*6,p-direction*3+side*3,p-direction*3-side*3]),Color("faf0bb"))
	var title: String = "지역 지도"
	if field != null:
		var region: Dictionary = field.region_at(world.player.global_position)
		title = str(region["name"]) + (" · 안전" if str(region["type"])=="safe" else " · 사냥터")
	draw_string(font,Vector2(9,181),title,HORIZONTAL_ALIGNMENT_LEFT,204,12,Color("d7ceba"))

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.035,.045,.036,.93)
	style.border_color = Color("726448")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if pressed and area.has_point(event.position):
		world._set_click_destination(COORD.minimap_to_world(event.position,bounds,area))
		accept_event()
