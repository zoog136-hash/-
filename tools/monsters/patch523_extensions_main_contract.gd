extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const PANEL = preload("res://scripts/ui/patch523_npc_panel.gd")
const COORD = preload("res://scripts/maps/source_coordinates.gd")
class RegionField extends "res://scripts/maps/source_map_runtime_field.gd":
	func _init() -> void: definition = {"source_map_id":53}
var checks: int = 0
var failures: Array[String] = []
var screens: String = ""
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func _init() -> void: call_deferred("run")
func capture(name: String) -> void:
	if screens.is_empty(): return
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(screens.path_join(name)) == OK,"real render "+name)
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-screen-dir="): screens = arg.trim_prefix("--patch523-screen-dir=")
	if not screens.is_empty(): DirAccess.make_dir_recursive_absolute(screens)
	var world = (load("res://Main.tscn") as PackedScene).instantiate(); root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world),"real Main/class selection")
	check(world.field_map != null and not world.map_bootstrap_blocked,"actual source map and renderer")
	world.player.set_physics_process(false); world.field_population.set_process(false)
	var service = world.patch523_npc_spells; service.host_enabled = true; service.tick(0)
	var ext = service.extensions
	var panel: CanvasLayer
	for node: Node in world.get_children():
		if node.get_script() == PANEL: panel = node
	check(panel != null,"actual inspector attached")
	(panel.find_child("BossExt_enabled",true,false) as CheckButton).button_pressed = true
	(panel.find_child("BossExt_environment_enabled",true,false) as CheckButton).button_pressed = true
	(panel.find_child("BossExt_reaction_enabled",true,false) as CheckButton).button_pressed = true
	var restored = ext.get_script().new(); restored.configure(service)
	check(restored.enabled and restored.environment_enabled and restored.reaction_enabled,"extension UI persists independently")
	var actor = world.MONSTER_SCENE.instantiate(); world.monsters_root.add_child(actor)
	actor.setup({"name":"source rule execution fixture","hp":10000,"lv":1,"atk":1},world.player,world,null); actor.hide(); actor.set_physics_process(false); actor.global_position = world.player.global_position+Vector2(24,0)
	actor.source_m_npc_id = 104318; actor.source_m_original = service.catalog.row("NpcClass",104318).duplicate(true)
	actor.magic_accuracy = 1000000
	var field: Variant = world.field_map; var astar: Variant = world.astar
	world.field_map = null; world.astar = AStarGrid2D.new(); world.astar.region = Rect2i(world._world_to_cell(world.player.global_position)-Vector2i(50,50),Vector2i(100,100)); world.astar.update()
	var old_max: int = world.max_hp; var old_hp: int = world.hp
	world.hp = 1
	check(service.try_begin(actor,true,356208),"actual support NPC heal uses ActorMotion")
	actor.motion.advance(.65,Vector2.ZERO)
	check(world.hp > 1 and ext.last_event.get("amount") == 2001,"original2000+1d1 heals; no damage conversion")
	actor.motion.advance(1,Vector2.ZERO); actor.attack_cooldown = 0
	ext.heal_target = 1; actor.hp = 100
	check(service.try_begin(actor,true,356208),"explicit own caster target can cast")
	actor.motion.advance(.65,Vector2.ZERO)
	check(actor.hp == 2101 and service.catalog.row("SpellClass",120988).TargetKindID == 3,"own target selection preserves original Enemy enum")
	actor.motion.advance(1,Vector2.ZERO); actor.attack_cooldown = 0
	actor.source_m_npc_id = 89102; actor.source_m_original = service.catalog.row("NpcClass",89102).duplicate(true)
	check(service.try_begin(actor,true,308222),"actual original self barrier begins ActorMotion")
	actor.motion.advance(.65,Vector2.ZERO)
	check(ext.actor_buffs.has(actor.get_instance_id()) and ext.actor_buffs[actor.get_instance_id()][0].id == 58953,"self barrier stores exact native buff and16-second lifetime")
	check(service.player_buffs.is_empty(),"NPC self buff never leaks onto the player")
	check(not ext.release(actor,service.catalog.row("SpellClass",88672)),"mutually exclusive source group does not invent a replacement priority")
	ext.tick_environment(16.01)
	check(ext.actor_buffs.is_empty(),"source self-buff duration expires independently of physical pixels")
	ext.heal_target = 0
	var silence: Dictionary = service.status_plan(121718); service.apply_player_buff(9,5,silence.buffs[0].values)
	check(world.player.is_silenced() and not service.blocks("CannotCastSkill"),"native spell silence does not create skill mute")
	var mp_before: int = world.mp
	check(not world._cast_magic_attack(actor,26,3) and world.mp == mp_before,"spell denial occurs before MP cost")
	check(world._queue_player_attack(actor,"melee",func() -> void: pass,.4,false,200),"physical skill motion remains allowed under spell-only restriction")
	world.player.cancel_attack(); service.tick(5.01)
	check(not world.player.is_silenced(),"source expiry restores spell channel")
	service.apply_player_buff(111,4,service.buff_values(111))
	var original_inventory: Dictionary = world.inventory.duplicate(true)
	world.inventory["HP 물약"] = 3; world.hp = 1; world.selected_monster = actor
	world.player.global_position += Vector2(20,0)
	var inventory: Dictionary = world.inventory.duplicate(true); var old_position: Vector2 = world.player.global_position
	world._attack(); world._return_to_spawn(); world._use_healing_item("HP 물약",320)
	check(world.pending_attack.is_empty() and world.player.global_position == old_position and world.inventory == inventory,"source attack/teleport/item denial before mutation")
	var drop: Button = world._spawn_ground_drop("HP 물약",world.player.global_position,1)
	check(world.ground_loot.valid_view(drop) and not world._collect_ground_drop(drop) and world.ground_loot.valid_view(drop) and world.inventory == inventory,"source loot denial preserves an actual live world drop and inventory")
	world.ground_loot._remove(str(drop.get_meta("id")))
	world.inventory = original_inventory
	service.clear(); service.host_enabled = true
	check(not world.player.is_silenced() and not world.player.source_523_movement_blocked,"clear restores only source flags")
	service.apply_player_buff(61033,12,service.buff_values(61033))
	check(ext.healing(100,true) == 20,"raw800000 potion decrease consumed exactly")
	check(ext.healing(100,false) == 20,"raw800000 spell heal decrease consumed exactly")
	service.clear(); service.apply_player_buff(61023,12,service.buff_values(61023))
	check(ext.healing(100,false) == 0,"default host policy clamps recovery without rewriting3000000")
	ext.reverse_healing = true; world.hp = 1000; world.apply_patch523_healing(100,false)
	check(world.hp == 800 and service.catalog.scalar("BuffBonus",61023,"HPHealDecreasePercent") == 3000000,"explicit own inverse healing uses existing lethal damage lifecycle")
	service.clear(); service.apply_player_buff(62212,3,service.buff_values(62212)); world.hp = 10000; world.max_hp = 10000
	var before: int = world.hp; service.tick(.99); check(world.hp == before,"own poison interval not early")
	service.tick(.02); check(world.hp == before-2000,"native2000d1 through existing poison damage path")
	service.clear(); service.apply_player_buff(58983,4,service.buff_values(58983)); ext.on_player_event("attacked")
	check(not service.player_buffs.has(58983),"source erase-on-attacked releases phantasm")
	service.apply_player_buff(73001,20,{}); service.apply_player_buff(58713,20,{})
	world.rng.seed = 42
	actor.motion.advance(1,Vector2.ZERO); actor.attack_cooldown = 0
	actor.source_m_npc_id = 104258; actor.source_m_original = service.catalog.row("NpcClass",104258).duplicate(true)
	check(service.try_begin(actor,true,355058),"actual source cancellation begins ActorMotion")
	actor.motion.advance(.65,Vector2.ZERO)
	check(not service.player_buffs.has(73001) and service.player_buffs.has(58713),"cancel removes managed good buff and preserves source cancellation immunity")
	actor.motion.advance(1,Vector2.ZERO); actor.attack_cooldown = 0
	actor.source_m_npc_id = 60303; actor.source_m_original = service.catalog.row("NpcClass",60303).duplicate(true); actor.max_mp = int(actor.source_m_original.MP); actor.mp = 2
	var paid: Dictionary = {}
	for source: Dictionary in service.catalog.owned("NpcAttack",60303):
		if int(source.get("SpellID",0)) == 2811: paid = source
	check(not paid.is_empty() and service.try_begin(actor,true,int(paid.ID)),"original flat MPCost uses existing NPC MP pool")
	actor.motion.advance(.65,Vector2.ZERO)
	check(actor.mp == 0 and not service.release(actor,actor.motion.sequence),"release charges exact MP once; duplicate cannot charge again")
	actor.motion.advance(1,Vector2.ZERO); actor.attack_cooldown = 0
	check(not service.try_begin(actor,true,int(paid.ID)) and actor.mp == 0,"insufficient original NPC MP rejects before cast")
	service.clear(); service.host_enabled = true; world.field_map = field; world.astar = astar; world.hp = old_hp; world.max_hp = old_max
	var mode: OptionButton = panel.find_child("NpcSourceMode",true,false); mode.select(1); mode.item_selected.emit(1)
	panel.selector.select(panel.ids.find(53)); panel.refresh_npc()
	(panel.find_child("BossEnvironmentBind",true,false) as Button).pressed.emit()
	check(ext.own_attribute == 154063 and ext.own_map == world.active_map_id,"actual region UI binds exact selected row to explicit own current-field context")
	check(ext.bindings(actor).size() == 1,"actual current-field radius enters exact selected NPC buff")
	actor.position += Vector2(ext.own_radius+100,0); ext.tick_environment(.3)
	check(ext.bindings(actor).is_empty(),"actual movement out of own region removes buff")
	actor.global_position = ext.own_center+Vector2(24,0); ext.tick_environment(.3)
	check(ext.bindings(actor).size() == 1,"actual reentry reapplies buff")
	ext.own_attribute = 233271
	check(ext.outgoing(actor,100,"melee") == 101 and ext.outgoing(actor,100,"magic") == 100,"selected source melee bonus changes only its real outgoing channel")
	ext.own_attribute = 154063
	var native: RegionField = RegionField.new(); native.coordinates.configure([32700,32700],[200,200])
	world.field_map = native; ext.own_attribute = 0
	actor.global_position = native.coordinates.to_world(Vector2(32818,32853))
	check(ext.bindings(actor).size() == 1,"raw territory inclusive last cell retained using source projection fixture")
	actor.global_position = native.coordinates.to_world(Vector2(32819,32853))
	check(ext.bindings(actor).is_empty(),"adjacent source cell outside original bound rejected")
	native.definition.source_map_id = 54
	check(ext.bindings(actor).is_empty(),"matching numeric coordinates on another Land do not grant buff")
	world.field_map = field; ext.own_attribute = 154063; actor.global_position = ext.own_center+Vector2(24,0)
	var deterministic: int = 0
	for seed_value: int in range(100):
		world.rng.seed = seed_value
		if world.rng.randf() < .2: deterministic = seed_value; break
	world.hp = 1000; world.rng.seed = deterministic
	ext.begin_incoming(actor,100,"melee",false); var actor_before: int = actor.hp; actor.take_damage(100)
	check(actor.hp == actor_before and world.hp == 997 and ext.last_event.get("invoke") == 6343,"one exact source branch yields own3 counter damage and native Param2 reduction")
	ext.begin_incoming(actor,100,"melee",true); world.rng.seed = deterministic; actor.take_damage(100)
	check(ext.last_event.get("invoke") == 6373,"BySpellAttack=true has its own exact branch")
	check(ext.dismiss(actor) and ext.bindings(actor).is_empty(),"own dispel removes cancellable environment binding")
	actor.position += Vector2(ext.own_radius+100,0); ext.tick_environment(.3); actor.global_position = ext.own_center; ext.tick_environment(.3)
	check(ext.bindings(actor).size() == 1,"own dispel lifecycle resets only after exit/reentry")
	var previous_map: String = world.active_map_id; world.active_map_id = "unrelated-current-field"
	check(ext.bindings(actor).is_empty(),"own context cannot leak to another map")
	world.active_map_id = previous_map
	var cfg_path: String = ext.settings_path; var cfg_sha: String = FileAccess.get_sha256(cfg_path)
	ext.settings_path = "user://nonexistent-parent/extensions.cfg"
	var enabled_before: bool = ext.enabled
	ext.actor_buffs[actor.get_instance_id()] = [{"sentinel":"unchanged transient"}]
	check(not panel.update_extension("enabled",not enabled_before) and ext.enabled == enabled_before and FileAccess.get_sha256(cfg_path) == cfg_sha and ext.actor_buffs[actor.get_instance_id()][0].sentinel == "unchanged transient","failed UI setting save rolls live value back and preserves durable config/transient states")
	ext.actor_buffs.clear()
	ext.settings_path = cfg_path
	panel.get_node("BossSkillsButton").pressed.emit(); panel.find_child("BossExtensionsOpen",true,false).pressed.emit()
	await process_frame; await process_frame
	(panel.find_child("BossSkillsScroll",true,false) as ScrollContainer).ensure_control_visible(panel.find_child("BossEnvironmentBind",true,false))
	await capture("boss-environment-settings.png"); panel.panel.hide()
	service.apply_player_buff(9,5,service.buff_values(9))
	check(world._save_game(true) == OK,"actual save with transient status/environment")
	var save_path: String = world.save_path(); var digest: String = FileAccess.get_sha256(save_path); var gold: int = world.gold
	var pack: String = OS.get_environment("TWILIGHT_SOURCE_MAP_PACK"); OS.set_environment("TWILIGHT_SOURCE_MAP_PACK",ProjectSettings.globalize_path("user://absent-extension-pack")); world._load_game(true)
	check(world.source_save_blocked and service.player_buffs.has(9) and FileAccess.get_sha256(save_path) == digest,"rejected load preserves source status and save bytes")
	OS.set_environment("TWILIGHT_SOURCE_MAP_PACK",pack); world._load_game(true)
	check(not world.source_save_blocked and service.player_buffs.is_empty() and ext.actor_buffs.is_empty() and ext.active.is_empty() and not world.player.is_silenced(),"accepted load clears all transient consumers")
	check(world.gold == gold and FileAccess.get_sha256(save_path) == digest,"source integration preserves save bytes/progression")
	world.queue_free(); await process_frame
	print("PATCH523_EXTENSIONS_MAIN_RESULT checks=",checks," failures=",JSON.stringify(failures)," actual_current_field=true; native_region_projection_fixture=true")
	quit(0 if failures.is_empty() else 1)
