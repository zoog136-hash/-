extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		print("OPTION_AUDIT_FAIL: scene missing")
		quit(1)
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var base_db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json")) as Dictionary
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json")) as Dictionary
	var runtime_catalog: Dictionary = world.get("catalog_db") as Dictionary
	var verification: Dictionary = world.get("verified_catalog_options") as Dictionary
	var weight: Dictionary = world.get("item_weight_index") as Dictionary
	var report: Dictionary = {}
	for category: String in ["아이템", "변신", "마법인형", "성물"]:
		var base: Array = base_db.get(category, []) as Array
		var details: Array = catalog.get(category, []) as Array
		var detail_index: Dictionary = {}
		for raw: Variant in details:
			if raw is Dictionary:
				detail_index[str((raw as Dictionary).get("name", ""))] = raw
		var common: int = 0
		var desc_different: int = 0
		var name_missing: Array[String] = []
		var differing_examples: Array[String] = []
		for raw: Variant in base:
			if not (raw is Dictionary):
				continue
			var base_record: Dictionary = raw as Dictionary
			var name_value: String = str(base_record.get("name", ""))
			if not detail_index.has(name_value):
				if name_missing.size() < 12:
					name_missing.append(name_value)
				continue
			common += 1
			var a_desc: String = str(base_record.get("desc", ""))
			var b_desc: String = str((detail_index[name_value] as Dictionary).get("desc", ""))
			if a_desc != b_desc:
				desc_different += 1
				if differing_examples.size() < 10:
					differing_examples.append(name_value)
		var field_option_excerpts: Dictionary = {}
		for keyword: String in ["계열", "발동", "확률", "회복", "흡수", "MP", "HP", "리덕션", "치명타"]:
			var count: int = 0
			for raw: Variant in details:
				if raw is Dictionary and str((raw as Dictionary).get("desc", "")).contains(keyword):
					count += 1
			field_option_excerpts[keyword] = count
		report[category] = {
			"base_count":base.size(), "catalog_count":details.size(),
			"matched_names":common, "base_names_missing_from_catalog":base.size()-common,
			"desc_text_diff_on_common_names":desc_different,
			"missing_name_examples":name_missing,
			"description_diff_examples":differing_examples,
			"verified_original_overlay_count":(verification.get(category, {}) as Dictionary).size(),
			"catalog_desc_patterns":field_option_excerpts}
	var items: Array = runtime_catalog.get("아이템", []) as Array
	var missing_weights: Array[String] = []
	var zero_weights: Array[String] = []
	var unknown_weight_types: Array[String] = []
	var weight_spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/item_weight_rules.json")) as Dictionary
	var typed_defaults: Dictionary = weight_spec.get("type_defaults", {}) as Dictionary
	for raw: Variant in items:
		if not (raw is Dictionary):
			continue
		var record: Dictionary = raw as Dictionary
		var item_name: String = str(record.get("name", ""))
		var item_type: String = str(record.get("type", ""))
		if not typed_defaults.has(item_type) and unknown_weight_types.size() < 30 and not unknown_weight_types.has(item_type):
			unknown_weight_types.append(item_type)
		if not weight.has(item_name) and missing_weights.size() < 15:
			missing_weights.append(item_name)
		if int(weight.get(item_name, 0)) <= 0 and str(record.get("slot", "")) != "currency" and zero_weights.size() < 15:
			zero_weights.append(item_name)
	report["weight_check"] = {"runtime_items":items.size(), "indexed":weight.size(), "catalog_missing":missing_weights, "noncurrency_zero_examples":zero_weights, "catalog_types_without_policy":unknown_weight_types}
	report["monster_size_explicit_count"] = (world.get("monster_size_index") as Dictionary).size()
	print("ORIGINAL_OPTION_COMPARISON_REPORT:" + JSON.stringify(report))
	var is_valid: bool = unknown_weight_types.is_empty() and missing_weights.is_empty() and zero_weights.is_empty() and int(report["monster_size_explicit_count"]) >= 163
	world.queue_free()
	await process_frame
	print("OPTION_AUDIT_OK" if is_valid else "OPTION_AUDIT_FAILED")
	quit(0 if is_valid else 1)
