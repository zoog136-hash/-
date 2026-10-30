extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var checks:int=0
var errors:int=0
func check(ok:bool,note:String):
 checks+=1
 if not ok:errors+=1;printerr("HEAL_MAIN_FAIL ",note)
func _initialize():call_deferred("run")
func run():
 var world:TwilightWorld=load("res://Main.tscn").instantiate()
 world.active_map_id="source_0";root.add_child(world)
 check(QA.enter_game(world,"마법사"),"actual Main class confirmation")
 world.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false);world.save_timer=-100000
 world.field_population.set_process(false);world._clear_monsters();world.level=90
 var service=world.original_skills
 var cases={"힐":"SPR-U-a03b6d307a3a03ab4316","풀 힐":"SPR-U-65995a45fd43c03b3aeb"}
 for name:String in cases:
  var row:Dictionary=service.catalog.record_for(name);service.catalog.learned[str(row.id)]=1
  world.hp=1;world.mp=world._effective_max_mp();world.skill_cooldowns.clear();world.skill_global_cooldown=0
  var cost:int=int(service.catalog.resolve(row).mp);var before:int=world.mp
  check(world._cast_job_skill(name),"actual world cast route "+name)
  check(world.hp>1 and world.mp==before-cost,"one heal and one MP charge "+name)
  var found:Dictionary={}
  for live:Dictionary in service.vfx.live:
   if str(live.similar_key)==str(cases[name]):found=live
  check(not found.is_empty(),"native impact from actual Main cast "+name)
  if not found.is_empty():
   var sprite:AnimatedSprite2D=found.spx_sprite
   check(sprite.global_position==world.player.global_position,"same real player anchor")
   check(sprite.sprite_frames.get_frame_count("source")==21,"complete decoded native sequence")
  var paid:int=world.mp
  check(not world._cast_job_skill(name) and world.mp==paid,"cooldown prevents repeat cost "+name)
  service.vfx.clear();check(service.vfx.similar_bridge.cache.is_empty(),"native effect released")
 world.queue_free();await process_frame
 print("REVIEWED_HEAL_MAIN_RESULT checks=",checks," errors=",errors," real_casts=2 device=unverified")
 quit(0 if errors==0 else 1)
