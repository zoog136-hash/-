extends RefCounted
const Source = preload("res://scripts/death/source_rules.gd")
const Progression = preload("res://scripts/experience_progression.gd")
const KEY: String = "death_recovery523"
var world
var source = Source.new()
var state: Dictionary = fresh()
var policy: Dictionary = {}
var pending: Dictionary = {}
var save_blocked: bool = false
var busy: bool = false
# Synchronous save capability for this recovery only; never exported or saved.
var _saving_recovery_fields: Dictionary = {}
var clock_floor: int = 0
var view: Control
var death_overlay: Control
var test_clock: Callable

static func fresh() -> Dictionary:
	return {"version":1,"revision":0,"next_id":1,"dead_id":"","last_time":0,"free_day":-1,"free_used":0,"records":[],"slot_expansions":{"exp":0,"item":0}}

func configure(host) -> void:
	world = host
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string("res://data/config/death523_policy.json")) == OK and parser.data is Dictionary: policy = parser.data
	for key: String in ["item_loss_percent","item_recovery_adena","adena_per_gem","extended_gem_per_hour","restart_hp_fraction","restart_mp_fraction","timezone_offset_seconds","reset_hour","fallback_exp_loss_percent","fallback_adena_level_squared"]:
		if not (policy.get(key) is int or policy.get(key) is float) or not is_finite(float(policy.get(key))): save_blocked = true
	if not save_blocked:
		if float(policy.item_loss_percent) < 0 or float(policy.item_loss_percent) > 100 or float(policy.restart_hp_fraction) <= 0 or float(policy.restart_hp_fraction) > 1 or float(policy.restart_mp_fraction) < 0 or float(policy.restart_mp_fraction) > 1 or int(policy.adena_per_gem) < 1 or int(policy.item_recovery_adena) < 0 or int(policy.extended_gem_per_hour) < 0 or int(policy.reset_hour) < 0 or int(policy.reset_hour) > 23: save_blocked = true
	for key: String in ["certificate_per_recovery","base_recovery_slots","maximum_slot_expansions"]:
		if not integer(policy.get(key),1) or float(policy.get(key,0)) > 1000: save_blocked = true
	for key: String in ["death_stat_exp_reduction_percent_per_point","death_stat_item_reduction_percent_per_point","death_stat_custom_cap","death_stat_maximum_reduction_percent"]:
		if not (policy.get(key) is int or policy.get(key) is float) or not is_finite(float(policy.get(key))) or float(policy.get(key)) < 0 or float(policy.get(key)) > 100: save_blocked = true
	var explicit_source: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--death523-source":
			explicit_source = true
			source.problem = "명시한 사망 원본 경로가 없습니다 · 기존 자료 보존"
		elif argument.begins_with("--death523-source="):
			explicit_source = true
			if not source.load_pack(argument.trim_prefix("--death523-source=")):
				source.problem = "명시한 사망 원본을 읽을 수 없습니다 · 기존 자료 보존"
	source.fallback_loss_percent = clampf(float(policy.get("fallback_exp_loss_percent",5.0)),0.0,100.0)
	source.fallback_cost_factor = clampi(int(policy.get("fallback_adena_level_squared",12)),0,1000000)
	# UNVERIFIED: empty/bare/invalid explicit choices never trigger a second
	# default or common-source load. Failed imports retain already-ready data.
	if not explicit_source and not source.ready: source.load_default_source()

func now() -> int:
	var wall: int = int(test_clock.call()) if test_clock.is_valid() else int(Time.get_unix_time_from_system())
	clock_floor = maxi(maxi(wall,clock_floor),int(state.last_time))
	return clock_floor

func blocked() -> bool:
	return not pending.is_empty() or not str(state.dead_id).is_empty()

func export_state() -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out.last_time = persisted_clock_floor(now())
	return out

# The saved high-water clock only has to stop a clock rollback across restarts
# from changing a recovery rule. Rules change only at fixed ages of an open
# record: 24 h (adena -> gem), every following hour (gem cost) and 72 h
# (expiry). Persist the latest such boundary already crossed, so a rolled-back
# clock yields exactly the same quotes, while an unchanged game no longer
# rewrites its save every second (that defeated identical-save skipping).
# In-session time is still the exact monotonic now().
const RULE_START_AGE: int = 86400
const RULE_STEP: int = 3600
const RULE_EXPIRY_AGE: int = 259200

