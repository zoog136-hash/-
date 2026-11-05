extends RefCounted
## Original ItemClass reference contract for existing supplier/catalog readers.
## Data visibility never authorizes acquisition, effects or a save transaction.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const COMPILED_ITEMS = preload("res://scripts/loot/patch523_monster_drops.gd")
const SPELLS = preload("res://scripts/resources/current523_spell_data.gd")
const REWARDS = preload("res://scripts/resources/current523_reward_data.gd")
const BONUSES = preload("res://scripts/resources/current523_bonus_data.gd")
const BUFFS = preload("res://scripts/resources/current523_buff_data.gd")
const GACHA_CRAFT = preload("res://scripts/resources/current523_gacha_craft_data.gd")
const MARKET_GOTCHA = preload("res://scripts/resources/current523_market_gotcha_data.gd")

static func _missing(blockers: Array[String], table: String, id: int) -> Dictionary:
	var value: Dictionary = SOURCE.row(table,id)
	if value.is_empty(): blockers.append("missing_source_reference:"+table+":"+str(id))
	return value

static func _compiled(item_id: int) -> Dictionary:
	# Reuse the existing pinned private sidecars. A compact catalog row alone
	# does not contain the full original joins and is not a replacement for them.
	var value: Dictionary = COMPILED_ITEMS.definition_id(str(item_id))
	if value.get("original_item",{}).get("ID") != item_id or not value.get("unresolved_source_reference","").is_empty(): return {}
	return value

static func _link(joined: Dictionary, nested: Array[String]) -> Dictionary:
	var value: Dictionary = joined.duplicate(true)
	for field: String in nested: value.erase(field)
	return value

static func _effects(table: String, owner_field: String, id: int, blockers: Array[String]) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	for link: Dictionary in SOURCE.related(table,owner_field,id):
		var detail: Dictionary = BONUSES.describe(int(link.get("BonusID",-1)))
		for issue: Variant in detail.get("blockers",[]): blockers.append(str(issue))
		effects.append({"link":link,"bonus":detail.get("bonus",{}),"type":detail.get("type",{}),"unit":detail.get("unit",{}),"definition":detail})
	return effects

static func _target_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _target_node(table: String, row: Dictionary, blockers: Array[String]) -> Dictionary:
	var node: Dictionary = {"table":table,"row":row,"source":SOURCE.identity(),"excluded":false,
		"reference_only":true,"can_activate":false,"ownership_authorized":false}
	if row.is_empty(): return node
	var exclusion: Dictionary = SOURCE.declared_exclusion(table,row)
	if not exclusion.is_empty():
		node.excluded = true
		node["declared_exclusion"] = exclusion
	if table == "ItemClass":
		var test: Variant = row.get("TestItem")
		node["test_declaration"] = {"field":"TestItem","present":row.has("TestItem"),"value":test}
		if typeof(test) == TYPE_BOOL and test:
			node.excluded = true
			node["test_exclusion_reason"] = "source_TestItem_true"
		elif typeof(test) != TYPE_BOOL:
			blockers.append("source_test_declaration_missing")
	return node

static func _target_row(table: String, id: Variant, blockers: Array[String], unresolved: Array[Dictionary]) -> Dictionary:
	var node: Dictionary = _target_node(table,{},blockers)
	node["id"] = id
	node["source_table_metadata"] = SOURCE.table_metadata(table)
	if not _target_integer(id) or int(id)<0:
		blockers.append("invalid_source_reference:"+table)
		unresolved.append({"target":{"table":table,"id":id},"reason":"invalid_source_reference"})
		return node
	if node.source_table_metadata.is_empty():
		blockers.append("missing_source_reference:"+table+":"+str(int(id)))
		unresolved.append({"target":{"table":table,"id":id},"reason":"missing_source_reference","source_problem":SOURCE.problem()})
		return node
	var matches: Array[Dictionary] = SOURCE.related(table,"ID",int(id))
	if matches.size()!=1:
		var reason: String = "missing_source_reference" if matches.is_empty() else "ambiguous_source_reference"
		blockers.append(reason+":"+table+":"+str(int(id)))
		unresolved.append({"target":{"table":table,"id":id},"reason":reason,"matches":matches,"source_problem":SOURCE.problem()})
		return node
	var selected: Dictionary = _target_node(table,matches[0],blockers)
	selected["id"] = id
	selected["source_table_metadata"] = node.source_table_metadata
	return selected

