extends RefCounted
## One atomic file owns the roster, shared assets and the selected character.
## The selected character remains a flat legacy-compatible World payload. No
## character/account sidecar can commit half of an item or collection trade.
const KEY := "character_account"
const SCHEMA := "twilight.local-character-account.v2"
const LEGACY_SCHEMA := "twilight.local-character-account.v1"
const MAX_EXACT_ID: int = 9007199254740991
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const MAX_CHARACTERS: int = 13 # TWILIGHT policy, not a Class/AccountSlot row count.
const DEFAULT_PATH := "user://twilight_v20_save.json"
const WRITER = preload("res://scripts/skills/save_writer.gd")
const JOBS := {1:"기사",2:"요정",3:"마법사",4:"다크엘프",5:"투사",7:"광전사",8:"군주",34:"총사",52:"암흑기사",81:"신성검사",94:"사신",111:"뇌신",142:"마검사"}
const SHARED := ["warehouse","card_draw_fusion","equipment_collections","card_collection_policy","growth","card_option_awakening","card_skill_awakening","halphas_star_enchant","next_item_instance_id"]
## Existing gameplay roots cannot be reclassified as unknown shared data.
const PRIVATE_ROOTS := ["death_recovery523","map_id","map_layout_revision","position","level","experience","exp_need","experience_progression_version","hp","max_hp","mp","max_mp","hp_recovery_elapsed","mp_recovery_elapsed","source_item_regen_elapsed","attack","defense","str","dex","con","int","wis","cha","stat_points","gold","inventory","ground_drops","crafting_log","monster_world","original_monster_world","original_position","class_index","job_class","quickslots","ui_preferences","self_mode_enabled","active_skill_buffs","skill_cooldowns","skill_global_cooldown","original_skill_state","original_combat_state","active_item_buffs","item_use_cooldowns","ainhasad_state","equipped_catalog","equipped_items","enhancement_levels","item_instances","native_png_plan_sha256","native_png_review_sha256","oman_png_index_sha256","source_visual_context","character_source_cursor","character_name","source_map84_layouts","source_map84_doors","source_map_migrations","source_item_catalog","source_item_catalog_history","quest_state","monsterbook523","tj_coupons523","protection523","totem_state","growth96","half_elixir523","domination_stone523","routine523","emblem523","inventory_automation","patch523_crafting_usage","patch523_transaction_rng","spell_group_conversion","combination523","title523","equipment523_set_effects","equipped_ammo","ammo_unequipped","weapon_mastery523","expedition523_local","source_shop","source_dungeon_play","source_dungeon523","unconfirmed523"]
const LEGACY_PRIVATE_OPTION := ["native_subslot_identity","native_relic_subslot_identity","native_doll_unlock","native_relic_unlock"]
const PRIVATE_OPTION := ["native_subslot_identity","native_relic_subslot_identity","native_doll_unlock","native_relic_unlock","native_relic_summon_time"]
## Proofs follow warehouse items. Sharing these journals does not share the
## resulting learned skill, permanent stat, quest, cooldown or active buff.
const SHARED_PROOFS := ["source_native_stack_uses","source_native_stack_partitions"]
static var session: Dictionary = {}
var path: String = DEFAULT_PATH
var _hash: String = ""
var _loaded: Dictionary = {}
var _opened: bool = false
## Fault-injection seam. Production always uses the existing atomic writer.
var test_writer: Callable

static func fail(message: String) -> Dictionary:
	return {"ok":false,"problem":message}

static func _whole(value: Variant, minimum: int = 0) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=minimum and value<=9007199254740991

static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value

static func name_problem(value: String) -> String:
	if value != value.strip_edges() or value.length()<2 or value.length()>12: return "캐릭터 이름은 앞뒤 공백 없이 2~12자로 입력하세요."
	for index: int in value.length():
		var code: int=value.unicode_at(index)
		if code<32 or code==127 or code in [47,92]: return "이름에는 제어 문자나 경로 구분자를 사용할 수 없습니다."
	return ""

static func _shared_fields(payload: Dictionary, private_options: Array) -> Dictionary:
	var result: Dictionary = {}
	for key: String in SHARED:
		if payload.has(key): result[key] = _copy(payload[key])
	if result.get("card_option_awakening") is Dictionary:
		for key: String in private_options: result.card_option_awakening.erase(key)
	var proofs: Dictionary = {}
	if payload.get("consumable_state") is Dictionary:
		for key: String in SHARED_PROOFS:
			if payload.consumable_state.has(key): proofs[key] = _copy(payload.consumable_state[key])
	if not proofs.is_empty(): result["consumable_state"] = proofs
	return result

