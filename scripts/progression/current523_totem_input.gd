extends RefCounted
## Read-only input for the existing local Totem parser and execution policy.
## This is a typed minimum closure, not the unavailable research pack's selection.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const CORE_COUNTS = {"Totem":3,"TotemLevel":33,"TotemMaterial":60,"TotemBonus":94,"TotemResonance":4,"TotemResetCost":2,"TotemConstant":8}
const REQUIRED_TABLES = ["Bonus","BonusType","Unit","UIUnit","BonusApplicationType","NpcClassForNpcGroup","Currency","CurrencyUnitClass","ItemClass","ItemBonus","BuffClass","BuffBonus","SpellClass","SpellBonus","InvokeOption","InvokeOptionType","ItemCraftView","ItemCraftInput","ItemCraftOutputView"]
var problem: String = ""
var source_identity: Dictionary = {}
var deferred: Array = []
var recipe_references: Array = []
var _tables: Dictionary = {}
var _ids: Dictionary = {}
var _relations: Dictionary = {}

func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=2147483647.0

func _defer(reason: String, table: String, id: Variant) -> void:
	var entry := {"reason":reason,"table":table,"id":id}
	if entry not in deferred: deferred.append(entry)

func _exclusion(table: String, row: Dictionary) -> Dictionary:
	var declaration: Dictionary = SOURCE.declared_exclusion(table,row)
	var flag: String = {"ItemClass":"TestItem","SpellClass":"TestSpell","BuffClass":"TestBuff","NpcClass":"TestNPC"}.get(table,"")
	if not declaration.is_empty(): return declaration
	if not flag.is_empty() and row.get(flag) is bool and row[flag]:
		return {"reason":"source_test_declaration","field":flag}
	return {}

func _keep(table: String, row: Dictionary) -> bool:
	if not _tables.has(table): _tables[table] = []
	if row.has("ID"):
		if not _integer(row.ID): problem = "totem_non_integral_id:"+table; return false
		if not _ids.has(table): _ids[table] = {}
		var key := str(int(row.ID))
		if _ids[table].has(key):
			if _ids[table][key]!=row: problem = "totem_ambiguous_id:"+table+":"+key; return false
			return true
		_ids[table][key] = row.duplicate(true)
	_tables[table].append(row.duplicate(true))
	return true

func _by_id(table: String, value: Variant, required: bool = true, admit: bool = true) -> Dictionary:
	if not _integer(value):
		if required: problem = "totem_non_integral_reference:"+table
		else: _defer("non_integral_reference",table,value)
		return {}
	var matches: Array[Dictionary] = SOURCE.related(table,"ID",int(value))
	if matches.size()!=1:
		if required: problem = "totem_reference_missing_or_ambiguous:"+table+":"+str(int(value))
		else: _defer("reference_missing_or_ambiguous",table,value)
		return {}
	var row: Dictionary = matches[0]
	var excluded := _exclusion(table,row)
	if not excluded.is_empty():
		if required: problem = "totem_source_excluded:"+table+":"+str(int(value))
		else: _defer("source_declared_exclusion",table,value)
		return {}
	return row if not admit or _keep(table,row) else {}

func _owned(table: String, field: String, id: int) -> Array:
	var key := table+":"+field+":"+str(id)
	if _relations.has(key): return _relations[key]
	var result: Array = []
	for row: Dictionary in SOURCE.related(table,field,id):
		if not _integer(row.get(field)) or int(row[field])!=id:
			problem = "totem_source_owner_mismatch:"+table
			return []
		if not _exclusion(table,row).is_empty():
			_defer("source_declared_exclusion",table,row.get("ID",id))
			continue
		if not _keep(table,row): return []
		result.append(row)
	_relations[key] = result
	return result

func _queue(queue: Array, kind: String, value: Variant, required: bool = true) -> bool:
	if not _integer(value):
		if required: problem = "totem_non_integral_typed_reference:"+kind
		else: _defer("non_integral_typed_reference",kind,value)
		return false
	if int(value)!=0: queue.append({"kind":kind,"id":int(value),"required":required})
	return true

func _item(id: Variant, queue: Array) -> bool:
	var item: Dictionary = _by_id("ItemClass",id)
	if item.is_empty(): return false
	for link: Dictionary in _owned("ItemBonus","ItemClassID",int(id)):
		if not _queue(queue,"Bonus",link.get("BonusID")): return false
	return problem.is_empty()

