extends RefCounted
## Original box acquisition references for the existing relic input ABI only.
## No quest ancestry projection, claim, supply, item creation, opening or save.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const BOX: int = 346921
const BAG: int = 81612
const UNLOCK: int = 365748
const SCROLL: int = 365758
const BUFF: int = 95648
const UNLOCK_BONUS: int = 2357388
var problem: String = ""
var source_identity: Dictionary = {}
var exclusions: Array = []
var _positions: Dictionary = {}
var _deferred_source_references: Array = []

func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

func _fail(message: String) -> void:
	if problem.is_empty(): problem = message

func _position(table: String, raw: Dictionary) -> int:
	# Preserve the compiler's zero-based original-row coordinates. Index only
	# identities/coordinates; original rows remain in the common held reader.
	if not _positions.has(table):
		var indexed: Dictionary = {}
		var rows: Array[Dictionary] = SOURCE.rows(table)
		for index: int in range(rows.size()):
			var row: Dictionary = rows[index]
			var row_key: String
			if row.has("ID"):
				if not _integer(row.ID): _fail("relic_acquisition_non_integral_source_id:"+table); return -1
				row_key = "id:"+str(int(row.ID))
			else: row_key = "row:"+JSON.stringify(row,"",true,true)
			if not indexed.has(row_key): indexed[row_key] = []
			indexed[row_key].append(index)
		_positions[table] = indexed
	var key: String
	if raw.has("ID"):
		if not _integer(raw.ID): _fail("relic_acquisition_non_integral_reference:"+table); return -1
		key = "id:"+str(int(raw.ID))
		if SOURCE.row(table,int(raw.ID))!=raw: _fail("relic_acquisition_original_row_mismatch:"+table); return -1
	else: key = "row:"+JSON.stringify(raw,"",true,true)
	var matches: Array = _positions[table].get(key,[])
	if matches.size()!=1: _fail("relic_acquisition_row_coordinate_missing_or_ambiguous:"+table); return -1
	return int(matches[0])

func _node(table: String, raw: Dictionary) -> Dictionary:
	var index := _position(table,raw)
	if index<0: return {}
	var node := {"table":table,"row_index_zero":index,"raw":raw.duplicate(true)}
	var declaration: Dictionary = SOURCE.declared_exclusion(table,raw)
	if not declaration.is_empty():
		exclusions.append({"node":node,"evidence":declaration})
		_fail("relic_acquisition_source_declared_exclusion:"+table)
		return {}
	if table=="ItemClass":
		if not raw.get("TestItem") is bool:
			exclusions.append({"node":node,"reason":"source_test_declaration_unavailable","field":"TestItem"})
			_fail("relic_acquisition_ItemClass_TestItem_contract_unavailable")
			return {}
		if raw.TestItem:
			exclusions.append({"node":node,"reason":"source_test_declaration","field":"TestItem"})
			_fail("relic_acquisition_source_TestItem_true")
			return {}
	if table=="BuffClass" and raw.get("TestBuff") is bool and raw.TestBuff:
		exclusions.append({"node":node,"reason":"source_test_declaration","field":"TestBuff"})
		_fail("relic_acquisition_source_TestBuff_true")
		return {}
	return node

func _get(table: String, id: Variant) -> Dictionary:
	if not _integer(id) or int(id)<0: _fail("relic_acquisition_invalid_reference:"+table); return {}
	var matches: Array[Dictionary] = SOURCE.related(table,"ID",int(id))
	if matches.size()!=1: _fail("relic_acquisition_reference_missing_or_ambiguous:"+table+":"+str(int(id))); return {}
	return _node(table,matches[0])

func _owned(table: String, field: String, id: int) -> Array:
	if SOURCE.table_metadata(table).is_empty(): _fail("relic_acquisition_source_table_unavailable:"+table); return []
	var result: Array = []
	for raw: Dictionary in SOURCE.related(table,field,id):
		if not _integer(raw.get(field)) or int(raw[field])!=id: _fail("relic_acquisition_source_owner_mismatch:"+table); return []
		var node: Dictionary = _node(table,raw)
		if node.is_empty(): return []
		result.append(node)
	return result

func _description_refs(raw: Dictionary) -> Dictionary:
	# Text is deferred by the user's priority. Preserve source references without
	# reading a description member or making text availability a numeric gate.
	var result: Dictionary = {}
	for field: String in ["DescID","IdentifiedDescID","StoryDescID","ProductTitleDescID","ProductDescID"]:
		if not raw.has(field): continue
		var reference := {"table":"DescData_Korean","field":field,"id":raw[field],"item_class_id":raw.get("ID"),"deferred":true,"reason":"user_deferred_description_text"}
		result[field] = reference
		_deferred_source_references.append(reference.duplicate(true))
	return result