static func _private_fields(payload: Dictionary, private_options: Array) -> Dictionary:
	var result: Dictionary = payload.duplicate(true)
	result.erase(KEY)
	for key: String in SHARED: result.erase(key)
	var options: Dictionary = {}
	if payload.get("card_option_awakening") is Dictionary:
		for key: String in private_options:
			if payload.card_option_awakening.has(key): options[key] = _copy(payload.card_option_awakening[key])
	if not options.is_empty(): result["card_option_awakening"] = options
	if result.get("consumable_state") is Dictionary:
		for key: String in SHARED_PROOFS: result.consumable_state.erase(key)
		if result.consumable_state.is_empty(): result.erase("consumable_state")
	return result

static func shared_fields(payload: Dictionary) -> Dictionary:
	var result: Dictionary = _shared_fields(payload, PRIVATE_OPTION)
	# Retain unknown canonical shared namespaces without reclassifying old
	# unknown flat fields, which remain with their original character.
	var account: Variant = payload.get(KEY,{})
	if account is Dictionary and account.get("schema")==SCHEMA and account.get("shared") is Dictionary:
		for key: String in account.shared:
			if key not in SHARED and key!="consumable_state" and key!=KEY:
				result[key]=_copy(payload.get(key,account.shared[key]))
	return result

static func private_fields(payload: Dictionary) -> Dictionary:
	var result: Dictionary = _private_fields(payload, PRIVATE_OPTION)
	var account: Variant = payload.get(KEY,{})
	if account is Dictionary and account.get("schema")==SCHEMA and account.get("shared") is Dictionary:
		for key: String in account.shared:
			if key not in ["card_option_awakening","consumable_state"]: result.erase(key)
	return result

static func _same(left: Variant, right: Variant) -> bool:
	return JSON.stringify(left,"",true,true)==JSON.stringify(right,"",true,true)

static func _cursor_problem(value: Variant) -> String:
	if not value is Dictionary: return "캐릭터 원본 위치 저장 오류"
	if value.is_empty(): return ""
	if value.size()!=2 or not _whole(value.get("native_land_id")) or not value.get("source_position") is Array or value.source_position.size() not in [0,2]: return "캐릭터 원본 위치 저장 오류"
	for number: Variant in value.source_position:
		if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)) or number<0 or number>=65536: return "캐릭터 원본 좌표 저장 오류"
	return ""

static func _default_cursor() -> Dictionary:
	return {"native_land_id":4,"source_position":[]}

static func _legacy_cursor(data: Dictionary, capture_device: bool) -> Dictionary:
	var existing: Variant=data.get("character_source_cursor",{})
	if not existing is Dictionary or not _cursor_problem(existing).is_empty(): return fail("기존 원본 위치 저장이 손상되었습니다. 원본을 보존합니다.")
	if not existing.is_empty(): return {"ok":true,"cursor":existing.duplicate(true)}
	if capture_device:
		var options: Dictionary=OPTIONS.read()
		if options.get("enabled",false) and options.get("navigation_profile") in [OPTIONS.SOURCE,OPTIONS.GENERIC] and options.get("source_position",[]).size()==2:
			var cursor: Dictionary={"native_land_id":int(options.get("native_land_id",4)),"source_position":options.source_position.duplicate()}
			if _cursor_problem(cursor).is_empty(): return {"ok":true,"cursor":cursor}
	# An explicit empty Aden cursor overrides another character's device point.
	return {"ok":true,"cursor":_default_cursor()}

static func _timer_problem(timer: Variant, identity: String) -> String:
	if not timer is Dictionary or not _whole(timer.get("schema"),1) or int(timer.schema)!=1 or not _whole(timer.get("item_class_id"),1) or int(timer.item_class_id)!=365758 or not _whole(timer.get("slot_index"),1) or int(timer.slot_index)!=11 or not timer.get("identity") is String or timer.identity!=identity or not _whole(timer.get("expires_utc")): return "추가 성물 소환 시간과 캐릭터 선택 식별자가 일치하지 않습니다."
	if timer.has("legacy_deadline_unresolved") and (timer.legacy_deadline_unresolved!=true or int(timer.expires_utc)!=0): return "이전 성물의 미확정 만료 시각 표시가 올바르지 않습니다."
	return ""

