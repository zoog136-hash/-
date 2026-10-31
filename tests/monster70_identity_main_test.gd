extends SceneTree
const RUN=preload("res://scripts/maps/source_map_runtime.gd")
const SAFE=preload("res://scripts/maps/source_map_spawns.gd")
const CATALOG=preload("res://scripts/monsters/monster_catalog.gd")
const IDS=["45256", "45360", "45577", "45607", "45608", "45963", "46013", "46014", "45995", "45032", "45898", "45899", "45165"]
const QA=preload("res://tests/qa_class_selection.gd")
var errors:int=0
var checks:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;printerr("HABITAT_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(800,600)
 var payload:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters/local_source_habitats.json"))
 payload.rows=payload.rows.filter(func(r:Dictionary):return str(r.get("source_npc_id","")) in IDS)
 check(payload.rows.size()==13,"exact thirteen resolved identities and habitats")
 var all:Array=CATALOG.expand(JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))["몬스터"])
 var records:Dictionary={};for record:Dictionary in all:records[str(record.name)]=record
 check(all.size()==475 and CATALOG.spawnable_records(all).size()==318,"retained catalog and random pool")
 check(payload.source_placement_sha256==FileAccess.get_sha256("res://data/monsters/source3_map_spawns.json"),"pins current source placements")
 var maps:Dictionary={};var names:Dictionary={};var protected:Array=["aden_world","albino_01","albino_02","escaros_world","faith_01","faith_02","faith_03","faith_04","albino_03","albino_04"]
 for row:Dictionary in payload.rows:
  check(not names.has(str(row.monster_types[0])),"one new habitat per unplaced species");names[str(row.monster_types[0])]=true
  check(records.has(str(row.monster_types[0])) and int(records[str(row.monster_types[0])].lv)==int(row.expected_level),"existing level and identity")
  check(row.local_habitat and row.placement_provenance=="TWILIGHT_USER_AUTHORIZED_GAME_HABITAT_NOT_ORIGINAL_SOURCE_COORDINATE","explicit game design provenance")
  check(row.map_id not in protected and RUN.supports(str(row.map_id)),"protected/deleted maps untouched")
  check((row.mode=="boss" and int(row.max_count)==1 and float(row.respawn_time)>=900) or (row.mode=="normal" and int(row.max_count)<=2),"sparse named and bounded normal density")
  if not maps.has(str(row.map_id)):maps[str(row.map_id)]=[]
  maps[str(row.map_id)].append(row)
 if not "--runtime-only" in OS.get_cmdline_user_args():
  for mid:String in maps:
   var field=RUN.load_field(mid);check(field!=null,"actual source field "+mid)
   if field==null:continue
   var region_ids:Dictionary={}
   for region:Dictionary in field.data.monster_spawn:check(not region_ids.has(str(region.id)),"unique runtime region");region_ids[str(region.id)]=true
   for row:Dictionary in maps[mid]:
    check(region_ids.has(str(row.id)),"actual row installed "+str(row.id))
    for flat:Variant in row.cells:
     var point:Vector2=field.cell_to_world(Vector2i(int(flat)%field.width,int(flat)/field.width))
     check(SAFE.floor_allowed(field,point),"every authored cell clear "+str(row.id))
   field.close();print("HABITAT_GEOMETRY_MAP ",mid," species=",maps[mid].size())
 if "--geometry-only" in OS.get_cmdline_user_args():print("MONSTER70_IDENTITY_GEOMETRY_RESULT checks=",checks," errors=",errors," species=",names.size()," maps=",maps.size());quit(0 if errors==0 else 1);return
 var world:TwilightWorld=load("res://Main.tscn").instantiate();world.active_map_id="source_81";root.add_child(world)
 check(QA.enter_game(world),"real Main class confirmation")
 world.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false);world.save_timer=-100000
 for npc:String in IDS:
  var chosen:Dictionary={}
  for row:Dictionary in payload.rows:
   if str(row.get("source_npc_id",""))==npc:chosen=row;break
  check(not chosen.is_empty(),"normal and named source habitat "+npc)
  if chosen.is_empty():continue
  world._set_map(str(chosen.map_id),false);world.field_population.set_process(false);world.portal_cooldown=100000
  var population:FieldPopulation=world.field_population
  population.slots=population.slots.filter(func(slot:Dictionary):return str(slot.region.id)==str(chosen.id))
  for index:int in range(population.slots.size()):population.slots[index].slot_id=index
  population.pending_initial_spawns=population.pending_initial_spawns.filter(func(slot:Dictionary):return str(slot.region.id)==str(chosen.id))
  population.pending_spawn_ids.clear()
  for pending:Dictionary in population.pending_initial_spawns:population.pending_spawn_ids[int(pending.slot_id)]=true
  check(population.slots.size()==int(chosen.max_count),"production slot count for focused identity")
  var point:Vector2=world.field_map.coordinates.to_world(Vector2(chosen.source_center[0],chosen.source_center[1]))
  check(SAFE.floor_allowed(world.field_map,point),"actual entry target floor")
  world.player.global_position=point;world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
  for i:int in range(60):population._process(.4);await process_frame
  var slot:Dictionary={}
  for candidate:Dictionary in population.slots:
   if str(candidate.region.id)==str(chosen.id):slot=candidate;break
  check(not slot.is_empty() and is_instance_valid(slot.get("monster")),"real authored actor spawned "+npc)
  if slot.is_empty() or not is_instance_valid(slot.get("monster")):continue
  var actor:TwilightMonster=slot.monster
  check(actor.monster_name==chosen.monster_types[0] and actor.monster_level==int(chosen.expected_level),"no template or level substitution")
  check(actor.max_hp==maxi(30,int(records[str(actor.monster_name)].hp)),"source HP uses existing actor minimum30 clamp without visual-template inheritance")
  check(actor.motion.frame_source!=null and actor.sprite.texture!=null,"real source art loaded")
  check(SAFE.floor_allowed(world.field_map,actor.home_position),"actual physical foot clearance")
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw;check(not root.get_texture().get_image().is_empty(),"Main GPU viewport")
  if DisplayServer.get_name()!="headless":
   # Stage only the inspected actor for readable evidence; production spawning,
   # identity, damage and respawn assertions above/below remain unchanged.
   for other:Dictionary in population.slots:
    if is_instance_valid(other.get("monster")) and other.monster!=actor:
     other.monster.hide();other.monster.set_physics_process(false)
   actor.set_physics_process(false)
   world.hud._hide_aux_panels()
   world.player.global_position=actor.global_position+Vector2(0,100)
   world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("/workspace/pr201-validation/monster70-identity-main-"+npc+".png")
  world._deal_successful_player_hit(actor,actor.max_hp+1,false)
  check(actor.dead and slot.monster==null,"actual damage kill releases slot")
  if chosen.mode=="boss":
   var state:Dictionary=population.boss_director.state_for(str(chosen.map_id),slot.region)
   check(state.phase=="cooldown" and float(state.ready_at)>Time.get_unix_time_from_system()+800,"named life uses persistent wall clock cooldown")
   world._set_map("source_53",false);world.field_population.set_process(false)
   world._set_map(str(chosen.map_id),false);world.field_population.set_process(false)
   world.field_population.slots=world.field_population.slots.filter(func(slot:Dictionary):return str(slot.region.id)==str(chosen.id))
   for index:int in range(world.field_population.slots.size()):world.field_population.slots[index].slot_id=index
   world.field_population.pending_initial_spawns=world.field_population.pending_initial_spawns.filter(func(slot:Dictionary):return str(slot.region.id)==str(chosen.id))
   world.field_population.pending_spawn_ids.clear()
   for pending:Dictionary in world.field_population.pending_initial_spawns:world.field_population.pending_spawn_ids[int(pending.slot_id)]=true
   for i:int in range(20):world.field_population._process(.4);await process_frame
   var duplicates:int=0
   for current:Dictionary in world.field_population.slots:
    if str(current.region.id)==str(chosen.id) and is_instance_valid(current.monster):duplicates+=1
   check(duplicates==0,"map reentry cannot bypass named cooldown or duplicate boss")
   check(world._save_game(true)==OK,"real save includes new boss cooldown")
   var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
   var key:String=world.field_population.boss_director.key(str(chosen.map_id),slot.region)
   check(saved.monster_world.bosses.has(key) and saved.monster_world.bosses[key].phase=="cooldown","saved stable boss identity")
  else:
   var delay:float=slot.remaining
   population._process(delay-.1);check(slot.monster==null,"no early authored respawn")
   for i:int in range(20):population._process(.4);await process_frame
   check(is_instance_valid(slot.monster) and not slot.monster.dead,"production authored respawn")
 world.queue_free();await process_frame;await process_frame
 print("MONSTER70_IDENTITY_MAIN_RESULT checks=",checks," errors=",errors," species=",names.size()," maps=",maps.size());quit(0 if errors==0 else 1)
