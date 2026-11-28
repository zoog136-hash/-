extends RefCounted
class_name TwilightOriginalSkillCatalog

## Stable identities, grants, learned books, and verified enhancement relations.
## The old game DB remains untouched, but its synthesized skills are not active.
const CURRENT = preload("res://scripts/skills/current_official_skills.gd")
var current_official = CURRENT.new()
const SOURCE523 = preload("res://scripts/skills/player_skills523.gd")
const LEARNING_SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
var source523 = SOURCE523.new()
const SOURCE_LEARNING=preload("res://scripts/quests/quest_reference_learning.gd")
var source_quest_knowledge: Dictionary={}
const ROOT_PATH := "res://data/skills/"
const BUILT_IN_DATA = preload("res://scripts/resources/built_in_startup_data.gd")
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
var resolved_cache: Dictionary = {}
var resolved_signature: String = ""
var stat_signature: String = ""
var static_stat_totals: Dictionary = {}
var weighted_stat_entries: Dictionary = {}
var static_speed: float = 1.0
## TWILIGHT 근사 invoke options of learned approximated passives (rebuilt with the stat index).
var approx_invokes: Array = []
## TWILIGHT 근사 "스킬 대체": replaced record id -> transform of a learned approximated passive.
var approx_transforms: Dictionary = {}
var stat_rebuild_count: int = 0
const RELIC_LEVELS = preload("res://scripts/cards/relic_spell_levels.gd")
const REFERENCE_PROFILES523 = preload("res://scripts/skills/reference_profiles523.gd")
const COMBAT_PROC_MODES = ["proc", "mark", "toggle_proc", "stack_defense", "stack_attack"]
var _combat_record_source: Array = []
var _combat_record_count: int = -1
var _combat_record_revision: int = -1
var _combat_record_learned: Dictionary = {}
var _proc_records: Array[Dictionary] = []
var _possible_owned_records: Array[Dictionary] = []

func configure(owner: Node) -> void:
	world = owner
	records.clear();by_id.clear();by_name.clear()
	resolved_cache.clear();resolved_signature="";stat_signature=""
	revision += 1
	relations = read_json("relations.json")
	var master: Dictionary = read_json("master.json")
	var balances: Dictionary = read_json("balance.json").get("skills", {})
	for value: Dictionary in master.get("records", []):
		var record: Dictionary = value.duplicate(true)
		var id := str(record.id)
		for key: String in balances.get(id, {}):
			record[key] = balances[id][key].get("value")
		record["effect"] = effect_for(record)
		# Skill pictures come only from the original 523 pack (Source523 skill
		# images). Old icon files are never read; an unconnected slot stays empty.
		record.erase("icon")
		record["trigger"] = record.get("trigger", "always")
		records.append(record)
		by_id[id] = record
		by_name[str(record.name)] = id
	for record: Dictionary in current_official.records:
		record["effect"] = effect_for(record)
		records.append(record)
		by_id[str(record.id)] = record
		by_name[str(record.name)] = str(record.id)
		for alias: String in record.historical_aliases: by_name[alias] = str(record.id)
	var roster: Dictionary = read_json("official_roster.json")
	for alias: String in roster.get("aliases",{}):
		var canonical: String = str(roster.aliases[alias])
		if by_name.has(canonical): by_name[alias] = by_name[canonical]
	# Explicit reviewed class extensions retain one shared learned/save identity.
	for fact: Dictionary in roster.get("observations",[]):
		if fact.get("status","")!="existing_shared_class": continue
		var canonical: String=str(fact.runtime_name)
		if not by_name.has(canonical): continue
		var row: Dictionary=by_id[str(by_name[canonical])]
		if bool(row.get("runtime_blocked",false)): continue
		var job: String=str(fact["class"])
		if not row.classes.has(job): row.classes.append(job)
		if not row.has("class_learning_levels"): row["class_learning_levels"]={}
		if not row.has("class_costs"): row["class_costs"]={}
		if not row.has("class_references"): row["class_references"]={}
		row.class_learning_levels[job]=int(fact.level_display)
		row.class_costs[job]={"mp":int(fact.mp_display)}
		if str(fact.hp_display).is_valid_int(): row.class_costs[job]["hp"]=int(fact.hp_display)
		row.class_references[job]=fact.duplicate(true)
	relations.merge(current_official.local_design.get("relations",{}))
	source523.configure_arguments()
	var public_profiles: Dictionary = REFERENCE_PROFILES523.profiles()
	for record: Dictionary in records:
		source523.prepare_estimate(record)
		source523.prepare_source_direct(record)
		# TWILIGHT 근사: RequiredSpellClassID = prerequisite skill (learn guard).
		var required: Array = record.get("source_approx523",{}).get("requires",[])
		if not required.is_empty():
			if not relations.has(str(record.id)):relations[str(record.id)]={}
			relations[str(record.id)]["requires_skill"]=required.duplicate()
		REFERENCE_PROFILES523.install(record, public_profiles.get(str(record.id), {}), self)
		record["effect"] = effect_for(record)
	# TWILIGHT 근사: skills given by worn equipment (EquipSpellClassID).
	for record: Dictionary in source523.equipment_spell_records(source523.bindings.get("class_ids",{}).keys()):
		record["effect"] = effect_for(record)
		records.append(record)
		by_id[str(record.id)] = record
		by_name[str(record.name)] = str(record.id)
	seed_starters()


