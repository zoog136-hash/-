extends RefCounted
## Optional private runtime projection. No original tables or pixels in Git.
## Keep the v1 constants/filename valid for installed packs and existing saves.
const SCHEMA: String="twilight.card-slots523.v1"
const SHA256: String="98cfdb4f604fba7dad2de41cb290aee3d35087e0d4b805d416a372570dc1cc66"
const SCHEMA_V2: String="twilight.card-slots523.v2"
const SHA256_V2: String="35f1844fe70aa8df3a3aea03a9858822715a0dff4941fdb273ae5bab9ea81cd4"
const PATH_V1: String="user://card_slots523/TWILIGHT_card_slots523_runtime_v1.json"
const PATH_V2: String="user://card_slots523/TWILIGHT_card_slots523_runtime_v2.json"
const MAX_PACK_BYTES: int=8*1024*1024
static var problem: String=""
static var loaded_path: String=""
static var loaded_schema: String=""
# Declared before `pack`: static variables initialize in file order.
static var bake_enabled: bool=true
static var loaded_from_bake: bool=false
## Record bake of the per-key relic parts (null: everything resident).
static var _store: RefCounted=null
## Last storage failure of this producer ({} when none): stage and message.
static var store_failure: Dictionary={}
static var pack: Dictionary=_load_pack()
static var new_cards: Dictionary=pack.get("new_cards",{"catalog":{},"option_definitions":[],"skill_cards":{},"source_server_limits":[],"primary_doll_buffs":{},"subslot_buffs":{},"subslot_npc_bindings":{}})
static var options: Dictionary=pack.get("options",{"groups":{},"reviewed_primary_keys":[],"changed_primary_keys":[],"bonuses":{},"types":{},"units":{},"ui_units":{},"type_labels":{}})
static var relic: Dictionary=pack.get("relic",{"cards":{},"option_groups":{},"source_server_limits":[],"unlock_item":{}})
static var relic_combat: Dictionary=pack.get("relic_combat",{"relic_subslot_buffs":{},"invoke_options":[],"invoke_spells":{}})
static var card_acquisition: Dictionary=pack.get("card_acquisition",{})
static var relic_acquisition: Dictionary=pack.get("relic_acquisition",{})

static func schema_for_sha(digest: String) -> String:
	if digest==SHA256:return SCHEMA
	if digest==SHA256_V2:return SCHEMA_V2
	return ""

static func default_path() -> String:
	# A present but invalid v2 must fail closed, never silently remove its
	# reviewed primary correction by falling back to the older v1 projection.
	return PATH_V2 if FileAccess.file_exists(PATH_V2) else PATH_V1

## The projection is a pure function of the installed original tables and
## the scripts that build it (about 10 s and 550 MB of temporary memory with
## the real tables), so this device keeps the result of the same inputs.
##
## Lineage M style: only a small head (new_cards, options, acquisitions, the
## relic invoke option/spell and diagnostics) stays resident. The per-key
## relic parts (cards, slot11 option groups, secondary combat rows, the unlock
## item and the ServerLimit rows grouped by ServerLimitSetID) stay in a record
## bake on this device and are read on demand through a small LRU (accessors
## below). Readers see exactly the values of the former resident `relic` /
## `relic_combat` dictionaries.
const BAKE=preload("res://scripts/resources/current523_bake_cache.gd")
const RECORDS=preload("res://scripts/resources/current523_keyed_records.gd")
const SOURCE_ROWS=preload("res://scripts/resources/current523_definition_rows.gd")
## The former whole-pack bake (one resident value); removed once the record
## bake of the same device is in place.
const BAKE_NAME:="card_slot_relic_input"
const RECORDS_NAME:="card_slot_relic523_records"
const RECORDS_PRODUCER:="card_slots523"
const RECORDS_SCHEMA:="card_slot_relic_input.v1|records.v1"
const SECTION_CARDS:="relic_cards"
const SECTION_GROUPS:="relic_option_groups"
const SECTION_SUBSLOT:="relic_subslot_buffs"
const SECTION_LIMITS:="relic_server_limits"
const SECTION_UNLOCK:="relic_unlock_item"
const UNLOCK_KEY:="value"
## Relic fields kept on storage (relic key -> section).
const RELIC_OFFLOAD:={"cards":SECTION_CARDS,"option_groups":SECTION_GROUPS}

