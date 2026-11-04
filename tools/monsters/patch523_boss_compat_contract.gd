extends SceneTree
const SERVICE = preload("res://scripts/monsters/patch523_npc_combat.gd")
const FIXTURE = preload("res://tests/patch523_npc_combat_test.gd")
var checks: int = 0
var failures: Array[String] = []
class Helper extends Node2D:
	var monster_name: String = "existing host profile"
	var name_label := Label.new()
	var dead: bool = false
	func _init() -> void: add_child(name_label)
class Population extends Node:
	var owned: Array[Node] = []
	func summon_for(_actor: Node, requested: int = 2) -> Array[Node]:
		var result: Array[Node] = []
		for i: int in range(mini(requested,4-owned.size())):
			var helper := Helper.new(); add_child(helper); helper.set_meta("summoned",true)
			owned.append(helper); result.append(helper)
		return result
	func retire_summoned(helper: Node) -> void:
		owned.erase(helper); helper.queue_free()
class World extends Node:
	var player := Node2D.new()
	var field_population := Population.new()
	var combat_generation: int = 1
	var hp: int = 100000000
	var level: int = 1
	var rng := RandomNumberGenerator.new()
	var hits: Array[int] = []
	var host_roll: bool = true
	var line_of_sight: bool = true
	func _has_line_of_sight_world(_a: Vector2,_b: Vector2) -> bool: return line_of_sight
	func _roll_monster_hit(_actor: Node,_kind: String) -> bool: return host_roll
	func _effective_mr() -> int: return 0
	func _status_effect_chance(_a: int,_b: int,_c: int,_d: int) -> float: return 1
	func show_combat_number(_point: Vector2,_text: String,_color: Color) -> void: pass
	func resolve_patch523_npc_hit(_actor: Node, raw: int, _spell: Dictionary, _kind: String = "magic") -> bool:
		hits.append(raw); hp -= raw; return true
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func ready_actor(actor: Node) -> void:
	actor.motion.active = false; actor.motion.released = false; actor.attack_cooldown = 0
func strike(service: RefCounted, actor: Node) -> bool:
	actor.motion.released = true; return service.release(actor,actor.motion.sequence)