## Base records that can receive combat trigger events, in catalog order.
## Keep live class, equipment, level and ownership checks in the receiver.
func combat_proc_records() -> Array[Dictionary]:
	_ensure_combat_record_index()
	return _proc_records

## Learned records and every equipment-granted candidate, in catalog order.
## Callers still check the real ownership and restrictions for each record.
func possible_owned_records() -> Array[Dictionary]:
	_ensure_combat_record_index()
	return _possible_owned_records

func _ensure_combat_record_index() -> void:
	if _combat_record_revision == revision and _combat_record_count == records.size() \
		and is_same(_combat_record_source, records) and _combat_record_learned == learned:
		return
	_combat_record_source = records
	_combat_record_count = records.size()
	_combat_record_revision = revision
	_combat_record_learned = learned.duplicate()
	var procs: Array[Dictionary] = []
	var possible: Array[Dictionary] = []
	for base: Dictionary in records:
		if str(base.get("mode", "")) in COMBAT_PROC_MODES:
			procs.append(base)
		if base.has("equipment_spell523") or int(learned.get(str(base.get("id", "")), 0)) > 0:
			possible.append(base)
	_proc_records = procs
	_possible_owned_records = possible


static func read_json(filename: String) -> Dictionary:
	var result: Variant = BUILT_IN_DATA.read_json(ROOT_PATH + filename)
	return result if result is Dictionary else {}

static func effect_for(record: Dictionary) -> String:
	match str(record.get("mode", "")):
		"attack": return "damage"
		"turn_undead": return "turnUndead"
		"status": return str(record.get("status", "stun"))
		"heal", "convert", "cleanse", "local_heal": return "heal"
		"buff", "counter", "local_buff", "detect": return "defBuff"
		"teleport": return "teleport"
		"stealth": return "invisibility"
		"taunt", "toggle_proc", "summon": return "utility"
	return "passive"

func seed_starters() -> void:
	for record: Dictionary in records:
		if str(record.get("class")) == "공용" and int(record.get("stage", 1)) == 1:
			learned[str(record.id)] = maxi(1, int(learned.get(str(record.id), 0)))

func record_for(key: String) -> Dictionary:
	return by_id.get(key, by_id.get(by_name.get(key, ""), current_official.record_for(key)))

func minimum_level_for(record: Dictionary) -> int:
	var native: Dictionary=_source_learning_input(record)
	if native.has("minimum_level"):return int(native.minimum_level)
	return _host_minimum_level_for(record)


func _host_minimum_level_for(record: Dictionary) -> int:
	# Reference-only held-back rows (e.g. 버닝 드라이브, 매직 마스터(에이션트)) carry
	# no learning level. int(null) aborted reason()/buy_book()/learn() with a
	# script error; no known level means no level gate (they stay held back).
	var levels: Variant = record.get("class_learning_levels",{})
	var value: Variant = (levels as Dictionary).get(str(world.job_class),record.get("minimum_level",0)) if levels is Dictionary else record.get("minimum_level",0)
	return int(value) if value is int or value is float else 0


func level_locked(record: Dictionary) -> bool:
	# The new source learning threshold is for learning/UI only. Historical
	# owned spell execution retains its existing host level policy.
	return (record.get("reference_approx523",false) or record.get("local_design",false) \
		or record.get("class_learning_levels",{}).has(str(world.job_class))) and int(world.level)<_host_minimum_level_for(record)


