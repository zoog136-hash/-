extends RefCounted
## Authoritative adapter for the existing World. No demo inventory, sidecar saves,
## fuzzy name matching, PvP conversion, or per-frame collection scans.
const Core = preload("res://scripts/collections/equipment_collection_service.gd")
const Stats = preload("res://scripts/collections/equipment_collection_stats.gd")
const PATH: String = "res://data/collections/equipment_collections.json"
const SAVE_KEY: String = "equipment_collections"
var world
var core = Core.new()
var progress: Dictionary = Core.fresh_state()
var totals: Dictionary = {}
var bonus_record: Dictionary = {}
var extra_save_fields: Dictionary = {}
var save_blocked: bool = false
var problem: String = ""
var _rows: Array = []
var _availability: Dictionary = {}
var _sources: Dictionary = {}
var _exact_names: Dictionary = {}
var _normalized_names: Dictionary = {}
var _busy: bool = false
var _disk_hash: String = ""
var _disk_path: String = ""
## Only used by regression tests; an invalid Callable uses the real atomic writer.
var test_save_writer: Callable

func configure(host: Node) -> bool:
	world = host
	var parser := JSON.new()
	if not FileAccess.file_exists(PATH) or parser.parse(FileAccess.get_file_as_string(PATH)) != OK or not parser.data is Dictionary:
		problem = "장비 컬렉션 데이터 파일 누락 또는 손상"
		save_blocked = true
		return false
	var catalog: Array = []
	_sources.clear()
	_exact_names.clear()
	_normalized_names.clear()
	for raw: Variant in world.catalog_db.get("아이템",[]):
		if not raw is Dictionary: continue
		var row: Dictionary = raw
		var source: String = str(row.get("sourceId",""))
		if source.is_empty() or _sources.has(source) or world._enhancement_kind_for_record(row).is_empty(): continue
		_sources[source] = row.duplicate(true)
		var name_value: String = str(row.get("name",""))
		var canonical: String = Core.normalize_name(name_value)
		if not _exact_names.has(name_value): _exact_names[name_value] = []
		_exact_names[name_value].append(source)
		if not _normalized_names.has(canonical): _normalized_names[canonical] = []
		_normalized_names[canonical].append(source)
		catalog.append({"source_id":source,"name":name_value,"kind":"equipment"})
	if not core.configure(parser.data,catalog,Stats.SUPPORTED):
		problem = core.last_error
		save_blocked = true
		return false
	_rows = core.definitions()
	_availability.clear()
	for row: Dictionary in _rows:
		_availability[str(row.id)] = core.availability(str(row.id))
	_rebuild()
	return true

func definitions() -> Array:
	return _rows.duplicate(true)

func availability(cid: String) -> Dictionary:
	if not problem.is_empty(): return fail("configuration",problem)
	var resolved: Dictionary = core.resolve(cid)
	return _availability.get(str(resolved.get("id","")),fail("unknown_collection","알 수 없는 컬렉션")).duplicate(true)

func bonus(key: String) -> float:
	return float(totals.get(key,0.0))

func catalog_bonus(key: String) -> int:
	return Stats.catalog_bonus(totals,key)

func stat_record() -> Dictionary:
	return bonus_record # Read-only by World; never insert into real equipment/catalog.

func _rebuild() -> void:
	totals = core.bonuses(progress)
	bonus_record = Stats.record(totals)

func export_state() -> Dictionary:
	var out: Dictionary = progress.duplicate(true)
	out["gear"] = {} # World.item_instances is the only authoritative gear storage.
	return out

func _read_state(data: Dictionary) -> Dictionary:
	return data.get(SAVE_KEY,Core.fresh_state()).duplicate(true) if data.get(SAVE_KEY,Core.fresh_state()) is Dictionary else {}

func check_load(data: Dictionary) -> String:
	if not problem.is_empty(): return problem
	var state: Dictionary = _read_state(data)
	var error: String = core.validate_state(state)
	if not error.is_empty(): return error
	if not state.gear.is_empty(): return "독립 데모 인벤토리는 실제 게임 저장으로 가져올 수 없습니다"
	if not state.get("favorites",[]) is Array: return "즐겨찾기 저장 형식 오류"
	var live: Variant = data.get("item_instances",{})
	if not live is Dictionary: return "장비 개체 저장 형식 오류"
	for id: String in state.receipts:
		if live.has(id): return "등록 영수증과 현재 장비 ID가 중복됩니다"
	return ""

