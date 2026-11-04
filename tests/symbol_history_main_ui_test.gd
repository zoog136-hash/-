extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var world
var rt
var clock: Dictionary={"unix":2000000000}
var checks: int=0
var failures: Array[String]=[]
var evidence: String=""
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("SYMBOL_HISTORY_UI_FAIL "+label)
func same(a: Variant,b: Variant) -> bool:return JSON.stringify(JSON.parse_string(JSON.stringify(a)),"",true,true)==JSON.stringify(JSON.parse_string(JSON.stringify(b)),"",true,true)
func view():return world.hud.workspace.find_child("GrowthView",true,false)
func frames() -> void:
	for i: int in range(3):await process_frame
func freeze() -> void:
	world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false)
	for mob: TwilightMonster in world.monsters_root.get_children():mob.set_physics_process(false)
func tap(button: Control) -> void:
	if button==null:check(false,"missing native button");return
	if view().scroll.is_ancestor_of(button):view().scroll.ensure_control_visible(button);await frames()
	for down: bool in [true,false]:
		var event=InputEventScreenTouch.new();event.index=89;event.pressed=down;event.position=button.get_global_transform_with_canvas()*(button.size/2);root.push_input(event,true)
	await frames()
func prepare(action: String) -> void:
	view()._refresh();await frames()
	var name: String="GrowthAction_reset1" if action=="reset" else "GrowthHistory_"+action
	if DisplayServer.get_name()!="headless":await tap(view().find_child(name,true,false))
	else:view()._prepare(action,"eva",1)
	await frames()
func confirm() -> void:
	if DisplayServer.get_name()!="headless":await tap(view().find_child("GrowthConfirm",true,false))
	else:view()._confirm()
	await frames()
func capture(label: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name()=="headless":return
	await frames();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(label+".png"))==OK,"actual history UI capture "+label)
