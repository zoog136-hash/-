extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const CLOCK=preload("res://tests/combat_test_clock.gd")
var checks:int=0
var errors:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;printerr("WIZARD_GAP_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var world:TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
 check(QA.enter_game(world),"actual class selection")
 world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false);world.save_timer=-100000
 world._clear_monsters();world.job_class="마법사";world.level=90;world.gold=1000000;world.max_mp=1000;world.mp=1000
 var point:Vector2=preload("res://tests/active_source_test_positions.gd").combat(world,[Vector2(30,0),Vector2(50,0)])
 check(point.is_finite(),"real current map combat floor")
 if not point.is_finite():quit(1);return
 world.player.global_position=point
 var actors:Array[TwilightMonster]=[]
 for i:int in range(2):
  var actor:TwilightMonster=load("res://scenes/Monster.tscn").instantiate();world.monsters_root.add_child(actor)
  actor.setup({"name":"누락 마법 검사","hp":1000000,"lv":1,"mr":0,"ac":0,"atk":1},world.player,world,null)
  actor.global_position=point+Vector2(30+i*20,0);actor.set_physics_process(false);actors.append(actor)
 world.selected_monster=actors[0]
 var service=world.original_skills
 for name:String in ["프로즌 클라우드","파이어 볼","콘 오브 콜드","그레이터 힐","콜 라이트닝","선 버스트","블레스드 아머"]:
  var skill:Dictionary=service.catalog.record_for(name)
  check(not skill.is_empty() and skill.local_kind=="generic","registered named adaptation "+name)
  check(service.catalog.buy_book(skill.id) and service.catalog.learn(skill.id),"real book purchase and learning "+name)
  world._clear_combat_actions();world.skill_cooldowns.clear();world.skill_global_cooldown=0;world.mp=1000
  for actor:TwilightMonster in actors:actor.hp=1000000
  world.hp=maxi(1,world._effective_max_hp()/2)
  var hp_before:int=world.hp
  var ac_before:int=world._effective_ac()
  check(service.cast(skill),"real cast accepted "+name)
  check(world.mp==1000-int(skill.mp),"exact disclosed MP cost "+name)
  if skill.mode=="attack":
   check(actors[0].hp==1000000,"no damage before contact marker "+name)
   CLOCK.settle(world)
   check(actors[0].hp<1000000,"production marker applies damage "+name)
  elif skill.mode=="buff":
   check(world.active_skill_buffs.has(name),"production buff installed")
   check(world._effective_ac()==ac_before-3,"armor improves live defense by disclosed local AC")
   var defense:int=world._effective_ac()
   service.apply_buff(skill)
   check(world._effective_ac()==defense,"recast refreshes rather than stacking defense")
   world._tick_skill_buffs(1801)
   service.tick(0)
   check(not world.active_skill_buffs.has(name) and world._effective_ac()==ac_before,"armor duration expires and restores defense")
  else:check(world.hp>hp_before,"production heal changes player HP")
  check(not service.vfx.similar_bridge.binding_for(skill.id).is_empty(),"analogous source visual mapped "+name)
  check(not service.vfx.library.profile_for(skill.id).is_empty(),"authored fallback remains loadable "+name)
  world.job_class="기사";check(not service.ready(skill),"class permission enforced "+name);world.job_class="마법사"
 check(world._save_game(true)==OK,"actual save retains new stable learned IDs")
 var ids:Dictionary=service.catalog.learned.duplicate(true);world._load_game(true)
 for id:String in ids:check(int(service.catalog.learned.get(id,0))==int(ids[id]),"learned stable ID restored "+id)
 world.queue_free();await process_frame;await process_frame
 print("OFFICIAL_WIZARD_GAP_RESULT checks=",checks," errors=",errors," added=7")
 quit(0 if errors==0 else 1)
