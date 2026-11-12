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
var stat_rebuild_count: int = 0
const RELIC_LEVELS = preload("res://scripts/cards/relic_spell_levels.gd")

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
		record["icon"] = preferred_icon_path(record)
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
	for record: Dictionary in records:
		source523.prepare_estimate(record)
		source523.prepare_source_direct(record)
		record["effect"] = effect_for(record)
	seed_starters()


## Only ID-exact, locally installed private skill icons override generated art.
static func preferred_icon_path(record: Dictionary) -> String:
	var fallback: String = str(record.get("icon", ""))
	var skill_id: String = str(record.get("id", ""))
	if not skill_id.begins_with("lm_") or skill_id.length() != 19:
		return fallback
	for glyph: String in skill_id.substr(3):
		if not "0123456789abcdef".contains(glyph):
			return fallback
	var private_path: String = "res://assets/skills/private_icons/" + skill_id + ".png"
	if ResourceLoader.exists(private_path):
		return private_path
	var styled_path: String = "res://assets/skills/styled_icons/" + skill_id + ".svg"
	return styled_path if ResourceLoader.exists(styled_path) else fallback

static func read_json(filename: String) -> Dictionary:
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT_PATH + filename))
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
	return (bool(record.get("local_design",false)) or record.get("class_learning_levels",{}).has(str(world.job_class))) and int(world.level)<_host_minimum_level_for(record)


func permitted(record: Dictionary) -> bool:
	return record.get("classes", [record.get("class")]).has(world.job_class)

func owned(record: Dictionary) -> bool:
	if not source_learning_status(record).is_empty():return false
	if bool(record.get("runtime_blocked", false)): return false
	return permitted(record) and int(learned.get(str(record.get("id", "")), 0)) > 0

func enabled(record: Dictionary) -> bool:
	if world.get("spell_group_conversion")!=null and not world.spell_group_conversion.allows(record):return false
	if bool(record.get("runtime_blocked", false)): return false
	if not owned(record): return false
	if level_locked(record):return false
	if str(record.get("class", "")) == "요정" and str(record.get("school", "")) in ["water","earth","wind","fire"]:
		if str(record.school) != str(schools.get("요정", "water")): return false
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
	world.gold -= price
	world.inventory[str(record.book_name)] = int(world.inventory.get(str(record.book_name), 0)) + 1
	world._update_hud()
	world._save_game(true)
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
	if not supplied_book.is_empty() and world._save_game(true) != OK:
		world.inventory[book] = before_count
		learned = before_learned
		world.active_skill_buffs = before_buffs
		revision = before_revision
		world._update_hud()
		world.hud.show_message("습득 저장 실패 · 스킬북과 습득 상태 보존")
		return false
	if str(record.activation) == "passive":
		world.original_skills.vfx.emit_skill(str(record.id), "learn", world.player.global_position)
	world._refresh_speed_modifiers()
	world._update_hud()
	if supplied_book.is_empty():world._save_game(true)
	world.hud.show_message(str(record.name) + " 습득")
	return true

func _lineage_signature() -> String:
	# Tests and migration adapters may edit learned directly; hash catches those
	# alongside the normal learn/import revision without touching old save data.
	return "%d|%s|%d|%d|%d|%d" % [revision,str(world.job_class),hash(learned),records.size(),source523.revision,hash(world.equipped_items.get("weapon",{}))]

func _resolved_reference(record: Dictionary) -> Dictionary:
	var signature: String=_lineage_signature()
	signature += _relic_signature()
	if signature!=resolved_signature:
		resolved_signature=signature
		resolved_cache.clear()
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
	return source523.apply_to(result,job,family.size() > 1)

func _current_stat_signature() -> String:
	var equipped: Variant=world.equipped_items.get("weapon",{})
	return "%s|%s|%d|%d|%d" % [_lineage_signature() + _relic_signature(),str(schools.get("요정","water")),
		hash(equipped),int(world.level),records.size()]

func _ensure_stat_index() -> void:
	var signature: String=_current_stat_signature()
	if signature==stat_signature:return
	stat_signature=signature
	static_stat_totals.clear();weighted_stat_entries.clear()
	static_speed=1.0
	stat_rebuild_count+=1
	for record: Dictionary in records:
		if not enabled(record):continue
		if bool(record.get("local_design",false)):
			static_speed=maxf(static_speed,float(record.get("passive_speed",1)))
		var resolved: Dictionary=_resolved_reference(record)
		if not str(resolved.get("source523_block_reason","")).is_empty():continue
		if str(resolved.mode)!="stats":continue
		static_speed=maxf(static_speed,float(resolved.get("stats",{}).get("speed",1)))
		var stats: Dictionary=resolved.get("stats",{})
		var conditions: Dictionary=resolved.get("stat_conditions",{})
		for key: String in stats:
			var condition: Dictionary=conditions.get(key,{})
			var value: float=float(stats[key])
			if condition.has("weight_min_percent"):
				if not weighted_stat_entries.has(key):weighted_stat_entries[key]=[]
				weighted_stat_entries[key].append({"minimum":float(condition.weight_min_percent),"value":value})
			else:static_stat_totals[key]=float(static_stat_totals.get(key,0.0))+value

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
		if int(limit.LimitBuffCardID)==0 and int(limit.CharacterPolymorphGradeID)==0:
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
