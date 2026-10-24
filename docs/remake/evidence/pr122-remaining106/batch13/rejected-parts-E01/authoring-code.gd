extends SceneTree
## Golem authoring only: independent complete parts, fixed-length limb IK,
## constant opaque foot shape and alternating support. No production install.

const SOURCE := "res://docs/remake/evidence/pr122-remaining106/batch13/rig-parts-E-v01.png"
const ROOT_POINT := Vector2(130, 356)
const OUTPUT_POINT := Vector2(128, 160)
const OUTPUT_SCALE := 0.42
const CORE_SCALE := 0.52
const CORE_ANCHOR := Vector2(272, 425)
const BIND_HIPS := Vector2(135, 241)
const PARTS := [
	[Rect2(95,9,280,458), Vector2(272,425), Vector2(274,190), CORE_SCALE],
	[Rect2(503,60,211,407), Vector2(671,145), Vector2(638,437), 0.25],
	[Rect2(805,62,255,394), Vector2(866,104), Vector2(987,382), 0.30],
	[Rect2(85,479,230,364), Vector2(118,552), Vector2(248,811), 0.25],
	[Rect2(514,495,221,351), Vector2(583,535), Vector2(681,797), 0.25],
	[Rect2(825,501,205,304), Vector2(870,553), Vector2(977,766), 0.22],
	[Rect2(119,854,174,288), Vector2(216,893), Vector2(213,1114), 0.24],
	[Rect2(422,948,290,158), Vector2(485,990), Vector2(679,1085), 0.18],
	[Rect2(822,849,179,289), Vector2(958,888), Vector2(878,1110), 0.205],
	[Rect2(158,1151,154,274), Vector2(227,1188), Vector2(248,1397), 0.20],
	[Rect2(435,1249,275,148), Vector2(499,1297), Vector2(680,1380), 0.16],
]
const NEAR_SHOULDER := Vector2(138,198)
const FAR_SHOULDER := Vector2(361,210)
const NEAR_HIP := Vector2(206,429)
const FAR_HIP := Vector2(344,427)

var output := ""
var displays: Array[Sprite2D] = []

func _initialize() -> void:
	output = OS.get_environment("TWILIGHT_GOLEM_PARTS_OUTPUT")
	if not output.begins_with("/workspace/"):
		printerr("Explicit /workspace authoring output required")
		quit(2)
		return
	call_deferred("_bake")

func _core_map(point: Vector2, delta: Vector2, angle: float) -> Vector2:
	return BIND_HIPS + delta + ((point - CORE_ANCHOR) * CORE_SCALE).rotated(angle)

func _length(index: int) -> float:
	return PARTS[index][1].distance_to(PARTS[index][2]) * PARTS[index][3]

func _joint(a: Vector2, c: Vector2, first: float, second: float, side: float) -> Vector2:
	var distance := a.distance_to(c)
	assert(distance < first + second and distance > absf(first-second), "Unreachable limb target; re-author rather than stretch")
	var axis := (c-a).normalized()
	var along := (first*first-second*second+distance*distance)/(2.0*distance)
	var across := sqrt(maxf(0.0,first*first-along*along))
	return a + axis*along + Vector2(-axis.y,axis.x)*across*side

func _step(phase: float) -> Vector2:
	var p := fposmod(phase,1.0)
	var half_step := 82.0*0.48/4.0/(86.0/349.0)
	if p < 0.5:
		return Vector2(half_step*(1.0-4.0*p),0.0)
	var swing := (p-0.5)*2.0
	return Vector2(-half_step*cos(PI*swing),-18.0*sin(PI*swing))

func _place(index: int, a: Vector2, c: Vector2) -> void:
	var source_vector: Vector2 = PARTS[index][2]-PARTS[index][1]
	var target_vector := c-a
	var angle := target_vector.angle()-source_vector.angle()
	var part_scale := target_vector.length()/source_vector.length()
	var sprite := displays[index]
	sprite.rotation = angle
	sprite.scale = Vector2.ONE*part_scale*OUTPUT_SCALE
	sprite.position = OUTPUT_POINT + (a-ROOT_POINT)*OUTPUT_SCALE - ((PARTS[index][1]-PARTS[index][0].position)*part_scale*OUTPUT_SCALE).rotated(angle)