func persisted_clock_floor(current: int) -> int:
	var floor_time: int = int(state.last_time)
	for entry: Dictionary in state.records:
		if bool(entry.get("exp_claimed",true)) and bool(entry.get("item_claimed",true)): continue
		var age: int = current - int(entry.at)
		if age < RULE_START_AGE: continue
		var crossed: int = mini(RULE_EXPIRY_AGE, RULE_START_AGE + floori(float(age - RULE_START_AGE) / RULE_STEP) * RULE_STEP)
		floor_time = maxi(floor_time, int(entry.at) + crossed)
	return floor_time

static func integer(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) < 9007199254740991.0

func validate(raw: Variant, live: Dictionary = {}) -> String:
	if not raw is Dictionary: return "사망 복구 저장 형식 오류"
	for key: String in ["version","revision","next_id","last_time","free_used"]:
		if not integer(raw.get(key)): return "사망 복구 숫자 오류: "+key
	if int(raw.version) != 1 or int(raw.next_id) < 1 or int(raw.free_used) > 2 or not integer(raw.get("free_day"),-1) or not raw.get("dead_id") is String or not raw.get("records") is Array: return "사망 복구 저장 버전/횟수 오류"
	if raw.has("slot_expansions"):
		if not raw.slot_expansions is Dictionary: return "복구 슬롯 저장 오류"
		for kind: String in ["exp","item"]:
			if not integer(raw.slot_expansions.get(kind)): return "복구 슬롯 수치 오류"
	var ids: Dictionary = {}
	var physical_ids: Dictionary = {}
	var dead_found: bool = str(raw.dead_id).is_empty()
	for entry: Variant in raw.records:
		if not entry is Dictionary: return "사망 내역 형식 오류"
		for key: String in ["id","map","cause"]:
			if not entry.get(key) is String: return "사망 내역 식별자 오류"
		if ids.has(entry.id) or not entry.id.is_valid_int() or int(entry.id) < 1 or int(entry.id) >= int(raw.next_id): return "중복 사망 내역"
		ids[entry.id] = true
		for key: String in ["at","level","exp","cost"]:
			if not integer(entry.get(key)): return "사망 내역 수치 오류"
		if int(entry.at) > int(raw.last_time): return "사망 내역 시각 오류"
		for key: String in ["exp_claimed","item_claimed","revived"]:
			if not entry.get(key) is bool: return "사망 복구 상태 오류"
		if not entry.get("item") is Dictionary: return "사망 보관 장비 오류"
		if not entry.item.is_empty():
			var item: Dictionary = entry.item
			if not item.get("id") is String or not item.get("physical") is Dictionary or not item.physical.get("name") is String or item.physical.name.is_empty() or not integer(item.physical.get("level",0)): return "사망 보관 장비 식별 오류"
			if not bool(entry.item_claimed):
				if physical_ids.has(item.id) or live.has(item.id): return "복구 장비와 현재 장비 ID 중복"
				physical_ids[item.id] = true
		if str(entry.id) == str(raw.dead_id):
			if entry.revived: return "부활 상태 불일치"
			dead_found = true
	if not dead_found: return "사망 중인 내역 누락"
	return ""