static func _reserve_id(value: Variant, current: int) -> Dictionary:
	var uid: String=str(value)
	# Random 128-bit UUIDs are not the legacy numeric allocator namespace.
	if uid.length()>18 or not uid.is_valid_int(): return {"ok":true,"next":current}
	var number: int=int(uid)
	if number<0: return {"ok":true,"next":current}
	if number>=MAX_EXACT_ID: return fail("계정 물리 아이템 ID의 안전한 정수 범위를 초과했습니다.")
	return {"ok":true,"next":maxi(current,number+1)}

static func _allocator(payload: Dictionary, account: Dictionary) -> Dictionary:
	var next: int=1
	for value: Variant in [payload.get("next_item_instance_id",1),account.get("shared",{}).get("next_item_instance_id",1)]:
		if not _whole(value): return fail("계정 물리 아이템 할당자 형식 오류 · 기존 저장 보존")
		next=maxi(next,int(value))
	var states: Array=[payload]
	for record: Dictionary in account.get("characters",[]): states.append(record.state)
	var ids: Array=[]
	for state: Dictionary in states:
		if state.get("item_instances") is Dictionary: ids.append_array(state.item_instances.keys())
		if state.get("ground_drops") is Array:
			for drop: Variant in state.ground_drops:
				if drop is Dictionary and drop.get("physical_item") is Dictionary and drop.physical_item.has("id"): ids.append(drop.physical_item.id)
		var death: Variant=state.get("death_recovery523",{})
		if death is Dictionary and death.get("records") is Array:
			for entry: Variant in death.records:
				if entry is Dictionary and entry.get("item") is Dictionary and entry.item.has("id"): ids.append(entry.item.id)
	var shared_roots: Array=[payload,account.get("shared",{})]
	for shared: Dictionary in shared_roots:
		if shared.get("warehouse") is Dictionary and shared.warehouse.get("instances") is Dictionary: ids.append_array(shared.warehouse.instances.keys())
		if shared.get("equipment_collections") is Dictionary and shared.equipment_collections.get("receipts") is Dictionary: ids.append_array(shared.equipment_collections.receipts.keys())
	for uid: Variant in ids:
		var reserved: Dictionary=_reserve_id(uid,next)
		if not reserved.ok: return reserved
		next=int(reserved.next)
	return {"ok":true,"next":next}

## Trusted owner candidates are sealed once into canonical account state and
## its exact legacy-compatible selected-character projection. Pure: no I/O.
static func seal_payload(payload: Dictionary) -> Dictionary:
	var data: Dictionary=payload.duplicate(true)
	if not data.get(KEY) is Dictionary or data[KEY].get("schema")!=SCHEMA: return fail("계정 v2 저장으로 먼저 안전하게 이전해 주세요.")
	var account: Dictionary=data[KEY]
	if not account.get("characters") is Array or not account.get("selected") is String or not account.get("shared") is Dictionary: return fail("계정 공유·캐릭터 목록 저장 형식 오류")
	for key: String in ["card_option_awakening","consumable_state","source_visual_context"]:
		if data.has(key) and not data[key] is Dictionary: return fail("공유·캐릭터 상태 저장 형식 오류 · 기존 저장 보존")
	for key: String in account.shared:
		if key in PRIVATE_ROOTS: return fail("캐릭터별 상태를 계정 공유 상태로 바꿀 수 없습니다.")
	var selected: Dictionary=selected_record(data)
	if selected.is_empty(): return fail("선택한 캐릭터가 계정에 없습니다.")
	if data.get("job_class")!=JOBS.get(int(selected.get("class_id",0))) or int(data.get("source_visual_context",{}).get("gender_id",-1))!=int(selected.get("gender_id",0)): return fail("캐릭터 생성 시 선택한 직업·성별은 변경할 수 없습니다.")
	var allocation: Dictionary=_allocator(data,account)
	if not allocation.ok: return allocation
	data["next_item_instance_id"]=int(allocation.next)
	var cursor: Dictionary=_legacy_cursor(data,false)
	if not cursor.ok: return cursor
	data["character_source_cursor"]=cursor.cursor
	var shared: Dictionary=shared_fields(data)
	var state: Dictionary=private_fields(data)
	account.shared=shared
	selected.state=state
	var sealed: Dictionary=_project(shared,state)
	sealed[KEY]=account
	var error: String=validate(sealed)
	return {"ok":true,"payload":sealed} if error.is_empty() else fail(error)

static func reseal_migration(payload: Dictionary) -> Dictionary:
	return seal_payload(payload)

static func _project(shared: Dictionary, state: Dictionary) -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	for key: String in shared:
		if key in ["card_option_awakening","consumable_state"]:
			var merged: Dictionary = shared[key].duplicate(true)
			merged.merge(state.get(key,{}),true)
			result[key] = merged
		else: result[key] = _copy(shared[key])
	return result