func _pose(phase: float, walking: bool) -> Dictionary:
	var near_step := _step(phase) if walking else Vector2.ZERO
	var far_step := _step(phase+0.5) if walking else Vector2.ZERO
	var delta := Vector2(1.5*sin(TAU*phase),8.0+2.0*sin(TAU*2.0*phase)) if walking else Vector2(0.0,phase*2.0)
	var lean := 0.025 if walking else phase*0.006
	var core_a := _core_map(PARTS[0][1],delta,lean)
	var core_c := _core_map(PARTS[0][2],delta,lean)
	_place(0,core_a,core_c)
	var feet: Array = []
	for spec in [[5,6,7,NEAR_HIP,Vector2(126,335),near_step],
		[8,9,10,FAR_HIP,Vector2(169,312),far_step]]:
		var thigh: int=spec[0]
		var calf: int=spec[1]
		var foot: int=spec[2]
		var hip := _core_map(spec[3],delta,lean)
		var ankle: Vector2=spec[4]+spec[5]
		var knee := _joint(hip,ankle,_length(thigh),_length(calf),-1.0)
		_place(thigh,hip,knee)
		_place(calf,knee,ankle)
		# Entire foot stays rigid: no weighting or morphing of a shared sole.
		_place(foot,ankle,ankle+(PARTS[foot][2]-PARTS[foot][1])*PARTS[foot][3])
		feet.append([ankle.x,ankle.y])
	for spec in [[1,2,NEAR_SHOULDER,Vector2(79,277),near_step],
		[3,4,FAR_SHOULDER,Vector2(197,270),far_step]]:
		var upper: int=spec[0]
		var lower: int=spec[1]
		var shoulder := _core_map(spec[2],delta,lean)
		var hand: Vector2=spec[3]+delta+Vector2(-spec[4].x*0.40,-2.0 if walking else 0.0)
		var elbow := _joint(shoulder,hand,_length(upper),_length(lower),1.0)
		_place(upper,shoulder,elbow)
		_place(lower,elbow,hand)
	return {"phase":phase,"walking":walking,"near_ankle":feet[0],"far_ankle":feet[1],
		"near_support":not walking or fposmod(phase,1.0)<0.5,
		"far_support":not walking or fposmod(phase,1.0)>=0.5}

func _bake() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	assert(source != null and not source.is_empty())
	var texture := ImageTexture.create_from_image(source)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(256,256)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for index in range(PARTS.size()):
		var sprite := Sprite2D.new()
		sprite.texture=texture
		sprite.centered=false
		sprite.region_enabled=true
		sprite.region_rect=PARTS[index][0]
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.z_index=[0,5,6,-4,-3,1,2,3,-2,-1,0][index]
		viewport.add_child(sprite)
		displays.append(sprite)
	var results: Array=[]
	for role in ["idle","walk"]:
		var count := 2 if role=="idle" else 8
		for index in range(count):
			var result := _pose(float(index)/count,role=="walk")
			await process_frame
			await RenderingServer.frame_post_draw
			var path := output.path_join("E-%s-%02d.png" % [role,index])
			assert(viewport.get_texture().get_image().save_png(path)==OK)
			result["file"]=path
			results.append(result)
	var receipt := {"key":"monster:알비노 변이된 골렘","direction":"E",
		"method":"independent rigid crystalline parts, fixed-length shoulder/elbow/hip/knee IK and rigid flat feet; body weight transfer and opposite arm swing",
		"source":SOURCE,"poses":results,"actual_Main":"NOT_RUN","quality":"HOLD_UNREVIEWED",
		"production_applied":false,"new_completed":0,"cycle_seconds":0.48,"game_speed_unchanged":82.0}
	var file := FileAccess.open(output.path_join("source-authoring.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"\t")+"\n")
	file.close()
	print("Authored2 idle+8walk E parts-rig candidates; no final source/Main quality claim")
	quit(0)
