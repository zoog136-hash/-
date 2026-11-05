extends RefCounted
## Numeric source input for an existing local Orim actor, not native admission.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const KIND = "twilight.orim.npc-attribute-input.v1"
const FIELDS = ["Str","Dex","Con","Wis","Cha","Int"]

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
