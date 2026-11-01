extends Node2D
const AttackClock = preload("res://scripts/animation/actor_motion.gd")
const Motion = preload("res://scripts/animation/skin_pilot/shared_ground_motion.gd")
const FrontCutout = preload("res://scripts/animation/skin_pilot/front_cutout_skin.gd")
const Cutout = preload("res://scripts/animation/skin_pilot/cutout_skin.gd")
var motion := Motion.new()
var attack_clock := AttackClock.new()
var attack_index := 0
var strikes := 0
var strike_flash := 0.0
var actors: Array[Node2D] = []
var elapsed := 0.0
var frames := 0
var wall_started_usec := 0
# Same unbuffed normal-attack interval as world._normal_attack_interval().
const BASE_ATTACK_SECONDS := 0.72
var speed := 0.0
var status: Label
var close_label: Label
var active := false
var definitions: Dictionary
var swapped := false
var names: Array[Label] = []
var front_preview := false
var girtas_preview := false
var secondary_skin := "assassin"
var preview_speed := 80.0
var manual := false
var manual_moving := false
var manual_lift := 6.0

func _ready() -> void:
	front_preview = "--girtas-front" in OS.get_cmdline_user_args()
	girtas_preview = front_preview or "--girtas-skin" in OS.get_cmdline_user_args()
	if girtas_preview:
		motion.configure_run()
		preview_speed = 210.0 # Player.move_speed and Girtas NativeMotionProfile.reference_speed.
		manual_lift = 10.0
	Engine.max_fps = 30
	attack_clock.strike.connect(func(_sequence: int):
		strikes += 1
		strike_flash = 0.14
	)
	position = (get_viewport_rect().size - Vector2(960, 640)) * 0.5
	RenderingServer.set_default_clear_color(Color("19222b"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/animation/shared_skin_pilot.json"))
	_label("TWILIGHT  /  GIRTAS SHARED 2D SKIN" if girtas_preview else "TWILIGHT  /  SHARED 2D MOTION PILOT", Vector2(40, 24), 25)
	_label(("E side + S front / one shared RUN phase / 210 px/s" if front_preview else "E view / shared RUN / 210 px/s / fixed 30 FPS render") if girtas_preview else "Two existing skins. One joint pose and one distance-driven timeline.", Vector2(40, 65), 17)
	if girtas_preview:
		secondary_skin = "girtas_267"
		data.skins[secondary_skin] = JSON.parse_string(FileAccess.get_file_as_string("res://data/animation/girtas_shared_skin.json")).skin
	if front_preview:
		data.skins["girtas_front"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/animation/girtas_front_skin.json"))
	definitions = data.skins
	names.append(_label("GIRTAS E SIDE" if front_preview else "WARRIOR", Vector2(200, 125), 18))
	names.append(_label(("GIRTAS S FRONT" if front_preview else "GIRTAS") if girtas_preview else "ASSASSIN", Vector2(625, 125), 18))
	for row in range(2):
		for i in range(2):
			var actor = FrontCutout.new() if front_preview and i==1 else Cutout.new()
			add_child(actor)
			actor.bind_skin(data.skins[("girtas_267" if i==0 else "girtas_front") if front_preview else ("warrior" if i==0 else secondary_skin)])
			actor.position = Vector2(255 + 425 * i, 270 if row == 0 else 530) if girtas_preview else Vector2(255 + 425 * i, 255 if row == 0 else 510)
			actor.scale = Vector2.ONE * (1.0 if row == 0 else (1.8 if girtas_preview else 2.6))
			actors.append(actor)
	_label("1x actual pixels", Vector2(40, 180), 15)
	_label("1.8x same live pose" if girtas_preview else "2.6x same live pose", Vector2(40, 330), 15)
	status = _label("", Vector2(40, 555), 20)
	close_label = _label("E/S pilot / original base + authored upper posture / not eight-direction completion" if front_preview else "E-view pilot. Space: move/stop   A: attack   S: swap skins", Vector2(40, 600), 15)
	if "--pilot-test" in OS.get_cmdline_user_args():
		_tests()
		return
	for actor in actors: actor.apply_pose(motion.sample(0.0, false))
	await RenderingServer.frame_post_draw
	print("SKIN_PILOT_READY")
	await get_tree().create_timer(2.0).timeout
	wall_started_usec = Time.get_ticks_usec()
	active = true

func _process(delta: float) -> void:
	if not active: return
	elapsed += delta
	frames += 1
	strike_flash = maxf(0.0, strike_flash - delta)
	speed = (preview_speed if manual_moving else 0.0) if manual else (preview_speed if (elapsed > 2.0 and elapsed < 6.0) or (elapsed > 13.0 and elapsed < 16.0) else 0.0)
	var attack_times := [7.0, 8.4, 9.8, 14.0]
	if not manual and attack_index < attack_times.size() and elapsed >= attack_times[attack_index]:
		_begin_attack()
		attack_index += 1
	if not manual and elapsed >= 10.0 and not swapped: _swap_skins()
	motion.swing_height = manual_lift if manual else (10.0 if girtas_preview else 6.0)
	var was_attacking: bool = attack_clock.active
	if was_attacking: speed = 0.0
	attack_clock.advance(delta, Vector2(speed, 0))
	var pose := motion.advance(delta, speed)
	if was_attacking:
		pose = motion.sample_attack(attack_clock.visual_progress, attack_clock.attack_hit_ratio)
	for actor in actors:
		if actor.has_method("set_action"):
			actor.set_action(was_attacking,attack_clock.visual_progress,attack_clock.attack_hit_ratio)
		actor.apply_pose(pose)
	status.text = "IDLE / fixed feet, restrained chest breathing" if speed == 0 else "RUN / shared shoulder, elbow and distance-driven legs"
	if was_attacking: status.text = "ATTACK / existing hit clock / prepare - strike - recover"
	if strike_flash > 0.0: status.text = "STRIKE / authoritative event %d / both skins share this pose" % strikes
	if swapped: status.text += " / swapped"
	queue_redraw()
	if elapsed > 18.0 and "--pilot-capture" in OS.get_cmdline_user_args():
		print("SKIN_PILOT_PLAYBACK frames=", frames, " seconds=", elapsed, " average_fps=", frames / elapsed)
		var wall_seconds := float(Time.get_ticks_usec() - wall_started_usec) / 1000000.0
		print("SKIN_PILOT_WALL seconds=", wall_seconds, " rendered_fps=", frames / wall_seconds, " strikes=", strikes)
		get_tree().quit()

func _begin_attack() -> void:
	motion.capture_attack_origin()
	attack_clock.begin_attack(BASE_ATTACK_SECONDS, Vector2.RIGHT, "slash", attack_clock.profile.marker_for("slash"))

func _swap_skins() -> void:
	if front_preview: return
	swapped = not swapped
	for i in range(actors.size()):
		var warrior := (i % 2 == 0) != swapped
		actors[i].bind_skin(definitions["warrior" if warrior else secondary_skin])
	names[0].text = ("GIRTAS" if girtas_preview else "ASSASSIN") if swapped else "WARRIOR"
	names[1].text = "WARRIOR" if swapped else ("GIRTAS" if girtas_preview else "ASSASSIN")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if not manual and event.keycode in [KEY_SPACE, KEY_L]:
		manual_moving = speed > 0.01
		manual_lift = motion.swing_height
	if event.keycode == KEY_SPACE:
		manual = true
		manual_moving = not manual_moving
	elif event.keycode == KEY_L:
		manual = true
		manual_lift = (12.0 if manual_lift == 10.0 else 10.0) if girtas_preview else (8.0 if manual_lift == 6.0 else 6.0)
	elif event.keycode == KEY_S: _swap_skins()
	elif event.keycode == KEY_A:
		manual = true
		manual_moving = false
		_begin_attack()

func _draw() -> void:
	for row in range(2):
		var y := (270.0 if row == 0 else 530.0) if girtas_preview else (255.0 if row == 0 else 510.0)
		var zoom := 1.0 if row == 0 else (1.8 if girtas_preview else 2.6)
		draw_line(Vector2(40, y), Vector2(920, y), Color("6c7a80"), 1)
		for i in range(28):
			var x := 40 + fposmod(i * 38.0 - motion.distance * zoom, 880.0)
			if not front_preview or x < 470.0:
				draw_line(Vector2(x, y), Vector2(x - 8, y + 10), Color("43525b"), 1)
		if front_preview:
			for i in range(5):
				var depth_y := y - 40.0 + fposmod(i*15.0 - motion.distance*0.35*zoom,75.0)
				draw_line(Vector2(570,depth_y),Vector2(790,depth_y),Color("43525b"),1)

func _label(text: String, pos: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	add_child(label)
	return label

func _tests() -> void:
	if front_preview:
		var front = actors[1]
		var a := motion.sample(0.2)
		front.apply_pose(a)
		var first: Vector2 = front.front_foot(0)
		front.apply_pose(motion.sample(0.2001))
		var second: Vector2 = front.front_foot(0)
		assert(absf(second.x-first.x)<0.00001)
		assert(absf(second.y-first.y+motion.stride_distance*0.0001*0.35)<0.00001)
		print("FRONT_BINDING_OK actual_S_base=true authored_RUN_key=true shared_pose=true projected_stance_displacement=true")
	if girtas_preview and not front_preview:
		_girtas_binding_tests()
		_run_contact_tests()
	var max_drift := 0.0
	for sample_index in range(600):
		var p := float(sample_index) / 600.0
		var a := motion.sample(p)
		var b := motion.sample(p + 0.0001)
		assert(a.hip == Vector2(0, -32) if not motion.run_gait else a.hip.y >= -28.301 and a.hip.y <= -27.5)
		for side in range(2):
			var hip: Vector2 = a.hip + Vector2(-1 if side == 0 else 1, 0).rotated(a.pelvis_angle)
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
	assert(motion.sample(0.0).arm_angle < 0.0)
	assert(motion.sample(0.5).arm_angle > 0.0)
	var old_phase := motion.phase
	_swap_skins()
	assert(motion.phase == old_phase)
	for actor in actors: assert(is_same(actor.pose, pose))
	# Attack poses consume the production clock; skins never emit or reschedule hits.
	for step in [1.0 / 30.0, 1.0 / 60.0, 0.17]:
		var clock := AttackClock.new()
		var events := [0]
		clock.strike.connect(func(_sequence: int): events[0] += 1)
		clock.begin_attack(BASE_ATTACK_SECONDS, Vector2.RIGHT, "slash", clock.profile.marker_for("slash"))
		motion.previous_pose = motion.sample(0.23)
		motion.capture_attack_origin()
		var origin := motion.sample_attack(0.0, clock.attack_hit_ratio)
		assert(origin.feet[0].distance_to(motion.attack_origin.feet[0]) < 0.001)
		var swap_elapsed := clock.attack_elapsed
		_swap_skins()
		assert(clock.attack_elapsed == swap_elapsed)
		while clock.active:
			clock.advance(step, Vector2.ZERO)
			var old_elapsed := clock.attack_elapsed
			var attack_pose := motion.sample_attack(clock.visual_progress, clock.attack_hit_ratio)
			for actor in actors: actor.apply_pose(attack_pose)
			for actor in actors: assert(is_same(actor.pose, attack_pose))
			assert(clock.attack_elapsed == old_elapsed)
			assert(absf(attack_pose.torso_angle) <= 0.181)
			for side in range(2):
				var joint: Vector2 = attack_pose.hip + Vector2(-1 if side == 0 else 1, 0).rotated(attack_pose.pelvis_angle)
				assert(absf(joint.distance_to(attack_pose.knees[side]) - 16.0) < 0.001)
				assert(absf(attack_pose.knees[side].distance_to(attack_pose.feet[side]) - 16.0) < 0.001)
		assert(events[0] == 1)
		var end := motion.sample_attack(1.0, clock.attack_hit_ratio)
		assert(end.hip == motion.sample(0.0, false).hip)
		assert(end.feet == motion.sample(0.0, false).feet)
		var impact := motion.sample_attack(clock.attack_hit_ratio, clock.attack_hit_ratio)
		assert(impact.contact[0] and impact.contact[1])
		assert(impact.locomotion_weight == 0.0)
	motion.attack_origin = {}
	var marker := attack_clock.profile.marker_for("slash")
	var loaded := motion.sample_attack(marker * 0.55, marker)
	var struck := motion.sample_attack(marker, marker)
	assert(loaded.feet == struck.feet)
	assert(struck.hip.x - loaded.hip.x >= 9.0)
	assert(struck.knees[0].distance_to(loaded.knees[0]) > 3.0)
	assert(struck.far_arm_angle > loaded.far_arm_angle + 0.8)
	for index in range(101):
		var weighted := motion.sample_attack(float(index) / 100.0, marker)
		for side in range(2):
			var joint: Vector2 = weighted.hip + Vector2(-1 if side == 0 else 1, 0).rotated(weighted.pelvis_angle)
			assert(absf(joint.distance_to(weighted.knees[side]) - 16.0) < 0.001)
			assert(absf(weighted.knees[side].distance_to(weighted.feet[side]) - 16.0) < 0.001)
	print("SKIN_PILOT_WEIGHT_OK planted_feet_unchanged=true hip_and_knees_shift=true far_arm_response=true")
	print("SKIN_PILOT_ATTACK_OK original_clock=true one_strike_per_attack=true swap_preserves_clock=true recovery_returns_idle=true")
	print("SKIN_PILOT_CONTRACT_OK shared_pose=4 skins=2 bounded_torso=true fixed_bone_lengths=true stance_max_drift=", max_drift)
	get_tree().quit()

func _girtas_binding_tests() -> void:
	var actor = actors[1]
	var definition: Dictionary = actor.skin
	var bind: Dictionary = definition.retarget
	for index in range(601):
		var phase_sample := float(index) / 600.0
		for shared in [motion.sample(phase_sample), motion.sample_attack(phase_sample, attack_clock.profile.marker_for("slash"))]:
			actor.apply_pose(shared)
			assert(is_same(actor.pose, shared))
			var fitted: Dictionary = actor.draw_pose
			for side in range(2):
				var hip: Vector2 = fitted.hip + Cutout._v(bind.hip_offsets[side]).rotated(fitted.pelvis_angle)
				assert(absf(hip.distance_to(fitted.knees[side]) - float(bind.lengths[side][0])) < 0.001)
				assert(absf(fitted.knees[side].distance_to(fitted.feet[side]) - float(bind.lengths[side][1])) < 0.001)
				assert(absf(fitted.feet[side].x - shared.feet[side].x - float(bind.foot_bias[side])) < 0.0001)
				assert(fitted.contact[side] == shared.contact[side])
	# Torso appearance follows the same pose, including the return to the exact idle art.
	assert(actor.turn_frames.size() == 17)
	actor.apply_pose(motion.sample(0.0))
	assert(actor.turn_index == 16)
	actor.apply_pose(motion.sample(0.5))
	assert(actor.turn_index == 0)
	actor.apply_pose(motion.sample(0.0, false))
	assert(actor.turn_index == 0)
	assert(actor.turn_frames[0].torso == definition.parts.torso.texture)
	actor.apply_pose(motion.sample_attack(0.5, attack_clock.profile.marker_for("slash")))
	assert(actor.turn_index == 0)
	print("GIRTAS_BINDING_OK fixed_skin_lengths=true shared_contact_and_distance=true no_skin_clock=true")

func _run_contact_tests() -> void:
	var first := motion.sample(0.0)
	var opposite := motion.sample(0.5)
	assert(first.pelvis_angle * first.torso_x < 0.0)
	assert(opposite.pelvis_angle * opposite.torso_x < 0.0)
	assert(absf(first.torso_angle - opposite.torso_angle) > 0.10)
	assert(first.upper_arm_angle * first.far_arm_angle < 0.0)
	var flights := 0
	for i in range(1000):
		var phase_value := float(i) / 1000.0
		var sampled := motion.sample(phase_value)
		assert(not (sampled.contact[0] and sampled.contact[1]))
		if not sampled.contact[0] and not sampled.contact[1]: flights += 1
		assert(sampled.hip.y >= -28.301 and sampled.hip.y <= -27.5)
	assert(flights > 100 and flights < 140)
	# Toe-off and landing retain the same world-space stance velocity.
	for boundary in [motion.stance_fraction, 1.0]:
		var epsilon := 0.00001
		var a := motion.sample(boundary - epsilon)
		var b := motion.sample(boundary + epsilon)
		var drift: float = b.feet[0].x - a.feet[0].x + motion.stride_distance * 2.0 * epsilon
		# Measure displacement directly: dividing Vector2 float noise by epsilon is unstable.
		assert(absf(drift) < 0.0001)
	print("RUN_CONTACT_OK no_double_support=true brief_flight=true continuous_contact_velocity=true bounded_body_rise=true")
