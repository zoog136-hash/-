extends SceneTree
## The craft item index warm build (world._tick_craft_index_warm): idle-frame
## slices build the same index as the one-shot build, a half-built warm index
## finishes on the first quote with the same result, a cache reset drops it.
## Without the private 523 pack (CI) there are no original items: nothing is
## built and the tick stays idle. With the pack environment the real ~30,000
## item index is compared entry by entry.
var checks: int=0
var failures: Array[String]=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("CRAFT_INDEX_WARM_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var QA=load("res://tests/qa_class_selection.gd")
	var world=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	check(QA.enter_game(world),"Main class selection")
	world.player.set_physics_process(false)
	for _i: int in range(3):await process_frame
	var items: Dictionary=world.patch523_equipment.data.get("items",{}) if world.patch523_equipment.data is Dictionary else {}
	var source: String=FileAccess.get_file_as_string("res://scripts/world.gd")
	check(source.contains("\t_tick_craft_index_warm(delta)\n") and source.count("_craft_index_warm={}")>=4,"the warm build ticks on game frames and every cache reset drops it")
	if items.is_empty():
		world.patch523_craft_item_cache={}
		world.craft_index_warm_seconds=0.0
		check(not world._tick_craft_index_warm(1.0) and world._craft_index_warm.is_empty(),"no original items: nothing is built")
	else:
		world.patch523_craft_item_cache={}
		world._craft_index_warm={}
		var once: Dictionary=world._patch523_craft_item_index().duplicate()
		world.patch523_craft_item_cache={}
		world.craft_index_warm_seconds=0.0
		var slices: int=0
		var longest: int=0
		var more: bool=true
		while more and slices<200000:
			var started: int=Time.get_ticks_usec()
			more=world._tick_craft_index_warm(0.033)
			slices+=1
			longest=maxi(longest,Time.get_ticks_usec()-started)
		check(not world.patch523_craft_item_cache.is_empty() and world.patch523_craft_item_cache.keys()==once.keys() and world.patch523_craft_item_cache==once,"idle slices build the same index: %d entries, %d slices" % [once.size(),slices])
		world.patch523_craft_item_cache={}
		world.craft_index_warm_seconds=0.0
		for _i: int in range(4):world._tick_craft_index_warm(0.033)
		check(not world._craft_index_warm.is_empty(),"a warm build is under way")
		var finished: Dictionary=world._patch523_craft_item_index()
		check(finished==once and world._craft_index_warm.is_empty(),"the first quote finishes a half-built index with the same result")
		world._craft_index_warm={"ids":[],"cursor":0,"result":{}}
		world._index_catalog_item_sources()
		check(world._craft_index_warm.is_empty(),"a catalog reindex drops a warm build")
		print("CRAFT_INDEX_WARM_MEASURE ",JSON.stringify({"entries":once.size(),"slices":slices,"longest_slice_ms":longest/1000.0}))
	world.queue_free()
	await process_frame
	print("CRAFT_INDEX_WARM_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"pack":not items.is_empty()}))
	quit(0 if failures.is_empty() else 1)
