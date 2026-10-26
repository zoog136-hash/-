extends SceneTree

const QA=preload("res://tests/qa_class_selection.gd")
const Resolver=preload("res://scripts/ui/item_visual_resolver.gd")
var failures: Array[String]=[]

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);print("REMAINING UI FAIL ",message)
func frames() -> void:
	for i: int in range(6):await process_frame
func touch(point: Vector2,index: int,down: bool) -> void:
	var event:=InputEventScreenTouch.new()
	event.position=point;event.index=index;event.pressed=down
	root.push_input(event,true)

func run() -> void:
	root.size=Vector2i(1280,720)
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world);await frames()
	check(QA.enter_game(world),"class selection")
	world.save_timer=-100000;world.set_process(false);world.field_population.set_process(false)
	world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	world.gold=100000000;world._update_hud()
	var hud: Node=world.hud
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await frames()
		hud.open_detailed_status();await frames()
		var status: ScrollContainer=hud.status_view
		check(status.get_v_scroll_bar().max_value>status.get_v_scroll_bar().page,"real stat rows overflow "+str(extent))
		var point: Vector2=status.get_global_transform_with_canvas()*(status.size*.5)
		touch(point,81,true)
		var drag:=InputEventScreenDrag.new()
		drag.index=81;drag.position=point+Vector2(0,-100);drag.relative=Vector2(0,-100)
		root.push_input(drag,true);touch(drag.position,81,false);await frames()
		check(status.scroll_vertical>0,"native stat swipe reveals lower rows "+str(extent))
		check((status.get("values") as Dictionary).has("max_weight"),"existing last stat is retained")
		hud.detail_window.hide()
		hud.open_skills();await frames()
		var view: Control=hud.skills_view
		var index: int=-1
		for i: int in range(view.filtered.size()):
			var record: Dictionary=view.filtered[i]
			if record.get("origin","")=="LINEAGEM_20250617" and world.original_skills.catalog.reason(record,true).is_empty():index=i;break
		check(index>=0,"real available skill-book fixture")
		if index>=0:
			var record: Dictionary=view.filtered[index]
			world.inventory[str(record.book_name)]=1
			view.select(index)
			check(not view.learn_button.disabled and not view.book_button.disabled and not view.preview_button.disabled,"valid acquisition and preview remain available")
			view.preview_container.show()
		var before_inventory: Dictionary=world.inventory.duplicate(true)
		var before_learned: Dictionary=world.original_skills.catalog.learned.duplicate(true)
		view.search.text="__NO_SKILL__";view.search.text_changed.emit(view.search.text);await frames()
		for button: Button in [view.learn_button,view.book_button,view.use_button,view.quick_button,view.preview_button]:check(button.disabled,"empty filter disables stale action "+button.name)
		check(view.selected.is_empty() and view.cooldown.text.is_empty() and not view.summon_controls.visible and not view.preview_container.visible,"empty result clears the previous skill and effects")
		view.search.clear();view.search.text_changed.emit("");await frames()
		check(not view.selected.is_empty() and not view.preview_button.disabled,"clearing search restores real selection and preview")
		check(world.inventory==before_inventory and world.original_skills.catalog.learned==before_learned,"search never buys, learns, or consumes a book")
		hud._close_workspace()
	var icon: Dictionary=Resolver.describe({},"초록 잎")
	check(icon.route=="twilight_local_item" and icon.path=="res://assets/ui/items/green_leaf_painted.png","local leaf resolves its own painted art")
	var texture: Texture2D=Resolver.texture({},"초록 잎")
	check(texture!=null and texture.get_width()==256,"new icon imports at its UI budget without changing source PNG")
	var rejected: Dictionary=Resolver.describe({"sourceId":"not-a-leaf-id","name":"초록 잎"},"초록 잎")
	check(rejected.path!=icon.path,"a publisher ID cannot borrow the local item binding")
	await RenderingServer.frame_post_draw
	world.queue_free();await process_frame
	if failures.is_empty():print("UI_REMAINING_STATES_OK");quit(0)
	else:print("UI_REMAINING_STATES_FAILED ",failures);quit(1)
