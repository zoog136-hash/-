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
	print("PRODUCTION_REFRESH_REUSE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"mounted":mounted}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
