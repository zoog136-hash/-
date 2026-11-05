extends RefCounted

const Common = preload("res://scripts/equipment523/common.gd")
const PROBABILITY_TOTAL := 10000000

# Client definitions expose price components, but not their evaluation algorithm.
# These names deliberately require the caller to select the documented local rule.
static func quote(pack: Dictionary, action: Dictionary, context: Dictionary) -> Dictionary:
	if str(action.get("kind", "")) != "alchemy":
		return _fail("invalid_action")
	var recipe_id := int(action.get("recipe_type", 0))
	var recipe: Dictionary = Common.find(pack, "AlchemyRecipeType", recipe_id)
	if recipe_id not in [63, 113] or recipe.is_empty() or not bool(recipe.get("IsEnabled", false)):
		return _fail("recipe_disabled")
	var policy: Dictionary = context.get("policy", {}).get("alchemy", {})
	if str(policy.get("evaluation_mode", "")) != "additive_v1" or str(policy.get("cost_mode", "")) != "flat_recipe_group_v1" or str(policy.get("range_mode", "")) != "inclusive_v1":
		return _fail("explicit_alchemy_policy_required")
	var server_mode := str(policy.get("server_limit_mode", ""))
	var server_set := int(policy.get("server_limit_set_id", 0))
	if server_mode == "unrestricted_only":
		if server_set != 0:
			return _fail("unsupported_server_limit")
	elif server_mode == "local_explicit_set":
		if server_set <= 0 or not policy.get("allowed_server_limit_ids", []).has(server_set):
			return _fail("unsupported_server_limit")
	else:
		return _fail("explicit_server_limit_policy_required")
	var level_min := _constant(pack, "MinLevel")
	var max_materials := _constant(pack, "AlchemyMaterialMaxDemand")
	var group := int(recipe.get("GroupID", 0))
	var min_materials := _group_constant(pack, group, 3)
	var min_advanced := _group_constant(pack, group, 13)
	var min_rare := _group_constant(pack, group, 23)
	var gold := _group_constant(pack, group, 93)
	if level_min < 0 or max_materials < 3 or min_materials < 3 or min_advanced < 0 or min_rare < 0 or gold <= 0 or _constant(pack, "AlchemyCurrency") != 1:
		return _fail("invalid_alchemy_constants")
	if int(context.get("player_level", 0)) < level_min:
		return _fail("player_level_too_low")
	var selected: Array = action.get("material_ids", [])
	if selected.size() < min_materials or selected.size() > max_materials:
		return _fail("invalid_material_count")
	var by_instance: Dictionary = {}
	for entry in context.get("materials", []):
		if not entry is Dictionary:
			return _fail("invalid_material_record")
		var instance := str(entry.get("instance_id", ""))
		if instance.is_empty() or by_instance.has(instance):
			return _fail("invalid_material_instance")
		by_instance[instance] = entry
	var consumed: Array = []
	var components: Array = []
	var rare_count := 0
	var advanced_count := 0
	var score := 0
	for physical_id in selected:
		var instance := str(physical_id)
		if consumed.has(instance) or not by_instance.has(instance):
			return _fail("missing_or_duplicate_material")
		var material: Dictionary = by_instance[instance]
		if bool(material.get("equipped", false)) or bool(material.get("locked", false)):
			return _fail("material_equipped_or_locked")
		var source_id := int(material.get("source_id", 0))
		var item: Dictionary = Common.item(pack, source_id)
		if item.is_empty():
			return _fail("unknown_material_item")
		var grade: Dictionary = Common.find(pack, "Grade", int(item.get("raw", {}).get("GradeID", 0)))
		var grade_value := int(grade.get("GradeValue", 0))
		var minimum_grade := 3 if recipe_id == 113 else 2
		if grade_value < minimum_grade:
			return _fail("material_grade_too_low")
		var definition: Dictionary = {}
		for row in Common.rows(pack, "AlchemyItem"):
			if int(row.get("ItemClassID", 0)) == source_id and int(row.get("RecipeTypeID", 0)) == recipe_id:
				if not definition.is_empty():
					return _fail("ambiguous_material_definition")
				definition = row
		if definition.is_empty() or bool(definition.get("IsRecipeItem", false)):
			return _fail("material_not_allowed_by_recipe")
		# Membership is the exact source whitelist. No name or tradeability heuristic.
		var component := _evaluate(pack, definition, material)
		if not component.get("ok", false):
			return component
		score += int(component.score)
		components.append({"instance_id": instance, "source_id": source_id, "evaluation": component})
		consumed.append(instance)
		if grade_value >= 3:
			rare_count += 1
		if grade_value >= 2:
			advanced_count += 1
	if rare_count < min_rare or advanced_count < min_advanced:
		return _fail("material_grade_slots_unsatisfied")
	var pool: Array = []
	var ranges: Dictionary = {}
	var total := 0
	var result_ids: Array = []
	for row in Common.rows(pack, "AlchemyResult"):
		if int(row.get("RecipeTypeID", 0)) != recipe_id or int(row.get("ServerLimitSetID", 0)) != server_set:
			continue
		if score < int(row.get("PriceLow", 0)) or score > int(row.get("PriceHigh", -1)):
			continue
		if int(row.get("Probability", -1)) < 0 or int(row.get("Amount", 0)) <= 0 or Common.item(pack, int(row.get("ItemClassID", 0))).is_empty():
			return _fail("invalid_alchemy_result")
		ranges["%s:%s" % [row.PriceLow, row.PriceHigh]] = true
		pool.append(row)
		result_ids.append(int(row.ID))
		total += int(row.Probability)
	if pool.is_empty():
		return _fail("no_result_pool_for_evaluation")
	if ranges.size() != 1 or total != PROBABILITY_TOTAL:
		return _fail("ambiguous_or_invalid_result_pool")
	return {"ok": true, "kind": "alchemy", "target_id": "", "costs": [],
		"consume_instance_ids": consumed, "gold_cost": gold,
		"detail": "모든 재료 소멸 · 평가 %d · 아데나 %d · TWILIGHT 합산 정책" % [score, gold],
		"alchemy": {"recipe_type": recipe_id, "recipe_group": group, "score": score,
			"server_limit_set_id": server_set, "result_ids": result_ids, "components": components,
			"policy": policy.duplicate(true), "evaluation_formula_verified": false,
			"cost_basis": "AlchemyConstantByRecipeGroup.ConstantTypeID=93",
			"consume_all_materials_on_start": true, "confirmation_text_id": 44304}}


