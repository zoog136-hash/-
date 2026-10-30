extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: failures.append(why); printerr("COMPACT_CATALOG_FAIL "+why)
func _run() -> void:
	root.size = Vector2i(854,480)
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for frame: int in range(12): await process_frame
	_check(QA.enter_game(world),"class selection through production signals")
	world.save_timer = -10000
	world.set_process(false)
	world.player.set_physics_process(false)
	var hud: Node = world.hud
	for category: String in ["아이템","변신","마법인형","성물"]:
		hud.open_catalog(category)
		hud._on_catalog_item_selected(0)
		hud._set_catalog_detail_view(true)
		for frame: int in range(6): await process_frame
		var detail: RichTextLabel = hud.catalog_detail
		var preview: Control = hud.catalog_preview
		var scroll: ScrollContainer = hud.catalog_body_actions
		_check(detail.is_visible_in_tree() and detail.size.y >= 160,"description has readable height "+category)
		_check(preview.is_visible_in_tree() and preview.size.y >= 160,"existing artwork retains visible preview "+category)
		_check(scroll.size.x >= hud.workspace.content.size.x-24,"detail uses compact viewport width "+category)
		_check(not detail.text.is_empty(),"actual selected record binds description "+category)
		_check((scroll.get_child(0) as Control).size.y <= scroll.size.y+1 or scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page,"actions fit or remain scrollable without collapsing preview "+category)
		hud._set_catalog_detail_view(false)
		await process_frame
		_check(hud.catalog_body_left.is_visible_in_tree() and not scroll.is_visible_in_tree(),"return to actual list "+category)
	world.queue_free()
	await process_frame
	print("COMPACT_CATALOG_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
