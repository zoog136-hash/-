extends RefCounted
## Original gacha-craft graph for existing item/catalog readers only.
## Source weights and costs are retained without drawing or settling outcomes.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")

static func _id(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _reference(blockers: Array[String], table: String, value: Variant) -> Dictionary:
	if not _id(value):
		blockers.append("invalid_source_reference:"+table)
		return {}
	var matches: Array[Dictionary] = SOURCE.related(table,"ID",int(value))
	if matches.size()!=1:
		blockers.append(("missing_source_reference:" if matches.is_empty() else "ambiguous_source_reference:")+table+":"+str(int(value)))
		return {}
	return matches[0]

static func _typed_reference(table: String, field: String, value: Variant, target: String) -> Dictionary:
	return {"source_table":table,"source_field":field,"raw_id":value,"target_table":target,"reference_only":true,"can_execute":false}

static func _item_input(value: Variant, blockers: Array[String]) -> Dictionary:
	# Only the explicit ItemClassID/BoundItemClassID namespaces are joined.
	# This leaf does not enter ItemData again or expand a crafting-book cycle.
	var item: Dictionary = _reference(blockers,"ItemClass",value)
	var result: Dictionary = {"item_class":item,"source":SOURCE.identity(),
		"reference_only":true,"can_activate":false,"excluded":false}
	if item.is_empty(): return result
	var exclusion: Dictionary = SOURCE.declared_exclusion("ItemClass",item)
	if not exclusion.is_empty():
		result.excluded = true
		result["declared_exclusion"] = exclusion
	var test: Variant = item.get("TestItem")
	result["test_declaration"] = {"field":"TestItem","present":item.has("TestItem"),"value":test}
	if typeof(test) == TYPE_BOOL and test:
		result.excluded = true
		result["test_exclusion_reason"] = "source_TestItem_true"
	elif typeof(test) != TYPE_BOOL:
		blockers.append("source_test_declaration_missing:ItemClass:"+str(value))
	return result

static func describe(gacha_craft_id: int) -> Dictionary:
	var identity: Dictionary = SOURCE.identity()
	var blockers: Array[String] = []
	var unresolved: Array[Dictionary] = []
	var result: Dictionary = {
		"kind":"twilight.current523.gacha-craft-data.v1","ok":false,
		"reference_only":true,"can_execute":false,"can_activate":false,
		"ownership_authorized":false,"gacha_craft_id":gacha_craft_id,
		"source":identity,"gacha_craft":{},"group_probabilities":[],"groups":[],
		"unresolved_references":unresolved,"blockers":blockers,
		"remaining_contract":[
			"source_weights_are_raw_without_an_inferred_probability_scale",
			"ChangeCost_is_the_source_replacement_cost_without_a_settlement_contract",
			"MaterialClassID_MaterialAmount_and_GachaCraftCost_require_the_calling_item_bonus_context",
			"calling_ItemCategory_IsActivatable_ItemClass_TestItem_and_DeleteTime_scope_must_be_preserved",
			"candidate_generation_confirmation_and_retention_protocol_unresolved",
			"ownership_material_and_currency_settlement_save_and_reconnect_protocol_unresolved",
			"source_test_or_expired_items_are_not_activated"
		]}
	if identity.is_empty():
		blockers.append("source_gacha_craft_unavailable")
		result["problem"] = SOURCE.problem()
		return result
	var craft: Dictionary = _reference(blockers,"GachaCraft",gacha_craft_id)
	result.gacha_craft = craft
	if craft.is_empty(): return result
	# The book's typed GachaCraftID Bonus.Value selects this configuration.
	# Material and final craft cost bonuses remain in that same item context;
	# ChangeCost is not substituted for either of those source values.
	var probabilities: Array[Dictionary] = SOURCE.related("GachaCraftGroupProbability","GachaCraftID",gacha_craft_id)
	result.group_probabilities = probabilities
	if probabilities.is_empty(): blockers.append("missing_source_relation:GachaCraftGroupProbability.GachaCraftID")
	for probability: Dictionary in probabilities:
		var group_value: Variant = probability.get("GachaCraftGroupID")
		var group: Dictionary = _reference(blockers,"GachaCraftGroup",group_value)
		var entry: Dictionary = {"group_probability":probability,"group":group,"outputs":[]}
		result.groups.append(entry)
		if group.is_empty(): continue
		var outputs: Array[Dictionary] = SOURCE.related("GachaCraftOutput","GachaCraftGroupID",int(group_value))
		if outputs.is_empty(): blockers.append("missing_source_relation:GachaCraftOutput.GachaCraftGroupID:"+str(group_value))
		for output: Dictionary in outputs:
			# ClassID has no confirmed target namespace in the supplied contract.
			# Keep it distinct from the explicit ItemClassID and group joins.
			var class_reference: Dictionary = _typed_reference("GachaCraftOutput","ClassID",output.get("ClassID"),"")
			class_reference["unresolved"] = true
			class_reference["reason"] = "source_target_namespace_unconfirmed"
			unresolved.append(class_reference)
			var output_entry: Dictionary = {
				"output":output,"bound_items":[],"item_input":{},
				"bless_code":_reference(blockers,"ItemBlessCode",output.get("ItemBlessCodeID")),
				"typed_references":[
					_typed_reference("GachaCraftOutput","ItemClassID",output.get("ItemClassID"),"ItemClass"),
					_typed_reference("GachaCraftOutput","ItemBlessCodeID",output.get("ItemBlessCodeID"),"ItemBlessCode"),
					class_reference
				]}
			entry.outputs.append(output_entry)
			var item_value: Variant = output.get("ItemClassID")
			if not _id(item_value):
				blockers.append("invalid_source_reference:GachaCraftOutput.ItemClassID")
				continue
			output_entry.item_input = _item_input(item_value,blockers)
			# Preserve every matching row, including repeated source mappings.
			# BoundItemProbability, Probability, ItemAmount, ItemEnchant and
			# ItemBlessCodeID stay unchanged in output; no candidate is selected.
			for mapping: Dictionary in SOURCE.related("GachaCraftBoundItem","ItemClassID",int(item_value)):
				output_entry.bound_items.append({
					"row":mapping,
					"item_input":_item_input(mapping.get("ItemClassID"),blockers),
					"bound_item_input":_item_input(mapping.get("BoundItemClassID"),blockers),
					"typed_references":[
						_typed_reference("GachaCraftBoundItem","ItemClassID",mapping.get("ItemClassID"),"ItemClass"),
						_typed_reference("GachaCraftBoundItem","BoundItemClassID",mapping.get("BoundItemClassID"),"ItemClass")
					]})
	result.ok = blockers.is_empty()
	return result
