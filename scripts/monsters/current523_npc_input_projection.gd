extends RefCounted
## Current original input for already admitted host NPC identities only.
## Port of build_patch523_npc_catalog.py's host_npc_ids typed closure.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SOURCE_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
var problem: String = ""
var exclusions: Array = []
var _selected: Dictionary = {}
var _positions: Dictionary = {}
var _strict_dependencies: bool = false

static func integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

func _excluded(table: String, row: Dictionary) -> bool:
	var declaration: Dictionary = SOURCE.declared_exclusion(table,row)
	var flag: String = {"NpcClass":"TestNPC","SpellClass":"TestSpell","BuffClass":"TestBuff"}.get(table,"")
	if not declaration.is_empty() or (not flag.is_empty() and row.get(flag) is bool and row[flag]):
		exclusions.append({"table":table,"id":row.get("ID"),"declaration":declaration,"test_field":flag})
		return true
	return false

func _source_positions(table: String, row: Dictionary) -> Array:
	if not _positions.has(table):
		var positions: Dictionary = {}
		var rows: Array[Dictionary] = SOURCE.rows(table)
		for index: int in range(rows.size()):
			var key: String = JSON.stringify(rows[index],"",true,true)
			if not positions.has(key): positions[key] = []
			positions[key].append(index+1)
		_positions[table] = positions
	return _positions[table].get(JSON.stringify(row,"",true,true),[])

func _keep(table: String, row: Dictionary) -> bool:
	var positions: Array = _source_positions(table,row)
	if positions.is_empty(): problem = "source_row_position_missing:"+table; return false
	if row.has("ID") and (not integer(row.ID) or positions.size()!=1):
		problem = "source_row_identity_ambiguous:"+table
		return false
	if not _selected.has(table): _selected[table] = {}
	for position: int in positions:
		var key: String = str(int(row.ID)) if row.has("ID") else "@"+str(position)
		var old: Dictionary = _selected[table].get(key,{})
		if not old.is_empty() and old.row!=row: problem = "source_row_identity_conflict:"+table+":"+key; return false
		_selected[table][key] = {"source_row_1based":position,"row":row.duplicate(true)}
	return true

func _by_id(table: String, value: Variant) -> Dictionary:
	if not integer(value): problem = "non_integral_source_reference:"+table; return {}
	var rows: Array[Dictionary] = SOURCE.related(table,"ID",int(value))
	if rows.size()!=1: problem = "source_reference_missing_or_ambiguous:"+table+":"+str(int(value)); return {}
	var row: Dictionary = rows[0]
	if _excluded(table,row): problem = "source_declared_exclusion:"+table+":"+str(int(value)); return {}
	return row if _keep(table,row) else {}

func _owned(table: String, field: String, id: int) -> Array:
	# The exact owner predicate is the compiler's admission boundary.
	var result: Array = []
	if not _selected.has(table): _selected[table] = {}
	for row: Dictionary in SOURCE.related(table,field,id):
		if not integer(row.get(field)) or int(row[field])!=id:
			problem = "source_owner_mismatch:"+table
			return []
		if _excluded(table,row):
			if _strict_dependencies: problem = "excluded_dependency:"+table; return []
			continue
		if not _keep(table,row): return []
		result.append(row)
	return result

func _queue(queue: Array, kind: String, value: Variant) -> bool:
	if not integer(value): problem = "non_integral_typed_dependency:"+kind; return false
	if value!=0: queue.append({"kind":kind,"id":int(value)})
	return true