static func selected_record(payload: Dictionary) -> Dictionary:
	var envelope: Dictionary = payload.get(KEY,{})
	for record: Dictionary in envelope.get("characters",[]):
		if record.get("id")==envelope.get("selected"): return record
	return {}

## Native quantity journals are account-wide, including partly consumed
## stacks still held by an offline character. They must remain provable, but
## are never counted as the current character's inventory or usable items.
static func dormant_items(payload: Dictionary) -> Dictionary:
	var result: Dictionary={}
	var account: Dictionary=payload.get(KEY,{})
	for record: Dictionary in account.get("characters",[]):
		if record.id==account.get("selected"): continue
		result.merge(record.state.get("item_instances",{}),false)
		for entry: Dictionary in record.state.get("ground_drops",[]):
			var physical: Variant=entry.get("physical_item",{})
			if physical is Dictionary and physical.get("data") is Dictionary and physical.get("id") is String: result[physical.id]=physical.data
	return result

static func validate(payload: Dictionary) -> String:
	if not payload.has(KEY): return ""
	var account: Variant = payload[KEY]
	if not account is Dictionary or account.get("schema") not in [SCHEMA,LEGACY_SCHEMA] or not _whole(account.get("revision")) or not account.get("characters") is Array or not account.get("selected") is String: return "캐릭터 계정 저장 형식이 올바르지 않습니다. 원본을 보존합니다."
	var legacy: bool=account.schema==LEGACY_SCHEMA
	var private_options: Array=LEGACY_PRIVATE_OPTION if legacy else PRIVATE_OPTION
	if not legacy and (not account.get("shared") is Dictionary or account.shared.has(KEY)): return "계정 공유 상태 저장 형식 오류"
	if not legacy:
		for key: String in account.shared:
			if key in PRIVATE_ROOTS: return "캐릭터별 상태가 계정 공유 상태에 중복되어 있습니다."
	if account.characters.is_empty() or account.characters.size()>MAX_CHARACTERS: return "캐릭터 슬롯 저장 범위 오류"
	var ids: Dictionary = {}; var names: Dictionary = {}; var physical: Dictionary = {}
	var selected: Dictionary = {}
	for record: Variant in account.characters:
		if not record is Dictionary or not record.get("id") is String or record.id.length()!=32 or not record.id.is_valid_hex_number(false) or ids.has(record.id) or not record.get("name") is String or not name_problem(record.name).is_empty() or names.has(record.name.to_lower()) or not _whole(record.get("class_id"),1) or not JOBS.has(int(record.class_id)) or not _whole(record.get("gender_id")) or int(record.gender_id) not in [0,1,2] or not record.get("initialized") is bool or not record.get("state") is Dictionary: return "캐릭터 목록·이름·직업·성별 저장 오류"
		ids[record.id]=true; names[record.name.to_lower()]=true
		if record.state.has(KEY): return "중첩된 캐릭터 계정 저장 거부"
		for key: String in ["card_option_awakening","consumable_state","source_visual_context","character_source_cursor"]:
			if record.state.has(key) and not record.state[key] is Dictionary: return "캐릭터 개별 상태 저장 형식 오류"
		if record.state.get("consumable_state") is Dictionary:
			for key: String in SHARED_PROOFS:
				if record.state.consumable_state.has(key): return "공유 물리 영수증의 캐릭터별 중복 저장 거부"
		var context: Dictionary=record.state.get("source_visual_context",{})
		if context.get("snapshot")!="base508" or not _whole(context.get("gender_id")) or int(context.gender_id)!=int(record.gender_id): return "캐릭터 성별 식별자 불일치"
		var cursor: Dictionary=record.state.get("character_source_cursor",{})
		var cursor_error: String=_cursor_problem(cursor)
		if not cursor_error.is_empty(): return cursor_error
		if not legacy and cursor.is_empty(): return "캐릭터별 원본 위치가 없어 다른 캐릭터의 설정을 사용할 수 없습니다."
		for key: String in SHARED:
			if key!="card_option_awakening" and record.state.has(key): return "공유 자산의 캐릭터별 중복 저장 거부"
		if record.state.get("card_option_awakening") is Dictionary:
			if not legacy:
				for key: String in ["native_subslot_identity","native_relic_subslot_identity"]:
					if record.state.card_option_awakening.has(key) and not record.state.card_option_awakening[key] is String: return "캐릭터 카드 선택 ID 형식 오류"
			for key: Variant in record.state.card_option_awakening:
				if key not in private_options: return "캐릭터 카드 선택과 공유 보유 분리 오류"
			if not legacy and record.state.card_option_awakening.has("native_relic_summon_time"):
				var timer_error: String=_timer_problem(record.state.card_option_awakening.native_relic_summon_time,str(record.state.card_option_awakening.get("native_relic_subslot_identity","")))
				if not timer_error.is_empty(): return timer_error
		if record.state.get("job_class",JOBS[int(record.class_id)])!=JOBS[int(record.class_id)]: return "캐릭터 직업 식별자 불일치"
		if record.id==account.selected: selected=record
		var items: Variant = record.state.get("item_instances",{})
		if not items is Dictionary: return "캐릭터 장비 개체 저장 오류"
		for uid: Variant in items:
			if physical.has(str(uid)): return "캐릭터 사이에 중복된 물리 아이템 ID가 있습니다."
			physical[str(uid)]=record.id
		var drops: Variant=record.state.get("ground_drops",[])
		if not drops is Array: return "캐릭터 바닥 소유 기록 형식 오류"
		for entry: Variant in drops:
			if not entry is Dictionary: return "캐릭터 바닥 소유 행 오류"
			var floor_item: Variant=entry.get("physical_item",{})
			if not floor_item is Dictionary: return "캐릭터 바닥 개체 형식 오류"
			if floor_item.is_empty(): continue
			if not floor_item.get("id") is String or not floor_item.get("data") is Dictionary or physical.has(floor_item.id): return "바닥·캐릭터 물리 개체 ID 중복 또는 형식 오류"
			physical[floor_item.id]=record.id
	if selected.is_empty(): return "선택한 캐릭터가 계정에 없습니다."
	for key: String in ["card_option_awakening","consumable_state"]:
		if payload.has(key) and not payload[key] is Dictionary: return "공유/캐릭터 상태 분리 형식 오류"
	if legacy:
		if not _same(_private_fields(payload,LEGACY_PRIVATE_OPTION),selected.state): return "선택 캐릭터 상태와 저장 본문이 일치하지 않습니다."
	else:
		var shared: Dictionary=account.shared
		if shared.get("card_option_awakening") is Dictionary:
			for key: String in PRIVATE_OPTION:
				if shared.card_option_awakening.has(key): return "캐릭터 카드 선택·시간이 계정 공유 상태에 중복되어 있습니다."
		if shared.get("consumable_state") is Dictionary:
			for key: String in shared.consumable_state:
				if key not in SHARED_PROOFS: return "개별 소비 상태가 계정 공유 상태에 중복되어 있습니다."
		if not _same(shared_fields(payload),shared) or not _same(private_fields(payload),selected.state): return "계정 공유·캐릭터 상태와 저장 본문이 일치하지 않습니다."
		var flat: Dictionary=payload.duplicate(true);flat.erase(KEY)
		if not _same(flat,_project(shared,selected.state)): return "계정 정본과 선택 캐릭터 호환 저장이 일치하지 않습니다."
		if not _whole(shared.get("next_item_instance_id"),1): return "계정 물리 아이템 할당자 형식 오류"
	var warehouse: Variant=payload.get("warehouse",{})
	if not warehouse is Dictionary or not warehouse.get("instances",{}) is Dictionary or not warehouse.get("stacks",{}) is Dictionary: return "공유 창고 저장 형식 오류"
	for uid: Variant in warehouse.get("instances",{}):
		if physical.has(str(uid)): return "공유 창고와 캐릭터에 동일한 물리 아이템이 중복되어 있습니다."
	return ""

