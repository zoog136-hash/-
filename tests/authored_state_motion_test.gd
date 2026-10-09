extends SceneTree

## Uses the existing class textures as a native-resource fixture, not new game art.
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const MOTION = preload("res://scripts/animation/actor_motion.gd")
const FOLLOWER = preload("res://scripts/animation/follower_motion.gd")
const RELIC = preload("res://scripts/animation/relic_motion.gd")
var failures: int = 0
var assertions: int = 0
var strikes: int = 0

class Arena extends Node:
	var field_map = null
	var combat_flights = null
	var hp: int = 999999
	func is_player_concealed() -> bool: return false
	func _has_line_of_sight_world(_a: Vector2, _b: Vector2) -> bool: return true
	func find_world_path(a: Vector2, b: Vector2) -> PackedVector2Array: return PackedVector2Array([a, b])

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		print("AUTHORED STATE FAIL: " + label)

func _fixture() -> SpriteFrames:
	var original: SpriteFrames = CATALOG.frames("res://assets/sprites/classes/warrior.png", "class5")
	var frames: SpriteFrames = SpriteFrames.new() # deliberately retains an empty default
	for pose: String in ["idle", "walk", "attack", "hit", "death"]:
		for direction: int in range(8):
			var key: String = pose + "_fixture_" + str(direction)
			frames.add_animation(key)
			frames.set_animation_speed(key, 10.0)
			frames.set_animation_loop(key, pose in ["idle", "walk"])
			var count: int = 5 if pose == "attack" else 3
			for index: int in range(count):
				var source: String = "attack" if pose == "attack" else "walk_down"
				frames.add_frame(key, original.get_frame_texture(source, index), 2.0 if index == 1 and pose == "idle" else 1.0)
	return frames

func _names() -> Dictionary:
	var names: Dictionary = {}
	for pose: String in ["idle", "walk", "attack", "hit", "death"]:
		for direction: int in range(8): names[pose + ":" + str(direction)] = pose + "_fixture_" + str(direction)
	return names

