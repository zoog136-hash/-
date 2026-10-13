extends SceneTree

const MOTION = preload("res://scripts/animation/actor_motion.gd")
const GEOMETRY = preload("res://scripts/monsters/boss_geometry.gd")
const DIRECTOR = preload("res://scripts/monsters/boss_director.gd")
var failures: Array[String] = []
var checks: int = 0

class Arena extends Node:
	var field_map = null
	var field_population = null
	var combat_flights = null
	var combat_vfx = null
	var hp: int = 9999
	func is_player_concealed() -> bool: return false
	func _has_line_of_sight_world(_a: Vector2, _b: Vector2) -> bool: return true
	func show_combat_number(_p: Vector2, _v: String, _c: Color, _critical: bool = false) -> void: pass

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("COMBAT_LIFECYCLE_FAIL: " + label)

func _run() -> void:
	var player: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.camera.enabled = false
	var attack_animation: String = "attack_0" if player.class_profile.layout == "directional8" else "attack"
	check(player.class_sprite.sprite_frames.has_animation(attack_animation), "existing player attack frames imported")
	var hits: Array[int] = []
	player.attack_strike.connect(func(id: int) -> void: hits.append(id))
	# Crossing the marker and the end of recovery in one tick must render and hit once.
	for fps: float in [5.0, 15.0, 30.0, 60.0]:
		for speed: float in [0.5, 1.0, 4.0]:
			for style: String in ["slash", "heavy", "thrust", "bow", "magic"]:
				hits.clear()
				var duration: float = .72 / speed
				var id: int = player.start_combat_attack(Vector2.RIGHT * 100, duration, style, player.motion.profile.marker_for(style))
				var sampled_release: bool = false
				for tick: int in range(int(ceil(duration * fps)) + 2):
					var before: int = hits.size()
					player.motion.advance(1.0 / fps, Vector2.ZERO)
					player.motion.apply(player.class_sprite, Vector2.ONE)
					if hits.size() > before:
						sampled_release = player.class_sprite.animation == attack_animation and player.class_sprite.frame == player.class_profile.attack_hit_frame
				check(hits == [id], "single skipped-frame marker %s/%s/%s" % [fps, speed, style])
				check(sampled_release and not player.motion.active, "release pose and unchanged cadence %s/%s/%s" % [fps, speed, style])
	# Multiple physics ticks before rendering must not discard the only release pose.
	player.start_combat_attack(Vector2.RIGHT * 100, .1, "slash")
	player.motion.advance(.11, Vector2.ZERO)
	player.motion.advance(.11, Vector2.ZERO)
	player.motion.apply(player.class_sprite, Vector2.ONE)
	check(player.class_sprite.animation == attack_animation and player.class_sprite.frame == player.class_profile.attack_hit_frame, "release survives unsampled physics ticks")
	player.motion.advance(.01, Vector2.ZERO)
	player.motion.apply(player.class_sprite, Vector2.ONE)
	check(player.class_sprite.animation != attack_animation, "release latch clears after presentation")
	player.start_combat_attack(Vector2.RIGHT * 100, .1, "slash")
	player.motion.advance(.11, Vector2.ZERO)
	player.motion.advance(.3, Vector2.ZERO)
	player.motion.apply(player.class_sprite, Vector2.ONE)
	check(player.class_sprite.animation != attack_animation, "offscreen stale release expires")
	_test_reentrant_motion()
	for status: String in ["stun", "fear", "silence"]:
		hits.clear()
		player.clear_status_effects()
		player.start_combat_attack(Vector2.RIGHT * 100, .2, "magic")
		if status == "fear": player.apply_fear(.001, Vector2.ZERO)
		else: player.call("apply_" + status, .001)
		player.motion.advance(.3, Vector2.ZERO)
		check(hits.is_empty() and not player.motion.active, "player immediate short " + status)
	player.clear_status_effects()
	player.motion.reduced_motion = true
	player.motion.react(true, Vector2.LEFT)
	player.motion.advance(.016, Vector2.RIGHT * 210)
	player.motion.apply(player.class_sprite, Vector2.ONE)
	check(player.motion.visual_hold == 0.0, "reduced motion disables pose freeze")
	check(player.class_sprite.position == player.motion.profile.sprite_offset and player.class_sprite.rotation == 0.0 and player.class_sprite.scale == Vector2.ONE, "reduced motion keeps body anchor")
	_test_boss_actions(player)
	_test_boss_save_clock()
	player.free()
	if failures.is_empty(): print("COMBAT_TIMELINE_LIFECYCLE_OK checks=" + str(checks))
	quit(0 if failures.is_empty() else 1)

func _test_reentrant_motion() -> void:
	var motion = MOTION.new()
	var cancellations: Array[int] = []
	motion.begin_attack(.5, Vector2.RIGHT)
	motion.cancelled.connect(func(id: int) -> void:
		cancellations.append(id)
		motion.cancel_attack())
	motion.cancel_attack()
	check(cancellations == [1] and not motion.active, "cancellation commits before reentrant signal")
	var replacement = MOTION.new()
	replacement.begin_attack(.5, Vector2.RIGHT)
	replacement.cancelled.connect(func(_id: int) -> void: replacement.begin_attack(.6, Vector2.DOWN), CONNECT_ONE_SHOT)
	var rejected: int = replacement.begin_attack(.8, Vector2.LEFT)
	check(rejected == -1 and replacement.sequence == 2 and replacement.direction == Vector2.DOWN and replacement.active, "cancel callback replacement remains authoritative")
	var dying = MOTION.new()
	dying.strike.connect(func(_id: int) -> void: dying.die())
	dying.begin_attack(.1, Vector2.RIGHT)
	dying.advance(.2, Vector2.ZERO)
	check(dying.dead and dying.state == "death" and not dying.active, "strike callback death survives old timeline tail")
	check(dying.begin_attack(.5, Vector2.RIGHT) == -1, "dead actor cannot restart attack")
	var chained = MOTION.new()
	chained.strike.connect(func(_id: int) -> void: chained.begin_attack(.4, Vector2.UP), CONNECT_ONE_SHOT)
	chained.begin_attack(.1, Vector2.RIGHT)
	chained.advance(.2, Vector2.ZERO)
	check(chained.sequence == 2 and chained.active and chained.attack_elapsed == 0.0 and chained.direction == Vector2.UP, "strike callback new cycle starts at zero")
	# RefCounted signal lambdas intentionally capture their subject during reentry.
	for subject: RefCounted in [motion, replacement, dying, chained]:
		for signal_name: String in ["strike", "cancelled"]:
			for connection: Dictionary in subject.get_signal_connection_list(signal_name):
				subject.disconnect(signal_name, connection.callable)

