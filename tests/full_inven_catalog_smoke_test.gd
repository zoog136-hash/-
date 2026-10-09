extends SceneTree

const INVEN = preload("res://scripts/inven_option_adapter.gd")
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		print("INVEN_CATALOG_FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sample: Dictionary = INVEN.annotate({"source":"inven", "name":"검증용 장비",
		"sourceOptions":["STR +10", "Max HP +5,000", "마법 방어력(MR) +13",
			"PVP 대미지 리덕션 +3", "PVP 대미지 감소 +7%",
			"근거리 대미지 리덕션 무시 +2", "대미지 증가 +25%",
			"HP 회복(틱) +8", "MP 회복(틱) +8", "무기 손상 방지",
			"발동: 특수 스킬 5%", "추가 대미지 +10"]})
	check(int(sample.get("strFlat",0)) == 10, "source STR+10")
	check(int(sample.get("hpFlat",0)) == 5000, "source comma thousands HP+5000")
	check(int(sample.get("mr",0)) == 13, "source magic resistance +13")
	check(int(sample.get("pve_damage_reduction",0)) == 3, "PvP reduction converted to PvE")
	check(int(sample.get("pve_damage_reduction_pct",0)) == 7, "PvP percent reduction converted to PvE")
	check(int(sample.get("melee_reduction_ignore",0)) == 2, "melee ignore converted to additional damage")
	check(int(sample.get("damage_amp_pct",0)) == 25, "percent damage amplifier")
	check(int(sample.get("hpRecoveryTick",0)) == 8, "HP periodic recovery defined")
	check(int(sample.get("mpRecoveryTick",0)) == 8, "MP periodic recovery defined")
	check(int(sample.get("additionalDamage",0)) == 10, "source extra damage")
	check((sample.get("inven_unimplemented_options",[]) as Array).has("발동: 특수 스킬 5%"), "unique effect retained but dormant")
	check(not (sample.get("inven_passives", {}) as Dictionary).has("weapon_damage_prevention"), "removed damage flag absent")
	check(int(INVEN.annotate({"source":"inven","sourceOptions":["물리 방어력(AC) -8"],"def":0}).get("def",0)) == 8, "AC -8 normalized to defense 8")
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	check(scene != null, "Main scene exists")
	if scene == null:
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var data: Dictionary = world.get("catalog_db") as Dictionary
	var originals: Dictionary = world.get("inven_record_index") as Dictionary
	var expected: Dictionary = {"아이템":2129, "변신":413, "마법인형":166, "성물":144}
	var total_originals: int = 0
	var original_options: int = 0
	var numeric_keys: int = 0
	for category: String in ["아이템", "변신", "마법인형", "성물"]:
		var entries: Array = data.get(category, []) as Array
		var originals_by_cat: Dictionary = originals.get(category,{}) as Dictionary
		var source_count: int = 0
		for raw: Variant in entries:
			if not (raw is Dictionary):
				continue
			var record: Dictionary = raw as Dictionary
			if str(record.get("source","")) != "inven":
				continue
			source_count += 1
			original_options += (record.get("sourceOptions",[]) as Array).size()
			numeric_keys += (record.get("inven_passives",{}) as Dictionary).size()
			check(bool(record.get("inven_indexed",false)), category+" unindexed "+str(record.get("name","")))
			check(originals_by_cat.has("id:" + str(record.get("sourceId",""))), category+" missing source ID "+str(record.get("sourceId","")))
		total_originals += source_count
		check(source_count == int(expected[category]), category + " all source records visible: " + str(source_count))
	check(total_originals == 2852, "2,852 entries ingested")
	var hud: Node = world.get("hud") as Node
	hud.call("open_catalog", "아이템")
	print("INVEN_UI_SLOT_FILTER=" + str(hud.get("item_slot_filter")))
	check(str(hud.get("item_slot_filter")) == "all", "all original item types accessible without slot filter")
	var staff: Dictionary = world.call("_source_catalog_record", "아이템", {"name":"기르타스의 지팡이"})
	check((staff.get("sourceOptions", []) as Array).size() >= 17, "original Giltas staff has over 16 source options")
	hud.set("catalog_category", "아이템")
	hud.set("catalog_results", [staff])
	hud.call("_on_catalog_item_selected", 0)
	var full_description: String = str((hud.get("catalog_detail") as RichTextLabel).text)
	for raw_opt: Variant in staff.get("sourceOptions", []) as Array:
		var text_option: String = str(raw_opt)
		if text_option.contains("손상") or text_option.contains("저주"):
			continue
		check(full_description.contains(text_option.replace("PVP", "PVE").replace("PvP", "PvE")),
			"catalog UI truncated source option: " + text_option)

	check(original_options >= 9500, "9,600 original options preserved")
	check(numeric_keys > 1500, "numeric passive normalization coverage")
	print("INVEN_CATALOG_AUDIT source_records=" + str(total_originals) + " raw_options=" + str(original_options) + " typed_stats=" + str(numeric_keys))
	var dagger: Dictionary = world.call("_source_catalog_record", "아이템", {"name":"기르타스의 단검"})
	check(str(dagger.get("sourceId","")) == "362391", "Giltas dagger looked up in original catalog")
	check(int(dagger.get("strFlat",0)) == 10, "Giltas dagger STR +10 applies")
	check(int(dagger.get("damage_amp_pct",0)) == 25, "Giltas dagger percent damage +25")
	check(int(dagger.get("additionalDamage",0)) == 84, "Giltas original item additional damage +84")
	check((dagger.get("sourceOptions",[]) as Array).size() >= 15, "original unique item full option list preserved")
	var doll: Dictionary = world.call("_source_catalog_record", "마법인형", {"name":"할파스"})
	check(int(doll.get("hpFlat",0)) == 3000, "Halpas HP +3000 kept")
	check(int(doll.get("pve_damage_reduction_pct",0)) == 7, "Halpas original PvP reduction converted to PVE")
	world.set("equipped_items", {})
	world.set("equipped_catalog", {"변신":{}, "마법인형":{}, "성물":{}})
	var base_str: int = int(world.call("_effective_attribute","STR"))
	var base_damage: int = int(world.call("_melee_damage_stat"))
	var base_mr: int = int(world.call("_effective_mr"))
	world.set("equipped_items", {"weapon":{"name":"기르타스의 단검","slot":"weapon"}})
	check(int(world.call("_effective_attribute","STR")) == base_str + 10, "original STR impacts character stats")
	check(int(world.call("_melee_damage_stat")) > base_damage, "original weapon damage impacts combat")
	check(int(world.call("_equipped_numeric_sum", "damage_amp_pct")) == 25, "original damage percent is active")
	var source_cloak: Dictionary = world.call("_source_catalog_record", "아이템", {"name":"마법 망토"})
	world.set("equipped_items", {"cloak":{"name":"마법 망토","slot":"cloak"}})
	check(int(world.call("_effective_mr")) >= base_mr + 10, "original base MR works from saved item name")
	world.set("equipped_items", {})
	world.set("equipped_catalog", {"변신":{}, "마법인형":{"name":"할파스"}, "성물":{}})
	check(int(world.call("_pve_damage_after_item_buffs",100)) == 93, "original Halpas PvP defense applies to PvE")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("INVEN_CATALOG_OK")
		quit(0)
	else:
		print("INVEN_CATALOG_SMOKE_FAILED: " + str(failures.size()))
		quit(1)
