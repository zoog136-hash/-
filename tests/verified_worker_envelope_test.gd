extends SceneTree
## The finished worker can hand off only its own sealed graph and the
## writer-verified content digest. Keep external replacements distinguishable.
const A=preload("res://scripts/characters/account_store.gd")
const EQ=preload("res://scripts/collections/equipment_collection_runtime.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
var fails: Array[String]=[];var n:=0
func ck(v: bool,m: String)->void:
	n+=1
	if not v:fails.append(m);printerr("WORKER_ENVELOPE_FAIL ",m)
func _initialize()->void:
	var path: String="user://hash-bound-envelope-"+str(Time.get_ticks_usec())+".json"
	var background_path: String=path+".detached"
	var extra: Dictionary={"source":"frozen"}
	var work: Dictionary={"path":background_path,"data":{"gold":33,"protection523":extra},"prior_hash":"","error":ERR_BUSY}
	preload("res://scripts/world.gd")._run_background_save(work)
	ck(work.error==OK and work.has("data") and work.has("payload") and not work.has("extras") and work.envelope==null,"flat saves stay on old ownership path")
	ck(work.payload.protection523==extra,"flat save preserved its extra field")
	DirAccess.remove_absolute(background_path)
	var fixture=preload("res://tests/dungeon_durable_cpu_test.gd").new()
	var sealed: Dictionary=fixture.fixture_seed();fixture.free()
	background_path=path+".v2"
	ck(WRITER.write(background_path,A.compact(sealed))==OK,"seed actual sealed v2")
	A.session={"path":background_path,"id":sealed[A.KEY].selected,"initialized":true}
	var field: Dictionary={"marker":[1,2]};sealed.protection523=field
	work={"path":background_path,"data":sealed,"prior_hash":FileAccess.get_sha256(background_path),"error":ERR_BUSY}
	preload("res://scripts/world.gd")._run_background_save(work)
	ck(work.error==OK and work.envelope is Dictionary and work.extras.protection523==field and not work.has("data") and not work.has("payload"),"v2 worker only transfers sealed graph and required extras")
	field.marker.append(9);ck(work.extras.protection523.marker==[1,2],"v2 extra independent of mutable caller")
	DirAccess.remove_absolute(background_path);A.session={};A.forget_durable()
	var bytes: String=JSON.stringify({"committed":true});var sha:=bytes.sha256_text()
	ck(WRITER.write_text(path,bytes)==OK,"seed")
	var writer:=EQ.new()
	var graph: Dictionary={"shared":{"inventory":{"a":1}}}
	var job: Dictionary={"envelope":graph,"payload_hash":sha}
	ck(writer.commit_written(path,{},sha)==OK,"actual main completion seals digest")
	# Interleave an external replacement after verified publication, before the
	# cache is installed. It may not be paired with the old graph.
	ck(WRITER.write_text(path,"{}")==OK,"interleaved new file")
	A.adopt_verified_worker_envelope(path,job,writer.verified_payload_sha(path))
	ck(not job.has("envelope") and is_same(graph,A._durable.envelope),"private graph moves out of joined job")
	ck(A._durable.sha==sha and FileAccess.get_sha256(path)!=A._durable.sha,"external bytes cannot authenticate old graph")
	A.adopt_verified_worker_envelope(path,{"envelope":{},"payload_hash":sha},"bad")
	ck(A._durable.is_empty(),"mismatched receipt cannot enter cache")
	A.adopt_verified_worker_envelope(path,{"envelope":null,"payload_hash":sha},sha)
	ck(A._durable.is_empty(),"missing envelope cannot enter cache")
	var input: Dictionary={"live":{"a":1}}
	A.remember_verified_durable(path,input,sha);input.live.a=3
	ck(A._durable.envelope.live.a==1,"ordinary caller remains detached")
	# Simulate an interrupted temp write; only the canonical file is read.
	var temp:=FileAccess.open(path+".tmp",FileAccess.WRITE);temp.store_string("{");temp.close()
	ck(FileAccess.get_file_as_string(path)=="{}","partial temp is not committed state")
	ck(WRITER.write_text_if_unchanged(path,bytes,sha)==ERR_BUSY and FileAccess.get_file_as_string(path)=="{}","stale worker cannot clobber replacement")
	ck(WRITER.write_text_if_unchanged(path,bytes,FileAccess.get_sha256(path))==OK and FileAccess.get_sha256(path)==sha,"retry uses original atomic writer and new correct identity")
	DirAccess.remove_absolute(path);A.forget_durable()
	print("VERIFIED_WORKER_ENVELOPE_RESULT ",JSON.stringify({"checks":n,"failures":fails}))
	quit(0 if fails.is_empty() else 1)
