extends RefCounted
## Missing native enhancement operands for the existing shared receiver.
## Read-only: the existing equipment/rules owners retain physical/save authority.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const ENHANCE = preload("res://scripts/crafting/patch523_enhancement.gd")
static var evidence: Dictionary = {}

static func integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _original_delta(item_id: int, effects: Array, level: int, blessing: int) -> Dictionary:
	var groups: Dictionary = {}; var selectors: Dictionary = {}
	for link: Dictionary in SOURCE.related("ItemBonus","ItemClassID",item_id):
		var bonus: Dictionary = SOURCE.row("Bonus",int(link.get("BonusID",-1)))
		var type: Dictionary = SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1)))
		if type.get("Name")!="EnchantBonusGroupID": continue
		var unit: Dictionary = SOURCE.row("Unit",int(type.get("UnitID",-1)))
		if unit.get("Name")!="EnchantBonusGroupID" or not SOURCE.declared_exclusion("Unit",unit).is_empty(): continue
		if link.get("IsPossession")!=false or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0 or not integer(bonus.get("Value")): continue
		if not SOURCE.declared_exclusion("ItemBonus",link).is_empty() or not SOURCE.declared_exclusion("Bonus",bonus).is_empty() or not SOURCE.declared_exclusion("BonusType",type).is_empty(): continue
		if selectors.has(int(bonus.Value)): return {}
		selectors[int(bonus.Value)]={"link":link,"bonus":bonus,"type":type,"unit":unit}
	var seen_rows: Dictionary = {}
	for row: Variant in effects:
		if not row is Dictionary or not integer(row.get("ID")) or not integer(row.get("ItemEnchantBonusGroupID")) or not integer(row.get("BlessCode")): return {}
		var originals: Array[Dictionary] = SOURCE.related("ItemEnchantBonus","ID",int(row.ID))
		if originals.size()!=1 or originals[0]!=row or not SOURCE.declared_exclusion("ItemEnchantBonus",row).is_empty(): return {}
		if seen_rows.has(int(row.ID)): return {}
		seen_rows[int(row.ID)]=true
		var group: int = int(row.ItemEnchantBonusGroupID)
		if not groups.has(group): groups[group]=[]
		groups[group].append(row)
	var total: float = 0.0; var used: Array = []
	for group: int in groups:
		if not selectors.has(group): continue
		var codes: Dictionary = {}
		for row: Dictionary in groups[group]: codes[int(row.BlessCode)]=true
		var selected_code: int = blessing if codes.has(blessing) else 0
		for row: Dictionary in groups[group]:
			if row.BlessCode!=selected_code: continue
			var bonus: Dictionary = SOURCE.row("Bonus",int(row.get("BonusID",-1)))
			var type: Dictionary = SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1)))
			if type.get("Name")!="PierceMagicShieldPercent": continue
			var unit: Dictionary = SOURCE.row("Unit",int(type.get("UnitID",-1)))
			if unit.get("Name")!="ValuePercent" or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0 or not integer(row.get("EnchantLevel")): return {}
			# Whole-value +0 families need their owner's baseline subtraction;
			# they must never be added to a separately supplied base operand here.
			if int(row.EnchantLevel)==0: return {}
			if int(row.EnchantLevel)!=level: continue
			for pair: Array in [["Bonus",bonus],["BonusType",type],["Unit",unit]]:
				if not SOURCE.declared_exclusion(pair[0],pair[1]).is_empty(): return {}
			var value: Variant = bonus.get("Value")
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return {}
			total+=float(value) # ValuePercent is already percentage points.
			used.append({"selector":selectors[group],"row":row,"bonus":bonus,"type":type,"unit":unit})
	return {"value":total,"rows":used} if not used.is_empty() and is_finite(total) else {}

