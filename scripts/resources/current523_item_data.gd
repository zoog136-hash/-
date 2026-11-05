extends RefCounted
## Original ItemClass reference contract for existing supplier/catalog readers.
## Data visibility never authorizes acquisition, effects or a save transaction.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const COMPILED_ITEMS = preload("res://scripts/loot/patch523_monster_drops.gd")
const SPELLS = preload("res://scripts/resources/current523_spell_data.gd")
const REWARDS = preload("res://scripts/resources/current523_reward_data.gd")

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
		var bonus: Dictionary = _missing(blockers,"Bonus",int(link.get("BonusID",-1)))
		var type: Dictionary = _missing(blockers,"BonusType",int(bonus.get("BonusTypeID",-1))) if not bonus.is_empty() else {}
		var unit: Dictionary = _missing(blockers,"Unit",int(type.get("UnitID",-1))) if not type.is_empty() else {}
		effects.append({"link":link,"bonus":bonus,"type":type,"unit":unit})
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
	elif unit == "BuffClassID":
		reference["buff"] = _missing(blockers,"BuffClass",id)
		reference["bonuses"] = _effects("BuffBonus","BuffClassID",id,blockers)
	else:
		return {}
	return reference

static func describe(item_id: int, include_descriptions: bool = false) -> Dictionary:
	var compiled: Dictionary = _compiled(item_id) if item_id>0 else {}
	var identity: Dictionary = {"kind":"twilight.current523.compiled-item-data.v1","source_snapshot":"patch523","source_archive_expected":SOURCE.SOURCE_SHA,"pack":COMPILED_ITEMS.pack_identity()} if not compiled.is_empty() else SOURCE.identity()
	var item: Dictionary = compiled.get("original_item",{}).duplicate(true)
	if item.is_empty() and item_id>0 and not identity.is_empty(): item = SOURCE.row("ItemClass",item_id)
	var blockers: Array[String] = []
	var result: Dictionary = {"kind":"twilight.current523.item-data.v1","ok":false,"reference_only":true,"can_activate":false,"ownership_authorized":false,"item_class_id":item_id,"source":identity,"item_class":item,"category":{},"grade":{},"equip_slots":[],"class_limits":[],"bonuses":[],"typed_references":[],"descriptions":{},"blockers":blockers}
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
	if not compiled.is_empty():
		result.category = compiled.get("category",{}).duplicate(true)
		result.grade = compiled.get("grade",{}).duplicate(true)
		result["compiled_use_spec"] = compiled.get("native_record",{}).get("source_use_spec",{}).duplicate(true)
		result["compiled_invoke_options"] = compiled.get("source_invoke_options",[]).duplicate(true)
		for joined: Dictionary in compiled.get("equip_rows",[]):
			result.equip_slots.append({"link":_link(joined,["equip_slot"]),"slot":joined.get("equip_slot",{}).duplicate(true)})
		for joined: Dictionary in compiled.get("class_rows",[]):
			result.class_limits.append({"link":_link(joined,["class"]),"class":joined.get("class",{}).duplicate(true)})
		for joined: Dictionary in compiled.get("item_bonus",[]):
			result.bonuses.append({"link":_link(joined,["bonus","bonus_type","unit","weapon_type"]),"bonus":joined.get("bonus",{}).duplicate(true),"type":joined.get("bonus_type",{}).duplicate(true),"unit":joined.get("unit",{}).duplicate(true)})
	else:
		result.category = _missing(blockers,"ItemCategory",int(item.get("CategoryID",-1)))
		result.grade = _missing(blockers,"Grade",int(item.get("GradeID",-1)))
		for link: Dictionary in SOURCE.related("ItemEquipSlot","ItemClassID",item_id):
			result.equip_slots.append({"link":link,"slot":_missing(blockers,"EquipSlot",int(link.get("EquipSlotID",-1)))})
		for link: Dictionary in SOURCE.related("ItemClassLimit","ItemClassID",item_id):
			result.class_limits.append({"link":link,"class":_missing(blockers,"Class",int(link.get("ClassID",-1)))})
		result.bonuses = _effects("ItemBonus","ItemClassID",item_id,blockers)
	for detail: Dictionary in result.bonuses:
		var reference: Dictionary = _typed_reference(detail,blockers)
		if not reference.is_empty(): result.typed_references.append(reference)
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
