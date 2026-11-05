extends RefCounted
## Optional private runtime projection. No original tables or pixels in Git.
const SCHEMA: String="twilight.card-slots523.v1"
const SHA256: String="98cfdb4f604fba7dad2de41cb290aee3d35087e0d4b805d416a372570dc1cc66"
static var problem: String=""
static var pack: Dictionary=_load_pack()
static var new_cards: Dictionary=pack.get("new_cards",{"catalog":{},"option_definitions":[],"skill_cards":{},"source_server_limits":[],"primary_doll_buffs":{},"subslot_buffs":{},"subslot_npc_bindings":{}})
static var options: Dictionary=pack.get("options",{"groups":{},"reviewed_primary_keys":[],"changed_primary_keys":[],"bonuses":{},"types":{},"units":{},"ui_units":{},"type_labels":{}})
static var relic: Dictionary=pack.get("relic",{"cards":{},"option_groups":{},"source_server_limits":[],"unlock_item":{}})
static var relic_combat: Dictionary=pack.get("relic_combat",{"relic_subslot_buffs":{},"invoke_options":[],"invoke_spells":{}})
static var card_acquisition: Dictionary=pack.get("card_acquisition",{})
static var relic_acquisition: Dictionary=pack.get("relic_acquisition",{})

static func _load_pack() -> Dictionary:
	# UNVERIFIED: installed() is the existing definition-availability ABI, not
	# a claim that a new art/runtime pack has been installed. Legacy inputs are
	# retained below and are never used as a final-input or missing-input fallback.
	var input=preload("res://scripts/cards/current523_relic_input.gd").new()
	var candidate: Dictionary=input.build()
	problem=input.problem
	return candidate

static func _load_legacy_pack_for_reference() -> Dictionary:
	var path: String=OS.get_environment("TWILIGHT_CARD523_SLOT_PACK")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--card523-slot-pack="):path=arg.trim_prefix("--card523-slot-pack=")
	if path.is_empty():path="user://card_slots523/TWILIGHT_card_slots523_runtime_v1.json"
	if not FileAccess.file_exists(path):problem="카드523 슬롯 적용팩 미설치";return {}
	if FileAccess.get_sha256(path)!=SHA256:problem="카드523 슬롯 적용팩 SHA256 불일치 · 기존 카드 유지";return {}
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary or raw.get("schema","")!=SCHEMA:problem="카드523 슬롯 적용팩 형식 오류";return {}
	for key: String in ["new_cards","options","relic"]:
		if not raw.get(key) is Dictionary:problem="카드523 슬롯 적용팩 구성 누락";return {}
	return raw

static func installed() -> bool:return not pack.is_empty() and problem.is_empty()
