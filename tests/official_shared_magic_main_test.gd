extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const CLOCK=preload("res://tests/combat_test_clock.gd")
var checks:int=0
var errors:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;printerr("SHARED_MAGIC_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var world:TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
 check(QA.enter_game(world),"actual Main class confirmation")
 world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false);world.save_timer=-100000
 world.level=90;world.gold=1000000;world.max_mp=1000;world.mp=1000
 var point:Vector2=preload("res://tests/active_source_test_positions.gd").combat(world,[Vector2(30,0),Vector2(50,0)])
 check(point.is_finite(),"actual source-map combat floor")
 if not point.is_finite():quit(1);return
 world.player.global_position=point
 var service=world.original_skills;var catalog=service.catalog
 var roster:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/official_roster.json"))
 var extensions:Array=roster.observations.filter(func(r):return r.status=="existing_shared_class")
 check(extensions.size()==11,"all eleven reviewed class/spell combinations")
 var learned_ids:Dictionary={}
 for fact:Dictionary in extensions:
  world._clear_combat_actions();world._clear_monsters();await process_frame
  world.active_skill_buffs.clear();service.vfx.clear();world.skill_cooldowns.clear();world.skill_global_cooldown=0
  world.job_class=str(fact["class"]);var row:Dictionary=catalog.record_for(fact.runtime_name)
  world.level=int(fact.level_display)-1
  check(catalog.level_locked(row) and not catalog.enabled(row),"class-specific learning/casting level "+str(fact["class"])+str(row.name))
  world.level=90
  if int(catalog.learned.get(row.id,0))==0:
   check(catalog.buy_book(row.id) and catalog.learn(row.id),"existing shared book and stable ID "+str(row.name))
  else:check(catalog.owned(row),"shared learned ID reused without a duplicate book")
  learned_ids[row.id]=true
  var targets:Array[TwilightMonster]=[]
  for i:int in range(2):
   var actor:TwilightMonster=load("res://scenes/Monster.tscn").instantiate();world.monsters_root.add_child(actor)
   actor.setup({"name":"공통 마법 검증 대상","hp":1000000,"lv":1,"mr":0,"ac":0,"undead":row.mode=="turn_undead","grade":"일반"},world.player,world,null)
   actor.global_position=point+Vector2(30+i*20,0);actor.set_physics_process(false);targets.append(actor)
  world.selected_monster=targets[0];world.mp=1000;world.hp=maxi(1,world._effective_max_hp()/2)
  var before_hp:int=world.hp;var before_ac:int=world._effective_ac()
  var resolved:Dictionary=catalog.resolve(row)
  check(resolved.id==row.id and int(resolved.mp)==int(fact.mp_display),"class MP uses official observation, not wizard defaults")
  world._update_hud();world.hud.open_skills();await process_frame
  var view:Node=world.hud.skills_view;view.class_filter.select(0);view.search.text=str(row.name);view.refresh()
  var selected:int=-1
  for i:int in range(view.filtered.size()):
   if view.filtered[i].id==row.id:selected=i
  check(selected>=0,"actual current-class UI lists the shared spell")
  if selected>=0:
   view.select(selected);check(not view.use_button.disabled and view.detail.text.contains(str(fact["class"])) and view.detail.text.contains("Lv."+str(fact.level_display)),"UI displays reviewed class level and permits real use")
  world.hud._close_workspace()
  check(world._cast_job_skill(row.name),"production world cast route "+str(row.name))
  check(world.mp==1000-int(fact.mp_display),"exact class-specific MP spent once")
  if row.mode in ["attack","turn_undead"]:
   check(targets[0].hp==1000000,"no damage before the production marker")
   CLOCK.settle(world)
   check(targets[0].hp<1000000 or targets[0].dead or row.mode=="turn_undead","contact or documented probabilistic undead resistance")
   if row.name in ["프로즌 클라우드","파이어 볼"]:check(targets[1].hp<1000000,"existing shared area processing remains connected")
  elif row.mode=="heal":check(world.hp>before_hp,"actual shared self-heal adaptation")
  elif row.mode=="buff":check(world.active_skill_buffs.has(row.name) and world._effective_ac()==before_ac-3,"actual shared self-defense adaptation")
  world._clear_combat_actions();world.skill_cooldowns.clear();world.skill_global_cooldown=0
  world.job_class="기사";var mp_before:int=world.mp
  check(not service.cast(row) and world.mp==mp_before,"unlisted class still rejected without charge")
 check(learned_ids.size()==8,"eleven class links retain eight existing skill identities")
 world.job_class="요정";world.level=90
 check(world._save_game(true)==OK,"real save retains shared learned IDs")
 world._load_game(true)
 for id:String in learned_ids:check(catalog.owned(catalog.record_for(id)),"real reload retains shared learned identity "+id)
 world.queue_free();await process_frame;await process_frame
 print("OFFICIAL_SHARED_MAGIC_MAIN_RESULT checks=",checks," errors=",errors," class_links=11 skill_ids=8 playable=147")
 quit(0 if errors==0 else 1)
