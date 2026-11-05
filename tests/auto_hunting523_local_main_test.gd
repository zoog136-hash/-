extends SceneTree
## Executes production Main/current source field/private523 pack; isolated user:// only.
const QA = preload("res://tests/qa_class_selection.gd")
const POLICY = preload("res://scripts/auto_hunting/local_movement.gd")
var checks: int = 0
var failures: Array[String] = []
var scan: Array = []
var actual_moves: Array = []
var reentrant_code: String = ""
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("AUTO_HUNT_LOCAL_MAIN_FAIL: ",label)
func normalized(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func protected_state(world: Node) -> Dictionary:
	return {"position":world.player.global_position,"gold":world.gold,"auto":world.player.auto_enabled,
		"path":world.player.click_path.duplicate(),"velocity":world.player.velocity,"touch":world.player.touch_vector,
		"inventory":normalized(world.inventory),"instances":normalized(world.item_instances),"equipment":normalized(world.equipped_items),
		"collection":normalized(world.equipment_collections.export_state()),"drops":normalized(world._ground_drops_snapshot()),
		"buffs":normalized(world.active_skill_buffs),"sha":FileAccess.get_sha256(world.save_path())}
func finish(world: Node) -> void:
	print("AUTO_HUNT_LOCAL_MAIN_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"scan":scan,"actual_moves":actual_moves,"reentrant_code":reentrant_code}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	check(not OS.get_environment("TWILIGHT_AUTO_HUNT523_DIR").is_empty(),"actual private523 input supplied")
	var scene=load("res://Main.tscn") as PackedScene
	check(scene!=null,"production Main loads")
	if scene==null:quit(1);return
	var world=scene.instantiate();root.add_child(world)
	world.set_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"production class confirmation and startup")
	world.player.set_physics_process(false)
	if is_instance_valid(world.field_population):world.field_population.set_process(false)
	world.gold=9876543;world.level=99;world.player.auto_enabled=true
	check(world._save_game(true)==OK,"initial durable current-map save")
	var spawn: Vector2=world.player.global_position
	check(not world.auto_hunting_local_settings().enabled,"own-policy opt in starts disabled")
	var entries: Array=world.auto_hunting_destinations().entries
	check(entries.size()==80,"actual source menu count")
	print("AUTO_HUNT_LOCAL_PHASE startup_complete")
	if entries.size()!=80:await finish(world);return
	world.hud._navigate("auto")
	await process_frame
	var view=world.hud.find_child("AutoHuntingDestinations",true,false)
	check(view!=null and view.is_visible_in_tree(),"production AUTO route exposes controls")
	if view==null:await finish(world);return
	check(view.find_child("AutoHuntingLocalPolicyNote",true,false).text.contains("자체"),"UI distinguishes original data from own movement")
	view.local_enabled.button_pressed=true
	check(world.auto_hunting_local_settings().enabled,"UI checkbox commits own-policy opt in")
	view.end_rule.select(1);view.end_rule.item_selected.emit(1)
	check(not world.auto_hunting_local_settings().end_inclusive,"UI exposes half-open endpoint policy")
	view.end_rule.select(0);view.end_rule.item_selected.emit(0)
	view.search_order.select(1);view.search_order.item_selected.emit(1)
	check(world.auto_hunting_local_settings().search_order=="coordinate_order","UI exposes candidate order")
	view.search_order.select(0);view.search_order.item_selected.emit(0)
	var options: Dictionary=world.auto_hunting_local_settings()
	var reopened=POLICY.new()
	check(reopened.get_settings()==options,"durable options reopen")
	var candidate: Dictionary={}
	var candidate_region: int=-1
	var candidate_landing: int=-1
	var aden_menus: int=0
	for i: int in range(entries.size()):
		var entry: Dictionary=entries[i]
		if int(entry.destinations[0].land.ID)==4 and str(entry.currency.Name)=="Adena":aden_menus+=1
		for j: int in range(entry.destinations.size()):
			var landing: Dictionary=entry.destinations[j]
			var quote: Dictionary=world.auto_hunting_movement_assessment(int(entry.schedule.ID),int(landing.link.ID))
			scan.append({"schedule":int(entry.schedule.ID),"link":int(landing.link.ID),"code":str(quote.get("code","READY")),"ok":bool(quote.ok)})
			if not quote.ok:continue
			var bounds: Rect2i=POLICY.territory_bounds(landing.territory,true)
			check(bounds.has_point(quote.source_cell),"actual candidate inside original arrival rectangle")
			check(world.field_map.point_clear(quote.destination,4) and POLICY.safe_point(world,quote.destination),"actual candidate passes active map and occupancy")
			check(int(quote.price)==int(entry.teleport.TeleportCost),"source fee unchanged")
			if candidate.is_empty() or int(quote.price)<int(candidate.price):
				candidate=quote;candidate_region=i;candidate_landing=j
	check(aden_menus==49,"49 Adena menus bind current Aden independently of Gem and other Land")
	print("AUTO_HUNT_LOCAL_PHASE region_scan_complete")
	check(not candidate.is_empty(),"at least one real region has a safe supported destination")
	if candidate.is_empty():await finish(world);return
	var schedule_id: int=candidate.schedule_id
	var link_id: int=candidate.landing_link_id
	view.regions.select(candidate_region);view.regions.item_selected.emit(candidate_region)
	view.landings.select(candidate_landing);view.landings.item_selected.emit(candidate_landing)
	check(not view.move_button.disabled and view.details.text.contains(str(int(candidate.price))),"UI enables actual movement with original fee")
	var prior_settings_path: String=world.auto_hunting_local.settings_path
	world.auto_hunting_local.settings_path="user://missing-policy-dir/config.json"
	view.local_enabled.button_pressed=false
	check(world.auto_hunting_local_settings()==options and view.local_enabled.button_pressed and view.status.text.contains("실패"),"settings write failure restores visible and live options")
	world.auto_hunting_local.settings_path=prior_settings_path
	view._refresh_assessment()
	world.player.velocity=Vector2(3,4);world.player.set_touch_vector(Vector2.RIGHT)
	world.player.set_click_path(PackedVector2Array([spawn+Vector2(1,1)]),spawn+Vector2(1,1))
	var baseline: Dictionary=protected_state(world)
	world.gold=0
	check(world.auto_hunting_move(schedule_id,link_id).code=="INSUFFICIENT_ADENA","cost failure does not attempt movement")
	world.gold=baseline.gold
	check(protected_state(world)==baseline,"cost failure preserves saved and live state")
	world.player.stun_remaining=10.0
	check(world.auto_hunting_move(schedule_id,link_id).code=="MOVEMENT_STATE","stun blocks movement")
	world.player.stun_remaining=0.0
	world.player.hold_remaining=10.0
	check(world.auto_hunting_move(schedule_id,link_id).code=="MOVEMENT_STATE","hold blocks movement")
	world.player.hold_remaining=0.0
	world.player.fear_remaining=10.0
	check(world.auto_hunting_move(schedule_id,link_id).code=="MOVEMENT_STATE","fear blocks movement")
	world.player.fear_remaining=0.0
	var hp: int=world.hp;world.hp=0
	check(world.auto_hunting_move(schedule_id,link_id).code=="DEAD","death blocks movement")
	world.hp=hp
	world.pending_map_save_record={"test_pending":true}
	check(world.auto_hunting_move(schedule_id,link_id).code=="SAVE_GUARD","uncommitted map migration blocks movement")
	world.pending_map_save_record={}
	check(protected_state(world)==baseline,"failed state checks preserve live and saved state")
	var reservations: Array=world.field_map.reservations.duplicate(true)
	world.field_map.reservations.append({"center":[candidate.destination.x,candidate.destination.y],"radius":10000000.0})
	check(not world.auto_hunting_move(schedule_id,link_id).ok,"fully reserved landing fails safely without fallback")
	world.field_map.reservations=reservations
	check(protected_state(world)==baseline,"no-safe-cell failure preserves state")
	check(world._save_game(true,{},candidate)==ERR_UNAVAILABLE,"caller cannot inject staged movement outside transaction")
	var writes: int=world.equipment_collections.save_writes
	world.equipment_collections.test_save_writer=func(_path:String,_data:Dictionary)->Error:
		reentrant_code=str(world.auto_hunting_move(schedule_id,link_id).code)
		return ERR_CANT_CREATE
	view.move_button.pressed.emit()
	check(view.status.text.contains("실패"),"UI shows actual save failure")
	check(reentrant_code=="BUSY","reentrant movement prevented")
	check(protected_state(world)==baseline and world.equipment_collections.save_writes==writes,"save failure preserves position gold items AUTO paths and exact saved bytes")
	world.equipment_collections.test_save_writer=Callable()
	candidate=world.auto_hunting_movement_assessment(schedule_id,link_id)
	view.move_button.pressed.emit()
	check(view.status.text.contains("완료") and view.move_button.disabled,"UI executes move then exposes completion and already-inside disable")
	check(world.player.global_position==candidate.destination and world.player.global_position!=spawn,"production player actually moved to validated foot point")
	check(world.gold==int(baseline.gold)-int(candidate.price),"exact original fee charged once")
	check(world.player.auto_enabled and world.player.click_path.is_empty() and world.player.velocity==Vector2.ZERO and world.player.touch_vector==Vector2.ZERO,"AUTO preserved and transient movement cleared")
	var after: Dictionary=protected_state(world)
	for key: String in ["inventory","instances","equipment","collection","drops","buffs"]:
		check(after[key]==baseline[key],"movement preserves "+key)
	check(world.equipment_collections.save_writes==writes+1,"one durable write for successful movement")
	actual_moves.append({"schedule":schedule_id,"link":link_id,"price":int(candidate.price),"destination":[candidate.destination.x,candidate.destination.y]})
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(data.position==[candidate.destination.x,candidate.destination.y] and int(data.gold)==world.gold,"destination and fee already durable")
	check(data.original_position==normalized(POLICY.save_fields(world,candidate).original_position),"source-coordinate save matches exact pixel destination")
	var durable_sha: String=FileAccess.get_sha256(world.save_path())
	check(world.auto_hunting_move(schedule_id,link_id).code=="ALREADY_THERE","repeat activation cannot charge twice")
	check(FileAccess.get_sha256(world.save_path())==durable_sha and world.equipment_collections.save_writes==writes+1,"repeat activation makes no extra save")
	var destination: Vector2=world.player.global_position
	var charged_gold: int=world.gold
	world.player.global_position=spawn;world.gold=1
	world._load_game(true)
	check(not world.source_save_blocked and world.player.global_position==destination and world.gold==charged_gold,"actual save reentry restores destination and fee")
	check(FileAccess.get_sha256(world.save_path())==durable_sha,"reentry preserves saved bytes")
	world.hud._navigate("auto")
	await process_frame
	view=world.hud.find_child("AutoHuntingDestinations",true,false)
	view.regions.select(candidate_region);view.regions.item_selected.emit(candidate_region)
	view.landings.select(candidate_landing);view.landings.item_selected.emit(candidate_landing)
	check(view.local_enabled.button_pressed and view.move_button.disabled and view.status.text.contains("이미"),"reopened actual AUTO UI retains policy and shows arrived state")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture=") and DisplayServer.get_name()!="headless":
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(arg.trim_prefix("--capture="))==OK,"actual local-policy screen captured")
	# Exercise each initially safe source destination through the production
	# action/save path. Reset only the harness actor to the verified entry between
	# cases, so overlapping arrival regions cannot hide an untested transition.
	for row: Dictionary in scan:
		if not bool(row.ok) or int(row.schedule)==schedule_id and int(row.link)==link_id: continue
		world.player.global_position=spawn
		var next: Dictionary=world.auto_hunting_movement_assessment(int(row.schedule),int(row.link))
		check(bool(next.ok),"previously safe destination reassesses at verified entry")
		if not next.ok: continue
		var previous_gold: int=world.gold
		var moved: Dictionary=world.auto_hunting_move(int(row.schedule),int(row.link))
		check(moved.ok and moved.code=="MOVED" and world.player.global_position==next.destination,"each safe region performs actual movement")
		check(world.gold==previous_gold-int(next.price),"each safe region charges exact original fee")
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
		check(saved.position==[next.destination.x,next.destination.y] and int(saved.gold)==world.gold,"each safe region persists destination and charge")
		actual_moves.append({"schedule":int(row.schedule),"link":int(row.link),"price":int(next.price),"destination":[next.destination.x,next.destination.y]})
	var ready_count: int=0
	for row: Dictionary in scan:
		if bool(row.ok): ready_count+=1
	check(actual_moves.size()==ready_count and ready_count>0,"every initially safe and saveable source destination executed")
	await finish(world)
