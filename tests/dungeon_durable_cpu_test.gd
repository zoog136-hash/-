extends SceneTree
## Actual synchronous account/writer used by world._save_game; isolated save and
## synthetic character records. Runs unchanged against the pre-change revision.
const ACCOUNT = preload("res://scripts/characters/account_store.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const COLLECTION = preload("res://scripts/collections/equipment_collection_runtime.gd")
const DUNGEON = preload("res://scripts/dungeons/dungeon_play_service.gd")
const LIVE = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const DORMANT = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const KEY = "source_dungeon_play"
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var path: String

class Hud extends Node:
	func append_log(_message: String) -> void: pass
class Host extends Node:
	var hud := Hud.new()

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("DUNGEON_DURABLE_CPU_FAIL ",label)

func item_rows(count: int, offset: int) -> Dictionary:
	var result: Dictionary={}
	for i: int in count:
		var info: Dictionary={"name":"검","level":i%10,"record":{"notes":[i,offset,"synthetic physical record"],"extra":{"n":int(i+offset),"metadata":"owned"}}}
		result[str(i+offset)]=info
	return result

func fixture_seed() -> Dictionary:
	var account: Dictionary={"schema":ACCOUNT.SCHEMA,"selected":LIVE,"revision":60,"shared":{"retained_unknown":{"v":42}},"characters":[
		{"id":LIVE,"name":"첫기사","class_id":1,"gender_id":1,"initialized":true,"state":{},"retained_field":{"n":10}},
		{"id":DORMANT,"name":"둘기사","class_id":1,"gender_id":1,"initialized":true,"state":{"job_class":ACCOUNT.JOBS[1],"source_visual_context":{"snapshot":"base508","gender_id":1},"character_source_cursor":{"native_land_id":4,"source_position":[32600,32800]},"item_instances":item_rows(600,5000)}}
	]}
	var payload: Dictionary={
		ACCOUNT.KEY:account,"job_class":ACCOUNT.JOBS[1],"source_visual_context":{"snapshot":"base508","gender_id":1},"character_source_cursor":{"native_land_id":4,"source_position":[32600,32800]},
		"item_instances":item_rows(2500,20000),"inventory":{"검":2500},"gold":708,"warehouse":{"instances":{},"stacks":{}},"card_option_awakening":{"choices":{"x":5},"native_subslot_identity":"selected"},"consumable_state":{"source_native_stack_uses":{"x":{"marker":5}},"hunger":10},KEY:DUNGEON.empty_state()
	}
	return ACCOUNT.seal_payload(payload).get("payload",{})

func body_from_disk() -> Dictionary:
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK or not parser.data is Dictionary:return {}
	var body: Dictionary=parser.data
	ACCOUNT.expand(body)
	return body

func remember(writer: RefCounted, envelope: Dictionary) -> void:
	if writer.has_method("verified_payload_sha"):
		load("res://scripts/characters/account_store.gd").call("remember_verified_durable",path,envelope,writer.verified_payload_sha(path))
	else:ACCOUNT.remember_durable(path,envelope)

func write_checkpoint(writer: RefCounted, body: Dictionary) -> Error:
	if writer.has_method("verified_payload_sha"):return writer.call("write_save",path,body,false)
	return writer.write_save(path,body)

func summarize_usec(values: Array[int]) -> Dictionary:
	var ordered: Array[int]=values.duplicate()
	ordered.sort()
	return {"p50":ordered[ordered.size()/2],"p95":ordered[ceili(ordered.size()*0.95)-1],"samples":values}

func run() -> void:
	path="user://dungeon-durable-cpu-"+str(Time.get_ticks_usec())+".json"
	var payload: Dictionary=fixture_seed()
	check(not payload.is_empty(),"valid v2 fixture")
	if payload.is_empty():quit(1);return
	var host := Host.new()
	root.add_child(host);host.add_child(host.hud)
	var writer:=COLLECTION.new();writer.world=host
	check(writer.write_save(path,ACCOUNT.compact(payload))==OK,"seed physically durable")
	ACCOUNT.session={"path":path,"id":LIVE,"initialized":true}
	remember(writer,payload[ACCOUNT.KEY])
	var probe_value: Dictionary=body_from_disk()
	probe_value.item_instances.erase("22499")
	probe_value.inventory["검"]-=1
	probe_value.next_item_instance_id=1
	probe_value[KEY].revision=10
	var expected:=ACCOUNT.stage_save(path,probe_value)
	check(expected.get("ok",false),"staged a new transaction")
	if not expected.get("ok",false):quit(1);return
	check(int(expected.payload.next_item_instance_id)>=22500,"allocator includes removed prior selected IDs")
	check(ACCOUNT.validate(expected.payload).is_empty(),"full validation of staged account")
	var frozen: String=JSON.stringify(expected.payload,"",true,true)
	expected.payload.item_instances["20000"].record.notes[0]=-7
	ACCOUNT.selected_record(expected.payload).state.item_instances["20001"].record.notes[0]=-9
	expected.payload[ACCOUNT.KEY].characters[1].state.item_instances["5000"].record.notes[0]=-3
	expected.payload[ACCOUNT.KEY].shared.retained_unknown.v=-3
	check(JSON.stringify(ACCOUNT.stage_save(path,probe_value).payload,"",true,true)==frozen,"returned branches do not alias the producer or trusted cached account")
	var stages: Array[int]=[]
	var writes: Array[int]=[]
	for i: int in 13:
		probe_value[KEY].revision=11+i
		var start: int=Time.get_ticks_usec()
		var staged: Dictionary=ACCOUNT.stage_save(path,probe_value)
		var stage_elapsed: int=Time.get_ticks_usec()-start
		check(staged.get("ok",false),"checkpoint stages")
		if not staged.get("ok",false):break
		var file_value: Dictionary=ACCOUNT.compact(staged.payload)
		start=Time.get_ticks_usec()
		ACCOUNT.forget_durable()
		var error: Error=write_checkpoint(writer,file_value)
		if error==OK:remember(writer,staged.payload[ACCOUNT.KEY])
		var write_elapsed: int=Time.get_ticks_usec()-start
		check(error==OK,"checkpoint is durable before return")
		if i>0:stages.append(stage_elapsed);writes.append(write_elapsed)
		if i==12:
			var durable: Dictionary=body_from_disk()
			check(ACCOUNT.validate(durable).is_empty() and int(durable[KEY].revision)==23,"fresh load sees latest ledger")
			check(durable.item_instances.size()==2499 and durable[ACCOUNT.KEY].characters[1].state.item_instances.size()==600,"item ownership untouched by checkpoint")
			check(FileAccess.get_sha256(path)==JSON.stringify(file_value,"",true,true).sha256_text(),"exact canonical bytes")
	evidence={"account_usec":summarize_usec(stages),"write_and_remember_usec":summarize_usec(writes),"file_bytes":FileAccess.get_size(path),"durable_sha_before_external":FileAccess.get_sha256(path)}
	var durable: Dictionary=body_from_disk()
	var durable_revision: int=int(durable[ACCOUNT.KEY].revision)
	var untouched: Dictionary=ACCOUNT.stage_save(path,probe_value).payload
	check(int(untouched[ACCOUNT.KEY].revision)==durable_revision,"identical account stage retains revision")
	var file_value: Dictionary=ACCOUNT.compact(untouched)
	var sha: String=FileAccess.get_sha256(path)
	var old_writes: int=writer.save_writes
	check(write_checkpoint(writer,file_value)==OK and writer.save_writes==old_writes and FileAccess.get_sha256(path)==sha,"exact bytes still skip without typed snapshot")
	var economic: Dictionary=untouched.duplicate(true)
	economic.gold=709
	var economic_stage: Dictionary=ACCOUNT.stage_save(path,economic)
	check(writer.write_save(path,ACCOUNT.compact(economic_stage.payload))==OK and writer._last_payload_snapshot_valid,"unrelated saves retain typed cache policy")
	remember(writer,economic_stage.payload[ACCOUNT.KEY])
	var newer: Dictionary=body_from_disk()
	newer[ACCOUNT.KEY].revision+=20
	check(WRITER.write(path,ACCOUNT.compact(newer))==OK,"outside replacement fixture")
	var external_sha: String=FileAccess.get_sha256(path)
	var after: Dictionary=ACCOUNT.stage_save(path,economic)
	check(after.get("ok",false) and int(after.payload[ACCOUNT.KEY].revision)>=int(newer[ACCOUNT.KEY].revision),"old durable proof cannot be associated with external revision")
	check(write_checkpoint(writer,ACCOUNT.compact(after.payload))==ERR_BUSY and FileAccess.get_sha256(path)==external_sha,"checkpoint cannot overwrite outside replacement")
	ACCOUNT.session={};ACCOUNT.forget_durable()
	DirAccess.remove_absolute(path)
	host.queue_free();await process_frame
	print("DUNGEON_DURABLE_CPU_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
