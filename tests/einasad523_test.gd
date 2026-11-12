extends SceneTree
## Original 523 아인하사드의 축복 (EinasadLevel / EinasadBenefit / EinasadVariable /
## ItemConsumeRate / LevelEinasadBlessRecharge) in the actual game.
## Without the original definition ZIP only the fallback runs: the existing
## TWILIGHT thresholds and rates stay. With it the stages and rates are
## compared with the rows, then in actual Main: monster-death EXP/Adena per
## stage, blessing spent per kill with and without the card-deck
## EinasadSavingPercent, item charge (드래곤의 다이아몬드 #549, 드래곤의 비약
## #344191) below/at level 85, the HUD state and save -> reload.
const RULES = preload("res://scripts/einasad/einasad523_rules.gd")
const EFFECTS = preload("res://scripts/loot/source523_item_effects.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("EINASAD523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func fallback() -> void:
	var ain := TwilightAinhasadService.new()
	if not SOURCE.not_installed(): return
	RULES.reset_cache()
	check(not RULES.available() and RULES.stage_for_points(10)==-1 and RULES.max_points()==-1, "without the archive the original rules are not available")
	ain.blessing = 0; check(ain.stage()==0 and is_equal_approx(ain.experience_rate(),1.0) and not ain.protected_drops(), "fallback stage 0")
	ain.blessing = 200; check(ain.stage()==1 and is_equal_approx(ain.experience_rate(),4.0) and is_equal_approx(ain.adena_rate(),1.5), "fallback stage 1")
	ain.blessing = 201; check(ain.stage()==2 and is_equal_approx(ain.experience_rate(),7.0) and is_equal_approx(ain.adena_rate(),2.0), "fallback stage 2")
	check(TwilightAinhasadService.charge_cap()==TwilightAinhasadService.MAX_BLESSING, "fallback charge cap is the existing maximum")

func table() -> void:
	RULES.reset_cache()
	var data: Dictionary = RULES.definition()
	if not check(data.get("ok",false), "original Einasad rows validate: "+str(data.get("problem",""))): return
	var unit: int = int(SOURCE.rows_matching("EinasadVariable","EinasadVariableTypeID",{42:true})[0].Value)
	check(int(data.unit)==unit and unit==6000, "bless unit is EinasadVariable #42")
	var levels: Dictionary = {}
	for row: Dictionary in SOURCE.rows("EinasadLevel"): levels[str(row.Name)] = int(row.CumulativeValue)
	check(int(data.max_points)==int(levels.Level2)/unit and int(data.max_points)==99999, "top ordinary stage = EinasadLevel2 / unit")
	var stages: Dictionary = {}
	for points: int in [0,1,int(levels.Level1)/unit,int(levels.Level1)/unit+1,99999,150000]: stages[points] = RULES.stage_for_points(points)
	evidence["stage_by_points"] = stages
	check(stages[0]==0 and stages[1]==1 and stages[200]==1 and stages[201]==2 and stages[99999]==2 and stages[150000]==2, "0 / 1..200 / 201..99999 stages from EinasadLevel CumulativeValue")
	var benefits: Dictionary = {}
	for row: Dictionary in SOURCE.rows("EinasadBenefit"):
		if int(row.EinasadBenefitTypeID)==2: benefits["exp:%d"%int(row.Level)] = int(row.Value)
		if int(row.EinasadBenefitTypeID)==12: benefits["adena:%d"%int(row.Level)] = int(row.Value)
	var rates: Dictionary = {}
	for level: int in range(0,5):
		rates[level] = [RULES.experience_multiplier(level),RULES.adena_multiplier(level),str(RULES.benefit(level).get("get_item_text",""))]
		check(is_equal_approx(rates[level][0],1.0+benefits["exp:%d"%level]/100.0) and is_equal_approx(rates[level][1],1.0+benefits["adena:%d"%level]/100.0), "stage %d rates are the EinasadBenefit rows" % level)
	evidence["rates_by_stage"] = rates
	check(is_equal_approx(rates[1][0],4.0) and is_equal_approx(rates[2][0],7.0) and is_equal_approx(rates[3][0],10.0) and is_equal_approx(rates[3][1],2.0), "1~200 x4, 201+ x7, SpecialBless x10/x2 (its buff text: 경험치 1000% / 아데나 200%)")
	var special: String = str(SOURCE.row("DescData_Korean",int(SOURCE.row("BuffClass",59142).get("EffectDescID",0))).get("Description",""))
	check(special.contains("1000%") and special.contains("200%"), "SpecialBless buff description confirms the per-100 percent unit")
	check(str(rates[0][2]).contains("거래 불가") and str(rates[1][2]).contains("모든"), "GetItem stage 0 = untradable equipment only, stage 1+ = all")
	check(RULES.first_rate_level(12)==85, "item charge-bonus group 12 starts at level 85")
	var g31: Dictionary = RULES.consume_rate_group(31)
	check(g31.size()==110 and int(g31[1])==700 and int(g31[80])==1550 and int(g31[110])==9050, "LevelEinasadBlessRecharge group 31: 110 levels")
	evidence["level_recharge_group31"] = {"1":g31[1],"60":g31[60],"80":g31[80],"84":g31[84]}

func live_actor(world: Node) -> TwilightMonster:
	for candidate: Node in world.monsters_root.get_children():
		if candidate is TwilightMonster and not candidate.dead and is_instance_valid(candidate): return candidate
	return null

func kill(world: Node, actor: TwilightMonster, exp_reward: int) -> Dictionary:
	actor.set_physics_process(false)
	actor.exp_reward = exp_reward; actor.gold_reward = 1000; actor.drop_items = []
	var xp: int = world.experience; var gold: int = world.gold; var bless: int = world.ain_service.blessing
	var rate: float = world.ain_service.experience_rate()
	actor.dead = true; world._on_monster_died(actor)
	var result: Dictionary = {"monster":str(actor.monster_name),"blessing_before":bless,"blessing_after":world.ain_service.blessing,"spent":bless-world.ain_service.blessing,"exp":world.experience-xp,"adena":world.gold-gold,"exp_rate":rate,"stage":world.ain_service.stage()}
	return result

func pick_doll(world: Node) -> Dictionary:
	for record: Dictionary in world.catalog_db.get("마법인형",[]):
		var original: Variant = record.get("source_original_card")
		if record.get("source_snapshot","")!="patch523" or not original is Dictionary: continue
		if int(original.get("BuffCardDeckID",0))!=2 or int(original.get("GradeID",0))!=5: continue
		var identity: String = Cards.card_id(record)
		world.card_draw_fusion.owned["마법인형"][identity] = true
		if world._patch523_card_available("마법인형",record): return record
		world.card_draw_fusion.owned["마법인형"].erase(identity)
	return {}

func use_plain(world: Node, class_id: int) -> Dictionary:
	var definition: Dictionary = world.source_item_definition(class_id)
	var record: Dictionary = world.source_item_record(class_id)
	if record.is_empty(): return {"missing":true,"status":str(definition.get("native_record_status","")),"excluded":definition.get("excluded",null)}
	var name: String = str(record.get("name",""))
	world.inventory[name] = 3
	world.item_use_cooldowns.clear()
	var before: int = world.ain_service.blessing
	var handled: bool = EFFECTS.try_use_plain(world,name)
	var left: int = int(world.inventory.get(name,0))
	world.inventory.erase(name)
	return {"name":name,"handled":handled,"before":before,"after":world.ain_service.blessing,"count_after":left,"claims":EFFECTS.claims(record)}

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false); world.player.auto_enabled = false
	world._clear_drops()
	# Controlled actors (as symbol_absolute_followup_test): only the rewards
	# matter here, the kill goes through the actual _on_monster_died consumer.
	var actors: Array[TwilightMonster] = []
	for index: int in range(4):
		var actor: TwilightMonster = world.MONSTER_SCENE.instantiate(); world.monsters_root.add_child(actor)
		actor.setup({"name":"축복 검증 %d" % index,"hp":999999,"lv":1,"ac":0,"crit":0},world.player,world,null)
		actor.set_physics_process(false); actor.global_position = world.player.global_position+Vector2(1024,1024)
		actors.append(actor)
	evidence["live_actors"] = actors.size()
	if not check(actors.size()>=4, "four controlled actors"): world.queue_free(); await process_frame; return
	for category: String in Cards.CATEGORIES: world.equipped_catalog[category] = {}
	world._invalidate_equipment_static()
	world.ain_service.dragon_orb_expires_at = 0
	world.level = 50; world.experience = 0; world.exp_need = 1<<50
	# Monster-death EXP / Adena / blessing per stage (exp 420000 = 10 points at the
	# existing TWILIGHT consumption constant).
	var kills: Dictionary = {}
	for blessing: int in [0,150,5000]:
		world.ain_service.blessing = blessing; world.ain_service.spend_remainder = 0.0
		world.rng.seed = 523
		kills[blessing] = kill(world,actors[[0,150,5000].find(blessing)],420000)
	evidence["kills_no_saving"] = kills
	check(kills[0].stage==0 and kills[0].spent==0 and kills[150].stage==1 and kills[5000].stage==2, "kills run at stages 0/1/2")
	check(absf(float(kills[150].exp)/float(kills[0].exp)-RULES.experience_multiplier(1))<0.01 and absf(float(kills[5000].exp)/float(kills[0].exp)-RULES.experience_multiplier(2))<0.01, "kill EXP x4 / x7 of stage 0 (EinasadBenefit Experience)")
	check(absf(float(kills[150].adena)/float(kills[0].adena)-RULES.adena_multiplier(1))<0.01 and absf(float(kills[5000].adena)/float(kills[0].adena)-RULES.adena_multiplier(2))<0.01, "kill Adena x1.5 / x2 of stage 0 (EinasadBenefit Adena)")
	check(kills[150].spent==10 and kills[5000].spent==10, "blessing spent per kill without saving")
	# Card-deck EinasadSavingPercent reaches the consumption.
	var doll: Dictionary = pick_doll(world)
	if check(not doll.is_empty(), "a grade-5 magic doll card exists"):
		world._equip_catalog("마법인형",doll); world.card_deck_bonus._signature = 0; world._invalidate_equipment_static()
		var saving: float = world._blessing_consumption_reduction_percent()
		world.ain_service.blessing = 5000; world.ain_service.spend_remainder = 0.0
		var with_saving: Dictionary = kill(world,actors[3],420000)
		with_saving["saving_pct"] = saving
		evidence["kill_with_card_deck_saving"] = with_saving
		check(saving>0.0 and with_saving.spent==int(floor(10.0*(1.0-saving/100.0))), "card-deck saving lowers blessing spent per kill (%.2f%%)" % saving)
		world.equipped_catalog["마법인형"] = {}; world.card_deck_bonus._signature = 0; world._invalidate_equipment_static()
	# Item charge: below the charge-bonus group's first level and from it.
	var charges: Dictionary = {}
	for level: int in [84,85,89,100]:
		world.ain_service.blessing = 150; world.level = level
		charges["549_lv%d" % level] = use_plain(world,549)
	for level: int in [60,84,89]:
		world.ain_service.blessing = 150; world.level = level
		charges["344191_lv%d" % level] = use_plain(world,344191)
	evidence["item_charges"] = charges
	var bonus: float = 1.0+(world.growth.bonus("blessing_charge:percent")+world.card_collections.bonus("blessing_charge:percent"))/100.0
	# User decision: group 12 Value is an added percent; above its rows the last row.
	var expected_549: Dictionary = {84:100,85:200,89:500,100:500}
	for level: int in expected_549:
		var used: Dictionary = charges["549_lv%d" % level]
		check(not used.has("missing") and used.claims=="ain" and used.after-used.before==int(round(expected_549[level]*bonus)) and used.count_after==2, "#549 at %d charges %d and uses one" % [level,expected_549[level]])
		check(TwilightAinhasadService.charge_amount("드래곤의 다이아몬드",level)==expected_549[level], "name path charge_amount equals the original path at %d" % level)
	check(RULES.charge_bonus_percent(12,100)==RULES.charge_bonus_percent(12,99) and RULES.charge_bonus_percent(12,84)==0, "group 12: 0 below 85, last row above 99")
	var expected_344191: Dictionary = {60:725,84:1950,89:2450*5}
	var e60: Dictionary = charges["344191_lv60"]
	if check(not e60.has("missing") and e60.claims=="ain", "드래곤의 비약 #344191 is claimed as a level charge"):
		for level: int in expected_344191:
			var used: Dictionary = charges["344191_lv%d" % level]
			check(used.after-used.before==int(round(expected_344191[level]*bonus)) and used.count_after==2, "#344191 at %d charges %d" % [level,expected_344191[level]])
	# Cap: EinasadLevel2 / unit.
	world.level = 50; world.ain_service.blessing = 99950
	var capped: Dictionary = use_plain(world,549)
	check(capped.after==99999, "a charge stops at 99999")
	evidence["cap"] = capped
	world.ain_service.blessing = 99999
	var full: Dictionary = use_plain(world,549)
	check(full.after==99999 and full.count_after==3, "full blessing keeps the item")
	# HUD state follows the service.
	world.ain_service.blessing = 150; world._update_ain_hud()
	var hud_state: Variant = world.hud.get("v20_ain_state")
	check(hud_state is Dictionary and int(hud_state.blessing)==150 and is_equal_approx(float(hud_state.exp_rate),RULES.experience_multiplier(1)) and int(hud_state.stage)==1 and bool(hud_state.source_stage.get("source",false)), "HUD state: 150, stage 1, x4")
	world.ain_service.blessing = 201; world._update_ain_hud()
	hud_state = world.hud.get("v20_ain_state")
	check(int(hud_state.blessing)==201 and is_equal_approx(float(hud_state.exp_rate),RULES.experience_multiplier(2)) and int(hud_state.stage)==2, "HUD state: 201, stage 2, x7")
	# The original main-HUD blessing binding reads the same state.
	var source_view: Dictionary = preload("res://scripts/ui/original_ui/source_main_blessing_bindings.gd").source_state(world.hud)
	evidence["original_hud_blessing_state"] = source_view
	check(source_view.get("ok",false) and int(source_view.amount)==201 and str(source_view.get("info",{}).get("exp_text",""))=="%d%%" % int(RULES.experience_multiplier(2)*100.0), "original HUD blessing binding shows 201 / 700%")
	evidence["hud_state_201"] = {"blessing":hud_state.blessing,"stage":hud_state.stage,"exp_rate":hud_state.exp_rate,"adena_rate":hud_state.adena_rate,"charge_cap":hud_state.charge_cap}
	# Save -> reload.
	world.ain_service.blessing = 4321; world.ain_service.spend_remainder = 0.5
	check(world._save_game(true)==OK, "save")
	world.ain_service.blessing = 7
	world._load_game(true)
	evidence["after_reload"] = {"blessing":world.ain_service.blessing,"stage":world.ain_service.stage(),"exp_rate":world.ain_service.experience_rate()}
	check(world.ain_service.blessing>=4321 and world.ain_service.stage()==2, "blessing and stage survive reload")
	check(world.patch523_owner_state_problem.is_empty(), "no owner problem after reload")
	world.queue_free()
	await process_frame

func run() -> void:
	fallback()
	if not SOURCE.not_installed():
		table()
		await runtime()
	print("EINASAD523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
