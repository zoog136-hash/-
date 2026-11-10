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
const BAKE=preload("res://scripts/resources/current523_bake_cache.gd")
const BAKE_NAME:="card_slot_relic_input"
const BAKE_CODE: Array[String]=["res://scripts/cards/patch523_slot_data.gd","res://scripts/cards/current523_relic_input.gd",
	"res://scripts/cards/current523_card_identity.gd","res://scripts/cards/option_slot_definitions.gd",
	"res://scripts/cards/current523_card_acquisition_input.gd","res://scripts/cards/current523_relic_acquisition_input.gd",
	"res://scripts/resources/current523_definition_rows.gd"]
static func _load_pack() -> Dictionary:
	var source_sha: String=str(preload("res://scripts/resources/current523_definition_rows.gd").identity().get("source_sha256",""))
	var key: String=BAKE.key(["card_slot_relic_input.v1",source_sha,BAKE.code_key(BAKE_CODE)]) if bake_enabled and not source_sha.is_empty() else ""
	var baked: Variant=BAKE.read(BAKE_NAME,key) if not key.is_empty() else null
	if baked is Dictionary and baked.get("candidate") is Dictionary and not baked.candidate.is_empty() and baked.get("problem") is String:
		problem=baked.problem
		loaded_schema=str(baked.candidate.get("schema",""));loaded_path="current523_original_memory"
		loaded_from_bake=true
		return baked.candidate
	var input=preload("res://scripts/cards/current523_relic_input.gd").new()
	var candidate: Dictionary=input.build()
	problem=input.problem
	if not key.is_empty() and not candidate.is_empty(): BAKE.write(BAKE_NAME,key,{"candidate":candidate,"problem":problem})
	loaded_schema=str(candidate.get("schema",""));loaded_path="current523_original_memory"
	return candidate

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
