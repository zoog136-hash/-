extends RefCounted
## Private 523 source evidence. No legacy-name joins or inferred server formulas.
const SOURCE_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
const ORIGINAL_INPUT = preload("res://scripts/monsters/current523_npc_input_projection.gd")
const MAX_BYTES = 16 * 1024 * 1024
const DEFINITION_TABLES = ["NpcClass","NpcAttribute","NpcSpecialResistance","NpcCategory","NpcRace","NpcAttack","SpellClass","SpellBonus","SpellCategory","TargettingType","TargetKind","BuffClass","BuffBonus","BuffGroup","Bonus","BonusType","BonusApplicationType","Unit","UIUnit","SpecialResistanceType","ElementalType","StatusEffectAttr","InvokeOption","InvokeOptionType","AttackType"]
const DEFINITION_OWNERS = {"NpcAttribute":"NpcClassID","NpcSpecialResistance":"NpcClassID","NpcRace":"NpcClassID","SpellBonus":"SpellClassID","BuffBonus":"BuffClassID","StatusEffectAttr":"StatusEffectID"}
const NPC_STAT_FIELDS = {"hp":"HP","mp":"MP","ac":"AC","mr":"MR","xp":"Exp"}
const ATTACK_STRUCTURE_FIELDS = ["ID","NpcClassID","SpellID","NextAttack","MotionType","WeaponType","AttackType","ChangeTarget","Range","Prob","FixedDelayTime","DiceCount","DiceSpots","DiceBonus"]
const SPELL_ATTACK_VIEW_FIELDS = ["ID","NpcClassID","SpellID","MotionType","WeaponType","Range"]
var content: Dictionary = {}
var error: String = ""
var indexes: Dictionary = {}
var source_mode: String = "current523_original"
var source_available: bool = false
var source_identity: Dictionary = {}
var source_model_sha256: String = ""
var admitted_source_identities: Dictionary = {}
var deferred_npc_inputs: Dictionary = {}
var source_status: Dictionary = {}
var _original_input = ORIGINAL_INPUT.new()

func configure_original() -> bool:
	source_mode = "current523_original"
	var identity: Dictionary = DEFINITIONS.identity()
	if content.get("input_kind")!="twilight.current523.npc-input.v1":
		content = {"kind":"patch523_npc_spell_catalog","schema":1,"source_snapshot":"patch523",
			"input_kind":"twilight.current523.npc-input.v1","source_archive_sha256":SOURCE_SHA,
			"tables":{},"boss_npc_ids":[],"host_extension_npc_ids":[]}
		indexes = {}
		admitted_source_identities = {}
		source_model_sha256 = ""
	if identity.is_empty() or identity.get("source_sha256")!=SOURCE_SHA:
		source_available = false
		error = "current523_original_unavailable:"+DEFINITIONS.problem()
		source_status = {"state":"unavailable","reason":error}
		return false
	if not source_identity.is_empty() and source_identity!=identity:
		source_available = false
		error = "current523_original_identity_changed"
		source_status = {"state":"unavailable","reason":error}
		return false
	source_identity = identity.duplicate(true)
	if source_model_sha256.is_empty():
		var initial: Dictionary = _original_input.build([])
		if initial.is_empty():
			source_available = false
			error = _original_input.problem
			source_status = {"state":"unavailable","reason":error}
			return false
		_publish_original(initial)
	source_available = true
	error = ""
	source_status = {"state":"available","mode":source_mode,"visual":"independent_current_visual_pin_required"}
	return true

func _publish_original(candidate: Dictionary) -> void:
	content = candidate
	indexes = {}
	for pair: Array in [["NpcAttack","NpcClassID"],["NpcAttribute","NpcClassID"],["NpcSpecialResistance","NpcClassID"],["NpcRace","NpcClassID"],["SpellBonus","SpellClassID"],["BuffBonus","BuffClassID"],["StatusEffectAttr","StatusEffectID"],["LandAttribute","LandID"]]:
		var index: Dictionary = {}
		for entry: Dictionary in content.tables.get(pair[0],{}).values():
			if not source_integer(entry.row.get(pair[1])): continue
			var owner: String = str(int(entry.row[pair[1]]))
			if not index.has(owner): index[owner] = []
			index[owner].append(entry.row)
		indexes[pair[0]] = index
	# This is the actual in-memory registry payload, never a legacy manifest or
	# source-archive fingerprint. No model/pack/receipt is written to disk.
	source_model_sha256 = JSON.stringify(content,"",true,true).sha256_text()

