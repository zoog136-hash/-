extends RefCounted
class_name TwilightOriginalSkillCatalog

## Stable identities, grants, learned books, and verified enhancement relations.
## The old game DB remains untouched, but its synthesized skills are not active.
const ROOT_PATH := "res://data/skills/"
var records: Array = []
var by_id: Dictionary = {}
var by_name: Dictionary = {}
var relations: Dictionary = {}
var learned: Dictionary = {}
var archived: Dictionary = {}
var class_slots: Dictionary = {}
var schools: Dictionary = {"요정":"water"}
var world: Node
var revision: int = 0

func configure(owner: Node) -> void:
	world = owner
	relations = read_json("relations.json")
	var master: Dictionary = read_json("master.json")
	var balances: Dictionary = read_json("balance.json").get("skills", {})
	for value: Dictionary in master.get("records", []):
		var record: Dictionary = value.duplicate(true)
		var id := str(record.id)
		for key: String in balances.get(id, {}):
			record[key] = balances[id][key].get("value")
		record["effect"] = effect_for(record)
		record["trigger"] = record.get("trigger", "always")
		records.append(record)
		by_id[id] = record
		by_name[str(record.name)] = id
	seed_starters()

static func read_json(filename: String) -> Dictionary:
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT_PATH + filename))
	return result if result is Dictionary else {}

static func effect_for(record: Dictionary) -> String:
	match str(record.get("mode", "")):
		"attack": return "damage"
		"status": return str(record.get("status", "stun"))
		"heal", "convert", "cleanse": return "heal"
		"buff", "counter": return "defBuff"
		"teleport": return "teleport"
		"stealth": return "invisibility"
		"taunt", "toggle_proc", "summon": return "utility"
	return "passive"

func seed_starters() -> void:
	for record: Dictionary in records:
		if str(record.get("class")) == "공용" and int(record.get("stage", 1)) == 1:
			learned[str(record.id)] = maxi(1, int(learned.get(str(record.id), 0)))

func record_for(key: String) -> Dictionary:
	return by_id.get(key, by_id.get(by_name.get(key, ""), {}))

func permitted(record: Dictionary) -> bool:
	return record.get("classes", [record.get("class")]).has(world.job_class)

func owned(record: Dictionary) -> bool:
	return permitted(record) and int(learned.get(str(record.get("id", "")), 0)) > 0

func enabled(record: Dictionary) -> bool:
	if not owned(record): return false
	if str(record.get("class", "")) == "요정" and str(record.get("school", "")) in ["water","earth","wind","fire"]:
		if str(record.school) != str(schools.get("요정", "water")): return false
	var required: Array = record.get("weapons", [])
	return required.is_empty() or required.has(world._current_weapon_type())

func reason(record: Dictionary, buying: bool = false) -> String:
	if record.is_empty(): return "스킬 정보 없음"
	if not permitted(record): return "현재 직업에서 습득 불가"
	if int(learned.get(str(record.id), 0)) > 0: return "이미 습득함"
	if int(world.level) < int(record.minimum_level): return "Lv.%d 필요" % int(record.minimum_level)
	var rel: Dictionary = relations.get(str(record.id), {})
	for required: String in rel.get("requires_skill", []):
		if int(learned.get(required, 0)) < int(rel.get("requires_skill_level", {}).get(required, 1)):
			return "선행 스킬 필요: " + str(record_for(required).get("name", required))
	if not buying and int(world.inventory.get(str(record.book_name), 0)) < 1: return "스킬북 필요"
	return ""

func buy_book(key: String) -> bool:
	var record := record_for(key)
	var blocked := reason(record, true)
	if not blocked.is_empty():
		world.hud.show_message(blocked)
		return false
	var price := maxi(0, int(record.get("book_cost", 0)))
	if int(world.gold) < price:
		world.hud.show_message("아데나 부족 · %d 필요" % price)
		return false
	world.gold -= price
	world.inventory[str(record.book_name)] = int(world.inventory.get(str(record.book_name), 0)) + 1
	world._update_hud()
	world._save_game(true)
	return true

func learn(key: String) -> bool:
	var record := record_for(key)
	var blocked := reason(record)
	if not blocked.is_empty():
		world.hud.show_message(blocked)
		return false
	# Validate every prerequisite before consuming the book. An UNKNOWN original
	# prerequisite is displayed as unknown; it is not invented by this service.
	world.inventory[str(record.book_name)] -= 1
	learned[str(record.id)] = 1
	revision += 1
	world._refresh_speed_modifiers()
	world._update_hud()
	world._save_game(true)
	world.hud.show_message(str(record.name) + " 습득")
	return true

