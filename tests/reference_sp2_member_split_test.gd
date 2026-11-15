extends "res://tests/reference_sp2_load_memo_test.gd"
## A first shared NPC bank build spread over attempts one level finer than
## roles: with a member budget each attempt verifies (parses) at most that many
## new original members, the finished bank equals the one-shot build and the
## mutable oracle, a retained member is reused only while its file is the
## verified one, the budget cannot hold a role forever, and unbudgeted callers
## keep nothing.
##   godot --headless --path <repo> --script res://tests/reference_sp2_member_split_test.gd
const PREPARED = preload("res://scripts/resources/reference_sp2_prepared_bank.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")

func shared(bank: RefCounted, data: Dictionary) -> Dictionary:
	return bank.load_shared_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "npc")

func _reset_state() -> void:
	PREPARED.clear()
	BANK._role_memo.clear()
	BANK.forget_member_meta()
	BANK.role_build_budget = -1
	BANK.member_verify_budget = -1

## Repeats a shared build with the given budgets until it is not deferred.
func _spread(data: Dictionary, members: int, roles: int, owners: Array, limit: int = 40) -> Dictionary:
	var result: Dictionary = {}
	var attempts: int = 0
	var deferred: int = 0
	var most_verified: int = 0
	while attempts < limit:
		attempts += 1
		BANK.role_build_budget = roles
		BANK.member_verify_budget = members
		HITCH._counters.clear()
		var owner := BANK.new()
		owners.append(owner) # prepared snapshots are weak: a live bank keeps it
		result = shared(owner, data)
		BANK.role_build_budget = -1
		BANK.member_verify_budget = -1
		most_verified = maxi(most_verified, int(HITCH._counters.get("sp2.member_verify", 0)))
		if result.get("error") == BANK.ROLE_DEFERRED:
			deferred += 1
			continue
		break
	return {"result":result, "attempts":attempts, "deferred":deferred, "most_verified":most_verified}

func run() -> void:
	var directory: String = "user://member_split_test_%d" % OS.get_process_id()
	var data: Dictionary = fixture(directory)
	ASSETS.reset_for_tests()
	BANK.forget_verified_members()
	_reset_state()
	var oracle: Dictionary = BANK.new().load_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "npc")
	var whole: Dictionary = shared(BANK.new(), data)
	check(oracle.ok and whole.ok, "fixture builds")
	check(BANK._member_meta.is_empty(), "the default (-1) build retains no member entries")
	var owners: Array = []
	# One member per attempt, roles unlimited.
	_reset_state()
	var one: Dictionary = _spread(data, 1, -1, owners)
	check(one.result.get("ok", false), "member-budgeted build completes")
	check(one.most_verified <= 1, "no attempt verifies more than one new member (max %d)" % one.most_verified)
	check(one.deferred >= 2, "a three-member bank needs several attempts (%d deferred)" % one.deferred)
	check(var_to_bytes(one.result) == var_to_bytes(whole), "the spread build equals the one-shot shared build")
	check(var_to_bytes(one.result) == var_to_bytes(oracle), "the spread build equals the mutable validation oracle")
	check(BANK._member_deferrals.is_empty(), "finished roles keep no deferral count")
	check(BANK._member_meta.size() <= BANK.MEMBER_META_MAX and BANK._member_meta.size() >= 1, "verified members are retained, bounded")
	# Together with the role budget (the population's real setting).
	_reset_state()
	var both: Dictionary = _spread(data, 2, 1, owners)
	check(both.result.get("ok", false) and both.most_verified <= 2 and var_to_bytes(both.result) == var_to_bytes(whole), "role and member budgets combine to the same bank")
	# The mutable API with a budget still returns independent, mutable data.
	_reset_state()
	var mutable: Dictionary = {}
	for attempt: int in 20:
		BANK.member_verify_budget = 1
		mutable = BANK.new().load_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "npc")
		BANK.member_verify_budget = -1
		if mutable.get("error") != BANK.ROLE_DEFERRED: break
	check(mutable.get("ok", false) and not mutable.is_read_only() and bytes_equal(mutable, oracle), "budgeted mutable load equals the oracle and stays mutable")
	# A zero budget cannot hold a role forever.
	_reset_state()
	var stuck: Dictionary = _spread(data, 0, -1, owners)
	check(stuck.result.get("ok", false) and stuck.deferred >= BANK.MEMBER_DEFERRALS_MAX and stuck.attempts <= BANK.MEMBER_DEFERRALS_MAX * BINDINGS.size() + 1, "a zero budget is lifted after the deferral limit (%d attempts)" % stuck.attempts)
	# A retained member is not reused once its file changed: verified again.
	_reset_state()
	BANK.member_verify_budget = 8
	var warm: Dictionary = BANK.new().load_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "npc")
	BANK.member_verify_budget = -1
	check(warm.ok and not BANK._member_meta.is_empty(), "a budgeted load retains its members")
	var key: String = BANK._member_meta.keys()[0]
	BANK._verified_members[BANK._member_meta[key].path] = ["changed", 0, 0]
	HITCH._counters.clear()
	BANK.member_verify_budget = 8
	var again: Dictionary = BANK.new().load_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "npc")
	BANK.member_verify_budget = -1
	check(again.ok and int(HITCH._counters.get("sp2.member_verify", 0)) >= 1, "a member whose verification stamp changed is verified again")
	HITCH._counters.clear()
	BANK.member_verify_budget = 8
	var reused: Dictionary = BANK.new().load_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "npc")
	BANK.member_verify_budget = -1
	check(reused.ok and int(HITCH._counters.get("sp2.member_verify", 0)) == 0 and int(HITCH._counters.get("sp2.member_meta_hit", 0)) >= 1, "unchanged retained members are reused without a parse")
	check(bytes_equal(reused, oracle), "a reused-member load equals the oracle")
	BANK.forget_verified_members()
	check(BANK._member_meta.is_empty() and BANK._member_deferrals.is_empty(), "forgetting verified members also forgets retained member entries")
	# Invalid proofs are still rejected under a budget.
	var bad: Dictionary = fixture(directory + "_bad", "wrong_attributes")
	_reset_state()
	var rejected: Dictionary = _spread(bad, 1, -1, owners)
	check(not rejected.result.get("ok", true) and rejected.result.get("error") != BANK.ROLE_DEFERRED, "invalid proof still rejected")
	_reset_state()
	owners.clear()
	print("REFERENCE_SP2_MEMBER_SPLIT_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "synthetic_only": true}))
	quit(0 if failures.is_empty() else 1)
