extends SceneTree
## Source-sized synthetic record bake. No private JSON/art or player saves.
const SERVICE=preload("res://scripts/quests/quest_service.gd")
const SOURCE=preload("res://scripts/quests/source_quest523.gd")
const BAKE=preload("res://scripts/resources/current523_bake_cache.gd")
const WINDOW=preload("res://scripts/ui/original_ui/source_main_quest_window.gd")
const BROWSER=preload("res://scripts/ui/renewal_quests.gd")
const PREPARATION=preload("res://tests/original_ui_quest_preparation_test.gd")
var checks: int=0
var failures: Array[String]=[]
var evidence: Dictionary={"synthetic":true,"android_verified":false}
var bake_name: String
var sentinel_path: String
var source: RefCounted

class MeasuredSource extends "res://scripts/quests/source_quest523.gd":
	var reads: int=0
	var peak: int=0
	func _read_record(id: String) -> Dictionary:
		reads+=1
		var row: Dictionary=super._read_record(id)
		peak=maxi(peak,OS.get_static_memory_usage())
		return row
	func reset() -> void:reads=0;peak=OS.get_static_memory_usage()

class QuestWorld extends Node:
	var level: int=80
	var inventory: Dictionary={}
	var quest_auto: RefCounted
	var quest_service: RefCounted

class OldAPI extends RefCounted:
	var service: RefCounted
	func entries(_level: int,_inventory: Dictionary) -> Array[Dictionary]:return []
	func entries_for_category(level: int,inventory: Dictionary,category: String) -> Array[Dictionary]:
		return service.entries_for_category(level,inventory,category)

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:_run.call_deferred()

func _row(index: int) -> Dictionary:
	return {"id":"m523:quest:"+str(index+1),"source_id":index+1,"title":"Synthetic "+str(index),"category":["main","common","achievement","other"][index%4],"definition":{"ID":index+1,"Name":"Synthetic","TypeID":0},"prerequisites":[{"type_name":"MinLevel","Value":99 if index==1 else 1}],"goals":[{"type_name":"Level","CharacterClassID":0,"Amount":1,"relation":{"GoalPredicateTypeID":1}}],"source_rewards":[{"ID":index+1,"CharacterClassID":0,"ClanOnly":false,"RewardEnhancementTypeID":1,"Amount":1,"RewardClassID":5000+index,"type_name":"Item","source_item":{"ID":5000+index,"Name":"Synthetic item","nested":{"id":index}},"ItemBlessCodeID":1,"UseImmediately":false}],"enhancements":[],"blockers":[],"excluded_reasons":[],"starts_at":0,"ends_at":4102444800,"description":"Synthetic description","objective":{"kind":"source","count":1,"target":""},"rewards":{},"min_level":1}

func _run() -> void:
	bake_name="quest-window-bounded-synthetic-"+str(OS.get_process_id())
	sentinel_path="user://quest-window-preserve-"+str(OS.get_process_id())+".sav"
	var sentinel:=FileAccess.open(sentinel_path,FileAccess.WRITE)
	sentinel.store_buffer("existing save bytes\nunchanged".to_utf8_buffer());sentinel.close()
	var save_sha: String=FileAccess.get_sha256(sentinel_path)
	var service=SERVICE.new()
	source=MeasuredSource.new()
	service.source=source
	service.source_context={"level":80,"class_id":1,"source_items":{},"currency_items":{}}
	service.day_key=SERVICE.korean_daily_key(int(Time.get_unix_time_from_system()))
	var writer=BAKE.record_writer(bake_name,"synthetic-window-v1")
	if writer==null:check(false,"record writer opens");_finish();return
	# Same 3,621 row count as the pinned original payload. A joined item has
	# 48 synthetic fields, giving >20 MB of verified record bytes.
	for index: int in 3621:
		var row: Dictionary=_row(index)
		row.category="main"
		var item: Dictionary=row.source_rewards[0].source_item
		for field: int in 48:item["synthetic_field_"+str(field)]={"value":index+field,"text":"fixture metadata ".repeat(4)}
		if index%7==0:row.blockers=["synthetic blocked"]
		if index%13==0:row.source_rewards[0].type_name="UnsupportedSynthetic"
		if index%11==0:service.claimed[row.id]=true
		if index%17==0:service.progress[row.id]=1
		writer.add(row.id,row)
		var compact: Dictionary=SOURCE._compact(row)
		service.quests.append(compact);service.index[compact.id]=compact;source.quests.append(compact)
	check(BAKE.finish_records(writer),"synthetic record bake validates")
	source._records=BAKE.open_records(bake_name,"synthetic-window-v1")
	if source._records==null:check(false,"verified records reopen");_finish();return
	var record_sha: String=FileAccess.get_sha256(BAKE.data_path(bake_name))
	evidence.record_bytes=source._records.file.get_length()
	check(evidence.record_bytes>20*1024*1024,"source-scale fixture exceeds 20 MiB")
	var before: Dictionary=service.export_state()
	var world:=QuestWorld.new();world.quest_service=service;root.add_child(world)
	var window=WINDOW.new();window._world=weakref(world)
	var old:=OldAPI.new();old.service=service
	world.quest_service=old
	source.reset()
	var baseline: int=OS.get_static_memory_usage()
	var started: int=Time.get_ticks_usec()
	var expected: Array[Dictionary]=window._rows()
	evidence.before={"usec":Time.get_ticks_usec()-started,"sampled_static_growth":source.peak-baseline,"record_reads":source.reads}
	check(expected.size()==60 and source.reads==3621,"baseline decodes all 3621 records before capping 60 rows")
	world.quest_service=service
	source.reset();baseline=OS.get_static_memory_usage();started=Time.get_ticks_usec()
	var actual: Array[Dictionary]=window._rows()
	evidence.after={"usec":Time.get_ticks_usec()-started,"sampled_static_growth":source.peak-baseline,"record_reads":source.reads}
	check(actual==expected,"bounded result matches every nested field, reward plan and ready ordering")
	check(source.reads<100 and source._bulk.is_empty() and source._cache.is_empty(),"native first page reads only eligible candidates and selected rows without bulk or LRU growth")
	check(evidence.after.sampled_static_growth*5<evidence.before.sampled_static_growth,"sampled retained record growth falls by more than fivefold")
	actual[0].source_rewards[0].source_item.Name="caller only"
	check(window._rows()==expected,"detached display rows cannot mutate original records")
	actual.clear();expected.clear()
	# Exercise the waiting and completed portions as well as ready overflow.
	service.progress.clear()
	await _compare_rows(window,world,service,old,"waiting plus done")
	for row: Dictionary in service.quests:service.claimed[row.id]=true
	await _compare_rows(window,world,service,old,"all completed")
	service.import_state(before)
	source.reset()
	check(service.entries_for_window(80,{},"missing",60).is_empty() and source.reads==0,"missing category does not touch the record file")
	check(service.entries_for_window(80,{},"main",0).is_empty() and source.reads==0,"zero capacity performs no reads")
	await _browser(world,service)
	await _lifecycle(world)
	check(service.export_state()==before,"browsing preserves quest progression, claims and receipts")
	check(FileAccess.get_sha256(sentinel_path)==save_sha and FileAccess.get_sha256(BAKE.data_path(bake_name))==record_sha,"existing save and input record bytes remain unchanged")
	world.free()
	_finish()

