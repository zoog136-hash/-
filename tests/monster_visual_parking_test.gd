extends SceneTree
## Sleeping ordinary monsters drop their pose frames and get the same
## SpriteFrames back before they can reach the screen. Bosses never park.

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _initialize() -> void:
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for i: int in 200: await process_frame
	var world: Node = root.get_node("World")
	var monsters: Array = world.get_node("Monsters").get_children()
	var parked: int = 0
	var target: Node = null
	for monster: Node in monsters:
		if monster.visual_parked:
			parked += 1
			check(not monster.is_boss, "boss never parks " + str(monster.monster_name))
			check(not monster.is_physics_processing(), "only sleeping actors park " + str(monster.monster_name))
			check(monster.motion.frame_source == null and monster.sprite.texture != null, "parked actor keeps one still frame " + str(monster.monster_name))
			if target == null: target = monster
	check(parked > 0, "a populated field parks far sleeping monsters")
	var restored: bool = false
	if target != null:
		var expected: SpriteFrames = preload("res://scripts/animation/animation_catalog.gd").frames_for_profile(target.motion.profile, "")
		world.player.global_position = target.global_position + Vector2(220, 0)
		for i: int in 90: await physics_frame
		restored = not target.visual_parked and target.motion.frame_source == expected and target.motion._resolved_key != ""
		check(restored, "approached monster restores its own frames and resolves a pose")
		world.player.global_position = target.global_position + Vector2(6000, 0)
		for i: int in 400: await physics_frame
		check(target.visual_parked, "monster seen before parks again after staying asleep")
	print("MONSTER_VISUAL_PARKING_RESULT ", JSON.stringify({"monsters":monsters.size(), "parked":parked, "restored":restored, "failures":failures}))
	if failures.is_empty(): print("MONSTER_VISUAL_PARKING_OK")
	else:
		for failure: String in failures: print("MONSTER_VISUAL_PARKING_FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)