func _run() -> void:
	var player: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	var frames: SpriteFrames = _fixture()
	var path: String = "user://authored-state-fixture.tres"
	check(ResourceSaver.save(frames, path) == OK, "native fixture save")
	frames = CATALOG.frames(path, "still")
	var record: Dictionary = {"sourceId":"state-fixture", "animation_profile":{
		"frames_path":path, "animation_names":_names(), "attack_hit_ratio":0.6, "attack_hit_frame":2}}
	var profile: TwilightAnimationProfile = CATALOG.for_record("transform", record)
	player.set_transform_visual("", 1.0, profile)
	check(player.transform_active, "empty default animation prevented valid native art")
	check(not profile.dedicated_attack, "fixture should use directional names without a dedicated flag")
	var scale_value: Vector2 = player.transform_sprite.get_meta("base_scale")
	player.attack_strike.connect(func(_id: int) -> void: strikes += 1)
	for direction: int in range(8):
		player.motion = MOTION.new()
		player.motion.profile = profile
		player.motion.strike.connect(func(_id: int) -> void: strikes += 1)
		var aim: Vector2 = Vector2.from_angle(direction * PI / 4.0)
		player.motion.face(aim)
		player.motion.advance(0.12, aim * 210.0)
		player.motion.apply(player.transform_sprite, scale_value)
		check(player.transform_sprite.animation == "walk_fixture_" + str(direction), "directional walk " + str(direction))
		check(player.transform_sprite.frame > 0 and not player.transform_sprite.flip_h, "walk progression/double mirroring " + str(direction))
		var before: int = strikes
		player.motion.begin_attack(1.0, aim, "slash", profile.marker_for("slash"))
		player.motion.advance(0.59, Vector2.ZERO)
		player.motion.apply(player.transform_sprite, scale_value)
		check(strikes == before and player.transform_sprite.frame < 2, "early authored hit " + str(direction))
		player.motion.advance(0.01, Vector2.ZERO)
		player.motion.apply(player.transform_sprite, scale_value)
		check(strikes == before + 1 and player.transform_sprite.frame == 2, "directional marker/frame mismatch " + str(direction))
		player.motion.advance(0.18, Vector2.ZERO)
		player.motion.apply(player.transform_sprite, scale_value)
		check(player.transform_sprite.animation == "attack_fixture_" + str(direction), "recovery discarded attack " + str(direction))
		player.motion.advance(0.3, Vector2.ZERO)
		check(strikes == before + 1 and not player.motion.active, "duplicate marker/cadence " + str(direction))
		player.motion.react()
		player.motion.advance(0.035, Vector2.ZERO)
		player.motion.apply(player.transform_sprite, scale_value)
		check(player.transform_sprite.animation == "hit_fixture_" + str(direction) and player.transform_sprite.frame > 0, "hit stuck on first frame " + str(direction))
		player.motion.die()
		player.motion.advance(0.25, Vector2.ZERO)
		player.motion.apply(player.transform_sprite, scale_value)
		check(player.transform_sprite.animation == "death_fixture_" + str(direction) and player.transform_sprite.frame == 2, "death progression " + str(direction))
		check(is_zero_approx(player.transform_sprite.rotation), "authored death received a second procedural fall " + str(direction))
		player.motion.advance(0.4, Vector2.ZERO)
		player.motion.apply(player.transform_sprite, scale_value)
		check(player.transform_sprite.frame == 2 and player.motion.state == "corpse", "death restarted in corpse " + str(direction))
	# Relative frame durations and loop policy are native SpriteFrames data.
	var motion: TwilightActorMotion = MOTION.new()
	motion.profile = profile
	motion.face(Vector2.RIGHT)
	motion.advance(0.01, Vector2.RIGHT * 210.0)
	motion.advance(0.12, Vector2.ZERO)
	motion.apply(player.transform_sprite, scale_value)
	motion.advance(0.1, Vector2.ZERO)
	motion.apply(player.transform_sprite, scale_value)
	check(player.transform_sprite.frame == 1, "idle did not advance at native FPS")
	motion.advance(0.19, Vector2.ZERO)
	motion.apply(player.transform_sprite, scale_value)
	check(player.transform_sprite.frame == 1, "relative frame duration ignored")
	motion.advance(0.02, Vector2.ZERO)
	motion.apply(player.transform_sprite, scale_value)
	check(player.transform_sprite.frame == 2, "idle final frame missing")
	motion.advance(0.10, Vector2.ZERO)
	motion.apply(player.transform_sprite, scale_value)
	check(player.transform_sprite.frame == 0, "looping idle did not restart")
	var sprite: Sprite2D = Sprite2D.new()
	root.add_child(sprite)
	motion.frame_source = frames
	motion.apply_frames(sprite)
	check(sprite.texture == frames.get_frame_texture("idle_fixture_0", 0), "Sprite2D/native sampler differs")
	var one_shot: SpriteFrames = frames.duplicate(true) as SpriteFrames
	one_shot.set_animation_loop("idle_fixture_0", false)
	player.transform_sprite.sprite_frames = one_shot
	motion = MOTION.new()
	motion.profile = profile
	motion.face(Vector2.RIGHT)
	motion.advance(2.0, Vector2.ZERO)
	motion.apply(player.transform_sprite, scale_value)
	check(player.transform_sprite.frame == 2, "non-loop idle failed to hold its final frame")
	motion.advance(2.0, Vector2.ZERO)
	motion.apply(player.transform_sprite, scale_value)
	check(player.transform_sprite.frame == 2, "non-loop idle restarted")
	one_shot.add_animation("explicit_recovery")
	for index: int in range(3): one_shot.add_frame("explicit_recovery", frames.get_frame_texture("walk_fixture_0", index))
	var late: TwilightAnimationProfile = profile.duplicate(true) as TwilightAnimationProfile
	late.attack_hit_ratio = 0.8
	late.animation_names["recovery"] = "explicit_recovery"
	motion = MOTION.new()
	motion.profile = late
	motion.begin_attack(1.0, Vector2.RIGHT, "slash", 0.8)
	motion.advance(0.75, Vector2.ZERO)
	motion.apply(player.transform_sprite, scale_value)
	check(motion.state == "attack" and player.transform_sprite.animation == "attack_fixture_0", "late marker entered recovery before impact")
	motion.advance(0.05, Vector2.ZERO)
	motion.apply(player.transform_sprite, scale_value)
	check(motion.released and player.transform_sprite.frame == 2 and player.transform_sprite.animation == "attack_fixture_0", "explicit recovery hid the hit frame")
	motion.advance(0.02, Vector2.ZERO)
	motion.apply(player.transform_sprite, scale_value)
	check(player.transform_sprite.animation == "explicit_recovery", "separate recovery animation missing")
	player.transform_sprite.sprite_frames = frames
	# The monster uses its real AI windup and the configured authored marker.
	var arena: Arena = Arena.new()
	root.add_child(arena)
	var mob: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
	root.add_child(mob)
	var monster_record: Dictionary = record.duplicate(true)
	monster_record.merge({"name":"전용 모션 검증", "hp":9999})
	mob.setup(monster_record, player, arena, load("res://assets/sprites/monsters/monster_0.png"))
	mob.set_physics_process(false)
	mob.position = player.position - Vector2(40, 0)
	var hits: Array[int] = [0]
	mob.player_hit.connect(func(_m: TwilightMonster, _n: int, _kind: String) -> void: hits[0] += 1)
	var body: Transform2D = mob.get_node("CollisionShape2D").transform
	mob._physics_process(0.01)
	mob._physics_process(0.30)
	check(mob.motion.frame_source != null and hits[0] == 0, "monster native art/configured windup missing")
	mob._physics_process(0.10)
	check(hits[0] == 1 and mob.sprite.texture == frames.get_frame_texture("attack_fixture_0", 2), "monster marker not synced to native frame")
	check(mob.get_node("CollisionShape2D").transform == body, "native monster animation moved collision shape")
	mob.take_damage(mob.hp)
	mob.motion.advance(0.25, Vector2.ZERO)
	mob.motion.apply(mob.sprite, mob.animation_base_scale)
	check(mob.sprite.texture == frames.get_frame_texture("death_fixture_0", 2), "monster death ignored native art")
	# Invalid optional resources preserve existing transform/doll/relic art.
	player.motion = MOTION.new()
	var fallback_record: Dictionary = {"sourceId":"fallback", "animation_profile":{"frames_path":"res://assets/missing-optional-art.tres"}}
	var fallback: String = "res://assets/sprites/monsters/monster_0.png"
	player.set_transform_visual(fallback, 1.0, CATALOG.for_record("transform", fallback_record))
	check(player.transform_active and player.transform_sprite.sprite_frames.has_animation("still"), "missing native art removed transformation")
	var anchor: Node2D = Node2D.new()
	root.add_child(anchor)
	var doll: AnimatedSprite2D = AnimatedSprite2D.new()
	anchor.add_child(doll)
	var follower: TwilightFollowerMotion = FOLLOWER.new()
	follower.configure(fallback_record, fallback, anchor, doll, player)
	check(follower.enabled and doll.sprite_frames.has_animation("still"), "missing native art removed doll")
	follower.configure(record, "", anchor, doll, player)
	check(follower.enabled, "native-only doll resource rejected")
	var relic: TwilightRelicMotion = RELIC.new()
	relic.configure(record, sprite, player, Color.WHITE)
	check(relic.enabled and relic.motion.frame_source != null, "native-only relic resource rejected")
	for i: int in range(20): relic.update(0.01, sprite, player)
	check(sprite.texture == frames.get_frame_texture("idle_fixture_2", 1), "relic native idle frame frozen")
	player.queue_free()
	mob.queue_free()
	arena.queue_free()
	sprite.queue_free()
	anchor.queue_free()
	await process_frame
	if failures == 0: print("AUTHORED_STATE_MOTION_OK directions=8 assertions=", assertions, " monster_native=true relic_native=true")
	quit(0 if failures == 0 else 1)
