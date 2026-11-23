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
const NUMERIC_INPUT_POLICY_PATH = "res://data/monsters/current523_numeric_input_policy.json"
const NPC_RANGE_INPUT_POLICY_PATH = "res://data/monsters/current523_npc_range_input_policy.json"
const NPC_RESISTANCE_FIELDS = {"fire":"FireResistance","water":"WaterResistance","earth":"EarthResistance","wind":"AirResistance"}
const NPC_SPECIAL_RESISTANCE_FIELDS = {"Stun":"stun_resistance","Hold":"hold_resistance","Fear":"fear_resistance"}
var content: Dictionary = {}
var error: String = ""
var indexes: Dictionary = {}
var source_mode: String = "current523_original"
var source_available: bool = false
var source_identity: Dictionary = {}
## SHA-256 of JSON.stringify(content, "", true, true). Serialising the whole
## payload on every newly admitted monster kind grew with the admitted set
## (desktop 60 ms -> 125 ms per kind by 200 kinds; ~0.4 s on the phone), so
## it is computed only when read. Spawn provenance uses
## admitted_registry_ids_sha256() instead.
var _model_sha: String = ""
var _model_dirty: bool = false
var source_model_sha256: String = "":
	get:
		if _model_dirty:
			_model_sha = JSON.stringify(content,"",true,true).sha256_text()
			_model_dirty = false
		return _model_sha
	set(value):
		_model_sha = value
		_model_dirty = false
## Owner index rows already appended, per table (incremental _publish_original).
var _indexed_keys: Dictionary = {}
var _indexes_built: Dictionary = {}
var admitted_source_identities: Dictionary = {}
var deferred_npc_inputs: Dictionary = {}
var source_status: Dictionary = {}
var _original_input = ORIGINAL_INPUT.new()
## res:// input policies are fixed for the run. Every spawn projection read,
## parsed and hashed the same small JSON files up to three times; keep each
## parse and SHA-256 once (two entries, a few KB).
static var _policy_files: Dictionary = {}

