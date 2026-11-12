extends SceneTree
## Uses the actual verified synthetic BAKE record format and SourceQuest523
## decoder. No original/private quest data or game save action is run.
const SERVICE=preload("res://scripts/quests/quest_service.gd")
const SOURCE=preload("res://scripts/quests/source_quest523.gd")
const BAKE=preload("res://scripts/resources/current523_bake_cache.gd")
var checks: int=0
var failures: Array[String]=[]
var bake_name: String=""
var sentinel_path: String=""
var source: RefCounted

class TracedRecords extends RefCounted:
	var inner: RefCounted
	var file: FileAccess
	var offsets: Dictionary
	var calls: int=0
	func has(id: String) -> bool:return inner.has(id)
	func read(id: String) -> Variant:
		calls+=1
		return inner.read(id)

class TracedSource extends "res://scripts/quests/source_quest523.gd":
	var begins: int=0
	var ends: int=0
	var bulk_bytes: int=0
	var materializations: int=0
	func begin_bulk() -> void:
		begins+=1
		super.begin_bulk()
		bulk_bytes=_bulk.size()
	func end_bulk() -> void:ends+=1;super.end_bulk()
	func _read_record(id: String) -> Dictionary:
		materializations+=1
		return super._read_record(id)
	func reset_counts() -> void:
		begins=0;ends=0;bulk_bytes=0;materializations=0;_records.calls=0

class NoBulkSource extends RefCounted:
	var detached_count: int=0
	func detached(row: Dictionary) -> Dictionary:detached_count+=1;return row.duplicate(true)
	func gate(_row: Dictionary, _context: Dictionary, _claimed: Dictionary, _now: int) -> String:return ""
	func reward_plan(_row: Dictionary, _context: Dictionary) -> Dictionary:return {"ok":true,"items":[],"adena":0,"exp":7}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:_run.call_deferred()

func _row(index: int) -> Dictionary:
	return {"id":"m523:quest:"+str(index+1),"source_id":index+1,"title":"Synthetic "+str(index),"category":["main","common","achievement","other"][index%4],"definition":{"ID":index+1,"Name":"Synthetic","TypeID":0},"prerequisites":[{"type_name":"MinLevel","Value":99 if index==1 else 1}],"goals":[{"type_name":"Level","CharacterClassID":0,"Amount":1,"relation":{"GoalPredicateTypeID":1}}],"source_rewards":[{"ID":index+1,"CharacterClassID":0,"ClanOnly":false,"RewardEnhancementTypeID":1,"Amount":1,"RewardClassID":5000+index,"type_name":"Item","source_item":{"ID":5000+index,"Name":"Synthetic item","nested":{"id":index}},"ItemBlessCodeID":1,"UseImmediately":false}],"enhancements":[],"blockers":[],"excluded_reasons":[],"starts_at":0,"ends_at":4102444800,"description":"Synthetic description","objective":{"kind":"source","count":1,"target":""},"rewards":{},"min_level":1}

