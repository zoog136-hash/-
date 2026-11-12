extends SceneTree
## Optional synthetic CPU/Variant comparison; never a latency threshold.
## git show 4c78a97:scripts/quests/quest_service.gd > /tmp/quest-service-before.gd
## XDG_DATA_HOME=/tmp/quest-reads-data XDG_CONFIG_HOME=/tmp/quest-reads-config \
## XDG_CACHE_HOME=/tmp/quest-reads-cache godot --headless --path . \
##   --script res://tools/benchmarks/benchmark_quest_category_record_reads.gd \
##   -- --baseline=/tmp/quest-service-before.gd --output=/tmp/quest-reads.json
## Baseline code is supplied explicitly, not copied into this repository.
## Both services use the actual SourceQuest decoder, reward planner and verified
## BAKE RecordFile with synthetic 3621/906-row input. No private source, real
## artwork, GPU, APK termination or Android elapsed-time result is measured.
## Engine static allocations and sampled peaks differ from process RSS; RSS
## may remain high after the allocator releases/reuses all returned row data.
const SERVICE=preload("res://scripts/quests/quest_service.gd")
const SOURCE=preload("res://scripts/quests/source_quest523.gd")
const BAKE=preload("res://scripts/resources/current523_bake_cache.gd")
const COUNT=3621
const NOW=1794460000
const MAX_FILE_BYTES=32*1024*1024
const MAX_RSS_GROWTH_KB=384*1024
var failures: Array[String]=[]
var reports: Array=[]
var baseline_rss_kb: int=-1
var output_path: String=""
var baseline_sha256: String=""
class TracedRecords extends RefCounted:
	var inner: RefCounted
	var file: FileAccess
	var offsets: Dictionary
	var sizes: Dictionary
	var read_calls: int=0
	var requested_bytes: int=0
	func has(id: String) -> bool:return inner.has(id)
	func read(id: String) -> Variant:
		read_calls+=1
		requested_bytes+=int(sizes.get(id,0))
		return inner.read(id)
class TracedSource extends "res://scripts/quests/source_quest523.gd":
	var reads: int=0
	var gates: int=0
	var plans: int=0
	var begins: int=0
	var ends: int=0
	var bulk_bytes: int=0
	var sampled_peak: int=0
	func _read_record(id: String) -> Dictionary:
		reads+=1
		var value: Dictionary=super._read_record(id)
		if reads%64==0:sampled_peak=maxi(sampled_peak,OS.get_static_memory_usage())
		return value
	func begin_bulk() -> void:
		begins+=1
		super.begin_bulk()
		bulk_bytes=_bulk.size()
		sampled_peak=maxi(sampled_peak,OS.get_static_memory_usage())
	func end_bulk() -> void:ends+=1;super.end_bulk()
	func gate(row: Dictionary, context: Dictionary, claimed: Dictionary, now: int) -> String:
		gates+=1
		return super.gate(row,context,claimed,now)
	func reward_plan(row: Dictionary, context: Dictionary) -> Dictionary:
		plans+=1
		return super.reward_plan(row,context)
	func reset() -> void:
		reads=0;gates=0;plans=0;begins=0;ends=0;bulk_bytes=0
		sampled_peak=OS.get_static_memory_usage()
		_records.read_calls=0;_records.requested_bytes=0
func _initialize() -> void:_run.call_deferred()
func _row(index: int, chars: int) -> Dictionary:
	var item: Dictionary={"ID":5000+index%765,"Name":"Synthetic item "+str(index%765)}
	for field: int in range(16):item["synthetic_field_%d"%field]=("field-%d-"%field)+"x".repeat(chars)
	return {"id":"m523:quest:"+str(index+1),"source_id":index+1,"title":"Synthetic "+str(index),"category":["main","common","achievement","other"][index%4],"definition":{"ID":index+1,"Name":"Synthetic","TypeID":0},"prerequisites":[{"type_name":"MinLevel","Value":1}],"goals":[{"type_name":"Level","CharacterClassID":0,"Amount":1,"relation":{"GoalPredicateTypeID":1}}],"source_rewards":[{"ID":index+1,"CharacterClassID":0,"ClanOnly":false,"RewardEnhancementTypeID":1,"Amount":1,"RewardClassID":item.ID,"type_name":"Item","source_item":item,"ItemBlessCodeID":1,"UseImmediately":false}],"enhancements":[],"blockers":[],"excluded_reasons":[],"starts_at":0,"ends_at":4102444800,"description":"synthetic description ".repeat(8),"objective":{"kind":"source","count":1,"target":""},"rewards":{},"min_level":1}
func _rss() -> int:
	# /proc pseudo-files report length zero; read lines rather than a length-
	# sized buffer. Non-Linux platforms simply omit this optional guard.
	if not OS.has_feature("linux"):return -1
	var file:=FileAccess.open("/proc/self/status",FileAccess.READ)
	if file==null:return -1
	while not file.eof_reached():
		var line: String=file.get_line()
		if line.begins_with("VmRSS:"):
			for part: String in line.replace("\t"," ").split(" ",false):
				if part.is_valid_int():return int(part)
	return -1

