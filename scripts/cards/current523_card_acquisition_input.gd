extends RefCounted
## UNVERIFIED: exact public Nemesis recipe input in the existing consumer ABI.
## No native/physical item DTO, source-currency ownership, craft/open or save.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const RECIPE: int = 258482
const COIN: int = 3252
const CURRENCY: int = 1102
const TICKET: int = 370562
const CARD: int = 25152
const BONUS: int = 2392192
## Foreign-language calendars are cut from the game (user decision 2026-11-10).
const CALENDARS = ["DateTimes","DateTimes_Korean"]
var problem: String = ""
var source_identity: Dictionary = {}
var exclusions: Array = []
var unavailable_source_definitions: Array = []
var deferred_source_references: Array = []
var _tables: Dictionary = {}
var _metadata: Dictionary = {}

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

static func _exact(value: Variant, expected: int) -> bool:
	return _integer(value) and int(value) == expected

func _fail(reason: String, evidence: Dictionary = {}) -> Dictionary:
	if problem.is_empty(): problem = reason
	unavailable_source_definitions.append({"reason":reason,"evidence":evidence,"source_identity":source_identity})
	return {}

func _rows(table: String) -> Array:
	if _tables.has(table): return _tables[table]
	var metadata: Dictionary = SOURCE.table_metadata(table)
	if metadata.get("version") != 523 or metadata.get("path") != "content/"+table+".json" or not _integer(metadata.get("row_count")) or not metadata.get("sha256") is String:
		_fail("missing_source_table_metadata:"+table,{"table":table,"metadata":metadata,"source_problem":SOURCE.problem()})
		return []
	var rows: Array[Dictionary] = SOURCE.rows(table)
	if rows.size() != int(metadata.row_count):
		_fail("missing_source_table_rows:"+table,{"table":table,"metadata":metadata,"source_problem":SOURCE.problem()})
		return []
	_tables[table] = rows
	_metadata[table] = metadata
	return rows

func _ref(table: String, row: Dictionary, position: int) -> Dictionary:
	var node: Dictionary = {"table":table,"row_index_zero":position,"raw":row}
	var declaration: Dictionary = SOURCE.declared_exclusion(table,row)
	if not declaration.is_empty():
		exclusions.append({"reference":node,"evidence":declaration})
		return _fail("source_declared_exclusion:"+table,{"reference":node,"declaration":declaration})
	if table == "ItemClass":
		if typeof(row.get("TestItem")) != TYPE_BOOL:
			return _fail("source_TestItem_missing_or_invalid",node)
		if row.TestItem:
			exclusions.append({"reference":node,"test_declaration":{"field":"TestItem","value":true}})
			return _fail("source_TestItem_true",node)
	return node

func _selected(table: String, field: String, value: Variant) -> Array:
	var result: Array = []
	if not _integer(value) or int(value)<0:
		_fail("invalid_source_reference:"+table+":"+field,{"value":value})
		return result
	var rows: Array = _rows(table)
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		if not _integer(row.get(field)):
			_fail("invalid_source_join_field:"+table+":"+field,{"table":table,"row_index_zero":index,"raw":row})
			return []
		if int(row[field]) != int(value): continue
		var node: Dictionary = _ref(table,row,index)
		if node.is_empty(): return []
		result.append(node)
	return result

func _source_row(table: String, id: Variant, required: bool = true) -> Dictionary:
	var selected: Array = _selected(table,"ID",id)
	if not problem.is_empty(): return {}
	if selected.size()>1:
		return _fail("ambiguous_source_reference:"+table+":"+str(id),{"table":table,"id":id,"matches":selected})
	if selected.is_empty():
		if required: return _fail("missing_source_reference:"+table+":"+str(id),{"table":table,"id":id})
		return {}
	return selected[0]