func act(action: String) -> Dictionary:return rt.execute(action,"eva",1,int(rt.state.revision))
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="):evidence=arg.trim_prefix("--evidence=")
	if not evidence.is_empty():DirAccess.make_dir_recursive_absolute(evidence)
	root.size=Vector2i(1280,720);world=load("res://Main.tscn").instantiate();root.add_child(world)
	check(QA.enter_game(world,"마법사"),"actual Main wizard entry");freeze();rt=world.growth
	rt.restore(rt.empty_state());rt.state.points=100000
	rt.history.test_now=func() -> int:return int(clock.unix)
	var row: Dictionary=rt.source523.item_record(231772)
	world.inventory[row.name]=3
	for id: String in ["history_scroll1","history_scroll2","history_scroll3"]:world.item_instances[id]={"name":row.name,"level":0,"record":row.duplicate(true)}
	check(not rt.quote("restore_emblem","eva").ok and not rt.quote("save_emblem","eva").ok,"legacy empty save has no manufactured past")
	for i: int in range(2):check(act("enhance").ok,"real enhancement creates checkpoint source")
	var initial: Dictionary=rt.progress("eva");var wallet: int=int(rt.state.points)
	world.hud.open_growth("emblems");await frames()
	check(view().find_child("GrowthHistory_save_emblem",true,false)!=null,"history actions in existing native symbol menu")
	await prepare("save_emblem")
	check(view().result.text.contains("자체 보관료 0") and not view().request.is_empty(),"native save confirmation shows configured zero cost")
	var state: Dictionary=rt.state.duplicate(true)
	if DisplayServer.get_name()!="headless":await tap(view().find_child("GrowthCancel",true,false))
	else:view().request={};view()._refresh()
	check(same(rt.state,state) and rt.state.points==wallet,"native save cancellation consumes nothing")
	await prepare("save_emblem");await confirm()
	check(same(rt.history.record("eva").progress,initial) and not rt.history.record("eva").used and int(rt.state.points)==wallet,"native save persists exact real record only")
	var ticket: int=int(rt.history.record("eva").ticket)
	view()._confirm();check(int(rt.history.record("eva").ticket)==ticket,"repeat release cannot mint another receipt")
	check(not rt.quote("save_emblem","eva").ok and not rt.quote("restore_emblem","eva").ok,"identical current checkpoint not duplicated")
	for i: int in range(2):check(act("enhance").ok,"continue real enhancement after snapshot")
	var current_principal: int=int(rt.progress("eva").spent)
	var invested_balance: int=int(rt.state.points)+current_principal
	await prepare("restore_emblem")
	check(view().result.text.contains("자체 수수료 100") and view().result.text.contains("일일 초기화1회"),"native restore confirmation shows principal settlement, fee and quota")
	await capture("symbol523-history-restore-confirm-1280x720")
	state=rt.state.duplicate(true)
	if DisplayServer.get_name()!="headless":await tap(view().find_child("GrowthCancel",true,false))
	else:view().request={};view()._refresh()
	check(same(rt.state,state),"native restore cancellation preserves checkpoint and wallet")
	world._save_game(true)
	var sha: String=FileAccess.get_sha256(world.save_path())
	var inventory: Dictionary=world.inventory.duplicate(true);var ids: Dictionary=world.item_instances.duplicate(true)
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary) -> Error:return ERR_CANT_CREATE
	await prepare("restore_emblem");await confirm()
	check(view().result.text.contains("저장 실패") and same(rt.state,state) and same(world.inventory,inventory) and same(world.item_instances,ids) and FileAccess.get_sha256(world.save_path())==sha,"native restore write failure rolls back exact file, funds, items, checkpoint and day quota")
	await prepare("save_emblem");await confirm()
	check(view().result.text.contains("저장 실패") and same(rt.state,state) and FileAccess.get_sha256(world.save_path())==sha,"native overwrite write failure preserves old checkpoint")
	world.equipment_collections.test_save_writer=Callable()
	await prepare("restore_emblem");await confirm()
	check(same(rt.progress("eva"),initial) and rt.history.record("eva").used,"native restore replaces only selected real progress and consumes ticket")
	check(int(rt.state.points)+int(rt.progress("eva").spent)==invested_balance-100 and same(world.inventory,inventory) and same(world.item_instances,ids),"native restore conserves principal, spends fee100 and keeps all physical IDs/inventory")
	check(not rt.quote("reset","eva").ok and not rt.quote("restore_emblem","eva").ok,"same-day repeat and ordinary reset cannot bypass quota")
	await capture("symbol523-history-restore-result-1280x720")
	state=rt.state.duplicate(true);world._load_game(true);freeze()
	check(same(rt.state,state) and not rt.quote("restore_emblem","eva").ok and not rt.quote("save_emblem","eva").ok,"actual reconnect preserves consumed receipt and numeric-normalized identity")
	clock.unix+=86400
	check(act("enhance").ok,"next real enhancement is independent of saved receipt")
	await prepare("reset");check(not view().request.is_empty(),"next existing game-day resets allowance")
	state=rt.state.duplicate(true);sha=FileAccess.get_sha256(world.save_path())
	clock.unix+=86400;await confirm()
	check(view().result.text.contains("일자가 바뀌") and same(rt.state,state) and FileAccess.get_sha256(world.save_path())==sha and same(world.inventory,inventory),"confirmation across day boundary requires a fresh quote without spending")
	await prepare("reset")
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary) -> Error:return ERR_CANT_CREATE
	await confirm()
	check(view().result.text.contains("저장 실패") and same(rt.state,state) and same(world.inventory,inventory) and same(world.item_instances,ids) and FileAccess.get_sha256(world.save_path())==sha,"daily-reset write failure preserves receipt, quota, scroll and file")
	world.equipment_collections.test_save_writer=Callable()
	var refund: int=int(rt.progress("eva").spent);wallet=int(rt.state.points)
	await prepare("reset");await confirm()
	check(int(rt.progress("eva").attempts)==0 and rt.state.points==wallet+refund and int(world.inventory[row.name])==2 and world.item_instances.size()==ids.size()-1,"native reset refunds only current invested points, consumes one exact source-ID scroll")
	check(int(rt.state.symbol_daily.counts.eva)==1 and rt.history.record("eva").used,"daily reset and restoration history persist independently")
	state=rt.state.duplicate(true);world._load_game(true);freeze()
	check(same(rt.state,state) and not rt.quote("reset","eva").ok,"actual reconnect keeps daily consumption")
	clock.unix-=86400
	check(not rt.history.daily_offer("eva").ok and not rt.quote("save_emblem","eva").ok,"backward game date cannot reset high-water or issue new receipts")
	world._load_game(true);freeze()
	check(same(rt.state,state) and not rt.history.daily_offer("eva").ok,"reconnect at backward date preserves saved high-water unchanged")
	clock.unix+=3*86400
	for i: int in range(3):check(act("enhance").ok,"new actual run for restore-after-reset")
	var second: Dictionary=rt.progress("eva")
	await prepare("save_emblem");await confirm()
	check(int(rt.history.record("eva").ticket)>ticket and same(rt.history.record("eva").progress,second),"native overwrite stores different actual run and issues a newer ticket")
	await prepare("reset");await confirm()
	check(int(rt.progress("eva").attempts)==0,"native reset leaves recorded checkpoint intact")
	clock.unix+=86400;wallet=int(rt.state.points)
	await prepare("restore_emblem")
	check(view().result.text.contains("현재 강화 0포인트 반환"),"restore-after-reset confirmation requires saved principal again")
	await confirm()
	check(same(rt.progress("eva"),second) and int(rt.state.points)==wallet-int(second.spent)-100,"native restore-after-reset pays invested principal plus fee without duplicating refunded points")
	state=rt.state.duplicate(true);world._load_game(true);freeze()
	check(same(rt.state,state) and rt.history.record("eva").used and not rt.quote("restore_emblem","eva").ok,"restore-after-reset survives actual reconnect as consumed single-use receipt")
	print("SYMBOL_HISTORY_UI_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name()}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