func open() -> Dictionary:
	_loaded.clear(); _opened=false
	if DirAccess.dir_exists_absolute(path): return fail("저장 경로가 파일이 아닙니다.")
	_hash=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	if not _hash.is_empty():
		var file:=FileAccess.open(path,FileAccess.READ)
		if file==null or file.get_length()>128*1024*1024: return fail("저장 파일을 읽을 수 없거나 허용 크기를 초과했습니다.")
		var parser:=JSON.new()
		if parser.parse(file.get_as_text())!=OK or not parser.data is Dictionary: return fail("저장 파일이 손상되었습니다. 기존 파일을 보존합니다.")
		_loaded=parser.data
		var error: String=validate(_loaded)
		if not error.is_empty(): return fail(error)
	elif FileAccess.file_exists(path): return fail("저장 파일 무결성을 확인하지 못했습니다.")
	_opened=true
	var account: Dictionary=_loaded.get(KEY,{})
	var characters: Array=[]
	for entry: Dictionary in account.get("characters",[]):
		var brief: Dictionary=entry.duplicate(true); brief.erase("state")
		brief["level"]=entry.state.get("level",1)
		characters.append(brief)
	return {"ok":true,"legacy":not _loaded.is_empty() and not _loaded.has(KEY),"upgrade":account.get("schema")==LEGACY_SCHEMA,"characters":characters,"selected":account.get("selected",""),"revision":account.get("revision",0)}