func _description_refs(node: Dictionary, fields: Array) -> Dictionary:
	# Description text is deferred. Empty descriptions below do not assert
	# that original text is absent, and no text lookup can reject this model.
	var result: Dictionary = {}
	var row: Dictionary = node.raw
	for field: String in fields:
		if not row.has(field): continue
		var reference: Dictionary = {"table":"DescData_Korean","id":row[field],"deferred":true}
		result[field] = reference
		deferred_source_references.append({"from":{"table":node.table,"row_index_zero":node.row_index_zero,
			"id":row.get("ID"),"field":field},"target":reference,"deferred":true})
	return result

func _effect(link: Dictionary) -> Dictionary:
	var bonus: Dictionary = _source_row("Bonus",link.raw.get("BonusID"))
	if bonus.is_empty(): return {}
	var type: Dictionary = _source_row("BonusType",bonus.raw.get("BonusTypeID"))
	if type.is_empty(): return {}
	var unit: Dictionary = _source_row("Unit",type.raw.get("UnitID"))
	if unit.is_empty(): return {}
	var result: Dictionary = {"link":link,"bonus":bonus,"type":type,"unit":unit}
	var display: Array = _selected("UIUnit","UnitID",type.raw.get("UnitID"))
	if display.size()>1: return _fail("ambiguous_source_display_unit",{"type":type,"matches":display})
	if display.size()==1: result["ui_unit"] = display[0]
	return result

func _item(id: Variant) -> Dictionary:
	var item: Dictionary = _source_row("ItemClass",id)
	if item.is_empty(): return {}
	var category: Dictionary = _source_row("ItemCategory",item.raw.get("CategoryID"))
	var grade: Dictionary = _source_row("Grade",item.raw.get("GradeID"))
	if category.is_empty() or grade.is_empty(): return {}
	# record() already consumes these exact fields; retain source values and
	# reject absent shapes rather than supply a fabricated physical DTO.
	if not item.raw.get("Name") is String or str(item.raw.Name).is_empty() or typeof(item.raw.get("Weight")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(item.raw.Weight)) or typeof(category.raw.get("IsStackable")) != TYPE_BOOL:
		return _fail("missing_source_item_record_fields",{"item":item,"category":category})
	for field: String in ["IsDroppable","IsStorable"]:
		if typeof(item.raw.get(field)) != TYPE_BOOL: return _fail("missing_source_item_record_field:"+field,item)
	var effects: Array = []
	for link: Dictionary in _selected("ItemBonus","ItemClassID",id):
		var effect: Dictionary = _effect(link)
		if effect.is_empty(): return {}
		effects.append(effect)
	return {"item":item,"category":category,"grade":grade,
		"descriptions":{},"description_refs":_description_refs(item,["DescID","IdentifiedDescID","StoryDescID","ProductTitleDescID","ProductDescID"]),
		"class_limits":_selected("ItemClassLimit","ItemClassID",id),"effects":effects}

func _payload(table: String, link: Dictionary) -> Dictionary:
	if link.get("table") != table: return _fail("source_payload_table_mismatch",link)
	var bless: Dictionary = _source_row("ItemBlessCode",link.raw.get("ItemBlessCodeID"))
	if bless.is_empty(): return {}
	var result: Dictionary = {"link":link,"bless_code":bless}
	if not _integer(link.raw.get("ItemClassID")): return _fail("invalid_source_payload_ItemClassID",link)
	if int(link.raw.ItemClassID)!=0:
		var item: Dictionary = _item(link.raw.ItemClassID)
		if item.is_empty(): return {}
		result["item_definition"] = item
	if link.raw.has("DescID"):
		result["descriptions"] = {}
		result["description_refs"] = _description_refs(link,["DescID"])
	return result