func permitted(record: Dictionary) -> bool:
	return record.get("classes", [record.get("class")]).has(world.job_class)

func owned(record: Dictionary) -> bool:
	if record.has("equipment_spell523"): return permitted(record) and equipment_spells().has(int(record.equipment_spell523))
	# Every condition below is a side-effect-free AND that ends on "learned";
	# check that one first. Combat loops ask this for all ~480 records per hit
	# and most are not learned (523 auto-hunt: ~950 calls per attack).
	if int(learned.get(str(record.get("id", "")), 0)) <= 0: return false
	if not source_learning_status(record).is_empty():return false
	if bool(record.get("runtime_blocked", false)): return false
	# TWILIGHT 근사: a card-bound skill (LimitBuffCardID) works while that card is owned.
	if int(record.get("approx_required_card",0)) != 0 and not preload("res://scripts/cards/card_requirement523.gd").satisfied(world,int(record.approx_required_card)): return false
	return permitted(record) and int(learned.get(str(record.get("id", "")), 0)) > 0

var _equip_spells: Dictionary = {}
## SpellClass IDs given by the currently worn items (TWILIGHT 근사, EquipSpellClassID).
func equipment_spells() -> Dictionary:
	_equip_spells = {}
	if world == null or source523.equip_spell_items.is_empty(): return _equip_spells
	for slot: Variant in world.equipped_items:
		var worn: Variant = world.equipped_items[slot]
		if not worn is Dictionary: continue
		var physical: Variant = world.item_instances.get(str((worn as Dictionary).get("instance_id","")), {})
		var record: Dictionary = (physical as Dictionary).get("record", {}) if physical is Dictionary else {}
		var item_id: int = int(record.get("source_item_class_id", (worn as Dictionary).get("source_item_class_id",0)))
		if item_id <= 0: continue
		for spell_id: Variant in source523.equip_spell_items:
			if (source523.equip_spell_items[spell_id] as Dictionary).has(item_id): _equip_spells[int(spell_id)] = true
	return _equip_spells

func enabled(record: Dictionary) -> bool:
	# Every condition is a side-effect-free AND. The cheap ownership checks run
	# first: combat loops call this for all ~480 records on every hit, and the
	# spell-group source-ID adapter costs ~12 us per record (2026-11-15:
	# outgoing_damage + trigger ~15 ms per hit on desktop, ~1.9 s on the phone).
	if bool(record.get("runtime_blocked", false)): return false
	if not owned(record): return false
	if world.get("spell_group_conversion")!=null and not world.spell_group_conversion.allows(record):return false
	if level_locked(record):return false
	if bool(record.get("reference_approx523", false)):
		for prerequisite: String in relations.get(str(record.id), {}).get("requires_skill", []):
			if int(learned.get(prerequisite, 0)) <= 0: return false
	if str(record.get("class", "")) == "요정" and str(record.get("school", "")) in ["water","earth","wind","fire"]:
		if str(record.school) != str(schools.get("요정", "water")): return false
	var approx_weapons: Array = record.get("approx_weapon_types", [])
	if not approx_weapons.is_empty() and not approx_weapons.has(source_weapon_type_id()): return false
	var required: Array = record.get("weapons", [])
	return required.is_empty() or required.has(world._current_weapon_type())

func reason(record: Dictionary, buying: bool = false, supplied_book: String = "") -> String:
	var source_status: Dictionary=source_learning_status(record,true)
	if not source_status.is_empty():return str(source_status.message)
	if record.is_empty(): return "스킬 정보 없음"
	if not permitted(record): return "현재 직업에서 습득 불가"
	if bool(record.get("runtime_blocked", false)):
		if int(world.level) < minimum_level_for(record): return "Lv.%d 필요" % minimum_level_for(record)
		return CURRENT.blocked_reason(record)
	if int(learned.get(str(record.id), 0)) > 0: return "이미 습득함"
	if int(world.level) < minimum_level_for(record): return "Lv.%d 필요" % minimum_level_for(record)
	var rel: Dictionary = relations.get(str(record.id), {})
	for required: String in rel.get("requires_skill", []):
		if int(learned.get(required, 0)) < int(rel.get("requires_skill_level", {}).get(required, 1)):
			return "선행 스킬 필요: " + str(record_for(required).get("name", required))
	if not buying and int(world.inventory.get(supplied_book if not supplied_book.is_empty() else str(record.book_name), 0)) < 1: return "스킬북 필요"
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
	var book: String = str(record.book_name)
	var previous_count: int = int(world.inventory.get(book, 0))
	world.gold -= price
	world.inventory[book] = previous_count + 1
	world._update_hud()
	var result: Error = world._save_game(true)
	if result != OK and bool(record.get("reference_approx523", false)):
		world.gold += price
		if previous_count > 0: world.inventory[book] = previous_count
		else: world.inventory.erase(book)
		world._update_hud()
		world.hud.show_message("교본 구매 저장 실패 · 아데나 복구")
		return false
	return true

