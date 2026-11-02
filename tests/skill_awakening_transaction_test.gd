extends SceneTree
const Runtime=preload("res://scripts/cards/skill_awakening_runtime.gd")
class Draw extends RefCounted:
	var owned: Dictionary={}
class Host extends Node:
	var card_draw_fusion=Draw.new()
	var gold: int=10000000
	var inventory: Dictionary={}
	var item_instances: Dictionary={}
	var equipment_records_dirty: bool=false
	var card_collections=null
	var save_error: Error=OK
	var saved: Dictionary={}
	func _save_game(_quiet: bool,override: Dictionary) -> Error:
		if save_error!=OK:return save_error
		saved=override.duplicate(true);return OK
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message)
func _initialize() -> void:
	var host:=Host.new();var runtime=Runtime.new();runtime.configure(host)
	var tested: Dictionary={}
	for identity: String in runtime.core.cards:
		if not runtime.core.eligibility(identity).ok:continue
		var card: Dictionary=runtime.core.cards[identity]
		var key: String=card.category+":"+str(int(card.source_card.GradeID))
		if tested.has(key):continue
		tested[key]=true
		host.card_draw_fusion.owned={card.category:{identity:true}}
		var req: Dictionary=runtime.core.book_requirement(identity)
		var record: Dictionary={"name":"fixture book","source":"lineagem_base508","source_snapshot":"base508","source_item_class_id":req.item_class_id,"sourceId":"m508:item:"+str(req.item_class_id)}
		host.inventory={"fixture book":2};host.item_instances={"first":{"name":"fixture book","record":record},"second":{"name":"fixture book","record":record}}
		host.gold=10000000
		var before: int=hash([runtime.progress,host.inventory,host.item_instances,host.gold,runtime.selection_rng.state])
		host.save_error=ERR_CANT_CREATE
		check(runtime.request_operation(identity,{"operation_id":key}).code=="save_failed","save failure "+key)
		check(hash([runtime.progress,host.inventory,host.item_instances,host.gold,runtime.selection_rng.state])==before,"atomic rollback "+key)
		host.save_error=OK
		var original_gold: int=host.gold
		host.gold=0
		check(runtime.request_operation(identity).code=="insufficient_gold" and host.gold==0,"insufficient gold "+key)
		host.gold=original_gold
		host.card_draw_fusion.owned={}
		check(runtime.request_operation(identity).code=="not_owned" and hash([runtime.progress,host.inventory,host.item_instances,host.gold,runtime.selection_rng.state])==before,"unowned no debit "+key)
		host.card_draw_fusion.owned={card.category:{identity:true}}
		check(runtime.request_operation(identity,{"expected_revision":-1}).code=="stale_revision","stale transaction "+key)
		host.item_instances.first.record=record.duplicate(true);host.item_instances.second.record=record.duplicate(true)
		host.item_instances.first.record.source_item_class_id=-1;host.item_instances.second.record.source_item_class_id=-1
		check(runtime.request_operation(identity).code=="insufficient_book","wrong grade/source book "+key)
		host.item_instances.first.record=record;host.item_instances.second.record=record
		var result: Dictionary=runtime.request_operation(identity,{"operation_id":key})
		check(result.ok and host.gold==10000000-int(req.fee) and host.inventory["fixture book"]==1 and host.item_instances.size()==1,"exact debit "+key)
		check(host.saved.gold==host.gold and host.saved.item_instances==host.item_instances and host.saved.card_skill_awakening==runtime.progress,"single save snapshot "+key)
		var after: int=hash([runtime.progress,host.inventory,host.item_instances,host.gold,runtime.selection_rng.state])
		check(not runtime.request_operation(identity,{"operation_id":key}).ok and hash([runtime.progress,host.inventory,host.item_instances,host.gold,runtime.selection_rng.state])==after,"duplicate no debit "+key)
		runtime.progress.cards[identity].level=3;runtime.progress.cards[identity].experience="123"
		check(runtime.request_operation(identity,{"operation_id":key+":reroll"}).ok and runtime.progress.cards[identity].level==3 and runtime.progress.cards[identity].experience=="123","growth preserved "+key)
		check(host.inventory.is_empty() and host.item_instances.is_empty(),"last physical book removed "+key)
		before=hash([runtime.progress,host.gold,runtime.selection_rng.state])
		check(not runtime.request_operation(identity).ok and hash([runtime.progress,host.gold,runtime.selection_rng.state])==before,"missing book no debit "+key)
	check(tested.size()>=12,"eligible source deck/grade transactions")
	for grade: int in [3,4,5,32,52]:
		check(Runtime.Core.FEES[grade]=={3:100000,4:500000,5:1000000,32:2000000,52:5000000}[grade],"explicit fee "+str(grade))
	host.free()
	print("SKILL_TRANSACTION ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
