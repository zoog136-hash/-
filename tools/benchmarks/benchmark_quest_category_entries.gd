extends SceneTree
## Optional synthetic CPU/Variant benchmark, never a CI latency threshold.
## mkdir -p /tmp/quest-category-bench-data /tmp/quest-category-bench-cache
## XDG_DATA_HOME=/tmp/quest-category-bench-data XDG_CACHE_HOME=/tmp/quest-category-bench-cache \
##   godot --headless --path . --script res://tools/benchmarks/benchmark_quest_category_entries.gd
## Writes its own synthetic RecordFile under user:// and removes it afterward.
## No private pack/source data, source-pack hash, real UI/GPU or Android memory
## behavior is measured. Engine static allocations differ from process RSS;
## allocators may retain RSS after all returned row Variants are released.
const SERVICE=preload("res://scripts/quests/quest_service.gd")
const SOURCE=preload("res://scripts/quests/source_quest523.gd")
const BAKE=preload("res://scripts/resources/current523_bake_cache.gd")
const COUNT=3621
const SELECTED_CATEGORY="main"
const SAMPLE_TIME=1794460000
const MAX_RSS_KB=524288
var failures: Array[String]=[]
var measurements: Array=[]
var directory: String=""
var records_path: String=""
var source: RefCounted

class CountingSource extends "res://scripts/quests/source_quest523.gd":
	var reads: int=0
	var gates: int=0
	var plans: int=0
	var sampled_static_peak: int=0
	var bulk_bytes: int=0
	func _read_record(id: String) -> Dictionary:
		reads+=1
		var result: Dictionary=super._read_record(id)
		if reads%128==0:sampled_static_peak=maxi(sampled_static_peak,OS.get_static_memory_usage())
		return result
	func begin_bulk() -> void:
		super.begin_bulk()
		bulk_bytes=_bulk.size()
		sampled_static_peak=maxi(sampled_static_peak,OS.get_static_memory_usage())
	func gate(row: Dictionary, context: Dictionary, claimed: Dictionary, now: int) -> String:
		gates+=1
		return super.gate(row,context,claimed,now)
	func reward_plan(row: Dictionary, context: Dictionary) -> Dictionary:
		plans+=1
		return super.reward_plan(row,context)
	func reset_counts() -> void:
		reads=0;gates=0;plans=0;bulk_bytes=0
		sampled_static_peak=OS.get_static_memory_usage()

func _initialize() -> void:_run.call_deferred()

func _row(index: int) -> Dictionary:
	var item: Dictionary={"ID":5000+index%765,"Name":"Synthetic item "+str(index%765)}
	for field: int in range(16):item["synthetic_field_%d"%field]="synthetic joined data "+str(field)
	return {"id":"m523:quest:"+str(index+1),"source_id":index+1,"title":"Synthetic quest "+str(index),"category":["main","common","achievement","other"][index%4],"definition":{"ID":index+1,"Name":"Synthetic quest","TypeID":0},"prerequisites":[{"type_name":"MinLevel","Value":1}],"goals":[{"type_name":"Level","CharacterClassID":0,"Amount":1,"relation":{"GoalPredicateTypeID":1},"description":"Synthetic level goal"}],"source_rewards":[{"ID":index+1,"CharacterClassID":0,"ClanOnly":false,"RewardEnhancementTypeID":1,"Amount":1,"RewardClassID":item.ID,"type_name":"Item","source_item":item,"ItemBlessCodeID":1,"UseImmediately":false}],"enhancements":[],"blockers":[],"excluded_reasons":[],"starts_at":0,"ends_at":4102444800,"description":"synthetic description ".repeat(8),"objective":{"kind":"source","count":1,"target":""},"rewards":{},"min_level":1}

func _fixture() -> RefCounted:
	var service=SERVICE.new()
	source=CountingSource.new()
	var writer:=FileAccess.open(records_path,FileAccess.WRITE)
	if writer==null:
		failures.append("Cannot create the isolated synthetic RecordFile.")
		return null
	var offsets: Dictionary={}
	for index: int in range(COUNT):
		var row: Dictionary=_row(index)
		offsets[row.id]=writer.get_position()
		if not writer.store_var(row):
			failures.append("Synthetic RecordFile write failed.")
			break
		var compact: Dictionary=SOURCE._compact(row)
		if compact.is_empty():
			failures.append("Synthetic row no longer matches the compact-row contract.")
			break
		source.quests.append(compact)
		service.quests.append(compact)
		service.index[compact.id]=compact
	writer.close()
	if not failures.is_empty():return null
	var records=BAKE.RecordFile.new()
	records.file=FileAccess.open(records_path,FileAccess.READ)
	if records.file==null:
		failures.append("Cannot read the isolated synthetic RecordFile.")
		return null
	records.offsets=offsets
	source._records=records
	service.source=source
	service.day_key=SERVICE.korean_daily_key(SAMPLE_TIME)
	service.source_context={"level":50,"class_id":1,"source_items":{},"currency_items":{}}
	return service

