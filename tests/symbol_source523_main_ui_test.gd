extends SceneTree
## Real Main + existing HUD. All mutations use an isolated XDG test profile.
var failures: Array[String] = []
var checks: int = 0
var world
var evidence_dir: String = ""

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); print("SYMBOL523_MAIN_FAIL "+message)

func frames(count: int = 3) -> void:
	for index: int in range(count): await process_frame

func tap(button: Control, view: Control = null) -> void:
	if button == null: check(false,"missing UI button"); return
	if view != null and view.scroll.is_ancestor_of(button):
		view.scroll.ensure_control_visible(button)
		await frames()
	var position: Vector2 = button.get_global_transform_with_canvas()*(button.size/2)
	for pressed: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 97; event.position = position; event.pressed = pressed
		root.push_input(event,true)
	await frames()

func screenshot(name: String) -> void:
	if evidence_dir.is_empty() or DisplayServer.get_name()=="headless": return
	view().scroll.scroll_vertical = 0
	await frames()
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(evidence_dir.path_join(name+".png"))
	check(error==OK,"actual viewport capture "+name)

func view() -> Control:
	return world.hud.workspace.find_child("GrowthView",true,false)

func confirm(current: Control) -> void:
	await tap(current.find_child("GrowthConfirm",true,false),current)

func canonical(value: Variant) -> Variant:
	# Godot JSON decodes numbers as floats. Preserve every key/value while
	# comparing schema1's validated integral fields across serialization.
	if value is float and is_finite(value) and value==floorf(value): return int(value)
	if value is Array:
		var out: Array = []
		for entry: Variant in value: out.append(canonical(entry))
		return out
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value: out[str(key)] = canonical(value[key])
		return out
	return value

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--symbol-evidence-dir="): evidence_dir = arg.trim_prefix("--symbol-evidence-dir=")
	if not evidence_dir.is_empty(): DirAccess.make_dir_recursive_absolute(evidence_dir)
	root.size = Vector2i(1280,720)
	world = load("res://Main.tscn").instantiate(); root.add_child(world)
	world.set_process(false); world.player.set_physics_process(false)
	world.field_population.set_process(false)
	await frames(5)
	world.hud.complete_class_selection()
	var rt = world.growth
	check(rt.config.get("source_snapshot")=="patch523","Main uses actual523 growth runtime")
	check(rt.config.emblems.size()==7,"all seven tabs retained")
	rt.restore(rt.empty_state())
	# Existing debug catalogue grant is explicit; it is not a normal loot grant.
	world._grant_playtest_catalog_variant("m523:item:117294",1)
	var physical: String = ""
	for id: String in world.item_instances:
		if not rt.source523.recharge(world.item_instances[id]).is_empty(): physical=id; break
	check(not physical.is_empty(),"real source catalogue grant pins ID")
	world.hud.toggle_menu(); await frames()
	await tap(world.hud.workspace.find_child("MenuTile_emblems",true,false))
	check(world.hud.active_section=="emblems" and view()!=null,"native menu opens existing emblem UI")
	var current: Control = view()
	check(current.find_child("GrowthTab_shilen",true,false)!=null,"seventh source tab reachable")
	await tap(current.find_child("GrowthRecharge_"+physical,true,false),current)
	check(not current.request.is_empty(),"physical holy water opens confirmation")
	await confirm(current)
	check(rt.state.points==100 and not world.item_instances.has(physical),"UI recharge consumes100 exact identity")
	check(current.result.visible and not current.result.text.is_empty(),"recharge result visible")
	var button: Button = current.find_child("GrowthAction_enhance1",true,false)
	check(button!=null and not button.disabled,"production first enhancement is enabled")
	await tap(button,current)
	check(current.request.get("action")=="enhance","native enhance opens cost confirmation")
	var before: int = int(rt.state.points)
	await confirm(current)
	check(rt.progress("eva").attempts==1 and rt.progress("eva").spent==20 and rt.state.points==before-20,"native confirmation persists source cost/result")
	check(current.result.visible and current.result.text.contains("강화 결과"),"enhancement result shown in same screen")
	check(current.diagram.stage==rt.progress("eva").stage,"stage diagram reflects committed result")
	await create_timer(1.4).timeout
	await screenshot("symbol523-enhancement-1280x720")
	world._grant_playtest_catalog_variant("m523:item:231772",1)
	world.hud.open_growth("emblems"); await frames(); current=view()
	check(not current.find_child("GrowthAction_reset1",true,false).disabled,"source reset scroll enables button")
	await tap(current.find_child("GrowthAction_reset1",true,false),current)
	await confirm(current)
	check(rt.progress("eva").stage==0 and rt.state.points==100,"UI reset refunds enhancement only")
	check(current.result.text.contains("환급"),"reset result visible")
	# A source-complete fixture permits testing the actual absolute UI without
	# simulating thirty random enhancement stages or granting production progress.
	var saved: Dictionary = rt.state.duplicate(true)
	saved.emblems["sayha"]={"stage":30,"attempts":10,"spent":0,"guaranteed":false,"absolute":0}
	rt.restore(saved)
	world.inventory["축복의 열쇠"]=40
	world.hud.open_growth("emblems"); await frames(); current=view()
	await tap(current.find_child("GrowthTab_sayha",true,false),current)
	var absolute: Button = current.find_child("GrowthAbsolute_absolute1",true,false)
	check(absolute!=null and not absolute.disabled,"supported source absolute grade1 exposed")
	check(current.find_child("GrowthAbsolute_absolute2",true,false).disabled,"unknown grade dependency stays disabled")
	await tap(absolute,current)
	check(current.request.get("action")=="absolute","absolute opens actual confirmation")
	await confirm(current)
	check(rt.progress("sayha").get("absolute_grades",[])==[1] and world.inventory["축복의 열쇠"]==0,"UI absolute commits exact40keys and grade")
	check(current.result.text.contains("절대 옵션 1 개방"),"absolute result shown")
	check(current.find_child("GrowthAbsoluteStatus",true,false)!=null,"owned absolute status is visible in current effects")
	await create_timer(1.4).timeout
	await screenshot("symbol523-absolute-1280x720")
	var expected: Dictionary = rt.state.duplicate(true)
	world._load_game(true)
	world.field_population.set_process(false)
	if canonical(rt.state) != canonical(expected):
		print("SYMBOL523_SAVE_EXPECTED ",JSON.stringify(expected))
		print("SYMBOL523_SAVE_ACTUAL ",JSON.stringify(rt.state))
	check(canonical(rt.state)==canonical(expected),"actual Main save/load preserves every state field and ledger across JSON numeric decoding")
	world.hud.open_growth("emblems"); await frames(); current=view()
	root.size=Vector2i(854,480); await frames(5); world.hud._fit_hud(); await frames()
	check(current.find_child("GrowthAction_enhance1",true,false)!=null,"small landscape keeps actions")
	var corner: Vector2 = root.get_final_transform()*world.hud.workspace.get_global_transform_with_canvas()*world.hud.workspace.size
	check(corner.x<=855 and corner.y<=481,"small landscape workspace fits")
	await screenshot("symbol523-ui-854x480")
	world.hud._close_workspace(); await frames()
	check(not world.hud.workspace.visible,"UI closes normally")
	print("SYMBOL523_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"renderer":DisplayServer.get_name()}))
	world.queue_free(); await frames()
	quit(0 if failures.is_empty() else 1)