func accept_load(data: Dictionary) -> bool:
	var error: String = check_load(data)
	if not error.is_empty():
		save_blocked = true
		world.hud.show_message(error)
		return false
	var path: String = world.save_path()
	if not data.has(SAVE_KEY) and FileAccess.file_exists(path) and not FileAccess.file_exists(path+".pre-equipment-collections"):
		if DirAccess.copy_absolute(path,path+".pre-equipment-collections") != OK:
			save_blocked = true
			world.hud.show_message("컬렉션 저장 이전 백업 실패 · 기존 저장 보존")
			return false
	progress = _read_state(data)
	extra_save_fields = data.duplicate(true)
	# Only unknown top-level fields are retained, not old map hashes or live state.
	for key: String in KNOWN_SAVE_KEYS: extra_save_fields.erase(key)
	save_blocked = false
	_disk_path = path
	_disk_hash = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	_rebuild()
	return true

func next_safe_id() -> int:
	var result: int = 1
	for id: String in progress.receipts:
		if id.is_valid_int(): result = maxi(result,int(id)+1)
	return result

func write_save(path: String, data: Dictionary) -> Error:
	if save_blocked or not problem.is_empty(): return ERR_UNAVAILABLE
	# Refuse an external/stale save replacement rather than resurrecting consumed gear.
	var current_hash: String = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	if _disk_path == path and current_hash != _disk_hash:
		save_blocked = true
		world.hud.append_log("외부 저장 변경 감지 · 다시 불러오기 전 저장 차단")
		return ERR_BUSY
	if _disk_path != path and not current_hash.is_empty(): return ERR_BUSY
	var error: Error = OK
	if test_save_writer.is_valid():
		error = test_save_writer.call(path,data.duplicate(true))
	else:
		error = preload("res://scripts/skills/save_writer.gd").write(path,data)
	if error == OK:
		_disk_path = path
		_disk_hash = FileAccess.get_sha256(path)
	return error

func _source_for(physical: Dictionary) -> String:
	var name_value: String = str(physical.get("name",""))
	var pinned: Variant = physical.get("record",{})
	if not pinned is Dictionary: return ""
	var direct: String = str(physical.get("sourceId",""))
	var record_id: String = str(pinned.get("sourceId",""))
	if not direct.is_empty() and not record_id.is_empty() and direct != record_id: return ""
	var source: String = direct if not direct.is_empty() else record_id
	if not source.is_empty():
		if not _sources.has(source): return ""
		if Core.normalize_name(name_value) != Core.normalize_name(str(_sources[source].name)): return ""
		if not str(pinned.get("name",name_value)).is_empty() and Core.normalize_name(str(pinned.get("name",name_value))) != Core.normalize_name(name_value): return ""
		return source
	# A name-only legacy item must match exactly ONE original catalog name.
	# Never pick the first source of a same-name multi-variant item.
	var matches: Array = _exact_names.get(name_value,[])
	return str(matches[0]) if matches.size() == 1 else ""

func snapshot() -> Dictionary:
	var out: Dictionary = export_state()
	for raw_id: Variant in world.item_instances:
		var id: String = str(raw_id)
		var raw: Variant = world.item_instances[raw_id]
		if not raw is Dictionary: continue
		var physical: Dictionary = raw
		var name_value: String = str(physical.get("name",""))
		if int(world.inventory.get(name_value,0)) < 1 or not Core._integer(physical.get("level",0)): continue
		out.gear[id] = {"instance_id":id,"name":name_value,"source_id":_source_for(physical),
			"enchant":physical.get("level",0),"quantity":1,
			"equipped":bool(world._is_instance_equipped(id)),
			"locked":bool(world._item_locked(name_value,id)) or bool(world._item_locked(name_value)) or bool(physical.get("locked",false))}
	return out

func candidates(cid: String, sid: String) -> Array:
	return core.candidates(snapshot(),cid,sid)

func completed(cid: String) -> bool:
	return core.complete(progress,cid)

func slot_count(cid: String, sid: String) -> int:
	return progress.progress.get(cid,{}).get(sid,[]).size()

func icon_record(name_value: String) -> Dictionary:
	var exact: Array = _exact_names.get(name_value,[])
	var matches: Array = exact if not exact.is_empty() else _normalized_names.get(name_value,[])
	return _sources.get(str(matches[0]),{}).duplicate(true) if not matches.is_empty() else {}

func request_for(cid: String, sid: String, ids: Array) -> Dictionary:
	return {"collection_id":cid,"slot_id":sid,"instance_ids":ids.duplicate(),
		"expected_revision":int(progress.revision),"request_id":Crypto.new().generate_random_bytes(16).hex_encode()}

