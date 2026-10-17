extends SceneTree

const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")
const ART = preload("res://scripts/monsters/monster_art.gd")
const GEOMETRY = preload("res://scripts/monsters/boss_geometry.gd")
const LOOT = preload("res://scripts/loot_drop.gd")
var failures: Array[String] = []
var checks: int = 0
var report: Array[Dictionary] = []

class OpenGround extends RefCounted:
	func is_safe(_point: Vector2) -> bool: return false
	func walkable(_point: Vector2) -> bool: return true
	func point_clear(_point: Vector2) -> bool: return true
	func line_clear(_a: Vector2, _b: Vector2) -> bool: return true

class Population extends Node:
	var summoned: int = 0
	func summon_for(_mob: TwilightMonster) -> void: summoned += 1
	func alert_social(_mob: TwilightMonster) -> void: pass

class Arena extends Node:
	var field_map = null
	var field_population: Population
	var combat_flights: TwilightCombatFlights
	var combat_vfx: TwilightCombatVFX
	var hp: int = 999999
	var concealed: bool = false
	func is_player_concealed() -> bool: return concealed
	func _has_line_of_sight_world(_a: Vector2, _b: Vector2) -> bool: return true
	func find_world_path(a: Vector2, b: Vector2) -> PackedVector2Array: return PackedVector2Array([a,b])
	func show_combat_number(_p: Vector2, _v: String, _c: Color, _critical: bool = false) -> void: pass

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("BOSS_PRESENTATION FAIL: " + message)