func learn(key: String, supplied_book: String = "") -> bool:
	var record := record_for(key)
	if not supplied_book.is_empty() and not preload("res://scripts/shop/source523_skill_books.gd").registered(world,supplied_book,key):
		world.hud.show_message("스킬북 원본 정체 불일치 · 보존")
		return false
	if not supplied_book.is_empty():
		var definition: Dictionary = world._find_catalog_item_record(supplied_book)
		var native_reason: String = preload("res://scripts/shop/source523_skill_books.gd").learn_reason(world,preload("res://scripts/shop/source523_skill_books.gd").contract(int(definition.source_item_class_id)))
		if not native_reason.is_empty():world.hud.show_message(native_reason);return false
	var blocked := reason(record,false,supplied_book)
	if not blocked.is_empty():
		world.hud.show_message(blocked)
		return false
	# Validate every prerequisite before consuming the book. An UNKNOWN original
	# prerequisite is displayed as unknown; it is not invented by this service.
	var book: String = supplied_book if not supplied_book.is_empty() else str(record.book_name)
	var before_count: int = int(world.inventory.get(book,0))
	var before_revision: int = revision
	var before_learned: Dictionary = learned.duplicate(true)
	var before_buffs: Dictionary = world.active_skill_buffs.duplicate(true)
	world.inventory[book] = before_count - 1
	learned[str(record.id)] = 1
	revision += 1
	world.original_skills.refresh_buffs_after_learning(str(record.id))
	var atomic_learning: bool = not supplied_book.is_empty() or bool(record.get("reference_approx523", false))
	if atomic_learning and world._save_game(true) != OK:
		world.inventory[book] = before_count
		learned = before_learned
		world.active_skill_buffs = before_buffs
		revision = before_revision
		world._update_hud()
		world.hud.show_message("습득 저장 실패 · 스킬북과 습득 상태 보존")
		return false
	if str(record.activation) == "passive":
		world.original_skills.vfx.emit_skill(str(record.id), "learn", world.player.global_position)
		world.original_skills.emit_reference_learning(record)
	world._refresh_speed_modifiers()
	world._update_hud()
	if not atomic_learning:world._save_game(true)
	world.hud.show_message(str(record.name) + " 습득")
	return true

func _lineage_signature() -> String:
	# Tests and migration adapters may edit learned directly; hash catches those
	# alongside the normal learn/import revision without touching old save data.
	return "%d|%s|%d|%d|%d|%d" % [revision,str(world.job_class),hash(learned),records.size(),source523.revision,hash(world.equipped_items.get("weapon",{}))]

func _refresh_resolved_cache() -> String:
	var signature: String = _lineage_signature() + _relic_signature()
	if signature != resolved_signature:
		resolved_signature = signature
		resolved_cache.clear()
	return signature

func _resolved_reference(record: Dictionary) -> Dictionary:
	_refresh_resolved_cache()
	return _resolve_in_current_cache(record)

func _resolve_in_current_cache(record: Dictionary) -> Dictionary:
	var id: String=str(record.get("id",""))
	# World quickslots and the skill browser keep deep copies of this catalog.
	# Accept exact copies, then resolve the canonical row; altered records do
	# not acquire native effects merely by carrying a known ID.
	if not id.is_empty() and by_id.has(id) and (is_same(by_id[id],record) or by_id[id] == record):
		if not resolved_cache.has(id):
			var result: Dictionary = _resolve_uncached(by_id[id])
			var identity: Dictionary = by_id.get(str(result.get("relic_resolved_id", id)), {})
			resolved_cache[id] = RELIC_LEVELS.project(world, result, identity, enabled(record))
		return resolved_cache[id]
	return _resolve_uncached(record)

