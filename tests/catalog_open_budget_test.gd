extends SceneTree
## Actual Main and fallback catalog with synthetic 33,258-entry data; timing is
## a PC proxy for filtering and mounting, without the original icon pack.
const QA=preload("res://tests/qa_class_selection.gd")
var failures: Array[String]=[]
var checks: int=0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func run() -> void:
	var world: Node=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	check(QA.enter_game(world),"actual Main joins as knight")
	var hud: Node=world.hud
	var rows: Array=[]
	for index: int in range(33258):
		rows.append({"name":"Budget Fixture %d"%index,"sourceId":str(900000+index),"grade":"희귀" if index%3==0 else "일반","type":"Fixture","desc":"original search field fixture"})
	hud.set_catalog_data({"아이템":rows},{})
	var fresh: Array=[]
	var restored: Array=[]
	var expected_saved: Dictionary={"query":"fixture","grade":"희귀","page":2,"id":"900291","scroll":72.0}
	for pair: int in range(6):
		hud.catalog_view_state.erase("아이템")
		var fresh_generation: int=hud.catalog_icon_generation
		var started: int=Time.get_ticks_usec()
		hud.open_catalog("아이템")
		fresh.append(Time.get_ticks_usec()-started)
		check(hud.catalog_filtered_results.size()==33258 and hud.catalog_results.size()==40 and hud.catalog_page==0,"fresh ordered 40-row page is unchanged")
		check(str(hud.selected_catalog_record.get("sourceId"))=="900000","fresh first selected item")
		var fresh_mount_delta: int=hud.catalog_icon_generation-fresh_generation
		hud._close_workspace()
		hud.catalog_view_state["아이템"]=expected_saved.duplicate(true)
		var restored_generation: int=hud.catalog_icon_generation
		started=Time.get_ticks_usec()
		hud.open_catalog("아이템")
		restored.append(Time.get_ticks_usec()-started)
		check(hud.catalog_search.text=="fixture" and hud.catalog_grade_filter=="희귀","saved query and grade")
		check(hud.catalog_filtered_results.size()==11086 and hud.catalog_page==2,"saved page and exact filter membership")
		check(str(hud.selected_catalog_record.get("sourceId"))=="900291" and hud.catalog_list.is_selected(17),"saved stable identity at its original row")
		check(hud.rarity_filter.get_item_text(hud.rarity_filter.selected)=="희귀" or "--benchmark-baseline" in OS.get_cmdline_user_args(),"compact dropdown matches restored grade")
		if "--benchmark-baseline" not in OS.get_cmdline_user_args():
			check(hud.catalog_icon_generation-restored_generation==fresh_mount_delta,"saved view mounts only once, like the fresh view")
		await process_frame
		await process_frame
		check(is_equal_approx(hud.catalog_list.get_v_scroll_bar().value,72.0),"deferred scroll restored")
		hud._close_workspace()
		await process_frame
	world.queue_free()
	await process_frame
	print("CATALOG_OPEN_BUDGET_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"fresh_us":fresh,"restored_us":restored}))
	quit(0 if failures.is_empty() else 1)