func _digest(rows: Array) -> String:
	var hash:=HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for row: Dictionary in rows:hash.update(var_to_bytes(row))
	return hash.finish().hex_encode()
func _fixture(chars: int, baseline_script: Script) -> Dictionary:
	var name: String="quest-seek-synthetic-%d-%d"%[OS.get_process_id(),chars]
	var key: String="synthetic-3621-16fields-"+str(chars)
	var writer=BAKE.record_writer(name,key)
	if writer==null:failures.append("writer failed");return {}
	var source:=TracedSource.new()
	var baseline: RefCounted=baseline_script.new()
	var candidate: RefCounted=SERVICE.new()
	var sizes: Dictionary={}
	for index: int in range(COUNT):
		var full: Dictionary=_row(index,chars)
		var at: int=writer.file.get_position()
		writer.add(full.id,full)
		sizes[full.id]=writer.file.get_position()-at
		if writer.file.get_position()>MAX_FILE_BYTES:
			writer.abort();failures.append("synthetic file bound exceeded");return {}
		var hot: Dictionary=SOURCE._compact(full)
		if hot.is_empty():failures.append("fixture compaction failed");writer.abort();return {}
		source.quests.append(hot)
		for service: RefCounted in [baseline,candidate]:service.quests.append(hot);service.index[hot.id]=hot
	if not BAKE.finish_records(writer):failures.append("record commit failed");BAKE.clear(name);return {}
	var records: RefCounted=BAKE.open_records(name,key)
	if records==null:failures.append("verified record open failed");BAKE.clear(name);return {}
	var traced:=TracedRecords.new()
	traced.inner=records;traced.file=records.file;traced.offsets=records.offsets;traced.sizes=sizes
	source._records=traced
	for service: RefCounted in [baseline,candidate]:
		service.source=source
		service.day_key=SERVICE.korean_daily_key(NOW)
		service.claimed={"old-history":true}
		service.source_context={"level":50,"class_id":1,"source_items":{},"currency_items":{}}
	return {"name":name,"key":key,"source":source,"baseline":baseline,"candidate":candidate,"file_bytes":records.file.get_length(),"sha256":FileAccess.get_sha256(BAKE.data_path(name))}
func _measure(f: Dictionary, label: String, service: RefCounted, category: bool, digests: Dictionary) -> Dictionary:
	f.source.reset()
	var state: Dictionary=service.export_state()
	var before: int=OS.get_static_memory_usage()
	var started: int=Time.get_ticks_usec()
	var rows: Array=service.entries_for_category(50,{},"main",NOW) if category else service.entries(50,{},NOW)
	var usec: int=Time.get_ticks_usec()-started
	var held: int=OS.get_static_memory_usage()
	var result: Dictionary={"case":label,"category":"main" if category else "all","rows":rows.size(),"usec":usec,"materializations":f.source.reads,"gates":f.source.gates,"plans":f.source.plans,"begin_calls":f.source.begins,"end_calls":f.source.ends,"bulk_bytes":f.source.bulk_bytes,"record_file_read_calls":f.source._records.read_calls,"record_requested_bytes_estimate":f.source._records.requested_bytes,"engine_static_before":before,"engine_static_with_rows":held,"engine_static_rows_delta":held-before,"sampled_engine_static_peak":f.source.sampled_peak,"rss_with_rows_kb":_rss()}
	var digest: String=_digest(rows)
	var digest_key: String="main" if category else "all"
	if digests.has(digest_key) and digests[digest_key]!=digest:failures.append("rows/order/full nested values differ between strategies")
	digests[digest_key]=digest
	result["rows_sha256"]=digest
	if service.export_state()!=state:failures.append("browsing changed claim/save state")
	var expected: int=906 if category else COUNT
	if rows.size()!=expected or f.source.reads!=expected or f.source.gates!=expected or f.source.plans!=expected:failures.append("Wrong requested row/materialization/gate/reward-plan counts.")
	var expects_bulk: bool=not category or label=="baseline_category"
	if f.source.begins!=(1 if expects_bulk else 0) or f.source.ends!=(1 if expects_bulk else 0) or f.source.bulk_bytes!=(f.file_bytes if expects_bulk else 0):failures.append("Baseline must be the actual #419 whole-bulk service; current category must skip only its own begin/end.")
	if f.source._records.read_calls!=(0 if expects_bulk else expected):failures.append("RecordFile reads differ from the selected bulk/per-record path.")
	if not f.source._bulk.is_empty():failures.append("bulk retained after call")
	rows.clear()
	result["engine_static_after_rows_release"]=OS.get_static_memory_usage()
	result["rss_after_rows_release_kb"]=_rss()
	return result