func resolve(record: Dictionary) -> Dictionary:
	# Callers may alter a resolved action; never hand out the cached source.
	return _resolved_reference(record).duplicate(true)

func _relic_signature() -> String:
	return "|relic:%d|%d|%d|%d" % [RELIC_LEVELS.state_key(world), int(world.level), hash(world.equipped_items.get("weapon", {})), hash(schools)]

func _resolve_uncached(record: Dictionary) -> Dictionary:
	var result: Dictionary = record.duplicate(true)
	result["relic_resolved_id"] = str(record.id)
	var family: Dictionary = {str(record.id):true}
	var native_upgrade := false
	var public_upgrades: Array[Dictionary] = []
	# Apply each augment once, in ancestry order. A stronger tier's values
	# replace weaker values rather than adding both passive stat packages.
	var candidates: Array[Dictionary] = possible_owned_records()
	for _depth: int in candidates.size():
		var changed := false
		for augment: Dictionary in candidates:
			var id := str(augment.id)
			if family.has(id): continue
			var rel: Dictionary = relations.get(id, {})
			if not family.has(str(rel.get("upgrades_from", ""))) or not owned(augment): continue
			if bool(augment.get("reference_approx523", false)):
				if level_locked(augment): continue
				public_upgrades.append(rel.get("patch", {}))
			else:
				result.merge(rel.get("patch", {}), true)
				native_upgrade = true
			family[id] = true
			result["resolved_grade"] = augment.grade
			result["relic_resolved_id"] = id
			changed = true
		if not changed: break
	var job: String=str(world.job_class)
	if record.get("class_learning_levels",{}).has(job):
		result["minimum_level"]=_host_minimum_level_for(record)
		result.merge(record.get("class_costs",{}).get(job,{}),true)
		result["display_class"]=job
		result["current_class_reference"]=record.class_references[job].duplicate(true)
		if result.has("design_provenance"):
			for field: String in ["minimum_level","mp"]:
				result.design_provenance[field]={"value":result[field],"status":"official","basis":record.class_references[job].source_url}
		if result.has("official"):
			result.official["source_url"]=record.class_references[job].source_url
			result.official["learning_level"]=result.minimum_level
			result.official["mp_cost"]=result.mp
	if result.has("bow_range") and world._current_weapon_type() == "활": result["range"] = float(result.bow_range)
	result = source523.apply_to(result, job, native_upgrade)
	for patch: Dictionary in public_upgrades:
		result.merge(patch, true)
		result["reference_upgrade523"] = true
		if patch.has("stats"): result["reference_upgrade_stats"] = patch.stats
		if patch.has("power") and result.get("approx_child", {}).get("effect") == "damage":
			# Keep the admitted child's dice, timing and follow-up graph.
			result.approx_child["base"] = maxi(int(result.approx_child.get("base", 0)), int(patch.power))
	if result.get("reference_flexible_weapon", false) and world._current_weapon_type() == "활":
		result["attack_type"] = "ranged"
		result["range"] = maxf(314, float(result.get("range", 0)))
	var name: String = str(record.get("name", ""))
	for support: Dictionary in candidates:
		var names: Array = support.get("reference_boost_skills", [])
		var fairy: bool = support.get("reference_fairy_master", false) and name in ["블러드 투 소울","엘리멘탈 큐어"]
		if not (names.has(name) or fairy) or not enabled(support): continue
		result["reference_upgrade523"] = true
		if fairy:
			result["heal"] = int(result.get("heal", 0)) + 25
			result["mana"] = int(result.get("mana", 0)) + 12
		else:
			if result.has("range"): result["range"] = float(result.range) + 14.0
			if result.has("status_chance"): result["status_chance"] = minf(.95, float(result.status_chance) + .06)
			if result.has("power"): result["power"] = int(result.power) + 12
	return result

static func _can_add_static_stats(fields: Dictionary) -> bool:
	return fields.get("mode", "") == "stats" or fields.has("stats") or fields.has("source_approx523") or fields.has("id")

func _upgrades_can_add_static_stats() -> bool:
	for relation: Dictionary in relations.values():
		if _can_add_static_stats(relation.get("patch", {})):
			return true
	return false

