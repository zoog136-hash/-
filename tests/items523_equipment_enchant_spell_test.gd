extends SceneTree
## Original 523 enchant-level equipment procs (ItemEnchantBonus InvokeOption):
## - type 1 Attack_Spell whose SpellClass compiles to a profile the existing
##   SkillService executor runs (pure damage dice or pure stat/hold debuff);
## - type 61 Defence_FixedDamageCounterBarrier (existing fixed counter).
## The current 523 equipment model compiles them like the earlier public
## compiler did. Real Main: grant at the source enchant level -> equip -> hit
## -> proc -> save -> reload. Without the original definition ZIP only the
## static rules are checked.
const PROFILES = preload("res://scripts/crafting/current523_equipment_spell_profiles.gd")
const PROJECTION = preload("res://scripts/crafting/patch523_enchantment_projection.gd")
const SPELLS = preload("res://scripts/crafting/patch523_equipment_spells.gd")
const COMBAT = preload("res://scripts/crafting/patch523_equipment_combat.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const F = preload("res://scripts/loot/current523_native_fields.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEMS523_EQUIP_ENCHANT_SPELL_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func option(kind: int, extra: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {"ID":7.0,"InvokeOptionTypeID":float(kind),"AttackTypeID":0.0,"BySpellAttack":false,"Param1":700.0,"Param2":0.0,"Param3":0.0,"Param4":false,"Param5":0.0,"Param6":0.0,
		"MaterialTypeID":0.0,"MaterialAmount":0.0,"IsAmmoAttack":false,"WeaponGroupID":0.0,"ShieldTypeID":0.0,"SuccessedInvokeOptionID":0.0,"TargetKind":0.0,"SiegeTargetKind":0.0}
	row.merge(extra,true)
	return row

func rules() -> void:
	var RP = preload("res://scripts/crafting/patch523_rules_projection.gd")
	check(RP._sorted_ids([8.0,2.0])==[2,8] and RP._sorted_ids([8.0])==RP._ids([{"EquipSlotID":8}],"EquipSlotID"), "table float slot/class IDs bind native equipment to the rules model (#411 type)")
	var p := PROJECTION.new()
	var weight: Dictionary = {"UnitID":3.0}
	check(p._native_invoke(option(61,{"Param1":1000000.0,"Param2":1000000.0,"Param3":700.0,"Param4":true}),weight,{"Value":20000.0})=="defence_fixed_counter", "type 61 counter with float table numbers compiles")
	check(p._native_invoke(option(61,{"Param4":0.0}),weight,{"Value":20000.0})=="", "type 61 needs a boolean Param4")
	check(p._native_invoke(option(61,{"Param5":1.0,"Param4":true}),weight,{"Value":20000.0})=="", "type 61 with an extra parameter stays unconnected")
	check(p._native_invoke(option(61,{"Param4":true}),{"UnitID":1.0},{"Value":20000.0})=="", "non-percentage weight stays unconnected")
	check(p._native_invoke(option(2),weight,{"Value":20000.0})=="", "Defence_Spell stays unconnected")
	check(p._native_invoke(option(1,{"Param2":5.0}),weight,{"Value":20000.0})=="", "Attack_Spell with extra parameters stays unconnected")
	var damage: Dictionary = {"source_spell":{"ID":9.0,"TestSpell":false,"TargettingTypeID":2.0,"TargetKindID":11.0,"TargetAreaRadius":0.0,"ElementalTypeID":1.0,"CastRange":3.0,"MinCastRange":0.0,"CastDelay":1000.0},
		"effects":[{"link":{"SpellClassID":9.0,"MinSpellLevel":0.0},"bonus":{"Value":30.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0},"type":{"Name":"SpellDamageBase","UnitID":1.0}}]}
	for key: String in PROFILES.ZERO_RULES: damage.source_spell[key] = 0.0
	var compiled: Dictionary = PROFILES.damage_profile(damage)
	check(compiled.get("mode")=="source_dice_magic" and not SPELLS.values(compiled).is_empty(), "pure damage spell compiles to a profile the executor accepts")
	var flagged: Dictionary = damage.duplicate(true)
	flagged.effects.append({"link":{"SpellClassID":9.0,"MinSpellLevel":0.0},"bonus":{"Value":1.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0},"type":{"Name":"FixedMagicDamage","UnitID":20.0}})
	check(PROFILES.damage_profile(flagged).is_empty(), "a partial fixed-damage flag set is refused")
	var drain: Dictionary = damage.duplicate(true)
	drain.effects.append({"link":{"SpellClassID":9.0,"MinSpellLevel":0.0},"bonus":{"Value":10.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0},"type":{"Name":"SpellDrainHP","UnitID":1.0}})
	check(PROFILES.damage_profile(drain).is_empty(), "an effect the executor does not run (SpellDrainHP) refuses the whole spell")

