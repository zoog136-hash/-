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
		button.get_viewport().push_input(event,true)
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
	var pack: String=OS.get_environment("GUARDIAN_ORIGINAL_MEDIA_PACK")
	check(not pack.is_empty(),"explicit verified private original input")
	var rt=world.growth
	world.inventory["수호석"]=1000;world.inventory["다이아"]=1195
	var currency=preload("res://scripts/loot/currency_drops.gd")
	var random:=RandomNumberGenerator.new();random.seed=523
	var earned: Dictionary={}
	for trial: int in range(30):
		var drops: Array=currency.roll([],"fixture","faith_01",world.loot_catalog,random,1.0)
		if not drops.is_empty() and int(drops[0].quantity)>=5:earned=drops[0];break
	check(not earned.is_empty(),"existing non-Aden currency policy supplies a1..10 stack")
	var ground=world._spawn_ground_drop("다이아",world.player.global_position,int(earned.quantity))
	check(world.inventory["다이아"]==1195,"spawned diamond stays on ground until pickup")
	ground.visible_since=Time.get_ticks_msec()-1000
	check(world._collect_ground_drop(ground),"real ground pickup API accepts in-range diamond")
	var diamonds: int=1195+int(earned.quantity)
	check(int(world.inventory["다이아"])==diamonds,"existing earned inventory balance updated by pickup")
	var fixture: Dictionary=rt.state.duplicate(true)
	grant_path(rt,fixture,"source523_2112");rt.restore(fixture)
	check(world._save_game(true)==OK,"fixture saved before presentation installation")
	var save_hash: String=FileAccess.get_sha256(world.save_path())
	world.hud.open_growth("guardians");await frames()
	var view=world.hud.workspace.find_child("GrowthView",true,false)
	var install: Control=view.find_child("GuardianInstallOriginalMedia",true,false)
	view.scroll.ensure_control_visible(install);await frames();tap(install);await frames()
	var dialog: FileDialog=view.find_child("GuardianOriginalMediaFile",true,false)
	check(dialog!=null and dialog.visible,"native source pack file selector opened")
	dialog.current_path=pack;await frames()
	# FileDialog's programmatic current_path does not select a row. Select the
	# verified filename fixture through its actual ItemList handler, then tap OK.
	var selected_file: bool=false
	for list: Node in dialog.find_children("*","ItemList",true,false):
		for index: int in range(list.item_count):
			if list.get_item_text(index)==pack.get_file():
				list.select(index);list.item_selected.emit(index);selected_file=true
	await frames()
	check(selected_file and not dialog.get_ok_button().disabled,"source archive selected through actual file-list handler")
	tap(dialog.get_ok_button());await frames()
	check(preload("res://scripts/growth/guardian_media.gd").installed(),"file selection installs exact original pack")
	check(FileAccess.get_sha256(world.save_path())==save_hash and int(world.inventory["다이아"])==diamonds,"install leaves progression save and currency unchanged")
	var board: ScrollContainer=view.find_child("GuardianSourceBoard",true,false)
	var button: Control=view.find_child("GuardianNode_source523_2112",true,false)
	board.ensure_control_visible(button);view.scroll.ensure_control_visible(button);await frames();tap(button);await frames()
	var upgrade: Dictionary=rt.guardian_source.upgrade("source523_2112",1)
	var probability: float=upgrade.Probability;upgrade.Probability=1000000
	button=view.find_child("GuardianAction_guardian_enchant",true,false)
	view.scroll.ensure_control_visible(button);await frames();tap(button);await frames();tap(view.find_child("GrowthConfirm",true,false))
	await process_frame;await process_frame
	upgrade.Probability=probability
	check(rt.guardian_level("source523_2112")==1 and world.inventory["수호석"]==990,"real enchant consumes source cost and records upgraded node")
	button=view.find_child("GuardianNode_source523_2112",true,false)
	board=view.find_child("GuardianSourceBoard",true,false)
	board.ensure_control_visible(button);view.scroll.ensure_control_visible(button)
	await frames()
	var glow: Control=button.get_node_or_null("GuardianOriginalGlow")
	check(glow!=null and not glow.frame_key.is_empty(),"successful source node plays original texture track")
	await capture("guardian-original-glow-private")
	await create_timer(1.4).timeout
	check(button.get_node_or_null("GuardianOriginalGlow")==null,"original effect ends at source clip boundary")
	check(not rt.state.has("guardian_wallet"),"earned route uses no development credit")
	button=view.find_child("GuardianAction_guardian_reset",true,false)
	view.scroll.ensure_control_visible(button);await frames();tap(button);await frames()
	await capture("guardian-earned-diamonds-reset-confirm")
	tap(view.find_child("GrowthConfirm",true,false));await frames()
	check(not rt.state.nodes.has("source523_2112") and world.inventory["다이아"]==diamonds-1200,"native reset consumes earned inventory diamonds")
	check(world.inventory["수호석"]==1000 and not rt.state.has("guardian_wallet"),"recorded enchant refunded without fabricating debug currency")
	await capture("guardian-earned-diamonds-reset-result")
	world._load_game(true);await frames()
	check(world.inventory["다이아"]==diamonds-1200 and not rt.state.nodes.has("source523_2112"),"earned reset persists through full Main save reload")
	check(preload("res://scripts/growth/guardian_media.gd").installed(),"presentation installation survives full game reload")
	world.queue_free();await process_frame
	print("GUARDIAN_MEDIA_UI_OK: ",checks," checks; ",RenderingServer.get_video_adapter_name())
	quit(0)
