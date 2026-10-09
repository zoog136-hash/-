extends SceneTree

const FULL = preload("res://scripts/full_catalog_options.gd")
var errors: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		errors.append(label)
		print("FULL_CATALOG_FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var raw_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	check(raw_data is Dictionary, "detailed catalog JSON exists")
	if not (raw_data is Dictionary):
		_finish()
		return
	var source: Dictionary = raw_data as Dictionary
	for key: String in ["아이템", "변신", "마법인형", "성물"]:
		var expected: int = int({"아이템":2129,"변신":413,"마법인형":166,"성물":144}.get(key, 0))
		check((source.get(key, []) as Array).size() == expected, key + " has all original entries")
	var option_count: int = 0
	var visible_total: int = 0
	var populated: int = 0
	for category: String in ["아이템", "변신", "마법인형", "성물"]:
		for raw: Variant in source.get(category, []) as Array:
			var record: Dictionary = raw as Dictionary
			var options: Array = record.get("sourceOptions", []) as Array
			var prepared: Dictionary = FULL.enrich(record)
			option_count += options.size()
			visible_total += (prepared.get("runtimeOptions", []) as Array).size()
			check(prepared.get("sourceOptions", []) == options, "source options retained: " + str(record.get("name", "")))
			check(prepared.has("catalogNumericCount"), "passive normalization exists")
			if int(prepared.get("catalogNumericCount", 0)) > 0:
				populated += 1
	check(option_count >= 9600, "all 9603 original option clauses included")
	check(visible_total >= 9000, "all options except removed curse/durability displayed")
	print("FULL_CATALOG_AUDIT: original=%d visible=%d records_with_numeric=%d" % [option_count, visible_total, populated])

	var weapon: Dictionary = FULL.enrich({"name":"군터의 단도", "slot":"weapon",
		"sourceOptions":["무기 명중 +4", "근거리 대미지 리덕션 무시 +2", "STR +2", "발동: 군터의 절망 5%"]})
	check(int(weapon.get("hit",0)) == 4, "item accuracy from sourceOptions")
	check(int(weapon.get("melee_damage_reduction_ignore",0)) == 2, "melee reduction ignore converted to extra damage")
	check(int(weapon.get("strFlat",0)) == 2, "equipment source STR")
	check((weapon.get("deferredOptions", []) as Array).size() == 1, "unknown proc retained but deferred")
	var card: Dictionary = FULL.enrich({"name":"테스트 변신", "sourceOptions":["공격 속도 +190%", "PVP 대미지 리덕션 +3", "PVP 대미지 감소 10%", "최대 HP +10,000", "최대 MP +250", "근거리 대미지 +5", "STR +3", "스턴 내성 +30%", "경험치 획득량 증가 +20%"]})
	check(int(card.get("attackSpeed",0)) == 190, "attack speed from source")
	check(int(card.get("pve_damage_reduction",0)) == 3, "PvP flat converted to PvE")
	check(int(card.get("pve_damage_reduction_pct",0)) == 10, "PvP percentage converted to PvE")
	check(int(card.get("hpFlat",0)) == 10000, "HP thousands punctuation")
	check(int(card.get("mpFlat",0)) == 250, "MP source")
	check(int(card.get("meleeDamage",0)) == 5, "melee damage passive")
	check(int(card.get("strFlat",0)) == 3, "transformation STR")
	check(int(card.get("stun_resistance",0)) == 30, "stun resistance passive")
	check(absf(float(card.get("xp",0)) - 0.2) < 0.00001, "experience bonus converted from percent")
	var protection: Dictionary = FULL.enrich({"name":"보호옵션", "sourceOptions":["무기 손상 방지", "저주", "PVP 근거리 대미지 +4","발동: 고유 주문 1%"]})
	check((protection.get("runtimeOptions", []) as Array).size() == 2, "deprecated durability curse not shown")
	check(int(protection.get("pve_melee_damage",0)) == 4, "PvP melee bonus converted to PvE")
	check((protection.get("sourceOptions", []) as Array).size() == 4, "original source raw preserved")

	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	check(scene != null, "scene loads")
	if scene == null:
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var catalog: Dictionary = world.get("catalog_db") as Dictionary
	for category: String in ["아이템","변신","마법인형","성물"]:
		check((catalog.get(category, []) as Array).size() >= (source.get(category, []) as Array).size(), "loaded catalog has all " + category)
	var record: Dictionary = world.call("_find_catalog_item_record", "군터의 단도")
	check(not record.is_empty(), "detailed weapon available through item lookup")
	check((record.get("runtimeOptions", []) as Array).size() > 3, "detailed weapon source clauses indexed")
	var first: Dictionary = (catalog.get("변신", []) as Array)[0] as Dictionary
	check(first.has("catalogOptionCount"), "loaded first transform passives indexed")
	var hud: Node = world.get_node_or_null("HUD")
	if hud != null:
		hud.call("open_catalog", "아이템")
		check(str(hud.get("item_slot_filter")) == "all", "all detailed items shown by default")
		var filtered: Array = hud.get("catalog_filtered_results") as Array
		check(filtered.size() >= 2129, "unfiltered all-items view includes all 2,129 Inven items")
		hud.call("open_catalog", "변신")
		check((hud.get("catalog_filtered_results") as Array).size() == 413, "all 413 transforms visible")
	else:
		check(false, "HUD unavailable")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if errors.is_empty():
		print("FULL_CATALOG_OK: complete source records, display, interpretation, PvE conversion and runtime")
		quit(0)
	else:
		print("FULL_CATALOG_FAILED: %d" % errors.size())
		quit(1)