func _commit(payload: Dictionary) -> Dictionary:
	if not _opened: return fail("캐릭터 목록을 먼저 다시 불러오세요.")
	if (FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "")!=_hash: return fail("다른 실행에서 저장이 변경되었습니다. 목록을 다시 불러오세요.")
	var error: String=validate(payload)
	if not error.is_empty(): return fail(error)
	var result: Error=test_writer.call(path,payload.duplicate(true)) if test_writer.is_valid() else WRITER.write(path,payload)
	if result!=OK:
		# A lost response after an actual replace must not create a second
		# character on retry. Only the exact intended durable bytes count.
		var expected: String=JSON.stringify(payload,"",true,true).sha256_text()
		var actual: String=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		if actual!=expected:
			if actual!=_hash: _opened=false
			return fail("저장 결과를 확인하지 못했습니다. 목록을 다시 불러오세요. 오류 %d"%result)
	_loaded=payload.duplicate(true); _hash=FileAccess.get_sha256(path)
	return {"ok":true}

func _backup(suffix: String) -> Dictionary:
	if (FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "")!=_hash: return fail("다른 실행에서 저장이 변경되었습니다. 목록을 다시 불러오세요.")
	var backup: String=path+suffix+_hash
	if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(path,backup)!=OK: return fail("기존 저장 백업을 만들지 못했습니다. 이전하지 않습니다.")
	if FileAccess.get_sha256(backup)!=_hash: return fail("기존 저장 백업 무결성 확인 실패. 이전하지 않습니다.")
	return {"ok":true,"backup":backup}

func _write_sealed(data: Dictionary) -> Dictionary:
	var sealed: Dictionary=seal_payload(data)
	return _commit(sealed.payload) if sealed.ok else sealed

func _upgrade_needed() -> bool:
	return _loaded.get(KEY,{}).get("schema")==LEGACY_SCHEMA

func migrate_legacy() -> Dictionary:
	if not _opened: return fail("저장 목록을 먼저 불러오세요.")
	if _loaded.is_empty() or _loaded.has(KEY): return fail("이전할 단일 캐릭터 저장이 없습니다.")
	var legacy_class: int=1
	for id: int in JOBS:
		if JOBS[id]==_loaded.get("job_class","기사"): legacy_class=id
	if not _loaded.get("source_visual_context",{}) is Dictionary: return fail("기존 저장의 성별 구조를 확인해 주세요.")
	if not JOBS.values().has(_loaded.get("job_class","기사")): return fail("기존 저장의 직업을 확인해 주세요. 다른 직업으로 대체하지 않습니다.")
	var gender: int=int(_loaded.get("source_visual_context",{}).get("gender_id",0))
	if gender not in [0,1,2]: return fail("기존 저장의 성별 값을 확인해 주세요.")
	var data: Dictionary=_loaded.duplicate(true)
	var cursor: Dictionary=_legacy_cursor(data,true)
	if not cursor.ok: return cursor
	data["character_source_cursor"]=cursor.cursor
	if not data.has("source_visual_context"): data["source_visual_context"]={"snapshot":"base508","gender_id":gender,"active_card_options":{}}
	if not data.has("job_class"): data["job_class"]=JOBS[legacy_class]
	var preserved_name: Variant=data.get("character_name","")
	var roster_name: String=preserved_name if preserved_name is String and name_problem(preserved_name).is_empty() else "기존캐릭터"
	var id: String=Crypto.new().generate_random_bytes(16).hex_encode()
	data[KEY]={"schema":SCHEMA,"revision":1,"selected":id,"shared":{},"characters":[{"id":id,"name":roster_name,"class_id":legacy_class,"gender_id":gender,"initialized":true,"state":private_fields(data)}]}
	var sealed: Dictionary=seal_payload(data)
	if not sealed.ok: return sealed
	var proof: Dictionary=_backup(".pre-character-account-")
	if not proof.ok: return proof
	sealed.payload[KEY]["legacy_backup"]={"path":proof.backup,"sha256":_hash}
	var result: Dictionary=_commit(sealed.payload)
	if result.ok: result["backup"]=proof.backup
	return result

