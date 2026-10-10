extends SceneTree
const LOOT = preload("res://scripts/loot_drop.gd")
const CRAFTING = preload("res://scripts/crafting/local_crafting.gd")
const MONSTER_CATALOG = preload("res://scripts/monsters/monster_catalog.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		printerr("CRAFT_MATERIAL_FAIL: " + label)

func _run() -> void:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	_check(source is Dictionary,"item+monster database is valid JSON")
	if not (source is Dictionary):
		quit(1)
		return
	var db: Dictionary = source as Dictionary
	var catalog: Dictionary = LOOT.build_catalog(db.get("아이템",[]))
	var items: Dictionary = catalog.get("by_name",{})
	var sources: Dictionary = catalog.get("crafting_drops",{})
	var monsters: Array = MONSTER_CATALOG.expand(db.get("몬스터",[]))
	_check(items.size() == 485,"485 items including ten resources and five scrolls")
	_check(monsters.size() == 318 and sources.size() == monsters.size(),"all 318 monsters have explicit crafting drop rows")
	var materials: Array[String] = ["철 광석","동 광석","미스릴 원석","가죽 조각","정제된 목재","천 조각","마력 결정","연마석","약초","정령의 가루"]
	var material_reach: Dictionary = {}
	var equipment_reach: Dictionary = {}
	for record: Variant in monsters:
		var name: String = str((record as Dictionary).get("name",""))
		_check(sources.has(name),"known monster has crafting drop list: "+name)
		var row: Dictionary = sources.get(name,{})
		_check(not (row.get("materials",[]) as Array).is_empty(),"nonempty material pool for "+name)
		for raw: Variant in row.get("materials",[]):
			var item_name: String = str((raw as Dictionary).get("item",""))
			_check(items.has(item_name) and bool((items[item_name] as Dictionary).get("crafting_material",false)), "only material items in resource pool: "+item_name)
			material_reach[item_name] = true
		for raw: Variant in row.get("equipment_ingredients",[]):
			var item_name: String = str(raw)
			_check(items.has(item_name) and LOOT._is_equipment(items[item_name] as Dictionary), "equipment ingredient exists and is equipment: "+item_name)
			if not bool((items[item_name] as Dictionary).get("crafting_scroll",false)):
				equipment_reach[item_name] = true
	var recipes := CRAFTING.new()
	recipes.load_recipes()
	var required_equipment: Dictionary = {}
	for recipe_id: String in recipes.recipes:
		var recipe: Dictionary = recipes.recipes[recipe_id]
		for raw: Variant in recipe.get("materials",[]):
			var item_name: String = str((raw as Dictionary).get("item",""))
			if not (items[item_name] as Dictionary).get("crafting_material",false) and LOOT._is_equipment(items[item_name] as Dictionary):
				required_equipment[item_name] = true
	_check(required_equipment.size() >= 76 and equipment_reach.size() == 76, "all original 76 physical crafting ingredients explicitly reachable")
	for name: String in required_equipment:
		_check(equipment_reach.has(name),"equipment material has monster source: "+name)
	for name: String in materials:
		_check(material_reach.has(name),"resource has monster source: "+name)
		_check(not LOOT._is_equipment(items[name] as Dictionary) and not LOOT._is_potion(items[name] as Dictionary),"resources do not occupy gear/potion roll: "+name)

	var configured: Dictionary = catalog.duplicate(true)
	var override_rows: Dictionary = configured["crafting_drops"]
	override_rows["TESTING_MONSTER"] = {"materials":[],"equipment_ingredients":["청동 한손검"]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1955
	_check(LOOT._pick_equipment("일반",["낡은 장검"],configured,rng,"TESTING_MONSTER") == "낡은 장검","existing explicit equipment drop retains priority")
	_check(LOOT._pick_equipment("일반",["HP 물약"],configured,rng,"TESTING_MONSTER") == "청동 한손검","crafted equipment can fill otherwise empty grade pool")
	_check(LOOT.MAX_BOSS_EQUIPMENT_ROLLS == 3,"boss still limited to three independent equipment rolls")
	_check(LOOT.NORMAL_POTION_RATE == 0.45 and LOOT.BOSS_POTION_RATE == 0.90,"potion rates unchanged")
	for grade: String in ["일반","고급","희귀"]:
		_check(float(LOOT.NORMAL_EQUIPMENT_RATES[grade]) == 0.001 and float(LOOT.BOSS_EQUIPMENT_RATES[grade]) == 0.001,"equipment grade chance unchanged: "+grade)

	# Verify drop-channel wiring; no direct inventory grants or replacement
	# of the original potion/equipment rolls.
	var ordinary: Dictionary = monsters[0]
	var boss: Dictionary = {}
	for raw: Variant in monsters:
		var candidate: Dictionary = raw as Dictionary
		if str(candidate.get("name","")) == "샌드 웜":
			boss = candidate
	_check(not boss.is_empty(),"world boss exists for the sampled drop path")
	for trial: int in range(2):
		var record: Dictionary = ordinary if trial == 0 else boss
		if record.is_empty():
			continue
		var name: String = str(record.get("name",""))
		var is_boss: bool = trial == 1
		var configured_drops: Array[String] = []
		for item_name: Variant in record.get("drop",[]):
			configured_drops.append(str(item_name))
		var sample_rng := RandomNumberGenerator.new()
		sample_rng.seed = 606060 + trial
		var seen: int = 0
		for _index: int in range(4000):
			var acquired: Array[String] = LOOT.roll(configured_drops,is_boss,catalog,sample_rng,name)
			var material_count: int = 0
			var equipment_count: int = 0
			var potion_count: int = 0
			for item_name: String in acquired:
				_check(items.has(item_name),"all rolled items are present in the game database")
				if bool((items[item_name] as Dictionary).get("crafting_material",false)):
					material_count += 1
				elif LOOT._is_equipment(items[item_name] as Dictionary):
					equipment_count += 1
				elif LOOT._is_potion(items[item_name] as Dictionary):
					potion_count += 1
			_check(material_count <= 1 and equipment_count <= (3 if is_boss else 1) and potion_count <= 1,"separate material, equipment, potion slots preserved")
			seen += material_count
		var rate: float = float(seen) / 4000.0
		var expected: float = LOOT.BOSS_MATERIAL_DROP_RATE if is_boss else LOOT.MATERIAL_DROP_RATE
		_check(absf(rate - expected) <= 0.04,"material drops trigger at local configured rate "+name)
	if failures.is_empty():
		print("CRAFT_MATERIAL_OK: 10 materials, 81 recipes, 76 equipment sources, 318 monster sources, independent ground-loot rolls")
		quit(0)
	else:
		print("CRAFT_MATERIAL_FAILED: %d" % failures.size())
		quit(1)
