extends SceneTree

const Catalog = preload("res://scripts/expedition/source_catalog.gd")
const Local = preload("res://scripts/expedition/local_runtime.gd")
var failures: Array[String] = []
var checks: int = 0

class MigrationHost extends Node:
	var pending_map_save_record: Dictionary = {"pending": true}

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)

func selection(id: int, level: int, owned: bool = true) -> Array:
	return [{"source_id": id, "skill_awaken_level": level, "owned": owned}]

func find_card(catalog: RefCounted, deck: int, grade: int) -> int:
	for card: Dictionary in catalog.rows("BuffCard"):
		if int(card.BuffCardDeckID) == deck and int(card.GradeID) == grade:
			return int(card.ID)
	return 0

func _initialize() -> void:
	var local := Local.new()
	var migration_host := MigrationHost.new()
	local.world = migration_host
	check(str(local.prepare(1, []).get("error", "")).contains("이전"), "pending map activation cannot create ambiguous paid transaction")
	local.world = null
	migration_host.free()
	check(local.validate(Local.fresh()).is_empty(), "fresh local namespace valid")
	check(local.check_load({}).is_empty(), "historical save without namespace valid")
	check(not local.check_load({Local.KEY: null}).is_empty(), "malformed namespace rejected")
	var job := {"id": 1, "spot_id": 1, "group_id": 242, "deck_id": 2, "cost": 10000, "identity": "source:m508:2:1", "duration": 28800, "remaining": 100, "status": "running", "completion_reward_id": 1}
	var fixture := Local.fresh()
	fixture.revision = 1
	fixture.jobs = [job]
	fixture.attempts = {"2": 1}
	check(local.validate(fixture).is_empty(), "bounded local checkpoint shape")
	check(local.validate(JSON.parse_string(JSON.stringify(fixture))).is_empty(), "JSON numeric checkpoint roundtrip")
	for mutation in [{"remaining": -1}, {"remaining": 0}, {"duration": 1}, {"identity": "source:m508:2:01"}, {"id": 2}]:
		var corrupt := fixture.duplicate(true)
		corrupt.jobs[0].merge(mutation, true)
		check(not local.validate(corrupt).is_empty(), "reject local checkpoint mutation "+str(mutation))
	var wrong_attempts := fixture.duplicate(true)
	wrong_attempts.attempts = {"2": 0}
	check(not local.validate(wrong_attempts).is_empty(), "attempts cannot erase paid departure")
	var catalog := Catalog.new()
	check(not catalog.install("/missing/expedition.json", "0".repeat(64)), "missing pack rejected")
	check(not catalog.ready(), "missing pack stays unavailable")
	check(not catalog.request_start(1, []).ok, "unavailable pack cannot start")
	var path := ""
	var sha := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expedition523-pack="): path = argument.trim_prefix("--expedition523-pack=")
		if argument.begins_with("--expedition523-sha256="): sha = argument.trim_prefix("--expedition523-sha256=")
	if not path.is_empty():
		check(catalog.install(path, sha), "actual private pack loads")
		if catalog.ready():
			var rare_doll := find_card(catalog, 2, 3)
			var rare_relic := find_card(catalog, 98, 3)
			check(rare_doll > 0 and rare_relic > 0, "exact source card identities")
			var valid: Dictionary = catalog.inspect(1, selection(rare_doll, 5))
			check(valid.static_conditions_met and not valid.can_start, "static conditions do not authorize RNG or activation")
			check(valid.group_id == 242, "skill level5 matches5-19 group")
			check(catalog.inspect(1, selection(rare_doll, 19)).group_id == 242, "skill level19 group")
			check(catalog.inspect(1, selection(rare_doll, 20)).group_id == 252, "skill level20 distinct group")
			check(not catalog.inspect(1, selection(rare_doll, 4)).static_conditions_met, "below skill level5 rejected")
			check(not catalog.inspect(1, selection(rare_doll, 21)).static_conditions_met, "level21 is not20")
			check(not catalog.inspect(1, selection(rare_doll, 20, false)).static_conditions_met, "unowned card rejected")
			check(not catalog.inspect(1, selection(rare_relic, 20)).static_conditions_met, "deck mismatch rejected")
			var low_relic: Dictionary = catalog.inspect(202, selection(rare_relic, 20))
			check(not low_relic.static_conditions_met and low_relic.completion.size() == 1 and not low_relic.event_rewards.is_empty(), "existing reward pool does not override minimum grade")
			var low_doll: Dictionary = catalog.inspect(223, selection(rare_doll, 20))
			check(not low_doll.static_conditions_met and low_doll.completion.size() == 1 and low_doll.event_rewards.is_empty(), "completion display does not override minimum grade or missing pool")
			var event_doll := find_card(catalog, 2, 71)
			check(event_doll > 0 and not catalog.inspect(1, selection(event_doll, 20)).static_conditions_met, "grade71 has no invented hero group")
			var candidates: Array = catalog.completion_box_candidates(166594)
			var coin_amounts: Array = []
			for row: Dictionary in candidates:
				if int(row.ItemClassID) == 3252: coin_amounts.append(int(row.ItemAmount))
			coin_amounts.sort()
			check(coin_amounts == [100, 1000], "same item retains distinct quantity candidates")
			check(catalog.synergy_evidence().size() == 7, "all synergies retained including unresolved server274")
			var before: String = JSON.stringify(catalog.rows("MagicDollExpeditionSpot"))
			var copy: Array = catalog.spots()
			copy[0].ExpeditionCost = 0
			check(JSON.stringify(catalog.spots()) == before, "caller cannot mutate catalogue rows")
			check(not catalog.install(path, "0".repeat(64)), "wrong hash rejected")
			check(catalog.ready() and catalog.pack_sha256 == sha, "failed replacement preserves active catalogue")
			check(not catalog.request_start(1, selection(rare_doll, 20)).ok, "no invented execution even with static conditions")
			check(JSON.stringify(catalog.spots()) == before, "request leaves source rows unchanged")
	print("EXPEDITION523_CATALOG_RESULT "+JSON.stringify({"checks": checks, "failures": failures, "source_installed": catalog.ready()}))
	quit(0 if failures.is_empty() else 1)
