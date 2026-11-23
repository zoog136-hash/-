extends SceneTree
## Actual Main save path, isolated user directory only. The large case is a
## schema-valid synthetic historical extension (400 rows), not a phone save or
## original-resource measurement. The same script runs on baseline/candidate.
const QA = preload("res://tests/qa_class_selection.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("SAVE_SNAPSHOT_BUDGET_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func disk(world: Node) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	return value if value is Dictionary else {}
func canonical(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)),"",true,true)
func fixture() -> Dictionary:
	var rows: Dictionary = {}
	for i: int in 400:
		var row: Dictionary = {}
		for j: int in 32: row[str(j)]={"id":i,"values":[j,j+1,j+2],"state":"historical-extension"}
		rows[str(i)]=row
	return rows
var _prior_files: Dictionary = {}
func remember_user_files() -> void:
	var directory: String=ProjectSettings.globalize_path("user://")
	for name: String in DirAccess.get_files_at(directory):
		if name.begins_with("twilight_v20_save"):_prior_files[name]=FileAccess.get_file_as_bytes(directory.path_join(name))
func restore_user_files() -> void:
	var directory: String=ProjectSettings.globalize_path("user://")
	for name: String in DirAccess.get_files_at(directory):
		if name.begins_with("twilight_v20_save") and not _prior_files.has(name):DirAccess.remove_absolute(directory.path_join(name))
	for name: String in _prior_files:
		var file:=FileAccess.open(directory.path_join(name),FileAccess.WRITE)
		file.store_buffer(_prior_files[name]);file.close()
