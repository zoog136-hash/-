extends SceneTree
## Identical real floor views, validity checks, bag/quest/audio/HUD handlers.
## This fixture controls geometry (empty AStar test grid), not phone rendering.
const QA=preload("res://tests/qa_class_selection.gd")
class Reference extends TwilightLootPickupController:
	func _original_before(a: String,b: String)->bool:
		var current_a:bool=not manager.current_batch.is_empty() and str(manager.records[a].hunt_batch)==manager.current_batch
		var current_b:bool=not manager.current_batch.is_empty() and str(manager.records[b].hunt_batch)==manager.current_batch
		if current_a!=current_b:return current_a
		var da:int=roundi(player.global_position.distance_to(_destination(a))*10.0)
		var db:int=roundi(player.global_position.distance_to(_destination(b))*10.0)
		if da!=db:return da<db
		var ga:int=TwilightDropVisual.GRADES.find(str(manager.records[a].grade));var gb:int=TwilightDropVisual.GRADES.find(str(manager.records[b].grade))
		return ga>gb if ga!=gb else a<b
	func _ranked_candidates(automatic:bool,limit:int)->Array[String]:
		var ids:Array[String]=[]
		for id:String in manager.views.keys():
			if float(blocked.get(id,0))>clock:continue
			if automatic and bool(manager.records[id].get("player_dropped",false)):continue
			if manager.valid_view(manager.views[id]) and player.global_position.distance_to(_destination(id))<=SCAN_RADIUS:ids.append(id)
		ids.sort_custom(_original_before)
		return ids.slice(0,limit)

var failures:Array[String]=[]
var checks:=0
func ck(ok:bool,msg:String)->void:
	checks+=1
	if not ok:failures.append(msg);printerr("GROUND_PICKUP_SHORTLIST_FAIL ",msg)
func _initialize()->void:run.call_deferred()
func stats(raw:Array)->Dictionary:
	var v:=raw.duplicate();v.sort();var over:=0;var tail:=0
	for x:int in v:
		if x>16000 and x<=50000:over+=1
		if x>50000:tail+=1
	return {"n":v.size(),"median_us":v[v.size()/2],"p95_us":v[ceili(v.size()*0.95)-1],"max_us":v[-1],"gt16_to50":over,"gt50":tail}
func spawn(w: Node,id:String,point:Vector2,grade:String,batch:String,dropped:bool)->void:
	var now:=Time.get_unix_time_from_system()
	var view: Button=w.ground_loot._commit_spawn({"map_id":w.ground_loot.current_map,"id":id,"state":"ground","item_name":"HP 물약","position":[point.x,point.y],"grade":grade,"hunt_batch":batch,"quantity":1,"created_at":now,"expires_at":now+900,"player_dropped":dropped})
	view.set("visible_since",Time.get_ticks_msec()-950)
func run()->void:
	var w: Node=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false)
	ck(QA.enter_game(w),"real Main before fixture")
	w.field_population.set_process(false);w.player.auto_enabled=false;w._clear_monsters();w._clear_drops()
	w.field_map=null;w.astar=AStarGrid2D.new();w.astar.region=Rect2i(-40,-40,80,80);w.astar.update()
	w.player.global_position=Vector2.ZERO
	var live:TwilightLootPickupController=w.loot_pickup
	var ref:=Reference.new();ref.configure(w,w.ground_loot)
	var report:Dictionary={}
	var fps_cap:int=Engine.max_fps
	# The frame budget concerns work. Also allow the production 60 FPS cap
	# as a second experiment, where a 16.67 ms present interval is expected.
	if OS.get_environment("TWILIGHT_PICKUP_UNCAPPED")=="1":Engine.max_fps=0
	var bench:=OS.get_environment("TWILIGHT_PICKUP_RANK_BENCH")=="1"
	for n:int in ([4,32,128] if bench else [32]):
		w._clear_drops();w.ground_loot.current_batch="new"
		var rs:Dictionary={"before_scan":[],"after_scan":[],"before_action":[],"after_action":[],"before_next_frame":[],"after_next_frame":[]}
		for i:int in n:
			var pos:=Vector2.from_angle(float(i)*2.399963)*float(100+(i*71)%300)
			if i<2:pos=Vector2(200,0) # exact distance and grade ties
			spawn(w,"far%03d"%i,pos,"일반" if i%3!=0 else "영웅","new" if i%2==0 else "prior",i%7==0)
		for c:TwilightLootPickupController in [live,ref]:c.blocked={"far002":c.clock+10}
		for batch:String in ["","new"]:
			w.ground_loot.current_batch=batch
			for off:Vector2 in [Vector2.ZERO,Vector2(50,23)]:
				w.player.global_position=off
				for auto:bool in [true,false]:
					for lim:int in [1,8]:ck(live._ranked_candidates(auto,lim)==ref._ranked_candidates(auto,lim),"priority including old batch, collect mode, ties, position and blocked")
		w.ground_loot.current_batch="new";w.player.global_position=Vector2.ZERO
		for j:int in (100 if bench else 2):
			for tag:String in (["before","after"] if j%2==0 else ["after","before"]):
				var owner:TwilightLootPickupController=ref if tag=="before" else live
				w.loot_pickup=owner;owner.cancel();w.player.clear_click_path()
				spawn(w,"near",Vector2(0,0),"영웅","new",false)
				var start:=Time.get_ticks_usec();var selected:=owner._ranked_candidates(false,1);rs[tag+"_scan"].append(Time.get_ticks_usec()-start)
				ck(selected==["near"],"repeated exact nearest target")
				var count:=int(w.inventory.get("HP 물약",0))
				# No benchmark pre-scan inside either button-to-next-frame interval.
				await process_frame
				start=Time.get_ticks_usec();var handled:=owner.request_nearby()
				rs[tag+"_action"].append(Time.get_ticks_usec()-start)
				ck(handled and int(w.inventory.get("HP 물약",0))==count+1 and not w.ground_loot.views.has("near"),"button to real bag grant, no wait or duplicate")
				await process_frame
				rs[tag+"_next_frame"].append(Time.get_ticks_usec()-start)
				owner.cancel()
		for key:String in rs:rs[key]=stats(rs[key])
		report[str(n)]=rs
	w.loot_pickup=live;w.queue_free();await process_frame
	print("GROUND_PICKUP_SHORTLIST_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"samples":report,"engine_cap":Engine.max_fps,"normal_cap":fps_cap}))
	quit(0 if failures.is_empty() else 1)
