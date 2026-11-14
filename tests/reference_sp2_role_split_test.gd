extends "res://tests/reference_sp2_load_memo_test.gd"
## A first shared NPC bank build spread over attempts: with a role budget each
## attempt builds one more role, the finished bank equals the one-shot build
## and the mutable oracle, role parts are dropped once it is prepared, and
## unbudgeted callers are unchanged.
##   godot --headless --path <repo> --script res://tests/reference_sp2_role_split_test.gd
const PREPARED = preload("res://scripts/resources/reference_sp2_prepared_bank.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")

func shared(bank: RefCounted, data: Dictionary) -> Dictionary:
	return bank.load_shared_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "npc")

func run() -> void:
	var directory: String = "user://role_split_test_%d" % OS.get_process_id()
	var data: Dictionary = fixture(directory)
	PREPARED.clear()
	BANK._role_memo.clear()
	var oracle: Dictionary = BANK.new().load_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "npc")
	var whole: Dictionary = shared(BANK.new(), data)
	check(oracle.ok and whole.ok, "fixture builds")
	# Budgeted: one role per attempt.
	PREPARED.clear()
	BANK._role_memo.clear()
	var attempts: int = 0
	var result: Dictionary = {}
	var deferred: int = 0
	var owners: Array = [] # prepared snapshots are weak: a live bank keeps it
	while attempts < 10:
		attempts += 1
		BANK.role_build_budget = 1
		var owner := BANK.new()
		owners.append(owner)
		result = shared(owner, data)
		BANK.role_build_budget = -1
		if result.get("error") == BANK.ROLE_DEFERRED:
			deferred += 1
			check(PREPARED.size() == 0, "a deferred attempt prepares no snapshot")
			continue
		break
	check(result.ok and deferred == BINDINGS.size() - 1 and attempts == BINDINGS.size(), "one role per attempt: %d attempts, %d deferred" % [attempts, deferred])
	check(var_to_bytes(result) == var_to_bytes(whole), "the spread build equals the one-shot shared build")
	check(var_to_bytes(result) == var_to_bytes(oracle), "the spread build equals the mutable validation oracle")
	check(BANK._role_memo.is_empty(), "role parts are dropped once the combined bank is prepared")
	# The prepared bank is now a hit even with a zero budget.
	BANK.role_build_budget = 0
	HITCH._counters.clear()
	var hit: Dictionary = shared(BANK.new(), data)
	BANK.role_build_budget = -1
	check(hit.ok and is_same(hit, result) and HITCH._counters.get("sp2.prepared_hit") == 1, "a prepared bank needs no role builds")
	# A zero budget defers without doing any role work.
	PREPARED.clear()
	BANK._role_memo.clear()
	BANK.role_build_budget = 0
	HITCH._counters.clear()
	var none: Dictionary = shared(BANK.new(), data)
	BANK.role_build_budget = -1
	check(none.get("error") == BANK.ROLE_DEFERRED and not HITCH._counters.has("sp2.layer_validate"), "zero budget defers before validating layers")
	# Unbudgeted callers build everything in one call, keep nothing.
	PREPARED.clear()
	BANK._role_memo.clear()
	var plain: Dictionary = shared(BANK.new(), data)
	check(plain.ok and var_to_bytes(plain) == var_to_bytes(whole) and BANK._role_memo.is_empty(), "default (-1) is the one-shot build")
	var mutable: Dictionary = BANK.new().load_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "npc")
	check(mutable.ok and not mutable.is_read_only() and BANK._role_memo.is_empty(), "the mutable API never uses role parts")
	# A role part never outlives a changed member: the final stamp check re-verifies.
	PREPARED.clear()
	BANK._role_memo.clear()
	BANK.role_build_budget = 1
	var first: Dictionary = shared(BANK.new(), data)
	BANK.role_build_budget = -1
	check(first.get("error") == BANK.ROLE_DEFERRED and BANK._role_memo.size() == 1, "one role part kept between attempts")
	var bad: Dictionary = fixture(directory + "_bad", "wrong_attributes")
	check(not shared(BANK.new(), bad).ok, "invalid proof still rejected")
	BANK._role_memo.clear()
	owners.clear()
	PREPARED.clear()
	print("REFERENCE_SP2_ROLE_SPLIT_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "synthetic_only": true}))
	quit(0 if failures.is_empty() else 1)
