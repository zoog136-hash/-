extends SceneTree
const SERVICE = preload("res://scripts/monsters/patch523_npc_combat.gd")
const CATALOG = preload("res://scripts/monsters/patch523_npc_catalog.gd")
var checks: int = 0
var failed: bool = false
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failed = true; push_error(label); quit(1)
class Profile extends RefCounted:
	var motion_style: String = "slash"
	func marker_for(_style: String) -> float: return .5
class Pose extends RefCounted:
	var profile = Profile.new()
	var sequence: int = 0
	var active: bool = false
	var released: bool = false
	var facing8: int = 0
	func cancel_attack() -> void: active = false; released = false
	func begin_attack(_duration: float, _aim: Vector2, _style: String, _marker: float) -> int:
		sequence += 1; active = true; released = false; return sequence
class Player extends Node2D:
	var source_523_movement_blocked: bool = false
class World extends Node:
	var combat_generation: int = 1
	var hp: int = 1000
	var level: int = 1
	var player = Player.new()
	var rng = RandomNumberGenerator.new()
	var hits: int = 0
	var last_kind: String = ""
	func _has_line_of_sight_world(_a: Vector2,_b: Vector2) -> bool: return true
	func _roll_monster_hit(_actor: Node,_kind: String) -> bool: return true
	func _effective_mr() -> int: return 0
	func _status_effect_chance(_a: int,_b: int,_c: int,_d: int) -> float: return 1.0
	func show_combat_number(_point: Vector2,_label: String,_color: Color) -> void: pass
	func resolve_patch523_npc_hit(_actor: Node, raw: int, _spell: Dictionary, kind: String = "magic") -> bool:
		last_kind = kind; hits += 1; hp -= raw; return true
class Actor extends Node2D:
	var source_m_npc_id: int = 111
	var source_m_original: Dictionary = {"ID":111,"Sprite":222}
	var dead: bool = false
	var life_id: int = 1
	var motion = Pose.new()
	var attack_cooldown: float = 0
	var attack_interval: float = 1.25
	var velocity: Vector2
	var visual_height: float = 60
	var magic_accuracy: int = 100
	var monster_level: int = 1
	var enraged: bool = false
	var silenced: bool = false
	var attackable: bool = true
	var returning_home: bool = false
	func is_stunned() -> bool: return false
	func is_feared() -> bool: return false
	func is_silenced() -> bool: return silenced
	func _target_attackable() -> bool: return attackable
	func current_attack_range() -> float: return 280.0
	func current_attack_type() -> String: return "melee"
func put(catalog: RefCounted, table: String, row: Dictionary) -> void:
	if not catalog.content.tables.has(table): catalog.content.tables[table] = {}
	catalog.content.tables[table][str(row.ID)] = {"row":row,"source_row_1based":1}
func fixture() -> RefCounted:
	var c = CATALOG.new(); c.content = {"tables":{}}
	put(c,"NpcClass",{"ID":111,"Sprite":222,"TestNPC":false})
	for unit: Dictionary in [{"ID":1,"Name":"Value"},{"ID":2,"Name":"Seconds"},{"ID":3,"Name":"BuffClassID"},{"ID":4,"Name":"TrueFalse"},{"ID":5,"Name":"SpellClassID"}]: put(c,"Unit",unit)
	for type: Dictionary in [{"ID":1,"Name":"SpellDamageBase","UnitID":1},{"ID":2,"Name":"BuffClassID","UnitID":3},{"ID":3,"Name":"SpellBuffDuration","UnitID":2},{"ID":4,"Name":"CannotUseItem","UnitID":4},{"ID":5,"Name":"CannotCastSpell","UnitID":4},{"ID":6,"Name":"NextSpellClassID","UnitID":5}]: put(c,"BonusType",type)
	for bonus: Dictionary in [{"ID":1,"BonusTypeID":1,"Value":17},{"ID":2,"BonusTypeID":2,"Value":201},{"ID":3,"BonusTypeID":3,"Value":12},{"ID":4,"BonusTypeID":4,"Value":1},{"ID":5,"BonusTypeID":5,"Value":1},{"ID":6,"BonusTypeID":6,"Value":104,"BonusApplicationTypeID":1,"BonusApplicationTargetID":1}]:
		if not bonus.has("BonusApplicationTypeID"): bonus.merge({"BonusApplicationTypeID":0,"BonusApplicationTargetID":0})
		put(c,"Bonus",bonus)
	for spell: Dictionary in [{"ID":100,"Name":"synthetic attack","SpellCategoryID":1,"TargettingTypeID":2,"TargetKindID":3},{"ID":101,"Name":"synthetic item lock","SpellCategoryID":8,"TargettingTypeID":2,"TargetKindID":3},{"ID":102,"Name":"synthetic heal","SpellCategoryID":4,"TargettingTypeID":2,"TargetKindID":3},{"ID":103,"Name":"synthetic box","SpellCategoryID":51,"TargettingTypeID":62,"TargetKindID":3},{"ID":104,"Name":"synthetic followup","SpellCategoryID":51,"TargettingTypeID":4,"TargetKindID":3}]: put(c,"SpellClass",spell)
	put(c,"BuffClass",{"ID":201,"Name":"synthetic item lock","BuffGroupID":9})
	put(c,"BuffClass",{"ID":202,"Name":"synthetic other buff","BuffGroupID":9})
	put(c,"BuffGroup",{"ID":9,"IsAllowOverlap":false,"IsAllowPriority":false})
	c.indexes = {"SpellBonus":{"100":[{"ID":1,"BonusID":1}],"101":[{"ID":2,"BonusID":2},{"ID":3,"BonusID":3}],"103":[{"ID":6,"BonusID":6}]},"BuffBonus":{"201":[{"ID":4,"BonusID":4},{"ID":5,"BonusID":5}]},"NpcAttack":{"111":[{"ID":301,"NpcClassID":111,"IsSpell":true,"SpellID":100}]}}
	return c
