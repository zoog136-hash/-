extends SceneTree
## History journals no rule reads (user 2026-11-19 "... 쓸데없이 비용만
## 차지하는데이터들 ... 다 삭제해"):
## - consumable_state.source_native_bag_uses (every opened box's inputs,
##   rewards and RNG), source_native_ammo_uses (every shot) and
##   source_native_skill_material_uses (every cast) are not written and an
##   old save's box journal is dropped on load;
## - unconfirmed523 live-event replay keys (session nonce + kill/pickup id,
##   up to 8192 per save) stay in memory, bounded, and are not saved;
##   "source_grant:" one-time grant keys are kept;
## - source_item_catalog_history (earlier definition-pack identities).
## Rules always; with the original definition ZIP, actual Main kills/saves/
## reloads keep event counters and the bag.
const UNCONFIRMED = preload("res://scripts/unconfirmed523/runtime.gd")
const SERVICE = preload("res://scripts/consumable_service.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("SAVE_JOURNAL_TRIM_FAIL: ", label)
	return condition

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	var state: Dictionary = {"schema":1,"revision":4,"domains":{},"event_counters":{"kill":3},"bonus_rewards":[],"event_receipts":{"abc:aden:1:1":true,"abc:floor1":true,"source_grant:quest523:pass_exp:1:2:ff":true,"source_grant:unconfirmed523:blessing_use:3":true}}
	var saved: Dictionary = UNCONFIRMED.saved_form(state)
	check(saved.event_receipts.keys() == ["source_grant:quest523:pass_exp:1:2:ff","source_grant:unconfirmed523:blessing_use:3"], "saved form keeps only one-time grant keys")
	check(state.event_receipts.size() == 4, "saved_form never edits the live state")
	check(saved.event_counters == state.event_counters and saved.revision == 4, "counters and revision kept")
	check(is_same(UNCONFIRMED.saved_form(saved), saved), "an already saved form is returned as is")
	var many: Dictionary = {"event_receipts":{"source_grant:x":true}}
	for index: int in range(UNCONFIRMED.LIVE_RECEIPT_LIMIT + UNCONFIRMED.LIVE_RECEIPT_TRIM + 5): many.event_receipts["n:%d" % index] = true
	UNCONFIRMED._bound_live_receipts(many)
	check(many.event_receipts.has("source_grant:x") and many.event_receipts.size() == UNCONFIRMED.LIVE_RECEIPT_LIMIT + 1 and many.event_receipts.has("n:%d" % (UNCONFIRMED.LIVE_RECEIPT_LIMIT + UNCONFIRMED.LIVE_RECEIPT_TRIM + 4)) and not many.event_receipts.has("n:0"), "live keys bounded in memory (oldest go first), grant keys kept")
	var service: Node = SERVICE.new()
	service.import_state({"source_native_bag_uses":{"r1":{"schema":1,"input":[{"q":1}],"selected_rewards":[{"id":5}]}},"source_native_stack_uses":{"u":{"receipt":{},"used_quantity":1,"remaining_quantity":0}},"elixirs_used":2})
	var exported: Dictionary = service.export_state()
	check(not exported.has("source_native_bag_uses"), "an old box journal is dropped on load and not exported")
	check(exported.has("source_native_stack_uses") and int(exported.elixirs_used) == 2, "the use ledger and other consumable state stay")
	service.free()
	var text: String = FileAccess.get_file_as_string("res://scripts/loot/current523_native_stack.gd")
	check(not text.contains("journal[id]=") and not text.contains("journal[receipt_id]="), "no shot/cast/box journal rows are written")

## user:// is shared by CI tests: put every save file back as it was.
var _prior_files: Dictionary = {}
func remember_user_files() -> void:
	var directory: String = ProjectSettings.globalize_path("user://")
	for name: String in DirAccess.get_files_at(directory):
		if name.begins_with("twilight_v20_save"): _prior_files[name] = FileAccess.get_file_as_bytes(directory.path_join(name))
func restore_user_files() -> void:
	var directory: String = ProjectSettings.globalize_path("user://")
	for name: String in DirAccess.get_files_at(directory):
		if name.begins_with("twilight_v20_save") and not _prior_files.has(name): DirAccess.remove_absolute(directory.path_join(name))
	for name: String in _prior_files:
		var file := FileAccess.open(directory.path_join(name), FileAccess.WRITE)
		if file != null: file.store_buffer(_prior_files[name]); file.close()

func runtime() -> void:
	remember_user_files()
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false); world.player.auto_enabled = false
	check(world._save_game(true) == OK, "baseline save")
	var content: Variant = world.unconfirmed523
	if check(content != null and not content.save_blocked, "추가 콘텐츠 runtime ready"):
		var counters_before: Dictionary = content.state.event_counters.duplicate(true)
		for index: int in range(40):
			content.record_event("kill",{"source_id":45,"npc_id":45,"event_id":"probe:%d:1" % index,"player_credit":true,"amount":1})
		content.record_event("kill",{"source_id":45,"npc_id":45,"event_id":"probe:0:1","player_credit":true,"amount":1})
		var live: int = 0
		for id: String in content.state.event_receipts:
			if not id.begins_with("source_grant:"): live += 1
		evidence["live_in_memory"] = live
		check(int(content.state.event_counters.get("kill",0)) == int(counters_before.get("kill",0)) + 40, "40 kills counted once each (a repeated id is ignored)")
		check(world._save_game(true) == OK, "save after kills")
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
		var saved_receipts: Dictionary = saved.get("unconfirmed523",{}).get("event_receipts",{})
		var saved_live: int = 0
		for id: String in saved_receipts:
			if not id.begins_with("source_grant:"): saved_live += 1
		check(saved_live == 0 and live >= 40, "live replay keys are not saved (%d in memory)" % live)
		check(int(saved.unconfirmed523.event_counters.get("kill",0)) == int(counters_before.get("kill",0)) + 40, "saved counters keep the kills")
		# An old save holding live keys and a box journal loads without them.
		saved.unconfirmed523.event_receipts["oldnonce:aden:1:1"] = true
		if not saved.has("consumable_state"): saved["consumable_state"] = {}
		saved.consumable_state["source_native_bag_uses"] = {"r1":{"schema":1,"input":[],"selected_rewards":[]}}
		saved["source_item_catalog_history"] = [{"schema":3,"sha256":"old"}]
		var file := FileAccess.open(world.save_path(), FileAccess.WRITE); file.store_string(JSON.stringify(saved)); file.close()
		var gold: int = world.gold; var bag: String = JSON.stringify(JSON.parse_string(JSON.stringify(world.inventory)),"",true)
		world._load_game(true)
		check(not content.state.event_receipts.has("oldnonce:aden:1:1") and int(content.state.event_counters.get("kill",0)) == int(counters_before.get("kill",0)) + 40, "old live keys dropped on load, counters kept")
		check(not world.consumable_service.export_state().has("source_native_bag_uses") and world.patch523_owner_state_problem.is_empty() and not content.save_blocked, "old box journal dropped, no ownership problem")
		check(int(world.gold) == gold and JSON.stringify(JSON.parse_string(JSON.stringify(world.inventory)),"",true) == bag, "gold and bag unchanged")
		check(world._save_game(true) == OK, "re-save after load")
		var written: String = FileAccess.get_file_as_string(world.save_path())
		check(not written.contains("source_native_bag_uses"), "re-save without the box journal")
		check(not written.contains("source_item_catalog_history"), "re-save without the definition-pack history")
		check(not written.contains("oldnonce:"), "re-save without old live event keys")
	world.queue_free()
	await process_frame
	restore_user_files()

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		await runtime()
	print("SAVE_JOURNAL_TRIM_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