func runtime_kinds(book: Object, id: String) -> Dictionary:
	var out: Dictionary = {}
	var runtime: Dictionary = book.equipment_runtime_of(id)
	for level: Variant in runtime.get("invokes",{}).get("1",{}):
		for effect: Dictionary in runtime.invokes["1"][level]:
			var kind: String = str(effect.get("kind",""))
			if not out.has(kind) or int(level) < int(out[kind].level): out[kind] = {"level":int(level),"effect":effect}
	return out

func usable(world: Node, record: Dictionary) -> bool:
	var full: Dictionary = F.full(record)
	return not full.get("source_delete_time_unresolved",false) and not full.has("source_delete_time_raw") and full.get("source_condition_pending",[]).is_empty() and str(full.get("source_category_name",""))!="FishingRod"

func scan(world: Node) -> Dictionary:
	var book: Object = world.patch523_equipment
	var counts: Dictionary = {}; var picks: Dictionary = {}; var bound: int = 0; var natives: int = 0
	for record: Dictionary in world.catalog_db.get("아이템",[]):
		if record.get("source_m_native_item")!=true or not D.equipment(record): continue
		var id: String = str(int(record.source_item_class_id))
		natives += 1
		if book.has_equipment_runtime(id): bound += 1
		var kinds: Dictionary = runtime_kinds(book,id)
		for kind: String in kinds:
			counts[kind] = int(counts.get(kind,0))+1
			var pick_key: String = kind
			if kind=="attack_source_spell":
				var profile: Dictionary = PROFILES.of(book,int(kinds[kind].effect.option.Param1))
				pick_key = "spell_"+str(profile.get("mode",""))
			if str(record.get("slot",""))!="weapon" and kind=="attack_source_spell": continue
			if not usable(world,record): continue
			if not picks.has(pick_key) or int(kinds[kind].level) < int(picks[pick_key].level):
				picks[pick_key] = {"id":int(id),"level":int(kinds[kind].level),"option_id":int(kinds[kind].effect.option.ID),"spell":int(kinds[kind].effect.option.Param1),"probability":int(kinds[kind].effect.probability),"classes":F.full(record).get("source_class_names",[]),"min_level":int(F.full(record).get("source_level_limit_min",0))}
	evidence["items_by_kind"] = counts
	evidence["equipment_runtime"] = [bound,natives]
	check(natives >= 2900 and bound == natives, "every native equipment item has its original enchant runtime (%d / %d)" % [bound,natives])
	check(int(counts.get("attack_source_spell",0)) >= 600, "about 615 equipment items compile enchant Attack_Spell procs (%d)" % int(counts.get("attack_source_spell",0)))
	check(int(counts.get("defence_fixed_counter",0)) == 2, "2 equipment items compile the fixed counter barrier (%d)" % int(counts.get("defence_fixed_counter",0)))
	return picks

func grant(world: Node, id: int, level: int) -> String:
	world.equipped_items.clear(); world._invalidate_equipment_static()
	world.inventory = {}; world.item_instances = {}
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":level}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_test_level"})
	if not check(staged.get("ok",false) and world._save_game(true,staged.overrides)==OK, "physical grant of #%d +%d: %s" % [id,level,str(staged.get("error",""))]): return ""
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	for key: String in world.item_instances: return key
	return ""