static func _item_target_leaves(id: Variant, blockers: Array[String]) -> Dictionary:
	# Forward leaves only. Never call describe() or follow the target's own
	# ItemBonus graph: self-references and cycles remain original raw values.
	var unresolved: Array[Dictionary] = []
	var target: Dictionary = _target_row("ItemClass",id,blockers,unresolved)
	target["category"] = {}; target["grade"] = {}
	target["equip_slots"] = []; target["class_limits"] = []
	target["unresolved"] = unresolved
	if target.row.is_empty() or target.excluded: return target
	var raw: Dictionary = target.row
	var category: Dictionary = _target_row("ItemCategory",raw.get("CategoryID"),blockers,unresolved)
	var grade: Dictionary = _target_row("Grade",raw.get("GradeID"),blockers,unresolved)
	target.category = category.row; target.grade = grade.row
	target["category_reference"] = category; target["grade_reference"] = grade
	for table: String in ["ItemEquipSlot","ItemClassLimit"]:
		if SOURCE.table_metadata(table).is_empty():
			blockers.append("missing_source_reference:"+table)
			unresolved.append({"target":{"table":table,"field":"ItemClassID","id":raw.ID},"reason":"missing_source_reference","source_problem":SOURCE.problem()})
			continue
		for link: Dictionary in SOURCE.related(table,"ItemClassID",int(raw.ID)):
			var source_link: Dictionary = _target_node(table,link,blockers)
			if table == "ItemEquipSlot":
				var equip: Dictionary = {"link":link,"source_link":source_link,"slot":{},"slot_reference":{},"reference_only":true,"can_activate":false}
				target.equip_slots.append(equip)
				if source_link.excluded: equip["excluded"] = true; continue
				var slot: Dictionary = _target_row("EquipSlot",link.get("EquipSlotID"),blockers,unresolved)
				equip.slot = slot.row; equip.slot_reference = slot
			else:
				var limit: Dictionary = {"link":link,"source_link":source_link,"class":{},"class_reference":{},"reference_only":true,"can_activate":false}
				target.class_limits.append(limit)
				if source_link.excluded: limit["excluded"] = true; continue
				var character_class: Dictionary = _target_row("Class",link.get("ClassID"),blockers,unresolved)
				limit["class"] = character_class.row; limit.class_reference = character_class
	return target

static func _typed_item_target(detail: Dictionary, unit: String, value: Variant, blockers: Array[String]) -> Dictionary:
	var target: Dictionary = {}
	if unit == "ItemClassID":
		target = _item_target_leaves(value,blockers)
	else:
		# This namespace establishes IntangibleItemClass only. Similar field
		# names do not establish item category/equip/class joins for that table.
		var unresolved: Array[Dictionary] = []
		target = _target_row("IntangibleItemClass",value,blockers,unresolved)
		target["unresolved"] = unresolved
	var reference: Dictionary = {"unit":unit,"id":value,"raw_value":value,
		"item_bonus_id":detail.get("link",{}).get("ID"),"target":target,
		"excluded":target.get("excluded",false),"reference_only":true,"can_activate":false,"ownership_authorized":false}
	if unit == "ItemClassID": reference["item_class"] = target.row
	else: reference["intangible_item_class"] = target.row
	if target.has("declared_exclusion"): reference["declared_exclusion"] = target.declared_exclusion
	return reference

