extends SceneTree
## User list 2026-11-21 #19: the original bag could not be dragged down to
## its last row. A drag that starts on an item slot is captured by the HUD's
## PointerTransfer (it consumes the touch), so the original list never saw it.
## Real ScreenTouch/ScreenDrag on the actual Main: many original items, swipe
## up on slots until the end, the last row's slots are inside the original
## ScrollView and a tap there selects that item; swipe down returns to the top.
## Everything written under user:// is put back at the end.
const QA = preload("res://tests/qa_class_selection.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var user_files: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("INVENTORY_TOUCH_SCROLL_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func frames(count: int = 6) -> void:
	for frame: int in range(count): await process_frame

func touch(at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0; event.position = at; event.pressed = pressed
	root.push_input(event,true)

func drag(at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0; event.position = at; event.relative = relative
	root.push_input(event,true)

func swipe(from: Vector2, dy: float, steps: int = 6) -> void:
	touch(from,true); await process_frame
	for step: int in range(1,steps+1):
		drag(from+Vector2(0,dy*step/steps),Vector2(0,dy/steps)); await process_frame
	touch(from+Vector2(0,dy),false); await frames(4)

func tap(at: Vector2) -> void:
	touch(at,true); await process_frame
	touch(at,false); await frames(6)

func snapshot_user(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for file: String in dir.get_files(): user_files[path.path_join(file)] = FileAccess.get_file_as_bytes(path.path_join(file))
	for sub: String in dir.get_directories(): snapshot_user(path.path_join(sub))

func restore_user(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for sub: String in dir.get_directories(): restore_user(path.path_join(sub))
	for file: String in dir.get_files():
		var full: String = path.path_join(file)
		if not user_files.has(full): DirAccess.remove_absolute(full)
	for full: String in user_files:
		if full.get_base_dir() != path: continue
		var current: PackedByteArray = FileAccess.get_file_as_bytes(full) if FileAccess.file_exists(full) else PackedByteArray()
		if current != user_files[full]:
			var out := FileAccess.open(full,FileAccess.WRITE)
			if out != null: out.store_buffer(user_files[full]); out.close()

func center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas()*(control.size*0.5)

## Original items, one physical row each, until the bag has `count` rows.
func grant_rows(world: Node, count: int) -> int:
	var grants: Array = []
	for record: Dictionary in world.catalog_db.get("아이템",[]):
		if grants.size() >= count: break
		if record.get("source_m_native_item") != true: continue
		var id: int = int(record.get("source_item_class_id",0))
		var grant: Dictionary = {"item_class_id":id,"amount":1 if D.equipment(record) else 2,"bless_raw":1,"enchant":0}
		if id <= 0 or not INVENTORY.stage(world,[grant],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"}).get("ok",false): continue
		grants.append(grant)
	var staged: Dictionary = INVENTORY.stage(world,grants,{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not staged.get("ok",false): return 0
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	world._update_hud(); world.hud.refresh_inventory(world.inventory)
	return grants.size()

## The slot center of each built hit, top-left first.
func ordered_hits(view: RefCounted) -> Array:
	var rows: Array = []
	for reference: String in view._hits:
		var control: Control = view._hits[reference].control
		if is_instance_valid(control) and control.is_visible_in_tree(): rows.append({"reference":reference,"point":center(control),"row":int(view._hits[reference].get("row",0))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.point.y < b.point.y or a.point.y == b.point.y and a.point.x < b.point.x)
	return rows

func finish(world: Node) -> void:
	world.queue_free()
	await frames(4)
	restore_user("user://")
	print("INVENTORY_TOUCH_SCROLL_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(1 if not failures.is_empty() else 0)

func run() -> void:
	snapshot_user("user://")
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world._clear_monsters()
	await frames(30)
	var hud: Node = world.hud
	if DEF.not_installed() or not is_instance_valid(hud.get("original_main_ui_controller")):
		# CI has neither the original pack nor the original bag: the scroll
		# forward must stay inert there.
		check(hud.original_inventory_scroll_by(-40.0).is_empty(), "no original bag: the scroll forward does nothing")
		evidence["mode"] = "no_original_pack"
		await finish(world); return
	evidence["granted"] = grant_rows(world,60)
	var opened: int = Time.get_ticks_usec()
	hud.toggle_inventory()
	evidence["open_call_usec"] = Time.get_ticks_usec() - opened
	if not check(hud.original_inventory_is_open(), "the original bag opens on the input frame"):
		await finish(world); return
	var view: RefCounted = hud.original_main_ui_controller._inventory_view
	check(not view._hits.is_empty() and view._line_scenes.is_empty(), "the authored row is usable before further rows are mounted")
	var mounted: int = int(view.stats.line_builds)
	var slices: Array[int] = []
	for frame: int in range(12):
		var started: int = Time.get_ticks_usec()
		await process_frame
		slices.append(Time.get_ticks_usec() - started)
		var count: int = int(view.stats.line_builds)
		check(count - mounted <= 1, "at most one additional row was mounted this frame")
		mounted = count
		if view._opening_line_tree == null: break
	evidence["open_frame_usec"] = slices
	var visible_rows: Vector2i = view.line_range(view.COLD_OPEN_BUILD_LINES)
	var complete: bool = visible_rows.x <= visible_rows.y
	for line: int in range(visible_rows.x,visible_rows.y+1):
		if not view._line_scenes.has(line): complete = false
	check(complete and view._opening_line_tree == null, "all visible original rows complete within the opening frames")
	await frames(6)
	var lines: int = view._lines.size()
	evidence["lines"] = lines+1
	evidence["scroll"] = [view._scroll_top,view._scroll_bottom]
	check(lines >= 6, "more rows than the original ScrollView shows (%d)" % (lines+1))
	var area: Control = view._scroll_content.get_parent().call("input_control")
	var area_rect: Rect2 = area.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,area.size)
	var top_position: float = view._scroll_content.position.y
	# Swipe up on item slots (fast, mostly vertical: PointerTransfer "scroll").
	var swipes: int = 0
	while swipes < 30 and view._scroll_content.position.y > view._scroll_bottom+0.5:
		var hits: Array = ordered_hits(view)
		var start: Vector2 = Vector2.INF
		for hit: Dictionary in hits:
			if area_rect.grow(-10).has_point(hit.point) and hit.point.y > area_rect.get_center().y: start = hit.point; break
		if not start.is_finite(): break
		check(not hud.original_inventory_hit_at(start).is_empty(), "each swipe starts on an item slot")
		await swipe(start,-150.0)
		swipes += 1
	evidence["swipes"] = swipes
	evidence["end_position"] = view._scroll_content.position.y
	check(swipes > 0 and swipes < 30, "swipes that start on a slot scroll the original rows (%d swipes)" % swipes)
	check(absf(view._scroll_content.position.y-view._scroll_bottom) < 0.5, "the rows reach their last position (%s of %s)" % [view._scroll_content.position.y,view._scroll_bottom])
	check(view._line_scenes.has(lines), "the last row is built at the end")
	var last_refs: Array = (view._lines[lines-1] as Dictionary).values()
	var shown: int = 0
	var last_point: Vector2 = Vector2.INF
	for reference: String in last_refs:
		if not view._hits.has(reference): continue
		var control: Control = view._hits[reference].control
		var rect: Rect2 = control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)
		if area_rect.grow(1.0).encloses(rect) and not hud.original_inventory_hit_at(rect.get_center()).is_empty():
			shown += 1; last_point = rect.get_center()
	evidence["last_row"] = [last_refs.size(),shown]
	check(shown == last_refs.size(), "every slot of the last row is inside the original ScrollView (%d/%d)" % [shown,last_refs.size()])
	if last_point.is_finite():
		var reference: String = str(hud.original_inventory_hit_at(last_point).reference)
		await tap(last_point)
		check(hud.lineage_inventory_ui.selected_item == reference, "a tap on the last row selects that item")
	# Swipe down returns to the top.
	swipes = 0
	while swipes < 30 and view._scroll_content.position.y < top_position-0.5:
		var start: Vector2 = Vector2.INF
		for hit: Dictionary in ordered_hits(view):
			if area_rect.grow(-10).has_point(hit.point): start = hit.point; break
		if not start.is_finite(): break
		await swipe(start,150.0)
		swipes += 1
	check(absf(view._scroll_content.position.y-top_position) < 0.5, "swipes down on slots return to the first row")
	# A short tap is still a tap, not a scroll.
	var before: float = view._scroll_content.position.y
	var first: Array = ordered_hits(view)
	if not first.is_empty():
		await tap(first[0].point)
		check(view._scroll_content.position.y == before and hud.lineage_inventory_ui.selected_item == str(first[0].reference), "a tap selects without scrolling")
	hud.toggle_inventory()
	await frames(6)
	await finish(world)
