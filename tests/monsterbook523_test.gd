extends SceneTree
const Book = preload("res://scripts/monsterbook/monsterbook523.gd")
var checks: int = 0
var failed: int = 0
var committed: Dictionary = {}
var last_quote: Dictionary = {}
var service = Book.new()
class CardHost extends Node:
	var level: int = 99
	var catalog_db: Dictionary = {}
	var card_draw_fusion = preload("res://scripts/card_draw_fusion.gd").new()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(message + " / " + service.last_error)

func sink(_before: Dictionary, proposed: Dictionary, quote: Dictionary) -> bool:
	committed = proposed.duplicate(true)
	last_quote = quote.duplicate(true)
	return true

func deny(_before: Dictionary, _proposed: Dictionary, _quote: Dictionary) -> bool:
	return false

func receipt(action: String, seq: int, book_id: int = 6013, epoch: String = "confirmed-day-A") -> Dictionary:
	return {"action": action, "book_id": book_id, "sequence": seq, "epoch": epoch, "authority": "TEST_CONFIRMED_ADAPTER", "approved": true, "server_allowed": true, "clock_locale": "Korean", "source_clock": "202610200500"}

func _initialize() -> void:
	var path: String = OS.get_environment("MONSTERBOOK523_PACK")
	var sha: String = OS.get_environment("MONSTERBOOK523_SHA256")
	if path.is_empty():
		push_error("MONSTERBOOK523_PACK and digest required; no source fixture masquerades as original")
		quit(2)
		return
	check(service.load_pack(path, sha), "actual private source pack loads")
	check(service.books(false).size() == 557 and service.books().size() == 33, "557 definitions / 33 currently linked, not 524 active")
	check(service.levels(6013).size() == 1, "daily exactly one stage")
	var daily: Dictionary = service.levels(6013)[0]
	check(int(daily.ID) == 16423 and int(daily.Amount) == 1000 and int(daily.CurrencyCost) == 0, "daily threshold/cost")
	check(daily.bonuses.is_empty() and daily.rewards.size() == 2, "daily reward without permanent bonus")
	check(int(daily.rewards[0].RewardTypeID) == 1 and int(daily.rewards[0].RewardClassID) == 281, "EXP Class281 stays EXP reference")
	check(int(daily.rewards[1].RewardClassID) == 3631 and int(daily.rewards[1].Amount) == 1500, "honor coin source amount")
	check(int(service.target_books(104938)[0].ID) == 5903, "new nightmare hotspot member")
	check(int(service.target_books(105593)[0].ID) == 5863, "new albino mushroom member")
	check(service.target_books(64842).is_empty(), "same name/sprite nonmember excluded")
	check(int(service.target_books(6681)[0].ID) == 6013, "exact daily NPC member")
	var population: int = 0
	var stages: int = 0
	for b: Dictionary in service.books():
		stages += service.levels(int(b.ID)).size()
	for n: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(path)).tables.NpcClassForNpcGroup:
		population += 1
		check(service.target_books(int(n.NpcClassID)).size() == 1, "unique exact current membership")
	check(population == 944 and stages == 97, "all current members/stages")
	var begin := receipt("begin_epoch", 1)
	begin.reset_approved = true
	check(service.apply_confirmed(begin, sink), "explicit initial epoch")
	var before := service.export_state()
	check(not service.apply_confirmed(begin, sink) and service.export_state() == before, "replayed receipt rejected without mutation")
	var count := receipt("count", 2)
	count.npc_class_id = 6681
	count.level_ids = [16423]
	check(not service.apply_confirmed(count, deny) and service.export_state() == before, "failed durable transaction preserves state")
	count.approved = false
	check(not service.apply_confirmed(count, sink), "unapproved credit blocked")
	count.approved = true
	count.npc_class_id = 64842
	check(not service.apply_confirmed(count, sink), "same display identity not a kill credit")
	count.npc_class_id = 6681
	count.source_clock = "202610280500"
	check(not service.apply_confirmed(count, sink), "counting end exclusive, not option end")
	count.source_clock = "202610202599"
	check(not service.apply_confirmed(count, sink), "invalid civil source clock rejected")
	count.source_clock = "202610200500"
	count.level_ids = [16423, 16423]
	check(not service.apply_confirmed(count, sink), "duplicate stage does not double count")
	count.level_ids = [16423]
	check(service.apply_confirmed(count, sink), "confirmed exact credit increments")
	check(int(service.progress(6013).counts['16423']) == 1, "stage count persisted")
	var registration := receipt("register", 3)
	registration.level_id = 16423
	registration.registration_approved = true
	check(not service.apply_confirmed(registration, sink), "under threshold register blocked")
	var seeded := service.export_state()
	seeded.books['6013'].epochs['confirmed-day-A'].counts['16423'] = 999
	seeded['future_extension'] = {"owned": ["unchanged"]}
	check(service.import_state(seeded), "confirmed historical count restored")
	count.sequence = 3
	check(service.apply_confirmed(count, sink), "1000th confirmed count")
	registration.sequence = 4
	check(not service.apply_confirmed(registration, deny), "registration save failure rolls back")
	check(service.apply_confirmed(registration, sink), "registration separately recorded")
	var claim := receipt("claim", 5)
	claim.level_id = 16423
	claim.claim_window_approved = true
	check(not service.apply_confirmed(claim, deny), "payout transaction failure leaves unclaimed")
	check(service.apply_confirmed(claim, sink), "typed reward quote settled together with claim")
	check(last_quote.rewards == daily.rewards and service.progress(6013).claimed == [16423], "whole original reward bundle retained")
	check(service.import_state(JSON.parse_string(JSON.stringify(service.export_state()))), "real JSON round trip restores state")
	check(service.progress(6013).claimed.has(16423), "claimed integer identity survives JSON floats")
	claim.sequence = 6
	check(not service.apply_confirmed(claim, sink), "duplicate payout cannot settle again")
	var next := receipt("begin_epoch", 6, 6013, "confirmed-day-B")
	check(not service.apply_confirmed(next, sink), "ResetType numeric alone does not reset")
	next.reset_approved = true
	check(service.apply_confirmed(next, sink), "confirmed reset archives previous epoch")
	check(service.export_state().books['6013'].epochs['confirmed-day-A'].claimed == [16423], "previous claim preserved across reset")
	check(service.progress(6013).counts.is_empty(), "new epoch starts separately")
	var unknown := service.export_state()
	unknown.books['999999'] = {"sequence": 7, "current_epoch": "historical", "epochs": {"historical": {"counts": {"777": 44}, "registered": [777], "claimed": [777], "effective_levels": [777], "owned_extension": true}}}
	check(service.import_state(unknown) and service.export_state() == unknown, "unknown ownership/registration/extensions preserved")
	var malformed := unknown.duplicate(true)
	malformed.books['6013'].epochs['confirmed-day-A'].counts['16423'] = -1
	check(not service.import_state(malformed) and service.export_state() == unknown, "malformed save rejected atomically")
	var no_pack = Book.new()
	check(no_pack.import_state(unknown) and no_pack.export_state() == unknown, "state survives optional source pack absence")
	check(not service.load_pack(path, '0'.repeat(64)) and service.export_state() == unknown and service.books().size() == 33, "bad pack replacement retains live registry and save")
	var regular: Dictionary = service.books()[0]
	var book_id := int(regular.ID)
	var regular_levels := service.levels(book_id)
	var level_ids: Array = []
	var counts: Dictionary = {}
	for level: Dictionary in regular_levels:
		level_ids.append(int(level.ID))
		counts[str(int(level.ID))] = int(level.Amount)
	var snapshot := service.export_state()
	snapshot.books[str(book_id)] = {"sequence": 1, "current_epoch": "season", "epochs": {"season": {"counts": counts, "registered": level_ids, "claimed": [], "effective_levels": []}}}
	check(service.import_state(snapshot), "restored multiple registered stages")
	var effect := receipt("effects", 2, book_id, "season")
	effect.effective_levels = [level_ids.back()]
	check(service.apply_confirmed(effect, sink), "authority chooses applicable stage; no guessed stacking")
	var final_bonuses: Array = regular_levels.back().bonuses
	check(service.effective_bonuses(book_id, '202610290500') == final_bonuses, "bonuses can outlive counting end")
	check(service.effective_bonuses(book_id, '202611040500').is_empty(), "option expiry separate and exclusive")
	check(service.progress(book_id).registered == level_ids, "expiry preserves registrations")
	var prior := service.export_state()
	var bad_group := receipt("begin_epoch", 1, 13, "historic")
	bad_group.reset_approved = true
	check(not service.apply_confirmed(bad_group, sink) and service.export_state() == prior, "zero-group historical book not repopulated")
	# Default UI must not claim an unsupported selected stage changes combat.
	var runtime = preload("res://scripts/monsterbook/monsterbook523_runtime.gd").new()
	runtime.catalog = service
	runtime.local.configure(runtime,null)
	runtime.local.unix_clock = func() -> int: return int(Time.get_unix_time_from_datetime_string("2026-10-20T00:00:00"))
	var local_state := service.export_state()
	var target_levels := service.levels(5903)
	var target_id: int = int(target_levels[1].ID)
	var target_epoch: String = runtime.local.epoch(5903)
	local_state.books['5903'] = {"sequence":1,"current_epoch":target_epoch,"epochs":{target_epoch:{"counts":{},"registered":[target_id],"claimed":[],"effective_levels":[]}}}
	check(service.import_state(local_state),"registered unsupported stage fixture preserves exact source")
	check(runtime.local.status("effects",5903,target_id).is_empty(),"source typed reduction now has a real compatibility consumer")
	var broken_wallet := service.export_state()
	broken_wallet.local_economy = {"schema":1,"gems":10,"acquired":9,"spent":0,"provenance":"twilight_custom_internal_gems_v1"}
	check(not service.import_state(broken_wallet) and service.export_state() == local_state,"inconsistent internal currency ledger rejected atomically")
	var broken_conversion := service.export_state()
	broken_conversion.books['5903'].epochs[target_epoch].reward_conversions = {"1":{"source_amount":1,"local_exp":-1,"numerator":1,"denominator":1,"provenance":"test"}}
	check(not service.import_state(broken_conversion) and service.export_state() == local_state,"malformed EXP settlement record rejected before replacing save")
	var completed_stages: int = 0
	for book: Dictionary in service.books():
		var ordered := service.levels(int(book.ID))
		ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.Level) < int(b.Level))
		var registered: Array = []
		var counts_by_stage: Dictionary = {}
		var total: int = 0
		var npc_id: int = 0
		for member: Dictionary in service.table_rows("NpcClassForNpcGroup"):
			if int(member.NpcGroupID) == int(book.NpcGroupID): npc_id = int(member.NpcClassID); break
		for stage_row: Dictionary in ordered:
			var current := service.export_state()
			counts_by_stage[str(int(stage_row.ID))] = int(stage_row.Amount)-1
			total += int(stage_row.Amount)-1
			current.books[str(int(book.ID))] = {"sequence":1,"current_epoch":"explicit-policy-test","epochs":{"explicit-policy-test":{"counts":counts_by_stage.duplicate(),"kill_count":total,"registered":registered.duplicate(),"claimed":[],"effective_levels":registered.duplicate(),"counter_policy":"per_stage","bonus_policy":"cumulative"}}}
			check(service.import_state(current),"restored original near-threshold policy fixture")
			var actual := receipt("count",2,int(book.ID),"explicit-policy-test")
			actual.npc_class_id = npc_id
			actual.level_ids = [int(stage_row.ID)]
			actual.progression_policy = "per_stage"
			actual.bonus_policy = "cumulative"
			check(service.apply_confirmed(actual,sink),"every current natural stage has a runnable compatibility transition")
			registered.append(int(stage_row.ID)); total += 1
			counts_by_stage[str(int(stage_row.ID))] = int(stage_row.Amount)
			check(service.progress(int(book.ID)).registered == registered and service.progress(int(book.ID)).effective_levels == registered,"natural stage thresholds and cumulative effects remain separate from paid shortcuts")
			completed_stages += 1
	check(completed_stages == 97,"all 97 current stages covered without Gem debit")
	var policy_state: Dictionary = service.export_state()
	for field: String in ["counter_policy","bonus_policy"]:
		var invalid: Dictionary = policy_state.duplicate(true)
		invalid.books['5903'].epochs['explicit-policy-test'][field] = "unknown-policy"
		check(not service.import_state(invalid) and service.export_state() == policy_state,"unknown persisted progression policy cannot replace current state")
	var invalid_clock: Dictionary = policy_state.duplicate(true)
	invalid_clock.item_actions = {"schema":1,"sequence":1,"last_results":[],"last_clock":"202602300500"}
	check(not service.import_state(invalid_clock) and service.export_state() == policy_state,"invalid item transaction clock cannot replace current state")
	var card_host := CardHost.new()
	card_host.catalog_db = JSON.parse_string(FileAccess.get_file_as_string("res://data/lineagem_base508/cards.json")).catalog
	card_host.card_draw_fusion.configure(card_host.catalog_db)
	runtime.items.configure(runtime,card_host)
	runtime.item_use.configure(runtime,card_host)
	var item_ids: Dictionary = {}
	for book: Dictionary in service.books():
		for stage_row: Dictionary in service.levels(int(book.ID)):
			for reward: Dictionary in stage_row.rewards:
				if int(reward.RewardTypeID) != 2: continue
				var record: Dictionary = runtime.items.definition(reward)
				if not record.has("source_delete_clock") or item_ids.has(int(record.source_item_class_id)): continue
				item_ids[int(record.source_item_class_id)] = true
				check(not runtime.item_use.spec(record).has("error"),"all 18 dated item actions join actual existing card model and original rule tables")
				if runtime.item_use.spec(record).get("kind") == "mystery":
					runtime.economy.settings.mystery_pool_policy = "invalid-pool"
					check(runtime.item_use.spec(record).has("error"),"changed mystery policy invalidates an already cached successful specification")
					runtime.economy.settings.mystery_pool_policy = "current_unrestricted_pack_cards"
	check(item_ids.size() == 18,"every current dated item action has a specification")
	card_host.free()
	print("MONSTERBOOK523_TEST checks=%d failed=%d" % [checks, failed])
	quit(1 if failed else 0)