func _init() -> void: call_deferred("run")
func run() -> void:
	var service = SERVICE.new(); service.catalog = fixture(); service.host_enabled = true
	var world = World.new(); root.add_child(world); world.add_child(world.player); service.world = world; service.tick(0)
	var actor = Actor.new(); world.add_child(actor)
	check(service.try_begin(actor,true),"host-clock cast begins")
	actor.motion.released = true
	check(service.release(actor,actor.motion.sequence) and world.hits == 1 and world.hp == 983,"one source dice resolution through host")
	check(not service.release(actor,actor.motion.sequence) and world.hits == 1,"duplicate release rejected")
	actor.motion.active = false; actor.attack_cooldown = 0
	check(service.try_begin(actor,true),"second cast")
	var old = actor.motion.sequence; service.cancel(actor,old); actor.motion.released = true
	check(not service.release(actor,old) and world.hits == 1,"cancelled cast cannot hit")
	actor.motion.active = false; actor.attack_cooldown = 0; check(service.try_begin(actor,true),"pool test begins")
	actor.life_id += 1; actor.motion.released = true
	check(service.release(actor,actor.motion.sequence) and world.hits == 1,"pooled life cannot hit")
	actor.motion.active = false; actor.attack_cooldown = 0; check(service.try_begin(actor,true),"pose replacement begins")
	actor.motion = Pose.new(); actor.motion.sequence = 4; actor.motion.active = true; actor.motion.released = true
	check(service.release(actor,4) and world.hits == 1,"replacement pose cannot release old action")
	check(service.support_reason({"IsSpell":true,"SpellID":102}).contains("회복"),"heal is never damage")
	check(not service.supported({"IsSpell":true,"SpellID":103}),"unknown box geometry stays pending")
	var chain: Dictionary = service.catalog.spell_chain(103)
	check(chain.next.size() == 1 and int(chain.next[0].spell.source.ID) == 104,"typed conditional followup retained")
	check(service.catalog.values("SpellBonus",103,"NextSpellClassID").is_empty(),"conditional value not made unconditional")
	var plan: Dictionary = service.status_plan(101)
	check(plan.buffs.size() == 1 and plan.buffs[0].values.has("CannotUseItem") and plan.buffs[0].values.has("CannotCastSpell") and not plan.buffs[0].values.has("CannotCastSkill"),"spell restriction consumed without inventing skill silence")
	check(service.apply_player_buff(201,12,plan.buffs[0].values) and service.blocks("CannotUseItem"),"item restriction stored")
	check(not service.apply_player_buff(202,12,{"CannotUseItem":1}),"nonoverlapping no-priority group not guessed")
	service.tick(13); check(not service.blocks("CannotUseItem"),"expiration restores item use")
	service.apply_player_buff(201,12,plan.buffs[0].values); world.combat_generation += 1; service.tick(0)
	check(service.player_buffs.is_empty(),"map generation clears state")
	service.host_enabled = false; actor.motion.active = false; actor.attack_cooldown = 0
	check(not service.try_begin(actor,true),"catalog-only mode cannot attack")
	check(service.effects.is_empty(),"missing source art produces no synthetic VFX")
	test_followups(service,world,actor)
	if failed: quit(1); return
	print("PATCH523_NPC_COMBAT_OK checks=",checks," synthetic_fixture=true")
	service.clear(); world.free(); quit()

func ready_action(actor: Node) -> void:
	actor.motion.active = false; actor.attack_cooldown = 0

func strike(service: RefCounted, actor: Node) -> bool:
	actor.motion.released = true
	return service.release(actor,actor.motion.sequence)

