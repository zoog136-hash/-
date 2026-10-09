extends SceneTree

# A full-catalog regression: all source records are browseable and detailed
# option text follows the same single-player policies as the runtime summary.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, detail: String) -> void:
	if not ok:
		failures.append(detail)
		print("CATALOG_BROWSER_FAIL: " + detail)

func _find_record(records: Array, item_name: String) -> Dictionary:
	for value: Variant in records:
		if value is Dictionary and str((value as Dictionary).get("name", "")) == item_name:
			return value as Dictionary
	return {}

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		_check(false, "Main.tscn unavailable")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var catalog: Dictionary = world.get("catalog_db") as Dictionary
	var all_items: Array = catalog.get("아이템", []) as Array
	_check(all_items.size() >= 2129, "full source item encyclopedia was lost")
	_check((catalog.get("변신", []) as Array).size() >= 413, "transformation encyclopedia was lost")
	_check((catalog.get("마법인형", []) as Array).size() >= 166, "doll encyclopedia was lost")
	_check((catalog.get("성물", []) as Array).size() >= 144, "relic encyclopedia was lost")
	var hud: Node = world.get_node("HUD")
	hud.call("open_catalog", "아이템")
	_check(str(hud.get("item_slot_filter")) == "all", "item encyclopedia must open with all categories")
	_check(str(hud.call("_item_slot_label", "all")) == "전체", "all-category label must be Korean")
	var selector: OptionButton = hud.get("collection_slot_filter") as OptionButton
	_check(selector != null and selector.get_item_text(0) == "전체", "category dropdown must expose all")
	var results: Array = hud.get("catalog_filtered_results") as Array
	_check(results.size() == all_items.size(), "all items must be browseable on opening")
	# Text query includes full option descriptions and stable source IDs.
	hud.call("_refresh_catalog_list", "HP 흡수")
	results = hud.get("catalog_filtered_results") as Array
	_check(results.size() > 0, "HP absorption option search must find cards")
	hud.call("_refresh_catalog_list", "362391")
	results = hud.get("catalog_filtered_results") as Array
	_check(not _find_record(results, "기르타스의 단검").is_empty(), "Inven source ID should be searchable")
	# Switching equipment groups preserves the old category mapping but resets grade.
	hud.call("_select_catalog_group_index", 2)
	results = hud.get("catalog_filtered_results") as Array
	_check(str(hud.get("item_slot_filter")) == "armor", "armor category index mapping")
	_check(results.size() > 0 and results.size() < all_items.size(), "armor filter must narrow the results")
	hud.call("_select_catalog_group_index", 1)
	_check(str(hud.get("item_slot_filter")) == "weapon", "weapon filter must remain selectable")
	hud.call("_refresh_catalog_list", "기르타스의 지팡이")
	var selected: Dictionary = hud.get("selected_catalog_record") as Dictionary
	_check(str(selected.get("name", "")) == "기르타스의 지팡이", "high-grade staff lookup must select its actual record")
	var detail: RichTextLabel = hud.get("catalog_detail") as RichTextLabel
	var staff_options: Array = selected.get("sourceOptions", []) as Array
	_check(staff_options.size() > 16, "staff must retain more than sixteen meaningful options")
	if not staff_options.is_empty() and detail != null:
		_check(detail.text.contains(str(staff_options.back())), "final encyclopedia option must not be truncated")
	var dagger: Dictionary = _find_record(all_items, "기르타스의 단검")
	for value: Variant in dagger.get("sourceOptions", []) as Array:
		var option_text: String = str(value)
		_check(not option_text.contains("손상"), "removed durability options must not show")
	var unique_transform: Dictionary = _find_record(catalog.get("변신", []) as Array, "해방된 할파스")
	var saw_pve: bool = false
	for value: Variant in unique_transform.get("sourceOptions", []) as Array:
		var option_text: String = str(value)
		_check(not option_text.contains("PVP"), "PvP card options must be converted to PvE")
		if option_text.contains("PVE"):
			saw_pve = true
	_check(saw_pve, "verified PvP text must appear as PvE")
	# Source artwork explicitly encodes hero/legend rank for some gear.
	var rank_counts: Dictionary = {}
	for raw: Variant in all_items:
		if raw is Dictionary:
			var entry: Dictionary = raw as Dictionary
			var grade: String = str(entry.get("grade", ""))
			rank_counts[grade] = int(rank_counts.get(grade, 0)) + 1
	_check(int(rank_counts.get("영웅", 0)) >= 19, "source hero equipment grades recovered")
	_check(int(rank_counts.get("전설", 0)) >= 13, "source legendary equipment grades recovered")
	var cloak: Dictionary = _find_record(all_items, "기억의 망토")
	_check(str(cloak.get("grade", "")) == "영웅", "hero-art cloak grade recovered")
	_check(str(cloak.get("grade_evidence", "")) == "inven_original_artwork_filename", "inferred rank provenance retained")
	var memory_cloak: Dictionary = _find_record(all_items, "진 기억의 망토")
	_check(str(memory_cloak.get("grade", "")) == "전설", "legend-art cloak grade recovered")
	var trophy: Dictionary = _find_record(all_items, "전설급 스킬 상자(기사)")
	_check(str(trophy.get("grade", "")) == "일반", "material box must not be promoted from asset token")
	# Same-name entries must retain distinct authoritative source IDs and
	# independent physical equipment instances, including after save/load.
	var same_name: String = "헌팅 라이플 (각인)"
	var duplicate_ids: Array[String] = []
	for raw: Variant in all_items:
		if raw is Dictionary and str((raw as Dictionary).get("name", "")) == same_name:
			duplicate_ids.append(str((raw as Dictionary).get("sourceId", "")))
	_check(duplicate_ids.size() >= 2, "distinct same-name source items retained")
	if duplicate_ids.size() >= 2:
		var before_count: int = int((world.get("inventory") as Dictionary).get(same_name, 0))
		world.call("_grant_playtest_catalog_variant", duplicate_ids[0], 1)
		world.call("_grant_playtest_catalog_variant", duplicate_ids[1], 1)
		_check(int((world.get("inventory") as Dictionary).get(same_name, 0)) == before_count + 2, "both source variants granted without name duplication loss")
		var instances: Dictionary = world.get("item_instances") as Dictionary
		var observed: Dictionary = {}
		for raw_id: Variant in instances.keys():
			var entry: Dictionary = instances[raw_id] as Dictionary
			if str(entry.get("name", "")) == same_name:
				var original_id: String = str(entry.get("sourceId", ""))
				observed[original_id] = true
		_check(observed.has(duplicate_ids[0]) and observed.has(duplicate_ids[1]), "distinct source IDs pinned to physical items")
		var second_variant: Dictionary = world.call("_find_catalog_item_record", same_name, duplicate_ids[1])
		_check(str(second_variant.get("sourceId", "")) == duplicate_ids[1], "source-ID lookup returns exact record")
		world.call("_save_game", true)
		world.call("_load_game", true)
		instances = world.get("item_instances") as Dictionary
		observed.clear()
		for raw_id: Variant in instances.keys():
			var entry: Dictionary = instances[raw_id] as Dictionary
			if str(entry.get("name", "")) == same_name:
				observed[str(entry.get("sourceId", ""))] = true
		_check(observed.has(duplicate_ids[0]) and observed.has(duplicate_ids[1]), "source variants survive save and reload")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("CATALOG_BROWSER_SMOKE_OK: full browsing, search, details and option policies verified")
		quit(0)
	else:
		print("CATALOG_BROWSER_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
