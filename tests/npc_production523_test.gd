extends SceneTree
## Original 523 NPC production (LuckyDefenceUnitSummon ->
## NpcProductionGenerationOutput, NpcProductionCombinationInput/Output,
## NpcProductionMerge). Without the original definition ZIP only the refusal
## and save-format rules run. With it the lookups are checked against the
## rows, and in actual Main the 제작 window's NPC 생산 button summons
## (forced success and failure rolls) and combines units, then the save is
## reloaded.
const RULES = preload("res://scripts/npc_production523/npc_production523_rules.gd")
const SERVICE = preload("res://scripts/npc_production523/npc_production523_service.gd")
const STATE = preload("res://scripts/npc_production523/npc_production523_state.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SUPPLY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label); printerr("NPC_PRODUCTION523_FAIL: ",label)

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	check(STATE.validate(STATE.fresh()).is_empty(), "a fresh roster is valid")
	check(not STATE.validate({"schema":1,"units":{"98388":0},"history":[]}).is_empty() and not STATE.validate({"schema":1,"units":{"x":1},"history":[]}).is_empty() and not STATE.validate({"schema":2,"units":{},"history":[]}).is_empty(), "zero counts, bad IDs and another schema are refused")
	var staged: Dictionary = STATE.staged({"schema":1,"units":{"1":2,"2":1},"history":[]},{"1":-2,"3":1},{"kind":"combination"})
	check(staged.units=={"2":1,"3":1} and staged.history.size()==1, "roster deltas remove spent units and add the result")
	check(RULES.pick([{"ID":1,"Probability":250000},{"ID":2,"Probability":250000}],249999).get("ID")==1 and RULES.pick([{"ID":1,"Probability":250000},{"ID":2,"Probability":250000}],250000).get("ID")==2 and RULES.pick([{"ID":1,"Probability":250000},{"ID":2,"Probability":250000}],500000).is_empty(), "a roll past the probability total gives no unit")
	check(RULES.percent_text(250000)=="25%" and RULES.percent_text(209525)=="20.95%", "percent text")
	if SOURCE.not_installed():
		check(not RULES.installed() and RULES.summon(8).get("code")=="source_not_installed" and RULES.combination(8).get("code")=="source_not_installed" and RULES.merge(8).get("code")=="source_not_installed", "without the original archive NPC production is held")

func generation_total(generation_id: int) -> int:
	var total: int = 0
	for row: Dictionary in SOURCE.rows_matching("NpcProductionGenerationOutput","GenerationID",{generation_id:true}): total += int(row.Probability)
	return total

func table() -> void:
	var summons: Array = RULES.summons()
	var by_id: Dictionary = {}
	for entry: Dictionary in summons: by_id[int(entry.summon_id)] = entry
	check(summons.size()==3 and by_id.has(8) and by_id.has(28) and by_id.has(48), "the three start-level summons (랜덤/영웅/전설) resolve")
	for id: int in by_id:
		var entry: Dictionary = by_id[id]
		var row: Dictionary = SOURCE.related("LuckyDefenceUnitSummon","ID",id)[0]
		check(int(entry.cost)==int(row.Cost) and int(entry.generation.generation_id)==int(row.NpcProductionGenerationID) and int(entry.generation.total)==generation_total(int(row.NpcProductionGenerationID)), "summon %d cost and outputs are the table rows" % id)
		check(int(entry.currency.item_class_id)==326368 and int(entry.currency.currency_id)==2718, "summon %d is paid with 마물의 결정 (Currency 2718 -> item 326368)" % id)
	evidence["summons"] = {}
	for id: int in by_id: evidence.summons[str(id)] = {"name":str(by_id[id].name),"cost":int(by_id[id].cost),"generation":int(by_id[id].generation.generation_id),"outputs":by_id[id].generation.outputs.size(),"total":int(by_id[id].generation.total)}
	check(RULES.summon(68).get("code")=="summon_level" and RULES.summon(308).get("code")=="summon_level", "other summon levels are held (no level-up rule)")
	check(RULES.summon(198).get("code")=="summon_type", "UnitSummonType 38 is held")
	var combinations: Array = RULES.combinations()
	var four: int = 0
	for entry: Dictionary in combinations:
		var count: int = 0
		for key: String in entry.inputs: count += int(entry.inputs[key])
		if count==4 and int(entry.total)==RULES.SCALE: four += 1
	check(combinations.size()==SOURCE.row_count("NpcProductionCombinationOutput") and four==combinations.size(), "every combination resolves to four input units and a 100% output")
	evidence["combinations"] = combinations.size()
	evidence["combination_input_rows"] = SOURCE.row_count("NpcProductionCombinationInput")
	evidence["generation_output_rows"] = SOURCE.row_count("NpcProductionGenerationOutput")
	for row: Dictionary in SOURCE.rows("NpcProductionMerge"):
		check(RULES.merge(int(row.ID)).get("code")=="merge_output_missing", "merge %d is held (no output in the table)" % int(row.ID))
	evidence["contents_enabled"] = RULES.contents_enabled()
	check(SOURCE.problem().is_empty(), "lookups leave no shared reader problem")

func grant(world: Node, grants: Array) -> bool:
	var staged: Dictionary = SUPPLY.stage(world,grants,{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not staged.get("ok",false): printerr("grant: ",staged); return false
	if world._save_game(true,staged.overrides)!=OK: return false
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances; world.gold = int(staged.overrides.gold)
	world.consumable_service.import_state(staged.overrides.get("consumable_state",world.consumable_service.export_state()))
	return true

## A seed whose first transaction roll is (or is not) below `probability`.
func seed_for(probability: int, success: bool) -> int:
	var rng := RandomNumberGenerator.new()
	for value: int in range(1,100000):
		rng.seed = value
		if (rng.randi_range(0,RULES.SCALE-1)<probability)==success: return value
	return 0

func crystals(world: Node) -> int:
	return int(SERVICE.currency_owned(world,326368).total)

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	world.inventory = {}; world.item_instances = {}; world.equipped_items = {}
	check(grant(world,[{"item_class_id":326368,"amount":200,"bless_raw":1,"enchant":0}]), "200 [디펜스][화폐] 마물의 결정 granted")
	check(crystals(world)==200, "the bag holds 200 마물의 결정")
	# Through the 제작 window (the town NPC craft function): NPC 생산 button.
	world.hud.call("open_crafting")
	var button: Button = world.hud.workspace.find_child("NpcProduction523Button",true,false) as Button
	check(button!=null, "the 제작 window has the NPC 생산 button")
	if button!=null: button.pressed.emit()
	var panel: Node = world.hud.workspace.find_child("NpcProduction523Panel",true,false)
	check(panel!=null, "the NPC 생산 window opens from the 제작 window")
	var random_gen: Dictionary = RULES.summon(8).generation
	var units_before: int = world.npc_production523.export_state().units.size()
	if panel!=null:
		var summon_button: Button = panel.find_child("Summon_8",true,false) as Button
		check(summon_button!=null and not summon_button.disabled, "the 랜덤 소환 button is enabled with 200 crystals")
		if summon_button!=null: summon_button.pressed.emit()
		evidence["panel_status"] = str((panel.find_child("NpcProductionStatus",true,false) as Label).text)
	var history: Array = world.npc_production523.export_state().history
	var first: Dictionary = history[history.size()-1] if not history.is_empty() else {}
	var expected_unit: int = int(RULES.pick(random_gen.outputs,int(first.get("roll",-1))).get("NpcClassID",0))
	check(crystals(world)==150 and int(first.get("unit",0))==expected_unit and expected_unit>0 and world.npc_production523.count(expected_unit)==1, "랜덤 소환 spends 50 and gives the unit its roll selects " + str(first))
	evidence["random_summon"] = {"roll":int(first.get("roll",-1)),"unit":expected_unit,"name":RULES.unit_name(expected_unit),"crystals":crystals(world),"units_before":units_before}
	# 영웅 소환: a failure then a success (25% in the table).
	var hero: Dictionary = RULES.summon(28)
	world.rng.seed = seed_for(int(hero.generation.total),false)
	var lost: Dictionary = SERVICE.summon(world,28)
	check(lost.get("ok",false) and lost.success==false and int(lost.unit)==0 and crystals(world)==90, "a roll past 25% fails, spending 60 " + str(lost))
	world.rng.seed = seed_for(int(hero.generation.total),true)
	var won: Dictionary = SERVICE.summon(world,28)
	var hero_unit: int = int(won.get("unit",0))
	check(won.get("ok",false) and won.success==true and crystals(world)==30 and str(RULES.unit_name(hero_unit)).begins_with("[영웅]") and world.npc_production523.count(hero_unit)>=1, "a roll below 25% gives a hero unit " + str(won))
	check(SERVICE.summon(world,28).get("code")=="currency" and crystals(world)==30, "with 30 crystals a 60 summon is refused and nothing changes")
	evidence["hero_summon"] = {"fail_roll":int(lost.get("roll",-1)),"success_roll":int(won.get("roll",-1)),"unit":hero_unit,"name":RULES.unit_name(hero_unit),"total":int(hero.generation.total),"crystals":crystals(world)}
	# 조합 8: 2x 젠 + 2x 로즈마리 -> 신화 뇌신(여).
	var recipe: Dictionary = RULES.combination(8)
	check(SERVICE.combine(world,8).get("code")=="units", "a combination without its input units is refused")
	var seeded: Dictionary = world.npc_production523.export_state()
	for key: String in recipe.inputs: seeded.units[key] = int(seeded.units.get(key,0))+int(recipe.inputs[key])
	check(world._save_game(true,{STATE.KEY:seeded})==OK, "test setup: the recipe's input units are saved into the roster")
	world.npc_production523.accept(seeded)
	var combined: Dictionary = SERVICE.combine(world,8)
	var output: int = int(recipe.outputs[0].NpcClassID)
	var spent: bool = true
	for key: String in recipe.inputs: spent = spent and world.npc_production523.count(int(key))==int(seeded.units.get(key,0))-int(recipe.inputs[key])
	check(combined.get("ok",false) and int(combined.unit)==output and spent and world.npc_production523.count(output)==1, "combination 8 spends its four inputs and gives " + RULES.unit_name(output))
	evidence["combination"] = {"id":8,"inputs":recipe.inputs,"output":output,"name":RULES.unit_name(output)}
	# Save and reload.
	var roster: Dictionary = world.npc_production523.export_state()
	var bag: Dictionary = world.inventory.duplicate(true)
	check(world._save_game(true)==OK, "the state saves")
	world.npc_production523.accept(STATE.fresh()); world.inventory = {}; world.item_instances = {}
	world._load_game(true)
	check(world.npc_production523.export_state()==roster, "the unit roster and history reload unchanged")
	var bag_diff: Dictionary = {}
	for key: Variant in bag: if world.inventory.get(key)!=bag[key]: bag_diff[key] = [bag[key],world.inventory.get(key)]
	for key: Variant in world.inventory: if not bag.has(key): bag_diff[key] = [null,world.inventory[key]]
	check(bag_diff.is_empty() and crystals(world)==30, "the bag and 30 remaining crystals reload unchanged " + str(bag_diff))
	check(world.patch523_owner_state_problem.is_empty(), "no owner problem after reload")
	evidence["reload"] = {"units":roster.units,"crystals":crystals(world)}
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		table()
		await runtime()
	print("NPC_PRODUCTION523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