func build(host_npc_ids: Array) -> Dictionary:
	problem = ""; exclusions = []; _selected = {}; _strict_dependencies = false
	var identity: Dictionary = SOURCE.identity()
	if identity.is_empty() or identity.get("source_sha256")!=SOURCE_SHA:
		problem = "current523_source_unavailable:"+SOURCE.problem()
		return {}
	var ids: Array[int] = []
	for value: Variant in host_npc_ids:
		if not integer(value): problem = "host_npc_id_not_integral"; return {}
		if int(value) not in ids: ids.append(int(value))
	ids.sort()
	var queue: Array = []
	for npc_id: int in ids:
		var npc: Dictionary = _by_id("NpcClass",npc_id)
		if npc.is_empty(): return {}
		if _by_id("NpcCategory",npc.get("Category")).is_empty(): return {}
		for attack: Dictionary in _owned("NpcAttack","NpcClassID",npc_id):
			if attack.get("IsSpell") is bool and attack.IsSpell and not _queue(queue,"Spell",attack.get("SpellID")): return {}
		if not problem.is_empty(): return {}
		_owned("NpcAttribute","NpcClassID",npc_id)
		_owned("NpcRace","NpcClassID",npc_id)
		for resistance: Dictionary in _owned("NpcSpecialResistance","NpcClassID",npc_id):
			if _by_id("SpecialResistanceType",resistance.get("SpecialResistanceTypeID")).is_empty(): return {}
		if not problem.is_empty(): return {}
	if not _collect_dependencies(queue): return {}
	# The compiler keeps these small overlap/element enums in full. AttackType
	# is a declared existing enum only; no native attack/AI policy is selected.
	if not ids.is_empty():
		for table: String in ["BuffGroup","ElementalType","AttackType"]:
			if not _selected.has(table): _selected[table] = {}
			for row: Dictionary in SOURCE.rows(table):
				if not _excluded(table,row) and not _keep(table,row): return {}
	var provenance: Dictionary = {}
	for table: String in _selected:
		var metadata: Dictionary = SOURCE.table_metadata(table)
		provenance[table] = {"path":metadata.get("path","content/"+table+".json"),
			"sha256":metadata.get("sha256",""),"bytes":metadata.get("bytes",0),
			"crc32":metadata.get("crc32",""),"row_count":metadata.get("row_count",0)}
	return {"kind":"patch523_npc_spell_catalog","schema":1,"source_snapshot":"patch523",
		"input_kind":"twilight.current523.npc-input.v1","source_archive_sha256":SOURCE_SHA,
		"boss_npc_ids":ids,"report_boss_npc_ids":[],"report_attack_ids":[],"report_spell_ids":[],
		"host_extension_npc_ids":ids,"provenance":provenance,"tables":_selected,
		"excluded_source_rows":exclusions,
		"execution_contract":"source typed graph; host attack clock/selection/hit/formula; unresolved semantics stay pending",
		"limits":["no summon-set members","no TargetClass geometry","no native AI clock/probability","no final reflection formula","no original sprite payload"]}


func _collect_dependencies(queue: Array) -> bool:
	var seen: Dictionary = {}
	while not queue.is_empty():
		var edge: Dictionary = queue.pop_back()
		var token: String = str(edge.kind)+":"+str(edge.id)
		if seen.has(token): continue
		seen[token] = true
		var table: String = {"Spell":"SpellClass","Buff":"BuffClass","Invoke":"InvokeOption"}[edge.kind]
		var row: Dictionary = _by_id(table,edge.id)
		if row.is_empty(): return false
		if edge.kind=="Invoke":
			# Keep the declared type but do not invent a Param1/Param2 spell edge.
			if _by_id("InvokeOptionType",row.get("InvokeOptionTypeID")).is_empty(): return false
			if not _queue(queue,"Invoke",row.get("SuccessedInvokeOptionID",0)): return false
			continue
		if edge.kind=="Spell":
			for pair: Array in [["SpellCategory","SpellCategoryID"],["TargettingType","TargettingTypeID"],["TargetKind","TargetKindID"]]:
				if row.get(pair[1],0)!=0 and _by_id(pair[0],row[pair[1]]).is_empty(): return false
		else:
			if (_strict_dependencies or row.get("BuffGroupID",0)!=0) and _by_id("BuffGroup",row.get("BuffGroupID")).is_empty(): return false
		var link_table: String = "SpellBonus" if edge.kind=="Spell" else "BuffBonus"
		var owner_field: String = "SpellClassID" if edge.kind=="Spell" else "BuffClassID"
		for link: Dictionary in _owned(link_table,owner_field,edge.id):
			var bonus: Dictionary = _by_id("Bonus",link.get("BonusID"))
			if bonus.is_empty(): return false
			if _strict_dependencies:
				var number: Variant = bonus.get("Value")
				if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)) or not integer(bonus.get("BonusApplicationTargetID")):
					problem = "invalid_environment_bonus_operand"; return false
			var type: Dictionary = _by_id("BonusType",bonus.get("BonusTypeID"))
			if type.is_empty(): return false
			var unit: Dictionary = _by_id("Unit",type.get("UnitID"))
			if unit.is_empty() or _by_id("BonusApplicationType",bonus.get("BonusApplicationTypeID",0)).is_empty(): return false
			_owned("UIUnit","UnitID",int(unit.ID))
			var target: String = {"SpellClassID":"Spell","BuffClassID":"Buff"}.get(unit.get("Name",""),"")
			if not target.is_empty() and not _queue(queue,target,bonus.get("Value")): return false
			if _strict_dependencies and unit.get("Name")=="BuffGroupID" and bonus.get("Value",0)!=0 and _by_id("BuffGroup",bonus.get("Value")).is_empty(): return false
			if _strict_dependencies and unit.get("Name")=="InvokeOptionID" and not _queue(queue,"Invoke",bonus.get("Value")): return false
			if type.get("Name")=="InvokeOption" and not _queue(queue,"Invoke",bonus.get("BonusApplicationTargetID",0)): return false
			if type.get("Name")=="StatusEffectID":
				if not integer(bonus.get("Value")): problem = "non_integral_status_reference"; return false
				_owned("StatusEffectAttr","StatusEffectID",int(bonus.Value))
		if not problem.is_empty(): return false
	return true

