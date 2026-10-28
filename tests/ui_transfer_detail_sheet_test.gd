extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);print("TRANSFER SHEET FAIL ",message)
func frames() -> void:
	for i: int in range(6):await process_frame
func touch(point: Vector2,index: int,down: bool) -> void:
	var event:=InputEventScreenTouch.new();event.position=point;event.index=index;event.pressed=down;root.push_input(event,true)
func tap(control: Control) -> void:
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5);touch(point,85,true);touch(point,85,false)
func select_hp(view: Node) -> void:
	for i: int in range(view.entries.size()):
		if str(view.entries[i].name)=="HP 물약":
			var point: Vector2=view.listing.get_global_transform_with_canvas()*view.listing.get_item_rect(i).get_center()
			touch(point,86,true);touch(point,86,false);return
	check(false,"existing HP potion row")
func run() -> void:
	root.size=Vector2i(1280,720)
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);await frames()
	check(QA.enter_game(world),"class selection")
	world.save_timer=-100000;world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	world._update_hud()
	var hud: Node=world.hud
	var physical: Dictionary=world.item_instances.duplicate(true)
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await frames()
		var count_before: int=int(world.inventory.get("HP 물약",0))
		var gold_before: int=world.gold
		hud.open_warehouse();await frames()
		var screen: Control=hud.workspace.content.get_child(0)
		select_hp(screen);await frames();screen.quantity.value=2;await frames()
		check(screen.transfer_sheet.title.text=="HP 물약" and screen.transfer_sheet.count_label.text.contains("선택 2개"),"native deposit selection matches name and quantity")
		check(screen.listing.fixed_icon_size==Vector2i(54,54) and screen.listing.max_columns==4,"warehouse uses the inspected four-column slots")
		check(screen.listing.get_item_metadata(0)!=null,"stable item identities survive quantity-only captions")
		tap(screen.action);await frames()
		var confirm: Control=hud.get_node_or_null("Root/TwilightConfirmation")
		check(confirm!=null,"deposit uses the existing confirmation")
		if confirm!=null:tap(confirm.confirm_button);await frames()
		check(int(world.inventory.get("HP 물약",0))==count_before-2 and int(world.warehouse.stacks.get("HP 물약",0))==2,"confirmed deposit moves exactly two items")
		screen=hud.workspace.content.get_child(0)
		tap(screen.find_child("WarehouseWithdrawTab",true,false));await frames()
		check(screen.mode.selected==1 and screen.action.text=="찾기","native withdraw tab selects the original direction")
		select_hp(screen);await frames();screen.quantity.value=2;await frames()
		tap(screen.action);await frames();confirm=hud.get_node_or_null("Root/TwilightConfirmation")
		check(confirm!=null,"withdraw confirmation")
		if confirm!=null:tap(confirm.confirm_button);await frames()
		check(int(world.inventory.get("HP 물약",0))==count_before and not world.warehouse.stacks.has("HP 물약") and world.gold==gold_before,"withdraw restores the stack without changing the economy")
		hud.open_item_sell();await frames();screen=hud.workspace.content.get_child(0)
		select_hp(screen);await frames();screen.quantity.value=3;await frames()
		check(screen.details.text.contains("120 아데나"),"authoritative existing potion appraisal is displayed")
		check(hud.workspace.content.get_global_rect().grow(1).encloses(screen.action.get_global_rect()),"sale action fits the small panel")
		tap(screen.action);await frames();confirm=hud.get_node_or_null("Root/TwilightConfirmation")
		check(confirm!=null,"sale confirmation")
		if confirm!=null:tap(confirm.cancel_button);await frames()
		check(int(world.inventory.get("HP 물약",0))==count_before and world.gold==gold_before,"canceled sale changes nothing")
		tap(screen.action);await frames();confirm=hud.get_node_or_null("Root/TwilightConfirmation")
		if confirm!=null:tap(confirm.confirm_button);await frames()
		check(int(world.inventory.get("HP 물약",0))==count_before-3 and world.gold==gold_before+120,"confirmed sale uses the existing quantity and payment")
		screen=hud.workspace.content.get_child(0)
		for i: int in range(screen.entries.size()):
			var entry: Dictionary=screen.entries[i]
			if not str(entry.get("instance_id","")).is_empty():
				var reference: String=str(entry.name)+"@@@"+str(entry.instance_id)
				world._set_item_locked(reference,true)
				screen._select(i)
				check(screen.action.disabled and screen.details.text.contains("잠긴"),"existing physical-item lock is visible before sale confirmation")
				world._set_item_locked(reference,false)
				screen._quote();break
		screen.search.text="__NO_ITEM__";screen.search.text_changed.emit(screen.search.text);await frames()
		check(screen.action.disabled and screen.transfer_sheet.picture.texture==null and screen.transfer_sheet.title.text=="선택한 아이템 없음","empty search clears previous sale data")
		hud._close_workspace()
	check(world.item_instances==physical,"stack transactions and UI browsing preserve all physical equipment IDs and records")
	await RenderingServer.frame_post_draw
	world.queue_free();await process_frame
	if failures.is_empty():print("UI_TRANSFER_DETAIL_SHEET_OK");quit(0)
	else:print("UI_TRANSFER_DETAIL_SHEET_FAILED ",failures);quit(1)
