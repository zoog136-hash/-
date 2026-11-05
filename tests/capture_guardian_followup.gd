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
	world.inventory["수호석"]=1000;world.inventory["명예 코인"]=100;world.gold=10000
	var rt=world.growth
	var fixture: Dictionary=rt.state.duplicate(true)
	for id: String in ["source523_2931","source523_2961","source523_3001"]:grant_path(rt,fixture,id)
	rt.restore(fixture)
	world.hp=1;world.mp=0
	var maximum: int=world._effective_max_hp()
	world.hud.open_skills();await frames()
	var skills=world.hud.skills_view
	tap(skills.find_child("SkillGuardianSpecialTab",true,false));await frames()
	check(skills.guardian_scope_button.button_pressed and not skills.scope_buttons[0].button_pressed,"special tab selection displayed correctly")
	check(skills.guardian_cast_buttons.size()==3,"all three owned guardian active skills mounted in special tab")
	await capture("guardian-special-ready")
	var button: Control=skills.find_child("GuardianSpecial_source523_2931",true,false)
	skills.guardian_special_scroll.ensure_control_visible(button);await frames();tap(button);await frames()
	check(world.hp==mini(maximum,1501) and world.inventory["명예 코인"]==90,"native special tab cast heals and consumes ten coins")
	check(not rt.quote("guardian_cast","source523_2961").ok,"other heal shares cooldown")
	await capture("guardian-special-shared-cooldown")
	world._load_game(true);await frames()
	check(world.inventory["명예 코인"]==90 and not rt.quote("guardian_cast","source523_3001").ok,"full world reload preserves paid shared cooldown")
	world.hud.open_skills();await frames();skills=world.hud.skills_view
	tap(skills.find_child("SkillGuardianSpecialTab",true,false));await frames()
	button=skills.find_child("GuardianQuick_source523_2931",true,false)
	skills.guardian_special_scroll.ensure_control_visible(button);await frames();tap(button);await frames()
	check(world.hud.active_section=="quickbind","guardian quickslot registration opens real picker")
	var picker: Button=null
	for descendant: Node in world.hud.workspace.find_children("*","Button",true,false):
		if descendant.text=="왼쪽 1":picker=descendant;break
	tap(picker);await frames()
	check(world.quickslots[0].get("id",world.quickslots[0].get("skill_id",""))=="guardian:source523_2931","picker binds stable guardian ID")
	world.growth.state.guardian_cast_until["311"]=Time.get_unix_time_from_system()-1
	world.growth.sync_guardian_cooldowns();world.hp=1;world.mp=0
	world.hud._close_workspace();await frames();tap(world.hud.v20_quickslot_buttons[0]);await frames()
	check(world.inventory["명예 코인"]==80 and world.hp>1,"native HUD quickslot casts guardian heal")
	await capture("guardian-quickslot-cast")
	# Paid source search creates a real refund ledger, independently of topology fixture.
	check(rt.execute("activate","source523_2022",1,int(rt.state.revision)).ok,"paid reset fixture starts real source search")
	rt.state.searches.source523_2022.winner=0
	check(rt.execute("choose","",0,int(rt.state.revision)).ok,"paid reset fixture records exact spent stone")
	world.hud.open_growth("guardians");await frames()
	var view=world.hud.workspace.find_child("GrowthView",true,false)
	button=view.find_child("GuardianAction_guardian_debug_gems",true,false)
	view.scroll.ensure_control_visible(button);await frames();tap(button);await frames();tap(view.find_child("GrowthConfirm",true,false));await frames()
	check(int(rt.state.guardian_wallet.get("4",0))==1200,"manual debug currency shown and saved")
	button=view.find_child("GuardianAction_guardian_reset",true,false)
	view.scroll.ensure_control_visible(button);await frames();tap(button);await frames()
	await capture("guardian-reset-confirmation")
	tap(view.find_child("GrowthConfirm",true,false));await frames()
	check(not rt.state.nodes.has("source523_2022") and rt.state.nodes.has("source523_2931"),"native reset affects selected category")
	check(world.inventory["수호석"]==1000 and int(rt.state.guardian_wallet.get("4",0))==0,"native reset returns recorded stone and charges source diamonds")
	check(not rt.quote("guardian_cast","source523_2931").ok,"reset does not bypass skill cooldown")
	await capture("guardian-reset-result")
	world._load_game(true);await frames()
	check(not rt.state.nodes.has("source523_2022") and world.inventory["수호석"]==1000,"reset survives real save reload")
	root.size=Vector2i(854,480);DisplayServer.window_set_size(root.size);await frames()
	world.hud.open_skills();await frames();skills=world.hud.skills_view
	tap(skills.find_child("SkillGuardianSpecialTab",true,false));await frames()
	await capture("guardian-special-854x480")
	world.queue_free();await process_frame
	print("GUARDIAN_FOLLOWUP_UI_OK: ",checks," checks; ",RenderingServer.get_video_adapter_name())
	quit(0)
