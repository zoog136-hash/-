extends SceneTree
## Original 523 equipment effects connected from the tables in actual Main:
## - CarryPlus (unit Weight, UIUnit Denominator 100) -> weightBonus -> carrying
##   capacity (100 items).
## - Base-item weapon InvokeOption rows -> source_invoke_options read by the
##   existing claw / dual blade (_roll_weapon_damage) and rifle bleed
##   (patch523_weapon_bleed) consumers: 42 + 80 + 65 weapons.
## physical grant -> equip -> effect -> save -> reload. Without the original
## definition ZIP only the static rules are checked.
const P = preload("res://scripts/loot/current523_native_item_projection.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const I = preload("res://scripts/loot/current523_weapon_invokes.gd")
const F = preload("res://scripts/loot/current523_native_fields.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const KINDS: Array[String] = ["normal_attack_additional_critical","normal_attack_weapon_scale","normal_attack_source_bleed"]
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEMS523_EQUIP_CARRY_INVOKE_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	check(I.SUPPORTED.get("9:Attack_AddCriticalProbability")=="normal_attack_additional_critical" and I.SUPPORTED.get("6:Attack_WeaponDamageScale")=="normal_attack_weapon_scale" and I.SUPPORTED.size()==2, "only claw critical and dual blade scale types are compiled (plus the exact bleed chain)")
	check(I._on(1.0) and not I._on(0.0) and not I._on(false) and I._on(true), "float table flags compare by value (#411)")

func usable(world: Node, full: Dictionary, record: Dictionary) -> bool:
	return int(full.get("source_level_limit_min",0))<=1 and not record.get("source_delete_time_unresolved",false) and not full.has("source_delete_time_raw") and str(full.get("source_category_name",""))!="FishingRod"

func scan(world: Node) -> Dictionary:
	var carry_items: int = 0; var carry_rows: int = 0; var invokes: Dictionary = {}; var blocked: Dictionary = {}; var picks: Dictionary = {}
	for record: Dictionary in world.catalog_db.get("아이템",[]):
		if record.get("source_m_native_item")!=true or not D.equipment(record): continue
		var full: Dictionary = F.full(record)
		var carried: bool = false
		for applied: Dictionary in full.get("source_mapped_bonuses",[]):
			if applied.get("field")!="weightBonus": continue
			carry_rows += 1; carried = true
		if carried:
			carry_items += 1
			if not picks.has("carry") and usable(world,full,record) and int(record.get("weightBonus",0))>0:
				picks["carry"] = {"id":int(record.source_item_class_id),"value":int(record.weightBonus),"slot":str(record.slot),"classes":full.get("source_class_names",[])}
		var has_invoke: bool = false
		for row: Dictionary in full.get("source_unhandled_bonuses",[]):
			if row.get("bonus_type")=="InvokeOption": has_invoke = true
		if not has_invoke: continue
		for effect: Dictionary in D.item_definition(record).get("source_invoke_options",[]):
			var kind: String = str(effect.get("kind",""))
			if effect.get("activation_status")=="unrestricted":
				if not invokes.has(kind): invokes[kind] = {}
				invokes[kind][int(record.source_item_class_id)] = true
				if not picks.has(kind) and usable(world,full,record):
					picks[kind] = {"id":int(record.source_item_class_id),"probability_raw":int(effect.probability_raw),"scale_raw":int(effect.get("scale_raw",0)),"classes":full.get("source_class_names",[])}
			else:
				for reason: Variant in effect.get("blocked_reasons",[]): blocked[str(reason)] = int(blocked.get(str(reason),0))+1
	var counts: Dictionary = {}
	for kind: String in invokes: counts[kind] = invokes[kind].size()
	evidence["carry_items"] = carry_items; evidence["carry_rows"] = carry_rows
	evidence["invoke_items_by_kind"] = counts; evidence["blocked_invoke_reasons"] = blocked
	check(carry_items==100 and carry_rows==100, "100 original equipment items project CarryPlus (%d items, %d rows)" % [carry_items,carry_rows])
	check(int(counts.get("normal_attack_additional_critical",0))==42 and int(counts.get("normal_attack_weapon_scale",0))==80 and int(counts.get("normal_attack_source_bleed",0))==65, "claw 42 / dual blade 80 / rifle bleed 65 weapons compile (%s)" % JSON.stringify(counts))
	check(int(blocked.get("source_invoke_requires_weapon",0))>0 and int(blocked.get("source_invoke_effect_not_implemented",0))>0, "non-weapon / unimplemented invoke rows stay blocked")
	return picks

func fresh_grant(world: Node, id: int) -> String:
	world.equipped_items.clear(); world._invalidate_equipment_static()
	world.inventory = {}; world.item_instances = {}
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok",false) and world._save_game(true,staged.overrides)==OK, "physical grant of #%d: %s" % [id,str(staged.get("error",""))]): return ""
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	var physical: String = ""
	for key: String in world.item_instances: physical = key
	return physical

func equip(world: Node, physical: String) -> bool:
	world._equip_or_acquire_item(world.item_instances[physical].record,false,physical)
	world._invalidate_equipment_static()
	return world._is_instance_equipped(physical)

func reload(world: Node) -> void:
	world.equipped_items.clear(); world._invalidate_equipment_static()
	world._load_game(true)
	await process_frame
	world._invalidate_equipment_static()

func set_job(world: Node, classes: Array) -> void:
	if not classes.is_empty() and not classes.has(world.job_class): world.job_class = str(classes[0])

func carry(world: Node, pick: Dictionary) -> void:
	set_job(world,pick.classes)
	var physical: String = fresh_grant(world,int(pick.id))
	if physical.is_empty(): return
	var before: int = world._carrying_capacity()
	var equipped: bool = equip(world,physical)
	var after: int = world._carrying_capacity()
	check(equipped and after-before==int(pick.value), "#%d equipped: capacity %d -> %d (+%d)" % [int(pick.id),before,after,int(pick.value)])
	check(world._save_game(true)==OK, "save with #%d equipped" % int(pick.id))
	await reload(world)
	var reloaded: int = world._carrying_capacity()
	check(world._is_instance_equipped(physical) and reloaded==after, "#%d stays equipped after reload, capacity %d" % [int(pick.id),reloaded])
	world.equipped_items.clear(); world._invalidate_equipment_static()
	var removed: int = world._carrying_capacity()
	check(removed==before, "capacity returns to %d without the item (%d)" % [before,removed])
	evidence["carry"] = {"id":pick.id,"slot":pick.slot,"bonus":pick.value,"before":before,"after":after,"reloaded":reloaded}

func weapon_effect(world: Node, kind: String) -> Dictionary:
	for effect: Dictionary in D.item_definition(world._equipped_weapon_record()).get("source_invoke_options",[]):
		if effect.get("kind")==kind and effect.get("activation_status")=="unrestricted": return effect
	return {}

func invoke(world: Node, kind: String, pick: Dictionary) -> void:
	set_job(world,pick.classes)
	var physical: String = fresh_grant(world,int(pick.id))
	if physical.is_empty(): return
	if not check(equip(world,physical), "#%d %s equipped as weapon" % [int(pick.id),kind]): return
	var effect: Dictionary = weapon_effect(world,kind)
	if not check(not effect.is_empty(), "#%d equipped weapon reads its %s" % [int(pick.id),kind]): return
	var result: Dictionary = {"id":pick.id,"probability_pct":float(pick.probability_raw)/10000.0}
	if kind!="normal_attack_source_bleed":
		var rng := RandomNumberGenerator.new(); rng.seed = 523
		var fired: int = 0; var trials: int = 20000; var shape_ok: bool = true
		for index: int in range(trials):
			var outcome: Dictionary = D.weapon_invoke_roll(world._equipped_weapon_record(),4,17,5,"base_flat_enchant",rng)
			if outcome.fired.is_empty():
				shape_ok = shape_ok and int(outcome.damage)==4
				continue
			fired += 1
			# claw: maximum weapon base; dual blade: (roll 4 + extra 5) x (scale - 1) added.
			var expected: int = 17 if kind=="normal_attack_additional_critical" else 4+int(round(9.0*(float(pick.scale_raw)/1000000.0-1.0)))
			shape_ok = shape_ok and int(outcome.damage)==expected
		var rate: float = float(fired)/float(trials)
		var target_rate: float = float(pick.probability_raw)/1000000.0
		check(shape_ok and absf(rate-target_rate)<0.015, "%s fires %.4f vs source %.4f with the existing damage rule" % [kind,rate,target_rate])
		result["observed_rate"] = rate
		if kind=="normal_attack_weapon_scale": result["scale"] = float(pick.scale_raw)/1000000.0
	else:
		check(int(effect.duration_seconds)==3 and int(effect.damage_dice_number)==10 and int(effect.damage_dice_spot_count)==1 and int(effect.source_max_hp_percent)==50, "bleed chain values 3s / 10D1 / MaxHPPercent 50")
		var monster: TwilightMonster = world.MONSTER_SCENE.instantiate()
		world.monsters_root.add_child(monster)
		monster.setup({"name":"출혈 대상","hp":100,"atk":1,"speed":0,"drop":[]},world.player,world,null)
		monster.set_physics_process(false)
		monster.global_position = world.player.global_position
		monster.max_hp = 1000000
		var armed: bool = false; var attempts: int = 0
		for seed_value: int in range(6000):
			monster.hp = 1000000; monster.patch523_weapon_bleed.clear()
			world.rng.seed = seed_value; attempts += 1
			if preload("res://scripts/loot/patch523_weapon_bleed.gd").on_normal_hit(world,monster): armed = true; break
		check(armed and monster.is_bleeding() and float(monster.patch523_weapon_bleed.remaining)==3.0, "rifle normal hit arms the source bleed (attempt %d)" % attempts)
		result["armed_after_attempts"] = attempts
		monster.queue_free()
	check(world._save_game(true)==OK, "save with #%d equipped" % int(pick.id))
	await reload(world)
	check(world._is_instance_equipped(physical) and not weapon_effect(world,kind).is_empty(), "#%d keeps %s after reload" % [int(pick.id),kind])
	evidence[kind] = result

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	var picks: Dictionary = scan(world)
	evidence["picks"] = picks
	if check(picks.has("carry"), "an equipable CarryPlus item"): await carry(world,picks.carry)
	for kind: String in KINDS:
		if check(picks.has(kind), "an equipable weapon for "+kind): await invoke(world,kind,picks[kind])
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed(): await runtime()
	print("ITEMS523_EQUIP_CARRY_INVOKE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
