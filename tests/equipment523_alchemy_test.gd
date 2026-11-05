extends SceneTree

const Alchemy = preload("res://scripts/equipment523/alchemy.gd")
var checked := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checked += 1
	if not ok:
		failures.append(message)
		printerr("ALCHEMY FAIL: " + message)

func _run() -> void:
	# Entirely synthetic definitions. No original source pack or player saves.
	var pack := _pack()
	var context := _context()
	var action := {"kind": "alchemy", "recipe_type": 63, "material_ids": ["a", "b", "c"]}
	var before := JSON.stringify(context)
	var quote: Dictionary = Alchemy.quote(pack, action, context)
	_check(quote.get("ok", false), "Base quote accepts two rare plus one advanced")
	if not quote.get("ok", false):
		_finish()
		return
	_check(quote.gold_cost == 100000 and quote.alchemy.score == 20, "flat source-group cost, separate from evaluation score")
	_check(quote.consume_instance_ids == ["a", "b", "c"] and quote.costs.is_empty(), "all selected physical instances consumed once")
	_check(quote.alchemy.confirmation_text_id == 44304 and quote.alchemy.consume_all_materials_on_start, "source destruction warning preserved")
	_check(JSON.stringify(context) == before, "quote is a pure calculation")
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var output: Dictionary = Alchemy.roll(pack, quote, rng)
	_check(output.get("ok", false) and output.output.source_id == "1001", "source result selected")
	_check(output.output.amount == 2 and output.output.level == 4 and output.output.bless_code == 2, "result quantity, enchant and bless preserved")
	var rejected := action.duplicate(true)
	for disabled_recipe in [74, 84, 94]:
		rejected.recipe_type = disabled_recipe
		_check(not Alchemy.quote(pack, rejected, context).ok, "disabled recipe %d rejected" % disabled_recipe)
	for field in ["equipped", "locked"]:
		var blocked := context.duplicate(true)
		blocked.materials[0][field] = true
		_check(not Alchemy.quote(pack, action, blocked).ok, field + " material rejected")
	rejected = action.duplicate(true)
	rejected.material_ids = ["a", "a", "b"]
	_check(not Alchemy.quote(pack, rejected, context).ok, "duplicate physical instance rejected")
	rejected.material_ids = ["a", "b", "missing"]
	_check(not Alchemy.quote(pack, rejected, context).ok, "unowned instance rejected")
	rejected.material_ids = ["a", "b"]
	_check(not Alchemy.quote(pack, rejected, context).ok, "minimum three slots enforced")
	var no_policy := context.duplicate(true)
	no_policy.policy = {}
	_check(not Alchemy.quote(pack, action, no_policy).ok, "missing local formula policy rejected")
	var low_level := context.duplicate(true)
	low_level.player_level = 0
	_check(not Alchemy.quote(pack, action, low_level).ok, "source minimum player level enforced")
	var enhanced := context.duplicate(true)
	enhanced.materials[0].level = 2
	var enhanced_quote: Dictionary = Alchemy.quote(pack, action, enhanced)
	_check(enhanced_quote.ok and enhanced_quote.alchemy.score == 32, "exact enchant row used instead of cumulative sum")
	_check(enhanced_quote.alchemy.result_ids == [702], "evaluation changes result interval")
	enhanced.materials[0].element_type = 1
	enhanced.materials[0].element_level = 1
	enhanced.materials[0].bless_code = 2
	enhanced_quote = Alchemy.quote(pack, action, enhanced)
	_check(enhanced_quote.ok and enhanced_quote.alchemy.score == 39, "element and bless groups contribute separately")
	enhanced.materials[0].level = 14
	_check(not Alchemy.quote(pack, action, enhanced).ok, "out-of-table enchant is not clamped")
	enhanced = context.duplicate(true)
	enhanced.materials[0].bless_code = 14
	_check(not Alchemy.quote(pack, action, enhanced).ok, "missing bless evaluation rejected")
	var law := action.duplicate(true)
	law.recipe_type = 113
	_check(not Alchemy.quote(pack, law, context).ok, "Law rejects advanced materials")
	var insufficient_rare := context.duplicate(true)
	insufficient_rare.materials[1].source_id = "503"
	_check(not Alchemy.quote(pack, action, insufficient_rare).ok, "Base requires two rare-or-higher slots")
	var rare_only := context.duplicate(true)
	rare_only.materials[2].source_id = "504"
	var law_quote: Dictionary = Alchemy.quote(pack, law, rare_only)
	_check(law_quote.ok and law_quote.gold_cost == 200000, "Law rare three and flat 200000 cost")
	_check(Alchemy.quote(pack, action, rare_only).ok, "Base advanced-or-higher slot accepts third rare")
	var restricted := pack.duplicate(true)
	restricted.erase("_indexes")
	for row in restricted.tables.AlchemyResult:
		row.ServerLimitSetID = 777
	_check(not Alchemy.quote(restricted, action, context).ok, "server-limited result unavailable under unrestricted policy")
	var local_server := context.duplicate(true)
	local_server.policy.alchemy.server_limit_mode = "local_explicit_set"
	local_server.policy.alchemy.server_limit_set_id = 777
	local_server.policy.alchemy.allowed_server_limit_ids = [777]
	var local_quote: Dictionary = Alchemy.quote(restricted, action, local_server)
	_check(local_quote.ok and Alchemy.roll(restricted, local_quote, rng).ok, "explicit local server policy selects exact supported set")
	local_quote.alchemy.policy.allowed_server_limit_ids = []
	_check(not Alchemy.roll(restricted, local_quote, rng).ok, "restricted roll checks explicit policy")
	var malformed := pack.duplicate(true)
	malformed.tables.AlchemyResult[0].Probability = 9000000
	_check(not Alchemy.quote(malformed, action, context).ok, "probability mass loss rejected")
	var contradictory := pack.duplicate(true)
	contradictory.tables.AlchemyBlessPriceGroup.append({"ID": 9, "GroupID": 1, "BlessCodeID": 1, "Price": 7})
	_check(not Alchemy.quote(contradictory, action, context).ok, "contradictory price aliases rejected")
	var stale := pack.duplicate(true)
	stale.erase("_indexes")
	stale.tables.AlchemyResult[0].PriceLow = 21
	_check(not Alchemy.roll(stale, quote, rng).ok, "stale quote cannot select different evaluation interval")
	_finish()

