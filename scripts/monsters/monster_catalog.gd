extends RefCounted
class_name TwilightMonsterCatalog

const CATALOG_PATH = "res://data/monsters/monster_world_catalog.json"
const SPAWN_PATH = "res://data/monsters/world_spawn_profiles.json"
const REVIEWED_PATH = "res://data/monsters/reviewed_source_monsters.json"
const ADDITIONS_PATH = "res://data/monsters/reviewed_source_additions.json"
const VERIFIED_GAP_IDS = ["45082", "45131", "45143", "45191", "45379", "45405", "45464", "45130", "45309", "45171", "45649", "45604", "45256", "45360", "45577", "45607", "45608", "45963", "46013", "46014", "45995", "45032", "45898", "45899", "45165"]
const LOCAL_NAMED_V2_IDS = ["45777", "45504", "45588", "45602", "45612", "45574", "45646", "45539", "45615", "45671", "45413", "45625", "45685", "45675", "45585", "45548", "45955", "45956", "45957", "45958", "45959", "45960", "45961", "45962", "45166", "45153", "45681", "45682", "45683", "45684", "46025", "46026", "46037", "81163", "97068", "45941", "45943"]
const RELAYOUT = preload("res://scripts/monsters/renewed_map_spawns.gd")
# These dedicated field encounters were added by the renewed placement layer.
# Reuse supported local boss attacks, without changing base HP, loot or visuals.
# These are local adaptations, not claims about verified original-game skills.
const DEDICATED_BOSS_SPECIALS: Dictionary = {
	"흑장로": {"kind":"beam", "cooldown":12.0, "windup":1.15, "radius":220.0,
		"multiplier":1.6, "label":"직선 마법", "evidence":"local_adaptation_not_verified_original_skill"},
	"데스나이트": {"kind":"charge", "cooldown":12.0, "windup":1.15, "radius":220.0,
		"multiplier":1.6, "label":"돌진", "evidence":"local_adaptation_not_verified_original_skill"},
}
static var catalog: Dictionary = {}
static var spawn_profiles: Dictionary = {}
static var records_by_name: Dictionary = {}

static func reviewed_record_allowed(record: Dictionary) -> bool:
	if str(record.get("appearance_status", "")).begins_with("HOLD_"): return false
	if not bool(record.get("import_enabled", false)): return false
	var status: String = str(record.get("identity_approval", ""))
	var approved: bool = status in ["APPROVED_CURRENT318_FIRST_FOUR_REVIEW", "APPROVED_CURRENT318_NEXT_NINE_REVIEW", "APPROVED_CURRENT318_MONSTER_NEXT_THIRTEEN_REVIEW", "APPROVED_CURRENT318_MONSTER_LATE_TEN_REVIEW", "APPROVED_CURRENT318_MONSTER_EARLY_THIRTEEN_REVIEW", "APPROVED_CURRENT318_MONSTER_MIDDLE_TWELVE_REVIEW", "APPROVED_FOR_LATE_SECOND_SOURCE_CATALOG_BATCH_AT_CURRENT_318_SNAPSHOT", "APPROVED_CURRENT318_MONSTER_ELDER_STONEGOLEM_REVIEW", "APPROVED_FOR_MYTHIC_PAIR_SOURCE_CATALOG_BATCH_AT_CURRENT_318_SNAPSHOT"]
	var local_named: bool = status in ["PROVISIONAL_OFFLINE_NAMED_IDENTITY_REVIEW_ONLY_CURRENT318_NO_EXTERNAL_APPLY_AUTHORITY", "PROVISIONAL_OFFLINE_IDENTITY_REVIEW_ONLY_CURRENT318_NO_EXTERNAL_APPLY_AUTHORITY", "OFFLINE_PROVISIONAL_NEW_NAMED_NPC_IDENTITY_SUPPORTED", "OFFLINE_SEMANTIC_IDENTITY_SUPPORTED_EXPLICIT_BASE_AND_ATTACHMENTS", "OFFLINE_PROVISIONAL_NEW_NAMED_IDENTITY_REVIEWED"] and str(record.get("source_npc_id", "")) in LOCAL_NAMED_V2_IDS and str(record.get("local_application_authorization", "")) == "USER_AUTHORIZED_LOCAL_NAMED_V2_CATALOG_ONLY"
	var reviewed_gap:bool=status=="USER_REVIEWED_SQL_AND_EXISTING_BYTES_20261030" and str(record.get("source_npc_id","")) in VERIFIED_GAP_IDS
	return approved or local_named or reviewed_gap

static func spawnable_records(records: Array) -> Array:
	# Catalog registration alone never opts a source identity into random maps.
	return records.filter(func(record: Variant) -> bool:
		return not (record is Dictionary and bool(record.get("catalog_only", false))))