static func _policy_file(path: String) -> Dictionary:
	if _policy_files.has(path): return _policy_files[path]
	var entry: Dictionary = {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file != null:
		var bytes: PackedByteArray = file.get_buffer(file.get_length())
		file.close()
		var parser := JSON.new()
		var hashing := HashingContext.new()
		if parser.parse(bytes.get_string_from_utf8())==OK and parser.data is Dictionary and hashing.start(HashingContext.HASH_SHA256)==OK and hashing.update(bytes)==OK:
			entry = {"policy":parser.data,"sha256":hashing.finish().hex_encode()}
	_policy_files[path] = entry
	return entry

func configure_original() -> bool:
	source_mode = "current523_original"
	var identity: Dictionary = DEFINITIONS.identity()
	if content.get("input_kind")!="twilight.current523.npc-input.v1":
		content = {"kind":"patch523_npc_spell_catalog","schema":1,"source_snapshot":"patch523",
			"input_kind":"twilight.current523.npc-input.v1","source_archive_sha256":SOURCE_SHA,
			"tables":{},"boss_npc_ids":[],"host_extension_npc_ids":[]}
		indexes = {}
		_indexed_keys = {}
		admitted_source_identities = {}
		_ids_sha_count = -1
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
	if _model_sha.is_empty() and not _model_dirty:
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

const INDEX_OWNERS: Array = [["NpcAttack","NpcClassID"],["NpcAttribute","NpcClassID"],["NpcSpecialResistance","NpcClassID"],["NpcRace","NpcClassID"],["SpellBonus","SpellClassID"],["BuffBonus","BuffClassID"],["StatusEffectAttr","StatusEffectID"],["LandAttribute","LandID"]]

func _publish_original(candidate: Dictionary) -> void:
	content = candidate
	# A grown selection keeps every earlier entry (same insertion order) and
	# appends new ones, so appending only the new rows gives the same owner
	# lists as a full rebuild. Anything else (reset, foreign indexes, a
	# missing earlier key) rebuilds in full.
	var incremental: bool = is_same(indexes,_indexes_built) and not _indexed_keys.is_empty()
	if incremental:
		for pair: Array in INDEX_OWNERS:
			var seen: Dictionary = _indexed_keys.get(pair[0],{})
			var still: int = 0
			for key: Variant in content.tables.get(pair[0],{}):
				if seen.has(key): still += 1
			if still != seen.size(): incremental = false; break
	if not incremental:
		indexes = {}
		_indexed_keys = {}
		_indexes_built = indexes
	for pair: Array in INDEX_OWNERS:
		if not indexes.has(pair[0]): indexes[pair[0]] = {}
		if not _indexed_keys.has(pair[0]): _indexed_keys[pair[0]] = {}
		var index: Dictionary = indexes[pair[0]]
		var seen: Dictionary = _indexed_keys[pair[0]]
		var table: Dictionary = content.tables.get(pair[0],{})
		for key: Variant in table:
			if seen.has(key): continue
			seen[key] = true
			var entry: Dictionary = table[key]
			if not source_integer(entry.row.get(pair[1])): continue
			var owner: String = str(int(entry.row[pair[1]]))
			if not index.has(owner): index[owner] = []
			index[owner].append(entry.row)
	# This is the actual in-memory registry payload, never a legacy manifest or
	# source-archive fingerprint. No model/pack/receipt is written to disk.
	_model_sha = ""
	_model_dirty = true

## The admitted registry payload is a pure function of the source archive,
## the admitted NpcClass IDs and this projection code. Spawn provenance names
## it by those IDs (O(kinds)); the full payload digest (source_model_sha256,
## O(payload) ~1.6 MB JSON at 200 kinds) is computed only when read.
var _ids_sha: String = ""
var _ids_sha_count: int = -1

func admitted_registry_ids_sha256() -> String:
	if _ids_sha_count < 0:
		var ids: Array = []
		for id: String in admitted_source_identities: ids.append(int(id))
		ids.sort()
		_ids_sha = (SOURCE_SHA + "|" + JSON.stringify(ids)).sha256_text()
		_ids_sha_count = admitted_source_identities.size()
	return _ids_sha

func _admit_original_actor(source: Dictionary) -> bool:
	if not configure_original(): return false
	var id: String = str(int(source.ID))
	if admitted_source_identities.has(id): return true
	var ids: Array = []
	for admitted: String in admitted_source_identities: ids.append(int(admitted))
	ids.append(int(source.ID))
	var candidate: Dictionary = _original_input.extend(ids)
	if candidate.is_empty():
		error = _original_input.problem
		deferred_npc_inputs[id] = error
		return false
	_publish_original(candidate)
	_ids_sha_count = -1
	admitted_source_identities[id] = {"npc_class_id":source.ID,"sprite":source.Sprite,"desc_id":source.DescId,
		"source_snapshot":"patch523","source_archive_sha256":SOURCE_SHA}
	deferred_npc_inputs.erase(id)
	error = ""
	return true

func load_pack(manifest_path: String, expected_sha: String) -> bool:
	# Kept for historical compatibility; the final input mode cannot activate
	# an old manifest or use its selection as an admission prerequisite.
	if source_mode=="current523_original": error = "legacy_npc_pack_excluded_from_final_input"; return false
	content = {}; indexes = {}; _indexed_keys = {}; error = ""
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
	result = _project_numeric_resistance_input(result,source)
	result = _project_named_special_resistance_input(result,source)
	return _project_uniform_attack_range_input(result,source)

func _project_numeric_resistance_input(record: Dictionary, source: Dictionary) -> Dictionary:
	# Called only after the same exact actor/source admission above. This is an
	# explicitly adjustable TWILIGHT input-scale estimate, not recovered native
	# resistance units or a replacement for the existing damage formula.
	var policy_file: Dictionary = _policy_file(NUMERIC_INPUT_POLICY_PATH)
	if policy_file.is_empty(): return record
	var policy: Dictionary = policy_file.policy
	if policy.get("schema")!="twilight.current523.numeric-input-policy.v1" or policy.get("source_snapshot")!="patch523" or policy.get("source_sha256")!=SOURCE_SHA: return record
	if not policy.get("enabled") is bool or not policy.enabled: return record
	if policy.get("origin")!="twilight_adjustable_numeric_estimate" or policy.get("source_raw_unit_scale")!="unconfirmed" or policy.get("native_server_damage_formula_recovered")!=false or policy.get("host_formula")!="existing_host_formula_retained": return record
	var raw_multiplier: Variant = policy.get("raw_resistance_to_host_percent")
	if typeof(raw_multiplier) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(raw_multiplier)) or float(raw_multiplier)<0.0: return record
	var multiplier := float(raw_multiplier)
	var projected: Dictionary = {}
	var fields: Dictionary = {}
	for channel: String in NPC_RESISTANCE_FIELDS:
		var field: String = NPC_RESISTANCE_FIELDS[channel]
		if not source_integer(source.get(field)): return record
		var raw: Variant = source[field]
		var value: float = float(raw)*multiplier
		if not is_finite(value): return record
		projected[channel] = value
		fields[channel] = {"source_field":field,"raw_value":raw,"host_percent_input":value}
	# Keep other already supplied channels. Air -> wind is the existing mobile
	# channel spelling in World.resolve_patch523_npc_hit; no enum is inferred.
	var prior: Variant = record.get("element_resistance",{})
	var resistance: Dictionary = prior.duplicate(true) if prior is Dictionary else {}
	resistance.merge(projected,true)
	var policy_sha: String = str(policy_file.sha256)
	record["element_resistance"] = resistance
	record["source_m_numeric_input_policy"] = {"origin":"twilight_adjustable_numeric_estimate",
		"policy_path":NUMERIC_INPUT_POLICY_PATH,"policy_schema":policy.schema,"policy_sha256":policy_sha,
		"source":source_identity.duplicate(true),"npc_class_id":source.ID,"source_raw_unit_scale":"unconfirmed",
		"raw_resistance_to_host_percent":multiplier,"fields":fields,
		"native_server_damage_formula_recovered":false,"host_formula":"existing_host_formula_retained"}
	return record