static func ownership(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw: Variant in [data.get("item_instances",{}),data.get("warehouse",{}).get("instances",{}) if data.get("warehouse",{}) is Dictionary else {},data.get("equipment_collections",{}).get("receipts",{}) if data.get("equipment_collections",{}) is Dictionary else {}]:
		if raw is Dictionary:
			for id: Variant in raw: out[str(id)] = true
	if data.get("ground_drops",[]) is Array:
		for drop: Variant in data.get("ground_drops",[]):
			if drop is Dictionary and drop.get("physical_item") is Dictionary: out[str(drop.physical_item.get("id",""))] = true
	return out

func check_load(data: Dictionary) -> String:
	var raw: Variant = data.get(KEY,fresh())
	var problem: String = validate(raw,ownership(data))
	if problem.is_empty() and not str(raw.dead_id).is_empty() and int(data.get("hp",0)) != 0: problem = "사망 저장 HP 불일치"
	return problem

func prepare_load(data: Dictionary, path: String) -> bool:
	if not check_load(data).is_empty(): return false
	if not data.has(KEY) and FileAccess.file_exists(path):
		var backup: String = path+".pre-death523-"+FileAccess.get_sha256(path)
		if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(path,backup) != OK: return false
	return true

func accept_load(data: Dictionary) -> void:
	state = data.get(KEY,fresh()).duplicate(true)
	if not state.has("slot_expansions"): state.slot_expansions = {"exp":0,"item":0}
	pending.clear(); save_blocked = false; clock_floor = int(state.last_time)
	world.call_deferred("_resume_death523")

func reserved(id: String) -> bool:
	for entry: Dictionary in state.records:
		if not entry.item.is_empty() and str(entry.item.id) == id: return true
	return false

func source_context() -> Dictionary:
	# Only explicit source contracts supply IDs/coordinates. Host map names are
	# never guessed to mean a native Land ID.
	var out: Dictionary = {"land":-1,"position":Vector2.INF}
	if world.field_map == null: return out
	var data: Dictionary = world.field_map.data
	if data.has("source_land_id"): out.land = int(data.source_land_id)
	if data.has("source_m_land_id"): out.land = int(data.source_m_land_id)
	if world.field_map.has_method("world_to_source"):
		out.position = world.field_map.call("world_to_source",world.player.global_position)
	return out

func death_policy() -> Dictionary:
	var context: Dictionary = source_context()
	var p: Dictionary = source.land_policy(int(context.land),context.position)
	var safe: bool = world.field_map != null and world.field_map.is_safe(world.player.global_position)
	p["exempt"] = bool(p.no_penalty) or (safe and not bool(p.npc_penalty))
	return p

func death_stats() -> Dictionary:
	var value: int = 0
	var seen: Dictionary = {}
	if source.ready:
		for raw: Variant in world.equipped_items.values():
			if not raw is Dictionary: continue
			var id: String = str(raw.get("instance_id",""))
			if id.is_empty() or seen.has(id) or not world.item_instances.has(id): continue
			seen[id] = true
			var physical: Dictionary = world.item_instances[id]
			var item_name: String = str(physical.get("name",""))
			if item_name != str(raw.get("name","")) or int(world.inventory.get(item_name,0)) < 1: continue
			var record: Dictionary = physical.get("record",{})
			if record.is_empty():
				if int(world.catalog_item_variant_count.get(item_name,0)) > 1: continue
				record = world._find_catalog_item_record(item_name)
			var sid: String = str(physical.get("sourceId",record.get("sourceId","")))
			if str(record.get("name","")) != item_name or not source.matches_item(record,sid) or bool(source.items[sid].TestItem): continue
			value += int(source.item_death_stats.get(sid,0))
	value = clampi(value,0,int(policy.get("death_stat_custom_cap",50)))
	# Native equipment declares KarmaDeath, but no server reduction formula
	# exists. These two coefficients and cap are explicitly local policy.
	var maximum: float = float(policy.get("death_stat_maximum_reduction_percent",90.0))
	return {"value":value,"exp_reduction":clampf(value*float(policy.get("death_stat_exp_reduction_percent_per_point",1.0)),0,maximum),"item_reduction":clampf(value*float(policy.get("death_stat_item_reduction_percent_per_point",1.0)),0,maximum)}

func _select_loss(reduction: float = 0.0) -> Dictionary:
	if not source.ready: return {}
	var draw := RandomNumberGenerator.new()
	draw.randomize()
	if draw.randf()*100.0 >= float(policy.get("item_loss_percent",5.0))*(1.0-reduction/100.0): return {}
	var candidates: Array = []
	for id: String in world.item_instances:
		var physical: Dictionary = world.item_instances[id]
		var name_value: String = str(physical.get("name",""))
		if world._is_instance_equipped(id) or world._item_locked(name_value,id) or world._item_locked(name_value) or bool(physical.get("locked",false)): continue
		var record: Dictionary = physical.get("record",{})
		if record.is_empty():
			if int(world.catalog_item_variant_count.get(name_value,0)) > 1: continue
			record = world._find_catalog_item_record(name_value)
		var sid: String = str(physical.get("sourceId",record.get("sourceId","")))
		if str(record.get("name","")) != name_value or world._enhancement_kind_for_record(record).is_empty() or not source.matches_item(record,sid) or not bool(source.items[sid].IsDroppable) or bool(source.items[sid].TestItem) or int(world.inventory.get(name_value,0)) < 1: continue
		candidates.append({"id":id,"physical":physical.duplicate(true),"source_id":sid})
	if candidates.is_empty(): return {}
	return candidates[draw.randi_range(0,candidates.size()-1)]

func begin_death(cause: String) -> void:
	if not str(state.dead_id).is_empty(): return
	if pending.is_empty():
		world._sync_item_instances()
		var p: Dictionary = death_policy()
		var next: Dictionary = export_state()
		var lost: int = 0 if p.exempt or p.no_exp else source.exp_loss(world.level,world.experience,world.exp_need)
		var stats: Dictionary = death_stats()
		lost = int(floor(lost*(1.0-float(stats.exp_reduction)/100.0)))
		var item_exempt: bool = world.level <= source.item_exemption_level() or (source.ready and int(source.row(world.level).get("DropRate",0)) <= 0)
		var item: Dictionary = {} if p.exempt or p.no_item or item_exempt else _select_loss(float(stats.item_reduction))
		var id: String = str(int(next.next_id))
		var entry: Dictionary = {"id":id,"at":now(),"map":world.active_map_id,"cause":cause,"level":world.level,"exp":lost,"cost":source.cost(world.level),"exp_claimed":lost == 0,"item":item,"item_claimed":item.is_empty(),"revived":false,"full_revive":bool(p.full_revive),"source_rules":source.ready,"exempt":p.exempt}
		entry["death_stat_policy"] = stats
		next.last_time = int(entry.at)
		next.next_id = int(next.next_id)+1; next.revision = int(next.revision)+1
		next.dead_id = id; next.records.append(entry)
		var inventory: Dictionary = world.inventory.duplicate(true)
		var instances: Dictionary = world.item_instances.duplicate(true)
		if not item.is_empty():
			var item_name: String = str(item.physical.name)
			inventory[item_name] = int(inventory[item_name])-1
			if int(inventory[item_name]) == 0: inventory.erase(item_name)
			instances.erase(str(item.id))
		pending = {"state":next,"fields":{"hp":0,"experience":world.experience-lost,"inventory":inventory,"item_instances":instances}}
	world._clear_combat_actions()
	world.player.set_auto_enabled(false)
	world.player.set_physics_process(false)
	world.player.clear_click_path()
	world.loot_pickup.cancel()
	var fields: Dictionary = pending.fields.duplicate(true)
	fields[KEY] = pending.state
	if world._save_game(true,fields) == OK:
		state = pending.state
		_publish(pending.fields)
		pending.clear()
		world.hud.append_log("사망 내역 저장 · 복구 화면에서 손실과 부활을 확인하세요")
	show_death()

func resume() -> void:
	if blocked():
		world.player.set_auto_enabled(false)
		world.player.set_physics_process(false)
		show_death()
	elif world.hp <= 0: begin_death("이전 저장의 사망 상태")

func _entry(id: String) -> Dictionary:
	for entry: Dictionary in state.records:
		if str(entry.id) == id: return entry
	return {}

func _staged_entry(next: Dictionary, id: String) -> Dictionary:
	for entry: Dictionary in next.records:
		if str(entry.id) == id: return entry
	return {}

func _day(timestamp: int) -> int:
	return int(floor(float(timestamp+int(policy.get("timezone_offset_seconds",32400))-int(policy.get("reset_hour",5))*3600)/86400.0))

func free_remaining() -> int:
	return 2 if _day(now()) > int(state.free_day) else maxi(0,2-int(state.free_used))

func slot_capacity(kind: String) -> int:
	return int(policy.get("base_recovery_slots",5))+int(state.get("slot_expansions",{}).get(kind,0))

func active_losses(kind: String) -> Array:
	var out: Array = []
	for entry: Dictionary in state.records:
		if not bool(entry[kind+"_claimed"]) and now()-int(entry.at) < 259200: out.append(str(entry.id))
	return out

func certificate_wallet() -> Dictionary:
	if not source.ready: return {}
	for id: String in ["198494","895"]:
		var item_name: String = str(source.certificates.get(id,""))
		if item_name.is_empty() or world._item_locked(item_name) or not integer(world.inventory.get(item_name,0),int(policy.get("certificate_per_recovery",1))): continue
		# Existing stack wallets are keyed by exact localized name. Reject a
		# conflicting catalog identity or physical object rather than consuming
		# a similarly named equipment/event variant or leaving an orphan ID.
		if int(world.catalog_item_variant_count.get(item_name,0)) > 1: continue
		var record: Dictionary = world._find_catalog_item_record(item_name)
		if not record.is_empty() and not source.matches_item(record,id): continue
		var physical_conflict: bool = false
		for physical: Dictionary in world.item_instances.values():
			if str(physical.get("name","")) == item_name: physical_conflict = true; break
		if not physical_conflict: return {"source_id":id,"name":item_name}
	return {}

func quote_slot(kind: String) -> Dictionary:
	if kind not in ["exp","item"] or blocked() or save_blocked or busy: return fail("슬롯을 확장할 수 없는 상태입니다")
	if not source.ready or not source.slot_offers.has(kind): return fail("원본523 슬롯 구매 정의가 필요합니다")
	var offer: Dictionary = source.slot_offers[kind]
	var owned: int = int(state.get("slot_expansions",{}).get(kind,0))
	if owned+int(offer.amount) > int(policy.get("maximum_slot_expansions",45)): return fail("자체 정책의 슬롯 확장 한도입니다")
	if int(world.inventory.get("다이아",0)) < int(offer.cost): return fail("다이아가 부족합니다")
	return {"ok":true,"kind":kind,"cost":int(offer.cost),"amount":int(offer.amount),"revision":state.revision,"purchase_id":int(offer.purchase_id),"message":""}

func expand_slot(request: Dictionary) -> Dictionary:
	var current: Dictionary = quote_slot(str(request.get("kind","")))
	if not current.ok: return current
	for key: String in ["cost","amount","revision","purchase_id"]:
		if current[key] != request.get(key): return fail("슬롯 또는 비용이 바뀌었습니다. 다시 확인하세요")
	busy = true
	var next: Dictionary = export_state()
	if not next.has("slot_expansions"): next.slot_expansions = {"exp":0,"item":0}
	next.slot_expansions[current.kind] = int(next.slot_expansions[current.kind])+int(current.amount)
	next.revision = int(next.revision)+1
	var inventory: Dictionary = world.inventory.duplicate(true)
	inventory["다이아"] = int(inventory.get("다이아",0))-int(current.cost)
	next["last_slot_receipt"] = {"at":now(),"kind":current.kind,"cost":current.cost,"amount":current.amount,"purchase_id":current.purchase_id}
	if world._save_game(true,{"inventory":inventory,KEY:next}) != OK:
		busy = false; return fail("저장 실패 · 다이아와 슬롯을 보존했습니다")
	state = next; world.inventory = inventory; busy = false; world._update_hud()
	return {"ok":true,"message":"복구 슬롯 확장 완료 · 저장했습니다"}

func quote(id: String, kind: String, mode: String) -> Dictionary:
	if blocked() or save_blocked or busy: return fail("사망 또는 저장 보호 중입니다")
	if kind not in ["exp","item"] or mode not in ["free","adena","gem","certificate"]: return fail("알 수 없는 복구 요청")
	var entry: Dictionary = _entry(id)
	if entry.is_empty() or bool(entry.get(kind+"_claimed",true)): return fail("이미 복구했거나 없는 내역입니다")
	var age: int = maxi(0,now()-int(entry.at))
	if age >= 259200: return fail("복구 기한 72시간이 지났습니다")
	if active_losses(kind).find(id) >= slot_capacity(kind): return fail("복구 슬롯 대기 중 · 앞선 내역 복구 또는 슬롯 확장")
	if age >= 86400 and mode != "gem": return fail("24시간 이후에는 다이아 복구만 가능합니다")
	if mode == "free" and (kind != "exp" or free_remaining() <= 0): return fail("경험치 무료 복구 횟수가 없습니다")
	var certificate: Dictionary = {}
	if mode == "certificate":
		if kind != "exp" or free_remaining() > 0: return fail("구호증서는 무료 경험치 복구 2회 소진 후 사용합니다")
		certificate = certificate_wallet()
		if certificate.is_empty(): return fail("잠금 없는 원본 영구 구호증서가 부족합니다")
	var adena: int = int(entry.cost)
	if kind == "item": adena = maxi(1,int(policy.get("item_recovery_adena",10000)))
	var cost: int = 0 if mode == "free" else adena
	if mode == "certificate": cost = int(policy.get("certificate_per_recovery",1))
	if mode == "gem":
		cost = maxi(1,int(ceil(float(adena)/maxi(1,int(policy.get("adena_per_gem",1000))))))
		if age >= 86400: cost += int(ceil(float(age-86400+1)/3600.0))*int(policy.get("extended_gem_per_hour",1))
	if mode == "adena" and world.gold < cost: return fail("아데나가 부족합니다")
	if mode == "gem" and int(world.inventory.get("다이아",0)) < cost: return fail("다이아가 부족합니다")
	if kind == "item":
		var physical: Dictionary = entry.item.physical
		if ownership({"item_instances":world.item_instances,"warehouse":world.warehouse.snapshot(),"equipment_collections":world.equipment_collections.export_state(),"ground_drops":world._ground_drops_snapshot()}).has(str(entry.item.id)): return fail("같은 물리 장비 ID가 이미 존재합니다")
		var weight: int = int(world.item_weight_index.get(str(physical.name),3))
		if world._inventory_total_weight()+weight > world._carrying_capacity(): return fail("소지품 무게가 초과됩니다")
	return {"ok":true,"id":id,"kind":kind,"mode":mode,"cost":cost,"revision":state.revision,"age":age,"certificate":certificate,"message":""}

func authorizes_recovery_save(staged: Dictionary) -> bool:
	if not busy or _saving_recovery_fields.is_empty() or not staged.get(KEY) is Dictionary: return false
	return staged == _saving_recovery_fields and int(staged[KEY].get("revision",-1)) == int(state.revision)+1

func recover(request: Dictionary) -> Dictionary:
	var current: Dictionary = quote(str(request.get("id","")),str(request.get("kind","")),str(request.get("mode","")))
	if not current.ok: return current
	if current.revision != request.get("revision") or current.cost != request.get("cost"): return fail("내역 또는 비용이 바뀌었습니다. 다시 확인하세요")
	if current.certificate != request.get("certificate",{}): return fail("구호증서 종류가 바뀌었습니다. 다시 확인하세요")
	busy = true
	var next: Dictionary = export_state()
	var entry: Dictionary = _staged_entry(next,str(current.id))
	var fields: Dictionary = {"gold":world.gold,"inventory":world.inventory.duplicate(true),"item_instances":world.item_instances.duplicate(true)}
	if current.mode == "adena": fields.gold -= int(current.cost)
	if current.mode == "gem": fields.inventory["다이아"] = int(fields.inventory.get("다이아",0))-int(current.cost)
	if current.mode == "certificate": fields.inventory[current.certificate.name] = int(fields.inventory.get(current.certificate.name,0))-int(current.cost)
	if current.mode == "free":
		if _day(now()) > int(next.free_day): next.free_day = _day(now()); next.free_used = 0
		next.free_used = int(next.free_used)+1
	if current.kind == "exp": fields.merge(_exp_gain(int(entry.exp)),true)
	else:
		var item_name: String = str(entry.item.physical.name)
		fields.inventory[item_name] = int(fields.inventory.get(item_name,0))+1
		fields.item_instances[str(entry.item.id)] = entry.item.physical.duplicate(true)
	entry[str(current.kind)+"_claimed"] = true
	entry[str(current.kind)+"_receipt"] = {"at":now(),"mode":current.mode,"cost":current.cost}
	if current.mode == "certificate": entry[str(current.kind)+"_receipt"]["certificate"] = current.certificate.duplicate(true)
	next.revision = int(next.revision)+1; fields[KEY] = next
	_saving_recovery_fields = fields.duplicate(true)
	var result: Error = world._save_game(true,fields)
	_saving_recovery_fields.clear()
	if result != OK: busy = false; return fail("저장 실패 · 재화·무료 횟수·복구 대상을 보존했습니다")
	state = next; fields.erase(KEY); _publish(fields); busy = false
	world._update_hud()
	return {"ok":true,"message":"복구 완료 · 저장했습니다"}

func _exp_gain(amount: int) -> Dictionary:
	var out: Dictionary = {"experience":world.experience+amount,"level":world.level,"exp_need":world.exp_need,"max_hp":world.max_hp,"max_mp":world.max_mp,"hp":world.hp,"mp":world.mp,"attack":world.attack_power,"defense":world.defense,"stat_points":world.stat_points}
	while int(out.experience) >= int(out.exp_need):
		out.experience -= int(out.exp_need); out.level = int(out.level)+1
		out.exp_need = Progression.required_for_level(int(out.level),int(out.exp_need))
		out.max_hp = int(out.max_hp)+45; out.max_mp = int(out.max_mp)+9
		# Preserve existing equipment contribution to the effective HP ceiling.
		out.hp = world._effective_max_hp(int(out.max_hp))
		out.mp = out.max_mp; out.attack = int(out.attack)+2; out.defense = int(out.defense)+1
		out.stat_points = int(out.stat_points)+world._stat_points_for_level_up(int(out.level))
	# A recovery that stays in the current level owns only the restored EXP.
	# Unchanged growth fields must not impersonate a quest growth transaction at
	# the shared save boundary. Keep every actual level-up change in the stage.
	for key: String in out.keys():
		var property: String = {"attack":"attack_power"}.get(key,key)
		if out[key] == world.get(property): out.erase(key)
	return out

func resurrect() -> Dictionary:
	if busy or pending.size() > 0 or str(state.dead_id).is_empty(): return fail("사망 내역을 먼저 저장해야 합니다")
	var destination: Vector2 = world._spawn_position()
	if not destination.is_finite() or not world._is_walkable_world(destination): return fail("현재 지역 시작 지점을 확인할 수 없습니다")
	busy = true
	var next: Dictionary = export_state()
	var entry: Dictionary = _staged_entry(next,str(next.dead_id))
	entry.revived = true; entry.resurrected_at = now()
	next.dead_id = ""; next.revision = int(next.revision)+1
	var hp_ratio: float = 1.0 if bool(entry.get("full_revive",false)) else float(policy.get("restart_hp_fraction",0.5))
	var fields: Dictionary = {"hp":maxi(1,int(world._effective_max_hp()*hp_ratio)),"mp":int(world._effective_max_mp()*float(policy.get("restart_mp_fraction",0.2))),KEY:next}
	var before: Vector2 = world.player.global_position
	world.player.global_position = destination
	var result: Error = world._save_game(true,fields)
	if result != OK:
		world.player.global_position = before; busy = false
		return fail("부활 저장 실패 · 위치·내역을 보존했습니다")
	state = next; fields.erase(KEY); _publish(fields)
	world.player.clear_status_effects(); world.player.clear_click_path()
	world.player.set_physics_process(true); world.player.camera.reset_smoothing()
	world.selected_monster = null; world.auto_target = null; world.hud.clear_target()
	busy = false
	if is_instance_valid(death_overlay): death_overlay.queue_free()
	world._update_hud()
	return {"ok":true,"message":"현재 지역 시작 지점에서 부활했습니다"}

func _publish(fields: Dictionary) -> void:
	for key: String in fields:
		var property: String = {"attack":"attack_power"}.get(key,key)
		world.set(property,fields[key])

static func fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}

