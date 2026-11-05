extends SceneTree
const S=preload("res://scripts/cards/native_awakening_supply.gd")
const Runtime=preload("res://scripts/cards/option_awakening_runtime.gd")
const GRANTS=preload("res://scripts/loot/patch523_item_inventory.gd")
class Host extends Node:
	var inventory: Dictionary={"마법인형 제작 코인":77}
	var item_instances: Dictionary={}
	var gold: int=5
	var locks: Dictionary={}
	var quest_service: Variant=null
	func _item_locked(item: String,id: String="") -> bool:return bool(locks.get(item,false)) or bool(locks.get(id,false))
	func _catalog_item_from_source_id(identity: String) -> Dictionary:
		for id: int in S.IDS:
			var value: Dictionary=S.record(id)
			if value.get("sourceId","")==identity:return value
		return {}
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:errors.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var host=Host.new();root.add_child(host)
	check(not S.record(3252).is_empty(),"full exact source item definition installed")
	check(S.available(host,3252)==0 and not S.prepare_debit(host,3252,1).ok,"legacy name-only coin balance cannot be promoted")
	var grant: Dictionary=GRANTS.stage(host,[{"item_class_id":3252,"amount":3000000,"bless_raw":1,"enchant":0}],{"kind":"source_grant_test","source_id":123})
	if not grant.ok:print("SOURCE_STAGE_DENIED ",JSON.stringify(grant));host.queue_free();quit(1);return
	check(grant.ok and host.inventory["마법인형 제작 코인"]==77 and host.item_instances.is_empty(),"source supplier stages without publishing")
	host.inventory=grant.overrides.inventory;host.item_instances=grant.overrides.item_instances
	check(host.inventory["마법인형 제작 코인"]==3000077 and host.item_instances.size()==1 and S.available(host,3252)==3000000,"exact3252 shares wallet while retaining distinct provenance quantity")
	var uid: String=host.item_instances.keys()[0]
	host.locks[uid]=true
	check(S.available(host,3252)==0 and not S.prepare_debit(host,3252,1,uid).ok,"selected source stack lock blocks debit")
	host.locks.clear()
	var before: int=hash([host.inventory,host.item_instances])
	var paid: Dictionary=S.prepare_debit(host,3252,3000000)
	check(paid.ok and paid.overrides.inventory["마법인형 제작 코인"]==77 and paid.overrides.item_instances.is_empty(),"exact source debit preserves all preexisting generic coins")
	check(hash([host.inventory,host.item_instances])==before and paid.consumed.size()==1 and paid.consumed[0].quantity==3000000,"debit is pure and reports exact physical consumption")
	var remaining: Dictionary=S.prepare_debit(host,3252,3)
	check(remaining.ok and remaining.overrides.item_instances[uid].source_awakening_quantity==2999997 and remaining.overrides.inventory["마법인형 제작 코인"]==3000074,"partial debit keeps original physicalID and source metadata")
	var saved: Dictionary=host.item_instances[uid].duplicate(true)
	host.item_instances[uid].record.source_snapshot="base508"
	check(S.available(host,3252)==0 and not S.prepare_debit(host,3252,1).ok,"wrong snapshot cannot authorize a source debit")
	host.item_instances[uid]=saved.duplicate(true);host.item_instances[uid].source_awakening_supply.pack_sha256="wrong"
	check(S.available(host,3252)==0,"wrong provider pack cannot authorize a source debit")
	host.item_instances[uid]=saved
	for id: int in [75184,75194,95624,118992,243043,346921,365748,365758,370562]:
		var staged: Dictionary=GRANTS.stage(host,[{"item_class_id":id,"amount":2,"bless_raw":1,"enchant":0}],{"kind":"source_supplier_test","item":id})
		check(staged.ok,"source supplier supports exact awakening identity "+str(id))
		host.inventory=staged.overrides.inventory;host.item_instances=staged.overrides.item_instances
		check(S.available(host,id)==2 and S.prepare_debit(host,id,1).ok,"consumer accepts same typed identity without renaming "+str(id))
	check(not S.exact(GRANTS.D.variant_item(S.definition(75184).native_record,2),75184),"blessed source book never aliases the reviewed normal awakening input")
	var runtime=Runtime.new();runtime.world=host
	var scroll_name: String=S.record(365758).name
	runtime.progress={"native_relic_subslot_identity":"source:m508:98:20548",Runtime.RELIC_SUMMON_TIME:{"expires_utc":int(Time.get_unix_time_from_system())+20}}
	check(runtime.source_scroll_supported(scroll_name) and not runtime.source_scroll_auto_ready(scroll_name),"proven source scroll registers but waits outside original5000ms overlap")
	runtime.progress[Runtime.RELIC_SUMMON_TIME].expires_utc=int(Time.get_unix_time_from_system())+4
	check(runtime.source_scroll_auto_ready(scroll_name),"proven scroll becomes auto eligible inside original5000ms overlap")
	runtime.progress.erase(Runtime.RELIC_SUMMON_TIME)
	check(not runtime.source_scroll_auto_ready(scroll_name),"legacy untimed selections are never silently converted by automatic use")
	host.locks[scroll_name]=true
	check(not runtime.source_scroll_supported(scroll_name),"global scroll lock disables source support")
	host.locks.clear();host.inventory.erase(scroll_name)
	check(not runtime.source_scroll_supported(scroll_name) and not runtime._use_source_relic_scroll("").ok,"orphaned physical proof without owned inventory cannot activate a scroll")
	host.queue_free();await process_frame
	print("NATIVE_AWAKENING_SUPPLY ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
