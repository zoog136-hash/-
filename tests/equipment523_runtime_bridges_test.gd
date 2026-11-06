extends SceneTree
## Focused production consumers with explicit synthetic runtime/source fixtures.
## No Main startup, private source acquisition, activation or artwork claim.
const NPC = preload("res://scripts/monsters/patch523_npc_combat.gd")
const CATALOG = preload("res://scripts/monsters/patch523_npc_catalog.gd")
var checks: int = 0
var failures: Array[String] = []

class ProbeWorld extends TwilightWorld:
	var captured_hit: Dictionary = {}
	func _melee_accuracy_stat() -> int: return 90
	func _ranged_accuracy_stat() -> int: return 60
	func _stun_accuracy_stat() -> int: return 30
	# Capture only the wrapper's outgoing packet. Other tests exercise the real
	# chance/status consumers; this probe does not claim a full incoming hit.
	func _on_player_hit(_actor: TwilightMonster, damage: int, kind: String, by_spell: bool = false, guard_kind: String = "") -> void:
		captured_hit = {"damage":damage,"kind":kind,"by_spell":by_spell,"guard_kind":guard_kind}
		hp -= damage

class StatusTarget extends TwilightMonster:
	# Keep this focused status target out of SceneTree presentation/tween setup.
	func show_status_text(_text: String) -> void: pass

class LegacyStunWorld extends ProbeWorld:
	var landed_hits: Array[Dictionary] = []
	# Exercise the production legacy cast after a confirmed hit. Capture its
	# outgoing damage boundary; damage formulas and presentation are not fixtures
	# for the immunity, resistance and RNG checks below.
	func _melee_hit_chance(_target: TwilightMonster) -> float: return 1.0
	func _roll_melee_hit(_target: TwilightMonster) -> bool: return true
	func _player_critical_rate(_kind: String) -> int: return 0
	func _deal_successful_player_hit(target: TwilightMonster, damage: int, critical: bool = false, kind: String = "", main_target: bool = true, by_spell: bool = false, context: Dictionary = {}, ordinary_attack: bool = false, relic_attack_context: Dictionary = {}) -> void:
		landed_hits.append({"target":target,"damage":damage,"critical":critical})
	func _update_hud() -> void: pass
	func _update_target_hud() -> void: pass

class OpenGround extends RefCounted:
	var data: Dictionary = {}
	func is_safe(_point: Vector2) -> bool: return false
	func walkable(_point: Vector2) -> bool: return true
	func point_clear(_point: Vector2) -> bool: return true
	func line_clear(_a: Vector2, _b: Vector2) -> bool: return true

class LogHUD extends TwilightHUD:
	var messages: Array[String] = []
	func append_log(text: String) -> void: messages.append(text)

class IncomingSpy extends "res://scripts/equipment523/service.gd":
	var observations: Array[Dictionary] = []
	func incoming(_world: Node, kind: String, by_spell: bool = false, attacker_is_pc: bool = false, landed: bool = true) -> bool:
		observations.append({"kind":kind,"by_spell":by_spell,"attacker_is_pc":attacker_is_pc,"landed":landed})
		return false

class MissWorld extends TwilightWorld:
	var rolled_kind: String = ""
	func _monster_accuracy_for_attack_type(_actor: TwilightMonster, _kind: String) -> int: return 50
	func _monster_hit_chance(_actor: TwilightMonster, _kind: String = "melee") -> float: return 0.5
	func _roll_monster_hit(_actor: TwilightMonster, kind: String = "melee") -> bool:
		rolled_kind = kind
		return false
	func _effective_mr() -> int: return 0

class Arena extends Node2D:
	var active_map_id: String = "equipment523-runtime-bridge-fixture"
	var field_map = OpenGround.new()
	var field_population: Node = null
	var combat_flights: Node = null
	var combat_vfx: Node = null
	var patch523_npc_spells: RefCounted = null
	var hp: int = 1000
	var combat_text: Array[String] = []
	func is_player_concealed() -> bool: return false
	func _has_line_of_sight_world(_a: Vector2, _b: Vector2) -> bool: return true
	func show_combat_number(_point: Vector2, text: String, _color: Color, _critical: bool = false) -> void: combat_text.append(text)

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("EQUIPMENT523_RUNTIME_BRIDGES_FAIL: ",label)