static func _load_pack() -> Dictionary:
	_store=null;store_failure={}
	var verified: String=SOURCE_ROWS.verified_key() if bake_enabled else ""
	var key: String=BAKE.producer_key(RECORDS_NAME,RECORDS_PRODUCER,RECORDS_SCHEMA,verified) if not verified.is_empty() else ""
	var opened: RECORDS.Store=RECORDS.open(RECORDS_NAME,key) if not key.is_empty() else null
	if opened!=null and _valid_head(opened.head):
		_store=opened
		problem=opened.head.problem
		loaded_schema=str(opened.head.candidate.get("schema",""));loaded_path="current523_original_memory"
		loaded_from_bake=true
		return opened.head.candidate
	var input=preload("res://scripts/cards/current523_relic_input.gd").new()
	var candidate: Dictionary=input.build()
	problem=input.problem
	loaded_schema=str(candidate.get("schema",""));loaded_path="current523_original_memory"
	if key.is_empty() or candidate.is_empty():return candidate
	return _adopt(candidate,key)

static func _valid_head(head: Variant) -> bool:
	return head is Dictionary and head.get("candidate") is Dictionary and not head.candidate.is_empty() and head.get("problem") is String

## Stores a freshly built candidate as records and returns the resident head.
## Storage failure: disk-required (Android/iOS) is an explicit failure (no
## pack, cause reported, the next start retries); elsewhere the whole
## candidate stays resident as before.
static func _adopt(candidate: Dictionary,key: String) -> Dictionary:
	var split: Dictionary=split_candidate(candidate)
	# A definition table that failed to reach storage this run may have
	# degraded the build: such a result is used now but never persisted.
	var degraded: bool=not SOURCE_ROWS._store_failures.is_empty()
	var stored: RECORDS.Store=null if degraded else RECORDS.write(RECORDS_NAME,key,{"candidate":split.head,"problem":problem},split.sections)
	if stored!=null:
		_store=stored
		BAKE.clear(BAKE_NAME)
		return split.head
	if BAKE.disk_required():
		store_failure={"stage":"degraded_source" if degraded else "records","message":"원본523 성물 슬롯 기록 파일을 저장하지 못했습니다"}
		problem=str(store_failure.message)+" · 기기 저장 공간을 확인한 뒤 다시 시작하면 다시 시도합니다"
		loaded_schema=""
		return {}
	return candidate

## {head, sections}: the candidate without its per-key relic parts, and those
## parts as keyed sections. Pure (the candidate is not modified).
static func split_candidate(candidate: Dictionary) -> Dictionary:
	var head: Dictionary=candidate.duplicate(false)
	var sections: Dictionary={SECTION_CARDS:{},SECTION_GROUPS:{},SECTION_SUBSLOT:{},SECTION_LIMITS:{},SECTION_UNLOCK:{}}
	var source_relic: Dictionary=candidate.get("relic",{})
	var resident_relic: Dictionary=source_relic.duplicate(false)
	for field: String in RELIC_OFFLOAD:
		if source_relic.get(field) is Dictionary:
			sections[RELIC_OFFLOAD[field]]=source_relic[field]
			resident_relic.erase(field)
	if source_relic.get("source_server_limits") is Array:
		var groups: Dictionary={}
		for row: Variant in source_relic.source_server_limits:
			var set_key: String=_limit_key(row)
			if not groups.has(set_key):groups[set_key]=[]
			(groups[set_key] as Array).append(row)
		sections[SECTION_LIMITS]=groups
		resident_relic.erase("source_server_limits")
	if source_relic.get("unlock_item") is Dictionary:
		sections[SECTION_UNLOCK]={UNLOCK_KEY:source_relic.unlock_item}
		resident_relic.erase("unlock_item")
	head["relic"]=resident_relic
	var source_combat: Dictionary=candidate.get("relic_combat",{})
	var resident_combat: Dictionary=source_combat.duplicate(false)
	if source_combat.get("relic_subslot_buffs") is Dictionary:
		sections[SECTION_SUBSLOT]=source_combat.relic_subslot_buffs
		resident_combat.erase("relic_subslot_buffs")
	if candidate.has("relic_combat"):head["relic_combat"]=resident_combat
	return {"head":head,"sections":sections}