## v1 is readable only. Upgrade requires a verified backup and retains exact
## historical timer evidence rather than inventing an inactive expiry.
func upgrade_account() -> Dictionary:
	if not _opened or not _upgrade_needed(): return fail("이전할 v1 캐릭터 계정 저장이 없습니다.")
	var error: String=validate(_loaded)
	if not error.is_empty(): return fail(error)
	var data: Dictionary=_loaded.duplicate(true)
	var account: Dictionary=data[KEY]
	var global_options: Dictionary=data.get("card_option_awakening",{})
	var has_timer: bool=global_options.has("native_relic_summon_time")
	var timer: Variant=global_options.get("native_relic_summon_time",{})
	if has_timer:
		if not timer is Dictionary or not timer.get("identity") is String: return fail("이전 추가 성물 시간 저장 형식 오류 · 원본 보존")
		error=_timer_problem(timer,str(timer.identity))
		if not error.is_empty(): return fail(error)
	var unresolved: Array[String]=[]
	for record: Dictionary in account.characters:
		var cursor: Dictionary=_legacy_cursor(record.state,account.characters.size()==1)
		if not cursor.ok: return cursor
		record.state["character_source_cursor"]=cursor.cursor
		if not has_timer: continue # Truly untimed legacy saves stay untimed.
		var options: Dictionary=record.state.get("card_option_awakening",{}).duplicate(true)
		var identity: String=str(options.get("native_relic_subslot_identity",""))
		if record.id==account.selected and timer.identity==identity:
			options["native_relic_summon_time"]=timer.duplicate(true)
		elif not identity.is_empty():
			options["native_relic_summon_time"]={"schema":1,"item_class_id":365758,"slot_index":11,"identity":identity,"expires_utc":0,"legacy_deadline_unresolved":true}
			unresolved.append(record.id)
		if not options.is_empty(): record.state["card_option_awakening"]=options
	if has_timer:
		account["legacy_relic_timer_migration"]={"source_schema":LEGACY_SCHEMA,"source_save_sha256":_hash,"historical_timer":timer.duplicate(true),"unresolved_character_ids":unresolved.duplicate()}
	account.schema=SCHEMA
	account.shared=_shared_fields(data,PRIVATE_OPTION)
	account.revision=int(account.revision)+1
	var selected: Dictionary=selected_record(data)
	data=_project(account.shared,selected.state);data[KEY]=account
	var sealed: Dictionary=seal_payload(data)
	if not sealed.ok: return sealed
	var proof: Dictionary=_backup(".pre-character-account-v2-")
	if not proof.ok: return proof
	sealed.payload[KEY]["v1_backup"]={"path":proof.backup,"sha256":_hash}
	var result: Dictionary=_commit(sealed.payload)
	if result.ok:
		result["backup"]=proof.backup
		result["unresolved_timers"]=unresolved.size()
	return result

func create_character(character_name: String, class_id: int, gender_id: int, catalog: RefCounted) -> Dictionary:
	if not _opened: return fail("캐릭터 목록을 먼저 불러오세요.")
	if _upgrade_needed(): return fail("v1 캐릭터 계정을 먼저 백업 후 v2로 이전해 주세요.")
	if not _loaded.is_empty() and not _loaded.has(KEY): return fail("기존 저장을 먼저 안전하게 이전해 주세요.")
	var error: String=name_problem(character_name)
	if not error.is_empty(): return fail(error)
	var account: Dictionary=_loaded.get(KEY,{"schema":SCHEMA,"revision":0,"selected":"","shared":{},"characters":[]}).duplicate(true)
	if account.characters.size()>=MAX_CHARACTERS: return fail("캐릭터는 계정당 최대 13개입니다.")
	for record: Dictionary in account.characters:
		if record.name.to_lower()==character_name.to_lower(): return fail("이미 사용 중인 캐릭터 이름입니다.")
	if catalog==null or not catalog.get("problem") is String or not str(catalog.get("problem")).is_empty(): return fail("검증된 원본523 직업 정의가 필요합니다.")
	var profile: Dictionary=catalog.call("profile",class_id,gender_id)
	if profile.is_empty() or not JOBS.has(class_id) or profile.get("name")!=JOBS[class_id]: return fail("생성 가능한 직업·성별 원본 조합이 아닙니다.")
	var id: String=Crypto.new().generate_random_bytes(16).hex_encode()
	var state: Dictionary={"job_class":JOBS[class_id],"class_index":0,"source_visual_context":{"snapshot":"base508","gender_id":gender_id,"active_card_options":{}},"character_source_cursor":{"native_land_id":4,"source_position":[]}}
	var stats: Dictionary=profile.get("stats",{})
	for key: String in ["str","dex","con","int","wis","cha"]:
		if not _whole(stats.get(key)): return fail("원본 클래스 초기 능력치가 없습니다.")
		state[key]=int(stats[key])
	account.characters.append({"id":id,"name":character_name,"class_id":class_id,"gender_id":gender_id,"initialized":false,"source_class":profile.get("source",{}).duplicate(true),"state":state})
	account.revision=int(account.revision)+1
	var data: Dictionary=_loaded.duplicate(true)
	if account.selected.is_empty():
		account.selected=id
		data=_project(shared_fields(_loaded),state)
	data[KEY]=account
	var result: Dictionary=_write_sealed(data)
	if result.ok: result["id"]=id
	return result

