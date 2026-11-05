extends RefCounted
## Whole-save transaction adapter for the offline game. Consumables and RNG
## become live only after World's existing atomic save writer returns OK.
const UnlockItem=preload("res://scripts/cards/native_doll_unlock_item.gd")
const Subslot=preload("res://scripts/cards/native_doll_subslot.gd")
const RelicSubslot=preload("res://scripts/cards/native_relic_subslot.gd")
const RelicUnlock=preload("res://scripts/cards/native_relic_unlock_item.gd")
const RelicBox=preload("res://scripts/cards/native_relic_reward_box.gd")
const Supply=preload("res://scripts/cards/native_awakening_supply.gd")
const Acquisition=preload("res://scripts/cards/native_card_acquisition.gd")
const Core = preload("res://scripts/cards/option_awakening_service.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const DATA_PATH: String = "res://data/cards/option_awakening_cards.json"
const POLICY_PATH: String = "res://data/cards/option_awakening_policy.json"
const SAVE_KEY: String = "card_option_awakening"
var world
var combat=preload("res://scripts/cards/native_option_combat.gd").new()
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
	combat.configure(self)
	var data: Dictionary = preload("res://scripts/cards/native_option_awakening.gd").adapt(_json(DATA_PATH),world.catalog_db)
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
	_sync_native_context()
	if not problem.is_empty(): return Core.fail("configuration", problem)
	var out: Dictionary = core.view(progress, world.card_draw_fusion.export_state(), int(world.gold), category, target_id)
	if core.native_mode and bool(out.get("ok",false)):
		out.slot_definitions=preload("res://scripts/cards/option_slot_definitions.gd").view(target_id)
	if core.native_mode and out.get("ok",false):
		out.source_status_reference=preload("res://scripts/cards/native_awakening_status.gd").binding(core.definition(category,target_id))
		var collections: Variant=world.get("card_collections")
		if collections!=null and collections.has_method("snapshot"):
			out.collections=[]
			for row: Dictionary in collections.snapshot(category,target_id):
				if not row.requirements.any(func(req: Dictionary) -> bool:return bool(req.get("awakened",false))):continue
				row.bonus_options=[]
				for effect: Dictionary in row.effects:row.bonus_options.append(str(effect.get("label","")))
				out.collections.append(row)
			out.native_collection_rows=true
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
	_sync_native_context()
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
	var tj_before: Dictionary={}
	var override: Dictionary = {SAVE_KEY: next, "card_draw_fusion": result.card_state, "gold": result.gold}
	if is_attempt and world.has_method("_tj_capture_awakening"):
		tj_before=world._tj_capture_awakening(category,target_id,result)
		override["tj_coupons523"]=world.tj_coupons.core.export_state()
	var error: Error = world._save_game(true, override)
	if error != OK:
		if not tj_before.is_empty():world.tj_coupons.core.state=tj_before.duplicate(true)
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
	_sync_native_context()
	var identity: String = Cards.card_id(record_or_id) if record_or_id is Dictionary else str(record_or_id)
	if core.native_mode and not core.owned({"owned":world.card_draw_fusion.owned},category,identity):return false
	return core.awakened(progress, category, identity)

func collections_view() -> Array:
	return core.collection_views(progress, world.card_draw_fusion.export_state()) if world != null else []

func _ensure_bonus_cache() -> void:
	_sync_native_context()
	if world == null or not problem.is_empty():
		_bonus_records.clear()
		_totals.clear()
		_bonus_signature = ""
		return
	var key: String = str(_source_relic_time_active())+":"+str(hash([progress.get(Subslot.FIELD,""),_world_property("level",0),Subslot.unlocked(int(_world_property("level",0)),_world_property("active_skill_buffs",{}),progress),RelicSubslot.unlocked(int(_world_property("level",0)),_world_property("active_skill_buffs",{}),progress)]))+":"+str(progress.get("revision", 0))+":"+str(hash(core.source_server_context))+":"+str(hash(world.card_draw_fusion.owned))
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
		if core.awakened(progress, category, identity) and core.owned(ownership,category,identity):
			_add_bonus(core.definition(category, identity).stats, category + ":" + identity)
	var subslot: Dictionary=subslot_view()
	if bool(subslot.get("active",false)):_add_bonus(subslot.effects.stats,"subslot11:"+str(subslot.identity))
	var relic: Dictionary=relic_subslot_view()
	if bool(relic.get("active",false)):_add_bonus(relic.effects.stats,"relic_subslot11:"+str(relic.identity))
	for collection: Dictionary in core.collection_views(progress, ownership):
		if bool(collection.completed): _add_bonus(collection.stats, "collection:" + str(collection.id))

func _add_bonus(stats: Dictionary, origin: String) -> void:
	var record: Dictionary = {"_option_awakening_bonus": true, "origin": origin}
	for key: String in stats:
		_totals[key] = float(_totals.get(key, 0.0)) + float(stats[key])
		if key == "moveSpeedPct": record["speedBonusPct"] = stats[key]
		elif core.native_mode and key in ["xp","hpPct"]:record[key]=float(stats[key])/100.0
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


func _sync_native_context() -> void:
	if not core.native_mode or world==null:return
	var runtime: Variant=world.get("card_collections")
	core.source_server_context=runtime.source_server_context() if runtime!=null and runtime.has_method("source_server_context") else {}

func native_collection_state() -> Dictionary:
	_sync_native_context()
	if not core.native_mode:return {}
	var result: Dictionary={"source_snapshot":"base508","kind":"BuffCardOptionAwakenGroup.SlotIndex1","bindings":{},"earned":{}}
	for category: String in Core.CATEGORIES:
		result.earned[category]={}
		for identity: String in core.definitions.get(category,{}):
			var row: Dictionary=core.definitions[category][identity]
			if not row.has("native_source"):continue
			var available: Dictionary=core.native_eligibility(category,identity)
			result.bindings[identity]={"group_id":int(row.native_source.group.ID),"card_id":int(row.native_source.card.ID),"eligible":bool(available.ok),"reason":available.get("code","")}
			if bool(core.card_progress(progress,category,identity).awakened) and core.owned({"owned":world.card_draw_fusion.owned},category,identity):result.earned[category][identity]=true
	return result

func _world_property(name_value: String,fallback: Variant) -> Variant:
	if world==null:return fallback
	for property: Dictionary in world.get_property_list():
		if property.name==name_value:return world.get(name_value)
	return fallback
func subslot_view(include_effects: bool=true) -> Dictionary:
	if world==null or not core.native_mode:return {"active":false,"identity":""}
	_sync_native_context()
	var identity: String=str(progress.get(Subslot.FIELD,""))
	var state: Dictionary=Subslot.eligibility(self,identity,int(_world_property("level",0)),_world_property("active_skill_buffs",{}))
	var active: bool=not identity.is_empty() and bool(state.ok) and problem.is_empty()
	return {"identity":identity,"active":active,"eligibility":state,"effects":Subslot.effects(self,identity) if active and include_effects else {},"unlocked":Subslot.unlocked(int(_world_property("level",0)),_world_property("active_skill_buffs",{}),progress)}
func select_subslot(identity: String) -> Dictionary:
	_sync_native_context()
	if _busy:return Core.fail("busy","이전 거래 처리 중")
	if save_blocked or not problem.is_empty() or not core.native_mode:return Core.fail("save_blocked","추가 인형 저장 보호 중")
	var available: Dictionary=Subslot.eligibility(self,identity,int(_world_property("level",0)),_world_property("active_skill_buffs",{}))
	if not available.ok:return available
	if str(progress.get(Subslot.FIELD,""))==identity:return {"ok":true,"unchanged":true}
	_busy=true
	var next: Dictionary=export_state();next[Subslot.FIELD]=identity;next.revision=int(next.revision)+1
	if not core.validate_state(next,{"owned":world.card_draw_fusion.owned}).is_empty():_busy=false;return Core.fail("invalid_state","추가 인형 저장 검증 실패")
	var error: Error=world._save_game(true,{SAVE_KEY:next})
	if error!=OK:_busy=false;return Core.fail("save_failed","저장 실패 · 기존 추가 인형 보존")
	progress=next;_bonus_signature="";world.set("equipment_records_dirty",true)
	_busy=false
	return {"ok":true,"snapshot":subslot_view()}

func use_native_unlock_item(item_name: String) -> Dictionary:
	if item_name!=str(UnlockItem.record().name):return {"handled":false}
	if _busy:return {"handled":true,"ok":false,"code":"busy","error":"이전 아이템 사용 처리 중"}
	if save_blocked or not problem.is_empty() or not core.native_mode:return {"handled":true,"ok":false,"code":"save_blocked","error":"해금 저장 보호 중"}
	_busy=true
	var result: Dictionary=UnlockItem.prepare(export_state(),world.inventory,world.item_instances,int(_world_property("level",0)))
	result.handled=true
	if not result.ok:_busy=false;return result
	var error: String=core.validate_state(result.state,{"owned":world.card_draw_fusion.owned})
	if not error.is_empty():_busy=false;return {"handled":true,"ok":false,"code":"invalid_state","error":error}
	var saved: Error=world._save_game(true,{SAVE_KEY:result.state,"inventory":result.inventory,"item_instances":result.item_instances})
	if saved!=OK:_busy=false;return {"handled":true,"ok":false,"code":"save_failed","error":"저장 실패 · 해금 아이템·기존 해금 상태 보존"}
	world.inventory=result.inventory;world.item_instances=result.item_instances;progress=result.state
	_bonus_signature="";world.set("equipment_records_dirty",true);_busy=false
	result.erase("state");result.erase("inventory");result.erase("item_instances")
	return result

func active_source_status_references() -> Dictionary:
	var result: Dictionary={}
	var active: Dictionary=combat.active()
	for identity: String in active:
		var row: Dictionary=active[identity]
		var reference: Dictionary=preload("res://scripts/cards/native_awakening_status.gd").binding(row)
		if reference.ok:result[identity]=reference
	return result

func relic_subslot_view(include_effects: bool=true) -> Dictionary:
	if world==null or not core.native_mode:return {"active":false,"identity":"","unlocked":false}
	_sync_native_context()
	var identity: String=str(progress.get(RelicSubslot.FIELD,""))
	var state: Dictionary=RelicSubslot.eligibility(self,identity,int(_world_property("level",0)),_world_property("active_skill_buffs",{}))
	var active: bool=not identity.is_empty() and bool(state.ok) and problem.is_empty() and not save_blocked and _source_relic_time_active()
	return {"identity":identity,"active":active,"eligibility":state,"effects":RelicSubslot.effects(self,identity) if active and include_effects else {},"unlocked":RelicSubslot.unlocked(int(_world_property("level",0)),_world_property("active_skill_buffs",{}),progress)}

func select_relic_subslot(identity: String) -> Dictionary:
	_sync_native_context()
	if _busy:return Core.fail("busy","이전 거래 처리 중")
	if save_blocked or not problem.is_empty() or not core.native_mode:return Core.fail("save_blocked","추가 성물 저장 보호 중")
	var available: Dictionary=RelicSubslot.eligibility(self,identity,int(_world_property("level",0)),_world_property("active_skill_buffs",{}))
	if not available.ok:return available
	if str(progress.get(RelicSubslot.FIELD,""))==identity:return {"ok":true,"unchanged":true}
	_busy=true
	var next: Dictionary=export_state();next[RelicSubslot.FIELD]=identity;next.revision=int(next.revision)+1
	if preload("res://scripts/cards/patch523_slot_data.gd").loaded_schema=="twilight.card-slots523.v2":
		var timer: Dictionary={"schema":1,"item_class_id":365758,"identity":identity,"slot_index":11,"expires_utc":0}
		if not identity.is_empty():
			var scroll: String=_available_source_scroll()
			var spec: Dictionary=_source_scroll_spec()
			if not scroll.is_empty() and not spec.is_empty():
				if world.has_method("_patch523_item_allowed") and not world._patch523_item_allowed():_busy=false;return Core.fail("item_condition","현재 아이템 사용 조건에서 소환할 수 없습니다")
				timer.expires_utc=int(Time.get_unix_time_from_system())+int(spec.seconds)
				timer.source_duration_seconds=int(spec.seconds);timer.source_auto_overlap_ms=int(spec.overlap_ms);timer.source_infinite_amount=true
		next[RELIC_SUMMON_TIME]=timer
	if not core.validate_state(next,{"owned":world.card_draw_fusion.owned}).is_empty():_busy=false;return Core.fail("invalid_state","추가 성물 저장 검증 실패")
	var staged: Dictionary={SAVE_KEY:next,"inventory":world.inventory.duplicate(true),"item_instances":world.item_instances.duplicate(true)}
	if world.has_method("_option_awakening_vitals_for_state"):staged.merge(world._option_awakening_vitals_for_state(next))
	var error: Error=world._save_game(true,staged)
	if error!=OK:_busy=false;return Core.fail("save_failed","저장 실패 · 기존 추가 성물 보존")
	progress=next;_bonus_signature="";world.set("equipment_records_dirty",true);_busy=false
	for key: String in ["hp","mp"]:
		if staged.has(key):world.set(key,staged[key])
	return {"ok":true,"snapshot":relic_subslot_view()}

func _source_item_locks(item_name: String) -> Dictionary:
	var locks: Dictionary={}
	if not world.has_method("_item_locked"):return locks
	if world._item_locked(item_name):locks[item_name]=true
	for id: String in world.item_instances:
		if world._item_locked(item_name,id):locks[id]=true
	return locks

func nemesis_craft_view() -> Dictionary:
	var available: int=Supply.available(world,3252)
	if Supply.record(3252).is_empty():available=Acquisition.available_coins(world.inventory,world.item_instances,_source_item_locks(str(Acquisition.record(3252).get("name",""))))
	var allowed: bool=Acquisition.rules_valid() and Acquisition.time_available() and core.catalog["마법인형"].has(Acquisition.CARD) and not save_blocked and problem.is_empty()
	return {"available_coins":available,"required_coins":Acquisition.REQUIRED,"can_craft":allowed and available>=Acquisition.REQUIRED,"save_blocked":save_blocked,"conditions_verified":allowed}

func craft_nemesis() -> Dictionary:
	if not Supply.record(3252).is_empty():return _craft_native_nemesis()
	if _busy:return Core.fail("busy","이전 거래 처리 중")
	if save_blocked or not problem.is_empty() or not core.catalog["마법인형"].has(Acquisition.CARD):return Core.fail("save_blocked","카드 제작 저장 보호 중")
	_busy=true
	var result: Dictionary=Acquisition.prepare_craft(world.inventory,world.item_instances,int(world.next_item_instance_id),_source_item_locks(str(Acquisition.record(3252).name)))
	if not result.ok:_busy=false;return result
	if world._save_game(true,{"inventory":result.inventory,"item_instances":result.item_instances,"next_item_instance_id":result.next_item_instance_id})!=OK:_busy=false;return Core.fail("save_failed","저장 실패 · 제작 재료와 결과 보존")
	world.inventory=result.inventory;world.item_instances=result.item_instances;world.next_item_instance_id=int(result.next_item_instance_id);_busy=false
	result.erase("inventory");result.erase("item_instances");result.erase("next_item_instance_id")
	return result

func use_nemesis_ticket(item_name: String,selected_instance: String="") -> Dictionary:
	if item_name!=str(Acquisition.record().get("name","")):return {"handled":false}
	if _busy:return {"handled":true,"ok":false,"error":"이전 거래 처리 중"}
	if save_blocked or not problem.is_empty() or not core.catalog["마법인형"].has(Acquisition.CARD):return {"handled":true,"ok":false,"error":"카드 획득 저장 보호 중"}
	_busy=true
	var result: Dictionary=Acquisition.prepare_ticket(world.inventory,world.item_instances,world.card_draw_fusion.export_state(),selected_instance,_source_item_locks(item_name))
	result.handled=true
	if not result.ok:_busy=false;return result
	if world._save_game(true,{"inventory":result.inventory,"item_instances":result.item_instances,"card_draw_fusion":result.card_state})!=OK:_busy=false;return {"handled":true,"ok":false,"code":"save_failed","error":"저장 실패 · 카드권과 보유 카드 보존"}
	world.inventory=result.inventory;world.item_instances=result.item_instances;world.card_draw_fusion.import_state(result.card_state);world.set("equipment_records_dirty",true);_bonus_signature="";_busy=false
	result.erase("inventory");result.erase("item_instances");result.erase("card_state")
	return result

func use_relic_reward_box(item_name: String,selected_instance: String="") -> Dictionary:
	if item_name!=str(RelicBox.record().get("name","")):return {"handled":false}
	if _busy:return {"handled":true,"ok":false,"code":"busy","error":"이전 거래 처리 중"}
	if save_blocked or not problem.is_empty():return {"handled":true,"ok":false,"code":"save_blocked","error":"각성 저장 보호 중 · 상자 보존"}
	if world.has_method("_item_locked") and world._item_locked(item_name):return {"handled":true,"ok":false,"code":"locked","error":"잠긴 상자는 사용할 수 없습니다"}
	var locks: Dictionary={}
	if world.has_method("_item_locked"):
		for id: String in world.item_instances:
			if world._item_locked(item_name,id):locks[id]=true
	_busy=true
	var result: Dictionary=RelicBox.prepare(world.inventory,world.item_instances,int(world.next_item_instance_id),selected_instance,locks)
	result.handled=true
	if not result.ok:_busy=false;return result
	var saved: Error=world._save_game(true,{"inventory":result.inventory,"item_instances":result.item_instances,"next_item_instance_id":result.next_item_instance_id})
	if saved!=OK:_busy=false;return {"handled":true,"ok":false,"code":"save_failed","error":"저장 실패 · 상자와 내용물 보존"}
	world.inventory=result.inventory;world.item_instances=result.item_instances;world.next_item_instance_id=int(result.next_item_instance_id)
	_busy=false
	result.erase("inventory");result.erase("item_instances");result.erase("next_item_instance_id")
	return result

func use_relic_unlock_item(item_name: String,selected_instance: String="") -> Dictionary:
	if item_name.is_empty() or item_name!=str(RelicUnlock.record().get("name","")):return {"handled":false}
	if _busy:return {"handled":true,"ok":false,"code":"busy","error":"이전 아이템 사용 처리 중"}
	if save_blocked or not problem.is_empty() or not core.native_mode:return {"handled":true,"ok":false,"code":"save_blocked","error":"해금 저장 보호 중"}
	if world.has_method("_item_locked") and world._item_locked(item_name):return {"handled":true,"ok":false,"code":"locked","error":"잠긴 해금 아이템은 사용할 수 없습니다"}
	var locks: Dictionary={}
	if world.has_method("_item_locked"):
		for key: String in world.item_instances:
			if world._item_locked(item_name,key):locks[key]=true
	if not selected_instance.is_empty():
		for key: String in world.item_instances:
			if key!=selected_instance:locks[key]=true
	_busy=true
	var result: Dictionary=RelicUnlock.prepare(export_state(),world.inventory,world.item_instances,int(_world_property("level",0)),locks)
	result.handled=true
	if not result.ok:_busy=false;return result
	var error: String=core.validate_state(result.state,{"owned":world.card_draw_fusion.owned})
	if not error.is_empty():_busy=false;return {"handled":true,"ok":false,"code":"invalid_state","error":error}
	var saved: Error=world._save_game(true,{SAVE_KEY:result.state,"inventory":result.inventory,"item_instances":result.item_instances})
	if saved!=OK:_busy=false;return {"handled":true,"ok":false,"code":"save_failed","error":"저장 실패 · 해금 아이템·기존 성물 해금 상태 보존"}
	world.inventory=result.inventory;world.item_instances=result.item_instances;progress=result.state
	_bonus_signature="";world.set("equipment_records_dirty",true);_busy=false
	result.erase("state");result.erase("inventory");result.erase("item_instances")
	return result

func source_visual_awakened(category: String,record: Dictionary) -> bool:
	# Preserve PR217's native aura API using this source-aware accepted ledger.
	# The canonical core guards source identity, ownership and server conditions.
	if world==null or record.get("source","")!="lineagem_base508":return false
	var identity: String=Cards.card_id(record)
	var canonical: Dictionary=core.catalog.get(category,{}).get(identity,{})
	if canonical.is_empty() or canonical.get("sourceId","")!=record.get("sourceId",""):return false
	if not preload("res://scripts/cards/native_awakening_status.gd").binding(core.definition(category,identity)).ok:return false
	return is_awakened(category,identity)

func source_subslot_visual_awakened(record: Dictionary) -> bool:
	if not source_visual_awakened("마법인형",record):return false
	var identity: String=Cards.card_id(record)
	if str(progress.get(Subslot.FIELD,""))!=identity:return false
	var condition: Dictionary=Subslot.eligibility(self,identity,int(_world_property("level",0)),_world_property("active_skill_buffs",{}))
	if not condition.ok:return false
	var reference: Dictionary=preload("res://scripts/cards/native_awakening_status.gd").binding(core.definition("마법인형",identity))
	return reference.ok and Subslot.status_available(self,identity,int(reference.status_effect_id))

func source_relic_subslot_visual_awakened(record: Dictionary) -> bool:
	if not source_visual_awakened("성물",record):return false
	var identity: String=Cards.card_id(record)
	if str(progress.get(RelicSubslot.FIELD,""))!=identity:return false
	if not RelicSubslot.eligibility(self,identity,int(_world_property("level",0)),_world_property("active_skill_buffs",{})).ok:return false
	var reference: Dictionary=preload("res://scripts/cards/native_awakening_status.gd").binding(core.definition("성물",identity))
	return reference.ok and RelicSubslot.status_available(self,identity,int(reference.status_effect_id))

func _craft_native_nemesis() -> Dictionary:
	if _busy or save_blocked or not problem.is_empty():return Core.fail("save_blocked","각성 저장 보호 중")
	if not Acquisition.rules_valid() or not Acquisition.time_available() or not core.catalog["마법인형"].has(Acquisition.CARD):return Core.fail("source_rules","원본 제작 규칙·카드 연결 확인 필요")
	_busy=true
	var paid: Dictionary=Supply.prepare_debit(world,3252,Acquisition.REQUIRED)
	if not paid.get("ok",false):_busy=false;return Core.fail("source_currency",str(paid.get("error","원본 제작 코인 부족")))
	var ticket: Dictionary=Supply.record(370562)
	var staged: Dictionary=Supply.stage_grant(ticket,1,paid.overrides.item_instances,{"kind":"card_craft","recipe_id":Acquisition.RECIPE,"inputs":paid.consumed})
	if ticket.is_empty() or not staged.get("ok",false):_busy=false;return Core.fail("source_rules","원본 카드권 정의 확인 필요")
	var next: Dictionary=paid.overrides;next.item_instances=staged.item_instances
	next.inventory[ticket.name]=int(next.inventory.get(ticket.name,0))+1
	if world._save_game(true,next)!=OK:_busy=false;return Core.fail("save_failed","저장 실패 · 제작 재료·결과 보존")
	Supply.publish(world,next);_busy=false
	return {"ok":true,"ticket_instance_id":staged.id,"consumed_source_coins":Acquisition.REQUIRED}

func use_source_awakening_item(item_name: String,selected: String="") -> Dictionary:
	var physical_id: String=selected;var item_id: int=0
	for uid: String in world.item_instances:
		if not physical_id.is_empty() and uid!=physical_id:continue
		var physical: Dictionary=world.item_instances[uid]
		if physical.get("name")!=item_name:continue
		var candidate: int=int(physical.get("record",{}).get("source_item_class_id",0))
		if candidate not in [346921,365748,365758,370562]:continue
		if not Supply.proof(world,uid,candidate).get("ok",false):continue
		physical_id=uid;item_id=candidate;break
	if item_id==0:
		var named: Dictionary=world._find_catalog_item_record(item_name)
		if not Supply.definition(int(named.get("source_item_class_id",0))).is_empty() and int(named.get("source_item_class_id",0)) in [346921,365748,365758,370562]:return {"handled":true,"ok":false,"error":"원본 소지·지급 증명이 필요합니다 · 아이템 보존"}
		return {"handled":false}
	if _busy or save_blocked or not problem.is_empty():return {"handled":true,"ok":false,"error":"각성 저장 보호 중 · 원본 보유 보존"}
	if world.has_method("_patch523_item_allowed") and not world._patch523_item_allowed():return {"handled":true,"ok":false,"error":"현재 원본 아이템 사용 조건을 만족하지 않습니다"}
	if item_id!=365758 and Supply.record(item_id).is_empty():return {"handled":false}
	if item_id==365758:return _use_source_relic_scroll(physical_id)
	if item_id==346921 and not RelicBox.rules_valid():return {"handled":true,"ok":false,"error":"상자 원본 연결 확인 필요"}
	if item_id==365748 and (not RelicUnlock.source_rules_valid() or RelicUnlock.unlocked(progress)):return {"handled":true,"ok":false,"error":"원본 해금 조건 확인 필요 또는 이미 해금됨 · 아이템 보존"}
	if item_id==370562 and (not Acquisition.rules_valid() or not core.catalog["마법인형"].has(Acquisition.CARD)):return {"handled":true,"ok":false,"error":"원본 카드권 연결 확인 필요"}
	_busy=true
	var paid: Dictionary=Supply.prepare_debit(world,item_id,1,physical_id)
	if not paid.get("ok",false):_busy=false;return {"handled":true,"ok":false,"error":paid.get("error","원본 소비 증명 확인 필요")}
	var staged: Dictionary=paid.overrides;var next: Dictionary=export_state();var cards: Dictionary=world.card_draw_fusion.export_state()
	if item_id==346921:
		for id: int in [365748,365758]:
			var reward: Dictionary=Supply.record(id)
			var awarded: Dictionary=Supply.stage_grant(reward,1,staged.item_instances,{"kind":"source_box","source_item_id":346921,"lucky_bag_id":81612,"consumed":paid.consumed})
			if reward.is_empty() or not awarded.get("ok",false):_busy=false;return {"handled":true,"ok":false,"error":"상자 출력 원본 정의 확인 필요 · 상자 보존"}
			staged.item_instances=awarded.item_instances;staged.inventory[reward.name]=int(staged.inventory.get(reward.name,0))+1
	elif item_id==365748:
		next[RelicUnlock.FIELD]=RelicUnlock.marker();next.revision=int(next.revision)+1;next[RELIC_SUMMON_TIME]={"schema":1,"item_class_id":365758,"identity":"","slot_index":11,"expires_utc":0};staged[SAVE_KEY]=next
	elif item_id==370562:
		if cards.owned["마법인형"].get(Acquisition.CARD,false)==true:
			var amount: Variant=cards.spare["마법인형"].get(Acquisition.CARD,0)
			if not Supply.integer(amount) or int(amount)>=1000000:_busy=false;return {"handled":true,"ok":false,"error":"중복 카드 수량 확인 필요 · 카드권 보존"}
			cards.spare["마법인형"][Acquisition.CARD]=int(amount)+1
		else:cards.owned["마법인형"][Acquisition.CARD]=true
		staged.card_draw_fusion=cards
	if world._save_game(true,staged)!=OK:_busy=false;return {"handled":true,"ok":false,"error":"저장 실패 · 원본 아이템·카드·해금·지급 영수증 보존"}
	Supply.publish(world,staged)
	if staged.has(SAVE_KEY):progress=next;_bonus_signature="";world.set("equipment_records_dirty",true)
	if item_id==370562:world.card_draw_fusion.import_state(cards)
	_busy=false
	return {"handled":true,"ok":true,"item_class_id":item_id,"message":"원본 상자 보상 각 1개 획득" if item_id==346921 else ("추가 성물 해금 완료" if item_id==365748 else "네메시스 카드 1장 획득")}

const RELIC_SUMMON_TIME: String="native_relic_summon_time"
var _last_timed_relic_active: int=-1
func _source_relic_time_active() -> bool:
	if not progress.has(RELIC_SUMMON_TIME):return true # Preserve pre-existing untimed saves.
	var timer: Variant=progress[RELIC_SUMMON_TIME]
	return timer is Dictionary and timer.get("schema")==1 and timer.get("item_class_id")==365758 and timer.get("identity")==progress.get(RelicSubslot.FIELD,"") and Supply.integer(timer.get("expires_utc")) and int(timer.expires_utc)>int(Time.get_unix_time_from_system())
func refresh_timed_relic() -> void:
	var active: int=int(_source_relic_time_active())
	if active==_last_timed_relic_active:return
	_last_timed_relic_active=active;_bonus_signature="";world._invalidate_equipment_static()
	if not bool(active):
		world.hp=mini(world.hp,world._effective_max_hp());world.mp=mini(world.mp,world._effective_max_mp())
		world._request_deferred_save()
		world.call_deferred("_update_hud")
func _source_scroll_spec() -> Dictionary:
	var source: Dictionary=RelicBox.definition(365758)
	if source.is_empty() or source.get("item",{}).get("raw",{}).get("TestItem",true):return {}
	var values: Dictionary={}
	for entry: Dictionary in source.get("effects",[]):
		if entry.link.raw.IsPossession or int(entry.bonus.raw.BonusApplicationTypeID)!=0 or int(entry.bonus.raw.BonusApplicationTargetID)!=0:return {}
		values[str(entry.type.raw.Name)]=int(entry.bonus.raw.Value)
	if values!={"BuffDuration":1800,"BuffDeckID":98,"AutoBuffOverlapDuration":5000,"PresetConsumeItem":1,"InfiniteAmount":1,"BuffCardSummonSlotIndex":11}:return {}
	return {"seconds":int(values.BuffDuration),"overlap_ms":int(values.AutoBuffOverlapDuration)}
func _use_source_relic_scroll(physical_id: String) -> Dictionary:
	var owned: Dictionary=Supply.proof(world,physical_id,365758)
	if Supply.available(world,365758)<1 or not owned.get("ok",false) or world._item_locked(str(owned.get("inventory_key","")),physical_id) or world._item_locked(str(owned.get("inventory_key",""))):return {"handled":true,"ok":false,"error":"소환 주문서 소지·잠금 확인 필요"}
	var spec: Dictionary=_source_scroll_spec()
	var identity: String=str(progress.get(RelicSubslot.FIELD,""));_sync_native_context()
	var allowed: Dictionary=RelicSubslot.eligibility(self,identity,int(_world_property("level",0)),_world_property("active_skill_buffs",{}))
	if identity.is_empty() or spec.is_empty() or not allowed.get("ok",false):return {"handled":true,"ok":false,"error":"추가 성물을 먼저 선택하고 원본 소환 조건을 확인하세요"}
	var next: Dictionary=export_state()
	next.revision=int(next.revision)+1
	next[RELIC_SUMMON_TIME]={"schema":1,"item_class_id":365758,"identity":identity,"slot_index":11,"expires_utc":int(Time.get_unix_time_from_system())+int(spec.seconds),"source_duration_seconds":int(spec.seconds),"source_auto_overlap_ms":int(spec.overlap_ms),"source_infinite_amount":true}
	# InfiniteAmount=1 retains the exact owned scroll; no synthetic item debit.
	var staged: Dictionary={SAVE_KEY:next,"inventory":world.inventory.duplicate(true),"item_instances":world.item_instances.duplicate(true)}
	if world._save_game(true,staged)!=OK:return {"handled":true,"ok":false,"error":"저장 실패 · 소환 시간·주문서 보존"}
	progress=next;_bonus_signature="";_last_timed_relic_active=-1;world._invalidate_equipment_static()
	return {"handled":true,"ok":true,"item_class_id":365758,"message":"추가 성물 30분 소환 · 원본 무제한 주문서 보존"}

func _available_source_scroll() -> String:
	if Supply.available(world,365758)<1:return ""
	for uid: String in world.item_instances:
		var owned: Dictionary=Supply.proof(world,uid,365758)
		if owned.get("ok",false) and not world._item_locked(str(owned.inventory_key),uid) and not world._item_locked(str(owned.inventory_key)):return uid
	return ""

func source_scroll_supported(item_name: String) -> bool:
	if item_name.is_empty() or _source_scroll_spec().is_empty():return false
	var uid: String=_available_source_scroll()
	return not uid.is_empty() and str(world.item_instances[uid].name)==item_name

func source_scroll_auto_ready(item_name: String) -> bool:
	if not source_scroll_supported(item_name) or str(progress.get(RelicSubslot.FIELD,"")).is_empty():return false
	var timer: Variant=progress.get(RELIC_SUMMON_TIME)
	if not timer is Dictionary:return false # Preserve old untimed saves.
	var spec: Dictionary=_source_scroll_spec()
	return Supply.integer(timer.get("expires_utc")) and float(timer.expires_utc)-Time.get_unix_time_from_system()<=float(spec.overlap_ms)/1000.0
