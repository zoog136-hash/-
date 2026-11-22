extends SceneTree
## Original 523 BuffCardDeckBonus (deck + grade -> Bonus) and the skill
## awakening stat (BuffCardSkillAwakenStat / BuffCardSkillAwakenStatPerLevel)
## in actual character stats. Without the original definition ZIP only the
## hold runs. With it every table row is resolved against Bonus/BonusType/Unit,
## then in actual Main a grade-5 polymorph, magic doll and holy-stuff card are
## equipped and the stats are compared with and without the deck bonus, an
## awakening level is set, and the save is reloaded.
const CATALOG = preload("res://scripts/cards/current523_card_catalog.gd")
const DECK = preload("res://scripts/cards/card_deck_bonus523.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const COMBAT = preload("res://scripts/cards/native_option_combat.gd")
class ForcedCardProc extends "res://scripts/cards/native_option_combat.gd":
	var weights: Array[int] = []
	func roll(weight: int) -> bool:
		weights.append(weight)
		return true

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

func companion_options() -> void:
	var entries: Dictionary = CATALOG.build().get("catalog",{})
	var found: Dictionary = {}
	for category: String in ["마법인형","성물"]:
		for record: Dictionary in entries.get(category,[]):
			var id: int = int(record.get("source_card_id",0))
			if id in [13763,21518]: found[id]=record
	if not check(found.size()==2,"reported doll and relic resolve from the original archive"): return
	var doll: Dictionary = found[13763]
	var relic: Dictionary = found[21518]
	var doll_lines: Array = doll.get("source_card_display_options",[])
	var relic_lines: Array = relic.get("source_card_display_options",[])
	check(doll_lines.size()==6 and doll_lines.any(func(line: Dictionary) -> bool: return line.label.contains("파푸리온") and line.value=="3%"),"Papurion displays all six tooltip rows, including its named proc")
	check(relic_lines.size()==5 and relic_lines.any(func(line: Dictionary) -> bool: return line.label.contains("스킬 레벨") and line.value=="+1") and relic_lines.any(func(line: Dictionary) -> bool: return line.label.contains("섬광") and line.value=="1%"),"Ainhasad's Avatar displays all five rows including the skill modifier and proc")
	check(float(doll.get("blessing_consumption_reduction_pct",0))==22.0 and float(doll.get("pve_damage_reduction_pct",0))==3.0 and float(doll.get("stun_accuracy",0))==15.0 and float(doll.get("stun_resistance",0))==10.0 and float(doll.get("fear_resistance",0))==7.0,"Papurion options feed the existing equipped-stat keys")
	check(is_equal_approx(float(relic.get("hpPct",0)),0.1) and float(relic.get("stun_resistance",0))==5.0 and float(relic.get("fear_resistance",0))==5.0,"Ainhasad's Avatar projects HP and resistances in their runtime units")
	evidence["reported_card_options"]={"papurion":doll_lines,"ainhasad_avatar":relic_lines}

func full_deck_options() -> void:
	var catalog: Dictionary = CATALOG.build().get("catalog",{})
	var ids: Dictionary = {}
	var totals: Dictionary = {}
	for category: String in catalog:
		var compiled_rows: int = 0
		var displayed: int = 0
		for record: Dictionary in catalog[category]:
			ids[int(record.source_card_id)]=record
			compiled_rows+=record.get("source_stat_application",[]).size()
			displayed+=record.get("source_card_display_options",[]).size()
		totals[category]={"cards":catalog[category].size(),"display_rows":displayed,"direct_stat_rows":compiled_rows}
		check(displayed>200 and compiled_rows>150,"each playable deck compiles original display and gameplay options: "+category)
	evidence["deck_base_option_coverage"]=totals
	check(ids.size()==720,"all 720 base cards across the three pinned source decks resolve")
	check(float(ids.get(122,{}).get("attackSpeed",0.0))==13.0,"legendary transformation base attack speed is 130000 / 10000")
	check(float(ids.get(4,{}).get("speedBonusPct",0.0))==11.0,"Black Wizard base movement modifier is 11 percentage points")
	check(float(ids.get(25,{}).get("weightBonus",0.0))==200.0 and float(ids.get(51,{}).get("equipment523_regen_mp",0.0))==12.0,"doll weight and regeneration respect the source unit")
	var spells: Dictionary = ids.get(11642,{}).get("source_card_spell_options",{})
	check(spells.get(77761,{}).get("damage")==2.0 and spells.get(120712,{}).get("damage")==2.0 and not spells.has(17564),"transformation spell damage is isolated to the exact two source spell IDs")
	check(ids.get(11482,{}).get("source_card_spell_options",{}).get(29152,{}).get("hit")==3.0,"Thunder Grab gets three hit percentage points from its declared card row")
	check(ids.get(13763,{}).get("stun_resistance")==10.0 and ids.get(21518,{}).get("source_card_base_invokes",[]).size()==1,"doll resistance and the Avatar's base invoke retain their scope")
	check(float(ids.get(24504,{}).get("source_card_immune_dark",0.0))==1.0,"Halphas has the explicit Dark immunity flag")
	check(is_equal_approx(float(ids.get(21518,{}).get("hpPct",0.0)),0.1),"relic HP uses a fractional host multiplier")
	var base_effect: Dictionary = ids[21518].source_card_base_invokes[0]
	var card: Dictionary = ids[21518].source_original_card
	var awakened_effect: Dictionary = {"bonus":{"ID":-1}}
	var definition: Dictionary = {"native_source":{"card":card,"effects":[awakened_effect]}}
	var active: Dictionary = {"example":definition}
	COMBAT._append_base_invokes(active,"example",card,[base_effect,base_effect])
	check(definition.native_source.effects==[awakened_effect] and active.example.native_source.effects==[awakened_effect,base_effect],"joining a base invoke retains the original awakening rows and deduplicates the base ID")

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

func primary_relic_spell(world: Node) -> void:
	var avatar: Dictionary = {}
	for record: Dictionary in world.catalog_db.get("성물",[]):
		if int(record.get("source_card_id",0))==21518:
			avatar=record
			break
	if not check(not avatar.is_empty(),"base Avatar is in the live catalog"):return
	var identity: String = Cards.card_id(avatar)
	var was_owned: bool = world.card_draw_fusion.owned["성물"].get(identity,false)
	var equipped: Dictionary = world.equipped_catalog.get("성물",{})
	world.card_draw_fusion.owned["성물"][identity]=true
	world.equipped_catalog["성물"]=avatar
	world._invalidate_equipment_static()
	var combat := ForcedCardProc.new()
	combat.configure(world.option_awakening)
	var monster: TwilightMonster=load("res://scenes/Monster.tscn").instantiate()
	root.add_child(monster)
	monster.set_physics_process(false)
	monster.hp=10000
	monster.magic_resistance=0
	check(combat.active().has(identity),"primary Avatar invokes without awakening")
	combat.on_hit(monster,"melee",false,false)
	check(monster.hp==10000 and combat.weights.is_empty(),"main-target condition prevents a secondary-target roll")
	var chance: float = world.original_skills.hit_chance({"attack_type":"magic"},monster)
	var rng_before: int = world.rng.state
	var probe:=RandomNumberGenerator.new()
	for n: int in range(1,100):
		probe.seed=n
		if probe.randf()<chance:
			world.rng.seed=n
			break
	combat.on_hit(monster)
	check(combat.fired==[15128] and monster.hp<10000 and combat.weights==[10000],"the 1% Flash row reaches the actual spell damage owner")
	combat.on_hit(monster)
	check(int(SOURCE.row("SpellClass",86578).CastDelay)==0 and combat.weights==[10000,10000],"Flash has zero CastDelay and retries the next eligible hit")
	world.skill_cooldowns.erase("native_option|"+identity+"|86578")
	world.rng.state=rng_before
	world.equipped_catalog["성물"]=equipped
	if not was_owned:world.card_draw_fusion.owned["성물"].erase(identity)
	world._invalidate_equipment_static()
	check(not combat.active().has(identity) or Cards.card_id(equipped)==identity,"unequipping disables the base proc")
	primary_doll_recovery(world,monster)
	primary_relic_darkness(world,monster)
	primary_doll_antaras_hold(world,monster)
	monster.free()

func primary_relic_darkness(world: Node,monster: TwilightMonster) -> void:
	var relic: Dictionary = {}
	for record: Dictionary in world.catalog_db.get("성물",[]):
		if int(record.get("source_card_id",0))==21528:
			relic=record
			break
	if not check(not relic.is_empty(),"Gran Kain's Avatar is in the live catalog"):return
	var identity: String=Cards.card_id(relic)
	var key: String="native_option|"+identity+"|86588"
	var original_context: Dictionary=world.card_collections.source_server_context()
	var region: Dictionary=SOURCE.related("ServerLimit","ServerLimitSetID",int(relic.source_original_card.ServerLimitSetID))[0]
	world.card_collections.set_source_server_context({"source_snapshot":"base508","ServiceRegionCode":str(region.ServiceRegionCode),"WorldNo":int(region.WorldNo)})
	var owned: Dictionary=world.card_draw_fusion.owned["성물"]
	var was_owned: bool=owned.get(identity,false)
	var equipped: Dictionary=world.equipped_catalog.get("성물",{})
	var rng_before: int=world.rng.state
	owned[identity]=true
	world.equipped_catalog["성물"]=relic
	world._invalidate_equipment_static()
	var combat:=ForcedCardProc.new()
	combat.configure(world.option_awakening)
	combat.on_hit(monster,"melee",false)
	check(combat.weights.is_empty(),"Darkness checks the source main-target condition")
	monster.status_immunities.append("dark")
	combat.on_hit(monster)
	check(combat.weights.is_empty() and not monster.source_option_cannot_see(),"Dark immunity blocks the status")
	monster.status_immunities.erase("dark")
	var base_speed: float=monster.source_523_speed_factor()
	monster.velocity=Vector2.RIGHT*40.0
	combat.on_hit(monster)
	var duration: float=monster.source_option_debuffs.get(identity,{}).get("remaining",0.0)
	check(combat.fired==[15138] and combat.weights==[10000] and duration>=4.0 and duration<=6.0,"original 1% trigger and 4–6 second status")
	check(monster.source_option_cannot_see() and monster.velocity==Vector2.ZERO and is_equal_approx(monster.source_523_speed_factor(),base_speed*0.4),"Darkness blocks sight, stops pursuit and reduces movement by 60%")
	combat.on_hit(monster)
	check(combat.weights==[10000] and world.skill_cooldowns.get(key,0.0)==3.0,"source cast delay blocks another roll")
	monster.advance_source_option_debuffs(duration+0.1)
	check(not monster.source_option_cannot_see() and is_equal_approx(monster.source_523_speed_factor(),base_speed),"expiry restores sight and movement")
	world.skill_cooldowns.erase(key)
	combat.on_hit(monster)
	check(monster.source_option_cannot_see(),"a later valid hit can apply the status again")
	world.equipped_catalog["성물"]=equipped
	combat.tick(0.0)
	check(not monster.source_option_cannot_see() and is_equal_approx(monster.source_523_speed_factor(),base_speed),"unequip prunes both effects from the target")
	world.equipped_catalog["성물"]=relic
	world.skill_cooldowns.erase(key)
	combat.on_hit(monster)
	check(monster.source_option_cannot_see(),"re-equipping restores the source trigger")
	monster.retire_for_pool()
	check(not monster.source_option_cannot_see() and is_equal_approx(monster.source_523_speed_factor(),1.0),"a pooled monster keeps no darkness or slowdown from its last life")
	world.equipped_catalog["성물"]=equipped
	if not was_owned:owned.erase(identity)
	world.skill_cooldowns.erase(key)
	world.rng.state=rng_before
	world.card_collections.set_source_server_context(original_context)
	world._invalidate_equipment_static()

func primary_doll_antaras_hold(world: Node,monster: TwilightMonster) -> void:
	var doll: Dictionary={}
	for record: Dictionary in world.catalog_db.get("마법인형",[]):
		if int(record.get("source_card_id",0))==11692:
			doll=record
			break
	if not check(not doll.is_empty(),"Antaras is in the original live catalog"):return
	var identity: String=Cards.card_id(doll)
	var equipped: Dictionary=world.equipped_catalog.get("마법인형",{})
	var owned: Dictionary=world.card_draw_fusion.owned["마법인형"]
	var was_owned: bool=owned.get(identity,false)
	var rng_before: int=world.rng.state
	owned[identity]=true
	world.equipped_catalog["마법인형"]=doll
	world._invalidate_equipment_static()
	var combat:=ForcedCardProc.new()
	combat.configure(world.option_awakening)
	combat.on_hit(monster,"melee",false)
	check(combat.weights.is_empty(),"Antaras checks the main target")
	monster.status_immunities.append("lapidification")
	combat.on_hit(monster)
	check(combat.weights.is_empty() and not monster.source_option_petrified(),"lapidification immunity blocks Antaras")
	monster.status_immunities.erase("lapidification")
	monster.motion.begin_attack(1.0,Vector2.RIGHT,"melee",0.5)
	monster.velocity=Vector2.RIGHT*40.0
	combat.on_hit(monster)
	var duration: float=monster.source_option_debuffs.get(identity,{}).get("remaining",0.0)
	check(combat.fired==[751] and combat.weights==[10000] and duration>=2.0 and duration<=3.0,"Antaras uses the original 1% trigger and 2–3 second duration")
	check(monster.is_stunned() and not monster.motion.active and monster.velocity==Vector2.ZERO,"petrification cancels windup and pauses movement")
	combat.on_hit(monster)
	check(combat.weights==[10000] and monster.source_option_debuffs[identity].remaining==duration,"Antaras cannot refresh a target already protected by petrification")
	monster.advance_source_option_debuffs(duration+0.01)
	check(not monster.source_option_petrified() and not monster.is_stunned(),"expiry restores monster control")
	combat.on_hit(monster)
	check(monster.source_option_petrified(),"a later attack can trigger the effect again")
	world.equipped_catalog["마법인형"]=equipped
	combat.tick(0.0)
	check(not monster.source_option_petrified() and not monster.is_stunned(),"unequip clears the petrification")
	world.equipped_catalog["마법인형"]=doll
	combat.on_hit(monster)
	check(monster.source_option_petrified(),"re-equipping restores the Antaras effect")
	monster.retire_for_pool()
	check(not monster.source_option_petrified() and monster.source_option_debuffs.is_empty(),"a reused monster keeps no petrification")
	world.equipped_catalog["마법인형"]=equipped
	if not was_owned:owned.erase(identity)
	world.rng.state=rng_before
	world._invalidate_equipment_static()

func transformation_area_procs(world: Node) -> void:
	var candidates: Dictionary={}
	for card: Dictionary in world.catalog_db.get("변신",[]):
		if int(card.get("source_card_id",0)) in [18722,24784]:candidates[int(card.source_card_id)]=card
	if not check(candidates.size()==2,"both area invokers exist in the original catalog"):return
	# Keep the real Main combat owners, with an open tile grid so the
	# distance and concealment assertions do not depend on the boot map.
	var original_field: PlayableField=world.field_map
	var original_grid: AStarGrid2D=world.astar
	var original_position: Vector2=world.player.global_position
	world.field_map=null
	world.astar=AStarGrid2D.new()
	world.astar.region=Rect2i(0,0,64,64)
	world.astar.update()
	world.player.global_position=world._cell_to_world(Vector2i(5,5))
	var actors: Array[TwilightMonster]=[]
	for offset: Vector2 in [Vector2.ZERO,Vector2(4,0),Vector2(400,0),Vector2(2,0)]:
		var actor: TwilightMonster=load("res://scenes/Monster.tscn").instantiate()
		world.monsters_root.add_child(actor)
		actor.set_physics_process(false)
		actor.global_position=world.player.global_position+offset
		actor.magic_resistance=0
		actors.append(actor)
	actors[3].concealed523=true
	var equipped: Dictionary=world.equipped_catalog.get("변신",{})
	var original_context: Dictionary=world.card_collections.source_server_context()
	var owned: Dictionary=world.card_draw_fusion.owned["변신"]
	var rng_before: int=world.rng.state
	for row: Array in [[18722,9512,64022,301],[24784,20894,119094,101]]:
		var card: Dictionary=candidates[row[0]]
		var identity: String=Cards.card_id(card)
		var was_owned: bool=owned.get(identity,false)
		var region: Dictionary=SOURCE.related("ServerLimit","ServerLimitSetID",int(card.source_original_card.ServerLimitSetID))[0]
		world.card_collections.set_source_server_context({"source_snapshot":"base508","ServiceRegionCode":str(region.ServiceRegionCode),"WorldNo":int(region.WorldNo)})
		owned[identity]=true
		world.equipped_catalog["변신"]=card
		world._invalidate_equipment_static()
		for actor: TwilightMonster in actors:actor.hp=10000
		var combat:=ForcedCardProc.new()
		combat.configure(world.option_awakening)
		combat.on_hit(actors[0],"melee",false)
		check(combat.weights.is_empty(),"an area spell does not roll for a secondary hit")
		var chance: float=world.original_skills.hit_chance({"attack_type":"magic"},actors[0])
		var probe:=RandomNumberGenerator.new()
		for n: int in range(1,1000):
			probe.seed=n
			if probe.randf()<chance and probe.randf()<chance and probe.randf()<chance:
				world.rng.seed=n
				break
		combat.on_hit(actors[0])
		evidence["area_"+str(row[1])]={"active":combat.active().has(identity),"spell":not (preload("res://scripts/cards/current523_option_combat_input.gd").invoke_spell(str(row[2])) as Dictionary).is_empty(),"fired":combat.fired.duplicate(),"weights":combat.weights.duplicate(),"hp":actors.map(func(actor: TwilightMonster) -> int:return actor.hp),"sight":actors.map(func(actor: TwilightMonster) -> bool:return world._has_line_of_sight_world(world.player.global_position,actor.global_position))}
		check(combat.fired==[row[1]] and combat.weights==[20000],"the 2% area option rolls once for the entire cast "+str(row[1]))
		check(actors[0].hp==10000-row[3] and actors[1].hp==10000-row[3] and actors[2].hp==10000 and actors[3].hp==10000,"typed damage reaches the primary and visible neighbour, never distant or concealed actors "+str(row[1]))
		var key: String="native_option|"+identity+"|"+str(row[2])
		combat.on_hit(actors[0])
		check(combat.weights==[20000] and world.skill_cooldowns.get(key,0.0)==3.0,"area spell observes its source cooldown")
		world.skill_cooldowns.erase(key)
		if not was_owned:owned.erase(identity)
	world.rng.state=rng_before
	world.equipped_catalog["변신"]=equipped
	world.card_collections.set_source_server_context(original_context)
	world._invalidate_equipment_static()
	for actor: TwilightMonster in actors:actor.free()
	world.field_map=original_field
	world.astar=original_grid
	world.player.global_position=original_position

func primary_doll_recovery(world: Node,monster: TwilightMonster) -> void:
	var doll: Dictionary = {}
	for record: Dictionary in world.catalog_db.get("마법인형",[]):
		if int(record.get("source_card_id",0))==13763:
			doll=record
			break
	if not check(not doll.is_empty(),"base Papurion is in the live catalog"):return
	var identity: String = Cards.card_id(doll)
	var was_owned: bool = world.card_draw_fusion.owned["마법인형"].get(identity,false)
	var equipped: Dictionary = world.equipped_catalog.get("마법인형",{})
	world.card_draw_fusion.owned["마법인형"][identity]=true
	world.equipped_catalog["마법인형"]=doll
	world._invalidate_equipment_static()
	var combat := ForcedCardProc.new()
	combat.configure(world.option_awakening)
	var rng_before: int = world.rng.state
	var original_context: Dictionary = world.card_collections.source_server_context()
	world.card_collections.set_source_server_context({})
	check(combat.incoming(monster,"melee",10).heal==0 and combat.weights.is_empty(),"Papurion retains its original server restriction")
	var region: Dictionary = SOURCE.related("ServerLimit","ServerLimitSetID",int(doll.source_original_card.ServerLimitSetID))[0]
	check(world.card_collections.set_source_server_context({"source_snapshot":"base508","ServiceRegionCode":str(region.ServiceRegionCode),"WorldNo":int(region.WorldNo)}),"Papurion uses an explicitly eligible source region and world")
	var ineligible: Dictionary = combat.incoming(monster,"melee",9)
	check(ineligible.heal==0 and combat.weights.is_empty(),"Papurion skips damage below its source threshold")
	var eligible: Dictionary = combat.incoming(monster,"melee",10)
	check(combat.fired==[3323] and combat.weights==[30000] and int(eligible.heal)>=491 and int(eligible.heal)<=510,"Papurion keeps the 3% defense roll and heals the original 490 + 1d20")
	world.skill_cooldowns.erase("native_option|"+identity+"|55653")
	world.rng.state=rng_before
	world.card_collections.set_source_server_context(original_context)
	world.equipped_catalog["마법인형"]=equipped
	if not was_owned:world.card_draw_fusion.owned["마법인형"].erase(identity)
	world._invalidate_equipment_static()

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	check(world.card_deck_bonus.problem.is_empty(), "deck bonus configured from the original archive")
	for category: String in Cards.CATEGORIES: world.equipped_catalog[category] = {}
	primary_relic_spell(world)
	transformation_area_procs(world)
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
	check(is_equal_approx(float(off.attack_speed_pct)-float(base.attack_speed_pct),float(cards["변신"].get("attackSpeed",0.0))),"equipping a transformation applies its base attack speed without the deck bonus")
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
	var baseline: Dictionary = world.skill_awakening.export_state()
	baseline.cards.erase(poly_id)
	check(world.skill_awakening.accept_load({"card_skill_awakening":baseline}), "awakening test starts without progress on the selected card")
	world._invalidate_equipment_static()
	var hp_before: int = world._effective_max_hp()
	var equipped_hp_multiplier: float = 1.0 + world.original_skills.stat("hpPct")
	for record: Dictionary in world._all_equipped_records():
		equipped_hp_multiplier += float(record.get("hpPct",0.0))
	var state: Dictionary = world.skill_awakening.export_state()
	state.cards[poly_id] = {"spell_id":spell,"level":10,"experience":"0"}
	check(world.skill_awakening.accept_load({"card_skill_awakening":state}), "awakening level 10 accepted")
	world._invalidate_equipment_static()
	var hp_after: int = world._effective_max_hp()
	var expected_gain: float = float(profile.hp)*equipped_hp_multiplier
	check(hp_after-hp_before in [floori(expected_gain),ceili(expected_gain)], "max HP applies the level-10 flat awakening HP before equipped percentage and final rounding")
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
		companion_options()
		full_deck_options()
		await runtime()
	print("CARD_DECK_BONUS523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
