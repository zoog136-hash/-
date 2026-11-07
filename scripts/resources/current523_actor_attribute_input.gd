extends RefCounted
## Numeric source input for an existing local Orim actor, not native admission.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const KIND = "twilight.orim.npc-attribute-input.v1"
const FIELDS = ["Str","Dex","Con","Wis","Cha","Int"]
const NUMERIC_POLICY = "res://data/monsters/current523_orim_numeric_input_policy.json"
const ELEMENT_FIELDS = {"fire":"FireResistance","water":"WaterResistance","wind":"AirResistance","earth":"EarthResistance"}
const STATUS_FIELDS = {"Stun":"stun_resistance","Hold":"hold_resistance","Fear":"fear_resistance"}

static func whole(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=0 and float(value)<=9007199254740991.0

static func unique(table: String, id: int) -> Dictionary:
	var matches: Array[Dictionary] = SOURCE.related(table,"ID",id)
	if matches.size()!=1 or not SOURCE.declared_exclusion(table,matches[0]).is_empty(): return {}
	return matches[0]

static func orim(npc_id: int, stage_id: int, spawn: Dictionary) -> Dictionary:
	var identity: Dictionary = SOURCE.identity()
	if identity.get("source_sha256")!=SOURCE.SOURCE_SHA or npc_id<=0 or stage_id<=0 or not whole(spawn.get("ID")): return {}
	var stage: Dictionary = unique("OrimsTrailStage",stage_id)
	var original_spawn: Dictionary = unique("OrimsTrailSpawn",int(spawn.ID))
	if stage.is_empty() or original_spawn.is_empty() or original_spawn!=spawn or spawn.get("StageID")!=stage_id: return {}
	if not whole(spawn.get("NpcClassID")) or not whole(spawn.get("NpcGroupID")): return {}
	var members: Array = []
	if int(spawn.NpcClassID)==0:
		if int(spawn.NpcGroupID)<=0: return {}
		for link: Dictionary in SOURCE.related("NpcClassForNpcGroup","NpcGroupID",int(spawn.NpcGroupID)):
			if link.get("NpcClassID")==npc_id:
				if not SOURCE.declared_exclusion("NpcClassForNpcGroup",link).is_empty(): return {}
				members.append(link)
		if members.size()!=1: return {}
	elif int(spawn.NpcClassID)!=npc_id: return {}
	var npc: Dictionary = unique("NpcClass",npc_id)
	if npc.is_empty() or npc.get("TestNPC")==true: return {}
	var values: Dictionary = {}
	for field: String in FIELDS:
		if not whole(npc.get(field)): return {}
		values[field] = npc[field]
	return {"kind":KIND,"source":identity,"npc":npc,"stage":stage,"spawn":original_spawn,"group_links":members,"values":values}

static func values(input: Dictionary) -> Dictionary:
	if input.get("kind")!=KIND or not input.get("npc") is Dictionary or not input.get("stage") is Dictionary or not input.get("spawn") is Dictionary: return {}
	if not whole(input.npc.get("ID")) or not whole(input.stage.get("ID")): return {}
	var current: Dictionary = orim(int(input.npc.ID),int(input.stage.ID),input.spawn)
	return current.get("values",{}).duplicate(true) if not current.is_empty() and current==input else {}

static func numeric(input: Dictionary) -> Dictionary:
	# A separate explicit local-input policy; the admitted-native-actor policy
	# is neither widened nor used as a replacement for source admission.
	if values(input).is_empty(): return {}
	var document: Dictionary = _policy()
	if document.is_empty(): return {}
	var policy: Dictionary = document.policy
	var scale: Variant = policy.get("raw_resistance_to_host_percent")
	if typeof(scale) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(scale)) or float(scale)<0.0: return {}
	var resistance: Dictionary = {}; var evidence: Dictionary = {}
	for channel: String in ELEMENT_FIELDS:
		var field: String = ELEMENT_FIELDS[channel]
		var raw: Variant = input.npc.get(field)
		if typeof(raw) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(raw)) or float(raw)!=floorf(float(raw)) or absf(float(raw))>9007199254740991.0: return {}
		var value: float = float(raw)*float(scale)
		if not is_finite(value): return {}
		resistance[channel]=value
		evidence[channel]={"field":field,"raw":raw,"host_input":value}
	var status: Dictionary = _named_resistances(int(input.npc.ID),policy.get("special_resistance"))
	return {"source":input.source,"npc_class_id":input.npc.ID,"element_resistance":resistance,
		"status_resistance":status.get("values",{}),"status_evidence":status.get("evidence",{}),
		"fields":evidence,"policy_path":NUMERIC_POLICY,"policy_sha256":document.sha256,
		"origin":"twilight_adjustable_numeric_estimate","source_raw_unit_scale":"unconfirmed",
		"scale":float(scale),"native_server_damage_formula_recovered":false,"native_admission":false}

