extends RefCounted
## Whole-save transaction adapter for the offline game. Consumables and RNG
## become live only after World's existing atomic save writer returns OK.
const Core = preload("res://scripts/cards/option_awakening_service.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const DATA_PATH: String = "res://data/cards/option_awakening_cards.json"
const POLICY_PATH: String = "res://data/cards/option_awakening_policy.json"
const SAVE_KEY: String = "card_option_awakening"
var world
var core = Core.new()
var progress: Dictionary = Core.fresh_state()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var problem: String = ""
var load_error: String = ""
var save_blocked: bool = false
var _busy: bool = false
var _bonus_signature: String = ""
var _bonus_records: Array[Dictionary] = []
var _totals: Dictionary = {}
var _prepared_load_fingerprint: String = ""
var _prepared_state: Dictionary = {}

func _init() -> void:
	rng.randomize()

func configure(host: Node) -> bool:
	world = host
	var data: Dictionary = _json(DATA_PATH)
	var settings: Dictionary = _json(POLICY_PATH)
	if data.is_empty() or settings.is_empty() or not core.configure(data, settings, world.catalog_db):
		problem = core.problem if not core.problem.is_empty() else "옵션 각성 데이터 파일 누락 또는 손상"
		save_blocked = true
		return false
	problem = ""
	save_blocked = false
	_bonus_signature = ""
	return true

func _json(path: String) -> Dictionary:
	var parser := JSON.new()
	if not FileAccess.file_exists(path) or parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return {}
	return parser.data

func export_state() -> Dictionary:
	var out: Dictionary = progress.duplicate(true)
	# Godot RNG states are 64-bit; decimal strings avoid JSON double truncation.
	out["rng_state"] = str(rng.state)
	return out

func check_load(data: Dictionary) -> String:
	if not problem.is_empty(): return problem
	if not data.has(SAVE_KEY): return "" # An existing save starts unawakened.
	return core.validate_state(data[SAVE_KEY], data.get("card_draw_fusion", {}))

func prepare_load(data: Dictionary) -> bool:
	_prepared_load_fingerprint = ""
	_prepared_state = {}
	var error: String = check_load(data)
	if not error.is_empty():
		save_blocked = true
		load_error = error
		return false
	var path: String = world.save_path()
	if not data.has(SAVE_KEY) and FileAccess.file_exists(path):
		var original_hash: String = FileAccess.get_sha256(path)
		var backup: String = path + ".pre-option-awakening"
		if FileAccess.file_exists(backup) and FileAccess.get_sha256(backup) != original_hash:
			backup += "." + original_hash.substr(0, 16)
		if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(path, backup) != OK:
			save_blocked = true
			load_error = "각성 저장 이전 백업 실패 · 기존 저장 보존"
			return false
		if original_hash.is_empty() or FileAccess.get_sha256(backup) != original_hash:
			save_blocked = true
			load_error = "각성 저장 이전 백업 무결성 확인 실패"
			return false
	_prepared_state = core.normalized_state(data.get(SAVE_KEY, Core.fresh_state()))
	_prepared_load_fingerprint = JSON.stringify(data).sha256_text()
	load_error = ""
	return true

func accept_load(data: Dictionary) -> bool:
	if _prepared_load_fingerprint != JSON.stringify(data).sha256_text():
		if not prepare_load(data): return false
	# All disk IO and validation were performed before other world state changes.
	progress = _prepared_state.duplicate(true)
	_prepared_load_fingerprint = ""
	_prepared_state = {}
	var rng_text: String = str(progress.get("rng_state", ""))
	if not rng_text.is_empty(): rng.state = int(rng_text)
	save_blocked = false
	_bonus_signature = ""
	return true

func view(category: String, target_id: String) -> Dictionary:
	if not problem.is_empty(): return Core.fail("configuration", problem)
	var out: Dictionary = core.view(progress, world.card_draw_fusion.export_state(), int(world.gold), category, target_id)
	if save_blocked and bool(out.get("ok", false)):
		out.can_feed = false
		out.can_awaken = false
		out["blocked_reason"] = "저장 보호 중 · 정상 저장을 다시 불러오세요"
	return out

func feed(category: String, target_id: String, materials: Dictionary) -> Dictionary:
	return _transact(category, target_id, materials, false)

func awaken(category: String, target_id: String) -> Dictionary:
	return _transact(category, target_id, {}, true)

func _transact(category: String, target_id: String, materials: Dictionary, is_attempt: bool) -> Dictionary:
	if _busy:
		return {"ok": false, "code": "busy", "error": "이전 각성 처리 중", "snapshot": view(category, target_id)}
	if save_blocked or not problem.is_empty():
		return {"ok": false, "code": "save_blocked", "error": "저장 보호 중 · 정상 저장을 다시 불러오세요", "snapshot": view(category, target_id)}
	_busy = true
	var before: Dictionary = export_state()
	var cards: Dictionary = world.card_draw_fusion.export_state()
	var staged_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	staged_rng.state = rng.state
	var result: Dictionary
	if is_attempt:
		# The temporary RNG is discarded on validation or persistence failure.
		result = core.prepare_awaken(before, cards, int(world.gold), category, target_id, staged_rng.randi_range(0, 9999))
	else:
		result = core.prepare_feed(before, cards, int(world.gold), category, target_id, materials)
	if not bool(result.get("ok", false)):
		_busy = false
		result["snapshot"] = view(category, target_id)
		return result
	var next: Dictionary = result.state
	next["rng_state"] = str(staged_rng.state)
	var override: Dictionary = {SAVE_KEY: next, "card_draw_fusion": result.card_state, "gold": result.gold}
	var error: Error = world._save_game(true, override)
	if error != OK:
		_busy = false
		return {"ok": false, "code": "save_failed", "error": "저장 실패 · 재료·아데나·각성 진행은 변경하지 않았습니다", "snapshot": view(category, target_id)}
	# No live mutation or result presentation occurs before this durable commit.
	world.card_draw_fusion.import_state(result.card_state)
	world.gold = int(result.gold)
	progress = next.duplicate(true)
	rng.state = staged_rng.state
	_bonus_signature = ""
	_busy = false
	result.erase("state")
	result.erase("card_state")
	result.erase("gold")
	result["category"] = category
	result["target_id"] = target_id
	result["snapshot"] = view(category, target_id)
	return result

func is_awakened(category: String, record_or_id: Variant) -> bool:
	var identity: String = Cards.card_id(record_or_id) if record_or_id is Dictionary else str(record_or_id)
	return core.awakened(progress, category, identity)

func collections_view() -> Array:
	return core.collection_views(progress, world.card_draw_fusion.export_state()) if world != null else []

func _ensure_bonus_cache() -> void:
	if world == null or not problem.is_empty():
		_bonus_records.clear()
		_totals.clear()
		_bonus_signature = ""
		return
	var key: String = str(progress.get("revision", 0))
	for category: String in Core.CATEGORIES:
		var record: Variant = world.equipped_catalog.get(category, {})
		key += "|" + category + ":" + (Cards.card_id(record) if record is Dictionary else "")
	# Only the small, explicitly listed collection membership set is inspected;
	# there is no per-frame scan through all cards or mutations of source options.
	var ownership: Dictionary = {"owned": world.card_draw_fusion.owned}
	for collection: Dictionary in core.collections:
		for requirement: Dictionary in collection.requirements:
			key += "1" if core.owned(ownership, str(requirement.category), str(requirement.id)) else "0"
	if key == _bonus_signature: return
	_bonus_signature = key
	_bonus_records.clear()
	_totals.clear()
	for category: String in Core.CATEGORIES:
		var record: Variant = world.equipped_catalog.get(category, {})
		if not record is Dictionary: continue
		var identity: String = Cards.card_id(record)
		if core.awakened(progress, category, identity):
			_add_bonus(core.definition(category, identity).stats, category + ":" + identity)
	for collection: Dictionary in core.collection_views(progress, ownership):
		if bool(collection.completed): _add_bonus(collection.stats, "collection:" + str(collection.id))

func _add_bonus(stats: Dictionary, origin: String) -> void:
	var record: Dictionary = {"_option_awakening_bonus": true, "origin": origin}
	for key: String in stats:
		_totals[key] = float(_totals.get(key, 0.0)) + float(stats[key])
		if key == "moveSpeedPct": record["speedBonusPct"] = stats[key]
		else: record[key] = stats[key]
	_bonus_records.append(record)

func bonus_records() -> Array[Dictionary]:
	_ensure_bonus_cache()
	return _bonus_records.duplicate(true)

func catalog_bonus(key: String) -> int:
	_ensure_bonus_cache()
	return int(_totals.get(key, 0))

func accuracy_bonus(style: String) -> int:
	return catalog_bonus({"melee": "meleeHit", "ranged": "rangedHit", "magic": "magicHit"}.get(style, ""))