func _reviewed_conditions(model: Dictionary) -> bool:
	var view: Dictionary = model.view.raw
	if not _exact(view.get("ItemCraftID"),RECIPE) or not _exact(view.get("AlwaysSuccess"),1) or not _exact(view.get("ServerLimitSetID"),0) or view.get("IsBelowLevelLimit") != false or typeof(view.get("IsBelowLevelLimit")) != TYPE_BOOL or not _exact(view.get("LevelLimitValue"),0) or view.get("NoRepeat") != false or typeof(view.get("NoRepeat")) != TYPE_BOOL or not model.restrictions.is_empty() or model.inputs.size()!=1 or model.outputs.size()!=1:
		_fail("reviewed_Nemesis_view_or_relation_contract_changed",{"view":model.view,"inputs":model.inputs,"outputs":model.outputs,"restrictions":model.restrictions})
		return false
	var input: Dictionary = model.inputs[0].link.raw
	var output: Dictionary = model.outputs[0].link.raw
	for field: String in ["ID","ItemClassID","Amount","Enchant","ItemBlessCodeID","ItemHoningEpithetID"]:
		var expected: int = {"ID":500592,"ItemClassID":COIN,"Amount":3000000,"Enchant":0,"ItemBlessCodeID":1,"ItemHoningEpithetID":0}[field]
		if not _exact(input.get(field),expected):
			_fail("reviewed_Nemesis_input_contract_changed:"+field,model.inputs[0])
			return false
	for field: String in ["ID","ItemClassID","Amount","Probability","Enchant","ItemBlessCodeID","ClanItemClassID","ClanAmount"]:
		var expected: int = {"ID":369922,"ItemClassID":TICKET,"Amount":1,"Probability":1000000,"Enchant":0,"ItemBlessCodeID":1,"ClanItemClassID":0,"ClanAmount":0}[field]
		if not _exact(output.get(field),expected):
			_fail("reviewed_Nemesis_output_contract_changed:"+field,model.outputs[0])
			return false
	var effects: Array = model.outputs[0].item_definition.effects
	if effects.size()!=1:
		_fail("reviewed_Nemesis_ticket_effect_count_changed",model.outputs[0].item_definition)
		return false
	var effect: Dictionary = effects[0]
	if not _exact(effect.bonus.raw.get("ID"),BONUS) or effect.type.raw.get("Name") != "BuffCardID" or effect.unit.raw.get("Name") != "BuffCardID" or not _exact(effect.bonus.raw.get("Value"),CARD) or not _exact(effect.bonus.raw.get("BonusApplicationTypeID"),0) or not _exact(effect.bonus.raw.get("BonusApplicationTargetID"),0) or typeof(effect.link.raw.get("IsPossession")) != TYPE_BOOL or effect.link.raw.IsPossession or not _exact(model.card.raw.get("BuffCardDeckID"),2):
		_fail("reviewed_Nemesis_ticket_dispatch_changed",{"effect":effect,"card":model.card})
		return false
	return true

