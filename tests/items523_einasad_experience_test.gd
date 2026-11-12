extends SceneTree
## Original 523 아인하사드 충전 + 경험치 아이템 (드래곤의 성수 / 떡국 / 치킨 등,
## ItemCategory EinasadRecharager with an Experience row and an ItemConsumeRate
## group of application type 42) in the actual game.
## Without the original definition ZIP only the static rules run. With it:
## the contract from the rows and the item's own description, a physical
## grant -> bag use -> save -> reload in actual Main, the level limit, the
## group-12 charge bonus at 85, the group-2 level range, a full blessing and a
## level-up reached by the item EXP.
const EFFECTS = preload("res://scripts/loot/source523_item_effects.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const EXP_RULES = preload("res://scripts/experience_progression.gd")
const QA = preload("res://tests/qa_class_selection.gd")
## 드래곤의 성수 without a delete time, 떡국 ("2026를 충전"), a 15,200,000 one.
const HOLY := 150784
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEMS523_EINASAD_EXP_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	check(EFFECTS.twilight_experience(31920000)==EXP_RULES.HOLY_WATER_EXP, "31,920,000 Lineage M EXP is the existing HOLY_WATER_EXP")
	check(EFFECTS.twilight_experience(15960000)==int(round(EXP_RULES.HOLY_WATER_EXP/2.0)), "half the EXP converts to half")
	check(EFFECTS.twilight_experience(0)==0, "no EXP converts to none")

func record(id: int) -> Dictionary:
	return D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)

func table() -> void:
	var holy: Dictionary = EFFECTS.ain(record(HOLY))
	evidence["contract_%d" % HOLY] = holy
	check(holy.get("points")==1500 and holy.get("experience")==30400000 and holy.get("experience_rate_group")==2 and holy.get("consume_rate_group")==12, "#150784: 1500 points, Experience 30,400,000, rate group 2, bonus group 12")
	check(EFFECTS.uniform_rate(2)==10500, "ItemConsumeRate group 2 is 10500 at both of its rows")
	check(EFFECTS.source_experience(holy,45)==31920000 and EFFECTS.source_experience(holy,99)==31920000, "45 and 99: 31,920,000 (description)")
	check(EFFECTS.source_experience(holy,100)==-1 and EFFECTS.source_experience(holy,0)==-1, "outside the group rows (1..99) the EXP is not decided")
	# Every non-test original item of this family is claimed, or explained.
	var claimed: int = 0; var held: Array = []
	var categories: Dictionary = {}
	for category: Dictionary in SOURCE.rows("ItemCategory"):
		if str(category.get("Name",""))=="EinasadRecharager": categories[int(category.ID)] = true
	for row: Dictionary in SOURCE.rows_matching("ItemClass","CategoryID",categories):
		if row.get("TestItem")!=false: continue
		var has_experience: bool = false
		for link: Dictionary in SOURCE.related("ItemBonus","ItemClassID",int(row.ID)):
			var bonus: Dictionary = SOURCE.row("Bonus",int(link.BonusID))
			if str(SOURCE.row("BonusType",int(bonus.get("BonusTypeID",0))).get("Name",""))=="Experience": has_experience = true
		if not has_experience: continue
		var contract: Dictionary = EFFECTS.ain(record(int(row.ID)))
		if not contract.is_empty() and int(contract.get("experience",0))>0: claimed += 1
		else: held.append(int(row.ID))
	evidence["family"] = {"claimed":claimed,"held":held}
	check(claimed==184 and held.is_empty(), "184 non-test Einasad+EXP items are claimed (%d, held %s)" % [claimed,str(held)])

func grant(world: Node, id: int, amount: int) -> String:
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":id,"amount":amount,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok",false), "physical grant of %d: %s" % [id,str(staged.get("error",""))]): return ""
	if not check(world._save_game(true,staged.overrides)==OK, "grant save"): return ""
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	return str(record(id).name)

