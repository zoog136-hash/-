extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var checks:int=0
var errors:int=0
func check(ok:bool,note:String):
 checks+=1
 if not ok:errors+=1;printerr("CLEANSE_BEAM_MAIN_FAIL ",note)
func _initialize():call_deferred("run")
func run():
 var world:TwilightWorld=load("res://Main.tscn").instantiate()
 world.active_map_id="source_0";root.add_child(world)
 check(QA.enter_game(world,"마법사"),"actual Main class confirmation")
 world.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false);world.save_timer=-100000
 world.field_population.set_process(false);world._clear_monsters();world.level=90
 var service=world.original_skills
 var cure:Dictionary=service.catalog.record_for("큐어 포이즌");service.catalog.learned[str(cure.id)]=1
 world.hp=world._effective_max_hp();world.mp=world._effective_max_mp()
 var before:int=world.mp
 check(not world._cast_job_skill(str(cure.id)),"no poison rejects unused cleanse")
 check(world.mp==before and service.vfx.live.is_empty(),"rejected cleanse has no cost or effect")
 world.player.apply_poison(30,1)
 check(world._cast_job_skill(str(cure.id)),"actual world cleanse cast route")
 check(not world.player.is_poisoned(),"actual poison removed")
 check(world.mp==before-int(service.catalog.resolve(cure).mp),"one real cleanse MP charge")
 var found:int=0
 for live:Dictionary in service.vfx.live:
  if str(live.similar_key)=="SPR-U-3bc093ad24d391ac1d01":
   found+=1;check(live.spx_sprite.global_position==world.player.global_position,"cleanse effect at actual player")
 check(found==1,"one source cleanse impact")
 service.vfx.clear();check(service.vfx.similar_bridge.cache.is_empty(),"cleanse resources released")
 world._set_map("source_491",false);world.field_population.set_process(false);world._clear_monsters()
 var arena:Vector2=Vector2.INF
 var habitats:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters/local_source_habitats.json"))
 for region:Dictionary in habitats.rows:
  if str(region.get("source_npc_id",""))!="45945":continue
  for flat:Variant in region.cells:
   var field=world.field_map
   var point:Vector2=field.cell_to_world(Vector2i(int(flat)%field.width,int(flat)/field.width))
   if preload("res://tests/active_source_test_positions.gd")._fits(field,point,[Vector2(30,0)]):arena=point;break
 check(arena.is_finite(),"actual reachable combat floor")
 if not arena.is_finite():quit(1);return
 world.player.global_position=arena
 var target:TwilightMonster=load("res://scenes/Monster.tscn").instantiate();world.monsters_root.add_child(target)
 target.setup({"name":"연출 검증 대상","hp":100000,"lv":1,"mr":0,"ac":0},world.player,world,null)
 target.global_position=arena+Vector2(30,0);target.set_physics_process(false);world.selected_monster=target
 var beam:Dictionary=service.catalog.record_for("디스인트그레이트");service.catalog.learned[str(beam.id)]=1
 world.skill_cooldowns.clear();world.skill_global_cooldown=0;world.mp=world._effective_max_mp();before=world.mp
 check(world._cast_job_skill(str(beam.id)),"actual world beam cast route")
 check(world.mp==before-int(service.catalog.resolve(beam).mp) and target.hp==100000,"paid cast waits for original release marker")
 world.rng.seed=12345
 world._release_player_attack(int(world.pending_attack.id))
 for step:int in range(60):world.combat_flights._physics_process(.02)
 check(target.hp<100000,"production flight reaches actual damage impact")
 found=0
 for live:Dictionary in service.vfx.live:
  if str(live.similar_key)=="SPR-U-1ca0ed4e4413ca7ed32f":
   found+=1;check(live.spx_sprite.global_position==target.combat_hit_position(),"beam effect at real target")
 check(found==1,"one BASE source beam impact, no shard variant")
 service.vfx.clear();check(service.vfx.similar_bridge.cache.is_empty(),"beam resources released")
 world.queue_free();await process_frame
 print("REVIEWED_CLEANSE_BEAM_MAIN_RESULT checks=",checks," errors=",errors," real_casts=2 controlled_release_marker=1 device=unverified")
 quit(0 if errors==0 else 1)
