extends SceneTree
const Runtime = preload("res://scripts/progression/growth96_runtime.gd")
const Source = preload("res://scripts/progression/growth96_source.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
var checks := 0
var failures: Array[String] = []

class Host extends Node:
	var level := 96
	var experience := 900
	var exp_need := 1000
	var inventory: Dictionary = {"existing-material":19,"[마법인형 카드 상자](영웅)":11}
	var item_db: Array = []
	var catalog_db: Dictionary = {"아이템":[{"name":"[마법인형 카드 상자](영웅)","source":"inven","sourceId":"259483"}]}
	var item_weight_index: Dictionary = {}
	var token_locked := false
	var pending_map_save_record: Dictionary = {}
	var fail_write := false
	var writes := 0
	var growth96
	var rng := RandomNumberGenerator.new()
	var path := "user://growth96-unit.json"
	func _save_game(_quiet: bool, overrides: Dictionary = {}) -> Error:
		if growth96.save_blocked: return ERR_FILE_CORRUPT
		if fail_write: return ERR_CANT_CREATE
		var data: Dictionary = {"inventory":inventory,"growth96":growth96.state,"gold":1234,"quest_state":{"existing_quest":{"complete":true}},"card_draw_fusion":{"owned":{"old-card":1}}}
		data.merge(overrides,true)
		var error: Error = Writer.write(path,data)
		if error == OK: writes += 1
		return error
	func _invalidate_equipment_static() -> void: pass
	func _update_hud() -> void: pass
	func _item_locked(_name: String) -> bool: return token_locked

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("GROWTH96_FAIL: ",label)

func make_host() -> Host:
	var host := Host.new(); root.add_child(host)
	host.rng.seed = 7654321
	host.growth96 = Runtime.new(); host.growth96.configure(host)
	return host

func _initialize() -> void:
	if OS.get_environment("TWILIGHT_GROWTH96_TEST_ROOT").is_empty() or not ProjectSettings.globalize_path("user://").begins_with(OS.get_environment("TWILIGHT_GROWTH96_TEST_ROOT")):
		push_error("Explicit isolated test profile required"); quit(1); return
	call_deferred("run")

func run() -> void:
	var host := make_host(); var service = host.growth96
	check(service.source.ready, "verified actual private source loads: " + service.source.problem)
	if not service.source.ready: quit(1); return
	var source = service.source
	check(source.audit.points == 71 and source.audit.rewards == 269 and source.audit.items == 17, "complete growth source closure")
	check(source.audit.points96 == 9 and source.audit.rewards96 == 36, "all new96 rows retained")
	check(source.audit.requirements == 63 and source.audit.collections == 8 and source.audit.effects == 16, "complete token registration closure")
	check(host.inventory.size() == 2 and service.state.claims.is_empty(), "loading definitions never grants ownership")
	check(host.catalog_db["아이템"][0].sourceId == "259483", "same-name Inven identity is preserved")
	check(Source.item_key(96084) != "[마법인형 카드 상자](영웅)", "source inventory key does not alias authored box")
	for id: String in source.items:
		var record: Dictionary = source.item_record(int(id))
		check(record.source_original == source.items[id] and not record.storable and not record.tradeable and not record.deletable and record.droppable,"all original item protections survive projection")
		check(int(host.item_weight_index[record.name]) == int(source.items[id].Weight),"all original weights include legitimate zero")
	var seen_rewards: Dictionary = {}
	for cap: String in ["cap0","cap1","cap2"]:
		service.restore(Runtime.fresh()); service.state.policy = cap
		host.inventory = {}; host.level = 100
		for point: String in source.points:
			var selected: Array = service.selected_rewards(point)
			if selected.is_empty(): continue
			var before_rng: String = str(host.rng.state)
			var result: Dictionary = service.execute("claim",point,int(service.state.revision))
			check(result.ok,"source point/version claim " + point + "/" + cap)
			check(str(host.rng.state) == before_rng,"sealed rewards never consume card acquisition RNG")
			for rid: String in selected:
				seen_rewards[rid] = true
				check(service.state.claims.has(rid),"every selected source reward has receipt")
			var before: String = JSON.stringify(service.state)
			check(not service.execute("claim",point,int(service.state.revision)).ok and JSON.stringify(service.state) == before,"duplicate point rejected without mutation")
	check(seen_rewards.size() == 269,"all269 source rows exercised through explicit version policies")
	# Check every exact source threshold independently of reward selection.
	for point: Dictionary in source.points.values():
		service.restore(Runtime.fresh()); host.level = int(point.Level); host.exp_need = 1000
		host.experience = int(point.Percent)*10
		check(service.reached(point),"inclusive exact source threshold")
		if host.experience > 0:
			host.experience -= 1
			check(not service.reached(point),"one EXP below source threshold")
		host.level = int(point.Level)-1; host.experience = 999
		check(not service.reached(point),"lower level never borrows another level's percent")
	# Genuine96 acquisition flow supplies27 tokens, not the63 needed for all choices.
	service.restore(Runtime.fresh()); host.level = 96; host.experience = 900; host.inventory = {"existing-material":19,"[마법인형 카드 상자](영웅)":11}
	check(host._save_game(true) == OK,"atomic baseline save")
	var before_hash: String = FileAccess.get_sha256(host.path)
	var before_state: String = JSON.stringify(service.state)
	var before_inventory: String = JSON.stringify(host.inventory)
	var offer: Dictionary = service.quote("claim","828")
	check(offer.ok and host.writes > 0 and JSON.stringify(service.state) == before_state and JSON.stringify(host.inventory) == before_inventory,"review/cancel is read-only")
	host.fail_write = true
	check(not service.execute("claim","828",int(service.state.revision)).ok,"failed claim write rejected")
	check(FileAccess.get_sha256(host.path) == before_hash and JSON.stringify(host.inventory) == before_inventory and JSON.stringify(service.state) == before_state,"failed claim keeps disk inventory and receipts")
	host.fail_write = false
	for point: Dictionary in source.points.values():
		if int(point.Level) == 96: check(service.execute("claim",Source.sid(point.ID),int(service.state.revision)).ok,"actual96 claim")
	for item: int in [96094,96084,254268,371128]: check(int(host.inventory.get(Source.item_key(item),0)) == 27,"exact96 quantity for each original item")
	check(int(host.inventory["[마법인형 카드 상자](영웅)"]) == 11 and int(host.inventory["existing-material"]) == 19,"unrelated inventory untouched")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(host.path))
	check(saved.quest_state.existing_quest.complete and saved.card_draw_fusion.owned["old-card"] == 1 and int(saved.gold) == 1234,"quests card ownership and gold preserved")
	var original_receipts: String = JSON.stringify(service.state.claims)
	check(service.execute("policy","cap2",int(service.state.revision)).ok,"policy change saves without resetting history")
	check(JSON.stringify(service.state.claims) == original_receipts and not service.quote("claim","828").ok,"cap2 retains claimed Version0 and prevents regrant")
	var first_card: String = str(source.collections["38828"].cards[0])
	host.level = 95
	check(not service.quote("register",first_card).ok,"collection minimum level enforced")
	host.level = 96
	before_state = JSON.stringify(service.state); before_inventory = JSON.stringify(host.inventory); before_hash = FileAccess.get_sha256(host.path)
	host.fail_write = true
	check(not service.execute("register",first_card,int(service.state.revision)).ok,"failed registration write rejected")
	check(JSON.stringify(service.state) == before_state and JSON.stringify(host.inventory) == before_inventory and FileAccess.get_sha256(host.path) == before_hash,"failed registration preserves debit receipt and durable save")
	host.fail_write = false
	for card: String in source.collections["38828"].cards: check(service.execute("register",card,int(service.state.revision)).ok,"register real earned token")
	check(int(host.inventory[Source.item_key(Source.TOKEN)]) == 24,"three distinct requirements consume exactly three real tokens")
	check(not service.quote("register",first_card).ok,"duplicate registration rejected")
	var snap: Dictionary = service.snapshot()
	check(snap.collections[0].complete and service.bonus("local_reduction_efficiency:percent") == 0,"raw percent formula is not invented by default")
	check(service.execute("effects_policy","twilight_estimates",int(service.state.revision)).ok and service.bonus("local_reduction_efficiency:percent") == 5,"explicit estimated effect policy enables existing offline model")
	# A separate, explicitly synthetic inventory fixture tests all63 paths. It is
	# never a production grant or evidence that a single character earned63 tokens.
	service.restore(Runtime.fresh()); host.inventory = {Source.item_key(Source.TOKEN):63}; service.state.effects_policy = "twilight_estimates"
	host.token_locked = true
	check(not service.quote("register",first_card).ok and host.inventory[Source.item_key(Source.TOKEN)] == 63,"player lock prevents consuming real tokens")
	host.token_locked = false
	for card: String in source.cards: check(service.execute("register",card,int(service.state.revision)).ok,"all source requirement transactions")
	check(not host.inventory.has(Source.item_key(Source.TOKEN)) and service.state.registrations.size() == 63,"full fixture consumes63 and creates63 receipts")
	for row: Dictionary in service.snapshot().collections: check(row.complete,"all source collection choices supported")
	for kind: String in ["melee","ranged","magic"]:
		check(service.bonus(kind+"_hit:flat") == 5,"actual accuracy effect")
		check(service.bonus("pve_"+kind+"_damage:flat") == 5,"existing offline PvP-to-PvE flat policy")
		check(service.bonus(kind+"_critical_damage:flat") == 7,"actual critical damage effect")
		check(service.bonus("local_"+kind+"_ignore:percent") == 5,"channel-specific optional percent model")
	check(service.bonus("local_ignore:percent") == 10 and service.status_accuracy(40) == 42,"both distinct PvP percent effects and opt-in4-status multiplier")
	check(not service.quote("register",first_card).ok,"full registration never reconsumes")
	saved = JSON.parse_string(FileAccess.get_file_as_string(host.path))
	service.restore(saved.growth96)
	check(service.state.registrations.size() == 63 and service.bonus("magic_hit:flat") == 5,"reload derives bonuses from permanent registrations exactly once")
	service.state["future_metadata"] = {"keep":true}; service.state.claims["999999999"] = true
	var preserved: Dictionary = service.state.duplicate(true)
	service.restore(preserved)
	check(service.state.future_metadata.keep and service.state.claims["999999999"],"unknown historical receipts and metadata remain")
	for field: String in ["claims","point_versions","registrations"]:
		var bad: Dictionary = Runtime.fresh(); bad[field] = []
		check(not service.validate(bad).is_empty(),"corrupt ledger structure rejected")
	var bad: Dictionary = Runtime.fresh(); bad.registrations[first_card] = false
	check(not service.check_load({"growth96":bad}).is_empty() and service.save_blocked,"corrupt registration protects save")
	check(host._save_game(true) != OK,"protected save cannot be overwritten")
	check(not service.install_source(OS.get_environment("TWILIGHT_PATCH523_CONTENT")).ok and service.save_blocked,"definition reinstall never reports corrupt save repaired")
	var mismatch: Dictionary = Runtime.fresh()
	var rid: String = source.by_point["828"][0]
	var raw: Dictionary = source.rewards[rid]
	mismatch.claims[rid] = {"point_id":"828","version":int(raw.version),"item_id":int(raw.RewardClassID),"amount":int(raw.Amount)}
	mismatch.point_versions["828"] = 2
	check(not service.validate(mismatch).is_empty(),"conflicting version lock is rejected without resetting receipts")
	service.restore(Runtime.fresh()); host.inventory = {}
	check(not service.quote("register",first_card).ok,"insufficient real token rejected")
	var revision: int = int(service.state.revision)
	check(service.execute("policy","hold",revision).ok,"hold policy stores atomically")
	check(not service.execute("policy","latest_available",revision).ok,"stale revision rejected")
	check(not service.quote("claim","828").ok,"hold policy prevents claims without deleting receipts")
	print("GROWTH96_RUNTIME_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source":source.audit,"all_reward_rows_exercised":seen_rewards.size(),"all_requirement_paths":63,"full_registration_inventory_is_explicit_fixture":true}))
	host.free()
	quit(0 if failures.is_empty() else 1)