func _typed_closure(queue: Array) -> bool:
	var seen: Dictionary = {}
	while not queue.is_empty():
		var edge: Dictionary = queue.pop_front()
		var key := str(edge.kind)+":"+str(edge.id)
		if seen.has(key): continue
		seen[key] = true
		if edge.kind=="Bonus":
			var bonus: Dictionary = _by_id("Bonus",edge.id)
			if bonus.is_empty(): return false
			var type: Dictionary = _by_id("BonusType",bonus.get("BonusTypeID"))
			if type.is_empty(): return false
			var unit: Dictionary = _by_id("Unit",type.get("UnitID"))
			if unit.is_empty() or _by_id("BonusApplicationType",bonus.get("BonusApplicationTypeID")).is_empty(): return false
			_owned("UIUnit","UnitID",int(unit.ID))
			# These are the exact existing Totem consumer predicates. A unit or
			# display name alone never becomes a new effect receiver.
			if type.get("Name")=="InvokeOption" and bonus.get("BonusApplicationTypeID")==10:
				_queue(queue,"Invoke",bonus.get("BonusApplicationTargetID"),false)
			if type.get("Name")=="BuffClassID" and unit.get("Name")=="BuffClassID":
				_queue(queue,"Buff",bonus.get("Value"),false)
		elif edge.kind=="Invoke":
			# Hold the raw option outside the executable table until the exact
			# consumer's typed spell receiver has been admitted.
			var option: Dictionary = _by_id("InvokeOption",edge.id,false,false)
			if option.is_empty(): continue
			var type: Dictionary = _by_id("InvokeOptionType",option.get("InvokeOptionTypeID"),false)
			if type.is_empty(): continue
			if int(type.ID) not in [1,2]:
				_defer("invoke_handler_not_supported","InvokeOption",edge.id)
				continue
			var param_unit: Dictionary = _by_id("Unit",type.get("Param1Unit"),false)
			if param_unit.get("Name")!="SpellClassID":
				_defer("invoke_param1_spell_unit_unconfirmed","InvokeOption",edge.id)
				continue
			if _by_id("SpellClass",option.get("Param1"),false,false).is_empty(): continue
			if not _keep("InvokeOption",option): return false
			_queue(queue,"Spell",option.get("Param1"),false)
		else:
			var table: String = "SpellClass" if edge.kind=="Spell" else "BuffClass"
			var row: Dictionary = _by_id(table,edge.id,bool(edge.required))
			if row.is_empty():
				if not problem.is_empty(): return false
				continue
			var link_table: String = "SpellBonus" if edge.kind=="Spell" else "BuffBonus"
			var owner: String = "SpellClassID" if edge.kind=="Spell" else "BuffClassID"
			for link: Dictionary in _owned(link_table,owner,edge.id):
				if not _queue(queue,"Bonus",link.get("BonusID")): return false
		if not problem.is_empty(): return false
	return true

func _contexts() -> Dictionary:
	# Exact builder chain; these Land records do not select a map or spawn.
	var contexts: Dictionary = {}
	for totem: Dictionary in _tables.Totem:
		var packs: Dictionary = {}
		for member: Dictionary in _tables.NpcClassForNpcGroup:
			if int(member.NpcGroupID)!=int(totem.NpcGroupID): continue
			for spawn: Dictionary in _owned("NpcSpawnPackNpcClassView","NpcClassID",int(member.NpcClassID)):
				if not _integer(spawn.get("NpcSpawnPackID")): problem = "totem_spawn_pack_reference_invalid"; return {}
				packs[int(spawn.NpcSpawnPackID)] = true
		var lands: Dictionary = {}
		for pack: int in packs:
			for link: Dictionary in _owned("NpcSpawnPackTerritory","NpcSpawnPackID",pack):
				var territory: Dictionary = _by_id("Territories",link.get("TerritoriesID"))
				if territory.is_empty(): return {}
				var land: Dictionary = _by_id("Land",territory.get("LandID"))
				if land.is_empty(): return {}
				lands[int(land.ID)] = land
		var ids: Array = lands.keys()
		ids.sort()
		var rows: Array = []
		for id: int in ids: rows.append(lands[id].duplicate(true))
		contexts[str(int(totem.ID))] = rows
	var sizes: Array = []
	for rows: Array in contexts.values(): sizes.append(rows.size())
	sizes.sort()
	if sizes!=[2,2,3]: problem = "totem_original_region_closure_changed"; return {}
	return contexts

func _reference_item(id: Variant) -> Dictionary:
	if not _integer(id): return {"blocker":"non_integral_item_reference"}
	var item: Dictionary = SOURCE.row("ItemClass",int(id))
	if item.is_empty(): return {"id":id,"blocker":"item_reference_missing_or_ambiguous"}
	var bonuses: Array = []
	for link: Dictionary in SOURCE.related("ItemBonus","ItemClassID",int(id)):
		var bonus: Dictionary = SOURCE.row("Bonus",int(link.get("BonusID",0))) if _integer(link.get("BonusID")) else {}
		var type: Dictionary = SOURCE.row("BonusType",int(bonus.get("BonusTypeID",0))) if _integer(bonus.get("BonusTypeID")) else {}
		var unit: Dictionary = SOURCE.row("Unit",int(type.get("UnitID",0))) if _integer(type.get("UnitID")) else {}
		var application: Dictionary = SOURCE.row("BonusApplicationType",int(bonus.get("BonusApplicationTypeID",0))) if _integer(bonus.get("BonusApplicationTypeID")) else {}
		var ui: Array = SOURCE.related("UIUnit","UnitID",int(unit.ID)) if not unit.is_empty() else []
		bonuses.append({"link":link,"bonus":bonus,"type":type,"unit":unit,"application_type":application,"ui_units":ui})
	return {"item_class":item,"source_exclusion":_exclusion("ItemClass",item),"bonuses":bonuses}

