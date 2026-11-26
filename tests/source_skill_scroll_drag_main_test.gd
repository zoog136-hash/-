extends SceneTree
## Actual Main gamescreen with its original UI44 installed, if selected.
## Never modifies a nonempty profile; no new images or server fixtures.
const QA=preload("res://tests/qa_class_selection.gd")
const L=preload("res://scripts/ui/reference_layout.gd")
var checks: int=0
var failures: Array[String]=[]
var w: Node
var h: Node
var controller: Node
var window: RefCounted
var pointer: Node

func _initialize() -> void:run.call_deferred()

func ck(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:failures.append(label);printerr("SKILL_SCROLL_DRAG_FAIL ",label)
	return ok

func frames(count: int=2) -> void:
	for i: int in count:await process_frame

func center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas()*(control.size*.5)

func touch(point: Vector2, pressed: bool, finger: int=7, canceled: bool=false) -> void:
	var event:=InputEventScreenTouch.new()
	event.index=finger;event.position=point;event.pressed=pressed;event.canceled=canceled
	root.push_input(event,true)

func dragged(point: Vector2, delta: Vector2, finger: int=7) -> void:
	var event:=InputEventScreenDrag.new()
	event.index=finger;event.position=point;event.relative=delta
	root.push_input(event,true)

func mouse(point: Vector2, pressed: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=pressed
	root.push_input(event,true)

func motion(point: Vector2, delta: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=point;event.relative=delta;event.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(event,true)

func swipe(start: Vector2, delta: Vector2) -> void:
	touch(start,true)
	dragged(start+delta,delta)
	touch(start+delta,false)
	await frames()

func run() -> void:
	var original: bool=not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty()
	root.size=Vector2i(2048,919)
	if ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"empty test user profile"):
		w=load("res://Main.tscn").instantiate()
		root.add_child(w);current_scene=w;w.set_process(false);w.save_timer=-100000
		ck(QA.enter_game(w),"actual Main character")
		w.field_population.set_process(false);w.player.set_physics_process(false);w._clear_monsters()
		h=w.hud;pointer=h.pointer_transfer
		if original:
			for frame: int in 20:
				if is_instance_valid(h.original_main_ui_controller):break
				await process_frame
		else:await frames()
		for index: int in w.quickslots.size():w.quickslots[index]={}
		w.ui_preferences.edited_quickslots[w.job_class]=true
		w._publish_player_hud(false)
		if original:
			h.toggle_menu();await frames(4)
			var skill_tile: Control=h.workspace.find_child("MenuTile_skills",true,false)
			if ck(is_instance_valid(skill_tile) and skill_tile.is_visible_in_tree(),"actual Main menu's skills touch target"):
				h.menu_scroll_view.ensure_control_visible(skill_tile);await frames()
				var at: Vector2=center(skill_tile)
				touch(at,true);touch(at,false)
		else:h.open_skills()
		await frames(3)
		controller=h.original_main_ui_controller
		if original:await exact()
		else:ck(not h.original_skill_window_is_open() and is_instance_valid(h.skills_view) and h.workspace.is_visible_in_tree(),"no-pack uses the existing skill workspace")
		w.queue_free();await frames()
	print("SKILL_SCROLL_DRAG_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"original_checked":original}))
	quit(0 if failures.is_empty() else 1)

func row_points() -> Dictionary:
	var result: Dictionary={}
	for slot: Dictionary in window._slots.values():
		var area: Control=slot.get("area")
		if not is_instance_valid(area):continue
		var at: Vector2=center(area)
		var hit: Dictionary=h.original_skill_window_hit_at(at)
		if hit.get("id")!=slot.id:continue
		var failure: String=w._quickslot_registration_error("skill",str(slot.id))
		var kind: String="learned" if failure.is_empty() else ("unlearned" if failure.contains("미습득") or failure.contains("습득") else "other")
		if not result.has(kind):result[kind]={"point":at,"id":slot.id}
	return result

func move_for_fixture(skill_id: String) -> Vector2:
	for index: int in window.records().size():
		if window._id(window.records()[index])!=skill_id:continue
		var row: int=index/window.COLUMNS
		var goal: float=clampf(window._view.y*.5-window.PITCH*(float(row)+.5),window._scroll_min,0.0)
		window._move_scroll(goal-window._scroll)
		var target: Control=window._slots.get(index,{}).get("area")
		if is_instance_valid(target) and h.original_skill_window_hit_at(center(target)).get("id")==skill_id:return center(target)
		break
	return Vector2.INF

func find_learned_fixture() -> String:
	for record: Dictionary in window.records():
		var id: String=window._id(record)
		if w._quickslot_registration_error("skill",id).is_empty():return id
	# A fresh disposable profile may have no active skill in this list.
	# Seed one existing eligible record while preserving every other value.
	var catalog: RefCounted=w.original_skills.catalog
	for record: Dictionary in window.records():
		var id: String=window._id(record)
		if str(record.get("activation",""))!="active" or not catalog.permitted(record):continue
		var previous: Variant=catalog.learned.get(id)
		catalog.learned[id]=1
		if w._quickslot_registration_error("skill",id).is_empty():
			window._stage()
			return id
		if previous==null:catalog.learned.erase(id)
		else:catalog.learned[id]=previous
	return ""

func edge_of_view() -> Vector2:
	var view: Control=window._scroll_area()
	for local_x: float in [1.0,view.size.x-1.0]:
		for row: float in [0.24,0.5,0.82]:
			var point: Vector2=view.get_global_transform_with_canvas()*Vector2(local_x,view.size.y*row)
			var hit: Dictionary=h.original_skill_window_hit_at(point)
			if not hit.is_empty() and hit.get("id","").is_empty():return point
	return Vector2.INF

func exact() -> void:
	if not ck(h.original_skill_window_is_open() and is_instance_valid(controller),"actual authored Skill_All opened: "+str(h.original_main_ui_status.get("skill_window",{})).left(350)):return
	window=controller.skill_window()
	if not ck(window._scroll_min<0.0 and window._scroll==0.0,"released skill list exceeds its viewport: "+str(window.last_result)):return
	var order: Array=window.records().map(func(record: Dictionary)->String:return window._id(record))
	var learned_id: String=find_learned_fixture()
	var start: Dictionary=row_points()
	if not ck(not learned_id.is_empty() and start.has("unlearned"),"actual source catalog has an eligible learned ID and a visible unlearned tile: "+str(start)):return
	var unlearned: Dictionary=start.unlearned
	var stable_slots: Array=w.quickslots.duplicate(true)
	var stable_cooldowns: Dictionary=w.skill_cooldowns.duplicate(true)
	var mp: int=w.mp
	var tile: Vector2=unlearned.point
	touch(tile,true)
	dragged(tile+Vector2(0,240),Vector2(0,240))
	touch(tile+Vector2(0,240),false)
	ck(window._scroll==0.0 and window.selected().is_empty(),"downwards from the top clamps without selecting")
	tile=move_for_fixture(learned_id)
	if not ck(tile.is_finite() and h.original_skill_window_hit_at(tile).get("id")==learned_id,"fixture displays the same actual learned row"):return
	var before_move: float=window._scroll
	var upward: bool=before_move>window._scroll_min+120.0
	var step_y: float=-64.0 if upward else 64.0
	touch(tile,true)
	dragged(tile+Vector2(0,step_y),Vector2(0,step_y))
	var first: float=window._scroll
	ck(not is_equal_approx(first,before_move) and pointer.mode=="scroll","vertical movement starts inside a learned tile and moves immediately")
	touch(tile+Vector2(8,-30),true,8)
	dragged(tile+Vector2(8,-240),Vector2(0,-210),8)
	touch(tile+Vector2(8,-240),false,8)
	ck(is_equal_approx(window._scroll,first) and pointer.pointer==7,"second finger does not move or end the captured list")
	var outside: Vector2=Vector2(tile.x,0 if upward else root.size.y-2)
	dragged(outside,outside-(tile+Vector2(0,step_y)))
	ck(window._scroll<first if upward else window._scroll>first,"the same swipe continues outside the clipped skill viewport")
	touch(outside,false)
	await frames()
	ck(pointer.pointer==-2 and window.selected().is_empty() and w.quickslots==stable_slots and w.mp==mp and w.skill_cooldowns==stable_cooldowns,"release outside after scrolling never binds or casts")
	var edge: Vector2=edge_of_view()
	if not ck(edge.is_finite(),"an empty side strip is inside the original viewport"):return
	await swipe(edge,Vector2(0,4096))
	ck(window._scroll==0.0,"a swipe from the viewport gap returns to the top")
	await swipe(unlearned.point,Vector2(0,-4096))
	ck(is_equal_approx(window._scroll,window._scroll_min) and window.selected().is_empty() and w.quickslots==stable_slots,"unlearned tile starts a real scroll and clamps at the last row")
	ck(window.tab=="all" and order==window.records().map(func(record: Dictionary)->String:return window._id(record)),"scrolling preserves the exact active tab and its rows")
	edge=edge_of_view()
	if not ck(edge.is_finite(),"empty viewport strip remains at the last row"):return
	await swipe(edge,Vector2(0,4096))
	var to: Vector2=center(h.original_quickslot_control(0))
	var to_second: Vector2=center(h.original_quickslot_control(1))
	ck(h.original_quickslot_control(0)!=h.v20_quickslot_buttons[0],"actual original quickslot destination")
	tile=move_for_fixture(learned_id)
	touch(tile,true)
	dragged(tile+Vector2(0,-42),Vector2(0,-42))
	dragged(to,to-(tile+Vector2(0,-42)));touch(to,false);await frames()
	ck(w.quickslots==stable_slots and w.mp==mp,"a vertical-owned gesture cannot assign even when it ends directly on an original quickslot")
	edge=edge_of_view()
	if not ck(edge.is_finite(),"viewport edge after quickslot-ended swipe"):return
	await swipe(edge,Vector2(0,4096))
	tile=move_for_fixture(learned_id)
	touch(tile,true);touch(tile,false);await frames()
	ck(window.selected()==learned_id and w.quickslots==stable_slots and w.mp==mp,"short tap still selects, without casting or binding")
	# Move horizontally first, then to the original destination.
	var left: Vector2=tile-Vector2(65,0)
	touch(tile,true);dragged(left,left-tile)
	ck(pointer.mode=="drag" and pointer.source.get("id")==learned_id,"horizontal intent captures the exact learned source ID")
	dragged(to,to-left);touch(to,false);await frames()
	var first_index: int=h.quickslot_index(0)
	var first_entry: Dictionary=w.quickslots[first_index]
	ck(first_entry.get("kind")=="skill" and first_entry.get("skill_id",first_entry.get("id"))==learned_id and window.selected()==learned_id and w.mp==mp and w.skill_cooldowns==stable_cooldowns,"touch registers exact skill without re-tapping or activating it")
	# Timer must not be required on a busy frame: the first move after a
	# real stationary hold still retains the old hold-and-drop behavior.
	touch(tile,true);OS.delay_msec(int((L.TOUCH_HOLD_SECONDS+.06)*1000.0))
	dragged(to_second,to_second-tile);touch(to_second,false);await frames()
	var next_index: int=h.quickslot_index(1)
	ck(w.quickslots[next_index].get("skill_id",w.quickslots[next_index].get("id"))==learned_id,"stationary hold still works even without an intervening process frame")
	var committed: Array=w.quickslots.duplicate(true)
	var invalid: Vector2=move_for_fixture(str(unlearned.id))
	touch(invalid,true);dragged(invalid-Vector2(65,0),Vector2(-65,0));dragged(to,to-(invalid-Vector2(65,0)));touch(to,false);await frames()
	ck(w.quickslots==committed and w.mp==mp,"unlearned icon cannot replace an occupied slot or cast")
	tile=move_for_fixture(learned_id);left=tile-Vector2(65,0)
	touch(tile,true);dragged(left,left-tile);touch(to,false,7,true);await frames()
	ck(w.quickslots==committed and pointer.pointer==-2 and not pointer.preview.visible,"canceled native touch cannot assign or leave a stale preview")
	await swipe(tile,Vector2(-90,0))
	ck(w.quickslots==committed,"release away from any target does not assign")
	var mouse_to: Vector2=center(h.original_quickslot_control(2))
	mouse(tile,true);motion(left,left-tile);motion(mouse_to,mouse_to-left);mouse(mouse_to,false);await frames()
	var mouse_slot: Dictionary=w.quickslots[h.quickslot_index(2)]
	ck(mouse_slot.get("skill_id",mouse_slot.get("id"))==learned_id and w.mp==mp,"mouse drag registers the same authored skill without a cast")
	touch(tile,true);dragged(left,left-tile)
	var saved: Array=w.quickslots.duplicate(true)
	controller.close_skill_window()
	touch(center(h.original_quickslot_control(3)),false);await frames()
	ck(w.quickslots==saved and pointer.pointer==-2,"closing the source before release cancels captured assignment")
	ck(w._save_game(true)==OK,"native quickslot binding uses the actual writer")
	w._load_game(true);await frames()
	ck(w.quickslots==saved,"the exact canonical page bindings survive disk reload")