func register(request: Dictionary) -> Dictionary:
	if _busy: return fail("busy","이전 등록 처리 중")
	if save_blocked: return fail("save_blocked","저장 보호 중 · 정상 저장을 다시 불러오세요")
	_busy = true
	var snapshot_value: Dictionary = snapshot()
	var result: Dictionary = core.prepare_registration(snapshot_value,request)
	if not bool(result.get("ok",false)) or bool(result.get("already_applied",false)):
		_busy = false
		return result
	var next_inventory: Dictionary = world.inventory.duplicate(true)
	var next_instances: Dictionary = world.item_instances.duplicate(true)
	var requested_counts: Dictionary = {}
	for raw_id: Variant in request.instance_ids:
		var id: String = str(raw_id)
		var name_value: String = str(next_instances[id].name)
		requested_counts[name_value] = int(requested_counts.get(name_value,0))+1
	for name_value: String in requested_counts:
		var live_count: int = 0
		for item: Variant in world.item_instances.values():
			if item is Dictionary and str(item.get("name","")) == name_value: live_count += 1
		if live_count != int(world.inventory.get(name_value,0)):
			_busy = false
			return fail("inventory_mismatch","인벤토리 수량과 개별 장비가 일치하지 않습니다")
	for raw_id: Variant in request.instance_ids:
		var id: String = str(raw_id)
		var name_value: String = str(next_instances[id].name)
		next_instances.erase(id)
		next_inventory[name_value] = int(next_inventory[name_value])-1
		if int(next_inventory[name_value]) == 0: next_inventory.erase(name_value)
	var next: Dictionary = result.state.duplicate(true)
	next.gear = {}
	var override: Dictionary = {"inventory":next_inventory,"item_instances":next_instances,SAVE_KEY:next}
	var error: Error = world._save_game(true,override)
	if error != OK:
		_busy = false
		return fail("save_failed","저장 실패 · 장비와 진행도는 변경하지 않았습니다")
	# Only the durable, atomically committed complete snapshot becomes live.
	world.inventory = next_inventory
	world.item_instances = next_instances
	progress = next
	_rebuild()
	_busy = false
	world._update_hud()
	world.hud.append_log("장비 컬렉션 등록 · "+str(core.resolve(str(request.collection_id)).name))
	result.erase("state")
	return result

func set_favorite(cid: String, enabled: bool) -> bool:
	if save_blocked or core.resolve(cid).is_empty() or _busy: return false
	var next: Dictionary = export_state()
	if enabled and not next.favorites.has(cid): next.favorites.append(cid)
	if not enabled: next.favorites.erase(cid)
	next.revision = int(next.revision)+1
	if world._save_game(true,{SAVE_KEY:next}) != OK: return false
	progress = next
	return true

func summary() -> Dictionary:
	var available_count: int = 0
	var completed_count: int = 0
	var reasons: Dictionary = {}
	for row: Dictionary in _rows:
		var ready: Dictionary = availability(str(row.id))
		if bool(ready.get("ok",false)): available_count += 1
		else:
			var code: String = str(ready.get("code","unknown"))
			reasons[code] = int(reasons.get(code,0))+1
		if completed(str(row.id)): completed_count += 1
	return {"total":_rows.size(),"available":available_count,"completed":completed_count,"blocked":_rows.size()-available_count,"reasons":reasons}

static func fail(code: String, message: String) -> Dictionary:
	return {"ok":false,"code":code,"message":message}

# Generated from the current World save dictionary; CI asserts exact parity.
const KNOWN_SAVE_KEYS: Array = ["map_id", "map_layout_revision", "position", "level", "experience", "exp_need", "experience_progression_version", "hp", "max_hp", "mp", "max_mp", "hp_recovery_elapsed", "mp_recovery_elapsed", "attack", "defense", "str", "dex", "con", "int", "wis", "cha", "stat_points", "gold", "inventory", "ground_drops", "warehouse", "crafting_log", "monster_world", "original_monster_world", "original_position", "class_index", "job_class", "quickslots", "ui_preferences", "self_mode_enabled", "active_skill_buffs", "skill_cooldowns", "skill_global_cooldown", "original_skill_state", "original_combat_state", "active_item_buffs", "item_use_cooldowns", "consumable_state", "ainhasad_state", "equipped_catalog", "card_draw_fusion", "card_option_awakening", "equipped_items", "enhancement_levels", "item_instances", "next_item_instance_id", "native_png_plan_sha256", "native_png_review_sha256", "equipment_collections", "growth"]