func _recipes(item_ids: Array) -> void:
	# The unavailable research selected executable recipes. The existing Totem
	# quote does not receive period/server/daily conditions, so no new recipe is
	# admitted to its execution arrays. Preserve exact referenced definitions.
	var seen: Dictionary = {}
	for item_id: int in item_ids:
		for view: Dictionary in SOURCE.related("ItemCraftView","ItemClassID",item_id):
			var key: String = JSON.stringify(view,"",true,true)
			if seen.has(key): continue
			seen[key] = true
			if not _integer(view.get("ItemCraftID")):
				recipe_references.append({"view":view,"reference_only":true,"can_execute":false,"blocker":"non_integral_craft_reference"})
				continue
			var craft_id := int(view.ItemCraftID)
			var inputs: Array = SOURCE.related("ItemCraftInput","ItemCraftID",craft_id)
			var outputs: Array = SOURCE.related("ItemCraftOutputView","ItemCraftID",craft_id)
			var items: Dictionary = {str(item_id):_reference_item(item_id)}
			for rows: Array in [inputs,outputs]:
				for row: Dictionary in rows:
					if _integer(row.get("ItemClassID")): items[str(int(row.ItemClassID))] = _reference_item(row.ItemClassID)
			recipe_references.append({"item_craft":SOURCE.row("ItemCraft",craft_id),"view":view,"inputs":inputs,"outputs":outputs,"items":items,
				"source_exclusion":SOURCE.declared_exclusion("ItemCraftView",view),"reference_only":true,"can_execute":false,
				"blocker":"totem_recipe_selection_and_condition_owner_pending"})
	if not recipe_references.is_empty(): _defer("recipe_selection_and_condition_owner_pending","ItemCraftView",null)

func build() -> Dictionary:
	problem = ""; deferred = []; recipe_references = []; _tables = {}; _ids = {}; _relations = {}
	source_identity = SOURCE.identity()
	if source_identity.is_empty(): problem = "totem_current523_unavailable:"+SOURCE.problem(); return {}
	for table: String in REQUIRED_TABLES: _tables[table] = []
	for table: String in CORE_COUNTS:
		var rows: Array[Dictionary] = SOURCE.rows(table)
		if rows.size()!=CORE_COUNTS[table]: problem = "totem_core_incomplete:"+table; return {}
		for row: Dictionary in rows:
			if not _exclusion(table,row).is_empty(): problem = "totem_core_source_excluded:"+table; return {}
			if not _keep(table,row): return {}
		if _tables[table].size()!=CORE_COUNTS[table]: problem = "totem_core_identity_ambiguous:"+table; return {}
	var queue: Array = []
	var item_ids: Array = []
	for material: Dictionary in _tables.TotemMaterial:
		if not _item(material.get("ItemClassID"),queue): return {}
		if int(material.ItemClassID) not in item_ids: item_ids.append(int(material.ItemClassID))
	for cost: Dictionary in _tables.TotemResetCost:
		var currency: Dictionary = _by_id("Currency",cost.get("CurrencyID"))
		if currency.is_empty(): return {}
		for unit: Dictionary in _owned("CurrencyUnitClass","CurrencyID",int(currency.ID)):
			if _by_id("Unit",unit.get("UnitID")).is_empty(): return {}
			# Exact existing reset payment receiver, not a generalized ClassID.
			if unit.UnitID==4:
				if not _item(unit.get("ClassID"),queue): return {}
				if int(unit.ClassID) not in item_ids: item_ids.append(int(unit.ClassID))
	for table: String in ["TotemBonus","TotemResonance"]:
		for link: Dictionary in _tables[table]:
			if not _queue(queue,"Bonus",link.get("BonusID")): return {}
	for totem: Dictionary in _tables.Totem:
		if not _integer(totem.get("NpcGroupID")): problem = "totem_group_reference_invalid"; return {}
		var relation_key := "NpcClassForNpcGroup:NpcGroupID:"+str(int(totem.NpcGroupID))
		if not _relations.has(relation_key):
			var members: Array = []
			for member: Dictionary in SOURCE.related("NpcClassForNpcGroup","NpcGroupID",int(totem.NpcGroupID)):
				if not _exclusion("NpcClassForNpcGroup",member).is_empty(): continue
				if _by_id("NpcClass",member.get("NpcClassID"),false).is_empty(): continue
				if not _keep("NpcClassForNpcGroup",member): return {}
				members.append(member)
			_relations[relation_key] = members
		if not _queue(queue,"Buff",totem.get("MapBuffClassID"),false): continue
	if not _typed_closure(queue): return {}
	var contexts: Dictionary = _contexts()
	if not problem.is_empty(): return {}
	_recipes(item_ids)
	return {"schema":1,"source_version":523,"input_kind":"twilight.current523.totem-input.v1","tables":_tables,"map_contexts":contexts}