func _admit_original_actor(source: Dictionary) -> bool:
	if not configure_original(): return false
	var id: String = str(int(source.ID))
	if admitted_source_identities.has(id): return true
	var ids: Array = []
	for admitted: String in admitted_source_identities: ids.append(int(admitted))
	ids.append(int(source.ID))
	var candidate: Dictionary = _original_input.build(ids)
	if candidate.is_empty():
		error = _original_input.problem
		deferred_npc_inputs[id] = error
		return false
	_publish_original(candidate)
	admitted_source_identities[id] = {"npc_class_id":source.ID,"sprite":source.Sprite,"desc_id":source.DescId,
		"source_snapshot":"patch523","source_archive_sha256":SOURCE_SHA}
	deferred_npc_inputs.erase(id)
	error = ""
	return true

func load_pack(manifest_path: String, expected_sha: String) -> bool:
	# Kept for historical compatibility; the final input mode cannot activate
	# an old manifest or use its selection as an admission prerequisite.
	if source_mode=="current523_original": error = "legacy_npc_pack_excluded_from_final_input"; return false
	content = {}; indexes = {}; error = ""
	if expected_sha.length() != 64 or not FileAccess.file_exists(manifest_path):
		error = "manifest_sha_mismatch"; return false
	var manifest_file: FileAccess = FileAccess.open(manifest_path,FileAccess.READ)
	if manifest_file == null or manifest_file.get_length() > 65536:
		error = "manifest_too_large"; return false
	if FileAccess.get_sha256(manifest_path) != expected_sha:
		error = "manifest_sha_mismatch"; return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary or manifest.get("kind") != "patch523_npc_spell_pack" or int(manifest.get("schema", 0)) != 1 or manifest.get("source_archive_sha256") != SOURCE_SHA:
		error = "manifest_contract_mismatch"; return false
	if manifest.get("catalog_file") != "npc_spells.json":
		error = "catalog_path_rejected"; return false
	var path: String = manifest_path.get_base_dir().path_join("npc_spells.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > MAX_BYTES or file.get_length() != int(manifest.get("catalog_bytes", -1)):
		error = "catalog_size_mismatch"; return false
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	if FileAccess.get_sha256(path) != manifest.get("catalog_sha256"):
		error = "catalog_sha_mismatch"; return false
	var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary or value.get("kind") != "patch523_npc_spell_catalog" or value.get("source_snapshot") != "patch523" or int(value.get("schema", 0)) != 1 or value.get("source_archive_sha256") != SOURCE_SHA:
		error = "catalog_contract_mismatch"; return false
	if not value.get("tables") is Dictionary or not value.get("boss_npc_ids") is Array:
		error = "catalog_tables_missing"; return false
	for table: String in value.tables:
		if not value.tables[table] is Dictionary or value.tables[table].size() != int(manifest.get("table_counts", {}).get(table, -1)):
			error = "table_count_mismatch"; return false
		for key: String in value.tables[table]:
			var entry: Variant = value.tables[table][key]
			if not entry is Dictionary or not entry.get("row") is Dictionary or int(entry.get("source_row_1based", 0)) <= 0:
				error = "source_row_missing"; return false
			if entry.row.has("ID") and str(int(entry.row.ID)) != key:
				error = "source_id_mismatch"; return false
	content = value
	for pair: Array in [["NpcAttack", "NpcClassID"], ["NpcAttribute", "NpcClassID"], ["NpcSpecialResistance", "NpcClassID"], ["NpcRace", "NpcClassID"], ["SpellBonus", "SpellClassID"], ["BuffBonus", "BuffClassID"], ["StatusEffectAttr", "StatusEffectID"], ["LandAttribute", "LandID"]]:
		var index: Dictionary = {}
		for entry: Dictionary in content.tables.get(pair[0], {}).values():
			var owner: String = str(int(entry.row.get(pair[1], -1)))
			if not index.has(owner): index[owner] = []
			index[owner].append(entry.row)
		indexes[pair[0]] = index
	return true

func row(table: String, id: int) -> Dictionary:
	if not source_available or content.get("input_kind")!="twilight.current523.npc-input.v1": return {}
	var selected: Dictionary = content.get("tables",{}).get(table,{}).get(str(id),{}).get("row",{}).duplicate(true)
	return _selected_spell_attack_view(selected) if table=="NpcAttack" else selected

func owned(table: String, id: int) -> Array:
	# Only the newly admitted original registry owns these sets. Empty sets are
	# authoritative; neither a legacy cache nor a larger source relation fills them.
	if not source_available or content.get("input_kind")!="twilight.current523.npc-input.v1": return []
	var selected: Array = indexes.get(table,{}).get(str(id),[]).duplicate(true)
	if table=="NpcAttack":
		for position: int in range(selected.size()): selected[position] = _selected_spell_attack_view(selected[position])
	return selected

func _selected_spell_attack_view(attack: Dictionary) -> Dictionary:
	# This is an input substitution for an already admitted attack, never an
	# attack/owner discovery path. A view ID alone does not establish a join.
	if not source_available or source_mode!="current523_original" or content.get("input_kind")!="twilight.current523.npc-input.v1" or content.get("source_archive_sha256")!=SOURCE_SHA: return attack
	var identity: Dictionary = DEFINITIONS.identity()
	if identity.is_empty() or identity.get("source_sha256")!=SOURCE_SHA or identity!=source_identity: return attack
	for field: String in SPELL_ATTACK_VIEW_FIELDS:
		if not source_integer(attack.get(field)): return attack
	var attack_id := int(attack.ID)
	var npc_id := int(attack.NpcClassID)
	var admitted: Dictionary = admitted_source_identities.get(str(npc_id),{})
	if not source_integer(admitted.get("npc_class_id")) or int(admitted.npc_class_id)!=npc_id or admitted.get("source_archive_sha256")!=SOURCE_SHA: return attack
	var selected: Dictionary = content.get("tables",{}).get("NpcAttack",{}).get(str(attack_id),{}).get("row",{})
	var npc: Dictionary = content.get("tables",{}).get("NpcClass",{}).get(str(npc_id),{}).get("row",{})
	if selected.is_empty() or selected!=attack or npc.is_empty() or not source_integer(npc.get("ID")) or int(npc.ID)!=npc_id: return attack
	for pair: Array in [["sprite","Sprite"],["desc_id","DescId"]]:
		if not source_integer(admitted.get(pair[0])) or not source_integer(npc.get(pair[1])) or admitted[pair[0]]!=npc[pair[1]]: return attack
	var original: Dictionary = DEFINITIONS.row("NpcAttack",attack_id)
	if original.is_empty() or original!=attack: return attack
	if not DEFINITIONS.declared_exclusion("NpcAttack",original).is_empty() or not DEFINITIONS.declared_exclusion("NpcClass",npc).is_empty(): return attack
	var matches: Array[Dictionary] = DEFINITIONS.related("ViewNpcSpellAttack","ID",attack_id)
	if matches.size()!=1: return attack
	var view: Dictionary = matches[0]
	if view.size()!=SPELL_ATTACK_VIEW_FIELDS.size() or not DEFINITIONS.declared_exclusion("ViewNpcSpellAttack",view).is_empty(): return attack
	for field: String in SPELL_ATTACK_VIEW_FIELDS:
		if not source_integer(view.get(field)) or view[field]!=attack[field]: return attack
	# Preserve every NpcAttack-only value, key and owner. No view metadata is
	# inserted into the raw attack identity; units and execution remain unchanged.
	var result: Dictionary = attack.duplicate(true)
	for field: String in SPELL_ATTACK_VIEW_FIELDS: result[field] = view[field]
	return result

func _selected_definition_row(table: String, compiled: Dictionary) -> Dictionary:
	if table == "NpcAttack": return selected_attack_row(compiled)
	if not DEFINITION_TABLES.has(table) or not source_integer(compiled.get("ID")): return compiled
	var id: int = int(compiled.ID)
	var selected: Dictionary = content.get("tables",{}).get(table,{}).get(str(id),{}).get("row",{})
	if selected.is_empty() or selected != compiled: return compiled
	# Read only an existing compiled identity. Full-row equality retains every
	# condition and foreign owner; it never imports a larger original relation.
	var original: Dictionary = DEFINITIONS.row(table,id)
	if original.is_empty() or not source_integer(original.get("ID")) or int(original.ID)!=id or original != compiled: return compiled
	return original

func selected_attack_row(compiled: Dictionary) -> Dictionary:
	if not source_integer(compiled.get("ID")) or not source_integer(compiled.get("NpcClassID")): return compiled
	var selected: Dictionary = content.get("tables",{}).get("NpcAttack",{}).get(str(int(compiled.ID)),{}).get("row",{})
	var npc: Dictionary = content.get("tables",{}).get("NpcClass",{}).get(str(int(compiled.NpcClassID)),{}).get("row",{})
	if selected.is_empty() or npc.is_empty() or not source_integer(npc.get("ID")) or int(npc.ID) != int(compiled.NpcClassID): return compiled
	# The compiled graph remains the admission contract. Only an already
	# selected NPC/attack may obtain its values from the pinned original table.
	var original: Dictionary = DEFINITIONS.row("NpcAttack",int(compiled.ID))
	if original.is_empty(): return compiled
	for field: String in ATTACK_STRUCTURE_FIELDS:
		if not source_integer(compiled.get(field)) or not source_integer(selected.get(field)) or not source_integer(original.get(field)): return compiled
		if compiled[field] != selected[field] or compiled[field] != original[field]: return compiled
	for field: String in ["IsSpell","IsAbsoluteAtk"]:
		if typeof(compiled.get(field)) != TYPE_BOOL or typeof(selected.get(field)) != TYPE_BOOL or typeof(original.get(field)) != TYPE_BOOL: return compiled
		if compiled[field] != selected[field] or compiled[field] != original[field]: return compiled
	# Prob and delay are compared above, never interpreted or used to schedule
	# a new action. Missing or changed structure always retains the compiled row.
	return original

static func source_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

static func definition_eligible(source: Dictionary) -> bool:
	if source.is_empty() or not source.get("TestNPC") is bool or bool(source.TestNPC): return false
	if not DEFINITIONS.declared_exclusion("NpcClass",source).is_empty(): return false
	if not source_integer(source.get("Category")): return false
	var category: Dictionary = DEFINITIONS.row("NpcCategory",int(source.Category))
	if not category.get("IsAttackable") is bool or not bool(category.IsAttackable): return false
	var category_name: String = str(category.get("Name",""))
	if category_name in ["SiegeNpc","SiegeTurret","BattleArenaSkillCoin","BattleArenaConchShell","Test"]: return false
	# Only the already supplied, attackable category declarations are projected.
	# Unknown categories retain their prior data; names never imply eligibility.
	return category_name in ["Npc","Orc","Elf","Kobolds","Slime","Wolf","Guard","Citizen","PartyNpc","PartyImportantNpc","LastavardGateKeeper","Companion"]

func npc_definition(npc_id: int) -> Dictionary:
	var source: Dictionary = DEFINITIONS.row("NpcClass",npc_id)
	if not definition_eligible(source): return {}
	var attacks: Array[Dictionary] = DEFINITIONS.related("NpcAttack","NpcClassID",npc_id)
	var special: Array[Dictionary] = []
	for link: Dictionary in DEFINITIONS.related("NpcSpecialResistance","NpcClassID",npc_id):
		if not source_integer(link.get("SpecialResistanceTypeID")): continue
		special.append({"link":link,"type":DEFINITIONS.row("SpecialResistanceType",int(link.SpecialResistanceTypeID)),"can_execute":false,"reference_only":true})
	return {"npc":source,"category":DEFINITIONS.row("NpcCategory",int(source.Category)),
		"attributes":DEFINITIONS.related("NpcAttribute","NpcClassID",npc_id),
		"special_resistances":special,"races":DEFINITIONS.related("NpcRace","NpcClassID",npc_id),
		"attacks":attacks,"can_execute":false,"reference_only":true,
		"source_snapshot":"patch523","source_archive_sha256":SOURCE_SHA,
		"remaining_contract":"NpcAttributeType/AI/probability/timing and additional attack activation require their existing owner; raw resistance values are not a new status formula"}

func attack_definition(npc_id: int, attack_id: int) -> Dictionary:
	var npc: Dictionary = DEFINITIONS.row("NpcClass",npc_id)
	var source: Dictionary = DEFINITIONS.row("NpcAttack",attack_id)
	if not definition_eligible(npc) or source.is_empty() or not source_integer(source.get("NpcClassID")) or int(source.NpcClassID) != npc_id: return {}
	var spell: Dictionary = {}
	if source.get("IsSpell") is bool and bool(source.IsSpell) and source_integer(source.get("SpellID")):
		spell = DEFINITIONS.row("SpellClass",int(source.SpellID))
	return {"source":source,"npc":npc,"spell":spell,"can_execute":false,"reference_only":true,
		"compiled_attack_available":not attack(npc_id,attack_id).is_empty(),
		"source_snapshot":"patch523","source_archive_sha256":SOURCE_SHA,
		"remaining_contract":"existing compiled attack choices only; no new MotionType, probability, target or clock interpretation"}

func project_actor_record(record: Dictionary) -> Dictionary:
	# This adapter changes data on an existing source actor only. It never
	# creates an encounter, replaces its pixels, changes a spawn level or grants loot.
	var prior: Variant = record.get("source_m_original")
	if not prior is Dictionary or not source_integer(record.get("source_m_npc_id")): return record
	var npc_id: int = int(record.source_m_npc_id)
	if not source_integer(prior.get("ID")) or int(prior.ID) != npc_id: return record
	var source: Dictionary = DEFINITIONS.row("NpcClass",npc_id)
	if not definition_eligible(source): return record
	for key: String in ["ID","Sprite","DescId"]:
		if not source_integer(source.get(key)) or not source_integer(prior.get(key)) or source[key] != prior[key]: return record
	for key: String in ["HP","MP","AC","MR","Exp","Str","Dex","Con","Wis","Cha","Int"]:
		if not source_integer(source.get(key)): return record
	if int(source.HP) <= 0 or int(source.MP) < 0 or int(source.MR) < 0 or int(source.Exp) < 0: return record
	# Monster.setup already proves this is an existing actor. The exact prior
	# ID/Sprite/DescId checks above gate admission; no actor/spawn is constructed.
	if not _admit_original_actor(source): return record
	var result: Dictionary = record.duplicate(true)
	var original: Dictionary = prior.duplicate(true)
	original.merge(source,true)
	# The persisted m508 encounter identity and explicit spawn-context level stay
	# intact; content version describes the values, not a new identity namespace.
	result["source_m_original"] = original
	result["source_m_definition_snapshot"] = "patch523"
	result["source_m_definition_archive_sha256"] = SOURCE_SHA
	for field_name: String in NPC_STAT_FIELDS:
		result[field_name] = int(source[NPC_STAT_FIELDS[field_name]])
	return result

func attack(npc_id: int, attack_id: int) -> Dictionary:
	for source: Dictionary in owned("NpcAttack",npc_id):
		if int(source.ID) == attack_id and int(source.NpcClassID) == npc_id: return source
	return {}

func attack_roots(npc_id: int) -> Array:
	var incoming: Dictionary = {}
	for source: Dictionary in owned("NpcAttack",npc_id):
		var next: int = int(source.get("NextAttack",0))
		if next > 0 and not attack(npc_id,next).is_empty(): incoming[next] = true
	var roots: Array = []
	for source: Dictionary in owned("NpcAttack",npc_id):
		if not incoming.has(int(source.ID)): roots.append(source)
	return roots

func attack_chain(npc_id: int, attack_id: int, visited: Array = []) -> Dictionary:
	if visited.has(attack_id) or visited.size() >= 32: return {"id":attack_id,"pending":"cycle_or_depth_limit"}
	var source: Dictionary = attack(npc_id,attack_id)
	if source.is_empty(): return {"id":attack_id,"pending":"missing_or_different_npc_attack"}
	var result: Dictionary = {"source":source}
	var next: int = int(source.get("NextAttack",0))
	if next > 0:
		var seen: Array = visited.duplicate(); seen.append(attack_id)
		result["next"] = attack_chain(npc_id,next,seen)
	return result

func ai_evidence(npc_id: int) -> Dictionary:
	var ids: Array = []
	for source: Dictionary in attack_roots(npc_id): ids.append(int(source.ID))
	return {"native_ai_id_raw":row("NpcClass",npc_id).get("AI",0),"host_graph_root_ids":ids,"native_ai_definition":"not_resolved_by_NpcClass_AI_integer","host_policy":"graph roots then exact NextAttack; existing clock; no source Prob denominator/phase inferred"}

func bonuses(table: String, id: int) -> Array:
	var result: Array = []
	for link: Dictionary in owned(table, id):
		var bonus: Dictionary = row("Bonus", int(link.BonusID))
		var type: Dictionary = row("BonusType", int(bonus.get("BonusTypeID", -1)))
		result.append({"link":link,"bonus":bonus,"type":type,"unit":row("Unit",int(type.get("UnitID",-1)))})
	return result

func values(table: String, id: int, name: String, unit: String = "") -> Array:
	var result: Array = []
	for detail: Dictionary in bonuses(table, id):
		# Conditions are retained in bonuses(), never collapsed into unconditional values.
		if detail.type.get("Name") != name or int(detail.bonus.get("BonusApplicationTypeID",-1)) != 0 or int(detail.bonus.get("BonusApplicationTargetID",-1)) != 0: continue
		if int(detail.link.get("MinSpellLevel",0)) != 0 or int(detail.link.get("CharacterLevel",0)) != 0 or int(detail.link.get("CharacterClass",0)) != 0: continue
		if not unit.is_empty() and detail.unit.get("Name") != unit: continue
		result.append(detail.bonus.Value)
	return result

func scalar(table: String, id: int, name: String, unit: String = "", fallback: float = 0.0) -> float:
	var found: Array = values(table,id,name,unit)
	return float(found[0]) if found.size() == 1 else fallback

func spell_chain(id: int, visited: Array = []) -> Dictionary:
	if visited.has(id) or visited.size() >= 32: return {"id":id,"pending":"cycle_or_depth_limit"}
	var source: Dictionary = row("SpellClass",id)
	if source.is_empty(): return {"id":id,"pending":"missing_spell"}
	var next_seen: Array = visited.duplicate(); next_seen.append(id)
	var next: Array = []
	for detail: Dictionary in bonuses("SpellBonus",id):
		if detail.type.get("Name") == "NextSpellClassID" and detail.unit.get("Name") == "SpellClassID":
			next.append({"edge":detail,"spell":spell_chain(int(detail.bonus.Value),next_seen)})
	return {"source":source,"bonuses":bonuses("SpellBonus",id),"next":next}

func buff_details(id: int) -> Dictionary:
	var source: Dictionary = row("BuffClass",id)
	var statuses: Array = []; var invokes: Array = []
	for detail: Dictionary in bonuses("BuffBonus",id):
		if detail.type.get("Name") == "StatusEffectID":
			statuses.append({"id":int(detail.bonus.Value),"attributes":owned("StatusEffectAttr",int(detail.bonus.Value))})
		if detail.type.get("Name") == "InvokeOption":
			# Invoke target is ApplicationTargetID, not probability Value.
			invokes.append({"edge":detail,"source":row("InvokeOption",int(detail.bonus.get("BonusApplicationTargetID",0)))})
	return {"source":source,"group":row("BuffGroup",int(source.get("BuffGroupID",0))),"bonuses":bonuses("BuffBonus",id),"statuses":statuses,"invokes":invokes}

func duration(id: int) -> Vector2:
	var fixed: Array = values("SpellBonus",id,"SpellBuffDuration","Seconds")
	if fixed.size() == 1: return Vector2(float(fixed[0]),float(fixed[0]))
	var low: Array = values("SpellBonus",id,"SpellDebuffMinDuration","Seconds")
	var high: Array = values("SpellBonus",id,"SpellDebuffMaxDuration","Seconds")
	return Vector2(float(low[0]),float(high[0])) if low.size() == 1 and high.size() == 1 else Vector2.ZERO

func environment_buffs(land_id: int) -> Array:
	var result: Array = []
	for attribute: Dictionary in owned("LandAttribute",land_id):
		var type: Dictionary = row("LandAttributeType",int(attribute.LandAttributeTypeID))
		if type.get("Name") != "NpcBuff": continue
		result.append({"attribute":attribute,"territory":row("Territories",int(attribute.TerritoryID)),"buff":buff_details(int(attribute.Value)),"application":"requires_verified_position_and_environment_lifecycle"})
	return result