static func _typed_invoke_target(detail: Dictionary, blockers: Array[String]) -> Dictionary:
	# Reuse the public item compiler's application-target join. Bonus.Value is
	# retained verbatim; it is never substituted for an InvokeOption identity.
	var bonus: Dictionary = detail.get("bonus",{})
	var target_id: Variant = bonus.get("BonusApplicationTargetID")
	var unresolved: Array[Dictionary] = []
	var reference: Dictionary = {"reference_kind":"InvokeOption","unit":detail.get("unit",{}).get("Name",""),
		"id":target_id,"raw_value":bonus.get("Value"),"raw_application_target_id":target_id,
		"item_bonus_id":detail.get("link",{}).get("ID"),"item_bonus":detail.get("link",{}),
		"bonus":bonus,"bonus_type":detail.get("type",{}),"bonus_unit":detail.get("unit",{}),
		"application_type":{},"invoke_option":{},"invoke_option_type":{},"parameter_units":[],"parameter_references":[],
		"unresolved":unresolved,"excluded":false,"reference_only":true,"can_activate":false,"can_execute":false,
		"activation_authorized":false,"ownership_authorized":false,"source":SOURCE.identity()}
	var source_nodes: Dictionary = {"item_bonus":_target_node("ItemBonus",detail.get("link",{}),blockers),
		"bonus":_target_node("Bonus",bonus,blockers),"bonus_type":_target_node("BonusType",detail.get("type",{}),blockers),
		"bonus_unit":_target_node("Unit",detail.get("unit",{}),blockers)}
	reference["source_nodes"] = source_nodes
	for key: String in source_nodes:
		if source_nodes[key].excluded:
			reference.excluded = true
			blockers.append("source_declared_exclusion:invoke_"+key)
	if reference.excluded: return reference
	var application: Dictionary = _target_row("BonusApplicationType",bonus.get("BonusApplicationTypeID"),blockers,unresolved)
	reference.application_type = application.row
	reference["application_type_reference"] = application
	if application.excluded:
		reference.excluded = true
		blockers.append("source_declared_exclusion:BonusApplicationType")
		return reference
	if application.row.get("Name")!="InvokeOption":
		blockers.append("unsupported_invoke_application_type")
		reference["source_status"] = "application_target_namespace_unconfirmed"
		return reference
	var option: Dictionary = _target_row("InvokeOption",target_id,blockers,unresolved)
	reference.invoke_option = option.row
	reference["invoke_option_reference"] = option
	if option.row.is_empty(): return reference
	if option.excluded:
		reference.excluded = true
		blockers.append("source_declared_exclusion:InvokeOption")
		return reference
	var kind: Dictionary = _target_row("InvokeOptionType",option.row.get("InvokeOptionTypeID"),blockers,unresolved)
	reference.invoke_option_type = kind.row
	reference["invoke_option_type_reference"] = kind
	if kind.row.is_empty(): return reference
	if kind.excluded:
		reference.excluded = true
		blockers.append("source_declared_exclusion:InvokeOptionType")
		return reference
	for number: int in range(1,7):
		var parameter: String = "Param"+str(number)
		var unit_field: String = parameter+"Unit"
		var raw_unit: Variant = kind.row.get(unit_field)
		var descriptor: Dictionary = {"parameter":parameter,"value":option.row.get(parameter),
			"value_present":option.row.has(parameter),"unit_field":unit_field,"unit_present":kind.row.has(unit_field),
			"unit_id":raw_unit,"unit":{},"unit_reference":{},"reference_only":true,"can_execute":false}
		reference.parameter_units.append(descriptor)
		# Missing/zero unit declarations remain raw and do not establish a
		# namespace. Other unit names are visible without parameter inference.
		if not kind.row.has(unit_field) or raw_unit==0: continue
		var unit: Dictionary = _target_row("Unit",raw_unit,blockers,unresolved)
		descriptor.unit = unit.row; descriptor.unit_reference = unit
		if unit.row.is_empty(): continue
		if unit.excluded:
			reference.excluded = true
			blockers.append("source_declared_exclusion:InvokeOptionType."+unit_field)
			continue
		# The public _invoke_options/_source_bleed contract confirms exactly
		# this Param1 spell leaf. Do not extend its child graph or reinterpret
		# another parameter merely because a numeric ID happens to match.
		var confirmed_spell: bool = parameter=="Param1" and kind.row.get("ID")==1 and kind.row.get("Name")=="Attack_Spell" and option.row.get("ID")==611 and option.row.get("Param1")==17564 and raw_unit==12 and unit.row.get("Name")=="SpellClassID"
		if not confirmed_spell:
			descriptor["source_status"] = "raw_parameter_namespace_not_projected"
			continue
		var leaf: Dictionary = _target_row("SpellClass",option.row.get(parameter),blockers,unresolved)
		leaf["can_execute"] = false
		var test: Variant = leaf.row.get("TestSpell")
		if leaf.row.has("TestSpell"):
			leaf["test_declaration"] = {"field":"TestSpell","value":test}
			if typeof(test)==TYPE_BOOL and test:
				leaf.excluded = true
				leaf["test_exclusion_reason"] = "source_TestSpell_true"
				blockers.append("source_TestSpell_true")
			elif typeof(test)!=TYPE_BOOL: blockers.append("source_test_declaration_invalid:SpellClass.TestSpell")
		if leaf.excluded:
			reference.excluded = true
			if leaf.has("declared_exclusion"): blockers.append("source_declared_exclusion:SpellClass")
		reference.parameter_references.append({"parameter":parameter,"raw_value":option.row.get(parameter),"unit":unit.row,
			"target":leaf,"spell":leaf.row,"excluded":leaf.excluded,"reference_only":true,"can_activate":false,"can_execute":false,"ownership_authorized":false})
	return reference