func _finish() -> void:
	print("ALCHEMY_%s: %d assertions" % ["OK" if failures.is_empty() else "FAILED", checked])
	print("EQUIPMENT523_ALCHEMY_RESULT ",JSON.stringify({"checks":checked,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _context() -> Dictionary:
	var materials: Array = []
	for entry in [["a", "501"], ["b", "502"], ["c", "503"]]:
		materials.append({"instance_id": entry[0], "source_id": entry[1], "level": 0, "bless_code": 1,
			"element_type": 0, "element_level": 0, "equipped": false, "locked": false})
	return {"materials": materials, "player_level": 1, "policy": {"alchemy": {
		"evaluation_mode": "additive_v1", "cost_mode": "flat_recipe_group_v1",
		"range_mode": "inclusive_v1", "server_limit_mode": "unrestricted_only"}}}

func _pack() -> Dictionary:
	var tables := {"AlchemyRecipeType": [{"ID": 63, "GroupID": 3, "IsEnabled": true},
		{"ID": 113, "GroupID": 13, "IsEnabled": true}, {"ID": 74, "GroupID": 3, "IsEnabled": false}],
		"Grade": [{"ID": 2, "GradeValue": 2}, {"ID": 3, "GradeValue": 3}],
		"AlchemyConstants": [{"Name": "MinLevel", "Value": 1}, {"Name": "AlchemyMaterialMaxDemand", "Value": 6}, {"Name": "AlchemyCurrency", "Value": 1}],
		"AlchemyConstantByRecipeGroup": [], "AlchemyItem": [],
		"AlchemyEnchantPriceGroup": [{"ID": 1, "GroupID": 1, "Enchant": 1, "Price": 2}, {"ID": 2, "GroupID": 1, "Enchant": 2, "Price": 12}],
		"AlchemyElementalEnchantPriceGroup": [{"ID": 1, "GroupID": 1, "ElementalType": 1, "Enchant": 1, "Price": 3}],
		"AlchemyBlessPriceGroup": [{"ID": 1, "GroupID": 1, "BlessCodeID": 1, "Price": 0}, {"ID": 2, "GroupID": 1, "BlessCodeID": 2, "Price": 4}],
		"AlchemyResult": []}
	for group in [3, 13]:
		for entry in [[3, 3], [13, 1 if group == 3 else 0], [23, 2 if group == 3 else 3], [93, 100000 if group == 3 else 200000]]:
			tables.AlchemyConstantByRecipeGroup.append({"GroupID": group, "ConstantTypeID": entry[0], "Value": entry[1]})
	for recipe in [63, 113]:
		for source_id in [501, 502, 503, 504]:
			tables.AlchemyItem.append({"ItemClassID": source_id, "RecipeTypeID": recipe, "BasePrice": 6 if source_id == 503 else 7,
				"EnchantGroupID": 1, "ElementalEnchantGroupID": 1, "BlessGroupID": 1, "IsRecipeItem": false})
	for entry in [[701, 63, 20, 29], [702, 63, 30, 39], [703, 113, 20, 29]]:
		tables.AlchemyResult.append({"ID": entry[0], "RecipeTypeID": entry[1], "PriceLow": entry[2], "PriceHigh": entry[3],
			"ServerLimitSetID": 0, "Probability": 10000000, "ItemClassID": 1001, "Amount": 2, "Enchant": 4, "BlessCode": 2})
	var items := {}
	for source_id in [501, 502, 503, 504, 1001]:
		items[str(source_id)] = {"raw": {"ID": source_id, "GradeID": 2 if source_id == 503 else 3}}
	return {"schema": "patch523-five-systems-v1", "tables": tables, "items": items}
