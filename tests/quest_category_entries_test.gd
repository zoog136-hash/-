extends SceneTree
## Synthetic complete/compact source rows through the actual record reader,
## gate and reward planner. No private pack or gameplay/save action is run.
const SERVICE=preload("res://scripts/quests/quest_service.gd")
const SOURCE=preload("res://scripts/quests/source_quest523.gd")
const BAKE=preload("res://scripts/resources/current523_bake_cache.gd")
var checks: int=0
var failures: Array[String]=[]
var directory: String=""
var records_path: String=""
var save_path: String=""
var now_value: int=0

class CountingSource extends "res://scripts/quests/source_quest523.gd":
	var detached_count: int=0
	var read_count: int=0
	var gate_count: int=0
	var plan_count: int=0
	var bulk_begin: int=0
	var bulk_end: int=0
	func detached(row: Dictionary) -> Dictionary:
		detached_count+=1
		return super.detached(row)
	func _read_record(id: String) -> Dictionary:
		read_count+=1
		return super._read_record(id)
	func gate(row: Dictionary, context: Dictionary, claimed: Dictionary, now: int) -> String:
		gate_count+=1
		return super.gate(row,context,claimed,now)
	func reward_plan(row: Dictionary, context: Dictionary) -> Dictionary:
		plan_count+=1
		return super.reward_plan(row,context)
	func begin_bulk() -> void:
		bulk_begin+=1
		super.begin_bulk()
	func end_bulk() -> void:
		bulk_end+=1
		super.end_bulk()
	func reset_counts() -> void:
		detached_count=0;read_count=0;gate_count=0;plan_count=0;bulk_begin=0;bulk_end=0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:_run.call_deferred()

func _native(index: int) -> Dictionary:
	var category: String=["main","common","achievement","other"][index%4]
	return {"id":"m523:quest:"+str(index+1),"source_id":index+1,"title":"Synthetic "+str(index),"category":category,"definition":{"ID":index+1,"Name":"Synthetic quest","TypeID":3 if category=="common" else 0},"prerequisites":[{"type_name":"MinLevel","Value":99 if index==1 else 1}],"goals":[{"type_name":"Level","CharacterClassID":0,"Amount":1,"relation":{"GoalPredicateTypeID":1}}],"source_rewards":[{"ID":index+1,"CharacterClassID":0,"ClanOnly":false,"RewardEnhancementTypeID":1,"Amount":1,"RewardClassID":5000+index,"type_name":"Item","source_item":{"ID":5000+index,"Name":"Synthetic item "+str(index),"preserved":{"value":index}},"ItemBlessCodeID":1,"UseImmediately":false}],"enhancements":[],"blockers":[],"excluded_reasons":[],"starts_at":0,"ends_at":0 if index==3 else 4102444800,"description":"Source description","objective":{"kind":"source","count":1,"target":""},"rewards":{},"min_level":1}

func _legacy(index: int) -> Dictionary:
	return {"id":"legacy:"+str(index),"title":"Legacy "+str(index),"category":["main","daily","common","other"][index],"objective":{"kind":"collect","count":5,"target":"Synthetic item"},"rewards":{"adena":5,"items":[{"name":"Synthetic item","quantity":1}]},"min_level":1,"legacy_retired":true}

func _fixture() -> Dictionary:
	var service=SERVICE.new()
	var source:=CountingSource.new()
	var file:=FileAccess.open(records_path,FileAccess.WRITE)
	var offsets: Dictionary={}
	for index: int in range(32):
		var full: Dictionary=_native(index)
		offsets[full.id]=file.get_position()
		file.store_var(full)
		# Both forms are supported: compact rows rehydrate from records while
		# injected complete rows retain their independent deep-copy behavior.
		var resident: Dictionary=SOURCE._compact(full) if index<16 else full
		check(resident.category==full.category,"source compaction retains authoritative category")
		service.quests.append(resident)
		source.quests.append(resident)
		service.index[resident.id]=resident
	for index: int in range(4):
		var row: Dictionary=_legacy(index)
		service.quests.append(row)
		service.index[row.id]=row
	file.close()
	var records=BAKE.RecordFile.new()
	records.file=FileAccess.open(records_path,FileAccess.READ)
	records.offsets=offsets
	source._records=records
	service.source=source
	service.day_key=SERVICE.korean_daily_key(now_value)
	service.claimed={"m523:quest:3":true,"legacy:1":true,"unavailable:historic":true}
	service.progress={"legacy:0":3,"legacy:1":2}
	service.item_grants={"m523:quest:3":[{"reward_id":3,"immutable_receipt":"preserved"}]}
	service.ui_requests={"old":[{"id":7}]}
	service.source_dummy_rewards={"old":[{"source":"preserved"}]}
	service.source_context={"level":50,"class_id":1,"source_items":{},"currency_items":{},"held_native_rewards":{"m523:quest:3":{"3":true}}}
	return {"service":service,"source":source}