func _effect(table: String, raw: Dictionary) -> Dictionary:
	var link: Dictionary = _node(table,raw)
	var bonus: Dictionary = _get("Bonus",raw.get("BonusID"))
	if link.is_empty() or bonus.is_empty(): return {}
	var type: Dictionary = _get("BonusType",bonus.raw.get("BonusTypeID"))
	if type.is_empty(): return {}
	var unit: Dictionary = _get("Unit",type.raw.get("UnitID"))
	if unit.is_empty(): return {}
	var effect := {"link":link,"bonus":bonus,"type":type,"unit":unit}
	# The reviewed compiler selects the first original UIUnit owner row.
	var ui_rows: Array[Dictionary] = SOURCE.related("UIUnit","UnitID",int(type.raw.UnitID))
	if not ui_rows.is_empty():
		var ui: Dictionary = _node("UIUnit",ui_rows[0])
		if ui.is_empty(): return {}
		effect["ui_unit"] = ui
	return effect

func _effects(table: String, field: String, id: int) -> Array:
	if SOURCE.table_metadata(table).is_empty(): _fail("relic_acquisition_source_table_unavailable:"+table); return []
	var result: Array = []
	for raw: Dictionary in SOURCE.related(table,field,id):
		if not _integer(raw.get(field)) or int(raw[field])!=id: _fail("relic_acquisition_effect_owner_mismatch:"+table); return []
		var effect: Dictionary = _effect(table,raw)
		if effect.is_empty(): return []
		result.append(effect)
	return result

func _item(id: int) -> Dictionary:
	var item: Dictionary = _get("ItemClass",id)
	if item.is_empty(): return {}
	var category: Dictionary = _get("ItemCategory",item.raw.get("CategoryID"))
	var grade: Dictionary = _get("Grade",item.raw.get("GradeID"))
	if category.is_empty() or grade.is_empty(): return {}
	var limits: Array = _owned("ItemClassLimit","ItemClassID",id)
	var description_refs: Dictionary = _description_refs(item.raw)
	var effects: Array = _effects("ItemBonus","ItemClassID",id)
	if not problem.is_empty(): return {}
	return {"item":item,"category":category,"grade":grade,"class_limits":limits,"descriptions":{},"description_refs":description_refs,"effects":effects}

func _unlock(definition: Dictionary) -> bool:
	var typed_link := false
	for effect: Dictionary in definition.effects:
		if effect.bonus.raw.get("ID")==UNLOCK_BONUS and effect.type.raw.get("Name")=="BuffClassID" and effect.unit.raw.get("Name")=="BuffClassID" and effect.type.raw.get("UnitID")==16 and effect.bonus.raw.get("Value")==BUFF:
			typed_link = true
	if not typed_link: _fail("relic_acquisition_unlock_typed_buff_reference_unavailable"); return false
	var buff: Dictionary = _get("BuffClass",BUFF)
	var effects: Array = _effects("BuffBonus","BuffClassID",BUFF)
	var use_desc: Dictionary = _get("UseDesc",definition.item.raw.get("UseDescID"))
	if buff.is_empty() or use_desc.is_empty() or not problem.is_empty(): return false
	var description_ref := {"table":"DescData_Korean","field":"DescID","id":use_desc.raw.get("DescID"),"source_table":"UseDesc","source_id":use_desc.raw.get("ID"),"deferred":true,"reason":"user_deferred_description_text"}
	definition["buff"] = buff
	definition["buff_effects"] = effects
	definition["use_desc"] = use_desc
	definition["use_description"] = {}
	definition["use_description_ref"] = description_ref
	_deferred_source_references.append(description_ref.duplicate(true))
	return true

func _complete_entities() -> Array:
	var rows: Array[Dictionary] = SOURCE.related("LuckyBagEntityView","LuckyBagClassID",BAG)
	# Apply the complete original two-row/order guard before any exclusion,
	# dependency filtering or model adoption. Probability0 stays non-random.
	if rows.size()!=2: _fail("relic_acquisition_complete_two_row_box_required"); return []
	var expected := [UNLOCK,SCROLL]
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		for field: String in ["ID","LuckyBagClassID","ItemClassID","ItemAmount","LuckyBagEntityTypeID","Probability","ItemBlessCodeID","ItemEnchant","LimitClass","EquipSlotID"]:
			if not _integer(row.get(field)): _fail("relic_acquisition_box_integer_contract_invalid:"+field); return []
		if int(row.LuckyBagClassID)!=BAG or row.ItemClassID!=expected[index] or row.ItemAmount!=1 or row.LuckyBagEntityTypeID!=1 or row.Probability!=0 or row.ItemBlessCodeID!=1 or row.ItemEnchant!=0:
			_fail("relic_acquisition_reviewed_box_contents_changed")
			return []
	return rows