func _run_size(chars: int, baseline_script: Script) -> Dictionary:
	var f: Dictionary=_fixture(chars,baseline_script)
	if f.is_empty():return {}
	var results: Array=[]
	var digests: Dictionary={}
	for round_index: int in range(2):
		var cases: Array=[["baseline_all",f.baseline,false],["candidate_all",f.candidate,false],["baseline_category",f.baseline,true],["candidate_seek_category",f.candidate,true]]
		if round_index==1:cases.reverse()
		for args: Array in cases:
			if baseline_rss_kb>=0 and _rss()>baseline_rss_kb+MAX_RSS_GROWTH_KB:failures.append("384MiB process RSS growth guard reached; remaining measurements skipped.");break
			var result: Dictionary=_measure(f,args[0],args[1],args[2],digests)
			result["round"]=round_index+1
			results.append(result)
	var first: Dictionary=f.source.detached(f.source.quests[0])
	first.definition.Name="only a returned copy"
	var independent: bool=f.source.detached(f.source.quests[0]).definition.Name=="Synthetic"
	if not independent:failures.append("detached row no longer independent")
	# Existing bounded fallback: an insufficient bulk header falls back to
	# the same verified/open RecordFile read, with the same row identity guard.
	f.source._bulk=PackedByteArray([0,0,0])
	var fallback: Dictionary=f.source._read_record("m523:quest:1")
	f.source.end_bulk()
	if fallback.get("id")!="m523:quest:1":failures.append("existing truncated-bulk fallback failed")
	# A category call inside an explicitly held outer bulk does not clear or
	# replace that owner's snapshot when begin/end are skipped.
	f.source.begin_bulk()
	var outer_size: int=f.source._bulk.size()
	var nested: Array=f.candidate.entries_for_category(50,{},"main",NOW)
	var outer_preserved: bool=f.source._bulk.size()==outer_size
	nested.clear()
	f.source.end_bulk()
	if not outer_preserved:failures.append("outer bulk ownership changed")
	var unchanged: bool=FileAccess.get_sha256(BAKE.data_path(f.name))==f.sha256
	if not unchanged:failures.append("The benchmark changed verified synthetic record bytes.")
	var report: Dictionary={"metadata_field_chars":chars,"file_bytes":f.file_bytes,"synthetic_file_sha256":f.sha256,"unchanged_file_sha256":unchanged,"independent_rows":independent,"nested_outer_bulk_preserved":outer_preserved,"truncated_bulk_uses_existing_fallback":fallback.get("id")=="m523:quest:1","measurements":results}
	f.source._records.file.close();f.source._records=null
	BAKE.clear(f.name)
	return report
func _run() -> void:
	var baseline_path: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--baseline="):baseline_path=value.trim_prefix("--baseline=")
		elif value.begins_with("--output="):output_path=value.trim_prefix("--output=")
	if not baseline_path.is_absolute_path() or not FileAccess.file_exists(baseline_path):
		printerr("QUEST_CATEGORY_RECORD_READS_BENCHMARK requires --baseline=/absolute/path/to/419/quest_service.gd (see the git show example).")
		quit(2);return
	var baseline:=GDScript.new()
	# The actual service is already registered under this class_name. Removing
	# only its registration lets the supplied baseline coexist in one process.
	baseline.source_code=FileAccess.get_file_as_string(baseline_path).replace("class_name TwilightQuestService", "")
	baseline_sha256=FileAccess.get_sha256(baseline_path)
	if baseline.reload()!=OK:
		printerr("QUEST_CATEGORY_RECORD_READS_BENCHMARK baseline failed to compile.")
		quit(2);return
	var probe: RefCounted=baseline.new()
	if not probe.has_method("entries") or not probe.has_method("entries_for_category"):
		printerr("QUEST_CATEGORY_RECORD_READS_BENCHMARK baseline lacks the #419 service API.")
		quit(2);return
	probe=null
	baseline_rss_kb=_rss()
	for chars: int in [16,64,256]:
		reports.append(_run_size(chars,baseline))
		if not failures.is_empty():break
	var result: Dictionary={"engine":Engine.get_version_info().string,"baseline_sha256":baseline_sha256,"scope":"synthetic verified BAKE RecordFile 3621/906; actual SourceQuest decoder/reward planner; supplied baseline/current QuestService; warm OS-cache desktop CPU; sampled engine static is not RSS/GPU; no private bake/Android OOM/latency claim or speed threshold","file_cap_bytes":MAX_FILE_BYTES,"rss_growth_guard_kb":MAX_RSS_GROWTH_KB,"initial_process_rss_kb":baseline_rss_kb,"reports":reports,"failures":failures}
	if not output_path.is_empty():
		var file:=FileAccess.open(output_path,FileAccess.WRITE)
		if file==null:failures.append("Cannot write requested --output report: "+str(FileAccess.get_open_error()))
		else:file.store_string(JSON.stringify(result,"\t"));file.close()
	print("QUEST_CATEGORY_RECORD_READS_BENCHMARK ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