func _project_named_special_resistance_input(record: Dictionary, source: Dictionary) -> Dictionary:
	# Existing admitted actor -> existing Monster.setup resistance operands.
	# The original numeric unit is unconfirmed; only an explicitly enabled
	# TWILIGHT estimate may supply a finite value below the host immunity gate.
	var identity: Dictionary = DEFINITIONS.identity()
	if identity.is_empty() or not source_available or source_mode!="current523_original" or source_identity!=identity or not source_integer(source.get("ID")) or int(source.ID)<=0: return record
	var npc_id: int = int(source.ID)
	if record.get("source_m_npc_id")!=npc_id or record.get("source_m_definition_snapshot")!="patch523" or record.get("source_m_definition_archive_sha256")!=SOURCE_SHA: return record
	if row("NpcClass",npc_id)!=source or DEFINITIONS.row("NpcClass",npc_id)!=source or not definition_eligible(source): return record
	var admitted: Variant = admitted_source_identities.get(str(npc_id))
	if not admitted is Dictionary or admitted.get("npc_class_id")!=npc_id or admitted.get("sprite")!=source.get("Sprite") or admitted.get("desc_id")!=source.get("DescId") or admitted.get("source_archive_sha256")!=SOURCE_SHA: return record
	var original: Variant = record.get("source_m_original")
	if not original is Dictionary: return record
	for field: String in source:
		if not original.has(field) or original[field]!=source[field]: return record
	var policy_file: Dictionary = _policy_file(NUMERIC_INPUT_POLICY_PATH)
	if policy_file.is_empty(): return record
	var policy: Dictionary = policy_file.policy
	if policy.get("schema")!="twilight.current523.numeric-input-policy.v1" or policy.get("source_snapshot")!="patch523" or policy.get("source_sha256")!=SOURCE_SHA: return record
	if typeof(policy.get("enabled"))!=TYPE_BOOL or not policy.enabled or policy.get("origin")!="twilight_adjustable_numeric_estimate" or policy.get("source_raw_unit_scale")!="unconfirmed" or typeof(policy.get("native_server_damage_formula_recovered"))!=TYPE_BOOL or policy.native_server_damage_formula_recovered or policy.get("host_formula")!="existing_host_formula_retained": return record
	var nested: Variant = policy.get("special_resistance")
	if not nested is Dictionary or typeof(nested.get("enabled"))!=TYPE_BOOL or not nested.enabled: return record
	if nested.get("origin")!="twilight_adjustable_numeric_estimate" or nested.get("scope")!="admitted_actor_NpcSpecialResistance_named_Stun_Hold_Fear_only" or nested.get("source_raw_unit_scale")!="unconfirmed" or typeof(nested.get("native_server_status_formula_recovered"))!=TYPE_BOOL or nested.native_server_status_formula_recovered or nested.get("host_formula")!="existing_host_status_formula_retained": return record
	var scale: Variant = nested.get("raw_to_host_percent")
	if typeof(scale) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(scale)) or float(scale)<0.0: return record
	var grouped: Dictionary = {}
	# The admitted registry owns this complete set, including an empty set.
	# Never fill it with a larger table or a former NPC pack as a fallback.
	for link: Dictionary in owned("NpcSpecialResistance",npc_id):
		if not source_integer(link.get("ID")) or int(link.ID)<0 or link.get("NpcClassID")!=npc_id or not source_integer(link.get("SpecialResistanceTypeID")): return record
		var originals: Array[Dictionary] = DEFINITIONS.related("NpcSpecialResistance","ID",int(link.ID))
		if originals.size()!=1 or originals[0]!=link or row("NpcSpecialResistance",int(link.ID))!=link: return record
		var type_id: int = int(link.SpecialResistanceTypeID)
		var types: Array[Dictionary] = DEFINITIONS.related("SpecialResistanceType","ID",type_id)
		if types.size()!=1 or row("SpecialResistanceType",type_id)!=types[0] or not source_integer(types[0].get("ID")) or int(types[0].ID)!=type_id: return record
		var type: Dictionary = types[0]
		var name_value: Variant = type.get("Name")
		if not name_value is String or not NPC_SPECIAL_RESISTANCE_FIELDS.has(name_value): continue
		if not grouped.has(name_value): grouped[name_value] = []
		grouped[name_value].append({"link":link,"type":type})
	if grouped.is_empty(): return record
	var applied: Dictionary = {}; var evidence: Dictionary = {}
	for name_value: String in grouped:
		var field: String = NPC_SPECIAL_RESISTANCE_FIELDS[name_value]
		var entries: Array = grouped[name_value]
		var detail: Dictionary = {"field":field,"source_rows":entries,"prior_present":record.has(field),
			"prior":record.get(field),"applied":false,"raw_to_host_percent":scale,"source_raw_unit_scale":"unconfirmed"}
		evidence[name_value] = detail
		if entries.size()!=1:
			detail["hold_reason"] = "multiple_source_rows_for_status_channel"
			continue
		var link: Dictionary = entries[0].link
		var type: Dictionary = entries[0].type
		var link_exclusion: Dictionary = DEFINITIONS.declared_exclusion("NpcSpecialResistance",link)
		var type_exclusion: Dictionary = DEFINITIONS.declared_exclusion("SpecialResistanceType",type)
		if not link_exclusion.is_empty() or not type_exclusion.is_empty():
			detail["hold_reason"] = "source_declared_exclusion"
			detail["declared_exclusion"] = {"link":link_exclusion,"type":type_exclusion}
			continue
		var raw: Variant = link.get("Value")
		detail["raw_value"] = raw
		if typeof(raw) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(raw)) or float(raw)<0.0:
			detail["hold_reason"] = "invalid_or_negative_source_value"
			continue
		var value: float = float(raw)*float(scale)
		detail["derived_host_percent"] = value
		if not is_finite(value) or value<0.0 or value>=100.0:
			detail["hold_reason"] = "derived_value_outside_non_immunity_input_range"
			continue
		# Monster.setup already uses int() for these existing operands. Keep
		# that conversion explicit without capping/summing or changing its rules.
		applied[field] = int(value)
		detail["receiver_value"] = int(value)
		detail["integer_receiver_policy"] = "existing_Monster_setup_int_conversion"
		detail.applied = true
	var policy_sha: String = str(policy_file.sha256)
	for field: String in applied: record[field] = applied[field]
	record["source_m_special_resistance_input_policy"] = {"origin":"twilight_adjustable_numeric_estimate",
		"policy_path":NUMERIC_INPUT_POLICY_PATH,"policy_schema":policy.schema,"policy_sha256":policy_sha,
		"policy":nested.duplicate(true),"source":identity,"admission":admitted.duplicate(true),"npc_class_id":npc_id,
		"source_raw_unit_scale":"unconfirmed","fields":evidence,"native_server_status_formula_recovered":false,
		"host_formula":"existing_host_status_formula_retained"}
	return record

