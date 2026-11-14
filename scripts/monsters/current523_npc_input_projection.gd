extends RefCounted
## Current original input for already admitted host NPC identities only.
## Port of build_patch523_npc_catalog.py's host_npc_ids typed closure.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SOURCE_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
var problem: String = ""
var exclusions: Array = []
var _selected: Dictionary = {}
var _seen: Dictionary = {}
var _ids: Array[int] = []
var _fixed_done: bool = false
var _valid: bool = false

static func integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

func _excluded(table: String, row: Dictionary) -> bool:
	var declaration: Dictionary = SOURCE.declared_exclusion(table,row)
	var flag: String = {"NpcClass":"TestNPC","SpellClass":"TestSpell","BuffClass":"TestBuff"}.get(table,"")
	if not declaration.is_empty() or (not flag.is_empty() and row.get(flag) is bool and row[flag]):
		exclusions.append({"table":table,"id":row.get("ID"),"declaration":declaration,"test_field":flag})
		return true
	return false

## 1-based table positions of every row identical to `row`. Identical rows
## share every field, so they are all inside the relation group the row came
## from (`candidates`, table order); only that group is compared, never the
## whole table (Bonus has ~218k rows: serializing it froze the phone for
## seconds while a monster was being placed).
func _positions_in(table: String, row: Dictionary, candidates: PackedInt32Array, group: Array) -> Array:
	var positions: Array = []
	for index: int in range(mini(candidates.size(), group.size())):
		if group[index] == row: positions.append(int(candidates[index])+1)
	return positions

func _keep(table: String, row: Dictionary, positions: Array) -> bool:
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
	return row if _keep(table,row,_positions_in(table,row,SOURCE.related_indices(table,"ID",int(value)),rows)) else {}

func _owned(table: String, field: String, id: int) -> Array:
	# The exact owner predicate is the compiler's admission boundary.
	var result: Array = []
	if not _selected.has(table): _selected[table] = {}
	var group: Array[Dictionary] = SOURCE.related(table,field,id)
	var candidates: PackedInt32Array = SOURCE.related_indices(table,field,id)
	for row: Dictionary in group:
		if not integer(row.get(field)) or int(row[field])!=id:
			problem = "source_owner_mismatch:"+table
			return []
		if _excluded(table,row): continue
		if not _keep(table,row,_positions_in(table,row,candidates,group)): return []
		result.append(row)
	return result

func _queue(queue: Array, kind: String, value: Variant) -> bool:
	if not integer(value): problem = "non_integral_typed_dependency:"+kind; return false
	if value!=0: queue.append({"kind":kind,"id":int(value)})
	return true

## Full closure for `host_npc_ids` (state is rebuilt from nothing).
func build(host_npc_ids: Array) -> Dictionary:
	_reset()
	return extend(host_npc_ids)

## Adds the closure of ids not yet selected to the current selection. The
## typed closure of a union is the union of closures, so each new monster type
## costs only its own rows instead of re-walking every admitted type (the
## phone recorded multi-second "몬스터 배치" frames as admissions grew).
## Any failure drops the partial state; the next call rebuilds in full.
func extend(host_npc_ids: Array) -> Dictionary:
	problem = ""
	var identity: Dictionary = SOURCE.identity()
	if identity.is_empty() or identity.get("source_sha256")!=SOURCE_SHA:
		_reset()
		problem = "current523_source_unavailable:"+SOURCE.problem()
		return {}
	var requested: Array[int] = []
	for value: Variant in host_npc_ids:
		if not integer(value): problem = "host_npc_id_not_integral"; return {}
		if int(value) not in requested: requested.append(int(value))
	if not _valid:
		_reset()
		_valid = true
	var fresh: Array[int] = []
	for npc_id: int in requested:
		if not _ids.has(npc_id): fresh.append(npc_id)
	fresh.sort()
	if not _grow(fresh):
		var failure: String = problem
		_reset()
		problem = failure
		return {}
	for npc_id: int in fresh: _ids.append(npc_id)
	_ids.sort()
	return _result()

func _reset() -> void:
	problem = ""; exclusions = []; _selected = {}; _seen = {}; _ids = []; _fixed_done = false; _valid = false