static func _typed_reference(detail: Dictionary, blockers: Array[String]) -> Dictionary:
	var value: Variant = detail.get("bonus",{}).get("Value")
	var unit: String = str(detail.get("unit",{}).get("Name",""))
	var type: String = str(detail.get("type",{}).get("Name",""))
	if type == "InvokeOption": return _typed_invoke_target(detail,blockers)
	if type != "MarketPurchaseID" and unit in ["ItemClassID","IntangibleItemClassID"]:
		return _typed_item_target(detail,unit,value,blockers)
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=floorf(float(value)) or value<=0 or value>9007199254740991.0: return {}
	var id: int = int(value)
	var reference: Dictionary = {"unit":unit,"id":id,"item_bonus_id":detail.get("link",{}).get("ID"),"reference_only":true,"can_activate":false}
	if type == "MarketPurchaseID":
		# Existing public ticket/monsterbook joins define this type namespace.
		# This forward graph retains offers/odds/conditions without authorizing use.
		reference["market_gotcha"] = MARKET_GOTCHA.describe(id,detail)
	elif unit == "BuffCardID":
		var card: Dictionary = _missing(blockers,"BuffCard",id)
		reference["card"] = card
		if not card.is_empty():
			reference["deck"] = _missing(blockers,"BuffCardDeck",int(card.get("BuffCardDeckID",-1)))
			if int(card.get("SpellClassID",0))>0: reference["spell"] = SPELLS.describe(int(card.SpellClassID))
	elif unit == "SpellClassID":
		reference["spell"] = SPELLS.describe(id)
	elif type == "LuckyBagClassID" and unit == "LuckyBagClassID":
		reference["bag"] = REWARDS.bag(id)
	elif type == "SelectRewardClassID" and unit == "RewardID":
		reference["reward"] = REWARDS.reward(id)
	elif unit == "GachaCraftID":
		# A crafting-book definition is not a directly activatable consumable.
		# Costs/materials/lifetime remain in the calling item's original bonuses.
		reference["gacha_craft"] = GACHA_CRAFT.describe(id)
	elif unit == "BuffClassID":
		var buff: Dictionary = BUFFS.describe(id)
		reference["buff_definition"] = buff
		reference["buff"] = buff.get("buff_class",{})
		reference["bonuses"] = buff.get("bonuses",[])
	else:
		return {}
	return reference

