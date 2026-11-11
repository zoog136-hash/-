extends SceneTree
## Original 523 BuffCardDeckBonus (deck + grade -> Bonus) and the skill
## awakening stat (BuffCardSkillAwakenStat / BuffCardSkillAwakenStatPerLevel)
## in actual character stats. Without the original definition ZIP only the
## hold runs. With it every table row is resolved against Bonus/BonusType/Unit,
## then in actual Main a grade-5 polymorph, magic doll and holy-stuff card are
## equipped and the stats are compared with and without the deck bonus, an
## awakening level is set, and the save is reloaded.
const DECK = preload("res://scripts/cards/card_deck_bonus523.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CARD_DECK_BONUS523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func hold() -> void:
	var runtime = DECK.new()
	var ready: bool = runtime.configure(null)
	if SOURCE.not_installed():
		check(not ready and not runtime.problem.is_empty() and runtime.bonus_records().is_empty() and runtime.catalog_bonus("weightBonus")==0, "without the original archive the deck bonus is held")
	else:
		check(ready and runtime.bonus_records().is_empty(), "without a world nothing is applied")

## Expected amount of one bonus type for deck/grade straight from the rows.
func expected(deck: int, grade: int, type_name: String) -> float:
	var total: float = 0.0
	for raw: Dictionary in SOURCE.rows("BuffCardDeckBonus"):
		if int(raw.BuffCardDeckID)!=deck or int(raw.GradeID)!=grade: continue
		var bonus: Dictionary = SOURCE.row("Bonus",int(raw.BonusID))
		var type: Dictionary = SOURCE.row("BonusType",int(bonus.BonusTypeID))
		if str(type.Name)!=type_name: continue
		var unit: String = str(SOURCE.row("Unit",int(type.UnitID)).Name)
		total += float(bonus.Value)/float(DECK.UNITS.get(unit,1))
	return total

func table() -> void:
	var runtime = DECK.new(); runtime.configure(null)
	var rows: Array[Dictionary] = SOURCE.rows("BuffCardDeckBonus")
	var applied: int = 0
	for key: String in runtime.definitions: applied += (runtime.definitions[key] as Array).size()
	check(rows.size()==68 and applied+runtime.held.size()==68, "all 68 BuffCardDeckBonus rows are applied or held")
	var reasons: Dictionary = {}
	for entry: Dictionary in runtime.held: reasons[str(entry.reason)] = int(reasons.get(str(entry.reason),0))+1
	evidence["rows"] = {"total":rows.size(),"applied":applied,"held":reasons}
	for entry: Dictionary in runtime.held:
		var reason: String = str(entry.reason)
		var ok: bool = reason=="deck_not_connected:31" or (reason=="no_game_consumer:HitRecoverySpeedBonus" and int(entry.bonus.Value)==0)
		check(ok, "a held row is only the test deck 31 or a zero-valued HitRecoverySpeedBonus " + str(entry.row))
	var poly: Array = runtime.effects_for(1,5)
	var values: Dictionary = {}
	for effect: Dictionary in poly: values[str(effect.type_name)] = float(effect.amount)
	check(is_equal_approx(float(values.get("AttackSpeedBonus",-1)),expected(1,5,"AttackSpeedBonus")) and is_equal_approx(float(values.get("MoveSpeedBonus",-1)),expected(1,5,"MoveSpeedBonus")) and is_equal_approx(float(values.get("CastSpeedBonus",-1)),expected(1,5,"CastSpeedBonus")), "grade-5 polymorph deck bonus equals the rows "+str(values))
	evidence["polymorph_grade5"] = values
	check(runtime.effects_for(1,52).is_empty() and runtime.effects_for(2,52).is_empty(), "grade 52 polymorph/doll have no deck bonus rows")

func pick(world: Node, category: String, deck: int, grade: int) -> Dictionary:
	for record: Dictionary in world.catalog_db.get(category,[]):
		var original: Variant = record.get("source_original_card")
		if record.get("source_snapshot","")!="patch523" or not original is Dictionary: continue
		if int(original.get("BuffCardDeckID",0))!=deck or int(original.get("GradeID",0))!=grade: continue
		var identity: String = Cards.card_id(record)
		var was: bool = world.card_draw_fusion.owned[category].get(identity,false)==true
		world.card_draw_fusion.owned[category][identity] = true
		if world._patch523_card_available(category,record) and world.skill_awakening.core.eligibility(identity).ok and not world.skill_awakening.core.candidates(identity).is_empty(): return record
		if not was: world.card_draw_fusion.owned[category].erase(identity)
	return {}

func stats(world: Node) -> Dictionary:
	world._invalidate_equipment_static()
	return {"max_hp":world._effective_max_hp(),"max_mp":world._effective_max_mp(),
		"attack_speed_pct":snappedf(world._effective_attack_speed_bonus_percent(),0.001),
		"move_speed_x":snappedf(world._effective_move_speed_multiplier(),0.0001),
		"exp_x":snappedf(world._experience_multiplier(),0.0001),"carry":world._carrying_capacity(),
		"ain_saving_pct":snappedf(world._blessing_consumption_reduction_percent(),0.001),
		"skill_cooldown_x":snappedf(world._skill_cooldown_factor(),0.0001)}

func with_and_without(world: Node) -> Array:
	world.card_deck_bonus.problem = "test_off"; world.card_deck_bonus._signature = 0
	var off: Dictionary = stats(world)
	world.card_deck_bonus.problem = ""; world.card_deck_bonus._signature = 0
	var on: Dictionary = stats(world)
	return [off,on]

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	check(world.card_deck_bonus.problem.is_empty(), "deck bonus configured from the original archive")
	for category: String in Cards.CATEGORIES: world.equipped_catalog[category] = {}
	var base: Dictionary = stats(world)
	evidence["no_card"] = base
	var cards: Dictionary = {"변신":pick(world,"변신",1,5),"마법인형":pick(world,"마법인형",2,5),"성물":pick(world,"성물",98,5)}
	for category: String in cards:
		var record: Dictionary = cards[category]
		if not check(not record.is_empty(), "a grade-5 "+category+" card exists"): continue
		var identity: String = Cards.card_id(record)
		world.card_draw_fusion.owned[category][identity] = true
		world._equip_catalog(category,record)
		check(Cards.card_id(world.equipped_catalog.get(category,{}))==identity and not world.card_deck_bonus.active_card(category).is_empty(), category+" card is the active card")
	# Not owned: the equipped card gives no deck bonus.
	var poly_id: String = Cards.card_id(cards["변신"])
	world.card_draw_fusion.owned["변신"].erase(poly_id); world.card_deck_bonus._signature = 0
	check(world.card_deck_bonus.active_card("변신").is_empty(), "an equipped card that is not owned gives no deck bonus")
	world.card_draw_fusion.owned["변신"][poly_id] = true; world.card_deck_bonus._signature = 0
	var pair: Array = with_and_without(world)
	var off: Dictionary = pair[0]; var on: Dictionary = pair[1]
	evidence["cards"] = {}
	for category: String in cards: evidence.cards[category] = {"id":Cards.card_id(cards[category]),"name":str(cards[category].get("name",""))}
	evidence["equipped_without_deck_bonus"] = off
	evidence["equipped_with_deck_bonus"] = on
	evidence["deck_bonus_view"] = world.card_deck_bonus.view().decks
	check(is_equal_approx(float(on.attack_speed_pct)-float(off.attack_speed_pct),expected(1,5,"AttackSpeedBonus")), "attack speed rises by the grade-5 polymorph row")
	check(float(on.move_speed_x)>float(off.move_speed_x) and expected(1,5,"MoveSpeedBonus")>0.0, "move speed rises with the polymorph MoveSpeedBonus row (percent points before the existing factors)")
	var xp_rows: float = (expected(2,5,"ExperienceAdditionPercent")+expected(98,5,"ExperienceAdditionPercent"))/100.0
	check(is_equal_approx(snappedf(float(on.exp_x)-float(off.exp_x),0.0001),snappedf(xp_rows,0.0001)), "experience rises by the doll + holy grade-5 rows")
	check(int(on.carry)-int(off.carry)==int(expected(2,5,"CarryPlus")), "carry capacity rises by the doll CarryPlus row")
	check(is_equal_approx(float(on.ain_saving_pct)-float(off.ain_saving_pct),expected(2,5,"EinasadSavingPercent")) or float(on.ain_saving_pct)==100.0, "Ainhasad saving rises by the doll row")
	check(float(on.skill_cooldown_x)<float(off.skill_cooldown_x), "skill cooldown factor drops (holy SpellCastDelayDecrease + polymorph CastSpeed)")
	check(on.max_hp==off.max_hp and on.max_mp==off.max_mp, "HPPlus/MPPlus rows are 0 in the table and change nothing")
	# Skill awakening stat: level 10 HP of the active polymorph.
	var core = world.skill_awakening.core
	var spell: int = int(core.candidates(poly_id)[0].spell_id)
	var profile: Dictionary = core.profile(poly_id,10)
	check(not profile.is_empty() and not profile.stat_set.is_empty(), "awakening profile names its BuffCardSkillAwakenStat set")
	var hp_before: int = world._effective_max_hp()
	var state: Dictionary = world.skill_awakening.export_state()
	state.cards[poly_id] = {"spell_id":spell,"level":10,"experience":"0"}
	check(world.skill_awakening.accept_load({"card_skill_awakening":state}), "awakening level 10 accepted")
	world._invalidate_equipment_static()
	var hp_after: int = world._effective_max_hp()
	check(hp_after-hp_before==int(profile.hp), "max HP rises by the level-10 BuffCardSkillAwakenStatPerLevel HP")
	evidence["skill_awakening"] = {"card":poly_id,"stat_set":profile.get("stat_set",{}),"level":10,"table_hp":int(profile.get("hp",0)),"max_hp_before":hp_before,"max_hp_after":hp_after}
	var profiles: int = 0
	for identity: String in core.cards: if not core.profile(identity,1).is_empty(): profiles += 1
	evidence["awakening_profiles"] = profiles
	check(profiles>0, "awakening profiles still resolve through the stat set")
	# Save and reload.
	var saved: Dictionary = stats(world)
	check(world._save_game(true)==OK, "the state saves")
	for category: String in Cards.CATEGORIES: world.equipped_catalog[category] = {}
	world.skill_awakening.progress = world.skill_awakening.core.fresh_state()
	world._invalidate_equipment_static()
	check(stats(world).attack_speed_pct<saved.attack_speed_pct, "clearing the cards removes the bonus before reload")
	world._load_game(true)
	world.card_deck_bonus._signature = 0
	var reloaded: Dictionary = stats(world)
	evidence["after_reload"] = reloaded
	check(reloaded==saved, "stats after reload equal the saved stats " + str([saved,reloaded]))
	check(world.patch523_owner_state_problem.is_empty(), "no owner problem after reload")
	world.queue_free()
	await process_frame

func run() -> void:
	hold()
	if not SOURCE.not_installed():
		table()
		await runtime()
	print("CARD_DECK_BONUS523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
