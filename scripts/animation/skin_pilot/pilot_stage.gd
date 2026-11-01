extends Node2D
const Motion = preload("res://scripts/animation/skin_pilot/shared_ground_motion.gd")
const Cutout = preload("res://scripts/animation/skin_pilot/cutout_skin.gd")
var motion := Motion.new()
var actors: Array[Node2D] = []
var elapsed := 0.0
var frames := 0
var speed := 0.0
var status: Label
var close_label: Label
var active := false
var definitions: Dictionary
var swapped := false
var names: Array[Label] = []
var manual := false
var manual_moving := false
var manual_lift := 6.0

func _ready() -> void:
	Engine.max_fps = 30
	position = (get_viewport_rect().size - Vector2(960, 640)) * 0.5
	RenderingServer.set_default_clear_color(Color("19222b"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/animation/shared_skin_pilot.json"))
	_label("TWILIGHT  /  SHARED 2D MOTION PILOT", Vector2(40, 24), 25)
	_label("Two existing skins. One joint pose and one distance-driven timeline.", Vector2(40, 65), 17)
	definitions = data.skins
	names.append(_label("WARRIOR", Vector2(200, 125), 18))
	names.append(_label("ASSASSIN", Vector2(625, 125), 18))
	for row in range(2):
		for i in range(2):
			var actor := Cutout.new()
			add_child(actor)
			actor.bind_skin(data.skins["warrior" if i == 0 else "assassin"])
			actor.position = Vector2(255 + 425 * i, 255 if row == 0 else 510)
			actor.scale = Vector2.ONE * (1.0 if row == 0 else 2.6)
			actors.append(actor)
	_label("1x actual pixels", Vector2(40, 180), 15)
	_label("2.6x same live pose", Vector2(40, 330), 15)
	status = _label("", Vector2(40, 555), 20)
	close_label = _label("E-view pilot only. Space: move/stop   L: shared lift   S: swap skins", Vector2(40, 600), 15)
	if "--pilot-test" in OS.get_cmdline_user_args():
		_tests()
		return
	for actor in actors: actor.apply_pose(motion.sample(0.0, false))
	await RenderingServer.frame_post_draw
	print("SKIN_PILOT_READY")
	await get_tree().create_timer(2.0).timeout
	active = true

func _process(delta: float) -> void:
	if not active: return
	elapsed += delta
	frames += 1
	speed = (80.0 if manual_moving else 0.0) if manual else (80.0 if elapsed > 2.0 and elapsed < 14.0 else 0.0)
	if not manual and elapsed >= 11.0 and not swapped: _swap_skins()
	# One authoring parameter changes both skins and both views together.
	motion.swing_height = manual_lift if manual else (6.0 if elapsed < 8.0 else 8.0)
	var pose := motion.advance(delta, speed)
	for actor in actors: actor.apply_pose(pose)
	status.text = "IDLE  /  shared stable pose" if speed == 0 else "RUN  /  ONE shared motion, foot lift %.0f px" % motion.swing_height
	if swapped: status.text += "  /  skins swapped, phase preserved"
	queue_redraw()
	if elapsed > 16.0 and "--pilot-capture" in OS.get_cmdline_user_args():
		print("SKIN_PILOT_PLAYBACK frames=", frames, " seconds=", elapsed, " average_fps=", frames / elapsed)
		get_tree().quit()

func _swap_skins() -> void:
	swapped = not swapped
	for i in range(actors.size()):
		var warrior := (i % 2 == 0) != swapped
		actors[i].bind_skin(definitions["warrior" if warrior else "assassin"])
	names[0].text = "ASSASSIN" if swapped else "WARRIOR"
	names[1].text = "WARRIOR" if swapped else "ASSASSIN"

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_SPACE:
		manual = true
		manual_moving = not manual_moving
	elif event.keycode == KEY_L:
		manual = true
		manual_lift = 8.0 if manual_lift == 6.0 else 6.0
	elif event.keycode == KEY_S: _swap_skins()

func _draw() -> void:
	for row in range(2):
		var y := 255.0 if row == 0 else 510.0
		var zoom := 1.0 if row == 0 else 2.6
		draw_line(Vector2(40, y), Vector2(920, y), Color("6c7a80"), 1)
		for i in range(28):
			var x := 40 + fposmod(i * 38.0 - motion.distance * zoom, 880.0)
			draw_line(Vector2(x, y), Vector2(x - 8, y + 10), Color("43525b"), 1)

func _label(text: String, pos: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	add_child(label)
	return label

func _tests() -> void:
	var max_drift := 0.0
	for sample_index in range(600):
		var p := float(sample_index) / 600.0
		var a := motion.sample(p)
		var b := motion.sample(p + 0.0001)
		assert(a.hip == Vector2(0, -32))
		for side in range(2):
			var hip: Vector2 = a.hip + Vector2(-1 if side == 0 else 1, 0)
			assert(absf(hip.distance_to(a.knees[side]) - 16.0) < 0.001)
			assert(absf(a.knees[side].distance_to(a.feet[side]) - 16.0) < 0.001)
			if a.contact[side] and b.contact[side]:
				var drift: float = absf(b.feet[side].x - a.feet[side].x + motion.stride_distance * 0.0001)
				max_drift = maxf(max_drift, drift)
				assert(drift < 0.0001)
	var pose := motion.sample(0.2)
	for actor in actors: actor.apply_pose(pose)
	for actor in actors: assert(is_same(actor.pose, pose))
	motion.swing_height = 6
	var low := motion.sample(0.77)
	motion.swing_height = 8
	var high := motion.sample(0.77)
	assert(high.feet[0].y < low.feet[0].y - 1.5)
	var old_phase := motion.phase
	_swap_skins()
	assert(motion.phase == old_phase)
	for actor in actors: assert(is_same(actor.pose, pose))
	print("SKIN_PILOT_CONTRACT_OK shared_pose=4 skins=2 stable_torso=true fixed_bone_lengths=true stance_max_drift=", max_drift)
	get_tree().quit()
