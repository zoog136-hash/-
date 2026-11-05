extends SceneTree
const Attempt = preload("res://scripts/honing/durable_attempt.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
const PATH: String = "user://honing-synthetic-transaction.json"
var checks: int = 0
var failures: int = 0

# Explicit synthetic rule/host adapter. This is not production authorization or
# PR262, Main, original RNG, or source outcome verification.
class FixtureAdapter extends "res://scripts/honing/durable_attempt.gd":
	var live: Dictionary = {}
	var authorized: bool = true
	var writes: int = 0
	var adopts: int = 0
	var mode: String = "ok"
	var saw_unchanged_live: bool = false
	var nested_code: String = ""
	func _authorize(before: Dictionary, _candidate: Dictionary) -> bool:
		return authorized and _same(live, before)
	func _write_payload(path: String, candidate: Dictionary) -> Error:
		writes += 1
		saw_unchanged_live = live.item_instances.a.get("synthetic_result") == null
		nested_code = commit(path, live, candidate).code
		if mode == "fail": return ERR_CANT_CREATE
		if mode == "false_ok": return OK
		if mode == "corrupt":
			Writer.write_text(path, "broken")
			return ERR_FILE_CORRUPT
		var error: Error = Writer.write(path, candidate)
		if mode == "write_then_error": return ERR_CANT_CREATE
		return error
	func _adopt_payload(candidate: Dictionary) -> bool:
		adopts += 1
		if mode == "adopt_fail": return false
		live = candidate.duplicate(true)
		return true

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func fixture() -> Dictionary:
	return {"inventory":{"gear":2,"material":5},
		"item_instances":{"a":{"name":"gear","level":7,"unknown_option":{"x":3}},
			"b":{"name":"gear","level":9},"m":{"quantity":5}},
		"quest_state":{"used":5}, "other_save_section":{"unchanged":[1,2,3]}}

func candidate(before: Dictionary) -> Dictionary:
	var after: Dictionary = before.duplicate(true)
	after.inventory.material = 3
	after.item_instances.m.quantity = 3
	after.quest_state.used = 7
	after.item_instances.a.synthetic_result = "fixture-only"
	return after

func _initialize() -> void:
	var before: Dictionary = fixture()
	var after: Dictionary = candidate(before)
	if "--restore-only" in OS.get_cmdline_user_args():
		var restored: Dictionary = Attempt._read(PATH)
		check(restored.ok and Attempt._same(restored.payload,after),"fresh process restores all synthetic candidate sections")
		print("HONING_FRESH_PROCESS_RESTORE failures=",failures)
		quit(1 if failures else 0)
		return
	check(Writer.write(PATH,before) == OK,"real atomic writer creates synthetic baseline")
	var denied := Attempt.new()
	check(denied.commit(PATH,before,after).code == "source_transaction_not_authorized","default adapter never authorizes source-unknown candidate")
	check(Attempt._same(Attempt._read(PATH).payload,before),"default refusal preserves file")
	var adapter := FixtureAdapter.new()
	adapter.live = before.duplicate(true)
	var result: Dictionary = adapter.commit(PATH,before,after)
	check(result.ok and adapter.writes == 1 and adapter.adopts == 1,"one write then one adoption")
	check(adapter.saw_unchanged_live,"no live mutation before durable save")
	check(adapter.nested_code == "attempt_already_used","reentrant duplicate blocked during writer")
	check(Attempt._same(adapter.live,after) and Attempt._same(Attempt._read(PATH).payload,after),"disk and live inventory instances ledger agree")
	check(Attempt._same(adapter.live.item_instances.b,before.item_instances.b),"same-name other physical item preserved")
	check(adapter.live.item_instances.a.unknown_option.x == 3 and adapter.live.item_instances.a.level == 7,"opaque options and enchantment preserved")
	check(Attempt._same(adapter.live.other_save_section,before.other_save_section),"unrelated save content preserved")
	check(adapter.commit(PATH,before,after).code == "attempt_already_used" and adapter.writes == 1,"second click never rewrites")
	after.item_instances.a.synthetic_result = "caller mutation"
	check(adapter.live.item_instances.a.synthetic_result == "fixture-only","adopted result isolated from caller")
	after = candidate(before)
	for mode: String in ["fail","false_ok","corrupt","write_then_error","adopt_fail"]:
		Writer.write(PATH,before)
		adapter = FixtureAdapter.new()
		adapter.live = before.duplicate(true)
		adapter.mode = mode
		result = adapter.commit(PATH,before,after)
		check(not result.ok and adapter.reload_required,mode + " requires reload")
		check(Attempt._same(adapter.live,before),mode + " leaves live unchanged")
		check(adapter.commit(PATH,before,after).code == "reload_required" and adapter.writes == 1,mode + " cannot retry")
		if mode == "write_then_error":
			check(result.durable_matches_candidate and adapter.adopts == 0,"durable write followed by error detected without live adoption")
		if mode == "fail": check(Attempt._same(Attempt._read(PATH).payload,before),"failed write preserves original file")
		if mode == "false_ok": check(not result.durable_matches_candidate,"writer success without durable candidate rejected")
	Writer.write(PATH,before)
	adapter = FixtureAdapter.new()
	adapter.live = before.duplicate(true)
	adapter.live.inventory.material = 0
	check(adapter.commit(PATH,before,after).code == "source_transaction_not_authorized" and adapter.writes == 0,"stale live balance rejected")
	adapter.live = before.duplicate(true)
	var other: Dictionary = before.duplicate(true)
	other.other_save_section.unchanged.append(4)
	Writer.write(PATH,other)
	check(adapter.commit(PATH,before,after).code == "durable_base_changed" and adapter.writes == 0,"external save change rejected")
	Writer.write_text(PATH,"broken")
	check(adapter.commit(PATH,before,after).code == "durable_base_changed" and adapter.writes == 0,"corrupt baseline not overwritten")
	check(adapter.commit(PATH,before,{"inventory":{}}).code == "invalid_full_payload","ledger-less payload rejected")
	# Fresh readers re-open the disk; this is not a Main/process restart test.
	Writer.write(PATH,after)
	for iteration: int in range(5):
		var restored: Dictionary = Attempt._read(PATH)
		check(restored.ok and Attempt._same(restored.payload,after),"disk reopen " + str(iteration))
	for iteration: int in range(3):
		var output: Array = []
		var exit_code: int = OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/honing_durable_attempt_test.gd","--","--restore-only"],output,true)
		check(exit_code == 0 and str(output).contains("HONING_FRESH_PROCESS_RESTORE failures=0"),"separate process restore " + str(iteration))
	DirAccess.remove_absolute(PATH)
	print("HONING_DURABLE_ATTEMPT_CHECKS ",checks," failures=",failures)
	quit(1 if failures else 0)
