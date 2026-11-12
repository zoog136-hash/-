extends SceneTree
## Optional CPU comparison of real slot-binding producers with synthetic owners.
## Each sample builds BOTH the 4-column and 8-column layouts: staged_slots is
## their sum (2 * owned), not a count of slots displayed in one game window.
## This does not mount/render original CSBs or measure phone response latency.
## Prepare the original producer without copying its source into the repository:
##   git show 8634f931b6b749865c52dd6437b2d18d5f91c174:scripts/ui/original_ui/source_main_inventory_slots.gd > /tmp/slots-before.gd
##   mkdir -p /tmp/twilight-inventory-benchmark/data /tmp/twilight-inventory-benchmark/config /tmp/twilight-inventory-benchmark/cache
##   XDG_DATA_HOME=/tmp/twilight-inventory-benchmark/data XDG_CONFIG_HOME=/tmp/twilight-inventory-benchmark/config XDG_CACHE_HOME=/tmp/twilight-inventory-benchmark/cache godot --headless --path . --script res://tests/benchmark_inventory_snapshot.gd -- --baseline=/tmp/slots-before.gd
## Use Godot 4.7.2. This opt-in benchmark has no elapsed-time pass threshold.
const FIXTURE=preload("res://tests/original_ui_inventory_snapshot_test.gd")
const AFTER=preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")

func _initialize() -> void:
	_run.call_deferred()

func _fail(reason: String) -> void:
	printerr("INVENTORY_SLOT_SNAPSHOT_COMPARISON_FAILED "+reason)
	quit(2)

func _run() -> void:
	var baseline_path: String=""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline="):baseline_path=argument.trim_prefix("--baseline=")
	if baseline_path.is_empty() or not baseline_path.is_absolute_path():
		_fail("Pass --baseline=/absolute/path.gd; see this script's reproduction commands.")
		return
	if not FileAccess.file_exists(baseline_path):
		_fail("Baseline file does not exist: "+baseline_path)
		return
	var baseline_source: String=FileAccess.get_file_as_string(baseline_path)
	if baseline_source.is_empty():
		_fail("Baseline file is empty or unreadable: "+baseline_path)
		return
	var before:=GDScript.new()
	before.source_code=baseline_source
	if before.reload()!=OK:
		_fail("Baseline GDScript failed to load: "+baseline_path)
		return
	var results: Array=[]
	for count: int in [64,256]:
		for improved: bool in [false,true]:
			var producer: Script=AFTER if improved else before
			var bag=FIXTURE.FakeBag.new()
			for index: int in range(count):
				var reference: String="same sword@@@physical-%d"%index
				bag.offered.append({"name":"same sword","reference":reference,"amount":index+1})
				bag.sorted_references.push_front(reference)
			var hud=FIXTURE.FakeHud.new()
			hud.lineage_inventory_ui=bag
			hud.add_child(bag)
			var pack=FIXTURE.FakePack.new()
			pack.manifest={"files":{AFTER.PARENT:{"sha256":AFTER.PARENT_SHA},AFTER.SET_MEMBER:{"sha256":AFTER.SET_SHA},AFTER.SLOT_MEMBER:{"sha256":AFTER.SLOT_SHA}}}
			var slots: RefCounted=producer.new()
			if not slots.configure(pack,hud,Callable(bag,"image")).get("ok",false):
				hud.free()
				_fail("Slot producer configuration failed.")
				return
			var started: int=Time.get_ticks_usec()
			var model: Dictionary=slots.entries()
			if not model.get("ok",false):
				hud.free()
				_fail("Slot producer rejected the synthetic owner snapshot.")
				return
			for variant: String in ["Nd_Slot","Nd_Slot_Extension"]:
				var offsets: Array=AFTER.VARIANTS[variant].slots
				var parent: int=56036 if offsets.size()==4 else 44156
				for first: int in range(0,count,offsets.size()):
					var assignments: Dictionary={}
					for column: int in range(mini(offsets.size(),count-first)):
						assignments[offsets[column]]=model.current_display_rows[first+column].reference
					var args: Array=[parent,assignments,{},variant]
					if improved:args.append(model)
					if not slots.callv("build",args).get("ok",false):
						hud.free()
						_fail("Slot contract construction failed: "+variant)
						return
			results.append({"mode":"after" if improved else "before","owned":count,"staged_slots":count*2,"owner_reads":bag.entry_calls,"usec":Time.get_ticks_usec()-started})
			hud.free()
	print("INVENTORY_SLOT_SNAPSHOT_COMPARISON ",JSON.stringify({"scope":"synthetic_slot_binding_cpu_only","layouts":[4,8],"staged_slots_basis":"sum_of_both_layouts","baseline":baseline_path,"samples":results}))
	quit()
