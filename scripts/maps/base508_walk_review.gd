extends "res://scripts/maps/base508_review.gd"
## Opt-in movement on registered existing collision, never unknown M terrain.
const REGISTERED_NAV = preload("res://scripts/maps/base508_registered_navigation.gd")
var navigation = REGISTERED_NAV.new()
var legacy_position: Vector2 = Vector2.INF
var actor: Polygon2D
var walk_ready: bool = false
var moved_distance: float = 0.0
var rejected_moves: int = 0
var autoplay: bool = false
var autoplay_start: Vector2

func _ready() -> void:
	super._ready()
	if camera==null: return
	var certificate: String=""
	var legacy_root: String=""
	var mid: String="albino_01"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--registration="):certificate=arg.trim_prefix("--registration=")
		if arg.begins_with("--legacy-art-root="):legacy_root=arg.trim_prefix("--legacy-art-root=")
		if arg.begins_with("--legacy-map="):mid=arg.trim_prefix("--legacy-map=")
		if arg=="--walk-proof":autoplay=true
	if not navigation.configure(pack,certificate,legacy_root,mid):
		label.text+="Movement unavailable: "+navigation.error;return
	legacy_position=navigation.spawn()
	autoplay_start=legacy_position
	actor=Polygon2D.new()
	actor.polygon=PackedVector2Array([Vector2(0,-18),Vector2(9,-6),Vector2(6,0),Vector2(-6,0),Vector2(-9,-6)])
	actor.color=Color("ffcc44")
	actor.z_index=40
	add_child(actor)
	camera.zoom=Vector2.ONE
	walk_ready=true
	capture_after=150
	label.text=label.text.replace("WASD/arrows: camera pan","WASD/arrows: review actor movement").replace("terrain collision: UNKNOWN / movement blocked","M terrain: UNKNOWN; registered legacy collision active")
	label.text+="Registered legacy collision review: WASD moves the yellow actor; original M terrain remains UNKNOWN\n"
	print("BASE508_WALK_READY ",JSON.stringify({"legacy_map":mid,"source_map":pack.source_map_key(),"legacy_spawn":[legacy_position.x,legacy_position.y],"M_terrain_enabled":false}))

func _process(delta: float) -> void:
	if walk_ready:
		var direction:=Input.get_vector("move_left","move_right","move_up","move_down")
		if autoplay:direction=Vector2.RIGHT if frames<75 else Vector2.LEFT
		var target: Vector2=legacy_position+direction*90*delta
		var accepted: Vector2=navigation.move(legacy_position,target)
		if direction!=Vector2.ZERO and accepted==legacy_position:rejected_moves+=1
		moved_distance+=legacy_position.distance_to(accepted)
		legacy_position=accepted
		actor.position=navigation.to_render(legacy_position)
		camera.position=actor.position-Vector2(0,110)
	super._process(delta)
	if walk_ready:camera.position=actor.position-Vector2(0,110)

func capture() -> void:
	print("BASE508_WALK_EVIDENCE ",JSON.stringify({"moved_legacy_pixels":moved_distance,"rejected_moves":rejected_moves,"legacy_position":[legacy_position.x,legacy_position.y],"source_terrain_confirmed":false,"original_collision_checks_preserved":true}))
	await super.capture()
