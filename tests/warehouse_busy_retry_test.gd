extends SceneTree
## Actual Main HUD signal/warehouse/save path. Isolated synthetic legacy material,
## not original523 physical receipts or Android. No admitted intent is retained.
const QA=preload("res://tests/qa_class_selection.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
const ACCOUNT=preload("res://scripts/characters/account_store.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
const ITEM="창고 검증 재료"
var checks: int=0
var failures: Array[String]=[]
var evidence: Dictionary={}
var prior: Dictionary={}
class Catalog extends RefCounted:
	var problem: String=""
	func profile(id: int,gender: int)->Dictionary:
		return {"name":ACCOUNT.JOBS[id],"stats":{"str":16,"dex":13,"con":16,"int":8,"wis":7,"cha":8},"source":{"ID":id}} if ACCOUNT.JOBS.has(id) and gender in [1,2] else {}
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("WAREHOUSE_BUSY_FAIL ",label)
func _initialize()->void:run.call_deferred()
func image(world: Node)->Dictionary:
	var v: Variant=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	return v if v is Dictionary else {}
func counts(world: Node)->Array:
	return [int(world.inventory.get(ITEM,0)),int(world.warehouse.stacks.get(ITEM,0))]
func tap(world: Node,quantity: int=1,direction: String="deposit")->int:
	var start: int=Time.get_ticks_usec()
	world.hud.warehouse_transfer_requested.emit(ITEM,quantity,direction,"")
	return Time.get_ticks_usec()-start
func prepare(world: Node)->void:
	world.set_process(false);world.save_timer=-100000;world.field_population.set_process(false);world.player.set_physics_process(false);world.player.auto_enabled=false
	world.background_save_enabled=true;world.deferred_save_enabled=true
	if world.item_db is Array:world.item_db.append({"name":ITEM,"type":"재료","weight":1})
	else:world.item_db[ITEM]={"name":ITEM,"type":"재료","weight":1}
	world.item_weight_index[ITEM]=1
func history()->Dictionary:
	var result: Dictionary={}
	for i: int in 400:
		var row: Dictionary={}
		for j: int in 32:row[str(j)]={"id":i,"values":[j,j+1,j+2],"state":"historical-extension"}
		result[str(i)]=row
	return result
func remember()->void:
	for n: String in DirAccess.get_files_at("user://"):
		if n.begins_with("twilight_v20_save"):prior[n]=FileAccess.get_file_as_bytes("user://"+n)
func restore()->void:
	for n: String in DirAccess.get_files_at("user://"):
		if n.begins_with("twilight_v20_save") and not prior.has(n):DirAccess.remove_absolute("user://"+n)
	for n: String in prior:
		var f:=FileAccess.open("user://"+n,FileAccess.WRITE);f.store_buffer(prior[n]);f.close()
func run()->void:
	remember()
	var baseline: bool="--warehouse-busy-baseline" in OS.get_cmdline_user_args()
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world);prepare(world)
	check(QA.enter_game(world),"actual Main entry")
	world.rng.seed=1234567;world.titles.state.rng="1234567";world.halphas_star.rng.seed=1234567;world.option_awakening.rng.seed=1234567;world.ain_service.last_regen_at=1700000000
	world.inventory[ITEM]=12
	var state: Dictionary=world.monsterbook523.export_state();state.historical_test_extension=history()
	check(world.monsterbook523.import_state(state),"valid synthetic retained history")
	check(not world._find_catalog_item_record(ITEM).is_empty(),"legacy material found by actual lookup")
	var samples: Array=[];var waits: Array=[]
	for round: int in 6:
		world.inventory[ITEM]=12;world.warehouse.stacks.erase(ITEM)
		check(world._save_game(true)==OK,"seed cloned test state")
		check(world._save_game(true,{},{},false,true)==OK and world.background_save_pending(),"actual autosave pending")
		HITCH._details.clear()
		var elapsed: int=tap(world)
		if round>0:samples.append(elapsed);waits.append(HITCH._details.get("save.wait",[0])[0])
		if baseline:
			check(counts(world)==[11,1],"baseline admitted and joined writer")
		else:
			check(counts(world)==[12,0] and world.background_save_pending(),"busy tap rejected without joining or mutation")
			check(world.hud.message_label.text.contains("실행하지 않았습니다"),"UI says request not executed and retry needed")
			for i: int in 3:tap(world)
			tap(world,1,"withdraw")
			check(counts(world)==[12,0],"duplicate pending taps are no-ops")
		world._finish_background_save(true)
		check(counts(world)==([11,1] if baseline else [12,0]),"no automatic replay on completion")
	evidence.busy_tap_usec=samples;evidence.busy_join_usec=waits
	if not baseline:
		HITCH._details.clear()
		var own_start: int=Time.get_ticks_usec();tap(world)
		evidence.unhooked_own_transaction_usec=Time.get_ticks_usec()-own_start
		evidence.unhooked_own_details=HITCH._details.duplicate(true)
	check(counts(world)==[11,1],"explicit retry reaches same result as original accepted transfer")
	var equivalent:=FileAccess.open("user://warehouse-equivalent.json",FileAccess.WRITE)
	equivalent.store_string(FileAccess.get_file_as_string(world.save_path()));equivalent.close()
	if baseline:
		world.queue_free();await process_frame;restore();finish();return
	# Restore the test starting state via an explicit, normally written withdrawal.
	tap(world,1,"withdraw");check(counts(world)==[12,0],"explicit withdrawal restores test starting state")
	# Menu switch and later live mutation cannot resurrect a rejected intent.
	check(world._save_game(true,{},{},false,true)==OK,"autosave before menu change")
	tap(world,12)
	world.hud._navigate("inventory")
	world._finish_background_save(true)
	world.inventory[ITEM]=11
	check(world._save_game(true)==OK,"newer live state durable")
	tap(world,12)
	check(counts(world)==[11,0],"explicit retry validates current count, no stale candidate")
	var writer_observed: Array=[]
	world.equipment_collections.test_save_writer=func(path: String,data: Dictionary)->Error:
		writer_observed.append(counts(world));return WRITER.write(path,data)
	var start: int=Time.get_ticks_usec();tap(world)
	evidence.instrumented_order_proof_usec=Time.get_ticks_usec()-start
	check(writer_observed==[[11,0]] and counts(world)==[10,1],"own write succeeds before live transfer")
	world.equipment_collections.test_save_writer=Callable()
	check(int(image(world).inventory.get(ITEM,0))==10 and int(image(world).warehouse.stacks.get(ITEM,0))==1,"same transfer durable")
	world._load_game(true);prepare(world)
	check(counts(world)==[10,1],"reload keeps exact transferred count")
	# Forced transaction failure: no live or durable move.
	var sha: String=FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_CANT_CREATE
	tap(world)
	check(counts(world)==[10,1] and FileAccess.get_sha256(world.save_path())==sha,"failed transaction preserves ownership")
	world.equipment_collections.test_save_writer=Callable()
	# Actual autosave writer failure never causes the rejected warehouse tap.
	DirAccess.make_dir_absolute(world.save_path()+".tmp")
	check(world._save_game(true,{},{},false,true)==OK,"failing worker scheduled")
	tap(world);var job: Dictionary=world._background_save_job;world._finish_background_save(true)
	check(int(job.error)!=OK and counts(world)==[10,1] and FileAccess.get_sha256(world.save_path())==sha,"failed worker and rejected tap preserve file and counts")
	DirAccess.remove_absolute(world.save_path()+".tmp")
	tap(world)
	check(counts(world)==[9,2],"explicit fresh retry after failure succeeds once")
	tap(world,1,"withdraw");check(counts(world)==[10,1],"explicit idle withdrawal ordered after deposit")
	tap(world);check(counts(world)==[9,2],"next explicit idle deposit sees latest state")
	# External file edit remains protected by the existing synchronous writer.
	var f:=FileAccess.open(world.save_path(),FileAccess.READ_WRITE);f.seek_end();f.store_string(" ");f.close()
	tap(world)
	check(counts(world)==[9,2] and world.equipment_collections.save_blocked,"external edit blocks fresh transaction")
	world._load_game(true);prepare(world);check(counts(world)==[9,2],"external-change reload preserves counts")
	# External replacement after worker rename but before main completion.
	check(world._save_game(true,{},{},false,true)==OK,"autosave before completion-window external edit")
	while not WorkerThreadPool.is_task_completed(world._background_save_task):OS.delay_usec(500)
	var outside: Dictionary=image(world);outside.gold=world.gold+777
	check(WRITER.write(world.save_path(),outside)==OK,"valid external file replacement")
	var outside_hash: String=FileAccess.get_sha256(world.save_path())
	tap(world);world._finish_background_save(false)
	check(world.equipment_collections.save_blocked and FileAccess.get_sha256(world.save_path())==outside_hash,"completion mismatch blocks instead of adopting external hash")
	tap(world)
	check(counts(world)==[9,2] and FileAccess.get_sha256(world.save_path())==outside_hash,"fresh retry cannot overwrite completion-window external edit")
	world._load_game(true);prepare(world)
	check(world.gold==int(outside.gold) and counts(world)==[9,2] and not world.equipment_collections.save_blocked,"reload adopts actual external state before another transaction")
	world.queue_free();await process_frame
	# Actual account writer/switch + new Main; rejected old intent cannot follow.
	ACCOUNT.session.clear();DirAccess.remove_absolute(ACCOUNT.DEFAULT_PATH)
	var store=ACCOUNT.new();check(store.open().get("ok",false),"fresh synthetic account")
	var a: Dictionary=store.create_character("창고첫째",1,1,Catalog.new());var b: Dictionary=store.create_character("창고둘째",3,2,Catalog.new())
	check(a.get("ok",false) and b.get("ok",false),"two real account profiles "+str([a,b]))
	if not a.get("ok",false) or not b.get("ok",false):restore();finish();return
	check(store.select_character(a.id).get("ok",false),"select character A")
	world=load("res://Main.tscn").instantiate();root.add_child(world);prepare(world)
	check(QA.enter_game(world),"character A actual entry")
	world.inventory[ITEM]=5
	check(world._save_game(true)==OK and world._save_game(true,{},{},false,true)==OK,"character A autosave pending")
	tap(world)
	world.queue_free();await process_frame
	store=ACCOUNT.new();check(store.open().get("ok",false) and store.select_character(b.id).get("ok",false),"actual account switches after worker completion")
	world=load("res://Main.tscn").instantiate();root.add_child(world);prepare(world)
	check(QA.enter_game(world,"마법사"),"character B actual entry")
	check(counts(world)==[0,0],"character B received no old request or shared warehouse deposit")
	for frame: int in 3:await process_frame
	check(counts(world)==[0,0],"no delayed callback after menu/character switch")
	world.queue_free();await process_frame
	store=ACCOUNT.new();check(store.open().get("ok",false) and store.select_character(a.id).get("ok",false),"switch back to A")
	world=load("res://Main.tscn").instantiate();root.add_child(world);prepare(world)
	check(QA.enter_game(world),"character A return entry")
	check(counts(world)==[5,0],"A retains item, shared warehouse empty after reload")
	world.queue_free();await process_frame;ACCOUNT.session.clear();restore();finish()
func finish()->void:
	print("WAREHOUSE_BUSY_RETRY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"actual Main/HUD/save/account + synthetic legacy material/history; no original native receipt/device claim"}))
	quit(0 if failures.is_empty() else 1)