func _init() -> void: call_deferred("run")
func run() -> void:
	var world := World.new(); root.add_child(world); world.add_child(world.player); world.add_child(world.field_population)
	var service = SERVICE.new(); check(service.configure(world),"actual pinned523 catalog loads")
	service.host_enabled = true; service.tick(0)
	var actor = FIXTURE.Actor.new(); world.add_child(actor)
	actor.source_m_npc_id = 89102; actor.source_m_original = service.catalog.row("NpcClass",89102).duplicate(true)
	var parent: Dictionary = service.catalog.row("SpellClass",88822)
	check(not service.compatibility.handles(parent),"missing-contract mode defaults off")
	service.compatibility.enabled = true
	check(not service.compatibility.handles(parent),"confirmed TestSpell needs separate host-test opt-in")
	service.compatibility.allow_test_definitions = true
	check(service.compatibility.handles(parent) and parent.TestSpell,"opt-in preserves source TestSpell flag")
	check(service.catalog.row("BonusApplicationType",1).Name == "SpellClass","source namespace1 never called on-hit")
	check(service.try_begin(actor,true,308662) and strike(service,actor),"actual source forewarning starts via service")
	check(service.compatibility.waiting.size() == 1 and world.hits.is_empty(),"release queues source followup and warning without fabricated parent damage")
	service.tick(2.99)
	check(float(service.compatibility.waiting[0].remaining) > 0,"3000ms source delay never fires early")
	service.tick(.02); ready_actor(actor); actor.attack_cooldown = 1
	check(not service.try_begin(actor,true) and service.compatibility.waiting.size() == 1,"ready source followup retains host recovery")
	actor.attack_cooldown = 0
	check(service.try_begin(actor,true),"due NextSpell begins actual host motion")
	var child_action: Dictionary = service.pending[actor.get_instance_id()].duplicate()
	check(int(child_action.spell_override.ID) == 88832 and int(child_action.attack.SpellID) == 88822,"child spell does not fabricate a new NpcAttack row")
	check(strike(service,actor) and service.compatibility.zones.size() == 1,"child release creates host ground state")
	check(not strike(service,actor) and service.compatibility.zones.size() == 1,"duplicate child release cannot create another zone")
	check(service.compatibility.zones[0].dice == {"base":400000,"count":10,"spots":10} and is_equal_approx(service.compatibility.zones[0].interval,.1),"confirmed source damage and100ms interval retained")
	service.tick(.099); check(world.hits.is_empty(),"no invented immediate plate hit")
	service.tick(.001)
	check(world.hits.size() == 1 and world.hits[0] >= 400010 and world.hits[0] <= 400100,"source dice reaches one authoritative damage call per tick")
	world.player.position = Vector2(1000,1000); service.tick(.1)
	check(world.hits.size() == 1,"player can leave visible host area")
	world.player.position = Vector2.ZERO; service.tick(.1)
	check(world.hits.size() == 2,"returning to area receives later source tick")
	service.compatibility.release(actor,service.catalog.row("SpellClass",88832),child_action)
	check(service.compatibility.zones.size() == 1,"default same-owner same-spell area replaces prior area")
	service.compatibility.ground_stack = true
	service.compatibility.release(actor,service.catalog.row("SpellClass",88832),child_action)
	check(service.compatibility.zones.size() == 2,"explicit host stacking can coexist within cap")
	service.clear(); service.compatibility.ground_repeat = false
	service.compatibility.release(actor,service.catalog.row("SpellClass",88832),child_action)
	var hits_before: int = world.hits.size(); service.tick(.3)
	check(world.hits.size() == hits_before+1 and service.compatibility.zones.is_empty(),"host single-pulse setting does not repeat")
	service.clear(); ready_actor(actor); world.host_roll = false; service.compatibility.trigger_on_hit = true
	check(service.try_begin(actor,true,308662) and strike(service,actor) and service.compatibility.waiting.is_empty(),"chosen host hit condition can reject followup")
	world.host_roll = true; ready_actor(actor)
	service.try_begin(actor,true,308662); strike(service,actor); service.cancel(actor,actor.motion.sequence)
	check(service.compatibility.waiting.is_empty(),"interruption cancels scheduled source chain")
	ready_actor(actor); service.try_begin(actor,true,308662); strike(service,actor)
	world.combat_generation += 1; service.tick(0)
	check(service.compatibility.waiting.is_empty() and service.compatibility.zones.is_empty(),"map generation clears transient chains and areas")
	ready_actor(actor); service.try_begin(actor,true,308662); strike(service,actor)
	service.tick(3.01); ready_actor(actor); service.try_begin(actor,true)
	world.line_of_sight = false; strike(service,actor)
	check(service.compatibility.waiting.is_empty() and service.compatibility.zones.is_empty() and service.compatibility.markers.is_empty(),"blocked child impact retires warning instead of leaking a marker")
	world.line_of_sight = true
	var action: Dictionary = {"actor":weakref(actor),"owner_id":actor.get_instance_id(),"life":actor.life_id,"motion_id":actor.motion.get_instance_id(),"generation":world.combat_generation,"target":world.player.get_instance_id(),"sequence":actor.motion.sequence,"attack":service.catalog.attack(89102,308662)}
	service.compatibility.summon_count = 4; service.compatibility.summon_seconds = 1
	service.compatibility.release(actor,service.catalog.row("SpellClass",48013),action)
	check(service.compatibility.summons.size() == 4 and world.field_population.owned.size() == 4,"host summon uses existing API count cap")
	service.compatibility.release(actor,service.catalog.row("SpellClass",48013),action)
	check(service.compatibility.summons.size() == 4,"same-owner summon cap prevents unbounded repeat")
	check(world.field_population.owned[0].get_meta("summoned") and int(world.field_population.owned[0].get_meta("patch523_source_set_raw")) == 2053,"no-reward host helper retains raw native set ID separately")
	service.tick(1.01)
	check(service.compatibility.summons.is_empty() and world.field_population.owned.is_empty(),"host summon lifetime retires ownership and actors")
	var cfg: String = "user://boss_rules_contract_%d.cfg" % Time.get_ticks_usec()
	service.compatibility.settings_path = cfg
	check(service.compatibility.save_settings() == OK,"host rules save separately from progression")
	var restored = service.compatibility.get_script().new(); restored.settings_path = cfg; restored.configure(service)
	check(restored.enabled and restored.allow_test_definitions and restored.trigger_on_hit and restored.ground_stack and restored.summon_count == 4,"chosen host rules survive reload")
	DirAccess.remove_absolute(cfg)
	service.clear(); world.free(); await process_frame
	print("PATCH523_BOSS_COMPAT_RESULT checks=",checks," failures=",JSON.stringify(failures)," source_contracts_preserved=true; native_runtime_equivalence=false")
	quit(0 if failures.is_empty() else 1)
