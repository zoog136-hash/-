extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("RESTORE_GUARD FAIL: ", message)

func run() -> void:
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "enter actual gameplay")
	await process_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world._clear_monsters()
	world.level = 90
	world._on_job_class_selected("마법사")
	world.equipped_items.clear()
	world.equipped_catalog.clear()
	var service := world.original_skills
	var catalog := service.catalog
	catalog.learned.clear()
	catalog.seed_starters()
	var guardian: Dictionary = catalog.record_for("서먼 가디언")
	var turn: Dictionary = catalog.record_for("턴 언데드")
	check(not guardian.is_empty() and not turn.is_empty(), "known persisted skill fixtures")
	if guardian.is_empty() or turn.is_empty():
		world.queue_free()
		await process_frame
		quit(1)
		return

	var guardian_id := str(guardian.id)
	var turn_id := str(turn.id)
	var valid_shield := {"amount":80, "remaining":12.0}
	catalog.learned[turn_id] = 1
	service.import_state({"shields": {turn_id: valid_shield, guardian_id: valid_shield}})
	check(service.shields.is_empty(), "an unrelated attack and unlearned summon cannot restore absorption")
	check(not world.active_skill_buffs.has(str(guardian.name)), "invalid summon creates no aura")

	service.import_state({"shields": {turn_id: "invalid", guardian_id: []}})
	check(service.shields.is_empty(), "malformed shield payload is ignored")
	service.import_state({"shields": []})
	check(service.shields.is_empty(), "non-dictionary shield collection is ignored")

	catalog.learned[guardian_id] = 1
	service.import_state({"shields": {guardian_id: valid_shield}})
	check(int(service.shields.get(guardian_id, {}).get("amount", -1)) == 80, "valid learned guardian shield retains capacity")
	check(str(world.active_skill_buffs.get(str(guardian.name), {}).get("summon_stage", "")) == "shield", "valid guardian restores shield aura")
	var stored: Dictionary = service.export_state()
	service.import_state(JSON.parse_string(JSON.stringify(stored)))
	check(int(service.shields.get(guardian_id, {}).get("amount", -1)) == 80, "JSON save round trip retains valid shield")
	check(str(world.active_skill_buffs.get(str(guardian.name), {}).get("summon_stage", "")) == "shield", "JSON save round trip preserves guardian aura")

	catalog.learned.erase(guardian_id)
	service.import_state({"shields": {guardian_id: valid_shield}})
	check(service.shields.is_empty(), "revoked guardian ownership cannot restore a shield")
	check(not world.active_skill_buffs.has(str(guardian.name)), "revoked guardian aura is cleared")

	catalog.learned[guardian_id] = 1
	world._on_job_class_selected("기사")
	catalog.learned[guardian_id] = 1 # Still owned, but not permitted by this job.
	service.import_state({"shields": {guardian_id: valid_shield}})
	check(service.shields.is_empty(), "wrong-class guardian shield cannot absorb damage")

	world._on_job_class_selected("마법사")
	catalog.learned[guardian_id] = 1
	service.import_state({"shields": {guardian_id: {"amount":0, "remaining":12}}})
	check(service.shields.is_empty(), "empty shield capacity cannot be restored")
	service.import_state({"shields": {guardian_id: {"amount":80, "remaining":0}}})
	check(service.shields.is_empty(), "expired shield cannot be restored")

	world.queue_free()
	for _frame: int in range(3):
		await process_frame
	if failures.is_empty():
		print("ORIGINAL_SKILL_RESTORE_GUARD_OK checks=", checks)
	quit(0 if failures.is_empty() else 1)
