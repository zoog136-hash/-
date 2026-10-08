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
	_check(monsters.size() >= 163, "monster catalogue must include all existing records")
	_check(LOOT.is_boss_record({"name":"검은숲의 지배자"}), "zone keeper must be a boss")
	_check(LOOT.is_boss_record({"name":"데스나이트", "desc":"보스형"}), "described boss must be a boss")
	_check(LOOT.is_boss_record({"name":"흑장로"}), "named boss must be a boss")
	_check(not LOOT.is_boss_record({"name":"천상계 성광기사", "grade":"영웅"}), "grade alone must not imply boss")
	_check(not LOOT.is_boss_record({"name":"데스나이트", "desc":"보스형", "is_boss":false}), "explicit override must work")
	var boss_count: int = 0
	for monster_value: Variant in monsters:
		var record: Dictionary = monster_value as Dictionary
		var is_boss: bool = LOOT.is_boss_record(record)
		if is_boss:
			boss_count += 1
		var drops: Array[String] = []
		for item_value: Variant in record.get("drop", []):
			drops.append(str(item_value))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 1024
		var potion_count: int = 0
		var gear_count: int = 0
		for index: int in range(500):
			var acquired: Array[String] = LOOT.roll(drops, is_boss, catalog, rng)
			_check(acquired.size() <= 2, "at most one potion and one piece of equipment")
			for item_name: String in acquired:
				_check(by_name.has(item_name), "unknown item: " + item_name)
				if not by_name.has(item_name):
					continue
				var item: Dictionary = by_name[item_name] as Dictionary
				var grade: String = str(item.get("grade", ""))
				if LOOT._is_potion(item):
					potion_count += 1
					_check(grade != "유일", "unique potion forbidden")
				else:
					gear_count += 1
					_check(LOOT._is_equipment(item), "drops must be gear or potion")
					_check(grade != "유일", "unique equipment forbidden")
					if not is_boss:
						_check(grade in ["일반", "고급", "희귀", "영웅"], "normal monster exceeded Hero cap: " + item_name)
		_check(potion_count > 0, "potion loot must be available to " + str(record.get("name", "")))
		_check(gear_count > 0, "equipment loot must be available to " + str(record.get("name", "")))
	_check(boss_count >= 30, "named / described boss recognition unexpectedly low")
	_check(absf(float(LOOT.NORMAL_EQUIPMENT_RATES["영웅"])-0.0003) < 0.000001, "normal Hero rate wrong")
	_check(absf(float(LOOT.BOSS_EQUIPMENT_RATES["신화"])-0.0005) < 0.000001, "boss Mythic rate wrong")
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("LOOT_BALANCE_OK: normal <= Hero, boss <= Mythic, unique excluded, potions separate")
		quit(0)
	else:
		print("LOOT_BALANCE_FAILED: %d issues" % failures.size())
		quit(1)