func run() -> void:
	remember_user_files()
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false);world.save_timer=-100000
	check(QA.enter_game(world),"actual Main entry")
	world.field_population.set_process(false);world.player.set_physics_process(false);world.player.auto_enabled=false
	world.background_save_enabled=true
	world.deferred_save_enabled=true
	world.rng.seed=1234567
	world.titles.state.rng="1234567"
	world.halphas_star.rng.seed=1234567
	world.option_awakening.rng.seed=1234567
	world.ain_service.last_regen_at=1700000000
	check(world._save_game(true)==OK,"initial test save")
	# Clone the seed save; production/user saves are never inputs to this test.
	check(DirAccess.copy_absolute(world.save_path(),world.save_path()+".benchmark-clone")==OK,"clone test seed")
	for size: String in ["small","large"]:
		if size=="large":
			var state: Dictionary=world.monsterbook523.export_state();state["historical_test_extension"]=fixture()
			check(world.monsterbook523.import_state(state),"schema-valid historical extension accepted")
		var samples: Array=[];var finishes: Array=[];var phases: Array=[]
		for round: int in 7:
			# Unchanged repeated input, then exactly one changed part.
			if round==4:world.gold+=1
			HITCH._details.clear()
			var start: int=Time.get_ticks_usec()
			check(world._save_game(true,{},{},false,true)==OK,size+" start "+str(round))
			var elapsed: int=Time.get_ticks_usec()-start
			var details: Dictionary=HITCH._details.duplicate(true)
			while world.background_save_pending() and not WorkerThreadPool.is_task_completed(world._background_save_task):OS.delay_usec(500)
			start=Time.get_ticks_usec();world._finish_background_save(false)
			if round>0:samples.append(elapsed);finishes.append(Time.get_ticks_usec()-start);phases.append(details)
			check(int(disk(world).get("gold",-1))==world.gold,"durable gold "+size+str(round))
		evidence[size]={"main_usec":samples,"completion_main_usec":finishes,"details":phases}
		var image:=FileAccess.open("user://budget-evidence-"+size+".json",FileAccess.WRITE)
		image.store_string(JSON.stringify(disk(world),"",true,true));image.close()
	# Prove that the five transferred exports are independent of live state.
	var before: Dictionary={"quest_state":world.quest_service.export_state(),"monsterbook523":world.monsterbook523.export_state(),"equipment_collections":world.equipment_collections.export_state(),"warehouse":world.warehouse.snapshot(),"consumable_state":world.consumable_service.export_state()}
	check(world._save_game(true,{},{},false,true)==OK,"snapshot before live edits")
	world.quest_service.claimed["987654"]=true
	world.monsterbook523._state.historical_test_extension["0"]["0"]["values"][0]=999
	world.equipment_collections.progress["unknown_test_extension"]={"after":true}
	world.warehouse.stacks["test-historical-stack"]=1
	world.consumable_service.permanent_damage_bonuses.melee_damage+=1
	world._request_deferred_save()
	world._finish_background_save(true)
	var written: Dictionary=disk(world)
	for key: String in before:check(canonical(written.get(key))==canonical(before[key]),"worker owns independent "+key)
	check(world.deferred_save.pending(),"later changes remain queued")
	# Autosave -> transaction -> duplicate transaction -> autosave, same path.
	var target: int=world.gold+11
	var tx_start: int=Time.get_ticks_usec()
	check(world._save_game(true,{"gold":target})==OK,"transaction after autosave")
	evidence["transaction_after_autosave_usec"]=Time.get_ticks_usec()-tx_start
	check(int(disk(world).gold)==target and world.gold!=target,"transaction durable before caller confirmation")
	world.gold=target
	check(world._save_game(true,{"gold":target})==OK and int(disk(world).gold)==target,"identical repeated transaction no double credit")
	check(world._save_game(true,{},{},false,true)==OK,"autosave after transaction")
	var second_target: int=target+13
	tx_start=Time.get_ticks_usec()
	HITCH._details.clear()
	check(world._save_game(true,{"gold":second_target})==OK,"transaction joins existing writer before next write")
	evidence["transaction_collision_usec"]=Time.get_ticks_usec()-tx_start
	evidence["transaction_collision_details"]=HITCH._details.duplicate(true)
	check(int(disk(world).gold)==second_target,"newer transaction not overwritten by older autosave")
	world.gold=second_target
	# Synchronous failed transaction leaves disk and live state unchanged.
	var sha: String=FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary)->Error:return ERR_CANT_CREATE
	check(world._save_game(true,{"gold":second_target+17})!=OK,"failed transaction rejected")
	check(FileAccess.get_sha256(world.save_path())==sha and world.gold==second_target,"failed transaction preserves live and durable state")
	world.equipment_collections.test_save_writer=Callable()
	# Force the actual worker atomic writer to fail opening its temporary file.
	check(DirAccess.make_dir_absolute(world.save_path()+".tmp")==OK,"temporary-file failure fixture")
	check(world._save_game(true,{},{},false,true)==OK,"worker failure scheduled")
	var job: Dictionary=world._background_save_job
	world._finish_background_save(true)
	check(int(job.error)!=OK and FileAccess.get_sha256(world.save_path())==sha,"failed worker preserves previous complete file")
	DirAccess.remove_absolute(world.save_path()+".tmp")
	check(world._save_game(true)==OK,"retry succeeds")
	# A real external file change is still caught by precheck.
	var text: String=FileAccess.get_file_as_string(world.save_path())
	var f:=FileAccess.open(world.save_path(),FileAccess.WRITE);f.store_string(text+" ");f.close()
	check(world._save_game(true,{},{},false,true)!=OK,"external edit blocks background write")
	world._load_game(true)
	check(world.gold==second_target and not world.equipment_collections.save_blocked,"reload restores last complete state and protection")
	check(world._save_game(true)==OK,"save after reload")
	evidence["final_gold"]=world.gold
	evidence["final_file_bytes"]=FileAccess.get_file_as_bytes(world.save_path()).size()
	world.queue_free();await process_frame
	restore_user_files()
	print("SAVE_SNAPSHOT_BUDGET_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"Linux headless actual Main + synthetic retained history; main preparation/completion only, not worker or Android frame latency"}))
	quit(0 if failures.is_empty() else 1)