func _grow(fresh: Array[int]) -> bool:
	var queue: Array = []
	for npc_id: int in fresh:
		var npc: Dictionary = _by_id("NpcClass",npc_id)
		if npc.is_empty(): return false
		if _by_id("NpcCategory",npc.get("Category")).is_empty(): return false
		for attack: Dictionary in _owned("NpcAttack","NpcClassID",npc_id):
			if attack.get("IsSpell") is bool and attack.IsSpell and not _queue(queue,"Spell",attack.get("SpellID")): return false
		if not problem.is_empty(): return false
		_owned("NpcAttribute","NpcClassID",npc_id)
		_owned("NpcRace","NpcClassID",npc_id)
		for resistance: Dictionary in _owned("NpcSpecialResistance","NpcClassID",npc_id):
			if _by_id("SpecialResistanceType",resistance.get("SpecialResistanceTypeID")).is_empty(): return false
		if not problem.is_empty(): return false
	while not queue.is_empty():
		var edge: Dictionary = queue.pop_back()
		var token: String = str(edge.kind)+":"+str(edge.id)
		if _seen.has(token): continue
		_seen[token] = true
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
			if row.get("BuffGroupID",0)!=0 and _by_id("BuffGroup",row.BuffGroupID).is_empty(): return false
		var link_table: String = "SpellBonus" if edge.kind=="Spell" else "BuffBonus"
		var owner_field: String = "SpellClassID" if edge.kind=="Spell" else "BuffClassID"
		for link: Dictionary in _owned(link_table,owner_field,edge.id):
			var bonus: Dictionary = _by_id("Bonus",link.get("BonusID"))
			if bonus.is_empty(): return false
			var type: Dictionary = _by_id("BonusType",bonus.get("BonusTypeID"))
			if type.is_empty(): return false
			var unit: Dictionary = _by_id("Unit",type.get("UnitID"))
			if unit.is_empty() or _by_id("BonusApplicationType",bonus.get("BonusApplicationTypeID",0)).is_empty(): return false
			_owned("UIUnit","UnitID",int(unit.ID))
			var target: String = {"SpellClassID":"Spell","BuffClassID":"Buff"}.get(unit.get("Name",""),"")
			if not target.is_empty() and not _queue(queue,target,bonus.get("Value")): return false
			if type.get("Name")=="InvokeOption" and not _queue(queue,"Invoke",bonus.get("BonusApplicationTargetID",0)): return false
			if type.get("Name")=="StatusEffectID":
				if not integer(bonus.get("Value")): problem = "non_integral_status_reference"; return false
				_owned("StatusEffectAttr","StatusEffectID",int(bonus.Value))
		if not problem.is_empty(): return false
	# The compiler keeps these small overlap/element enums in full. AttackType
	# is a declared existing enum only; no native attack/AI policy is selected.
	if not fresh.is_empty() and not _fixed_done:
		_fixed_done = true
		for table: String in ["BuffGroup","ElementalType","AttackType"]:
			if not _selected.has(table): _selected[table] = {}
			var all: Array[Dictionary] = SOURCE.rows(table)
			var order := PackedInt32Array()
			order.resize(all.size())
			for index: int in all.size(): order[index] = index
			for row: Dictionary in all:
				if not _excluded(table,row) and not _keep(table,row,_positions_in(table,row,order,all)): return false
	return true

func _result() -> Dictionary:
	# Rows are never changed once selected, so a per-table copy keeps the
	# returned content independent of later extend() calls.
	var tables: Dictionary = {}
	for table: String in _selected: tables[table] = (_selected[table] as Dictionary).duplicate(false)
	var provenance: Dictionary = {}
	for table: String in _selected:
		var metadata: Dictionary = SOURCE.table_metadata(table)
		provenance[table] = {"path":metadata.get("path","content/"+table+".json"),
			"sha256":metadata.get("sha256",""),"bytes":metadata.get("bytes",0),
			"crc32":metadata.get("crc32",""),"row_count":metadata.get("row_count",0)}
	return {"kind":"patch523_npc_spell_catalog","schema":1,"source_snapshot":"patch523",
		"input_kind":"twilight.current523.npc-input.v1","source_archive_sha256":SOURCE_SHA,
		"boss_npc_ids":_ids.duplicate(),"report_boss_npc_ids":[],"report_attack_ids":[],"report_spell_ids":[],
		"host_extension_npc_ids":_ids.duplicate(),"provenance":provenance,"tables":tables,
		"excluded_source_rows":exclusions.duplicate(false),
		"execution_contract":"source typed graph; host attack clock/selection/hit/formula; unresolved semantics stay pending",
		"limits":["no summon-set members","no TargetClass geometry","no native AI clock/probability","no final reflection formula","no original sprite payload"]}

