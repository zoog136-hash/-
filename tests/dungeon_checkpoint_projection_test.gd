extends "res://tests/dungeon_durable_cpu_test.gd"
## Matched file transitions from the same previous durable state. Includes
## the synchronous writer and canonical SHA, not just an isolated duplication.
## Uses the synthetic 3,100-item, two-character account of the prior regression.
func run() -> void:
	var starting: Dictionary=fixture_seed()
	check(not starting.is_empty(),"valid seed")
	var host:=Host.new()
	root.add_child(host);host.add_child(host.hud)
	var owners: Array=[]
	var paths: Array[String]=[]
	var priors: Array[Dictionary]=[]
	for arm: int in 2:
		paths.append("user://dungeon-projection-%s-%s.json"%[str(Time.get_ticks_usec()),str(arm)])
		var writer:=COLLECTION.new();writer.world=host;owners.append(writer)
		check(writer.write_save(paths[arm],ACCOUNT.compact(starting))==OK,"seed writer")
		priors.append(starting[ACCOUNT.KEY])
	var body: Dictionary=starting.duplicate(true)
	var stages: Array=[[],[]]; var totals: Array=[[],[]]
	for round_id: int in 13:
		body[KEY].revision+=1
		var hashes: Array[String]=[]
		var order: Array=[0,1] if round_id%2==0 else [1,0]
		for arm: int in order:
			var file: String=paths[arm]
			var writer: RefCounted=owners[arm]
			ACCOUNT.session={"path":file,"id":LIVE,"initialized":true}
			ACCOUNT.remember_verified_durable(file,priors[arm],FileAccess.get_sha256(file))
			var start: int=Time.get_ticks_usec()
			var staged: Dictionary
			if arm==0:
				var prior:=ACCOUNT.stage_save(file,body)
				if not prior.ok: check(false,"baseline stage");quit(1);return
				staged={"ok":true,"payload":ACCOUNT.compact(prior.payload),"envelope":prior.payload[ACCOUNT.KEY]}
			else:staged=ACCOUNT.stage_checkpoint_write(file,body)
			var stage_done: int=Time.get_ticks_usec()
			if not staged.ok: check(false,"compact stage");quit(1);return
			ACCOUNT.forget_durable()
			var wrote: Error=writer.write_save(file,staged.payload,false)
			ACCOUNT.remember_verified_durable(file,staged.envelope,writer.verified_payload_sha(file))
			var done: int=Time.get_ticks_usec()
			check(wrote==OK and writer.save_writes==round_id+2,"every changed checkpoint durable now")
			if round_id>0:
				stages[arm].append(stage_done-start);totals[arm].append(done-start)
			priors[arm]=staged.envelope
			hashes.append(FileAccess.get_sha256(file))
		check(hashes[0]==hashes[1] and not hashes[0].is_empty(),"exact pre/post on-disk bytes each revision")
	check(priors[0]==priors[1],"selected, dormant and shared envelope identical")
	var approved: Dictionary=ACCOUNT.stage_checkpoint_write(ACCOUNT.session.path,body)
	var body_before: String=JSON.stringify(body,"",true,true)
	approved.payload.item_instances["20000"].record.notes[0]=-9
	approved.payload.card_option_awakening.choices.x=-9
	approved.envelope.characters[1].state.item_instances["5000"].record.notes[0]=-7
	check(JSON.stringify(body,"",true,true)==body_before and int(ACCOUNT._durable.envelope.characters[1].state.item_instances["5000"].record.notes[0])==0,"write views detached from gameplay and prior durable cache")
	var corrupt: Dictionary=body.duplicate(true)
	corrupt.item_instances["5000"]=corrupt.item_instances["20000"]
	var a:=ACCOUNT.stage_save(ACCOUNT.session.path,corrupt)
	var b:=ACCOUNT.stage_checkpoint_write(ACCOUNT.session.path,corrupt)
	check(not a.ok and b==a,"cross-character duplicate remains blocked with same reason")
	ACCOUNT.session={};ACCOUNT.forget_durable()
	for file: String in paths:DirAccess.remove_absolute(file)
	host.queue_free();await process_frame
	print("DUNGEON_CHECKPOINT_PROJECTION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"pc_stage_us_old_new":stages,"pc_stage_write_remember_us_old_new":totals}))
	quit(0 if failures.is_empty() else 1)
