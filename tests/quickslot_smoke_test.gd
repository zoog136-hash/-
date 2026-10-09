extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("QUICKSLOT FAIL: " + message)

func _run() -> void:
	var main_scene: PackedScene = load("res://Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn could not be loaded")
		_finish()
		return

	var world: Node = main_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	world.call("_on_job_class_selected", "기사")
	await process_frame
	world.call("_ensure_quickslots_seeded")
	var quickslots_value: Variant = world.get("quickslots")
	if not (quickslots_value is Array):
		_fail("quickslots is not an Array")
	else:
		var quickslots: Array = quickslots_value as Array
		if quickslots.size() != 8:
			_fail("quickslots size must be 8")
		var has_skill: bool = false
		var has_item: bool = false
		for value: Variant in quickslots:
			if value is Dictionary:
				var entry: Dictionary = value as Dictionary
				has_skill = has_skill or str(entry.get("kind", "")) == "skill"
				has_item = has_item or str(entry.get("kind", "")) == "item"
		if not has_skill:
			_fail("default quickslots contain no skill")
		if not has_item:
			_fail("default quickslots contain no consumable")

	world.level = 90
	world.equipped_items["weapon"] = {"name":"검사 양손검","type":"양손검","slot":"weapon"}
	var counter: Dictionary = world.original_skills.catalog.record_for("카운터 배리어")
	world.inventory[str(counter.book_name)] = 1
	world.original_skills.catalog.learn(str(counter.id))
	world.call("_on_quickslot_assignment_requested", 0, "skill", "카운터 배리어")
	world.call("_on_quickslot_assignment_requested", 1, "item", "HP 물약")
	var assigned: Array = world.get("quickslots") as Array
	if str((assigned[0] as Dictionary).get("id", "")) != "카운터 배리어":
		_fail("skill assignment failed")
	if str((assigned[1] as Dictionary).get("id", "")) != "HP 물약":
		_fail("item assignment failed")

	world.set("mp", 999)
	world.set("self_mode_enabled", false)
	var buffs: Dictionary = world.get("active_skill_buffs") as Dictionary
	buffs.erase("카운터 배리어")
	world.set("active_skill_buffs", buffs)
	# Clear an earlier automatic buff\u0027s GCD before testing explicit recast.
	world.set("skill_cooldowns", {})
	world.set("skill_global_cooldown", 0.0)
	world.set("auto_buff_check_timer", 0.0)
	world.call("_run_auto_buff_quickslots", 1.0)
	buffs = world.get("active_skill_buffs") as Dictionary
	if not buffs.has("카운터 배리어"):
		_fail("SELF OFF did not auto-cast registered buff")

	buffs.erase("카운터 배리어")
	world.set("active_skill_buffs", buffs)
	world.set("self_mode_enabled", true)
	world.set("auto_buff_check_timer", 0.0)
	world.call("_run_auto_buff_quickslots", 1.0)
	buffs = world.get("active_skill_buffs") as Dictionary
	if buffs.has("카운터 배리어"):
		_fail("SELF ON should disable auto buff recast")

	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("QUICKSLOT_SMOKE_OK: mixed slots and SELF auto-buff behavior validated")
		quit(0)
	else:
		print("QUICKSLOT_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