func open_ui() -> void:
	world.hud.call("_open_window","death523","사망 복구","무료 경험치 복구 기본 2회 · 아이템은 물리 ID 그대로 복원")
	# The original DeathPenalty_All window when the UI pack has it and the
	# rule ZIP is installed; otherwise the panel (with the ZIP install button).
	var controller: Variant = world.hud.get("original_main_ui_controller")
	if is_instance_valid(controller) and controller.has_method("try_open_death_window"):
		var native: Dictionary = controller.try_open_death_window(self)
		world.hud.original_main_ui_status["death_window"] = native
		if native.get("handled",false):
			if world.hud.get("pointer_transfer") != null: world.hud.pointer_transfer.cancel()
			world.hud.workspace.hide()
			if world.hud.has_method("_sync_screen_focus"): world.hud.call("_sync_screen_focus")
			return
		if world.hud.has_method("_report_original_fallback") and str(native.get("code","")) != "source_death_window_rules_not_installed": world.hud.call("_report_original_fallback","사망 복구",native)
	view = preload("res://scripts/death/recovery_ui.gd").new()
	world.hud.workspace.mount(view)
	view.configure(self)

func show_death() -> void:
	if is_instance_valid(death_overlay): death_overlay.queue_free()
	death_overlay = preload("res://scripts/death/death_ui.gd").new()
	world.hud.get_node("Root").add_child(death_overlay)
	death_overlay.configure(self)