static func describe(item_id: int, include_descriptions: bool = false) -> Dictionary:
	# UNVERIFIED: final definition input is the newly supplied original ZIP.
	# Legacy sidecar code/files remain preserved; they are not a prerequisite
	# or a fallback when the new original is unavailable.
	var identity: Dictionary = SOURCE.identity()
	var item: Dictionary = SOURCE.row("ItemClass",item_id) if item_id>0 and not identity.is_empty() else {}
	var blockers: Array[String] = []
	var result: Dictionary = {"kind":"twilight.current523.item-data.v1","ok":false,"reference_only":true,"can_activate":false,"ownership_authorized":false,"item_class_id":item_id,"source":identity,"item_class":item,"category":{},"grade":{},"equip_slots":[],"class_limits":[],"bonuses":[],"typed_references":[],"descriptions":{},"compiled_use_spec":{},"compiled_invoke_options":[],"use_spec_status":"original_definition_only","blockers":blockers}
	if item.is_empty():
		blockers.append("source_item_unavailable")
		result["problem"] = SOURCE.problem()
		return result
	# This is the explicit original test declaration. Do not infer dummy status
	# from names, missing artwork, unsupported effects or absent suppliers.
	var test: Variant = item.get("TestItem")
	if typeof(test)!=TYPE_BOOL:
		blockers.append("source_test_declaration_missing")
	elif test:
		blockers.append("source_TestItem_true")
		result["excluded"] = true
	var exclusion: Dictionary = SOURCE.declared_exclusion("ItemClass",item)
	if not exclusion.is_empty():
		result["excluded"] = true
		result["declared_exclusion"] = exclusion
		blockers.append("source_declared_dummy")
		return result
	result.category = _missing(blockers,"ItemCategory",int(item.get("CategoryID",-1)))
	result.grade = _missing(blockers,"Grade",int(item.get("GradeID",-1)))
	for link: Dictionary in SOURCE.related("ItemEquipSlot","ItemClassID",item_id):
		result.equip_slots.append({"link":link,"slot":_missing(blockers,"EquipSlot",int(link.get("EquipSlotID",-1)))})
	for link: Dictionary in SOURCE.related("ItemClassLimit","ItemClassID",item_id):
		result.class_limits.append({"link":link,"class":_missing(blockers,"Class",int(link.get("ClassID",-1)))})
	result.bonuses = _effects("ItemBonus","ItemClassID",item_id,blockers)
	for detail: Dictionary in result.bonuses:
		var reference: Dictionary = _typed_reference(detail,blockers)
		if not reference.is_empty():
			reference["source_item_class_id"] = item_id
			result.typed_references.append(reference)
	# The same existing item/shop call must carry the book's actual ItemBonus
	# context with its GachaCraft graph. A group replacement cost cannot supply
	# the calling item's material, final-cost or lifetime definition.
	for reference: Dictionary in result.typed_references:
		if not reference.get("gacha_craft") is Dictionary: continue
		var material_refs: Array[Dictionary] = []
		for target: Dictionary in result.typed_references:
			if target.get("unit") == "ItemClassID": material_refs.append(target)
		reference.gacha_craft["calling_item_input"] = {
			"source":identity,"item_class":item,"category":result.category,
			"bonuses":result.bonuses,"item_class_references":material_refs,
			"reference_only":true,"can_execute":false,"ownership_authorized":false}
	# Preserve the declared description domains instead of looking up a same-ID
	# item, UI token or translated label in another table.
	for field: String in ["DescID","IdentifiedDescID","StoryDescID","UseDescID","ProductTitleDescID","ProductDescID"]:
		var id: int = int(item.get(field,0))
		if id==0: continue
		# DescData_Korean and DescID are explicitly lower priority. Retain exact
		# references without pulling their large text tables into ordinary quotes.
		result.descriptions[field] = {"id":id,"deferred":not include_descriptions}
		if include_descriptions: result.descriptions[field]["row"] = _missing(blockers,"DescData_Korean",id)
	result.ok = blockers.is_empty()
	return result