func _run() -> void:
	var now: int=int(Time.get_unix_time_from_system())
	bake_name="quest-category-records-synthetic-"+str(OS.get_process_id())
	var key: String="synthetic-valid-records-v1"
	var writer=BAKE.record_writer(bake_name,key)
	if writer==null:check(false,"synthetic writer opens");_finish();return
	var service=SERVICE.new()
	source=TracedSource.new()
	for index: int in range(16):
		var full: Dictionary=_row(index)
		writer.add(full.id,full)
		var compact: Dictionary=SOURCE._compact(full)
		check(not compact.is_empty(),"synthetic row supports compact source gate")
		service.quests.append(compact)
		service.index[compact.id]=compact
		source.quests.append(compact)
	if not BAKE.finish_records(writer):check(false,"synthetic record commit");_finish();return
	var records: RefCounted=BAKE.open_records(bake_name,key)
	check(records!=null,"synthetic file passes existing SHA/bytes/index verification")
	if records==null:_finish();return
	var traced:=TracedRecords.new()
	traced.inner=records;traced.file=records.file;traced.offsets=records.offsets
	source._records=traced
	service.source=source
	service.day_key=SERVICE.korean_daily_key(now)
	service.claimed={"historic:unknown":true,"m523:quest:3":true}
	service.item_grants={"m523:quest:3":[{"reward_id":3,"receipt":"preserved"}]}
	service.progress={"m523:quest:2":1}
	service.source_context={"level":50,"class_id":1,"source_items":{},"currency_items":{}}
	var state: Dictionary=service.export_state()
	var file_sha: String=FileAccess.get_sha256(BAKE.data_path(bake_name))
	sentinel_path="user://quest-category-save-preservation-"+str(OS.get_process_id())+".sav"
	var sentinel:=FileAccess.open(sentinel_path,FileAccess.WRITE)
	sentinel.store_buffer("retain previous save bytes\n".to_utf8_buffer());sentinel.close()
	var sentinel_sha: String=FileAccess.get_sha256(sentinel_path)
	var all_rows: Array=service.entries(50,{},now)
	check(all_rows.size()==16 and source.materializations==16,"existing full entries materializes every row")
	check(source.begins==1 and source.ends==1 and source.bulk_bytes==records.file.get_length() and traced.calls==0 and source._bulk.is_empty(),"full entries retains one whole-file bulk and decode-in-place path")
	var expected: Array=[]
	for row: Dictionary in all_rows:
		if row.category=="main":expected.append(row)
	source.reset_counts()
	var category: Array=service.entries_for_category(50,{},"main",now)
	check(category==expected,"bounded category rows/order/availability/rewards equal full entries filtered")
	check(source.materializations==4 and traced.calls==4,"category uses the existing RecordFile reader only for four requested rows")
	check(source.begins==0 and source.ends==0 and source.bulk_bytes==0 and source._bulk.is_empty(),"category allocates no whole-file bulk buffer")
	category[0].definition.Name="returned copy only"
	category[0].source_rewards[0].source_item.nested.id=-1
	category[0].rewards.items[0].record.source_original_item.Name="returned reward only"
	check(service.entries_for_category(50,{},"main",now)==expected,"per-record category results retain independent nested row and reward copies")
	source.reset_counts()
	check(service.entries_for_category(50,{},"unknown",now).is_empty() and source.materializations==0 and source.begins==0 and source.ends==0,"empty category reads no records and creates no bulk")
	# Existing callers may own a bulk snapshot around other synchronous work.
	source.begin_bulk()
	var outer: PackedByteArray=source._bulk
	source.reset_counts()
	check(service.entries_for_category(50,{},"main",now)==expected,"category result remains identical inside a caller-owned bulk")
	check(source._bulk==outer and source.begins==0 and source.ends==0 and traced.calls==0,"category neither replaces nor ends an existing caller's bulk snapshot")
	source.end_bulk()
	outer=PackedByteArray()
	# Keep the source's existing incomplete-buffer fallback behavior intact.
	source._bulk=PackedByteArray([0,0,0])
	source.reset_counts()
	check(service.entries_for_category(50,{},"main",now)==expected and traced.calls==4,"incomplete caller bulk still uses the original bounded fallback")
	check(source._bulk==PackedByteArray([0,0,0]) and source.begins==0 and source.ends==0,"category does not clear a caller-owned incomplete buffer")
	source.end_bulk()
	check(service.export_state()==state and FileAccess.get_sha256(sentinel_path)==sentinel_sha,"record browsing leaves claims/progression/receipts and existing save bytes unchanged")
	check(FileAccess.get_sha256(BAKE.data_path(bake_name))==file_sha,"consumer never changes verified record bytes or index")
	_custom_provider(now)
	_finish()

func _custom_provider(now: int) -> void:
	var service=SERVICE.new()
	var custom:=NoBulkSource.new()
	service.source=custom
	service.day_key=SERVICE.korean_daily_key(now)
	for index: int in range(4):service.quests.append(_row(index))
	var all_rows: Array=service.entries(50,{},now)
	check(all_rows.size()==4 and custom.detached_count==4,"injected source without begin_bulk retains full entries compatibility")
	custom.detached_count=0
	var category: Array=service.entries_for_category(50,{},"main",now)
	check(category.size()==1 and category[0]==all_rows[0] and custom.detached_count==1,"injected no-bulk source supports unchanged category model and copying")

func _finish() -> void:
	if source!=null and source._records!=null:
		source._records.file.close();source._records=null
	if not bake_name.is_empty():BAKE.clear(bake_name)
	if not sentinel_path.is_empty():DirAccess.remove_absolute(sentinel_path)
	print("QUEST_CATEGORY_RECORD_READS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"private_pack_used":false,"full_rows":16,"category_rows":4}))
	quit(0 if failures.is_empty() else 1)
