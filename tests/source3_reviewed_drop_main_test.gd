extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const CATALOG=preload("res://scripts/monsters/monster_catalog.gd")
const DROP=preload("res://scripts/loot_drop.gd")
const REVIEW=preload("res://scripts/loot/source3_reviewed_drop.gd")
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);printerr("SOURCE3_MAIN_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var phase:String="write"
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--phase="):phase=arg.trim_prefix("--phase=")
 var world:TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
 check(QA.enter_game(world),"actual Main class confirmation")
 world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false);world.save_timer=-100000;world.portal_cooldown=100000
 if "--check-item-links" in OS.get_cmdline_user_args():
  var mapped:Dictionary=preload("res://scripts/loot/source3_item_links.gd").resolve("weapon","11",world.loot_catalog)
  check(mapped.get("name")=="수정 단검","actual Main typed source item resolves existing item")
  check(world.loot_catalog.get("source3_by_key",{}).get("source3:tw380:Taiwan:weapon:11")=="수정 단검","actual runtime lookup index uses confirmed identity")
  print("SOURCE3_RUNTIME_ITEM_INDEX entries=",world.loot_catalog.get("source3_by_key",{}).size())
 var id_path:String="user://source3-main-expect.json"
 if phase=="write":
  world._clear_monsters();world.ground_loot.clear_map(world.active_map_id);world.level=90;world.ain_service.blessing=200
  world.original_skills.catalog.learned.clear()
  var record:Dictionary={}
  for r:Dictionary in world.monster_db:
   if str(r.get("sourceId",""))=="l1j_tw380_npc_45962":record=r
  check(not record.is_empty() and record.catalog_only,"exact actual active113 record, fixture only")
  if record.is_empty():await finish(world,phase);return
  var arena:Vector2=preload("res://tests/active_source_test_positions.gd").combat(world,[Vector2(30,0)])
  check(arena.is_finite(),"real admitted combat floor")
  if not arena.is_finite():await finish(world,phase);return
  world.player.global_position=arena
  var monster:TwilightMonster=load("res://scenes/Monster.tscn").instantiate();world.monsters_root.add_child(monster);monster.setup(record,world.player,world,null);monster.position=arena+Vector2(30,0);monster.set_physics_process(false)
  monster.died.connect(world._on_monster_died)
  check(monster.loot_source_identity==REVIEW.identity(record),"persistent source tuple reaches real actor")
  var empty_rng:=RandomNumberGenerator.new();empty_rng.seed=42
  check(DROP._pick_equipment_entry("희귀",monster.drop_items,world.loot_catalog,empty_rng,monster.monster_name).is_empty(),"actual preexisting rare candidate pool is empty")
  check(DROP._pick_equipment_entry("희귀",monster.drop_items,world.loot_catalog,empty_rng,monster.monster_name,monster.loot_source_identity)=={"item_name":"수정 단검","quantity":1},"reviewed rare fallback reachable in real catalog")
  var seed_value:int=-1;var expected:Array=[]
  for i:int in range(10000):
   var rng:=RandomNumberGenerator.new();rng.seed=i
   var rolled:Array=DROP.roll_detailed(monster.drop_items,monster.is_boss,world.loot_catalog,rng,monster.monster_name,monster.loot_source_identity)
   if rolled.any(func(row):return row.item_name=="수정 단검"):seed_value=i;expected=rolled;break
  check(seed_value>=0,"ordinary successful rarity roll reaches reviewed item")
  if seed_value<0:monster.queue_free();await finish(world,phase);return
  print("SOURCE3_MAIN_SEED ",seed_value," is_boss=",monster.is_boss," expected=",JSON.stringify(expected))
  world.rng.seed=seed_value;var before:int=int(world.inventory.get("수정 단검",0));var item_id:String=""
  world._deal_successful_player_hit(monster,monster.max_hp+1,false)
  check(monster.dead,"production damage kills real actor")
  var drops_before:Dictionary=world.ground_loot.records.duplicate(true)
  world._on_monster_died(monster)
  check(world.ground_loot.records==drops_before,"duplicate death signal cannot reward twice")
  for id:String in world.ground_loot.records:
   var row:Dictionary=world.ground_loot.records[id]
   if row.item_name=="수정 단검":item_id=id;check(int(row.quantity)==1 and row.grade=="희귀","real ground loot quantity/grade")
  check(not item_id.is_empty(),"real Main death produced reviewed ground drop")
  if item_id.is_empty():await finish(world,phase);return
  var view:Button=world.ground_loot.views.get(item_id)
  check(view!=null and view.visible and view.tooltip_text.contains("수정 단검"),"real item visual/button tooltip")
  check(str(world.ground_loot.item_record("수정 단검").get("sourceId",world.ground_loot.item_record("수정 단검").get("grade_source_id","")))=="423","actual existing game item423")
  check(int(world.inventory.get("수정 단검",0))==before,"death does not directly grant inventory")
  var file=FileAccess.open(id_path,FileAccess.WRITE);file.store_string(JSON.stringify({"item_id":item_id,"before":before,"position":world.ground_loot.records[item_id].position}));file.close()
  check(world._save_game(true)==OK,"save real ground item before pickup")
 elif phase=="read":
  var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(id_path));var id:String=saved.item_id
  check(world.ground_loot.records.has(id),"independent restart restores same ground item ID")
  world._restore_ground_drops(world._ground_drops_snapshot())
  check(world.ground_loot.records.has(id),"duplicate restore retains one stable item ID")
  var view:Button=world.ground_loot.views.get(id)
  check(view!=null,"real restored pickup view")
  if view!=null:
   world.player.global_position=Vector2(saved.position[0],saved.position[1])
   check(not world._collect_ground_drop(view),"visibility grace blocks immediate restored pickup")
   await create_timer(float(world.ground_loot.MIN_VISIBLE_MS)/1000.0+0.05).timeout
   check(world._collect_ground_drop(view),"actual pickup transaction after production visibility grace")
   check(not world._collect_ground_drop(view),"same view cannot be picked up twice")
  check(int(world.inventory.get("수정 단검",0))==int(saved.before)+1,"exact one inventory item after pickup")
  world._open_inventory();await process_frame
  check(world.hud.workspace.visible,"real inventory UI opens")
  check(world._save_game(true)==OK,"save after actual pickup")
 elif phase=="empty":
  var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(id_path))
  check(not world.ground_loot.records.has(str(saved.item_id)),"second restart cannot restore collected ground item")
  check(int(world.inventory.get("수정 단검",0))==int(saved.before)+1,"second restart retains exactly one item")
 var capture:String=OS.get_environment("TWILIGHT_SOURCE3_MAIN_CAPTURE")
 if not capture.is_empty() and DisplayServer.get_name()!="headless":
  world.player.camera.reset_smoothing();world.field_renderer.refresh_visible();await process_frame;await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(capture+"-"+phase+".png")==OK,"actual Main viewport")
 await finish(world,phase)
func finish(world:Node,phase:String):
 world.queue_free();await process_frame;await process_frame
 print("SOURCE3_DROP_MAIN_RESULT phase=",phase," checks=",checks," failures=",failures.size())
 quit(0 if failures.is_empty() else 1)