## Group of a ServerLimit row: its integer ServerLimitSetID (the only way the
## readers select rows), "" for a row without one.
static func _limit_key(row: Variant) -> String:
	if not row is Dictionary or typeof(row.get("ServerLimitSetID")) not in [TYPE_INT,TYPE_FLOAT]:return ""
	return str(int(row.ServerLimitSetID))

static func store_result() -> Dictionary:
	if store_failure.is_empty():return {}
	return {"ok":false,"reason":"card_slots_store_failed","stage":str(store_failure.get("stage","")),"message":problem}

## --- Accessors: the same values the former resident dictionaries held. ---
static func _entry(section: String,resident: Dictionary,key: String,fallback: Variant) -> Variant:
	if _store!=null:return _store.value(section,key,fallback)
	return resident.get(key,fallback)

static func relic_card(key: String) -> Dictionary:
	return _entry(SECTION_CARDS,relic.get("cards",{}),key,{})

static func has_relic_card(key: String) -> bool:
	if _store!=null:return _store.has(SECTION_CARDS,key)
	return relic.get("cards",{}).has(key)

static func relic_card_keys() -> PackedStringArray:
	if _store!=null:return _store.section_keys(SECTION_CARDS)
	return PackedStringArray(relic.get("cards",{}).keys())

static func relic_option_group(key: String) -> Dictionary:
	return _entry(SECTION_GROUPS,relic.get("option_groups",{}),key,{})

static func relic_option_group_keys() -> PackedStringArray:
	if _store!=null:return _store.section_keys(SECTION_GROUPS)
	return PackedStringArray(relic.get("option_groups",{}).keys())

static func relic_unlock_item() -> Dictionary:
	if _store!=null:return _store.value(SECTION_UNLOCK,UNLOCK_KEY,{})
	return relic.get("unlock_item",{})

## The original ServerLimit rows whose ServerLimitSetID is `set_id`, in table order.
static func relic_server_limits_for(set_id: int) -> Array:
	if _store!=null:return _store.value(SECTION_LIMITS,str(set_id),[])
	var rows: Array=[]
	for row: Variant in relic.get("source_server_limits",[]):
		if _limit_key(row)==str(set_id):rows.append(row)
	return rows

## The ServerLimitSetID groups present, in first-appearance (table) order.
static func relic_server_limit_set_ids() -> PackedStringArray:
	if _store!=null:return _store.section_keys(SECTION_LIMITS)
	var ids: Dictionary={}
	for row: Variant in relic.get("source_server_limits",[]):ids[_limit_key(row)]=true
	return PackedStringArray(ids.keys())

static func relic_subslot_buff(key: String) -> Dictionary:
	return _entry(SECTION_SUBSLOT,relic_combat.get("relic_subslot_buffs",{}),key,{})

static func relic_subslot_buff_keys() -> PackedStringArray:
	if _store!=null:return _store.section_keys(SECTION_SUBSLOT)
	return PackedStringArray(relic_combat.get("relic_subslot_buffs",{}).keys())

## Test seam: adopt a synthetic candidate exactly as a fresh build (key "" =
## no device bake), refreshing the derived statics.
static func adopt_for_test(candidate: Dictionary,key: String,candidate_problem: String="") -> void:
	_store=null;store_failure={}
	problem=candidate_problem
	loaded_schema=str(candidate.get("schema",""))
	pack=candidate if key.is_empty() or candidate.is_empty() else _adopt(candidate,key)
	_refresh_views()