func select_character(id: String) -> Dictionary:
	if not _opened or not _loaded.has(KEY): return fail("캐릭터 목록을 먼저 불러오세요.")
	if _upgrade_needed(): return fail("v1 캐릭터 계정을 먼저 백업 후 v2로 이전해 주세요.")
	var account: Dictionary=_loaded[KEY].duplicate(true)
	var selected: Dictionary={}
	for record: Dictionary in account.characters:
		if record.id==id: selected=record
	if selected.is_empty(): return fail("선택한 캐릭터가 없습니다.")
	var data: Dictionary=_project(account.shared,selected.state)
	account.selected=id; account.revision=int(account.revision)+1
	data[KEY]=account
	var result: Dictionary=_write_sealed(data)
	if result.ok: session={"path":path,"id":id,"initialized":selected.initialized}
	return result

## Only the once-unknown gender of a migrated character may be filled in.
## Its class, inventory, progression and equipped cards remain untouched.
func complete_legacy_gender(id: String, gender: int, catalog: RefCounted) -> Dictionary:
	if not _opened or not _loaded.has(KEY): return fail("캐릭터 목록을 먼저 불러오세요.")
	if _upgrade_needed(): return fail("v1 캐릭터 계정을 먼저 백업 후 v2로 이전해 주세요.")
	var data: Dictionary=_loaded.duplicate(true)
	var account: Dictionary=data[KEY]
	var found: bool=false
	for record: Dictionary in account.characters:
		if record.id!=id: continue
		if int(record.gender_id)!=0: return fail("이미 선택한 성별은 변경할 수 없습니다.")
		if catalog==null or not str(catalog.get("problem")).is_empty() or catalog.call("profile",int(record.class_id),gender).is_empty(): return fail("원본523에 존재하는 직업·성별 조합을 선택하세요.")
		record.gender_id=gender
		record.state.source_visual_context.gender_id=gender
		if account.selected==id: data.source_visual_context.gender_id=gender
		found=true
	if not found: return fail("선택한 캐릭터가 없습니다.")
	account.revision=int(account.revision)+1
	return _write_sealed(data)

## Called immediately before World's authoritative writer, after every owner
## has validated its staged override. Never mutates disk or live resources.
static func stage_save(path: String, payload: Dictionary) -> Dictionary:
	if session.is_empty() or session.get("path")!=path:
		if payload.has(KEY): return fail("캐릭터 계정 접속 정보가 없습니다. 로비에서 다시 접속하세요.")
		if FileAccess.file_exists(path):
			var saved:=JSON.new()
			if saved.parse(FileAccess.get_file_as_string(path))!=OK or not saved.data is Dictionary: return fail("기존 저장 형식 확인 실패 · 덮어쓰지 않습니다.")
			if saved.data.has(KEY): return fail("계정 저장은 로비에서 선택한 캐릭터만 변경할 수 있습니다.")
		return {"ok":true,"payload":payload}
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK or not parser.data is Dictionary: return fail("캐릭터 계정 저장을 읽지 못했습니다.")
	var prior: Dictionary=parser.data
	var error: String=validate(prior)
	if not error.is_empty(): return fail(error)
	var account: Dictionary=prior.get(KEY,{}).duplicate(true)
	if account.get("schema")!=SCHEMA: return fail("v1 캐릭터 계정을 로비에서 먼저 백업 후 v2로 이전해 주세요.")
	if account.get("selected")!=session.get("id"): return fail("다른 캐릭터로 선택이 변경되었습니다. 다시 접속하세요.")
	var data: Dictionary=payload.duplicate(true)
	data[KEY]=account
	for record: Dictionary in account.characters:
		if record.id==session.id: record.initialized=true
	var staged: Dictionary=seal_payload(data)
	if not staged.ok: return staged
	if not _same(staged.payload[KEY],prior[KEY]): staged.payload[KEY].revision=int(account.revision)+1
	return staged
