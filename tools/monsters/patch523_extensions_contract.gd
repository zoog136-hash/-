extends SceneTree
const SERVICE = preload("res://scripts/monsters/patch523_npc_combat.gd")
const FIXTURE = preload("res://tests/patch523_npc_combat_test.gd")
const MAIN = preload("res://tools/monsters/patch523_extensions_main_contract.gd")
class Actor extends FIXTURE.Actor:
	var mp: int = 100
class World extends Node:
	var player := Node2D.new()
	var field_map = MAIN.RegionField.new()
	var combat_generation: int = 1
	var active_map_id: String = "source_53"
	var rng := RandomNumberGenerator.new()
	var hp: int = 10000
	var monsters_root := Node2D.new()
	func apply_patch523_secondary_damage(amount: int, _label: String) -> void: hp -= amount
	func _roll_monster_hit(_actor: Node, _kind: String) -> bool: return true
var checks: int = 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func _init() -> void: call_deferred("run")
func run() -> void:
	var world := World.new(); root.add_child(world); world.add_child(world.player); world.add_child(world.monsters_root)
	world.field_map.coordinates.configure([32700,32700],[200,200])
	var service = SERVICE.new(); check(service.configure(world),"pinned original catalog")
	service.host_enabled = true; var ext = service.extensions; ext.enabled = true; ext.environment_enabled = true
	var actor = Actor.new(); world.monsters_root.add_child(actor); actor.source_m_npc_id = 89102; actor.source_m_original = service.catalog.row("NpcClass",89102).duplicate(true)
	actor.global_position = world.field_map.coordinates.to_world(Vector2(32750,32750))
	check(ext.bindings(actor).size() == 1,"only matching source territory grants jail buff")
	check(ext.dismiss(actor) and ext.bindings(actor).is_empty(),"explicit host dispel suppresses matching cancellable binding")
	actor.life_id += 1
	check(ext.bindings(actor).size() == 1,"pooled new life cannot inherit prior suppression")
	ext.tick_environment(.3)
	check(not ext.suppressed.has(actor.get_instance_id()),"pooled suppression is retired from live tracking")
	check(ext.release(actor,service.catalog.row("SpellClass",88652)),"source self buff can be applied")
	actor.life_id += 1
	check(ext.release(actor,service.catalog.row("SpellClass",88672)),"new pooled life cannot inherit conflicting previous-life self buff")
	check(ext.actor_buffs[actor.get_instance_id()].size() == 1 and int(ext.actor_buffs[actor.get_instance_id()][0].id) == 58963,"new life retains only exact new source buff")
	world.combat_generation += 1; ext.tick_environment(.3)
	check(ext.actor_buffs.is_empty(),"generation change expires actor state")
	for source: Dictionary in service.catalog.content.tables.SpellClass.values():
		var spell: Dictionary = source.row
		if int(spell.SpellCategoryID) == 2:
			ext.actor_buffs.clear()
			var expected: Array = service.catalog.values("SpellBonus",int(spell.ID),"BuffClassID","BuffClassID")
			check(ext.handles(spell) and ext.release(actor,spell) and int(ext.actor_buffs[actor.get_instance_id()][0].id) == int(expected[0]) and is_equal_approx(float(ext.actor_buffs[actor.get_instance_id()][0].remaining),16),"all original self buff definitions "+str(spell.ID))
		if int(spell.SpellCategoryID) == 3:
			service.player_buffs.clear(); service.apply_player_buff(73001,20,{}); service.apply_player_buff(58713,20,{})
			var grouped: bool = not service.catalog.values("SpellBonus",int(spell.ID),"SpellBuffGroup").is_empty()
			check(ext.handles(spell) and ext.release(actor,spell) and service.player_buffs.has(58713) and service.player_buffs.has(73001) == grouped,"all original cancellation groups/immunity "+str(spell.ID))
	ext.actor_buffs.clear(); service.player_buffs.clear()
	ext.reaction_enabled = true
	var seed: int = 0
	for n: int in 100:
		world.rng.seed = n
		if world.rng.randf() < .2: seed = n; break
	for pair: Array in [["melee",false,6343],["ranged",false,6353],["magic",false,6363],["melee",true,6373],["ranged",true,6383],["magic",true,6393]]:
		world.rng.seed = seed; var before: int = world.hp
		ext.begin_incoming(actor,100,pair[0],pair[1]); var result: int = ext.before_damage(actor,100,"")
		check(result == 0 and world.hp == before-3 and int(ext.last_event.invoke) == int(pair[2]),"exact attack/spell branch "+str(pair))
	var before: int = world.hp
	check(ext.before_damage(actor,100,"poison") == 100 and world.hp == before,"unclassified periodic damage never fabricates an invoke branch")
	actor.global_position = world.field_map.coordinates.to_world(Vector2(32819,32750))
	ext.begin_incoming(actor,100,"melee",false)
	check(ext.before_damage(actor,100,"") == 100 and world.hp == before,"outside territory no reduction/reflection")
	var cfg: String = "user://extensions_contract.cfg"; ext.settings_path = cfg
	check(ext.save_settings() == OK,"atomic separate settings save")
	var digest: String = FileAccess.get_sha256(cfg)
	var directory: String = "user://extensions_directory"; DirAccess.make_dir_absolute(directory); ext.settings_path = directory
	check(ext.save_settings() != OK and FileAccess.get_sha256(cfg) == digest and not FileAccess.file_exists(directory+".tmp"),"failed atomic rename preserves prior config and cleans temporary file")
	DirAccess.remove_absolute(directory); DirAccess.remove_absolute(cfg)
	service.clear(); world.free(); await process_frame
	print("PATCH523_EXTENSIONS_RESULT checks=",checks," failures=",JSON.stringify(failures)," source_region_and_pool_contract=true")
	quit(0 if failures.is_empty() else 1)
