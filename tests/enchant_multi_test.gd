extends SceneTree
## 다중 강화 (TWILIGHT 근사): the original Enchant_All 다중 강화 page state
## (source_main_enchant_window: picks, goal, fewest scrolls) and
## World.attempt_enhancement_series over the existing single roll in the real
## Main: it rolls each target in turn up to the goal and stops at the scroll
## running out, a failure or a destroyed target; the rolls are the single
## enhancement's own (each one consumes its scroll and saves).
const WINDOW=preload("res://scripts/ui/original_ui/source_main_enchant_window.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeWorld extends Node:
	var series: Array=[]
	func attempt_enhancement_series(scroll: String, targets: Array, goal: int) -> Dictionary:
		series.append([scroll,targets,goal])
		return {"ok":true,"rolls":0,"stop":""}

class FakeHud extends Node:
	var shown: Array[String]=[]
	var asked: Array=[]
	func show_message(text: String) -> void:
		shown.append(text)
	func confirm_action(title: String, body: String, _action: String, _callback: Callable, _maximum: int=0) -> void:
		asked.append([title,body])

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ENCHANT_MULTI_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_window_state()
	await _series()
	print("ENCHANT_MULTI_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _window_state() -> void:
	var world:=FakeWorld.new()
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	var window=WINDOW.new()
	window._hud=weakref(hud)
	window._scroll="무기 마법 주문서"
	window._candidates=[{"target_id":"검@@@a","level":0,"count":1},{"target_id":"검@@@b","level":2,"count":1},{"target_id":"검@@@c","level":5,"count":2}]
	window.multi=true
	window._toggle_pick("검@@@a");window._toggle_pick("검@@@b");window._toggle_pick("검@@@c")
	window._set_goal(4)
	check(window.picked()==["검@@@a","검@@@b","검@@@c"] and window.goal()==4,"bag taps pick targets and a progress button sets the goal")
	check(window.scrolls_needed()==6,"the fewest scrolls: (4-0)+(4-2), a target past the goal needs none")
	window._toggle_pick("검@@@b")
	check(window.picked()==["검@@@a","검@@@c"],"a second tap drops a pick")
	for index: int in range(20):window._toggle_pick("x@@@%d" % index)
	check(window.picked().size()==WINDOW.MULTI_MAX and hud.shown[-1].contains("%d개까지" % WINDOW.MULTI_MAX),"at most MULTI_MAX targets")
	window._reset_multi()
	check(window.picked().is_empty() and window.goal()==0,"초기화 clears picks and goal")
	check(window._multi_requested().has("notice"),"강화 시작 without picks says so")
	window._toggle_pick("검@@@a");window._set_goal(3)
	var asked: Dictionary=window._multi_requested()
	check(asked.get("started","")=="multi" and hud.asked.is_empty() and world.series.size()==1 and int(world.series[0][2])==3,"강화 시작 starts the series at once (no confirmation)")
	window._candidates=[{"target_id":"검@@@c","level":5,"count":2}]
	window._prune_picked()
	check(window.picked().is_empty(),"a target that left the list is dropped")
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_enchant_window.gd")
	check(not source.contains("다중 강화는 원본 규칙이 없어") and source.contains("\"Nd_Enchant_Bless\",\"Nd_Enchant_Smelt\",\"Nd_Enchant_Grace\""),"the 다중 강화 page is mounted (no longer kept out)")
	world.queue_free()

## user:// as it was: later suites in the same run read the saved character.
static func _snapshot(dir: String, into: Dictionary) -> void:
	for file: String in DirAccess.get_files_at(dir):into[dir.path_join(file)]=FileAccess.get_file_as_bytes(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):_snapshot(dir.path_join(sub),into)

static func _restore(dir: String, saved: Dictionary) -> void:
	var now: Dictionary={}
	_snapshot(dir,now)
	for path: String in now:
		if not saved.has(path):DirAccess.remove_absolute(path)
	for path: String in saved:
		if not now.has(path) or now[path]!=saved[path]:
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			var file:=FileAccess.open(path,FileAccess.WRITE)
			if file!=null:
				file.store_buffer(saved[path])
				file.close()

func _series() -> void:
	var saved: Dictionary={}
	_snapshot("user://",saved)
	await _series_run()
	_restore("user://",saved)
	var after: Dictionary={}
	_snapshot("user://",after)
	check(after.keys()==saved.keys() and after.values()==saved.values(),"user:// is restored for the next suites")

func _series_run() -> void:
	var QA=load("res://tests/qa_class_selection.gd")
	var world=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	check(QA.enter_game(world),"Main class selection")
	world.player.set_physics_process(false)
	for _i: int in range(3):await process_frame
	var record: Dictionary=world._catalog_item_from_source_id("423")
	if record.is_empty():
		check(true,"no catalog weapon 423: series run skipped")
		world.queue_free()
		return
	var name_value: String=str(record.name)
	world._grant_playtest_catalog_variant("423",2)
	var ids: Array[String]=[]
	for id: String in world.item_instances:
		if str(world.item_instances[id].get("name",""))==name_value:ids.append(id)
	check(ids.size()>=2,"two physical weapons")
	if ids.size()<2:
		world.queue_free()
		return
	var scroll: String="무기 마법 주문서"
	world.inventory[scroll]=1
	var targets: Array=[name_value+"@@@"+ids[0],name_value+"@@@"+ids[1]]
	var result: Dictionary=world.attempt_enhancement_series(scroll,targets,3)
	if str(result.stop)=="refused" and int(result.rolls)==0:
		# A world that refuses the single roll here (e.g. a protected original
		# item save with the private pack) moves nothing in the series either.
		check(int(world.inventory.get(scroll,0))==1 and not world.enhancement_series_quiet,"a refused single roll: the series rolls nothing and keeps the scroll")
		world.queue_free()
		await process_frame
		return
	check(int(result.rolls)==1 and int(world.inventory.get(scroll,0))==0,"one scroll: exactly one roll: "+str(result))
	check(str(result.stop) in ["scroll","fail","destroy"],"the series stops in place (scroll / failure / destroyed): "+str(result.stop))
	check(int(world.item_instances.get(ids[1],{}).get("level",0))==0,"the second target was never rolled")
	check(not world.enhancement_series_quiet,"the single roll presents again after the series")
	world.inventory[scroll]=30
	var again: Dictionary=world.attempt_enhancement_series(scroll,[targets[1]],2)
	var level: int=int(world.item_instances.get(ids[1],{}).get("level",-1))
	check((str(again.stop)=="" and level>=2 and int(again.reached)==1) or str(again.stop) in ["fail","destroy"],"enough scrolls: the goal is reached or the first failure stops it: "+str(again))
	check(int(again.rolls)>=1 and 30-int(world.inventory.get(scroll,0))==int(again.rolls),"one scroll per roll, the single roll's own cost")
	world.queue_free()
	await process_frame
