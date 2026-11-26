extends SceneTree
## The original 523 제작 window refresh (source_main_production_window.refresh):
## item rows whose recipe / selection / 제작 가능 state is unchanged and sort /
## material rows whose spec reads the same are moved into the new tree, not
## rebuilt (2026-11-19: ~0.4 s -> ~0.18 s per refresh on desktop). Without the
## private UI pack (CI) the window is not mounted and only the rule texts are
## checked; with the pack environment the real Main window is refreshed and
## must show the same state as a fresh build.
var checks: int=0
var failures: Array[String]=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("PRODUCTION_REFRESH_REUSE_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_production_window.gd")
	check(source.contains("_reuse_by_state=true") and source.contains("bool(kept.get_meta(\"row_ok\",false))==_craftable(world,id)") and source.contains("if not _ok_memo.has(id):_ok_memo[id]=bool(world._craft_quote(id,1).get(\"ok\",false))"),"a refresh reuses item rows only with the same 제작 가능 state")
	check(source.contains("str((old as Node).get_meta(\"row_signature\",\"\"))==signature"),"sort / material rows are reused only with the same spec")
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