func _ensure_stat_index() -> void:
	var signature: String = _refresh_resolved_cache()
	if signature==stat_signature:return
	stat_signature=signature
	static_stat_totals.clear();weighted_stat_entries.clear()
	static_speed=1.0
	approx_invokes.clear()
	approx_transforms.clear()
	stat_rebuild_count+=1
	# TWILIGHT 근사 passives (data/skills/source_approx523.json): a non-overlap
	# original BuffGroup keeps only its highest-priority learned passive.
	var approx_groups: Dictionary = {}
	var approx_weapon: int = source_weapon_type_id()
	var job: String = str(world.job_class)
	var stat_upgrades: bool = _upgrades_can_add_static_stats()
	for record: Dictionary in possible_owned_records():
		# A cast-only record gets its full projection on demand. Upgrades and
		# original progression can supply a passive even if the base mode differs.
		var local_design: bool = bool(record.get("local_design", false))
		var reference_stats: bool = bool(record.get("reference_approx523", false)) \
			and record.get("activation") == "passive" and not record.get("stats", {}).is_empty()
		var may_project_stats: bool = stat_upgrades or record.get("mode", "") == "stats" or reference_stats \
			or record.has("source_approx523") or source523.may_project_static_stats(str(record.id)) \
			or _can_add_static_stats(record.get("class_costs", {}).get(job, {}))
		if not (local_design or may_project_stats) or not enabled(record): continue
		if local_design:
			static_speed=maxf(static_speed,float(record.get("passive_speed",1)))
		if not may_project_stats: continue
		var resolved: Dictionary = _resolve_in_current_cache(record)
		if not str(resolved.get("source523_block_reason","")).is_empty():continue
		if resolved.has("source_approx523"):
			var spec: Dictionary=resolved.source_approx523
			if not spec.get("requires",[]).all(func(required: String) -> bool: return int(learned.get(required,0))>0):continue
			for transform: Dictionary in spec.get("transforms",[]):
				if int(transform.get("level",0))>int(world.level):continue
				var current: Dictionary=approx_transforms.get(str(transform.record),{})
				if current.is_empty() or int(transform.level)>int(current.level):approx_transforms[str(transform.record)]=transform
			var projected: Dictionary = SOURCE523.approx_values(spec,int(world.level),approx_weapon)
			projected.merge(resolved.get("reference_upgrade_stats", {}), true)
			var entry: Dictionary={"id":str(record.id),"stats":projected,
				"invokes":SOURCE523.approx_level_rows(spec.get("invokes",[]),int(world.level),approx_weapon,spec.get("weapons",[]))}
			var group: Dictionary=spec.get("group",{})
			var key: String=str(record.id) if group.is_empty() or bool(group.get("overlap",true)) else "group:%d" % int(group.id)
			var rank: Array=[int(group.get("priority",0)),int(group.get("buff_id",0))]
			if not approx_groups.has(key) or rank>approx_groups[key].rank:approx_groups[key]={"rank":rank,"entry":entry}
			continue
		if str(resolved.mode)!="stats" and not reference_stats:continue
		static_speed=maxf(static_speed,float(resolved.get("stats",{}).get("speed",1)))
		var stats: Dictionary=resolved.get("stats",{})
		if record.has("reference_aura_steps"):
			var aura_count := 0
			for aura_id: String in record.reference_aura_steps:
				if owned(record_for(aura_id)): aura_count += 1
			static_stat_totals["meleeDamage"] = float(static_stat_totals.get("meleeDamage", 0)) + aura_count
			static_stat_totals["rangedDamage"] = float(static_stat_totals.get("rangedDamage", 0)) + aura_count
			static_stat_totals["referenceArmor"] = float(static_stat_totals.get("referenceArmor", 0)) - aura_count
		var conditions: Dictionary=resolved.get("stat_conditions",{})
		for key: String in stats:
			var condition: Dictionary=conditions.get(key,{})
			var value: float=float(stats[key])
			if condition.has("weight_min_percent"):
				if not weighted_stat_entries.has(key):weighted_stat_entries[key]=[]
				weighted_stat_entries[key].append({"minimum":float(condition.weight_min_percent),"value":value})
			else:static_stat_totals[key]=float(static_stat_totals.get(key,0.0))+value
	for group_key: String in approx_groups:
		var chosen: Dictionary=approx_groups[group_key].entry
		for key: String in chosen.stats:
			if key=="moveSpeedPct":static_speed=maxf(static_speed,1.0+float(chosen.stats[key])/100.0)
			else:static_stat_totals[key]=float(static_stat_totals.get(key,0.0))+float(chosen.stats[key])
		for invoke: Dictionary in chosen.invokes:
			var copy: Dictionary=invoke.duplicate(true)
			copy["skill_id"]=str(chosen.id)
			approx_invokes.append(copy)