func _compare_rows(window: RefCounted,world: Node,service: RefCounted,old: RefCounted,label: String) -> void:
	world.quest_service=old
	var expected: Array[Dictionary]=window._rows()
	world.quest_service=service
	source.reset()
	check(window._rows()==expected and source.reads==60,label+" preserves complete row order with exactly 60 reads")

func _browser(world: Node,service: RefCounted) -> void:
	var browser=BROWSER.new();root.add_child(browser)
	source.reset()
	var baseline: int=OS.get_static_memory_usage()
	var started: int=Time.get_ticks_usec()
	browser.configure(world)
	evidence.browser={"usec":Time.get_ticks_usec()-started,"sampled_static_growth":source.peak-baseline,"record_reads":source.reads}
	check(browser.listing.get_child_count()==30 and browser.page_label.text.contains("3621"),"fallback first page creates 30 real cards and preserves total count")
	check(source._bulk.is_empty() and evidence.browser.sampled_static_growth<evidence.before.sampled_static_growth/5,"fallback scan retains a page without a whole-file buffer")
	browser.page=100000
	browser.refresh()
	check(browser.page==120 and browser.listing.get_child_count()==21,"out-of-range page clamps to final 21 records")
	browser.search.text="3621"
	browser.refresh()
	check(browser.page==0 and browser.listing.get_child_count()==1 and browser.page_label.text.contains("1개"),"exact source ID search remains reachable")
	browser.search.text=""
	browser.state_filter.select(2);browser.refresh()
	check(browser.listing.get_child_count()<=30 and browser.summary.text.contains("보상 받기 대기"),"availability filter and summary survive pagination")
	# Retired daily rows still appear in the common history bucket.
	var legacy: Dictionary={"id":"historic","title":"Preserved history","category":"daily","min_level":1,"objective":{"kind":"level","count":1},"rewards":{}}
	service.quests.append(legacy);service.claimed.historic=true
	browser.selected="common";browser.state_filter.select(4);browser.refresh()
	check(browser.listing.get_child_count()==1 and browser.summary.text.contains("기존 완료 이력"),"legacy daily history stays in common tab")
	service.quests.pop_back();service.claimed.erase("historic")
	browser.free()
	await process_frame

func _lifecycle(world: Node) -> void:
	var host:=Node2D.new();root.add_child(host)
	var window=PREPARATION.WindowProbe.new()
	window.open(host,world,Callable())
	for index: int in 50:window.open(host,world,Callable())
	check(window.stages.size()==1,"50 repeated open clicks reuse the open window")
	for index: int in 50:window._select_category("main" if index%2 else "common")
	check(window.stages.size()==1 and window._refresh_pending,"50 rapid tab clicks create no synchronous replacement scenes")
	await process_frame
	await process_frame
	check(window.stages.size()==2 and window.stages[-1][0]=="main","one next-frame rebuild uses the last selected tab")
	window._select_category("achievement")
	window.close()
	var count: int=window.stages.size()
	await process_frame
	check(window.stages.size()==count and not window.is_open(),"close cancels pending tab refresh")
	window.open(host,world,Callable())
	check(window.stages.size()==count+1 and window.is_open(),"reopening after close stages once")
	window.close();host.queue_free()
	await process_frame

func _finish() -> void:
	if source!=null:source._records=null
	if not bake_name.is_empty():BAKE.clear(bake_name)
	if not sentinel_path.is_empty():DirAccess.remove_absolute(sentinel_path)
	print("QUEST_WINDOW_BOUNDED_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
