extends RefCounted
class_name TwilightMonsterCatalog

const CATALOG_PATH = "res://data/monsters/monster_world_catalog.json"
const SPAWN_PATH = "res://data/monsters/world_spawn_profiles.json"
static var catalog: Dictionary = {}
static var spawn_profiles: Dictionary = {}

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
	return result

static func apply_map(definition: Dictionary) -> Dictionary:
	ensure_loaded()
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
	for spawn: Dictionary in result.monster_spawn:
		if str(spawn.get("mode", "normal")) == "dense":
			var a: Array = spawn.rect
			# Safe zones keep priority; dense UI wins over broad combat regions.
			var insertion: int = 0
			for i: int in range(result.regions.size()):
				if str(result.regions[i].get("type",""))=="safe": insertion = i+1
			result.regions.insert(insertion,{"id":spawn.id,"name":"폭젠 · 밀집 사냥터","type":"dense",
				"center":[float(a[0])+float(a[2])*.5,float(a[1])+float(a[3])*.5],"radius":spawn.spawn_radius,"color":"dc865e"})
	return result
