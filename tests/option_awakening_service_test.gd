extends SceneTree
## Real catalog bindings + transaction failures. These fixtures never grant
## cards to the normal game save; the test runner must use an isolated user dir.
const Core = preload("res://scripts/cards/option_awakening_service.gd")
const Runtime = preload("res://scripts/cards/option_awakening_runtime.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
var failures: Array[String] = []
var checks: int = 0
var catalog: Dictionary
var core = Core.new()

class Host extends Node:
	var catalog_db: Dictionary = {}
	var card_draw_fusion = preload("res://scripts/card_draw_fusion.gd").new()
	var equipped_catalog: Dictionary = {"변신": {}, "마법인형": {}, "성물": {}}
	var gold: int = 100000000
	var save_error: Error = OK
	var calls: int = 0
	func save_path() -> String: return "user://option_awakening_transaction_test.json"
	func _save_game(_quiet: bool, override: Dictionary = {}) -> Error:
		calls += 1
		if save_error != OK: return save_error
		return preload("res://scripts/skills/save_writer.gd").write(save_path(), override)

func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("OPTION_AWAKENING_FAIL: " + label)

func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _id(category: String, grade: String, awakenable: bool = false) -> String:
	var rows: Dictionary = core.definitions[category] if awakenable else core.catalog[category]
	for identity: String in rows:
		if str(rows[identity].grade) == grade: return identity
	return ""

func _own(cards: Dictionary, category: String, identity: String, count: int = 0) -> void:
	cards.owned[category][identity] = true
	if count > 0: cards.spare[category][identity] = count

func _empty_cards() -> Dictionary:
	var cards = Cards.new()
	cards.configure(catalog)
	return cards.export_state()

func _full_state(category: String, identity: String) -> Dictionary:
	var state: Dictionary = Core.fresh_state()
	var entry: Dictionary = Core.fresh_card()
	entry.experience = 100
	state.cards[category][identity] = entry
	return state

func _run() -> void:
	catalog = _json("res://data/catalog_v19.json")
	var data: Dictionary = _json(Runtime.DATA_PATH)
	var policy: Dictionary = _json(Runtime.POLICY_PATH)
	check(core.configure(data, policy, catalog), "official definitions bind actual catalog")
	if not core.problem.is_empty(): _finish(); return
	check(core.definitions["변신"].size() == 180 and core.definitions["마법인형"].size() == 83 and core.definitions["성물"].size() == 58, "321 exact runtime bindings")
	check(data.provenance.original_card_rows == 303 and data.unavailable_source_cards.size() == 6, "source rows and unavailable cards distinguished")
	check(core.definition("변신", "source:260").source_name == "각성:켄라우헬", "named awakening card alias stays distinct from base Ken Rauhel")
	check(core.definition("변신", "source:209").source_name == "각성:알폰스", "named awakening Alphonse explicit alias")
	check(core.definition("변신", "source:130").source_name == "신화변신", "generic class mythic row maps explicit class ID")
	var pending: int = 0
	for category: String in Core.CATEGORIES:
		for identity: String in core.definitions[category]:
			var row: Dictionary = core.definitions[category][identity]
			pending += row.pending_options.size()
			for text: String in row.pending_options: check(not row.applied_options.has(text), "pending unique proc excluded from applied options")
	check(pending == 5, "five unique special effects remain explicitly pending")
	check(policy.provenance.kind == "twilight_local_balance" and not bool(policy.pity_enabled), "unverified progression is local policy with no invented pity")
	var hero: String = _id("변신", "영웅", true)
	var rare: String = _id("변신", "희귀")
	var wrong: String = _id("변신", "고급")
	var cards: Dictionary = _empty_cards()
	_own(cards, "변신", hero)
	_own(cards, "변신", rare, 8)
	_own(cards, "변신", wrong, 8)
	var state: Dictionary = Core.fresh_state()
	state["future_metadata"] = {"preserve": [1, 2, 3]}
	state.cards["변신"]["future:unknown"] = {"experience": 10, "awakened": false, "attempts": 0, "failures": 0, "future_entry": "keep"}
	var before_cards: Dictionary = cards.duplicate(true)
	var before_state: Dictionary = state.duplicate(true)
	for material in [{}, {rare: 0}, {rare: -1}, {rare: 1.5}, {rare: true}, {rare: 9}, {wrong: 1}, {"source:missing": 1}]:
		check(not bool(core.prepare_feed(state, cards, 100000, "변신", hero, material).ok), "invalid material request rejected: " + str(material))
	check(cards == before_cards and state == before_state, "all rejected requests preserve caller state")
	var unowned: Dictionary = cards.duplicate(true)
	unowned.owned["변신"].erase(hero)
	check(not bool(core.prepare_feed(state, unowned, 100000, "변신", hero, {rare: 1}).ok), "free catalog equip does not imply acquired awakening target")
	var fed: Dictionary = core.prepare_feed(state, cards, 100000, "변신", hero, {rare: 5})
	check(bool(fed.ok) and fed.gained_experience == 100 and fed.discarded_experience == 25, "experience caps and reports overflow")
	check(fed.card_state.spare["변신"][rare] == 3 and bool(fed.card_state.owned["변신"][rare]), "only duplicate copies consumed; permanent unlock preserved")
	check(fed.gold == 100000 and fed.state.cards["변신"][hero].experience == 100, "feed is a distinct free transaction")
	check(fed.state.future_metadata == state.future_metadata and fed.state.cards["변신"]["future:unknown"].future_entry == "keep", "same-version future fields and unmapped progress preserved")
	check(cards == before_cards and state == before_state, "successful prepare is pure")
	check(not bool(core.prepare_feed(fed.state, fed.card_state, fed.gold, "변신", hero, {rare: 1}).ok), "full XP cannot consume additional duplicates")
	check(not bool(core.prepare_awaken(state, cards, 100000, "변신", hero, 0).ok), "partial XP cannot attempt")
	check(not bool(core.prepare_awaken(fed.state, fed.card_state, 99999, "변신", hero, 0).ok), "insufficient gold cannot attempt")
	var lost: Dictionary = core.prepare_awaken(fed.state, fed.card_state, 100000, "변신", hero, 9999)
	check(bool(lost.ok) and not bool(lost.success) and lost.gold == 0 and lost.refunded_experience == 20, "failure consumes attempt fee and returns configured XP")
	check(lost.card_state == fed.card_state and bool(lost.card_state.owned["변신"][hero]), "attempt never consumes target or returns previously fed cards")
	check(not bool(core.prepare_awaken(lost.state, lost.card_state, 100000, "변신", hero, 0).ok), "repeated failed attempt requires feeding again")
	for category: String in Core.CATEGORIES:
		for grade: String in Core.GRADES:
			var identity: String = _id(category, grade, true)
			var ready: Dictionary = _full_state(category, identity)
			var stock: Dictionary = _empty_cards()
			_own(stock, category, identity)
			var threshold: int = {"영웅": 1650, "전설": 1244, "신화": 5500, "유일": 10000}[grade]
			check(bool(core.prepare_awaken(ready, stock, 100000000, category, identity, threshold - 1).success), "published probability last winning roll " + category + grade)
			if threshold < 10000: check(not bool(core.prepare_awaken(ready, stock, 100000000, category, identity, threshold).success), "published probability first losing roll " + category + grade)
			var won: Dictionary = core.prepare_awaken(ready, stock, 100000000, category, identity, 0)
			check(bool(won.state.cards[category][identity].awakened) and won.state.cards[category][identity].experience == 0, "success is permanent and clears XP " + category + grade)
			check(not bool(core.prepare_awaken(won.state, won.card_state, won.gold, category, identity, 0).ok), "completed card cannot be charged twice " + category + grade)
			check(not bool(core.prepare_awaken(ready, stock, 100000000, category, identity, 10000).ok), "invalid random roll fails closed " + category + grade)
	var bad: Dictionary = Core.fresh_state()
	bad.version = 2
	check(not core.validate_state(bad).is_empty(), "future save version blocked")
	bad = _full_state("변신", hero)
	bad.cards["변신"][hero].experience = 100.5
	check(not core.validate_state(bad).is_empty(), "fractional saved XP rejected")
	bad = _full_state("변신", hero)
	bad.rng_state = "9223372036854775808"
	check(not core.validate_state(bad).is_empty(), "overflowed RNG state rejected instead of truncation")
	_runtime_transactions(hero, rare)
	_collections()
	_finish()

func _runtime_transactions(hero: String, rare: String) -> void:
	var host := Host.new()
	root.add_child(host)
	host.catalog_db = catalog
	host.card_draw_fusion.configure(catalog)
	var rt = Runtime.new()
	check(rt.configure(host), "runtime configures from packaged data")
	var stock: Dictionary = _empty_cards()
	_own(stock, "변신", hero)
	_own(stock, "변신", rare, 8)
	host.card_draw_fusion.import_state(stock)
	rt.rng.seed = 99231
	var state_before: Dictionary = rt.export_state()
	var cards_before: Dictionary = host.card_draw_fusion.export_state()
	var gold_before: int = host.gold
	host.save_error = ERR_CANT_CREATE
	check(not bool(rt.feed("변신", hero, {rare: 4}).ok), "injected feed save failure rejected")
	check(rt.export_state() == state_before and host.card_draw_fusion.export_state() == cards_before and host.gold == gold_before, "failed feed preserves live cards, XP, money and RNG")
	host.save_error = OK
	check(bool(rt.feed("변신", hero, {rare: 4}).ok), "feed commits a full durable save")
	var durable_before: String = FileAccess.get_file_as_string(host.save_path())
	state_before = rt.export_state()
	cards_before = host.card_draw_fusion.export_state()
	gold_before = host.gold
	var predicted := RandomNumberGenerator.new()
	predicted.state = rt.rng.state
	var will_win: bool = predicted.randi_range(0, 9999) < 1650
	host.save_error = ERR_CANT_CREATE
	check(not bool(rt.awaken("변신", hero).ok), "injected attempt save failure rejected")
	check(rt.export_state() == state_before and host.card_draw_fusion.export_state() == cards_before and host.gold == gold_before, "failed attempt preserves live state and RNG")
	check(FileAccess.get_file_as_string(host.save_path()) == durable_before, "failed attempt preserves existing save byte-for-byte")
	host.save_error = OK
	var result: Dictionary = rt.awaken("변신", hero)
	check(bool(result.ok) and bool(result.success) == will_win, "retry uses unconsumed RNG outcome")
	var saved: Dictionary = _json(host.save_path())
	check(saved.card_option_awakening == JSON.parse_string(JSON.stringify(rt.export_state())) and saved.gold == host.gold and saved.card_draw_fusion == JSON.parse_string(JSON.stringify(host.card_draw_fusion.export_state())), "gold, cards, progress and RNG committed together")
	var restored = Runtime.new()
	check(restored.configure(host) and restored.accept_load(saved), "saved progression reloads")
	check(restored.export_state() == rt.export_state() and restored.rng.state == rt.rng.state, "RNG and progression exact reload round-trip")
	var ready_before: Dictionary = restored.export_state()
	check(restored.prepare_load(saved) and restored.export_state() == ready_before, "prepare_load performs no live progression or RNG mutation")
	check(restored.accept_load(saved), "prepared load accepts without further migration work")
	var future: Dictionary = saved.duplicate(true)
	future.card_option_awakening.version = 99
	check(not restored.accept_load(future) and restored.save_blocked, "unsupported save version activates save protection")
	var calls: int = host.calls
	check(not bool(restored.feed("변신", hero, {rare: 1}).ok) and host.calls == calls, "blocked save never reaches persistence")
	var legacy: Dictionary = {"gold": 321, "card_draw_fusion": stock}
	check(Writer.write(host.save_path(), legacy) == OK, "legacy save fixture writes")
	var migration = Runtime.new()
	migration.configure(host)
	check(migration.accept_load(legacy) and FileAccess.file_exists(host.save_path() + ".pre-option-awakening"), "legacy save has retained backup before first awakening write")
	check(migration.progress.cards["변신"].is_empty(), "old owned cards are not automatically awakened")
	var old_backup: String = FileAccess.get_file_as_string(host.save_path() + ".pre-option-awakening")
	legacy.gold = 543
	Writer.write(host.save_path(), legacy)
	var backup_hash: String = FileAccess.get_sha256(host.save_path())
	check(migration.prepare_load(legacy), "different legacy save receives separate backup")
	check(FileAccess.get_file_as_string(host.save_path() + ".pre-option-awakening") == old_backup, "existing migration backup never overwritten")
	check(FileAccess.get_sha256(host.save_path() + ".pre-option-awakening." + backup_hash.substr(0, 16)) == backup_hash, "new legacy backup SHA exactly matches original save")
	host.free()

func _collections() -> void:
	var stock: Dictionary = _empty_cards()
	var state: Dictionary = Core.fresh_state()
	check(core.collections.size() == 4, "four verified doll collections packaged")
	for row: Dictionary in core.collections:
		check(bool(row.available), "collection uses exact existing IDs: " + str(row.name))
		for requirement: Dictionary in row.requirements:
			_own(stock, str(requirement.category), str(requirement.id))
			if bool(requirement.awakened):
				state.cards[requirement.category][requirement.id] = {"experience": 0, "awakened": true, "attempts": 1, "failures": 0}
	for row: Dictionary in core.collection_views(state, stock): check(bool(row.completed), "all verified requirements complete " + str(row.name))
	var absent: Dictionary = stock.duplicate(true)
	absent.owned["마법인형"].erase("source:8")
	check(not bool(core.collection_views(state, absent)[0].completed), "ordinary owned companion card is also required")
	var host := Host.new()
	root.add_child(host)
	host.catalog_db = catalog
	host.card_draw_fusion.configure(catalog)
	host.card_draw_fusion.import_state(stock)
	var rt = Runtime.new()
	rt.configure(host)
	rt.progress = state
	check(rt.catalog_bonus("potionHealFlat") == 3 and rt.catalog_bonus("intFlat") == 1 and rt.catalog_bonus("sp") == 1, "collection bonuses apply once with no card equipped")
	var defense: float = 0.0
	for record: Dictionary in rt.bonus_records(): defense += float(record.get("def", 0))
	check(defense == 1.0, "collection AC contributes only one defense point")
	var seer: Dictionary = core.catalog["마법인형"]["source:5"].duplicate(true)
	host.equipped_catalog["마법인형"] = seer
	var own_stats: Dictionary = core.definition("마법인형", "source:5").stats
	check(rt.catalog_bonus("intFlat") == 1 + int(own_stats.get("intFlat", 0)), "equipped card bonus stacks once with permanent collection")
	check(rt.catalog_bonus("potionHealFlat") == 3, "equipping collection member cannot duplicate collection reward")
	host.equipped_catalog["마법인형"] = {}
	check(rt.catalog_bonus("intFlat") == 1 and rt.catalog_bonus("potionHealFlat") == 3, "unequipping removes card bonus and retains collection reward")
	check(seer == core.catalog["마법인형"]["source:5"], "bonus computation leaves original card record untouched")
	var intact: Dictionary = rt.export_state()
	check(not rt.prepare_load({Runtime.SAVE_KEY: {"version": 99}}), "bad load rejected before existing live state changes")
	check(rt.export_state() == intact and rt.catalog_bonus("intFlat") == 1 and rt.catalog_bonus("potionHealFlat") == 3 and rt.is_awakened("마법인형", "source:5"), "failed load retains existing bonus and awakened decoration")
	host.free()

func _finish() -> void:
	print("OPTION_AWAKENING_SERVICE_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	if failures.is_empty(): print("OPTION_AWAKENING_SERVICE_OK")
	quit(0 if failures.is_empty() else 1)
