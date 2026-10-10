extends SceneTree

const LOOT = preload("res://scripts/loot_drop.gd")
const DB_PATH = "res://data/game_db_v17.json"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("LOOT_BALANCE_FAIL: " + message)

func _run() -> void:
	var data_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DB_PATH))
	_check(data_value is Dictionary, "database must parse")
	if not (data_value is Dictionary):
		_finish()
		return
	var data: Dictionary = data_value as Dictionary
	var catalog: Dictionary = LOOT.build_catalog(data.get("아이템", []))
	var by_name: Dictionary = catalog["by_name"]
	var monsters: Array = data.get("몬스터", [])
	_check(monsters.size() >= 163, "existing monster catalog must remain present")
	_check(LOOT.is_boss_record({"name":"검은숲의 지배자"}), "zone keeper must be a boss")
	_check(LOOT.is_boss_record({"name":"데스나이트", "desc":"보스형"}), "described boss must be a boss")
	_check(LOOT.is_boss_record({"name":"흑장로"}), "named boss must be a boss")
	_check(not LOOT.is_boss_record({"name":"천상계 성광기사", "grade":"영웅"}), "grade alone must not imply boss")
	_check(not LOOT.is_boss_record({"name":"데스나이트", "desc":"보스형", "is_boss":false}), "boss override must work")
	_check(LOOT.MAX_BOSS_EQUIPMENT_ROLLS == 3, "boss equipment must roll three times")
	_check(LOOT.EQUIPMENT_GRADES.has("유일"), "Unique grade must be selectable")
	for grade: String in ["일반", "고급", "희귀"]:
		_check(absf(float(LOOT.NORMAL_EQUIPMENT_RATES[grade]) - 0.001) < 0.000000001, "normal " + grade + " rate must be 0.1%")
		_check(absf(float(LOOT.BOSS_EQUIPMENT_RATES[grade]) - 0.001) < 0.000000001, "boss " + grade + " rate must be 0.1% per roll")
	_check(absf(float(LOOT.NORMAL_EQUIPMENT_RATES["영웅"]) - 0.00015) < 0.000000001, "normal Hero rate must be 0.015%")
	_check(absf(float(LOOT.BOSS_EQUIPMENT_RATES["영웅"]) - 0.01) < 0.000000001, "boss Hero rate must be 1%")
	_check(absf(float(LOOT.BOSS_EQUIPMENT_RATES["전설"]) - 0.002) < 0.000000001, "boss Legendary rate must be 0.2%")
	_check(absf(float(LOOT.BOSS_EQUIPMENT_RATES["신화"]) - 0.00025) < 0.000000001, "boss Mythic rate must be 0.025%")
	_check(absf(float(LOOT.BOSS_EQUIPMENT_RATES["유일"]) - 0.00001) < 0.000000001, "boss Unique rate must be 0.001%")
	_check(not LOOT.NORMAL_EQUIPMENT_RATES.has("전설"), "normal monsters cannot roll Legendary")
	_check(not LOOT.NORMAL_EQUIPMENT_RATES.has("신화"), "normal monsters cannot roll Mythic")
	_check(not LOOT.NORMAL_EQUIPMENT_RATES.has("유일"), "normal monsters cannot roll Unique")
	_check(absf(LOOT.NORMAL_POTION_RATE - 0.45) < 0.000001, "normal potion rate must remain 45%")
	_check(absf(LOOT.BOSS_POTION_RATE - 0.90) < 0.000001, "boss potion rate must remain 90%")
	var equipment_pools: Dictionary = catalog["equipment_by_grade"]
	_check(not (equipment_pools.get("유일", []) as Array).is_empty(), "Unique equipment pool must be available")
	var special_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	special_rng.seed = 714
	var unique_item: String = LOOT._pick_equipment("유일", ["기르타스의 단검"], catalog, special_rng)
	_check(unique_item == "기르타스의 단검", "boss configured Unique gear should be prioritized")
	# A configured monster must never inherit an unrelated item or grade.
	var strict_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	strict_rng.seed = 3189
	_check(LOOT._pick_equipment("희귀", ["HP 물약", "수정 단검"], catalog, strict_rng, "스파토이") == "", "grade miss must not substitute unrelated rare equipment")
	var live_spatoy_low: String = LOOT._pick_equipment("일반", ["HP 물약", "수정 단검"], catalog, strict_rng, "스파토이")
	_check(live_spatoy_low in ["청동 이도류", "청동 크로우"], "verified Spatoy common L1J source must not roll unrelated equipment")
	var live_spatoy_mid: String = LOOT._pick_equipment("고급", ["HP 물약", "수정 단검"], catalog, strict_rng, "스파토이")
	_check(live_spatoy_mid in ["강철 이도류", "강철 크로우", "수정 단검"], "verified Spatoy uncommon L1J source coexists with registered legacy item")
	_check(LOOT._pick_equipment("유일", ["HP 물약"], catalog, strict_rng, "고스트") == "", "potion-only monster must not inherit Unique equipment")
	_check(LOOT._pick_equipment("일반", ["없는 아이템"], catalog, strict_rng, "잘못된 몬스터") == "", "unmapped item must be rejected")
	# The optional L1J mapping changes ONLY item selection within the grade,
	# not absolute rarity probability or number of equipment rolls.
	var mapped_catalog: Dictionary = catalog.duplicate(false)
	mapped_catalog["l1j_monster_drops"] = {
		"스파토이":[
			{"item_name":"수정 단검", "weight":9, "min":2, "max":4},
			{"item_name":"강철 판금 갑옷", "weight":1, "min":1, "max":1}
		]
	}
	var samples: Dictionary = {}
	for sample_index: int in range(500):
		var pick: Dictionary = LOOT._pick_equipment_entry("고급", ["마족의 단검"], mapped_catalog, strict_rng, "스파토이")
		var pick_name: String = str(pick.get("item_name", ""))
		_check(pick_name in ["수정 단검", "강철 판금 갑옷"], "mapping must override unrelated legacy drop")
		if pick_name == "수정 단검":
			_check(int(pick.get("quantity", 0)) >= 2 and int(pick.get("quantity", 0)) <= 4, "mapped count range preserved")
		samples[pick_name] = int(samples.get(pick_name, 0)) + 1
	_check(int(samples.get("수정 단검",0)) > int(samples.get("강철 판금 갑옷",0)) * 5, "within-grade weights honored")
	_check(LOOT._pick_equipment_entry("희귀", ["마족의 단검"], mapped_catalog, strict_rng, "스파토이").get("item_name", "") == "마족의 단검", "partial L1J mapping preserves legacy monster items")
	_check(LOOT._pick_equipment_entry("유일", ["HP 물약"], mapped_catalog, strict_rng, "스파토이").is_empty(), "registered mob without Unique source or legacy entry cannot substitute")
	# Verified L1J 46141 Ice Queen -> 11 Crystal Dagger: real opt-in registry
	# enters the same selection path without dropping TWILIGHT's own boss loot.
	var live_map: Dictionary = catalog.get("l1j_monster_drops", {})
	_check(live_map.has("얼음 여왕"), "real Ice Queen source mapping loaded from JSON")
	var queen_loot: Dictionary = LOOT._pick_equipment_entry("고급", ["마법 망토"], catalog, strict_rng, "얼음 여왕")
	_check(str(queen_loot.get("item_name", "")) == "수정 단검", "L1J Crystal Dagger mapped through live catalog")
	_check(int(queen_loot.get("quantity", 0)) == 1, "real source quantity preserved")
	_check(LOOT._pick_equipment_entry("희귀", ["마법 망토"], catalog, strict_rng, "얼음 여왕").get("item_name", "") == "마법 망토", "Ice Queen retains her preexisting rare cloak with L1J import")
	var live_death_knight: Dictionary = LOOT._pick_equipment_entry("영웅", ["진명황의 집행검"], catalog, strict_rng, "데스나이트")
	_check(str(live_death_knight.get("item_name", "")) == "론드의 이도류", "source mob 45601 / weapon 76 must map to real Death Knight drop")
	_check(int(live_death_knight.get("quantity", 0)) == 1, "source Death Knight quantity must survive equipment pick")
	_check(LOOT._pick_equipment_entry("희귀", ["진명황의 집행검"], catalog, strict_rng, "데스나이트").get("item_name", "") == "완력의 목걸이", "Death Knight source strength amulet uses its rare grade")
	_check(LOOT._pick_equipment_entry("신화", ["진명황의 집행검"], catalog, strict_rng, "데스나이트").get("item_name", "") == "진명황의 집행검", "Death Knight legacy mythic gear must remain configured")
	var real_spatoy_rows: Array = live_map.get("스파토이", [])
	_check(real_spatoy_rows.size() == 4, "four explicit original Spatoy weapons must load")
	var source_spatoy_ids: Dictionary = {}
	for raw_spatoy: Variant in real_spatoy_rows:
		if raw_spatoy is Dictionary:
			source_spatoy_ids[int((raw_spatoy as Dictionary).get("l1j_item_id", 0))] = true
	for required_spatoy_id: int in [69, 71, 152, 153]:
		_check(source_spatoy_ids.has(required_spatoy_id), "missing verified Spatoy item source ID " + str(required_spatoy_id))

	_check(LOOT._pick_equipment_entry("희귀", ["마족의 단검"], catalog, strict_rng, "얼음 여왕").get("item_name", "") == "마족의 단검", "legacy registered rare item remains available")
	# Every catalog equipment item must be present in at least one usable
	# monster pool (audited L1J, legacy record, or balance supplement).
	var registered: Dictionary = {}
	var l1j_live: Dictionary = catalog["l1j_monster_drops"]
	var balance_equipment: Dictionary = catalog["twilight_coverage_equipment"]
	var balance_potions: Dictionary = catalog["twilight_coverage_potions"]
	var registered_potions: Dictionary = {"HP 물약":true, "강력 HP 물약":true}
	for monster_value: Variant in monsters:
		var mob: Dictionary = monster_value as Dictionary
		var mob_name: String = str(mob.get("name", ""))
		var boss: bool = LOOT.is_boss_record(mob)
		var direct: Array = mob.get("drop", [])
		for item_value: Variant in direct:
			var item_name: String = str(item_value)
			if not by_name.has(item_name):
				continue
			var item: Dictionary = by_name[item_name] as Dictionary
			if LOOT._is_equipment(item) and (boss or str(item.get("grade", "")) in ["일반","고급","희귀","영웅"]):
				registered[item_name] = true
			elif LOOT._is_potion(item):
				registered_potions[item_name] = true
		for source_group: Dictionary in [l1j_live, balance_equipment]:
			var rows: Variant = source_group.get(mob_name, [])
			if rows is Array:
				for row_value: Variant in rows:
					if not (row_value is Dictionary):
						continue
					var item_name: String = str((row_value as Dictionary).get("item_name", ""))
					if by_name.has(item_name):
						var item: Dictionary = by_name[item_name] as Dictionary
						_check(LOOT._is_equipment(item), "coverage cannot include non-equipment: " + item_name)
						_check(boss or str(item.get("grade", "")) in ["일반","고급","희귀","영웅"], "field coverage cannot exceed Hero: " + item_name)
						registered[item_name] = true
		var potion_rows: Variant = balance_potions.get(mob_name, [])
		if potion_rows is Array:
			for raw_row: Variant in potion_rows:
				if raw_row is Dictionary:
					var potion_name: String = str((raw_row as Dictionary).get("item_name", ""))
					_check(by_name.has(potion_name), "unknown balance potion: " + potion_name)
					if by_name.has(potion_name):
						var potion_record: Dictionary = by_name[potion_name] as Dictionary
						_check(LOOT._is_potion(potion_record), "balance potion must heal: " + potion_name)
						_check(boss or str(potion_record.get("grade", "")) != "유일", "Unique potion must be boss-only")
						registered_potions[potion_name] = true
	# Crafting scrolls share one existing equipment-grade roll and are only
	# reachable through their explicit per-monster ingredient sources.
	var crafting_sources: Dictionary = catalog.get("crafting_drops", {})
	for source_record: Variant in crafting_sources.values():
		if not (source_record is Dictionary):
			continue
		for item_value: Variant in (source_record as Dictionary).get("equipment_ingredients", []):
			var item_name: String = str(item_value)
			if by_name.has(item_name) and bool((by_name[item_name] as Dictionary).get("crafting_scroll", false)):
				registered[item_name] = true
	var equip_total: int = 0
	var potion_total: int = 0
	for item_value: Variant in data.get("아이템", []):
		var item: Dictionary = item_value as Dictionary
		var name_value: String = str(item.get("name", ""))
		if LOOT._is_equipment(item):
			equip_total += 1
			_check(registered.has(name_value), "unreachable equipment: " + name_value)
		elif LOOT._is_potion(item):
			potion_total += 1
			_check(registered_potions.has(name_value), "unreachable potion: " + name_value)
	_check(equip_total == 463, "458 gear plus five scrolls share equipment-grade rolls")
	_check(potion_total == 11, "catalog healing potion count must stay 11")
	# Select a balance-only item through the same in-game equipment-picker.
	var balance_mob_names: Array = balance_equipment.keys()
	_check(not balance_mob_names.is_empty(), "balance registry must be loaded")
	if not balance_mob_names.is_empty():
		var first_mob: String = str(balance_mob_names[0])
		var first_row: Dictionary = (balance_equipment[first_mob] as Array)[0] as Dictionary
		var first_name: String = str(first_row["item_name"])
		var first_grade: String = str((by_name[first_name] as Dictionary).get("grade", ""))
		var first_pick: Dictionary = LOOT._pick_equipment_entry(first_grade, [], catalog, strict_rng, first_mob)
		_check(not first_pick.is_empty() and by_name.has(str(first_pick.get("item_name", ""))), "supplemental item enters real loot picker")


	var boss_count: int = 0
	var normal_count: int = 0
	var gear_count: int = 0
	for monster_value: Variant in monsters:
		var record: Dictionary = monster_value as Dictionary
		var is_boss: bool = LOOT.is_boss_record(record)
		if is_boss:
			boss_count += 1
		else:
			normal_count += 1
		var drops: Array[String] = []
		for item_value: Variant in record.get("drop", []):
			drops.append(str(item_value))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 1024
		var potion_count: int = 0
		for index: int in range(200):
			var acquired: Array[String] = LOOT.roll(drops, is_boss, catalog, rng)
			var max_gear: int = 3 if is_boss else 1
			_check(acquired.size() <= max_gear + 2, "at most one potion, one material and allowed equipment slots")
			var potions_in_kill: int = 0
			var gear_in_kill: int = 0
			var resources_in_kill: int = 0
			for item_name: String in acquired:
				_check(by_name.has(item_name), "unknown dropped item: " + item_name)
				if not by_name.has(item_name):
					continue
				var item: Dictionary = by_name[item_name] as Dictionary
				var grade: String = str(item.get("grade", ""))
				if bool(item.get("crafting_material", false)):
					resources_in_kill += 1
				elif LOOT._is_potion(item):
					potion_count += 1
					potions_in_kill += 1
					_check(grade != "유일" or is_boss, "Unique consumables must be boss-only")
				else:
					gear_count += 1
					gear_in_kill += 1
					_check(LOOT._is_equipment(item), "drops must be equipment or potions")
					_check(grade in LOOT.EQUIPMENT_GRADES, "equipment grade unrecognized")
					if not is_boss:
						_check(grade in ["일반", "고급", "희귀", "영웅"], "normal monster exceeded Hero cap: " + item_name)
			_check(resources_in_kill <= 1, "at most one independent material per kill")
			_check(potions_in_kill <= 1, "at most one potion per kill")
			_check(gear_in_kill <= max_gear, "equipment drop count exceeded cap")
		_check(potion_count > 0, "potion should drop during sample for " + str(record.get("name","")))
	_check(boss_count >= 30 and normal_count >= 100, "boss/normal classification unexpectedly changed")
	_check(gear_count > 0, "equipment roll must produce items in aggregate")
	# Very-low drop rates make a two-or-more-gear kill rare. Sample a large
	# deterministic boss series to verify the independent-roll implementation.
	var sampled_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	sampled_rng.seed = 90210
	var multi_gear_kills: int = 0
	var boss_test_drops: Array[String] = ["HP 물약"]
	for grade: String in LOOT.EQUIPMENT_GRADES:
		var grade_items: Array = equipment_pools.get(grade, [])
		if not grade_items.is_empty():
			boss_test_drops.append(str(grade_items[0]))
	for index: int in range(25000):
		var earned: Array[String] = LOOT.roll(boss_test_drops, true, catalog, sampled_rng)
		var earned_gear: int = 0
		for name: String in earned:
			var item: Dictionary = by_name[name] as Dictionary
			if LOOT._is_equipment(item):
				earned_gear += 1
		if earned_gear >= 2:
			multi_gear_kills += 1
		_check(earned_gear <= 3, "boss dropped more than three equipment")
	_check(multi_gear_kills > 0, "boss must be able to award multiple equipment items")
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("LOOT_BALANCE_OK: 0.1% common/advanced/rare, halved high grades, boss Unique 0.001%, 3 equipment rolls")
		quit(0)
	else:
		print("LOOT_BALANCE_FAILED: %d issues" % failures.size())
		quit(1)