static func sum_native(world: Node, key: String) -> float:
	if key!="magic_penetration_pct" or not is_instance_valid(world): return 0.0
	evidence.clear()
	var identity: Dictionary = SOURCE.identity()
	if identity.is_empty(): return 0.0
	var total: float = 0.0; var visited: Dictionary = {}
	for slot: String in world.EQUIPMENT_SLOT_ORDER:
		var worn: Dictionary = world.equipped_items.get(slot,{})
		var physical_id: String = str(worn.get("instance_id",""))
		if physical_id.is_empty() or visited.has(physical_id): continue
		visited[physical_id]=true
		var physical: Dictionary = world.item_instances.get(physical_id,{})
		if physical.is_empty() or physical.get("name")!=worn.get("name") or not integer(physical.get("level",0)): continue
		var level: int = int(physical.get("level",0))
		if level<0 or level>20: continue # No missing-rank extrapolation.
		var current: Dictionary = world._source_catalog_record("아이템",worn)
		if current.get("source")!="lineagem_patch523" or current.get("source_snapshot")!="patch523" or current.get("source_projection")!="current523_original_typed_game_dto_v1" or current.get("source_m_native_item")!=true or current.get("source_test_item")!=false or current.get("source_equipment_status")!="mapped" or current.get("source_legacy_catalog_alias",false) or current.get("source_legacy_stack_variant",false): continue
		if current.get("_patch523_effective_extras",false) and current.has(key): continue # Already in the normal sum.
		var id: Variant = current.get("source_item_class_id")
		if not integer(id) or int(id)<=0 or current.get("sourceId")!="m523:item:"+str(int(id)) or current.get("source_definition_archive")!=identity: continue
		var raw: Dictionary = SOURCE.row("ItemClass",int(id))
		if raw.is_empty() or raw!=current.get("source_original_item") or raw.get("TestItem")!=false or not SOURCE.declared_exclusion("ItemClass",raw).is_empty(): continue
		if physical.has("sourceId") and physical.sourceId!=current.get("sourceId"): continue
		var blessing: int = world.patch523_equipment.bless_code(physical)
		if blessing not in [1,2]: continue
		var prepared: Dictionary = world._physical_enhancement_record(worn)
		if prepared.get("source")!="lineagem_patch523" or prepared.get("source_snapshot")!="patch523" or prepared.get("source_projection")!="current523_original_typed_game_dto_v1" or prepared.get("source_m_native_item")!=true or prepared.get("sourceId")!=current.get("sourceId") or prepared.get("source_item_class_id")!=id or prepared.get("source_definition_archive")!=identity or prepared.get("source_original_item")!=raw: continue
		var basis: Dictionary = prepared.get("patch523_effect_basis",{})
		var item_key: String = ENHANCE.item_id(prepared)
		if item_key!=str(int(id)) or basis.get("selection")!="source_exact_level" or basis.get("sha256")!=world.patch523_equipment.digest or not world.patch523_equipment.catalog_identity_matches(prepared,item_key): continue
		var bound: Dictionary = world.patch523_equipment.data.get("items",{}).get(item_key,{})
		if bound.get("item_class")!=raw: continue
		var expected: Variant = world.patch523_equipment.data.get("equipment_runtime",{}).get(item_key,{}).get("extra_options",{}).get(str(blessing),{}).get(str(level),{}).get(key)
		var actual: Variant = prepared.get("enhancement_extra_options",{}).get(str(level),{}).get(key)
		if typeof(expected) not in [TYPE_INT,TYPE_FLOAT] or typeof(actual) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(expected)) or not is_finite(float(actual)) or actual!=expected: continue
		var effects: Variant = bound.get("enchant_effects")
		if not effects is Array: continue
		var source: Dictionary = _original_delta(int(id),effects,level,blessing)
		if source.is_empty() or source.value!=expected: continue
		total+=float(expected)
		evidence[physical_id]={"source":identity,"item_class_id":id,"level":level,"bless_code":blessing,"rows":source.rows,"value":expected,"model_sha256":world.patch523_equipment.digest}
	return total if is_finite(total) else 0.0