func _project_uniform_attack_range_input(record: Dictionary, source: Dictionary) -> Dictionary:
	# A single existing actor-level receiver is valid only when every already
	# admitted attack of this owner supplies the same positive original Range.
	# No unadmitted relation, max/min, attack choice or spell range is consulted.
	if not source_available or source_mode!="current523_original" or content.get("input_kind")!="twilight.current523.npc-input.v1" or content.get("source_archive_sha256")!=SOURCE_SHA: return record
	var identity: Dictionary = DEFINITIONS.identity()
	if identity.is_empty() or identity.get("source_sha256")!=SOURCE_SHA or identity!=source_identity: return record
	if not source_integer(source.get("ID")): return record
	var npc_id := int(source.ID)
	var admitted: Dictionary = admitted_source_identities.get(str(npc_id),{})
	if admitted.get("source_archive_sha256")!=SOURCE_SHA: return record
	for pair: Array in [["npc_class_id","ID"],["sprite","Sprite"],["desc_id","DescId"]]:
		if not source_integer(admitted.get(pair[0])) or not source_integer(source.get(pair[1])) or admitted[pair[0]]!=source[pair[1]]: return record
	var selected_npc: Dictionary = content.get("tables",{}).get("NpcClass",{}).get(str(npc_id),{}).get("row",{})
	if selected_npc!=source or DEFINITIONS.row("NpcClass",npc_id)!=source or not DEFINITIONS.declared_exclusion("NpcClass",source).is_empty(): return record
	var policy_file: Dictionary = _policy_file(NPC_RANGE_INPUT_POLICY_PATH)
	if policy_file.is_empty(): return record
	var policy: Dictionary = policy_file.policy
	if policy.get("schema")!="twilight.current523.npc-range-input-policy.v1" or policy.get("source_snapshot")!="patch523" or policy.get("source_sha256")!=SOURCE_SHA: return record
	if not policy.get("enabled") is bool or not policy.enabled or policy.get("origin")!="twilight_adjustable_numeric_estimate": return record
	if policy.get("source_raw_range_unit_scale")!="unconfirmed" or policy.get("native_grid_scale_recovered")!=false or policy.get("host_range_contract")!="existing_record_attack_range_and_current_attack_range_retained": return record
	var scale: Variant = policy.get("raw_attack_range_to_host_length")
	if typeof(scale) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(scale)) or float(scale)<=0.0: return record
	var selected_attacks: Variant = content.get("tables",{}).get("NpcAttack",{})
	if not selected_attacks is Dictionary: return record
	var uniform: Variant = null
	var attack_ids: Array = []
	for key: Variant in selected_attacks:
		var entry: Variant = selected_attacks[key]
		if not entry is Dictionary or not entry.get("row") is Dictionary: return record
		var attack: Dictionary = entry.row
		if not source_integer(attack.get("NpcClassID")): return record
		if int(attack.NpcClassID)!=npc_id: continue
		if not source_integer(attack.get("ID")) or not source_integer(attack.get("Range")) or float(attack.Range)<=0.0: return record
		var attack_id := int(attack.ID)
		if not key is String or key!=str(attack_id) or attack_id in attack_ids: return record
		var originals: Array[Dictionary] = DEFINITIONS.related("NpcAttack","ID",attack_id)
		if originals.size()!=1 or originals[0]!=attack or not DEFINITIONS.declared_exclusion("NpcAttack",originals[0]).is_empty(): return record
		if uniform==null: uniform = attack.Range
		elif uniform!=attack.Range: return record
		attack_ids.append(attack_id)
	if attack_ids.is_empty(): return record
	var length: float = float(uniform)*float(scale)
	if not is_finite(length) or length<=0.0: return record
	var policy_sha: String = str(policy_file.sha256)
	var prior: Variant = record.get("attack_range")
	record["attack_range"] = length
	record["source_m_npc_range_input_policy"] = {"origin":"twilight_adjustable_numeric_estimate",
		"policy_path":NPC_RANGE_INPUT_POLICY_PATH,"policy_schema":policy.schema,"policy_sha256":policy_sha,
		"source":identity,"npc_class_id":npc_id,"admitted_actor_identity":admitted.duplicate(true),
		"admitted_registry_ids_sha256":admitted_registry_ids_sha256(),"admitted_attack_ids":attack_ids,
		"source_field":"NpcAttack.Range","uniform_raw_range":uniform,"raw_attack_range_to_host_length":float(scale),
		"prior_host_attack_range":prior,"host_length_input":length,"source_raw_range_unit_scale":"unconfirmed",
		"native_grid_scale_recovered":false,"calibration_status":policy.get("calibration_status"),
		"host_range_contract":"existing_record_attack_range_and_current_attack_range_retained"}
	return record

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