func _run() -> void:
	var arena := Arena.new()
	root.add_child(arena)
	arena.field_population = Population.new()
	arena.add_child(arena.field_population)
	arena.combat_flights = preload("res://scripts/animation/combat_flights.gd").new()
	arena.add_child(arena.combat_flights)
	arena.combat_vfx = preload("res://scripts/animation/combat_vfx.gd").new()
	arena.add_child(arena.combat_vfx)
	var player: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.camera.enabled = false
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	var bosses: Array = CATALOG.expand(db["몬스터"]).filter(func(r: Dictionary) -> bool: return LOOT.is_boss_record(r))
	for record: Dictionary in bosses:
		var before_errors: int = failures.size()
		var mob: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
		root.add_child(mob)
		mob.setup(record, player, arena, ART.texture_for(record))
		mob.set_physics_process(false)
		check(not mob.motion.profile.presentation.is_empty(), "boss ID configuration " + record.name)
		var hits: Array[int] = [0]
		var deaths: Array[int] = [0]
		mob.player_hit.connect(func(_mob: TwilightMonster, _amount: int, _kind: String) -> void: hits[0] += 1)
		mob.died.connect(func(_mob: TwilightMonster) -> void: deaths[0] += 1)
		player.position = mob.position + Vector2(40, 0)
		mob.special_cooldown = 9999.0
		mob.aggro_remaining = 10.0
		mob._physics_process(.04)
		check(mob.motion.active and hits[0] == 0, "AI starts windup " + record.name)
		mob.motion.advance(1.0, Vector2.ZERO)
		arena.combat_flights._physics_process(.6)
		check(hits[0] == 1, "basic release once " + record.name)
		mob.motion.advance(1.0, Vector2.ZERO)
		check(hits[0] == 1, "no second basic release " + record.name)
		var special: Dictionary = mob.ai.get("special", {})
		if not special.is_empty():
			var kind: String = special.kind
			if kind == "charge":
				arena.field_map = OpenGround.new()
				player.position = mob.position + Vector2(-140, 0)
			var before_summons: int = arena.field_population.summoned
			hits[0] = 0
			mob._begin_special()
			var rig: TwilightMonsterVisual = mob.species_visual
			check(rig.warning_active and rig.visible, "warning visible " + record.name)
			var original_center: Vector2 = rig.warning_center
			var original_aim: Vector2 = rig.warning_aim
			var release_time: float = mob.motion.attack_duration * mob.motion.attack_hit_ratio
			mob.motion.advance(release_time - .001, Vector2.ZERO)
			mob.motion.apply(mob.sprite, mob.animation_base_scale)
			var release_texture: Texture2D = mob.sprite.texture
			var release_body: Transform2D = mob.sprite.transform.scaled_local(Vector2(-1.0 if mob.sprite.flip_h else 1.0, -1.0 if mob.sprite.flip_v else 1.0))
			check(hits[0] == 0 and rig.effect_age < 0.0, "no damage/effect before marker " + record.name)
			mob.motion.advance(.002, Vector2.ZERO)
			check(not rig.warning_active and rig.effect_age == 0.0, "effect at marker " + record.name)
			check(rig.effect_center == original_center and rig.effect_aim == original_aim, "warning/impact world anchor " + record.name)
			check(rig.effect_outline == rig.warning_outline, "same warning and impact geometry " + record.name)
			if kind == "charge":
				check(mob.position == player.position, "existing charge moves on open ground " + record.name)
				check(rig.effect_body == release_body and rig.effect_texture == release_texture, "charge snapshots the actual release pose " + record.name)
				if mob.motion.profile.layout in ["directional8", "sequential8"]:
					# A genuine W image already faces left; mirroring it would face right.
					var frames: SpriteFrames = mob.motion.frame_source
					var has_west: bool = frames != null and frames.has_animation("attack_4") and frames.get_frame_count("attack_4") > 0
					check(has_west and mob.motion.facing8 == 4 and mob.motion._resolved_key == "attack_4", "charge selects native west attack " + record.name)
					check(not mob.sprite.flip_h and not mob.sprite.flip_v and rig.effect_body.x.x > 0.0, "native west charge remains unmirrored " + record.name)
					if has_west:
						var before_marker: int = maxi(0, clampi(mob.motion.profile.hit_frame_for("attack"), 0, frames.get_frame_count("attack_4") - 1) - 1)
						check(rig.effect_texture == frames.get_frame_texture("attack_4", before_marker), "charge freezes west pre-marker frame " + record.name)
						check(frames.has_animation("attack_0") and rig.effect_texture != frames.get_frame_texture("attack_0", before_marker), "west charge is distinct from east " + record.name)
				else:
					check(rig.effect_body.x.x < 0.0 and rig.effect_texture == mob.sprite.texture, "left-facing frozen charge trail " + record.name)
				arena.field_map = null
			arena.combat_flights._physics_process(.6)
			var expected: int = 0 if kind == "summon" else 3 if kind == "volley" else 1
			check(hits[0] == expected, "special hit count " + record.name)
			if kind == "summon": check(arena.field_population.summoned == before_summons + 1, "one summon " + record.name)
			mob.motion.advance(1.0, Vector2.ZERO)
			if kind == "charge":
				mob.motion.face(Vector2.RIGHT)
				mob.motion.apply(mob.sprite, mob.animation_base_scale)
				check(rig.effect_texture == release_texture and rig.effect_body == release_body, "charge trail stays frozen after recovery and turn " + record.name)
				check(rig.effect_center == original_center and rig.effect_aim == original_aim, "charge trail world anchor stays frozen after turn " + record.name)
			arena.combat_flights._physics_process(.6)
			check(hits[0] == expected, "no duplicate special " + record.name)
			rig.tick(.6)
			check(rig.effect_age < 0.0, "effect expires " + record.name)
			# A canceled windup or dead target must never leave a damaging-looking release.
			mob._begin_special()
			mob.motion.cancel_attack()
			rig.tick(.01)
			check(not rig.warning_active, "cancellation clears warning " + record.name)
			mob._begin_special()
			arena.hp = 0
			mob.motion.advance(2.0, Vector2.ZERO)
			check(rig.effect_age < 0.0 and hits[0] == expected, "dead target cancels release " + record.name)
			arena.hp = 999999
			mob._begin_special()
			mob.take_damage(mob.hp, true)
			mob.take_damage(999)
			rig.tick(.01)
			check(deaths[0] == 1 and not rig.warning_active and rig.effect_age < 0.0, "death cleanup once " + record.name)
		else:
			mob.take_damage(mob.hp)
			mob.take_damage(999)
			check(deaths[0] == 1, "basic boss death once " + record.name)
		arena.combat_flights.clear()
		arena.combat_vfx.clear()
		report.append({"id":mob.motion.profile.profile_id,"name":record.name,"special":special.get("kind", "none"),"errors":failures.slice(before_errors)})
		mob.free()
	# Golden edges of the unchanged hit geometry in every facing direction.
	for direction: int in range(8):
		var aim: Vector2 = Vector2.from_angle(direction * PI / 4.0)
		var side: Vector2 = aim.orthogonal()
		for kind: String in ["beam", "charge"]:
			check(GEOMETRY.contains(kind, 200.0, aim * 200.0 + side * 54.9, aim), "inside beam side")
			check(not GEOMETRY.contains(kind, 200.0, aim * 200.0 + side * 55.1, aim), "outside beam side")
			check(not GEOMETRY.contains(kind, 200.0, -aim, aim), "behind beam")
			check(not GEOMETRY.contains(kind, 200.0, aim * 400.1, aim), "past beam end")
		check(GEOMETRY.contains("cone", 200.0, aim.rotated(.549) * 399.9, aim), "inside cone")
		check(not GEOMETRY.contains("cone", 200.0, aim.rotated(.551) * 200.0, aim), "outside cone angle")
		check(not GEOMETRY.contains("cone", 200.0, aim * 400.1, aim), "outside cone radius")
		check(GEOMETRY.contains("nova", 200.0, aim * 199.9, aim), "inside nova")
		check(not GEOMETRY.contains("nova", 200.0, aim * 200.1, aim), "outside nova")
		check(not GEOMETRY.contains("summon", 200.0, aim * 1.0, aim), "summon is not AoE")
		check(not GEOMETRY.contains("volley", 200.0, aim * 1.0, aim), "volley is not AoE")
	# Authored bosses retain their warning node and skip procedural body deformation.
	var sample: Dictionary = bosses.filter(func(r: Dictionary) -> bool: return r.get("ai", {}).has("special"))[0].duplicate(true)
	var native: SpriteFrames = preload("res://scripts/animation/animation_catalog.gd").frames("res://assets/sprites/classes/warrior.png", "class5").duplicate(true)
	check(ResourceSaver.save(native, "user://boss-native.tres") == OK, "native boss fixture")
	sample.animation_profile = {"frames_path":"user://boss-native.tres", "layout":"class5"}
	var native_boss: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
	root.add_child(native_boss)
	native_boss.setup(sample, player, arena, ART.texture_for(sample))
	native_boss.set_physics_process(false)
	native_boss._begin_special()
	check(native_boss.motion.frame_source != null and native_boss.species_visual.visible and native_boss.species_visual.warning_active, "authored boss warning survives")
	check(native_boss.sprite.material == null, "native boss is not mesh warped twice")
	native_boss.free()
	FileAccess.open("user://boss-presentation-results.json", FileAccess.WRITE).store_string(JSON.stringify({"bosses":report,"checks":checks,"failures":failures}, "\t"))
	player.queue_free()
	arena.queue_free()
	await process_frame
	print("BOSS_PRESENTATION_%s bosses=%d checks=%d" % ["OK" if failures.is_empty() else "FAILED", report.size(), checks])
	quit(0 if failures.is_empty() else 1)
