extends RefCounted
class_name TwilightMonsterCatalog

const CATALOG_PATH = "res://data/monsters/monster_world_catalog.json"
const SPAWN_PATH = "res://data/monsters/world_spawn_profiles.json"
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