func test_followups(service: RefCounted, world: Node, actor: Node) -> void:
	service.clear(); service.host_enabled = true; actor.motion = Pose.new(); ready_action(actor)
	var c: RefCounted = service.catalog
	put(c,"SpellClass",{"ID":105,"Name":"synthetic self enemy area","SpellCategoryID":1,"TargettingTypeID":1,"TargetKindID":3,"TargetAreaRadius":9})
	c.indexes.SpellBonus["105"] = [{"ID":7,"BonusID":1}]
	var source_rows: Array = [{"ID":401,"NpcClassID":111,"IsSpell":true,"SpellID":100,"NextAttack":402},{"ID":402,"NpcClassID":111,"IsSpell":false,"SpellID":0,"DiceBonus":2,"DiceCount":1,"DiceSpots":1,"NextAttack":403},{"ID":403,"NpcClassID":111,"IsSpell":true,"SpellID":105,"NextAttack":0}]
	c.indexes.NpcAttack["111"] = source_rows
	check(c.attack_roots(111).size() == 1 and int(c.attack_roots(111)[0].ID) == 401,"followup child is not an implicit root")
	check(service.try_begin(actor,true),"graph root begins")
	check(strike(service,actor) and int(service.followups[actor.get_instance_id()].attack.ID) == 402,"typed NextAttack queued")
	check(not service.try_begin(actor,true),"followup respects host recovery and cooldown")
	ready_action(actor); actor.silenced = true
	check(service.try_begin(actor,true) and int(service.pending[actor.get_instance_id()].attack.ID) == 402,"silence allows queued physical attack")
	var before: int = world.hp
	check(strike(service,actor) and world.hp == before-3 and world.last_kind == "melee","source basic dice reaches physical host path")
	service.tick(0)
	check(service.followups.is_empty(),"silence discards queued spell without making it physical")
	actor.silenced = false; ready_action(actor)
	check(service.try_begin(actor,true,403) and strike(service,actor),"self enemy damage component uses host reach")
	check(service.followups.is_empty(),"terminal attack has no fabricated followup")
	ready_action(actor); check(not service.try_begin(actor,true,999),"unknown explicit start is not substituted")
	check(service.try_begin(actor,true,401) and strike(service,actor),"life isolation chain begins")
	actor.life_id += 1; service.tick(0)
	check(service.followups.is_empty(),"old-life queued followup discarded")
	ready_action(actor); check(service.try_begin(actor,true,401) and strike(service,actor),"cancel isolation chain begins")
	service.cancel(actor,actor.motion.sequence)
	check(service.followups.is_empty(),"cancel after impact cancels queued continuation")
	ready_action(actor); check(service.try_begin(actor,true,401) and strike(service,actor),"map isolation chain begins")
	world.combat_generation += 1; service.tick(0)
	check(service.followups.is_empty(),"map change discards queued continuation")
	ready_action(actor); check(service.try_begin(actor,true,401) and strike(service,actor),"returning actor chain begins")
	actor.returning_home = true; service.tick(0)
	check(service.followups.is_empty(),"host disengagement clears continuation")
	actor.returning_home = false
	source_rows[1].NextAttack = 401
	ready_action(actor); check(service.try_begin(actor,true,401) and strike(service,actor),"explicit cyclic graph start allowed once")
	ready_action(actor); check(service.try_begin(actor,true) and strike(service,actor),"cycle second node resolves")
	check(service.followups.is_empty() and service.last_event.next_attack_pending.reason == "cycle_or_depth_limit","cycle is bounded rather than invented infinite AI")
	source_rows[1].NextAttack = 999
	ready_action(actor); check(service.try_begin(actor,true,402) and strike(service,actor),"missing target attack resolves once")
	check(service.followups.is_empty() and service.last_event.next_attack_pending.reason == "missing_or_different_npc_attack","missing reference is not spawned or replaced")

	# Only an unconditional typed caster permission may bypass host silence.
	service.clear(); actor.motion = Pose.new(); actor.silenced = true; ready_action(actor)
	put(c,"BonusType",{"ID":7,"Name":"IgnoreCannotCastSpell","UnitID":4})
	put(c,"BonusType",{"ID":8,"Name":"IgnoreCannotCastSkill","UnitID":4})
	put(c,"Bonus",{"ID":8,"BonusTypeID":8,"Value":1,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0})
	c.indexes.SpellBonus["100"].append({"ID":8,"BonusID":8})
	check(not service.try_begin(actor,true,401),"caster skill-ignore does not imply spell-ignore")
	put(c,"Bonus",{"ID":7,"BonusTypeID":7,"Value":1,"BonusApplicationTypeID":1,"BonusApplicationTargetID":1})
	c.indexes.SpellBonus["100"].append({"ID":9,"BonusID":7})
	check(not service.try_begin(actor,true,401),"conditional caster override is not made unconditional")
	c.content.tables.Bonus["7"].row.BonusApplicationTypeID = 0
	c.content.tables.Bonus["7"].row.BonusApplicationTargetID = 0
	check(service.try_begin(actor,true,401) and strike(service,actor),"typed spell-ignore bypasses caster silence for this spell only")
	actor.silenced = false
