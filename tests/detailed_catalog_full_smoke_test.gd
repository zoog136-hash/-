extends SceneTree

const DETAIL = preload("res://scripts/detailed_catalog_options.gd")
var failures: Array[String] = []

func _check(ok: bool, note: String) -> void:
	if not ok:
		failures.append(note)
		print("DETAIL_CATALOG_FAIL: " + note)

func _find(data: Dictionary, category: String, name_value: String) -> Dictionary:
	for raw: Variant in data.get(category, []) as Array:
		if raw is Dictionary and str((raw as Dictionary).get("name", "")) == name_value:
			return raw as Dictionary
	return {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(DETAIL.parse_option("Max HP +5,000").get("value", 0.0) == 5000.0, "parse thousands")
	_check(DETAIL.parse_option("최대 HP+15%").get("value", 0.0) == 0.15, "parse percent max HP")
	_check(DETAIL.parse_option("PVP 근거리 추가 대미지 +5").get("key", "") == "pve_melee_damage", "convert PvP into PvE")
	_check(DETAIL.parse_option("근거리 대미지 리덕션 무시 +2").get("key", "") == "ignore_reduction_melee", "reduction ignore becomes extra damage")
	_check(DETAIL.parse_option("MP 회복(틱) +20").get("key", "") == "mp_recovery", "MP periodic recovery")
	_check(DETAIL.parse_option("마법 방어력(MR) +15").get("key", "") == "mr", "magic resist")
	_check(DETAIL.parse_option("물리 방어력(AC) -2").get("value", 0.0) == 2.0, "AC negative gives bonus")
	_check(DETAIL.parse_option("물약 회복률 +2%").get("key", "") == "potion_pct", "potion rate")
	_check(DETAIL.parse_option("무기 손상 방지").get("kind", "") == "removed", "durability removed")
	_check(DETAIL.parse_option("발동: 루인 크래시 5%").get("kind", "") == "deferred", "unique proc remains deferred")

	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	_check(raw is Dictionary, "catalog file loads")
	if not (raw is Dictionary):
		_finish()
		return
	var data: Dictionary = raw as Dictionary
	for cat: String in ["아이템", "변신", "마법인형", "성물"]:
		var expected: int = {"아이템":2129,"변신":413,"마법인형":166,"성물":144}[cat]
		var rows: Array = data.get(cat, []) as Array
		_check(rows.size() == expected, "full original %s %d records" % [cat, expected])
		var all_source: int = 0
		for raw_record: Variant in rows:
			var record: Dictionary = raw_record as Dictionary
			_check(not str(record.get("name","")).is_empty() and not str(record.get("sourceUrl","")).is_empty(),
				"source row has name and original URL")
			var checked: Dictionary = DETAIL.classify(record)
			var count: int = int(checked.get("total", -1))
			all_source += count
			_check(count == (record.get("sourceOptions", []) as Array).size(), "all original options counted")
		print("DETAIL_CATALOG_CATEGORY_OK: %s %d records %d original options" % [cat, rows.size(), all_source])

	var staff: Dictionary = _find(data,"아이템","기르타스의 지팡이")
	_check((staff.get("sourceOptions",[]) as Array).size() == 18, "Girtas staff has 18 source options")
	var display: PackedStringArray = DETAIL.source_display(staff)
	_check(display.size() == 17, "full staff description except deleted durability (not truncated to 16)")
	_check(display[display.size() - 1].contains("대미지 증가"), "last original option remains visible")
	var gunter: Dictionary = DETAIL.enrich(_find(data, "아이템", "군터의 단도"))
	_check(int(gunter.get("strFlat", 0)) == 2, "gunter STR +2")
	_check(int(gunter.get("hit", 0)) == 4, "gunter weapon hit +4")
	_check(int(gunter.get("ignore_reduction_melee", 0)) == 2, "gunter ignore converts extra melee damage")
	var halfas: Dictionary = DETAIL.enrich(_find(data,"변신","해방된 할파스"))
	_check(int(halfas.get("hpFlat",0)) == 5000, "Halphas +5000 HP")
	_check(int(halfas.get("pve_damage_reduction_pct",0)) == 10, "Halphas PvP->PvE percent reduction")
	_check(int(halfas.get("stun_resistance",0)) == 30, "Halphas +30 stun resist")
	var lindvior: Dictionary = DETAIL.enrich(_find(data,"마법인형","린드비오르"))
	_check(int(lindvior.get("weightBonus",0)) == 3500, "Lindvior +3500 weight")
	_check(int(lindvior.get("stun_resistance",0)) == 15, "Lindvior +15 stun resistance")
	var relic: Dictionary = DETAIL.enrich(_find(data,"성물","진명황의 보주"))
	_check(int(relic.get("damage_reduction_ignore",0)) == 5, "relic ignore converts +5 extra damage")
	_check(int(relic.get("skillCooldownPct",0)) == 10, "relic skill cooldown reduction")

	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		_check(false,"Main.tscn")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var cdata: Dictionary = world.get("catalog_db") as Dictionary
	for cat: String in ["아이템","변신","마법인형","성물"]:
		_check((cdata.get(cat,[]) as Array).size() >= (data.get(cat,[]) as Array).size(), "runtime complete catalog category " + cat)
	var hud: Node = world.get_node("HUD")
	var results: Array = [staff]
	hud.set("catalog_results", results)
	hud.call("_on_catalog_item_selected", 0)
	var detail_view: RichTextLabel = hud.get("catalog_detail") as RichTextLabel
	_check(detail_view.text.contains("대미지 증가 +25%"), "catalog UI shows final #18 source option")
	_check(detail_view.text.contains("추가 검증"), "catalog UI reports unsupported option count")
	world.set("equipped_catalog", {"변신":{},"마법인형":{},"성물":{}})
	world.set("equipped_items", {})
	var base_strength: int = int(world.call("_effective_attribute", "STR"))
	var base_capacity: int = int(world.call("_carrying_capacity"))
	var base_stun_resist: int = int(world.call("_stun_resistance_stat"))
	world.set("equipped_catalog", {"변신":halfas,"마법인형":lindvior,"성물":relic})
	_check(int(world.call("_carrying_capacity")) == base_capacity + 3500, "doll weight bonus affects inventory capacity")
	_check(int(world.call("_stun_resistance_stat")) >= base_stun_resist + 45, "transform and doll stun resistance apply")
	_check(int(world.call("_catalog_stat_sum","skillCooldownPct")) == 10, "relic cooldown bonus affects runtime")
	world.set("equipped_catalog", {"변신":{}, "마법인형":{}, "성물":{}})
	world.set("equipped_items", {"weapon":gunter})
	_check(int(world.call("_effective_attribute","STR")) == base_strength + 2, "source item STR affects runtime")
	_check(int(world.call("_equipment_additional_damage","melee")) >= 2, "reduction ignore adds melee combat damage")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("DETAIL_CATALOG_FULL_OK: all source entries/options, stats, PvE, HUD and runtime coverage")
		quit(0)
	else:
		print("DETAIL_CATALOG_FULL_FAILED: %d" % failures.size())
		quit(1)