func prepare(world: Node, pick: Dictionary) -> String:
	if not pick.classes.is_empty() and not pick.classes.has(world.job_class): world.job_class = str(pick.classes[0])
	world.level = maxi(int(world.level), maxi(1,int(pick.min_level)))
	var physical: String = grant(world,int(pick.id),int(pick.level))
	if physical.is_empty(): return ""
	world._equip_or_acquire_item(world.item_instances[physical].record,false,physical)
	world._invalidate_equipment_static()
	check(world._is_instance_equipped(physical), "#%d +%d equipped" % [int(pick.id),int(pick.level)])
	return physical

func target(world: Node) -> TwilightMonster:
	var monster: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(monster)
	monster.setup({"name":"발동 대상","hp":100,"atk":1,"speed":0,"drop":[]},world.player,world,null)
	monster.set_physics_process(false)
	monster.global_position = world.player.global_position
	monster.max_hp = 1000000; monster.hp = 1000000
	return monster

func spell_proc(world: Node, key: String, pick: Dictionary) -> void:
	var physical: String = prepare(world,pick)
	if physical.is_empty(): return
	var active: Array = COMBAT.active(world,"attack_source_spell")
	if not check(not active.is_empty(), "#%d reads its enchant Attack_Spell at +%d" % [int(pick.id),int(pick.level)]): return
	var monster: TwilightMonster = target(world)
	var fired: Dictionary = {}; var tries: int = 0
	for seed_value: int in range(40000):
		world.skill_cooldowns.clear(); world.rng.seed = seed_value; tries += 1
		monster.hp = 1000000
		COMBAT.on_hit(world,monster,"melee",true,false)
		if COMBAT.spell_fired.is_empty(): continue
		fired = COMBAT.spell_fired[0].result
		if fired.get("hit",false): break
	var outcome: Dictionary = {"id":pick.id,"level":pick.level,"spell":pick.spell,"probability_pct":float(pick.probability)/10000.0,"tries":tries,"result":fired}
	if key=="spell_source_buff_modifiers":
		check(fired.get("ok",false) and int(fired.get("spell_class_id",0))==int(pick.spell) and fired.has("hit"), "#%d debuff spell #%d executes through SkillService (%s)" % [int(pick.id),int(pick.spell),JSON.stringify(fired)])
	else:
		check(fired.get("ok",false) and int(fired.get("spell_class_id",0))==int(pick.spell) and fired.get("hit",false) and int(fired.get("damage",0))>0 and monster.hp<1000000, "#%d damage spell #%d hits through SkillService (%s)" % [int(pick.id),int(pick.spell),JSON.stringify(fired)])
	monster.queue_free()
	check(world._save_game(true)==OK, "save with #%d equipped" % int(pick.id))
	world.equipped_items.clear(); world._invalidate_equipment_static()
	world._load_game(true)
	await process_frame
	world._invalidate_equipment_static()
	check(world._is_instance_equipped(physical) and not COMBAT.active(world,"attack_source_spell").is_empty(), "#%d keeps its enchant proc after reload" % int(pick.id))
	evidence[key] = outcome

func counter(world: Node, pick: Dictionary) -> void:
	var physical: String = prepare(world,pick)
	if physical.is_empty(): return
	check(not COMBAT.active(world,"defence_fixed_counter").is_empty(), "#%d reads its fixed counter at +%d" % [int(pick.id),int(pick.level)])
	evidence["counter"] = pick

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	var picks: Dictionary = scan(world)
	evidence["picks"] = picks
	for key: String in ["spell_source_dice_magic","spell_source_buff_modifiers"]:
		if check(picks.has(key), "an equipable weapon for "+key): await spell_proc(world,key,picks[key])
	if check(picks.has("defence_fixed_counter"), "an equipable item with the fixed counter"): await counter(world,picks.defence_fixed_counter)
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed(): await runtime()
	print("ITEMS523_EQUIP_ENCHANT_SPELL_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