func resolve(record: Dictionary) -> Dictionary:
	var result: Dictionary = record.duplicate(true)
	var family: Dictionary = {str(record.id):true}
	# Apply each augment once, in ancestry order. A stronger tier's values
	# replace weaker values rather than adding both passive stat packages.
	for _depth: int in range(records.size()):
		var changed := false
		for augment: Dictionary in records:
			var id := str(augment.id)
			if family.has(id) or not owned(augment): continue
			var rel: Dictionary = relations.get(id, {})
			if not family.has(str(rel.get("upgrades_from", ""))): continue
			result.merge(rel.get("patch", {}), true)
			family[id] = true
			result["resolved_grade"] = augment.grade
			changed = true
		if not changed: break
	return result

func stat(key: String) -> float:
	var total := 0.0
	for record: Dictionary in records:
		if str(record.mode) != "stats" or not enabled(record): continue
		var resolved := resolve(record)
		var condition: Dictionary = resolved.get("stat_conditions", {}).get(key, {})
		if condition.has("weight_min_percent") and float(world._inventory_total_weight()) / float(world._carrying_capacity()) * 100 < float(condition.weight_min_percent): continue
		total += float(resolved.get("stats", {}).get(key, 0))
	return total

func speed() -> float:
	var result := 1.0
	for record: Dictionary in records:
		if str(record.mode) == "stats" and enabled(record):
			result = maxf(result, float(resolve(record).get("stats", {}).get("speed", 1)))
	return result

func export_state() -> Dictionary:
	return {"schema_version":1, "learned":learned.duplicate(true), "archived":archived.duplicate(true),"class_slots":class_slots.duplicate(true),"schools":schools.duplicate(true)}

func import_state(data: Dictionary) -> void:
	learned.clear()
	# Keep unknown future IDs without activating them; round trips are lossless.
	var state: Dictionary = data.get("original_skill_state", {})
	learned = state.get("learned", {}).duplicate(true)
	archived = state.get("archived", {}).duplicate(true)
	class_slots = state.get("class_slots", {}).duplicate(true)
	schools = state.get("schools", {"요정":"water"}).duplicate(true)
	seed_starters()
	if not data.has("original_skill_state"):
		# Previous versions had no book ownership. Explicit quickslots are evidence
		# of use; preserve valid names without granting every legacy class passive.
		archived["pre_migration_quickslots"] = data.get("quickslots", []).duplicate(true)
		archived["pre_migration_buffs"] = data.get("active_skill_buffs", {}).duplicate(true)
		archived["pre_migration_cooldowns"] = data.get("skill_cooldowns", {}).duplicate(true)
		for entry: Dictionary in data.get("quickslots", []):
			if str(entry.get("kind", "")) != "skill": continue
			var record := record_for(str(entry.get("id", "")))
			if not record.is_empty() and permitted(record) and record.activation == "active":
				var matches_legacy := false
				for previous: Dictionary in world.legacy_skills_db:
					if str(previous.get("name", "")) == str(record.name) and str(previous.get("grade", "")) == str(record.grade) and str(previous.get("class", "")) == str(record["class"]): matches_legacy = true
				if matches_legacy: learned[str(record.id)] = 1
				else: archived["unresolved_" + str(record.name)] = entry.duplicate(true)
		# Never translate a pre-2024 counter name into a different 2024 rarity.
		# Its old buff is preserved in the archive instead of executing stale stats.
		world.active_skill_buffs.clear()
	migrate_slots()
	revision += 1

func migrate_slots() -> void:
	for index: int in range(world.quickslots.size()):
		var entry: Dictionary = world.quickslots[index]
		if str(entry.get("kind", "")) != "skill": continue
		var record := record_for(str(entry.get("skill_id", entry.get("id", ""))))
		if record.is_empty() or not owned(record) or str(record.activation) == "passive":
			archived["slot_%d" % index] = entry.duplicate(true)
			world.quickslots[index] = {}
		else:
			# Existing HUD expects the name; the extra stable ID survives renames.
			entry["skill_id"] = str(record.id)
			entry["id"] = str(record.name)
			world.quickslots[index] = entry