static func ensure_loaded() -> void:
	if not catalog.is_empty(): return
	catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH)) as Dictionary
	spawn_profiles = JSON.parse_string(FileAccess.get_file_as_string(SPAWN_PATH)) as Dictionary

static func expand(original: Array) -> Array:
	ensure_loaded()
	var result: Array = []
	var by_name: Dictionary = {}
	for raw: Dictionary in original:
		var record: Dictionary = raw.duplicate(true)
		record.merge(catalog.overlays.get(str(record.name), {}), true)
		result.append(record)
		by_name[str(record.name)] = record
	for patch: Dictionary in catalog.additions:
		if by_name.has(str(patch.name)): continue
		var record: Dictionary = (by_name.get(str(patch.get("template", "해골 근위병")), {}) as Dictionary).duplicate(true)
		record.merge(patch, true)
		# New species inherit only an existing TWILIGHT drop pool, never claimed
		# to reproduce original rewards. Loot rates remain in loot_drop.gd.
		result.append(record)
		by_name[str(record.name)] = record
	# Reviewed source identities are independent records, without inherited stats,
	# loot or silhouettes. Existing names/source links always retain precedence.
	var source_ids: Dictionary = {}
	for record: Dictionary in result:
		for field: String in ["sourceId", "source_id", "source_npc_id"]:
			if record.has(field): source_ids[str(record[field])] = true
	var reviewed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REVIEWED_PATH)) as Dictionary
	var additions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ADDITIONS_PATH))
	for raw: Dictionary in reviewed.get("records", [])+additions.get("records",[]):
		if not reviewed_record_allowed(raw): continue
		var duplicate: bool = by_name.has(str(raw.name))
		for field: String in ["sourceId", "source_id", "source_npc_id"]:
			duplicate = duplicate or source_ids.has(str(raw.get(field, "")))
		if duplicate: continue
		var record: Dictionary = raw.duplicate(true)
		result.append(record)
		by_name[str(record.name)] = record
		for field: String in ["sourceId", "source_id", "source_npc_id"]:
			source_ids[str(record[field])] = true
	records_by_name = {}
	for record: Dictionary in result:
		var name: String = str(record.name)
		if DEDICATED_BOSS_SPECIALS.has(name):
			var ai: Dictionary = record.get("ai", {}).duplicate(true)
			if not ai.has("special"):
				var special: Dictionary = DEDICATED_BOSS_SPECIALS[name].duplicate(true)
				special["element"] = str(record.get("attack_element", "physical"))
				ai["special"] = special
			record["ai"] = ai
			record["is_boss"] = true
		records_by_name[name] = record
	return result

static func apply_map(definition: Dictionary) -> Dictionary:
	ensure_loaded()
	if str(definition.get("spawn_layout_revision", "")) == RELAYOUT.revision(): return definition.duplicate(true)
	var patch: Dictionary = spawn_profiles.maps.get(str(definition.map_id), {})
	if patch.is_empty(): return definition
	var result: Dictionary = definition.duplicate(true)
	result["monster_spawn"] = patch.monster_spawn.duplicate(true)
	result["monster_coordinate_note"] = patch.get("coordinate_note", "")
	if spawn_profiles.map_titles.has(str(result.map_id)):
		result["map_name"] = spawn_profiles.map_titles[str(result.map_id)]
	for label: Dictionary in patch.get("region_labels", []):
		var found: bool = false
		for region: Dictionary in result.regions:
			if str(region.id) == str(label.id):
				region.merge(label, true)
				found = true
				break
		if not found: result.regions.append(label.duplicate(true))
	if records_by_name.is_empty():
		var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json")) as Dictionary
		expand(base.get("몬스터", []))
	# Resolve against the current map, not the historical coordinate tables.
	result = RELAYOUT.apply(result, spawn_profiles.maps, records_by_name)
	for spawn: Dictionary in result.monster_spawn:
		if str(spawn.get("mode", "normal")) == "boss":
			# Additional encounters must satisfy the same schema as catalog bosses.
			spawn["map_id"] = str(result.map_id)
			var verification: Dictionary = spawn.get("verification_status", {}).duplicate(true)
			if not verification.has("exact_spawn_area"):
				verification["exact_spawn_area"] = "unverified"
			spawn["verification_status"] = verification
		if str(spawn.get("mode", "normal")) == "dense":
			var a: Array = spawn.rect
			# Safe zones keep priority; dense UI wins over broad combat regions.
			var insertion: int = 0
			for i: int in range(result.regions.size()):
				if str(result.regions[i].get("type",""))=="safe": insertion = i+1
			result.regions.insert(insertion,{"id":spawn.id,"name":"폭젠 · 밀집 사냥터","type":"dense",
				"center":[float(a[0])+float(a[2])*.5,float(a[1])+float(a[3])*.5],"radius":spawn.spawn_radius,"color":"dc865e"})
			if spawn.has("polygon"): result.regions[insertion]["polygon"] = spawn.polygon.duplicate(true)
	return result