## Test seam: reopen the record bake of `key` as a later start would.
static func reopen_for_test(key: String) -> bool:
	_store=null
	var opened: RECORDS.Store=RECORDS.open(RECORDS_NAME,key)
	if opened==null or not _valid_head(opened.head):return false
	_store=opened;problem=opened.head.problem;pack=opened.head.candidate
	_refresh_views()
	return true

static func _refresh_views() -> void:
	new_cards=pack.get("new_cards",{"catalog":{},"option_definitions":[],"skill_cards":{},"source_server_limits":[],"primary_doll_buffs":{},"subslot_buffs":{},"subslot_npc_bindings":{}})
	options=pack.get("options",{"groups":{},"reviewed_primary_keys":[],"changed_primary_keys":[],"bonuses":{},"types":{},"units":{},"ui_units":{},"type_labels":{}})
	relic=pack.get("relic",{"cards":{},"option_groups":{},"source_server_limits":[],"unlock_item":{}})
	relic_combat=pack.get("relic_combat",{"relic_subslot_buffs":{},"invoke_options":[],"invoke_spells":{}})
	card_acquisition=pack.get("card_acquisition",{})
	relic_acquisition=pack.get("relic_acquisition",{})

static func _load_legacy_pack_for_reference() -> Dictionary:
	var path: String=OS.get_environment("TWILIGHT_CARD523_SLOT_PACK")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--card523-slot-pack="):path=arg.trim_prefix("--card523-slot-pack=")
	if path.is_empty():path=default_path()
	return _read_pack(path)

static func _read_pack(path: String) -> Dictionary:
	problem="";loaded_path=path;loaded_schema=""
	if not FileAccess.file_exists(path):problem="카드523 슬롯 적용팩 미설치";return {}
	var file: FileAccess=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<=0 or file.get_length()>MAX_PACK_BYTES:
		problem="카드523 슬롯 적용팩 크기·읽기 오류 · 기존 카드 유지";return {}
	var payload: PackedByteArray=file.get_buffer(file.get_length())
	file.close()
	var context: HashingContext=HashingContext.new()
	context.start(HashingContext.HASH_SHA256);context.update(payload)
	var schema: String=schema_for_sha(context.finish().hex_encode())
	if schema.is_empty():problem="카드523 슬롯 적용팩 SHA256 불일치 · 기존 카드 유지";return {}
	var raw: Variant=JSON.parse_string(payload.get_string_from_utf8())
	if not raw is Dictionary or raw.get("schema","")!=schema:problem="카드523 슬롯 적용팩 형식 오류";return {}
	for key: String in ["new_cards","options","relic"]:
		if not raw.get(key) is Dictionary:problem="카드523 슬롯 적용팩 구성 누락";return {}
	if schema==SCHEMA_V2 and not _valid_v2(raw):problem="카드523 v2 슬롯 검증 범위 오류 · 기존 카드 유지";return {}
	loaded_schema=schema
	return raw

static func _valid_v2(raw: Dictionary) -> bool:
	if not raw.get("relic_combat") is Dictionary:return false
	if not raw.get("card_acquisition") is Dictionary or not raw.get("relic_acquisition") is Dictionary:return false
	if not raw.card_acquisition.get("guaranteed_nemesis") is Dictionary or not raw.relic_acquisition.get("box") is Dictionary:return false
	var value: Dictionary=raw.options
	if not value.get("groups") is Dictionary or value.groups.size()!=446:return false
	if not value.get("reviewed_primary_keys") is Array or value.reviewed_primary_keys.size()!=289:return false
	if value.get("changed_primary_keys")!=["2:25002:1"]:return false
	var counts: Dictionary=value.get("counts",{})
	return counts.get("cards")==305 and counts.get("effects")==2392 and counts.get("slot_pairs")==141 and counts.get("compatible_primary_groups")==289

static func installed() -> bool:return not pack.is_empty() and problem.is_empty()