func build() -> Dictionary:
	problem = ""; exclusions = []; unavailable_source_definitions = []; deferred_source_references = []
	_tables.clear(); _metadata.clear()
	source_identity = SOURCE.identity()
	if source_identity.is_empty(): return _fail("current523_original_unavailable",{"source_problem":SOURCE.problem()})
	var views: Array = _selected("ItemCraftView","ItemCraftID",RECIPE)
	if not problem.is_empty(): return {}
	if views.size()!=1: return _fail("missing_Nemesis_craft_view" if views.is_empty() else "ambiguous_Nemesis_craft_view",{"matches":views})
	var view: Dictionary = views[0]
	var model: Dictionary = {"view":view,"inputs":[],"outputs":[],"restrictions":_selected("ItemCraftRestriction","ItemCraftID",RECIPE),
		"recommendations":_selected("ItemCraftRecommend","ItemCraftID",RECIPE),"categories":{},"dates":{},
		"server_limits":_selected("ServerLimit","ServerLimitSetID",view.raw.get("ServerLimitSetID"))}
	for pair: Array in [["ItemCraftInput","inputs"],["ItemCraftOutputView","outputs"]]:
		for link: Dictionary in _selected(pair[0],"ItemCraftID",RECIPE):
			var payload: Dictionary = _payload(pair[0],link)
			if payload.is_empty(): return {}
			model[pair[1]].append(payload)
	model["card"] = _source_row("BuffCard",CARD)
	if model.card.is_empty(): return {}
	model["deck"] = _source_row("BuffCardDeck",model.card.raw.get("BuffCardDeckID"))
	model["source_flags"] = _source_row("BuffCardSourceView",CARD)
	model["source_craft_links"] = _selected("BuffCardSourceCraftView","ID",CARD)
	model["coin_currency"] = _source_row("Currency",CURRENCY)
	model["currency_item_unit"] = _source_row("Unit",4)
	model["coin_currency_bindings"] = []
	for binding: Dictionary in _selected("CurrencyUnitClass","CurrencyID",CURRENCY):
		if _exact(binding.raw.get("UnitID"),4) and _exact(binding.raw.get("ClassID"),COIN): model.coin_currency_bindings.append(binding)
	model["coin_source_hints"] = _selected("ItemCraftInputSource","ItemClassID",COIN)
	if not problem.is_empty(): return {}
	if model.deck.is_empty() or model.source_flags.is_empty() or model.coin_currency.is_empty() or model.currency_item_unit.is_empty() or model.coin_currency_bindings.is_empty() or model.currency_item_unit.raw.get("Name") != "ItemClassID":
		return _fail("missing_typed_Nemesis_card_or_currency_contract",model)
	if not _reviewed_conditions(model): return {}
	var has_calendar: bool = false
	for calendar: String in CALENDARS:
		var bounds: Dictionary = {"EffectiveFrom":null,"EffectiveTo":null}
		for field: String in ["EffectiveFrom","EffectiveTo"]:
			var node: Dictionary = _source_row(calendar,view.raw.get(field),false)
			if not node.is_empty():
				for part: String in ["Year","Month","Day","Hour","Minute"]:
					if not _integer(node.raw.get(part)): return _fail("missing_original_calendar_field:"+part,node)
				bounds[field] = node
		model.dates[calendar] = bounds
		if (bounds.EffectiveFrom == null) != (bounds.EffectiveTo == null): return _fail("missing_original_calendar_bound_pair",{"calendar":calendar,"bounds":bounds})
		if bounds.EffectiveFrom != null: has_calendar = true
	if not problem.is_empty(): return {}
	if not has_calendar: return _fail("missing_complete_original_Nemesis_calendar",{"view":view,"dates":model.dates})
	for pair: Array in [["MainCategoryID","ItemCraftMainCategory"],["SubCategoryID","ItemCraftSubCategory"],["Sub2CategoryID","ItemCraftSub2Category"],["CraftGroupTypeID","ItemCraftGroupType"]]:
		var category: Dictionary = _source_row(pair[1],view.raw.get(pair[0]),false)
		if not category.is_empty(): model.categories[pair[0]] = {"row":category,"descriptions":{},"description_refs":_description_refs(category,["DescID"])}
	if not problem.is_empty(): return {}
	# Sole output probability is preserved directly, never generalized as a
	# denominator or as a random-pool formula for other recipes.
	model["raw_probability_sum"] = model.outputs[0].link.raw.Probability
	model["deferred_source_references"] = deferred_source_references.duplicate(true)
	var hashes: Dictionary = {}
	for table: String in _metadata: hashes[table] = _metadata[table].sha256
	return {"schema":1,"source_snapshot":"patch523","source_zip_sha256":source_identity.get("source_sha256"),
		"source_identity":source_identity.duplicate(true),"source_table_sha256":hashes,"source_table_metadata":_metadata.duplicate(true),
		"deferred_source_references":deferred_source_references.duplicate(true),
		"guaranteed_nemesis":model,"diagnostics":{"runtime_enabled":false,"scope":"reviewed_recipe_only",
			"unavailable_source_definitions":unavailable_source_definitions.duplicate(true),"source_exclusion_evidence":exclusions.duplicate(true)},
		"execution_boundaries":{"projection":"tools/build_patch523_card_acquisition.py@b37e5b941d189351906a4a60e411ad1d07566aeb",
			"ownership":"Existing source-currency/physical ticket/craft/open/save owners remain authoritative",
			"date_policy":"Original calendar rows/null only; existing time_available owns clock/boundary checks"}}