func build_land_environment(land_id: int, asset_path: String, land_attribute_ids: Array) -> Dictionary:
	problem = ""; exclusions = []; _selected = {}; _strict_dependencies = true
	var identity: Dictionary = SOURCE.identity()
	if identity.is_empty() or identity.get("source_sha256")!=SOURCE_SHA:
		problem = "current523_source_unavailable:"+SOURCE.problem(); return {}
	var land: Dictionary = _by_id("Land",land_id)
	# Land0 is an actual row in this pinned snapshot, not an absent root.
	# Keep Buff/Spell/attribute zero sentinels unchanged; require exact Land/AssetPath.
	if land_id<0 or land.is_empty() or asset_path.is_empty() or land.get("AssetPath")!=asset_path:
		problem = "land_asset_path_identity_mismatch"; return {}
	var kind: Dictionary = _by_id("LandAttributeType",504)
	var unit: Dictionary = _by_id("Unit",16)
	if kind.get("Name")!="NpcBuff" or kind.get("UnitID")!=16 or unit.get("Name")!="BuffClassID":
		problem = "land_npc_buff_unit_contract_mismatch"; return {}
	var ids: Array[int] = []; var queue: Array = []
	for value: Variant in land_attribute_ids:
		if not integer(value) or int(value)<=0 or int(value) in ids:
			problem = "land_attribute_id_invalid_or_duplicate"; return {}
		ids.append(int(value))
	ids.sort()
	for id: int in ids:
		var attribute: Dictionary = _by_id("LandAttribute",id)
		if attribute.is_empty(): return {}
		if attribute.get("LandID")!=land_id or attribute.get("LandAttributeTypeID")!=504 or not integer(attribute.get("Value")) or int(attribute.Value)<=0 or not integer(attribute.get("TerritoryID")) or int(attribute.TerritoryID)<0:
			problem = "land_attribute_owner_or_type_mismatch:"+str(id); return {}
		for field: String in ["Param1","Param2","Param3"]:
			if not integer(attribute.get(field)) or attribute[field]!=0:
				problem = "land_npc_buff_parameter_pending:"+str(id)+":"+field; return {}
		if int(attribute.TerritoryID)!=0:
			var territory: Dictionary = _by_id("Territories",attribute.TerritoryID)
			if territory.is_empty(): return {}
			for field: String in ["LandID","StartX","StartY","EndX","EndY"]:
				if not integer(territory.get(field)): problem = "territory_coordinate_not_integral"; return {}
			if territory.LandID!=land_id or territory.StartX>territory.EndX or territory.StartY>territory.EndY:
				problem = "land_territory_owner_or_bounds_mismatch"; return {}
		if not _queue(queue,"Buff",attribute.Value): return {}
	if not _collect_dependencies(queue): return {}
	var provenance: Dictionary = {}
	for table: String in _selected:
		var metadata: Dictionary = SOURCE.table_metadata(table)
		if metadata.is_empty(): problem = "source_table_provenance_missing:"+table; return {}
		provenance[table]={"path":metadata.get("path","content/"+table+".json"),"sha256":metadata.get("sha256",""),"bytes":metadata.get("bytes",0),"crc32":metadata.get("crc32",""),"row_count":metadata.get("row_count",0)}
	return {"kind":"patch523_npc_land_environment_input","schema":1,"source_snapshot":"patch523",
		"input_kind":"twilight.current523.land-environment-input.v1","source_archive_sha256":SOURCE_SHA,"source_archive_identity":identity,
		"selection":{"land_id":land_id,"asset_path":asset_path,"land_attribute_ids":ids},
		"tables":_selected,"provenance":provenance,"excluded_source_rows":exclusions,
		"dependency_contract":"explicit LandAttribute504/Unit16 roots and complete admitted Buff/Spell/Invoke/StatusEffectAttr closure; no archive completion fallback",
		"execution_contract":"registered input only; caller owns exact current M/AssetPath relation, source position and existing environment opt-in/lifecycle",
		"limits":["no GroupID-to-BuffClass substitution","no untyped invoke parameter edges","no inferred native AI or renderer","raw conditional metadata retains existing receiver guards"]}