## Original WeaponType ID of the equipped weapon (native row first, then the
## existing local weapon-type mapping; -1 when unknown, 0 unarmed).
func source_weapon_type_id() -> int:
	var weapon: Variant=world.equipped_items.get("weapon",{})
	if not weapon is Dictionary or weapon.is_empty():return 0
	var native: Dictionary=preload("res://scripts/loot/patch523_ammo.gd").weapon_type(world._equipped_weapon_record())
	if not native.is_empty():return int(native.get("ID",-1))
	return preload("res://scripts/animation/source_weapon_banks.gd").local_type(world._current_weapon_type())

func approx_transform_for(id: String) -> Dictionary:
	_ensure_stat_index()
	return approx_transforms.get(id, {})

## Active TWILIGHT 근사 invoke options of learned passives at this level/weapon.
func approx_invoke_list() -> Array:
	_ensure_stat_index()
	return approx_invokes

func stat(key: String) -> float:
	_ensure_stat_index()
	var total: float=float(static_stat_totals.get(key,0.0))
	var weighted: Array=weighted_stat_entries.get(key,[])
	if not weighted.is_empty():
		var weight_percent: float=float(world._inventory_total_weight())/maxf(1.0,float(world._carrying_capacity()))*100.0
		for entry: Dictionary in weighted:
			if weight_percent>=float(entry.minimum):total+=float(entry.value)
	return total

func speed() -> float:
	_ensure_stat_index()
	return static_speed

func _source_learning_input(record: Dictionary)->Dictionary:
	var id: String=str(record.get("id",""))
	# Existing canonical skill IDs only. An absent optional original profile
	# neither invents a native ID nor changes the host's other skill contracts.
	if not by_id.has(id) or not source523.profiles.has(id):return {}
	var archive: Dictionary=LEARNING_SOURCE.identity()
	if archive.get("source_sha256")!=SOURCE523.SOURCE_SHA:
		return {"message":"원본 스킬 학습 입력이 없습니다. 기존 습득 상태는 보존됩니다."}
	var text: String=FileAccess.get_file_as_string(SOURCE523.BINDINGS_PATH)
	var public: Variant=JSON.parse_string(text)
	if not public is Dictionary or public.get("schema_version")!=1 or public.get("patch")!=523 or public.get("source_zip_sha256")!=SOURCE523.SOURCE_SHA or not public.get("skills") is Dictionary or not public.get("class_ids") is Dictionary or public!=source523.bindings:
		return {"message":"원본 스킬 학습의 공개 ID 연결 확인 필요"}
	var binding: Variant=public.get("skills",{}).get(id)
	var native_class: Variant=public.get("class_ids",{}).get(str(world.job_class))
	if not binding is Dictionary or not SOURCE523._source_integer(binding.get("spell_id")) or not binding.get("row_sha256") is String or not SOURCE523._source_integer(native_class):
		return {"message":"원본 스킬·현재 직업 ID 연결 확인 필요"}
	var profile: Dictionary=source523.profiles[id]
	var spell_id: int=int(binding.spell_id)
	var raw: Dictionary=LEARNING_SOURCE.row("SpellClass",spell_id)
	if raw.is_empty() or raw!=profile.get("row") or SOURCE523._source_row_json(raw,str(binding.row_sha256)).is_empty() or str(profile.get("row_json","")).sha256_text()!=str(binding.row_sha256):
		return {"message":"원본 스킬 학습 행·지문 연결 확인 필요"}
	if raw.get("TestSpell")!=false or not LEARNING_SOURCE.declared_exclusion("SpellClass",raw).is_empty():
		return {"message":"원본 시험·제외 스킬은 새로 습득할 수 없습니다."}
	var class_row: Dictionary=LEARNING_SOURCE.row("Class",int(native_class))
	if class_row.is_empty() or class_row.get("ID")!=native_class or not LEARNING_SOURCE.declared_exclusion("Class",class_row).is_empty():
		return {"message":"원본 직업 학습 참조 확인 필요"}
	var limits: Array[Dictionary]=LEARNING_SOURCE.related("SpellLearnLimit","SpellClassID",spell_id)
	# Require the complete current original set, including its order/duplicates;
	# a stale compiled subset cannot become the new learning qualification.
	if limits.is_empty() or limits!=profile.get("learn_limits"):
		return {"message":"원본 전체 학습 조건 입력 연결 확인 필요"}
	var ordinary_levels: Array[int]=[]
	var matched: bool=false
	for limit: Dictionary in limits:
		if not SOURCE523._source_integer(limit.get("ClassID")):
			return {"message":"원본 학습 조건의 직업 ID 확인 필요"}
		if limit.ClassID!=native_class:continue
		if not limit.get("IsTutorialSpell") is bool:
			return {"message":"원본 일반·튜토리얼 학습 조건 확인 필요"}
		if limit.IsTutorialSpell:continue
		matched=true
		if not LEARNING_SOURCE.declared_exclusion("SpellLearnLimit",limit).is_empty():continue
		for field: String in ["SpellClassID","CharacterMinLevel","LimitBuffCardID","CharacterPolymorphGradeID"]:
			if not SOURCE523._source_integer(limit.get(field)) or int(limit[field])<0:
				return {"message":"원본 학습 조건 수치 확인 필요: "+field}
		if int(limit.SpellClassID)!=spell_id:return {"message":"원본 학습 조건의 스킬 ID 불일치"}
		# Same ordinary alternatives as source523_skill_books.learn_reason:
		# a nonzero card/polymorph requirement is never satisfied by inference.
		# TWILIGHT 근사: a card row counts while its card is owned (card_requirement523).
		if int(limit.CharacterPolymorphGradeID)==0 and preload("res://scripts/cards/card_requirement523.gd").satisfied(world,int(limit.LimitBuffCardID)):
			ordinary_levels.append(int(limit.CharacterMinLevel))
	if not matched:return {"message":"523 원본 직업의 일반 학습 대상이 아닙니다."}
	if ordinary_levels.is_empty():return {"message":"원본 학습의 선행 카드·변신 등급·제외 조건 확인 필요"}
	# The existing book guard accepts any ordinary alternative at its level.
	# This threshold selects that same OR boundary, without mixing conditional rows.
	return {"minimum_level":ordinary_levels.min()}


