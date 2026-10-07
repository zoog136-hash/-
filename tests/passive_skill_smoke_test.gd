extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("PASSIVE SKILL FAIL: " + message)

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		_fail("Main.tscn load failed")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var skills: Array = world.get("skills_db") as Array
	if skills.is_empty():
		_fail("skills DB empty")
	var passive_count: int = 0
	for value: Variant in skills:
		if not (value is Dictionary):
			continue
		var skill: Dictionary = value as Dictionary
		var activation: String = str(skill.get("activation", ""))
		if activation != "active" and activation != "passive":
			_fail("invalid or missing activation: " + str(skill.get("name","")))
		if activation == "passive":
			passive_count += 1
	if passive_count <= 0:
		_fail("no passive skills marked in DB")

	var focus: Dictionary = world.call("_skill_record", "멘탈 포커스")
	if focus.is_empty():
		_fail("멘탈 포커스 missing")
	else:
		if not bool(world.call("_is_passive_skill", focus)):
			_fail("멘탈 포커스 should be passive")
		world.call("_on_job_class_selected", "요정")
		var base_attack: int = int(world.get("attack_power"))
		var equipment_bonus: int = 0
		for rec: Dictionary in world.call("_all_equipped_records"):
			equipment_bonus += int(rec.get("atk", 0))
		var enhance: int = int(world.call("_equipment_enhancement_level", "weapon"))
		var active_bonus: int = int(world.call("_active_skill_buff_total", "atk"))
		var passive_bonus: int = int(world.call("_passive_skill_total", "atk"))
		if passive_bonus != 4:
			_fail("요정 멘탈 포커스 passive attack should be +4")
		var expected_attack: int = base_attack + equipment_bonus + enhance + active_bonus + 4
		if int(world.call("_effective_attack")) != expected_attack:
			_fail("passive attack bonus was not automatically applied")

		var mp_before: int = int(world.get("mp"))
		world.call("_cast_job_skill", "멘탈 포커스")
		if int(world.get("mp")) != mp_before:
			_fail("passive skill direct-use path spent MP")
		var active_buffs: Dictionary = world.get("active_skill_buffs") as Dictionary
		if active_buffs.has("멘탈 포커스"):
			_fail("passive skill was incorrectly added to active buffs")

		var quickbar: Array = world.call("_quickbar_job_skills") as Array
		for q: Variant in quickbar:
			if q is Dictionary and str((q as Dictionary).get("name","")) == "멘탈 포커스":
				_fail("passive skill appeared in active quickbar list")

	world.call("_on_job_class_selected", "기사")
	if int(world.call("_passive_skill_total", "atk")) != 0:
		_fail("요정 passive remained active after switching to 기사")

	var active_skill: Dictionary = world.call("_skill_record", "에너지 볼트")
	if active_skill.is_empty() or bool(world.call("_is_passive_skill", active_skill)):
		_fail("에너지 볼트 should remain active")

	# Old saves can contain a skill that later became passive, or skills from another job.
	world.call("_on_job_class_selected", "요정")
	world.set("quickslots", [
		{"kind":"skill","id":"멘탈 포커스"},
		{"kind":"skill","id":"기사의 수호 5"},
		{"kind":"skill","id":"에너지 볼트"},
		{"kind":"item","id":"HP 물약"},
		{}, {}, {}, {}
	])
	world.call("_sanitize_quickslots_for_current_job")
	var cleaned: Array = world.get("quickslots") as Array
	if not (cleaned[0] as Dictionary).is_empty():
		_fail("legacy passive quickslot was not cleared")
	if not (cleaned[1] as Dictionary).is_empty():
		_fail("wrong-job active skill quickslot was not cleared")
	if str((cleaned[2] as Dictionary).get("id","")) != "에너지 볼트":
		_fail("valid common active skill was incorrectly cleared")
	if str((cleaned[3] as Dictionary).get("id","")) != "HP 물약":
		_fail("item quickslot was incorrectly cleared")

	# Active buffs from the previous class must not leak after a class change.
	world.set("active_skill_buffs", {
		"기사의 수호 5":{"remaining":60.0,"def":6},
		"실드":{"remaining":60.0,"def":3},
		"멘탈 포커스":{"remaining":60.0,"atk":4}
	})
	world.call("_prune_active_skill_buffs_for_current_job")
	var pruned_buffs: Dictionary = world.get("active_skill_buffs") as Dictionary
	if pruned_buffs.has("기사의 수호 5"):
		_fail("previous-job active buff leaked into new class")
	if pruned_buffs.has("멘탈 포커스"):
		_fail("passive skill remained in active buff dictionary")
	if not pruned_buffs.has("실드"):
		_fail("valid common active buff was incorrectly removed")

	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("PASSIVE_SKILL_SMOKE_OK: passive ownership and active-use separation validated")
		quit(0)
	else:
		print("PASSIVE_SKILL_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
