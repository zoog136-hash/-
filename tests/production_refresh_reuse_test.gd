extends SceneTree
## The original 523 제작 window refresh (source_main_production_window.refresh):
## item rows whose recipe / selection / 제작 가능 state is unchanged and sort /
## material rows whose spec reads the same are moved into the new tree, not
## rebuilt (2026-11-19: ~0.4 s -> ~0.18 s per refresh on desktop). Without the
## private UI pack (CI) the window is not mounted and only the rule texts are
## checked; with the pack environment the real Main window is refreshed and
## must show the same state as a fresh build.
const WORLD = preload("res://scripts/world.gd")
const PRODUCTION = preload("res://scripts/ui/original_ui/source_main_production_window.gd")
const NAMED = preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const ROUTER = preload("res://scripts/ui/original_ui/source_button_router.gd")
const SOURCE_HUD = preload("res://scripts/ui/original_ui/source_main_hud.gd")
var checks: int=0
var failures: Array[String]=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("PRODUCTION_REFRESH_REUSE_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _check_fast_rejection() -> void:
	var gear := {"item":"gear","source_id":"41","quantity":2,"row_id":11,"physical":true}
	var stack := {"item":"stack","source_id":"42","quantity":3,"row_id":12,"physical":false}
	var recipe := {"adena":10,"materials":[gear,stack]}
	check(not WORLD._production_can_meet_required_inputs(recipe,{"gear":2},9,{}),"known fee cannot be paid")
	check(not WORLD._production_can_meet_required_inputs(recipe,{"gear":1},10,{}),"known physical requirement cannot be met")
	check(WORLD._production_can_meet_required_inputs(recipe,{"gear":2},10,{}),"a missing stack may be supplied by another owner and must reach the full quote")
	recipe["material_slots"]=[{"slot_index":2,"candidates":[gear,stack]}]
	check(not WORLD._production_can_meet_required_inputs(recipe,{"gear":2},10,{}),"an unchosen alternative cannot be ready")
	check(WORLD._production_can_meet_required_inputs(recipe,{"gear":2},10,{"2":44}),"an explicit alternative must undergo the full choice validation")
	check(WORLD._production_can_meet_required_inputs(recipe,{},10,{"2":12}),"a selected stack still needs the full quote and its original ownership checks")
	recipe.material_slots[0].candidates=[gear]
	check(not WORLD._production_can_meet_required_inputs(recipe,{"gear":1},10,{}),"the fixed slot's equipment needs its exact quantity")

func _touch(window: RefCounted, suffix: String) -> Dictionary:
	var target: Dictionary=NAMED.locate_exact(window._scene,window.node_keys(),suffix)
	if not target.get("ok",false):return target
	var node: Node2D=target.player.source_nodes.get(target.offset)
	if not is_instance_valid(node) or not node.has_meta("source_button"):return {}
	var area: Control=node.get_meta("source_button").get("_input_area")
	var point: Vector2=area.get_global_transform_with_canvas()*(area.size*0.5)
	var buttons: Array=[]
	SOURCE_HUD._collect_native_buttons(window._scene,buttons)
	var router=ROUTER.new()
	var result: Dictionary={}
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.pressed=pressed
		event.position=point
		result=router.route(event,point,buttons)
	return result.get("result",{}) if result.get("activated",false) else {}

func _shown_amount(window: RefCounted) -> String:
	var target: Dictionary=NAMED.locate_exact(window._scene,window.node_keys(),PRODUCTION.P_PROD+"ProgressBar/Label_Amount")
	if not target.get("ok",false):return ""
	var node: Node2D=target.player.source_nodes.get(target.offset)
	if node.has_meta("source_text"):return str(node.get_meta("source_text").original_options.text)
	if node.has_meta("source_bitmap_text"):return str(node.get_meta("source_bitmap_text")._options.text)
	return ""

func _check_quantity(world: Node, window: RefCounted) -> void:
	var editable: String=""
	for id: String in window._item_ids:
		if not world.crafting.recipes[id].has("outcomes"):
			editable=id
			break
	if editable.is_empty():return
	window._select(editable)
	await process_frame
	var scene: Node2D=window._scene
	var visible_rows: Dictionary=window._item_rows.duplicate()
	var material_rows: Dictionary=window._fill_rows.get("materials",{}).duplicate()
	var changed: Dictionary=_touch(window,PRODUCTION.P_PROD+"ProgressBar/Btn_Arrow_Top")
	check(changed.get("ok",false) and window.count()==2 and _shown_amount(window)=="2","touching the original arrow refreshes the mounted amount label")
	check(window._scene==scene and window._item_rows==visible_rows,"a count change keeps the original window and list row instances")
	check(window._fill_rows.get("materials",{})==material_rows,"unchanged material slots keep their original row and icon instances")
	var full_quote: Dictionary=world._craft_quote(editable,2)
	check(changed.get("quote_ok",false)==full_quote.get("ok",false) and changed.get("quote_reason","")==str(full_quote.get("reason","")),"the mounted detail reads a current full quote at the new count")
	var maximum: Dictionary=_touch(window,PRODUCTION.P_PROD+"Nd_Count/Btn_Count_50")
	check(maximum.get("ok",false) and window._scene==scene and window.count()==20 and _shown_amount(window)=="20","the original +50 button clamps to 20 in the same window")
	var arrow: Dictionary=NAMED.locate_exact(window._scene,window.node_keys(),PRODUCTION.P_PROD+"ProgressBar/Btn_Arrow_Top")
	check(arrow.get("ok",false) and arrow.player.source_nodes[arrow.offset].get_meta("source_button").current_state=="disabled","the increase control displays its original disabled state at the cap")
	var reset: Dictionary=_touch(window,PRODUCTION.P_PROD+"Nd_Count/Btn_Count_01")
	check(reset.get("ok",false) and window._scene==scene and window.count()==1 and _shown_amount(window)=="1","the original reset button updates the same mounted controls")
	var label: Dictionary=NAMED.locate_exact(scene,window.node_keys(),PRODUCTION.P_PROD+"ProgressBar/Label_Amount")
	window.node_keys().erase(label.get("key",""))
	check(window._add_count(1).get("ok",false) and window._scene!=scene and _shown_amount(window)=="2","a missing live binding falls back to the complete source scene")

func _run() -> void:
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_production_window.gd")
	check(source.contains("_reuse_by_state=true") and source.contains("bool(kept.get_meta(\"row_ok\",false))==_craftable(world,id)") and source.contains("if _building and _ok_memo.has(id):return bool(_ok_memo[id])"),"a refresh reuses item rows only with the same 제작 가능 state")
	check(source.contains("str((old as Node).get_meta(\"row_signature\",\"\"))==signature"),"sort / material rows are reused only with the same spec")
	_check_fast_rejection()
	var QA=load("res://tests/qa_class_selection.gd")
	var world=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	check(QA.enter_game(world),"Main class selection")
	world.player.set_physics_process(false)
	var hud: Node=world.hud
	for _i: int in range(3):await process_frame
	hud.call("_navigate","crafting")
	await process_frame
	var controller: Object=hud.get("original_main_ui_controller")
	var window: Object=controller.production_window() if controller!=null and controller.has_method("production_window") else null
	var mounted: bool=window!=null and window.is_open()
	if mounted:
		var fresh: Dictionary=window.last_result.duplicate()
		var preview: Callable=world.production_preview_quote()
		var original_order: Array[String] = []
		for id: String in world.crafting.recipes:
			if world.crafting.recipes[id].get("category") in PRODUCTION.TABS[window.tab()]: original_order.append(id)
		var availability: Dictionary = {}
		for id: String in original_order:
			availability[id]=bool(preview.call(id,1).get("ok",false))
			check(world.production_recipe_craftable(id,preview)==availability[id],"list status equals a full original quote for "+id)
		var exact_order := PRODUCTION.ready_first(original_order,func(id: String) -> bool: return availability[id])
		check(window._item_ids==exact_order,"mounted list retains the complete ready-first order of full quotes")
		for id: String in window._item_ids.slice(0,12):
			for count: int in [1,2]:
				check(preview.call(id,count)==world._craft_quote(id,count),"synchronous preview uses the same rules and result as a fresh quote")
		var again: Dictionary=window.refresh()
		check(again.get("handled",false) and int(again.reused_rows)>0,"a refresh moves unchanged item rows: "+str(again.get("reused_rows")))
		for key: String in ["recipes","selected","count","materials","quote_ok","tab","category"]:
			check(str(again.get(key))==str(fresh.get(key)),"the refreshed window shows the same "+key)
		window._reuse_except.clear()
		var ids: Array=window._item_ids
		if ids.size()>1:
			window._select(str(ids[1]))
			check(window.selected()==str(ids[1]) and window.refresh().get("handled",false),"a new selection still refreshes")
		await _check_quantity(world,window)
	print("PRODUCTION_REFRESH_REUSE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"mounted":mounted}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