func run() -> void:
	_test_accuracy_and_resistance()
	_test_legacy_stun_immunity()
	_test_typed_guard_context()
	_test_authoritative_visibility()
	_test_held_charge()
	_test_miss_guard_observation()
	print("EQUIPMENT523_RUNTIME_BRIDGES_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"scope":"SYNTHETIC_FIXTURES_USING_PRODUCTION_METHODS_AND_SCENES"}))
	quit(0 if failures.is_empty() else 1)

func _test_accuracy_and_resistance() -> void:
	var world = ProbeWorld.new()
	world.level = 30
	world.original_skills = TwilightOriginalSkillService.new()
	world.original_skills.configure(world)
	var target = StatusTarget.new()
	target.life_id = 1
	target.armor_class = -100
	target.monster_level = 30
	target.world_controller = world
	var status = world.original_skills.status
	var base_melee: float = world._melee_hit_chance(target)
	var base_ranged: float = world._ranged_hit_chance(target)
	status.set_modifiers(target,"bridge-avoidance",10,{"ac":12,"dg":8,"er":11})
	check(not is_equal_approx(world._melee_hit_chance(target),base_melee) and not is_equal_approx(world._ranged_hit_chance(target),base_ranged),"live AC and DG/ER modifiers change both actual legacy hit consumers away from clamps")
	for kind: String in ["melee","ranged"]:
		var expected: float = world._normal_attack_hit_chance(target,kind)
		var method: String = "_melee_hit_chance" if kind == "melee" else "_ranged_hit_chance"
		check(is_equal_approx(float(world.call(method,target)),expected),"legacy "+kind+" uses common AC and style-specific avoidance")
	status.remove_modifiers(target,"bridge-avoidance")
	for kind: String in ["melee","ranged"]:
		var method: String = "_melee_hit_chance" if kind == "melee" else "_ranged_hit_chance"
		check(is_equal_approx(float(world.call(method,target)),world._normal_attack_hit_chance(target,kind)),"legacy "+kind+" restores common hit chance after modifier removal")
	target.stun_resistance = 40
	var before: float = world._player_stun_chance(target)
	status.set_modifiers(target,"bridge-stun-axis",10,{"status_resistance_6":-10})
	check(is_equal_approx(world._player_stun_chance(target),world._status_effect_chance(30,30,30,30)),"World stun chance consumes source resistance axis six")
	check(world._player_stun_chance(target) > before,"negative source stun resistance improves actual World chance")
	target.stun_resistance = 100
	var skill: Dictionary = {"id":"bridge-stun","status":"stun","status_chance":1.0,"duration":1.0,"duration_bounds":[],"debuff":{}}
	check(is_equal_approx(status.effective_resistance(target,"stun"),90.0) and status.can_affect(skill,target),"raw resistance100 with live minus10 is eligible")
	var seeded: RandomNumberGenerator = RandomNumberGenerator.new()
	var successful_seed: int = -1
	for seed: int in range(1000):
		seeded.seed = seed
		if seeded.randf() < 0.1:
			successful_seed = seed
			break
	check(successful_seed >= 0,"controlled first draw exists for the unchanged ten-percent status chance")
	if successful_seed >= 0:
		world.rng.seed = successful_seed
		check(status.apply(skill,target,world) and target.is_stunned(),"actual status application uses the same effective resistance as eligibility")
	target.stun_remaining = 0
	target.status_immunities = ["stun"]
	var rng_before: int = world.rng.state
	check(not status.can_affect(skill,target) and not status.apply(skill,target,world) and world.rng.state == rng_before,"explicit stun immunity still rejects before RNG")
	target.status_immunities.clear()
	status.tick(10.1)
	check(is_equal_approx(status.effective_resistance(target,"stun"),100.0) and not status.can_affect(skill,target),"source modifier expiry restores resistance100 eligibility rejection")
	check(is_equal_approx(world._player_stun_chance(target),world._status_effect_chance(30,30,100,30)),"World stun chance restores its existing clamp after expiry")
	target.free()
	world.free()

func _test_legacy_stun_immunity() -> void:
	var world = LegacyStunWorld.new()
	world.level = 30
	world.resolving_combat_action = true
	world.player = TwilightPlayer.new()
	var hud = LogHUD.new()
	world.hud = hud
	world.original_skills = TwilightOriginalSkillService.new()
	world.original_skills.configure(world)
	var target = StatusTarget.new()
	target.world_controller = world
	target.life_id = 1
	target.monster_level = 30
	target.stun_resistance = 40
	var status = world.original_skills.status
	var base_chance: float = world._player_stun_chance(target)
	status.set_modifiers(target,"legacy-source-six",10,{"status_resistance_6":-10})
	var improved_chance: float = world._player_stun_chance(target)
	status.remove_modifiers(target,"legacy-source-six")
	var probe = RandomNumberGenerator.new()
	var boundary_seed: int = -1
	var success_seed: int = -1
	var pre_status_rng: int = 0
	for seed: int in range(1000):
		probe.seed = seed
		probe.randi_range(-4,6) # The production cast's landed damage variation.
		probe.randf() # Its unchanged critical roll, with fixture critical rate 0.
		var before_status: int = probe.state
		var draw: float = probe.randf()
		if success_seed < 0 and draw < base_chance: success_seed = seed
		if boundary_seed < 0 and draw >= base_chance and draw < improved_chance:
			boundary_seed = seed
			pre_status_rng = before_status
		if boundary_seed >= 0 and success_seed >= 0: break
	check(boundary_seed >= 0 and success_seed >= 0,"legacy cast has deterministic normal-success and source-six boundary draws")
	if boundary_seed >= 0 and success_seed >= 0:
		world.mp = 100
		world.rng.seed = success_seed
		check(world._cast_stun_skill(target,55,10,2,"bridge legacy stun") and is_equal_approx(target.stun_remaining,2.0),"actual nonimmune legacy cast still applies its normal stun timer")
		check(world.mp == 90 and world.landed_hits.size() == 1 and int(world.landed_hits[-1].damage) > 0,"normal legacy stun retains MP cost and the landed damage call")
		target.stun_remaining = 0
		world.mp = 100
		world.rng.seed = boundary_seed
		check(not world._cast_stun_skill(target,55,10,2,"bridge legacy stun") and not target.is_stunned(),"actual legacy cast rejects the boundary draw at its original resistance")
		var boundary_damage: int = int(world.landed_hits[-1].damage)
		status.set_modifiers(target,"legacy-source-six",10,{"status_resistance_6":-10})
		world.mp = 100
		world.rng.seed = boundary_seed
		check(world._cast_stun_skill(target,55,10,2,"bridge legacy stun") and target.is_stunned(),"actual legacy cast consumes source-six reduction and succeeds at the same boundary draw")
		target.stun_remaining = 0
		target.status_immunities = ["stun"]
		world.mp = 100
		world.rng.seed = boundary_seed
		var hits_before: int = world.landed_hits.size()
		check(not world._cast_stun_skill(target,55,10,2,"bridge legacy stun") and not target.is_stunned(),"actual legacy cast never stuns an explicitly immune target despite source-six reduction")
		check(world.rng.state == pre_status_rng,"immune legacy cast skips only the stun draw after its existing damage and critical draws")
		check(world.mp == 90 and world.landed_hits.size() == hits_before+1 and int(world.landed_hits[-1].damage) == boundary_damage,"immune legacy cast preserves the same landed damage call and MP debit")
		target.status_immunities.clear()
		status.tick(10.1)
		world.mp = 100
		world.rng.seed = boundary_seed
		check(not world._cast_stun_skill(target,55,10,2,"bridge legacy stun") and not target.is_stunned() and is_equal_approx(world._player_stun_chance(target),base_chance),"source-six expiry restores the actual legacy cast's original rejection at the boundary")
		target.status_immunities = ["stun"]
		target.velocity = Vector2(7,9)
		target.motion.active = true
		target.apply_stun(3)
		check(not target.is_stunned() and target.velocity == Vector2(7,9) and target.motion.active,"direct Monster stun application preserves an immune actor's timer, movement and attack")
		target.status_immunities.clear()
		target.apply_stun(3)
		check(is_equal_approx(target.stun_remaining,3.0) and target.velocity == Vector2.ZERO and not target.motion.active,"direct nonimmune Monster stun still applies its timer and cancels movement and attack")
	var player: TwilightPlayer = world.player
	target.free()
	world.free()
	# This deliberately unmounted player never ran _ready(), which normally
	# adopts its eagerly allocated source preview as a child.
	if is_instance_valid(player.original_source_preview) and player.original_source_preview.get_parent() == null: player.original_source_preview.free()
	player.free()
	hud.free()

func put(catalog: RefCounted, table: String, row: Dictionary) -> void:
	if not catalog.content.tables.has(table): catalog.content.tables[table] = {}
	catalog.content.tables[table][str(int(row.ID))] = {"row":row,"source_row_1based":1}

func _catalog() -> RefCounted:
	var catalog = CATALOG.new()
	# Explicit synthetic admitted registry: the catalog only reads rows from an
	# admitted current523 NPC input, so the fixture declares that shape.
	catalog.content = {"tables":{},"input_kind":"twilight.current523.npc-input.v1"}
	catalog.source_available = true
	for row: Dictionary in [{"ID":1,"Name":"Value"},{"ID":20,"Name":"TrueFalse"},{"ID":10431,"Name":"AttackTypeID"}]: put(catalog,"Unit",row)
	for row: Dictionary in [{"ID":1,"Name":"Melee"},{"ID":2,"Name":"Range"},{"ID":3,"Name":"Magic"}]: put(catalog,"AttackType",row)
	put(catalog,"NpcClass",{"ID":111,"Sprite":222,"TestNPC":false})
	put(catalog,"BonusType",{"ID":101,"Name":"SpellAttackType","UnitID":10431})
	put(catalog,"BonusType",{"ID":102,"Name":"Invisible","UnitID":20})
	put(catalog,"Bonus",{"ID":201,"BonusTypeID":101,"Value":1,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0})
	put(catalog,"Bonus",{"ID":202,"BonusTypeID":102,"Value":1,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0})
	put(catalog,"SpellClass",{"ID":301,"Name":"synthetic typed attack","TestSpell":false,"ElementalTypeID":0})
	put(catalog,"BuffClass",{"ID":401,"Name":"synthetic typed self buff","BuffGroupID":5,"IsGood":true})
	var spell_link: Dictionary = {"ID":501,"SpellClassID":301,"BonusID":201,"MinSpellLevel":0}
	var buff_link: Dictionary = {"ID":502,"BuffClassID":401,"BonusID":202,"CharacterLevel":0,"CharacterClass":0,"MinSpellLevel":0}
	put(catalog,"SpellBonus",spell_link)
	put(catalog,"BuffBonus",buff_link)
	catalog.indexes = {"SpellBonus":{"301":[spell_link]},"BuffBonus":{"401":[buff_link]}}
	return catalog

func _test_typed_guard_context() -> void:
	var service = NPC.new()
	service.catalog = _catalog()
	var spell: Dictionary = service.catalog.row("SpellClass",301)
	for value: int in [1,2,3]:
		service.catalog.content.tables.Bonus["201"].row.Value = value
		var expected: String = {1:"melee",2:"ranged",3:"magic"}[value]
		var fallback: String = "melee" if value == 3 else "magic"
		check(str(service.call("guard_attack_kind",spell,fallback)) == expected,"typed SpellAttackType resolves guard context "+str(value))
	service.catalog.content.tables.Bonus["201"].row.Value = 52
	check(str(service.call("guard_attack_kind",spell,"ranged")) == "ranged","unhandled spell attack value preserves caller fallback")
	service.catalog = _catalog()
	service.catalog.content.tables.BonusType["101"].row.UnitID = 1
	check(str(service.call("guard_attack_kind",spell,"magic")) == "magic","wrong unit namespace cannot classify a physical spell")
	service.catalog = _catalog()
	service.catalog.indexes.SpellBonus["301"][0].MinSpellLevel = 1
	check(str(service.call("guard_attack_kind",spell,"magic")) == "magic","conditional spell level cannot become unconditional guard scope")
	service.catalog = _catalog()
	service.catalog.content.tables.Bonus["201"].row.BonusApplicationTypeID = 10
	check(str(service.call("guard_attack_kind",spell,"magic")) == "magic","conditional source application preserves guard fallback")
	service.catalog = _catalog()
	service.catalog.indexes.SpellBonus["301"] = []
	check(str(service.call("guard_attack_kind",spell,"melee")) == "melee","missing typed attack selector preserves caller fallback")
	service.catalog = _catalog()
	service.catalog.content.tables.Bonus["201"].row.Value = 2
	var world = ProbeWorld.new()
	world.patch523_npc_spells = service
	service.world = world
	var actor = TwilightMonster.new()
	actor.life_id = 1
	actor.world_controller = world
	actor.attack_element = "fire"
	actor.stun_duration = 3
	actor.stun_accuracy = 7
	world.hp = 1000
	check(world.resolve_patch523_npc_hit(actor,27,spell,"magic"),"production source wrapper forwards one captured packet")
	check(world.captured_hit == {"damage":27,"kind":"magic","by_spell":true,"guard_kind":"ranged"},"typed guard context changes without changing existing hit or damage kind")
	check(actor.attack_element == "fire" and actor.stun_duration == 3 and actor.stun_accuracy == 7,"wrapper restores actor element and unrelated status fields")
	actor.free()
	world.free()

func _seed_self_buff(service: RefCounted, world: Node, actor: TwilightMonster) -> void:
	service.catalog = _catalog()
	service.world = world
	service.host_enabled = true
	service.generation = world.combat_generation
	service.extensions._owner = weakref(service)
	service.extensions.enabled = true
	actor.source_m_npc_id = 111
	actor.source_m_original = {"ID":111,"Sprite":222}
	actor.world_controller = world
	actor.life_id = 7
	actor.dead = false
	service.extensions.actor_buffs = {actor.get_instance_id():[{"actor":weakref(actor),"life":7,"generation":world.combat_generation,"source":service.catalog.row("BuffClass",401),"id":401,"remaining":3.0}]}

func _test_authoritative_visibility() -> void:
	var world = ProbeWorld.new()
	world.combat_generation = 42
	var service = NPC.new()
	world.patch523_npc_spells = service
	var actor = TwilightMonster.new()
	_seed_self_buff(service,world,actor)
	check(bool(service.extensions.call("actor_invisible",actor)),"typed live actor self buff is authoritative invisibility")
	check(bool(world.call("equipment523_actor_invisible",actor)) and not world.equipment523_can_detect(actor),"World concealment consumes the authoritative runtime buff without guessed metadata")
	service.extensions.actor_buffs[actor.get_instance_id()][0].remaining = 0
	check(not bool(service.extensions.call("actor_invisible",actor)),"expired self buff cannot conceal before the next tick")
	_seed_self_buff(service,world,actor)
	actor.life_id += 1
	check(not bool(service.extensions.call("actor_invisible",actor)),"pooled actor life does not inherit concealment")
	_seed_self_buff(service,world,actor)
	world.combat_generation += 1
	check(not bool(service.extensions.call("actor_invisible",actor)),"old generation self buff cannot conceal")
	_seed_self_buff(service,world,actor)
	actor.dead = true
	check(not bool(service.extensions.call("actor_invisible",actor)),"dead source actor cannot conceal")
	_seed_self_buff(service,world,actor)
	service.host_enabled = false
	check(not bool(service.extensions.call("actor_invisible",actor)),"catalog-only NPC service cannot activate concealment")
	_seed_self_buff(service,world,actor)
	service.extensions.enabled = false
	check(not bool(service.extensions.call("actor_invisible",actor)),"disabled self-buff execution cannot activate concealment")
	_seed_self_buff(service,world,actor)
	service.extensions.actor_buffs.clear()
	check(not bool(service.extensions.call("actor_invisible",actor)),"missing runtime self buff never infers invisibility")
	_seed_self_buff(service,world,actor)
	service.catalog.content.tables.BonusType["102"].row.UnitID = 1
	check(not bool(service.extensions.call("actor_invisible",actor)),"wrong unit cannot turn Invisible into a true flag")
	_seed_self_buff(service,world,actor)
	service.catalog.content.tables.Bonus["202"].row.Value = 0
	check(not bool(service.extensions.call("actor_invisible",actor)),"explicit false source flag does not conceal")
	for field: String in ["CharacterLevel","CharacterClass","MinSpellLevel"]:
		_seed_self_buff(service,world,actor)
		service.catalog.indexes.BuffBonus["401"][0][field] = 1
		check(not bool(service.extensions.call("actor_invisible",actor)),"unresolved self-buff condition cannot become unconditional: "+field)
	_seed_self_buff(service,world,actor)
	service.catalog.content.tables.Bonus["202"].row.BonusApplicationTargetID = 1
	check(not bool(service.extensions.call("actor_invisible",actor)),"targeted Invisible selector cannot become a blanket source flag")
	_seed_self_buff(service,world,actor)
	service.extensions.enabled = false
	actor.set_meta("source_invisible",true)
	check(bool(world.call("equipment523_actor_invisible",actor)),"existing explicit source metadata remains a separate supported bridge")
	actor.remove_meta("source_invisible")
	actor.free()
	world.free()

func _prepare_charge(monster: TwilightMonster, held: bool) -> void:
	monster.global_position = Vector2.ZERO
	monster.hold_remaining = 2.0 if held else 0.0
	monster.motion.released = true
	monster.released_sequence = 17
	monster.special_sequence = 17
	monster.special_attack = {"skill":{"kind":"charge","radius":160,"multiplier":1.0},"center":Vector2.ZERO,"aim":Vector2.RIGHT}

func _test_held_charge() -> void:
	var arena = Arena.new()
	root.add_child(arena)
	var player: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	arena.add_child(player)
	player.set_physics_process(false)
	player.camera.enabled = false
	player.global_position = Vector2(120,0)
	var monster: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
	arena.add_child(monster)
	monster.set_physics_process(false)
	monster.target_player = player
	monster.world_controller = arena
	monster.life_id = 1
	monster.attack_power = 10
	var hits: Array[int] = [0]
	monster.player_hit.connect(func(_actor: TwilightMonster, _damage: int, _kind: String) -> void: hits[0] += 1)
	_prepare_charge(monster,true)
	monster._resolve_special()
	check(monster.global_position == Vector2.ZERO and hits[0] == 1,"held actual Monster charge keeps its position and still releases the attack")
	monster._resolve_special()
	check(hits[0] == 1,"held charge consumes its released special exactly once")
	_prepare_charge(monster,false)
	monster._resolve_special()
	check(monster.global_position == player.global_position and hits[0] == 2,"unheld actual Monster retains open-ground charge movement and attack")
	arena.free()

func _test_miss_guard_observation() -> void:
	var arena = Arena.new()
	root.add_child(arena)
	var player: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	arena.add_child(player)
	player.set_physics_process(false)
	player.camera.enabled = false
	var world = MissWorld.new()
	world.player = player
	world.field_map = null
	world.original_skills = null
	world.hp = 400
	var hud = LogHUD.new()
	world.hud = hud
	var spy = IncomingSpy.new()
	world.equipment523 = spy
	world.patch523_npc_spells.world = world
	world.patch523_npc_spells.extensions._owner = weakref(world.patch523_npc_spells)
	var actor = TwilightMonster.new()
	actor.world_controller = world
	actor.life_id = 1
	actor.set_meta("is_player_combatant",true)
	world.rng.seed = 523
	var before_rng: int = world.rng.state
	world._on_player_hit(actor,100,"magic",true,"ranged")
	check(spy.observations == [{"kind":"ranged","by_spell":true,"attacker_is_pc":true,"landed":false}],"actual World MISS observes the typed guard context without reporting a landed hit")
	check(world.rolled_kind == "magic" and world.hp == 400,"MISS keeps the established hit kind and applies no damage")
	check(arena.combat_text == ["MISS"] and hud.messages.size() == 1 and hud.messages[0].contains("MISS"),"actual Player and World retain the MISS presentation and log")
	check(world.rng.state == before_rng,"forced MISS adds no downstream guard, critical or status RNG draw")
	actor.free()
	world.free()
	hud.free()
	arena.free()