func source_learning_status(record: Dictionary, new_learning: bool=false)->Dictionary:
	var key: String=str(record.get("id",""))
	if source_quest_knowledge.has(key):
		var status: Dictionary=SOURCE_LEARNING.status(source_quest_knowledge,learned,key)
		if not status.is_empty():return status
	if new_learning:
		var native: Dictionary=_source_learning_input(record)
		if native.has("message"):return native
	return {}


func export_state() -> Dictionary:
	var state: Dictionary={"schema_version":1, "learned":learned.duplicate(true), "archived":archived.duplicate(true),"class_slots":class_slots.duplicate(true),"schools":schools.duplicate(true)}
	if not source_quest_knowledge.is_empty():state["source_quest_knowledge"]=source_quest_knowledge.duplicate(true)
	return state

func import_state(data: Dictionary) -> void:
	learned.clear()
	# Keep unknown future IDs without activating them; round trips are lossless.
	var state: Dictionary = data.get("original_skill_state", {})
	source_quest_knowledge=SOURCE_LEARNING.restore(state,data)
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
	var buffs: Variant = world.get("active_skill_buffs")
	if buffs is Dictionary:
		for name: String in buffs.keys():
			var buff: Variant = buffs[name]
			var record := record_for(str(buff.get("skill_id", name)) if buff is Dictionary else name)
			if not record.has("reference_offline_hold523"): continue
			archived["offline_reference_buff523:" + name] = buff.duplicate(true) if buff is Dictionary else buff
			buffs.erase(name)
	migrate_slots()
	revision += 1

func migrate_slots() -> void:
	for index: int in range(world.quickslots.size()):
		var entry: Dictionary = world.quickslots[index]
		if str(entry.get("kind", "")) != "skill": continue
		var record := record_for(str(entry.get("skill_id", entry.get("id", ""))))
		if record.is_empty() or not owned(record) or (str(record.activation) == "passive" and not (world.original_skills != null and world.original_skills.stackable.handles(record))):
			archived["slot_%d" % index] = entry.duplicate(true)
			world.quickslots[index] = {}
		else:
			# Existing HUD expects the name; the extra stable ID survives renames.
			entry["skill_id"] = str(record.id)
			entry["id"] = str(record.name)
			world.quickslots[index] = entry