static func _policy() -> Dictionary:
	var file := FileAccess.open(NUMERIC_POLICY,FileAccess.READ)
	if file==null: return {}
	if file.get_length()>16384:
		file.close()
		return {}
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var policy: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not policy is Dictionary or policy.get("schema")!="twilight.current523.orim-numeric-input-policy.v1" or policy.get("source_snapshot")!="patch523" or policy.get("source_sha256")!=SOURCE.SOURCE_SHA: return {}
	if typeof(policy.get("enabled"))!=TYPE_BOOL or not policy.enabled or policy.get("scope")!="verified_original_orim_stage_spawn_npc_numeric_input_only" or policy.get("origin")!="twilight_adjustable_numeric_estimate" or policy.get("source_raw_unit_scale")!="unconfirmed" or typeof(policy.get("native_server_damage_formula_recovered"))!=TYPE_BOOL or policy.native_server_damage_formula_recovered or policy.get("host_formula")!="existing_host_formula_retained": return {}
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256)!=OK or hashing.update(bytes)!=OK: return {}
	return {"policy":policy,"sha256":hashing.finish().hex_encode()}

static func attack_range(input: Dictionary, attack: Dictionary, host_kind: String) -> Dictionary:
	# The existing owner already chose this attack for its actual dice hit.
	# Never choose another row/range or change the host's attack-style role.
	if values(input).is_empty() or not whole(attack.get("ID")) or host_kind not in ["melee","ranged","magic"]: return {}
	var original: Dictionary = unique("NpcAttack",int(attack.ID))
	if original.is_empty() or original!=attack or original.get("NpcClassID")!=input.npc.ID or original.get("IsSpell")!=false or not whole(original.get("AttackType")): return {}
	var type: Dictionary = unique("AttackType",int(original.AttackType))
	if type.get("Name")!={"melee":"Melee","ranged":"Range","magic":"Magic"}[host_kind]: return {}
	var document: Dictionary = _policy()
	if document.is_empty(): return {}
	var policy: Variant = document.policy.get("attack_range")
	if not policy is Dictionary or typeof(policy.get("enabled"))!=TYPE_BOOL or not policy.enabled: return {}
	if policy.get("scope")!="existing_selected_nonspell_orim_attack_matching_host_kind" or policy.get("origin")!="twilight_adjustable_numeric_estimate" or policy.get("source_raw_range_unit_scale")!="unconfirmed" or typeof(policy.get("native_grid_scale_recovered"))!=TYPE_BOOL or policy.native_grid_scale_recovered: return {}
	var scale: Variant = policy.get("raw_attack_range_to_host_length")
	var raw: Variant = original.get("Range")
	if typeof(scale) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(scale)) or float(scale)<=0.0 or not whole(raw) or float(raw)<=0.0: return {}
	var length: float = float(raw)*float(scale)
	if not is_finite(length) or length<=0.0: return {}
	return {"source":input.source,"npc_class_id":input.npc.ID,"attack":original,"attack_type":type,
		"raw_range":raw,"host_kind":host_kind,"host_length":length,"scale":float(scale),
		"policy_path":NUMERIC_POLICY,"policy_sha256":document.sha256,
		"origin":"twilight_adjustable_numeric_estimate","source_raw_range_unit_scale":"unconfirmed",
		"native_grid_scale_recovered":false,"native_admission":false}

static func _named_resistances(npc_id: int, policy: Variant) -> Dictionary:
	if not policy is Dictionary or typeof(policy.get("enabled"))!=TYPE_BOOL or not policy.enabled: return {}
	if policy.get("origin")!="twilight_adjustable_numeric_estimate" or policy.get("source_raw_unit_scale")!="unconfirmed" or typeof(policy.get("native_server_status_formula_recovered"))!=TYPE_BOOL or policy.native_server_status_formula_recovered or policy.get("scope")!="verified_original_orim_NpcSpecialResistance_named_Stun_Hold_Fear_only": return {}
	var scale: Variant = policy.get("raw_to_host_percent")
	if typeof(scale) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(scale)) or float(scale)<0.0: return {}
	var grouped: Dictionary = {}
	for link: Dictionary in SOURCE.related("NpcSpecialResistance","NpcClassID",npc_id):
		if not whole(link.get("ID")) or not whole(link.get("SpecialResistanceTypeID")): return {}
		if unique("NpcSpecialResistance",int(link.ID))!=link: return {}
		var type: Dictionary = unique("SpecialResistanceType",int(link.SpecialResistanceTypeID))
		var name_value: Variant = type.get("Name")
		if not name_value is String or not STATUS_FIELDS.has(name_value): continue
		if not grouped.has(name_value): grouped[name_value]=[]
		grouped[name_value].append({"link":link,"type":type})
	var result: Dictionary = {}; var evidence: Dictionary = {}
	for name_value: String in grouped:
		var entries: Array = grouped[name_value]
		if entries.size()!=1: continue
		var raw: Variant = entries[0].link.get("Value")
		if typeof(raw) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(raw)) or float(raw)<0.0: continue
		var value: float = float(raw)*float(scale)
		# 100 is not an immunity declaration. Keep the previous host value.
		if not is_finite(value) or value<0.0 or value>=100.0: continue
		result[STATUS_FIELDS[name_value]]=int(value)
		evidence[name_value]={"source_rows":entries,"raw":raw,"scale":float(scale),"host_input":int(value),"source_raw_unit_scale":"unconfirmed"}
	return {"values":result,"evidence":evidence}
