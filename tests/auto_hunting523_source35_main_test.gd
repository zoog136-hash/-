extends SceneTree
## Existing Land35 contract only; no cross-map auto travel or original M claim.
const QA=preload("res://tests/qa_class_selection.gd")
const POLICY=preload("res://scripts/auto_hunting/local_movement.gd")
var checks:int=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("AUTO_HUNT35_FAIL: ",label)
func snapshot(w:Node)->Dictionary:
 return {"map":w.active_map_id,"point":w.player.global_position,"gold":w.gold,"inventory":JSON.stringify(w.inventory,"",true,true),"instances":JSON.stringify(w.item_instances,"",true,true),"auto":w.player.auto_enabled,"path":w.player.click_path.duplicate(),"sha":FileAccess.get_sha256(w.save_path())}
func run()->void:
 var w=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.save_timer=-100000.0
 check(QA.enter_game(w),"actual Main class/startup")
 w.player.set_physics_process(false)
 if is_instance_valid(w.field_population):w.field_population.set_process(false)
 w.level=99;w.gold=987654;w.inventory["다이아"]=50
 check(w._save_game(true)==OK,"initial current-map migration settled")
 check(w.auto_hunting_set_local_settings({"enabled":true,"end_inclusive":true,"search_order":"center_first","gem_wallet_enabled":true,"allow_entry_area":false}).ok,"existing policy and Gem opt in")
 check(w.auto_hunting_movement_assessment(474,1412).code=="CURRENT_FIELD_ONLY","Land35 cannot cross-map teleport from Aden")
 var adena:Dictionary=w.auto_hunting_move(174,882)
 check(adena.ok and w.gold==987654-int(adena.get("price",0)) and int(w.inventory["다이아"])==50,"existing Adena action still preserves Gem")
 var gold_before35:int=w.gold
 # Existing game map entry is fixture setup, not a new auto cross-map path.
 w._set_map("source_35",false)
 w.player.set_physics_process(false)
 check(w.active_map_id=="source_35" and int(w.field_map.definition.source_map_id)==35,"actual existing source35 field loaded")
 check(str(w.field_map.definition.source_sha256)=="c7ead4cd32cec6d527114268c00130668f673816a70047e5182d93a343282aba","existing collision identity unchanged")
 check(w.field_map.point_clear(w.player.global_position,4),"existing entry is traversable")
 w.player.auto_enabled=true
 check(w._save_game(true)==OK,"baseline source35 save")
 var before:Dictionary=snapshot(w)
 w.hud._navigate("auto");await process_frame
 var view=w.hud.find_child("AutoHuntingDestinations",true,false)
 var region:int=-1
 for i:int in range(view.entries.size()):
  if int(view.entries[i].schedule.ID)==474:region=i;break
 check(region>=0,"original source35 menu remains selectable")
 if region<0:quit(1);return
 view.regions.select(region);view.regions.item_selected.emit(region)
 check(view.move_button.disabled and w.auto_hunting_movement_assessment(474,1412).code=="NO_SAFE_CELL","default entry exclusion preserved")
 check(snapshot(w)==before,"browsing and excluded entry do not charge or write")
 view.entry_area_enabled.button_pressed=true
 var quote:Dictionary=w.auto_hunting_movement_assessment(474,1412)
 check(quote.ok,"explicit own entry policy finds a safe in-region cell")
 if not quote.ok:
  print("AUTO_HUNT35_BLOCK ",JSON.stringify(quote));quit(1);return
 check(quote.currency_id==4 and quote.price==10 and quote.map_id=="source_35","original Gem4 amount and existing active map bound")
 var bounds:Rect2i=POLICY.territory_bounds(w.auto_hunting_schedule.destination(474).destinations[0].territory,true)
 check(bounds.has_point(POLICY.source_cell(w.field_map,quote.destination)) and POLICY.safe_point(w,quote.destination,true),"actual cell passes original arrival bounds and active actor/portal checks")
 check(not view.move_button.disabled and view.details.text.contains("Gem ID4") and view.entry_area_enabled.button_pressed,"actual UI exposes source fee and entry setting")
 w.equipment_collections.test_save_writer=func(_path:String,_data:Dictionary)->Error:return ERR_CANT_CREATE
 view.move_button.pressed.emit()
 check(view.status.text.contains("실패") and snapshot(w)==before,"source35 save failure preserves exact live/saved state")
 w.equipment_collections.test_save_writer=Callable()
 view.move_button.pressed.emit()
 check(view.status.text.contains("완료") and w.player.global_position==quote.destination,"actual source35 movement executes through AUTO UI")
 check(w.active_map_id=="source_35" and w.gold==gold_before35 and int(w.inventory.get("다이아",0))==40,"same map preserved and exact10Gem debited once")
 check(JSON.stringify(w.item_instances,"",true,true)==str(before.instances) and w.player.auto_enabled,"physical IDs and live AUTO preserved")
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
 check(data.map_id=="source_35" and int(data.inventory["다이아"])==40 and data.position==[quote.destination.x,quote.destination.y],"destination and Gem debit durable together")
 check(int(data.original_position.source_map_id)==35 and data.original_position.grid_sha256==w.field_map.definition.source_sha256,"source35 save coordinate identity retained")
 var after:Dictionary=snapshot(w)
 check(w.auto_hunting_move(474,1412).code=="ALREADY_THERE" and snapshot(w)==after,"duplicate source35 click cannot charge again")
 w.inventory["다이아"]=1;w._load_game(true)
 check(not w.source_save_blocked and w.active_map_id=="source_35" and w.player.global_position==quote.destination and int(w.inventory["다이아"])==40,"actual source35 reload restores position and Gem")
 check(FileAccess.get_sha256(w.save_path())==after.sha,"source35 reload does not rewrite saved bytes")
 w.hud._navigate("auto");await process_frame
 view=w.hud.find_child("AutoHuntingDestinations",true,false);view.regions.select(region);view.regions.item_selected.emit(region)
 check(view.entry_area_enabled.button_pressed and view.move_button.disabled and view.status.text.contains("이미"),"reopened actual UI preserves policy and arrival result")
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--capture=") and DisplayServer.get_name()!="headless":
   await process_frame
   var scroll:ScrollContainer=w.hud.find_child("AutoSettingsScroll",true,false)
   scroll.ensure_control_visible(view.entry_area_enabled)
   await process_frame;await process_frame;await RenderingServer.frame_post_draw
   check(scroll.get_global_rect().encloses(view.entry_area_enabled.get_global_rect()),"entry policy actually inside viewport")
   check(root.get_texture().get_image().save_png(arg.trim_prefix("--capture="))==OK,"actual source35 AUTO screen captured")
 print("AUTO_HUNT35_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_land":35,"actual_moves":1,"cross_map_auto_travel":false,"save_or_collision_guard_weakened":false}))
 w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