func _run() -> void:
	now_value=int(Time.get_unix_time_from_system())
	directory=ProjectSettings.globalize_path("user://quest_category_entries_synthetic")
	DirAccess.make_dir_recursive_absolute(directory)
	records_path=directory.path_join("records.bin")
	save_path=directory.path_join("save-preservation.sav")
	var sentinel:=FileAccess.open(save_path,FileAccess.WRITE)
	sentinel.store_buffer("preserve unknown fields and save bytes\n".to_utf8_buffer())
	sentinel.close()
	var saved_sha: String=FileAccess.get_sha256(save_path)
	var fixture: Dictionary=_fixture()
	var service: RefCounted=fixture.service
	var source: CountingSource=fixture.source
	var saved_state: Dictionary=service.export_state()
	var context_before: Dictionary=service.source_context.duplicate(true)
	var inventory: Dictionary={"Synthetic item":4}
	var all_rows: Array=service.entries(50,inventory,now_value)
	check(all_rows.size()==36 and source.detached_count==36 and source.read_count==16 and source.gate_count==32 and source.plan_count==32,"existing entries still materializes all legacy/current rows exactly once")
	check(source.bulk_begin==1 and source.bulk_end==1 and source._bulk.is_empty(),"existing entries retains complete bulk lifecycle")
	for category: String in ["main","common","achievement","other","daily","","unknown"]:
		var expected: Array=[]
		var native_count: int=0
		var compact_count: int=0
		for row: Dictionary in all_rows:
			if str(row.get("category",""))!=category:continue
			expected.append(row)
			if row.has("source_id"):
				native_count+=1
				if int(row.source_id)<=16:compact_count+=1
		source.reset_counts()
		var offered: Array=service.entries_for_category(50,inventory,category,now_value)
		check(offered==expected,"category rows/order/content equal filtering unchanged entries: "+category)
		check(source.detached_count==expected.size() and source.read_count==compact_count and source.gate_count==native_count and source.plan_count==native_count,"only selected category is detached/gated/planned: "+category)
		check(source.bulk_begin==1 and source.bulk_end==1 and source._bulk.is_empty(),"category call preserves bulk lifecycle: "+category)
	check(service.entries_for_category(50,inventory,"main")==service.entries_for_category(50,inventory,"main",now_value),"new API retains optional time argument")
	check(service.entries(50,inventory)==all_rows,"old two-argument entries remains compatible")
	var selected: Array=service.entries_for_category(50,inventory,"main",now_value)
	var expected_selected: Array=selected.duplicate(true)
	selected[0].definition.Name="changed only in returned row"
	selected[0].source_rewards[0].source_item.preserved.value=-1
	selected[0].goals[0].relation.GoalPredicateTypeID=99
	selected[0].rewards.items[0].record.source_original_item.Name="changed only in planned reward"
	check(service.entries_for_category(50,inventory,"main",now_value)==expected_selected,"returned full source rows/reward plans are independent copies")
	var daily: Array=service.entries_for_category(50,inventory,"daily",now_value)
	daily[0].rewards.items[0].name="changed only in legacy copy"
	check(service.entries_for_category(50,inventory,"daily",now_value)[0].rewards.items[0].name=="Synthetic item","legacy rows preserve deep-copy isolation and exact daily category")
	check(service.export_state()==saved_state and service.source_context==context_before and inventory=={"Synthetic item":4},"browsing does not change claims/receipts/progress/context/inventory")
	check(FileAccess.get_sha256(save_path)==saved_sha,"browsing leaves save bytes unchanged")
	# Advance-day behavior runs even for an empty category, as the old full
	# entries call did. Retired legacy and unknown claims remain preserved.
	var active_daily: Dictionary=_legacy(1)
	active_daily.id="daily:active"
	active_daily.legacy_retired=false
	service.quests.append(active_daily)
	service.index[active_daily.id]=active_daily
	service.claimed[active_daily.id]=true
	service.progress[active_daily.id]=2
	service.entries_for_category(50,inventory,"unknown",now_value+86400)
	check(service.day_key==SERVICE.korean_daily_key(now_value+86400) and service.claimed.has("legacy:1") and service.claimed.has("unavailable:historic"),"category filter retains day high-water and historical claims")
	check(not service.claimed.has(active_daily.id) and not service.progress.has(active_daily.id),"empty category still applies existing active-daily reset outside the filter")
	check(service.entries_for_category(50,inventory,"unknown",now_value).is_empty() and service.day_key==SERVICE.korean_daily_key(now_value+86400),"clock reversal cannot reset day high-water")
	source._records.file.close()
	source._records=null
	DirAccess.remove_absolute(records_path)
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(directory)
	print("QUEST_CATEGORY_ENTRIES_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_rows":32,"legacy_rows":4,"full_detached":36,"main_detached":9,"private_pack_used":false}))
	quit(0 if failures.is_empty() else 1)