func _rss_kb() -> int:
	if not OS.has_feature("linux"):return -1
	var output: Array=[]
	if OS.execute("cat",["/proc/%d/status"%OS.get_process_id()],output)!=0 or output.is_empty():return -1
	for line: String in str(output[0]).split("\n"):
		if line.begins_with("VmRSS:"):
			for part: String in line.split(" ",false):
				if part.is_valid_int():return int(part)
	return -1

func _run() -> void:
	directory=ProjectSettings.globalize_path("user://benchmark_quest_category_entries").path_join(str(OS.get_process_id()))
	records_path=directory.path_join("synthetic_records.bin")
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:
		failures.append("Cannot create the isolated benchmark directory.")
		_finish()
		return
	var service: RefCounted=_fixture()
	if service!=null:
		# Full/category twice distinguishes the first cold allocation/read
		# from later warm calls, without enforcing any elapsed-time threshold.
		for iteration: int in range(4):
			if _rss_kb()>MAX_RSS_KB:
				failures.append("512MiB RSS guard reached; remaining calls skipped.")
				break
			_measure(service,iteration)
	_finish()

func _measure(service: RefCounted, iteration: int) -> void:
	var category: Variant=SELECTED_CATEGORY if iteration%2==1 else null
	source.reset_counts()
	var before: int=OS.get_static_memory_usage()
	var started: int=Time.get_ticks_usec()
	var rows: Array=service.entries(50,{},SAMPLE_TIME) if category==null else service.entries_for_category(50,{},category,SAMPLE_TIME)
	var elapsed: int=Time.get_ticks_usec()-started
	var held: int=OS.get_static_memory_usage()
	var expected: int=COUNT if category==null else ceili(float(COUNT)/4.0)
	if rows.size()!=expected or source.reads!=expected or source.gates!=expected or source.plans!=expected:failures.append("Materialization/gate/plan counts differ from the requested category.")
	if category!=null:
		for index: int in range(rows.size()):
			if rows[index].category!=SELECTED_CATEGORY or int(rows[index].source_id)!=index*4+1:
				failures.append("Category filtering changed source identity or order.")
				break
	if not source._bulk.is_empty():failures.append("Bulk buffer was retained after entries returned.")
	var sample: Dictionary={"operation":"entries" if category==null else "entries_for_category","iteration":iteration+1,"category":category,"rows":rows.size(),"record_reads":source.reads,"gate_calls":source.gates,"reward_plan_calls":source.plans,"usec":elapsed,"bulk_file_bytes":source.bulk_bytes,"bulk_released_after":source._bulk.is_empty(),"engine_static_before":before,"engine_static_with_rows":held,"engine_static_rows_delta":held-before,"sampled_engine_static_peak_including_bulk":source.sampled_static_peak,"rss_kb_with_rows":_rss_kb()}
	rows.clear()
	sample["engine_static_after_rows_release"]=OS.get_static_memory_usage()
	sample["rss_kb_after_rows_release"]=_rss_kb()
	measurements.append(sample)

func _finish() -> void:
	if source!=null and source._records!=null:
		source._records.file.close()
		source._records=null
	if not records_path.is_empty() and FileAccess.file_exists(records_path):
		if DirAccess.remove_absolute(records_path)!=OK:failures.append("Synthetic RecordFile cleanup failed.")
	if not directory.is_empty() and DirAccess.dir_exists_absolute(directory):
		if DirAccess.remove_absolute(directory)!=OK:failures.append("Synthetic benchmark directory cleanup failed.")
		DirAccess.remove_absolute(directory.get_base_dir())
	print("QUEST_CATEGORY_ENTRIES_BENCHMARK ",JSON.stringify({"engine":Engine.get_version_info().string,"scope":"synthetic CPU/Variant RecordFile materialization only; engine static bytes are not RSS/GPU bytes; RSS may stay high after allocator reuse; no private-pack or Android OOM/latency claim","synthetic_quests":COUNT,"category_quests":ceili(float(COUNT)/4.0),"private_pack_used":false,"rss_guard_kb":MAX_RSS_KB,"measurements":measurements,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