func _test_boss_actions(player: TwilightPlayer) -> void:
	var arena := Arena.new()
	root.add_child(arena)
	var boss: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
	root.add_child(boss)
	var record: Dictionary = {"name":"Lifecycle boss", "hp":1000, "atk":20, "grade":"보스", "is_boss":true,
		"ai":{"special":{"kind":"beam", "radius":200, "windup":.4, "multiplier":1.6}}}
	boss.setup(record, player, arena, null)
	boss.set_physics_process(false)
	var hits: Array[int] = []
	boss.player_hit.connect(func(_boss: TwilightMonster, amount: int, _kind: String) -> void: hits.append(amount))
	player.position = Vector2(100, 0)
	boss._begin_special()
	var first_id: int = boss.special_sequence
	check(boss.species_visual.warning_aim == Vector2.RIGHT, "boss normalized warning aim")
	boss._resolve_special()
	check(hits.is_empty() and not boss.special_attack.is_empty(), "boss special cannot release before marker")
	# Presentation updates and data reloads cannot move/change a committed damaging area.
	boss.species_visual.warning_center = Vector2(1000, 1000)
	boss.species_visual.warning_aim = Vector2.LEFT
	boss.ai.special.radius = 1.0
	boss.motion.advance(.5, Vector2.ZERO)
	boss._release_attack(first_id)
	boss._resolve_special()
	check(hits == [32], "snapshot geometry and single release remain authoritative")
	check(boss.species_visual.effect_center == Vector2.ZERO and boss.species_visual.effect_aim == Vector2.RIGHT, "release presentation consumes combat snapshot")
	boss.ai.special.radius = 200.0
	for status: String in ["stun", "fear", "silence"]:
		boss.stun_remaining = 0.0
		boss.fear_remaining = 0.0
		boss.silence_remaining = 0.0
		boss._begin_special()
		if status == "fear": boss.apply_fear(.001, Vector2.LEFT)
		else: boss.call("apply_" + status, .001)
		check(not boss.species_visual.warning_active and boss.special_attack.is_empty(), "boss immediate warning cancel " + status)
		boss.motion.advance(1.0, Vector2.ZERO)
		check(hits == [32], "cancelled boss causes no delayed hit " + status)
	boss.stun_remaining = 0.0
	boss.fear_remaining = 0.0
	boss.silence_remaining = 0.0
	boss._begin_special()
	var life: int = boss.life_id
	boss.take_damage(boss.hp)
	boss.motion.advance(1.0, Vector2.ZERO)
	check(hits == [32] and boss.dead and not boss.species_visual.warning_active, "boss death cancels warning and marker")
	boss.setup(record, player, arena, null)
	boss.set_physics_process(false)
	boss._resolve_attack(1, "magic", life)
	check(hits == [32] and boss.life_id == life + 1, "pooled life rejects old projectile")
	for kind: String in ["beam", "charge", "cone"]:
		check(GEOMETRY.contains(kind, 200, Vector2(100, 0), Vector2(20, 0)), "nonunit geometry " + kind)
		check(GEOMETRY.outline(kind, 200, Vector2(20, 0)) == GEOMETRY.outline(kind, 200, Vector2.RIGHT), "warning geometry normalized " + kind)
	check(GEOMETRY.contains("cone", 200, Vector2.ZERO, Vector2.RIGHT), "cone contains shared origin")
	check(GEOMETRY.outline("beam", 200, Vector2.ZERO) == GEOMETRY.outline("beam", 200, Vector2.RIGHT), "zero aim has finite matching fallback")
	boss.free()
	arena.free()

func _test_boss_save_clock() -> void:
	var director = DIRECTOR.new()
	var region: Dictionary = {"id":"room", "boss_id":"stable-boss", "respawn_time":3600}
	var key: String = director.key("map", region)
	var future: float = Time.get_unix_time_from_system() + 3600.0
	director.import_state({"version":2, "bosses":{key:{"phase":"alive", "ready_at":future, "hp":37, "position":[30, 40], "home":[10, 20]}}})
	check(director.can_spawn("map", region), "saved living boss restores across clock rollback")
	var saved: Dictionary = director.export_state()
	check(saved.version == 2 and saved.bosses[key].hp == 37 and saved.bosses[key].position == [30, 40] and saved.bosses[key].home == [10, 20], "boss save identity hp and anchors preserved")
	director.died("map", region)
	check(not director.can_spawn("map", region), "dead boss deadline still prevents spawn")
	director.import_state({"version":1, "game_seconds":100, "bosses":{key:{"phase":"cooldown", "ready_at":120}}})
	check(not director.can_spawn("map", region) and absf(float(director.state_for("map", region).ready_at) - Time.get_unix_time_from_system() - 20.0) < 1.0, "legacy remaining cooldown preserved")
