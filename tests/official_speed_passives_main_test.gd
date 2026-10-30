extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var checks:int=0
var errors:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;printerr("OFFICIAL_SPEED_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var world:TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
 check(QA.enter_game(world),"actual character selection")
 world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false);world.save_timer=-100000
 world._clear_monsters();world.gold=1000000;world.level=90
 var service=world.original_skills;var catalog=service.catalog
 check(service.local_runtime.rows().size()==22,"332 blocked references never enter per-hit runtime scan")
 for values:Array in [["요정","엘리멘탈 스피드",1.25,25.0,12.5],["암흑기사","다크 러쉬",1.25,25.0,25.0],["사신","고스트 스텝",1.3,30.0,25.0]]:
  world.job_class=values[0];var row:Dictionary=catalog.record_for(values[1]);catalog.learned.erase(row.id)
  world.level=int(row.minimum_level)-1
  check(not catalog.reason(row,true).is_empty(),"published learning level enforced "+str(row.name))
  world.level=90
  var before:float=world._effective_attack_speed_bonus_percent()
  check(catalog.buy_book(row.id) and catalog.learn(row.id),"real book purchase and learning "+str(row.name))
  check(is_equal_approx(catalog.speed(),values[2]),"live movement multiplier "+str(row.name))
  check(is_equal_approx(world._effective_attack_speed_bonus_percent()-before,values[3]),"live normal-attack speed "+str(row.name))
  check(service.stat("castSpeed")==values[4],"published casting percentage reaches existing cooldown policy")
  check(not service.ready(row) and not world._cast_job_skill(row.name),"passive cannot cast or consume activation costs")
  var entry:Dictionary=service.vfx.similar_bridge.binding_for(row.id)
  check(entry.phases.size()==1 and entry.phases.has("learn"),"visual event only on learning, no permanent texture preload")
  var key:String=entry.phases.learn;var frames:SpriteFrames=service.vfx.similar_bridge.frames_for_resource(key)
  check(frames!=null and frames.get_frame_count("source")>0,"real source effect bytes load")
  service.vfx.similar_bridge.release(key)
  world.job_class="기사";check(not catalog.enabled(row),"class change disables unrelated passive")
 for name:String in ["프라임 소드","쇼크 스턴(베테랑)","매직 마스터(에이션트)"]:
  var row:Dictionary=catalog.record_for(name);var mp:int=world.mp;var hp:int=world.hp
  check(row.runtime_blocked and not world._cast_job_skill(name),"unknown skill cannot fall through legacy damage path")
  check(world.mp==mp and world.hp==hp and world.pending_attack.is_empty(),"blocked reference cannot charge or attack")
 check(world._skill_record("셋팅 업").id==catalog.record_for("세팅 업").id,"world quickslot alias uses original ID")
 check(world._save_game(true)==OK,"save all three learned passive IDs")
 var learned:Dictionary=catalog.learned.duplicate(true);world._load_game(true)
 for values:Array in [["요정","엘리멘탈 스피드"],["암흑기사","다크 러쉬"],["사신","고스트 스텝"]]:
  world.job_class=values[0];var row:Dictionary=catalog.record_for(values[1]);check(catalog.enabled(row) and catalog.learned.get(row.id)==learned.get(row.id),"load preserves stable passive identity")
 service.vfx.clear();world.queue_free();await process_frame;await process_frame
 print("OFFICIAL_SPEED_MAIN_RESULT checks=",checks," errors=",errors," passives=3 playable=147 references=332")
 quit(0 if errors==0 else 1)