func use(world: Node, name: String) -> Dictionary:
	world.item_use_cooldowns.clear()
	var before: Dictionary = {"blessing":world.ain_service.blessing,"experience":world.experience,"level":world.level,"count":int(world.inventory.get(name,0))}
	var result: Dictionary = STACK.try_use(world,name)
	return {"result":{"ok":result.get("ok",false),"reason":str(result.get("reason",result.get("message","")))},"before":before,"after":{"blessing":world.ain_service.blessing,"experience":world.experience,"level":world.level,"count":int(world.inventory.get(name,0))}}

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false); world.player.auto_enabled = false
	world._clear_monsters(); world._clear_drops()
	world.inventory = {}; world.item_instances = {}
	world.ain_service.dragon_orb_expires_at = 0
	var bonus: float = 1.0+(world.growth.bonus("blessing_charge:percent")+world.card_collections.bonus("blessing_charge:percent"))/100.0
	var name: String = grant(world,HOLY,6)
	if name.is_empty(): world.queue_free(); await process_frame; return
	check(not STACK.supply_profile(record(HOLY)).is_empty() and STACK.profile(record(HOLY)).get("kind")=="ain", "the item has a physical supply and use owner (ain)")
	var uses: Dictionary = {}
	# Level 44: the item's LevelLimitMin 45 keeps it.
	world.level = 44; world.experience = 0; world.exp_need = 1<<50; world.ain_service.blessing = 150
	uses["lv44"] = use(world,name)
	check(not uses.lv44.result.ok and uses.lv44.after.count==6 and uses.lv44.after.blessing==150 and uses.lv44.after.experience==0, "below level 45 the item is kept")
	# Level 50: +1500 blessing and the converted EXP.
	world.level = 50
	uses["lv50"] = use(world,name)
	check(uses.lv50.result.ok and uses.lv50.after.count==5 and uses.lv50.after.blessing-uses.lv50.before.blessing==int(round(1500*bonus)) and uses.lv50.after.experience-uses.lv50.before.experience==EXP_RULES.HOLY_WATER_EXP, "level 50: blessing +1500 and EXP +%d, one used" % EXP_RULES.HOLY_WATER_EXP)
	# Level 85: the group-12 charge bonus (x2) on the blessing only.
	world.level = 85; world.ain_service.blessing = 150
	uses["lv85"] = use(world,name)
	check(uses.lv85.result.ok and uses.lv85.after.blessing-uses.lv85.before.blessing==int(round(3000*bonus)) and uses.lv85.after.experience-uses.lv85.before.experience==EXP_RULES.HOLY_WATER_EXP, "level 85: blessing x2 (3000), EXP unchanged")
	# Level 100: past the group-2 rows (1..99) the item is kept.
	world.level = 100; world.ain_service.blessing = 150
	uses["lv100"] = use(world,name)
	check(not uses.lv100.result.ok and uses.lv100.after.count==uses.lv100.before.count and uses.lv100.after.experience==uses.lv100.before.experience, "level 100: EXP rate row missing, item kept")
	# Full blessing keeps the item (existing charge rule).
	world.level = 50; world.ain_service.blessing = 99999
	uses["full"] = use(world,name)
	check(not uses.full.result.ok and uses.full.after.count==uses.full.before.count, "full blessing keeps the item")
	# A level-up reached by the item EXP.
	world.ain_service.blessing = 150; world.experience = 0; world.exp_need = 1000000
	uses["levelup"] = use(world,name)
	check(uses.levelup.result.ok and uses.levelup.after.level>50, "the item EXP levels up (Lv.%d)" % int(uses.levelup.after.level))
	await process_frame
	# A plain name-keyed stack (as the 523 shop sells it) of another one.
	var plain: String = str(record(152483).name)
	world.inventory[plain] = 2; world.level = 60; world.experience = 0; world.exp_need = 1<<50; world.ain_service.blessing = 150; world.item_use_cooldowns.clear()
	var plain_before: Dictionary = {"blessing":world.ain_service.blessing,"experience":world.experience}
	var handled: bool = EFFECTS.try_use_plain(world,plain)
	uses["plain_152483"] = {"handled":handled,"count":int(world.inventory.get(plain,0)),"blessing":world.ain_service.blessing-int(plain_before.blessing),"experience":world.experience-int(plain_before.experience)}
	check(handled and int(world.inventory.get(plain,0))==1 and world.ain_service.blessing-int(plain_before.blessing)==int(round(1500*bonus)) and world.experience-int(plain_before.experience)==EXP_RULES.HOLY_WATER_EXP, "plain stack #152483: one used, +1500 / EXP")
	world.inventory.erase(plain)
	world.level = 50
	evidence["uses"] = uses
	# Save -> reload.
	var expected: Dictionary = {"count":int(world.inventory.get(name,0)),"blessing":world.ain_service.blessing,"experience":world.experience,"level":world.level}
	check(world._save_game(true)==OK, "save")
	world.ain_service.blessing = 7; world.experience = 1; world.level = 1; world.inventory.erase(name)
	world._load_game(true)
	var reloaded: Dictionary = {"count":int(world.inventory.get(name,0)),"blessing":world.ain_service.blessing,"experience":world.experience,"level":world.level}
	evidence["save_reload"] = {"expected":expected,"reloaded":reloaded}
	check(reloaded==expected and expected.count==3, "count/blessing/EXP/level survive reload")
	var physical: int = 0
	for id: String in world.item_instances:
		var proof: Dictionary = STACK.proof(world,id)
		if not proof.is_empty() and str(proof.record.name)==name: physical += int(proof.remaining)
	check(physical==3, "the reloaded physical stack proves 3 remaining")
	uses["after_reload"] = use(world,name)
	check(uses.after_reload.result.ok and uses.after_reload.after.count==2, "the reloaded stack is usable")
	check(world.patch523_owner_state_problem.is_empty(), "no owner problem")
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		table()
		await runtime()
	print("ITEMS523_EINASAD_EXP_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
