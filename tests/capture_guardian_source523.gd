extends SceneTree
## Real Main/Compatibility renderer, isolated save directory supplied by caller.
var world
var directory: String
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		push_error(label)
		quit(1)
func frames() -> void:
	for i: int in range(5): await process_frame
func capture(label: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"capture "+label)
func tap(button: Control) -> void:
	check(button!=null,"button exists")
	var position: Vector2=button.get_global_transform_with_canvas()*(button.size/2)
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=87;event.position=position;event.pressed=pressed
		root.push_input(event,true)
func grant_path(rt, fixture: Dictionary, id: String) -> void:
	for parent: String in rt.node(id).prerequisites: grant_path(rt,fixture,parent)
	if not fixture.nodes.has(id): fixture.nodes.append(id)
func run() -> void:
	directory=OS.get_environment("GUARDIAN_CAPTURE_DIR")
	check(not directory.is_empty(),"explicit capture directory")
	DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	await frames()
	world.hud.complete_class_selection()
	world.set_process(false);world.player.set_physics_process(false);world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	world.inventory["수호석"]=1000
	world.hud.toggle_menu();await frames()
	tap(world.hud.workspace.find_child("MenuTile_guardians",true,false));await frames()
	check(world.hud.active_section=="guardians","real native menu route")
	var view: Control=world.hud.workspace.find_child("GrowthView",true,false)
	check(view.find_child("GuardianNode_source523_2022",true,false)!=null,"source nodes mounted")
	await capture("guardian-523-board-1280x720")
	var button: Control=view.find_child("GuardianNode_source523_2022",true,false)
	view.scroll.ensure_control_visible(button);await frames()
	var board: ScrollContainer=view.find_child("GuardianSourceBoard",true,false)
	var origin: Vector2=button.get_global_transform_with_canvas()*(button.size/2)
	var touch:=InputEventScreenTouch.new()
	touch.index=88;touch.position=origin;touch.pressed=true;root.push_input(touch,true)
	var drag:=InputEventScreenDrag.new()
	drag.index=88;drag.position=origin+Vector2(-170,0);drag.relative=Vector2(-170,0);root.push_input(drag,true)
	touch=InputEventScreenTouch.new();touch.index=88;touch.position=drag.position;touch.pressed=false;root.push_input(touch,true)
	await frames()
	check(board.scroll_horizontal>0 and view.selected_node.is_empty(),"horizontal native drag pans without selecting")
	board.scroll_horizontal=0;await frames();tap(button);await frames()
	check(view.selected_node=="source523_2022","native original root selection")
	var activate: Control=view.find_child("GuardianAction_activate",true,false)
	view.scroll.ensure_control_visible(activate);await frames()
	await capture("guardian-523-detail")
	tap(activate);await frames();tap(view.find_child("GrowthConfirm",true,false));await frames()
	check(world.growth.state.pending.get("node")=="source523_2022","source activation from UI")
	check(world.inventory["수호석"]==1000,"opening cards did not charge")
	view.scroll.scroll_vertical=0
	await capture("guardian-523-card-waiting")
	var winner: int=int(world.growth.state.searches.source523_2022.winner)
	var loser: int=(winner+1)%3
	button=view.find_child("GuardianCard_"+str(loser),true,false)
	view.scroll.ensure_control_visible(button);await frames();tap(button);await frames()
	tap(view.find_child("GrowthConfirm",true,false));await frames()
	check(world.growth.state.searches.source523_2022.failed.has(loser) and world.inventory["수호석"]==999,"UI failed result and cost")
	view.scroll.scroll_vertical=0
	await capture("guardian-523-card-failed")
	view._prepare("activate","source523_2022",1);view._confirm();await frames()
	world._load_game(true);world.hud.open_growth("guardians");await frames()
	view=world.hud.workspace.find_child("GrowthView",true,false)
	check(view.find_child("GuardianCard_"+str(loser),true,false).disabled,"failed card disabled after full reload")
	button=view.find_child("GuardianCard_"+str(winner),true,false)
	view.scroll.ensure_control_visible(button);await frames();tap(button);await frames()
	tap(view.find_child("GrowthConfirm",true,false));await frames()
	check(world.growth.state.nodes.has("source523_2022") and world.inventory["수호석"]==998,"UI successful unlock and exact cost")
	view.scroll.scroll_vertical=0
	await capture("guardian-523-card-success")
	world.hud._close_workspace();world.hud.open_growth("guardians");await frames()
	view=world.hud.workspace.find_child("GrowthView",true,false)
	# Reach a real enchantable node with an explicit topology fixture; UI cost,
	# chance and outcome still use unchanged production 523 rows.
	var fixture: Dictionary=world.growth.state.duplicate(true)
	grant_path(world.growth,fixture,"source523_2112")
	world.growth.restore(fixture);world._invalidate_equipment_static()
	world.hud._close_workspace();world.hud.open_growth("guardians");await frames()
	view=world.hud.workspace.find_child("GrowthView",true,false)
	board=view.find_child("GuardianSourceBoard",true,false)
	button=view.find_child("GuardianNode_source523_2112",true,false)
	board.ensure_control_visible(button);view.scroll.ensure_control_visible(button);await frames();tap(button);await frames()
	check(view.selected_node=="source523_2112","native enchantable source node selection")
	button=view.find_child("GuardianAction_guardian_enchant",true,false)
	view.scroll.ensure_control_visible(button);await frames()
	await capture("guardian-523-enchant-preview")
	var stones: int=int(world.inventory["수호석"])
	tap(button);await frames();tap(view.find_child("GrowthConfirm",true,false));await frames()
	check(world.inventory["수호석"]==stones-10,"source enchant UI consumes exact original cost")
	check(view.result.text.contains("수호성 강화 성공") or view.result.text.contains("수호성 강화 실패"),"enchant outcome shown in real view")
	await capture("guardian-523-enchant-result")
	world.hud._close_workspace();world.hud.open_growth("guardians");await frames()
	view=world.hud.workspace.find_child("GrowthView",true,false)
	root.size=Vector2i(854,480);DisplayServer.window_set_size(root.size);await frames()
	view.scroll.scroll_vertical=0
	await capture("guardian-523-board-854x480")
	view._select("christ");await frames()
	check(view.find_child("GuardianNode_source523_3272",true,false)!=null,"523 Crister category mounted")
	view._select("isilote");await frames()
	var quote: Dictionary=world.growth.quote("activate",str(world.growth.config.guardians[4].nodes[0].id))
	check(not quote.ok,"server restricted category remains guarded")
	await capture("guardian-523-server-condition")
	world.queue_free();await process_frame
	print("GUARDIAN_SOURCE523_UI_OK: ",checks," checks; ",RenderingServer.get_video_adapter_name())
	quit(0)
