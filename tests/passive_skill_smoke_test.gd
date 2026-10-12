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
	preload("res://tests/legacy_skill_fixture.gd").install(world)

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
	if passive_count != 40:
		_fail("expected 40 reclassified passives, found %d" % passive_count)

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
		if passive_bonus != 14:
			_fail("요정 멘탈 포커스 + 집중 passive should total +14")
		var expected_attack: int = base_attack + equipment_bonus + enhance + active_bonus + passive_bonus
		if int(world.call("_effective_attack")) != expected_attack:
			_fail("passive attack bonus was not automatically applied")
		var expected_ranged: int = expected_attack + int(world.call("_stat_step_bonus", int(world.get("dex_stat")), 10, 2.0)) + int(world.call("_active_item_buff_total", "ranged_damage"))
		if int(world.call("_ranged_damage_stat")) != expected_ranged:
			_fail("passive attack bonus was not included in ranged skill damage")

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
	if int(world.call("_passive_skill_total", "atk")) != 10:
		_fail("기사 집중 should replace 요정 passive attack after class switch")

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

	# Removing a previous-class speed buff must also reset the runtime speed multiplier.
	world.call("_on_job_class_selected", "기사")
	world.set("active_skill_buffs", {"기사의 가속 7":{"remaining":60.0,"speed":1.115}})
	var speed_player: Node = world.get("player") as Node
	speed_player.call("set_skill_speed_multiplier", 1.115)
	world.call("_on_job_class_selected", "요정")
	if abs(float(speed_player.get("skill_speed_multiplier")) - 1.0) > 0.001:
		_fail("class change removed speed buff data but left player runtime speed active")

	# Restored active speed buffs must re-apply their runtime multiplier after load.
	world.set("active_skill_buffs", {"헤이스트":{"remaining":120.0,"speed":1.15}})
	var player_node: Node = world.get("player") as Node
	player_node.call("set_skill_speed_multiplier", 1.0)
	player_node.call("set_skill_speed_multiplier", float(world.call("_active_skill_speed_multiplier")))
	if abs(float(player_node.get("skill_speed_multiplier")) - 1.15) > 0.001:
		_fail("restored active speed buff did not reapply player speed multiplier")

	# Active skill buffs must be serializable alongside item buffs instead of silently disappearing.
	var serialized: String = JSON.stringify({"active_skill_buffs":pruned_buffs})
	var parsed_value: Variant = JSON.parse_string(serialized)
	if not (parsed_value is Dictionary):
		_fail("active skill buff save payload is not JSON-safe")
	else:
		var parsed_buffs: Variant = (parsed_value as Dictionary).get("active_skill_buffs", {})
		if not (parsed_buffs is Dictionary) or not (parsed_buffs as Dictionary).has("실드"):
			_fail("active skill buff did not survive save payload round-trip")

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
