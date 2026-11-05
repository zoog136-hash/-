extends RefCounted
## Original ItemClass reference contract for existing supplier/catalog readers.
## Data visibility never authorizes acquisition, effects or a save transaction.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SPELLS = preload("res://scripts/resources/current523_spell_data.gd")
const REWARDS = preload("res://scripts/resources/current523_reward_data.gd")
const BONUSES = preload("res://scripts/resources/current523_bonus_data.gd")
const BUFFS = preload("res://scripts/resources/current523_buff_data.gd")
const GACHA_CRAFT = preload("res://scripts/resources/current523_gacha_craft_data.gd")

static func _missing(blockers: Array[String], table: String, id: int) -> Dictionary:
	var value: Dictionary = SOURCE.row(table,id)
	if value.is_empty(): blockers.append("missing_source_reference:"+table+":"+str(id))
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

static func _typed_reference(detail: Dictionary, blockers: Array[String]) -> Dictionary:
	var value: Variant = detail.get("bonus",{}).get("Value")
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=floorf(float(value)) or value<=0 or value>9007199254740991.0: return {}
	var id: int = int(value)
	var unit: String = str(detail.get("unit",{}).get("Name",""))
	var type: String = str(detail.get("type",{}).get("Name",""))
	var reference: Dictionary = {"unit":unit,"id":id,"item_bonus_id":detail.get("link",{}).get("ID"),"reference_only":true,"can_activate":false}
	if unit == "BuffCardID":
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

