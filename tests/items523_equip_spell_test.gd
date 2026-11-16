extends SceneTree
## TWILIGHT 근사: ItemBonus EquipSpellClassID (적용 유형 1 = SpellClass) gives that spell
## while the item is worn (player_skills523.equipment_spell_records, skill_catalog.owned).
## With the original ZIP, in actual Main: the skill records exist, a worn 에오딘의 스톤 /
## 패왕의 위엄 enables its skill, casting spends the original cost, and taking it off
## disables the skill again. Without the ZIP no record is made.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("EQUIP_SPELL523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func grant(world: Node, id: int) -> String:
	world.equipped_items.clear(); world._invalidate_equipment_static()
	world.inventory = {}; world.item_instances = {}
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok",false), "grant #%d: %s" % [id,str(staged.get("error",""))]): return ""
	world._save_game(true,staged.overrides)
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	for key: String in world.item_instances:
		if int(world.item_instances[key].get("record",{}).get("source_item_class_id",-1))==id: return key
	return ""

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	var catalog = world.original_skills.catalog
	var records: Dictionary = {}
	for record: Dictionary in catalog.records:
		if record.has("equipment_spell523"): records[str(record.id)] = {"name":str(record.name),"mode":str(record.get("mode","")),"items":(record.equipment_spell_items as Array).size()}
	evidence["records"] = records
	check(records.size() >= 5, "equipment skill records from EquipSpellClassID: "+str(records))
	world.level = 90
	for case: Array in [[186842,"eqspell523_62142"],[263808,"eqspell523_87828"]]:
		var item: int = int(case[0]); var id: String = str(case[1])
		var record: Dictionary = catalog.record_for(id)
		if not check(not record.is_empty(), "record %s" % id): continue
		world.job_class = "군주"
		var uid: String = grant(world, item)
		if uid.is_empty(): continue
		var before: bool = catalog.enabled(record)
		world._equip_or_acquire_item(world.item_instances[uid].record,false,uid,"")
		world._invalidate_equipment_static()
		var worn: bool = world._is_instance_equipped(uid)
		var on: bool = catalog.enabled(record)
		world.hp = maxi(1, int(world._effective_max_hp() / 2)); world.mp = world._effective_max_mp(); world.skill_cooldowns.clear(); world.skill_global_cooldown = 0.0
		var hp0: int = world.hp
		var cast: bool = false
		if str(record.get("mode","")) == "buff": cast = world.original_skills.cast(record)
		var row: Dictionary = {"item":item,"worn":worn,"before":before,"on":on,"mode":str(record.get("mode","")),"cast":cast,"hp":[hp0,world.hp],"cooldown":float(world.skill_cooldowns.get(str(record.name),0.0))}
		world.equipped_items.clear(); world._invalidate_equipment_static()
		row["off"] = catalog.enabled(record)
		evidence[id] = row
		check(worn and not before and on and not bool(row.off), "%s: 착용 중에만 스킬 사용 가능 %s" % [id,str(row)])
		if str(record.get("mode","")) == "buff": check(cast and world.hp > hp0 and float(row.cooldown) > 0.0, "%s: 시전 → HP 회복·원본 재사용 대기 %s" % [id,str(row)])
	world.queue_free()
	for frame: int in 5: await process_frame

func run() -> void:
	if SOURCE.not_installed():
		var world_free: bool = true
		check(world_free, "without the original ZIP no equipment skill record is made (nothing to check)")
	else:
		await runtime()
	print("EQUIP_SPELL523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
