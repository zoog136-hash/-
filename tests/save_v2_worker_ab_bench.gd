extends "res://tests/dungeon_durable_cpu_test.gd"
## Paired original vs new worker + completion with a real v2 sealed account.
## One Godot process, dedicated files, same payload and expected canonical SHA.
const W=preload("res://scripts/world.gd")
static func old_worker(j: Dictionary)->void:
	var stage: Dictionary=ACCOUNT.stage_save(j.path,j.data)
	if not stage.ok:j.error=ERR_INVALID_DATA;return
	var payload: Dictionary=stage.payload;j.envelope=payload.get(ACCOUNT.KEY)
	payload=ACCOUNT.compact(payload);ACCOUNT.forget_durable()
	var value:=JSON.stringify(payload,"",true,true);j.payload_hash=value.sha256_text();j.payload=payload
	j.error=WRITER.write_text_if_unchanged(j.path,value,j.prior_hash)
func old_finish(w: Node)->void:
	WorkerThreadPool.wait_for_task_completion(w._background_save_task);w._background_save_task=-1
	var j: Dictionary=w._background_save_job;w._background_save_job={}
	check(j.error==OK and w.equipment_collections.commit_written(j.path,j.payload,j.payload_hash)==OK,"old publication verified")
	if j.get("envelope") is Dictionary:ACCOUNT.remember_durable(j.path,j.envelope)
	if not ACCOUNT.session.is_empty() and ACCOUNT.session.path==j.path:ACCOUNT.session.initialized=true
	for key: String in ["protection523","expedition523_local","patch523_transaction_rng"]:
		if j.payload.has(key):w.equipment_collections.extra_save_fields[key]=j.payload[key].duplicate(true)
func run()->void:
	var original: Dictionary=fixture_seed();var flat: bool=false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--flat-sample="):
			var sample: Variant=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--flat-sample=")))
			if not sample is Dictionary or sample.has(ACCOUNT.KEY) or sample.get("monsterbook523",{}).get("historical_test_extension",{}).size()!=400:printerr("expected synthetic save_snapshot_budget_test flat fixture");quit(2);return
			original=sample;flat=true
	var body:=original.duplicate(true)
	var host:=Host.new();root.add_child(host);host.add_child(host.hud)
	var worlds: Array=[];var paths: Array[String]=[];var priors: Array=[]
	for arm: int in 2:
		var w:=W.new();w.equipment_collections.world=host;worlds.append(w)
		paths.append("user://v2-worker-"+str(Time.get_ticks_usec())+"-"+str(arm)+".json")
		ck_seed(w.equipment_collections.write_save(paths[arm],ACCOUNT.compact(original)))
		priors.append(original.get(ACCOUNT.KEY,{}))
	var worker: Array=[[],[]];var finish: Array=[[],[]];var total: Array=[[],[]]
	for pair: int in 9:
		body["gold"]=1234+pair
		var hashes: Array[String]=[]
		for arm: int in ([0,1] if pair%2==0 else [1,0]):
			var w: Node=worlds[arm];var file: String=paths[arm]
			var prior_hash:=FileAccess.get_sha256(file)
			ACCOUNT.session={} if flat else {"path":file,"id":LIVE,"initialized":true}
			if flat:ACCOUNT.forget_durable()
			else:ACCOUNT.remember_verified_durable(file,priors[arm],prior_hash)
			var j: Dictionary={"path":file,"data":body.duplicate(true),"prior_hash":prior_hash,"error":ERR_BUSY}
			w._background_save_job=j
			var op: Callable=old_worker.bind(j) if arm==0 else W._run_background_save.bind(j)
			j={}
			var start:=Time.get_ticks_usec()
			w._background_save_task=WorkerThreadPool.add_task(op);op=Callable()
			while not WorkerThreadPool.is_task_completed(w._background_save_task):OS.delay_usec(100)
			var completed:=Time.get_ticks_usec()
			var transferred: bool=w._background_save_job.has("extras")
			if arm==0:old_finish(w)
			else:w._finish_background_save(false)
			var done:=Time.get_ticks_usec()
			if pair>0:
				worker[arm].append(completed-start);finish[arm].append(done-completed);total[arm].append(done-start)
			var sha:=FileAccess.get_sha256(file);hashes.append(sha)
			check(transferred==(arm==1 and not flat),"new ownership transfer only for selected live v2 character")
			if flat:check(ACCOUNT._durable.is_empty(),"legacy never enters v2 cache adoption")
			else:
				check(ACCOUNT._durable.get("sha")==sha and ACCOUNT._durable.get("envelope",{}).get("characters",[]).size()==2,"both v2 characters published against verified digest")
				priors[arm]=ACCOUNT._durable.envelope
			var persisted: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file))
			check(persisted.gold==body.gold and ((not persisted.has(ACCOUNT.KEY)) if flat else persisted[ACCOUNT.KEY].characters.size()==2),"file contains both characters and latest gold")
		check(hashes[0]==hashes[1],"old/new same canonical save bytes each round")
	for w: Node in worlds:w.free()
	for f: String in paths:DirAccess.remove_absolute(f)
	host.queue_free();await process_frame;ACCOUNT.session={};ACCOUNT.forget_durable()
	print("SAVE_V2_WORKER_AB_RESULT ",JSON.stringify({"flat_no_account":flat,"checks":checks,"failures":failures,"worker_us":worker,"main_publish_us":finish,"total_us":total}))
	quit(0 if failures.is_empty() else 1)
func ck_seed(result: Error)->void:check(result==OK,"independent seeded file")