static func roll(pack: Dictionary, quoted: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if not quoted.get("ok", false) or str(quoted.get("kind", "")) != "alchemy":
		return _fail("invalid_alchemy_quote")
	var data: Dictionary = quoted.get("alchemy", {})
	var recipe_id := int(data.get("recipe_type", 0))
	var recipe: Dictionary = Common.find(pack, "AlchemyRecipeType", recipe_id)
	if recipe_id not in [63, 113] or not bool(recipe.get("IsEnabled", false)):
		return _fail("recipe_disabled")
	var policy: Dictionary = data.get("policy", {})
	var server_set := int(data.get("server_limit_set_id", 0))
	if server_set != 0 and (str(policy.get("server_limit_mode", "")) != "local_explicit_set" or not policy.get("allowed_server_limit_ids", []).has(server_set)):
		return _fail("unsupported_server_limit")
	var score := int(data.get("score", -1))
	var result_ids: Array = data.get("result_ids", [])
	var pool: Array = []
	var seen: Dictionary = {}
	var ranges: Dictionary = {}
	var total := 0
	for result_id in result_ids:
		var row: Dictionary = Common.find(pack, "AlchemyResult", int(result_id))
		if row.is_empty() or seen.has(int(result_id)) or int(row.get("RecipeTypeID", 0)) != recipe_id or int(row.get("ServerLimitSetID", 0)) != server_set or score < int(row.get("PriceLow", 0)) or score > int(row.get("PriceHigh", -1)):
			return _fail("stale_or_invalid_result_pool")
		if int(row.get("Probability", -1)) < 0 or int(row.get("Amount", 0)) <= 0 or Common.item(pack, int(row.get("ItemClassID", 0))).is_empty():
			return _fail("invalid_alchemy_result")
		seen[int(result_id)] = true
		ranges["%s:%s" % [row.PriceLow, row.PriceHigh]] = true
		pool.append(row)
		total += int(row.Probability)
	if total != PROBABILITY_TOTAL or ranges.size() != 1:
		return _fail("ambiguous_or_invalid_result_pool")
	var chosen: Dictionary = Common.weighted(pool, "Probability", rng)
	if chosen.is_empty():
		return _fail("empty_result_pool")
	return {"ok": true, "kind": "alchemy", "output": {
		"source_id": str(chosen.ItemClassID), "amount": int(chosen.Amount),
		"level": int(chosen.Enchant), "bless_code": int(chosen.BlessCode)},
		"detail": "연금 결과 · 원문 가중치 · TWILIGHT 재료 평가 정책",
		"result_id": int(chosen.ID), "server_limit_set_id": server_set}


static func _evaluate(pack: Dictionary, definition: Dictionary, material: Dictionary) -> Dictionary:
	var enchant := int(material.get("level", 0))
	var element := int(material.get("element_type", 0))
	var elemental_enchant := int(material.get("element_level", 0))
	var bless := int(material.get("bless_code", 1))
	if enchant < 0 or elemental_enchant < 0 or element < 0 or (element == 0 and elemental_enchant != 0):
		return _fail("invalid_material_state")
	var base := int(definition.get("BasePrice", -1))
	var enchant_price := 0
	var elemental_price := 0
	if enchant > 0:
		enchant_price = _price(pack, "AlchemyEnchantPriceGroup", {"GroupID": int(definition.get("EnchantGroupID", 0)), "Enchant": enchant})
	if element > 0:
		elemental_price = _price(pack, "AlchemyElementalEnchantPriceGroup", {"GroupID": int(definition.get("ElementalEnchantGroupID", 0)), "ElementalType": element, "Enchant": elemental_enchant})
	var bless_price := _price(pack, "AlchemyBlessPriceGroup", {"GroupID": int(definition.get("BlessGroupID", 0)), "BlessCodeID": bless})
	if base < 0 or enchant_price < 0 or elemental_price < 0 or bless_price < 0:
		return _fail("unsupported_material_evaluation_state")
	return {"ok": true, "score": base + enchant_price + elemental_price + bless_price,
		"base": base, "enchant": enchant_price, "elemental": elemental_price, "bless": bless_price}


static func _price(pack: Dictionary, table: String, selectors: Dictionary) -> int:
	var value := -1
	for row in Common.rows(pack, table):
		var matches := true
		for key in selectors:
			if int(row.get(key, -999999)) != int(selectors[key]):
				matches = false
		if matches:
			var candidate := int(row.get("Price", -1))
			if candidate < 0 or (value >= 0 and candidate != value):
				return -1
			value = candidate
	return value


static func _constant(pack: Dictionary, name: String) -> int:
	for row in Common.rows(pack, "AlchemyConstants"):
		if str(row.get("Name", "")) == name:
			return int(row.get("Value", -1))
	return -1


static func _group_constant(pack: Dictionary, group: int, constant_type: int) -> int:
	for row in Common.rows(pack, "AlchemyConstantByRecipeGroup"):
		if int(row.get("GroupID", -1)) == group and int(row.get("ConstantTypeID", -1)) == constant_type:
			return int(row.get("Value", -1))
	return -1


static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error, "kind": "alchemy", "detail": error}