func build() -> Dictionary:
	problem = ""; exclusions = []; _positions = {}; _deferred_source_references = []
	source_identity = SOURCE.identity()
	if source_identity.is_empty(): _fail("relic_acquisition_current523_unavailable:"+SOURCE.problem()); return {}
	var entities: Array = _complete_entities()
	if entities.is_empty(): return {}
	var box: Dictionary = _item(BOX)
	if box.is_empty(): return {}
	var bag_links := 0
	for effect: Dictionary in box.effects:
		if effect.type.raw.get("Name")=="LuckyBagClassID" and effect.unit.raw.get("Name")=="LuckyBagClassID" and effect.bonus.raw.get("Value")==BAG: bag_links+=1
	if box.effects.size()!=1 or bag_links!=1: _fail("relic_acquisition_box_typed_LuckyBagClassID_unavailable"); return {}
	var bag: Dictionary = _get("LuckyBagClass",BAG)
	if bag.is_empty(): return {}
	var contents: Array = []
	var type_counts: Dictionary = {}
	for raw: Dictionary in entities:
		var entity: Dictionary = _node("LuckyBagEntityView",raw)
		var type: Dictionary = _get("LuckyBagEntityType",raw.LuckyBagEntityTypeID)
		var grade: Dictionary = _get("Grade",raw.get("GradeID"))
		var category: Dictionary = _get("ItemCategory",raw.get("CategoryID"))
		var bless: Dictionary = _get("ItemBlessCode",raw.ItemBlessCodeID)
		if entity.is_empty() or type.is_empty() or grade.is_empty() or category.is_empty() or bless.is_empty(): return {}
		if type.raw.get("Name")!="IsGiven": _fail("relic_acquisition_entity_type_not_IsGiven"); return {}
		var limits: Array = _owned("LuckyBagEntityClassLimit","LuckyBagEntityID",int(raw.ID))
		var item: Dictionary = _item(int(raw.ItemClassID))
		if item.is_empty() or not problem.is_empty(): return {}
		if int(raw.ItemClassID)==UNLOCK and not _unlock(item): return {}
		contents.append({"entity":entity,"type":type,"grade":grade,"category":category,"bless_code":bless,"class_limits":limits,"item_definition":item})
		var name: String = type.raw.Name
		type_counts[name] = int(type_counts.get(name,0))+1
	box["lucky_bag"] = bag
	box["contents"] = contents
	box["content_type_counts"] = type_counts
	var bonus_names: Array = []
	for effect: Dictionary in box.effects: bonus_names.append(effect.type.raw.get("Name"))
	var levels: Dictionary = {}
	for field: String in ["LevelLimitMin","LevelLimitMax","MaxLevelLimitMin","MaxLevelLimitMax"]:
		if not box.item.raw.has(field): _fail("relic_acquisition_box_level_contract_missing:"+field); return {}
		levels[field] = box.item.raw[field]
	if not box.item.raw.has("ServiceRegionCode"): _fail("relic_acquisition_box_service_scope_missing"); return {}
	box["source_constraint_summary"] = {"item_bonus_names":bonus_names,"item_level_limits":levels,"service_region_code":box.item.raw.ServiceRegionCode,
		"content_limit_class_values":[entities[0].LimitClass,entities[1].LimitClass],"content_equip_slot_values":[entities[0].EquipSlotID,entities[1].EquipSlotID],
		"warning":"Raw scope, LimitClass and EquipSlotID remain uninterpreted; the existing consumer rules_valid is still required."}
	if not problem.is_empty(): return {}
	return {"schema":1,"source_snapshot":"patch523","source_zip_sha256":source_identity.get("source_sha256",""),"box":box,
		"quest_provider_boundary":{"provider":"existing_SourceQuest_original_loader","target_quest_id":96201,"prerequisite_quest_id":92794,
			"ancestry_projection":"provider_owned_not_duplicated","claim_authorized":false,"automatic_supply_authorized":false},
		"deferred_source_references":_deferred_source_references,
		"execution_boundaries":{"open_policy":"Existing explicit box consumer rules_valid, exact physical ownership and atomic save remain required; input projection authorizes no action.",
			"quest_reference_state_semantics":"Owned by the existing SourceQuest provider; do not infer ancestry completion or prior reward claims.",
			"source_execution":"Static content references only; no supply, claim, opening, effect or transaction is executed."}}

