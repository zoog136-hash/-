extends SceneTree
## Real Main with native touch controls; only topology and outcome RNG are QA fixtures.
var world
var view
var directory: String
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frames() -> void:
	for i: int in range(5):await process_frame
func tap(button: Control) -> void:
	check(button!=null,"native button exists")
	if button==null:return
	var point: Vector2=button.get_global_transform_with_canvas()*(button.size/2)
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=87;event.position=point;event.pressed=pressed
		button.get_viewport().push_input(event,true)
func press(name: String) -> void:
	var button: Control=view.find_child(name,true,false)
	if button!=null:
		var board: ScrollContainer=view.find_child("GuardianSourceBoard",true,false)
		if board!=null and board.is_ancestor_of(button):board.ensure_control_visible(button)
		if view.scroll.is_ancestor_of(button):view.scroll.ensure_control_visible(button)
	await frames();tap(button);await frames()
func action(name: String) -> void:
	await press("GuardianAction_"+name);await press("GrowthConfirm")
func reopen() -> void:
	world.hud._close_workspace();world.hud.open_growth("guardians");await frames()
	view=world.hud.workspace.find_child("GrowthView",true,false)
func grant(rt,fixture: Dictionary,id: String) -> void:
	for parent: String in rt.node(id).prerequisites:grant(rt,fixture,parent)
	if not fixture.nodes.has(id):fixture.nodes.append(id)
func capture(label: String) -> void:
	view.scroll.scroll_vertical=0;await frames();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"capture "+label)
func run() -> void:
	directory=OS.get_environment("GUARDIAN_CAPTURE_DIR");DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames()
	world.hud.complete_class_selection();world.set_process(false);world.player.set_physics_process(false);world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children():monster.set_physics_process(false)
	world.inventory["수호석"]=1000;world.inventory["다이아"]=1200
	world._save_game(true)
	await reopen()
	var presentation=view.guardian_presentation
	check(view.find_child("GuardianAuthoredNotice",true,false).text.contains("원본 아님"),"authored provenance visible")
	var save_hash: String=FileAccess.get_sha256(world.save_path())
	await press("GuardianPresentation_cards")
	await press("GuardianPresentation_volume") # default75 ->100
	check(not presentation.preferences.cards and presentation.preferences.volume==100,"native card/volume settings saved")
	check(FileAccess.get_sha256(world.save_path())==save_hash,"presentation settings do not alter game save")
	await press("GuardianNode_source523_2022");await action("activate")
	check(presentation.last_event=="open","real activation plays open cue")
	check(not view.card_faces[0].authored_art,"card display off leaves actionable placeholder")
	var rt=world.growth
	var winner: int=rt.state.searches.source523_2022.winner
	var loser: int=(winner+1)%3
	await press("GuardianCard_"+str(loser));await press("GrowthConfirm")
	check(presentation.last_event=="failure" and rt.state.searches.source523_2022.failed.has(loser),"real losing card plays failure")
	await capture("guardian-authored-card-off-failure")
	await press("GuardianPresentation_cards")
	await press("GuardianRetry");await press("GrowthConfirm")
	check(view.card_faces[0].authored_art,"authored card restored during actual retry")
	await press("GuardianCard_"+str(winner));await press("GrowthConfirm")
	check(presentation.last_event=="success" and rt.state.nodes.has("source523_2022"),"real winning card plays success")
	await capture("guardian-authored-card-success")
	await reopen()
	var fixture: Dictionary=rt.state.duplicate(true);grant(rt,fixture,"source523_2112");rt.restore(fixture)
	await reopen();await press("GuardianNode_source523_2112")
	var upgrade: Dictionary=rt.guardian_source.upgrade("source523_2112",1)
	var probability: float=upgrade.Probability;upgrade.Probability=0
	await action("guardian_enchant")
	check(presentation.last_event=="failure" and rt.guardian_level("source523_2112")==0,"real failed enchant plays failure")
	var stones: int=world.inventory["수호석"]
	var state: Dictionary=rt.state.duplicate(true)
	var played: int=presentation.played
	world.source_save_blocked=true
	await action("guardian_enchant")
	check(presentation.played==played and rt.state==state and world.inventory["수호석"]==stones,"failed game save rolls transaction back with no outcome audio")
	world.source_save_blocked=false;upgrade.Probability=1000000
	await action("guardian_enchant");upgrade.Probability=probability
	check(presentation.last_event=="success" and rt.guardian_level("source523_2112")==1,"real successful enchant plays success")
	await capture("guardian-authored-enchant-success")
	await press("GuardianNode_source523_2022");await action("representative")
	check(presentation.last_event=="representative" and rt.guardian_representative(222)=="source523_2022","real representative change plays authored cue")
	await press("GuardianAction_guardian_reset")
	played=presentation.played;await press("GrowthCancel")
	check(presentation.played==played,"cancel has no outcome cue")
	await action("guardian_reset")
	check(presentation.last_event=="reset" and not rt.state.nodes.has("source523_2112") and world.inventory["다이아"]==0,"real paid reset plays cue")
	world.presentation_audio.muted=true
	check(not presentation.play_confirmed("success"),"global presentation mute also suppresses guardian fallback")
	world.presentation_audio.muted=false
	await press("GuardianPresentation_sounds")
	check(not presentation.preferences.sounds,"native mute saved")
	played=presentation.played
	await press("GuardianNode_source523_2022");await action("activate")
	check(presentation.played==played,"muted real activation is silent")
	await reopen()
	check(view.guardian_presentation==presentation and not presentation.preferences.sounds and presentation.played==played,"reentry retains one service without replaying cues")
	world._load_game(true);await reopen()
	check(not presentation.preferences.sounds and presentation.preferences.cards and presentation.preferences.volume==100,"settings survive full game reload")
	var blocked_path: String=presentation.settings_path+".blocked";DirAccess.make_dir_recursive_absolute(blocked_path)
	var original_path: String=presentation.settings_path;presentation.settings_path=blocked_path
	await press("GuardianPresentation_cards")
	check(presentation.preferences.cards and view.result.text.contains("저장 실패"),"native settings failure retains previous UI state")
	presentation.settings_path=original_path;DirAccess.remove_absolute(blocked_path)
	root.size=Vector2i(854,480);DisplayServer.window_set_size(root.size);await frames()
	await capture("guardian-authored-settings-854x480")
	world.queue_free();await process_frame
	print("GUARDIAN_AUTHORED_UI_RESULT: ",checks," checks, ",failures," failures; ",RenderingServer.get_video_adapter_name())
	quit(0 if failures==0 else 1)
