extends SceneTree
const Runtime=preload("res://scripts/tj/runtime.gd")
const Service=preload("res://scripts/tj/coupon_service.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Writer=preload("res://scripts/skills/save_writer.gd")
var checks:=0
var failures: Array[String]=[]
class Context extends RefCounted:
	func source_server_context() -> Dictionary:return {"ServiceRegionCode":"KR","WorldNo":1,"source_snapshot":"base508"}
class Host extends RefCounted:
	var card_collections=Context.new()
	var card_draw_fusion=Cards.new()
	var catalog_db: Dictionary={}
	var gold:=1234
	var force_failure:=false
	var path: String="user://tj-transaction.json"
	var quest_state: Dictionary={"completed":["existing-quest"],"revision":7}
	func _option_awakening_busy() -> bool:return false
	func _invalidate_equipment_static() -> void:pass
	func _update_hud() -> void:pass
	func _save_game(_quiet: bool, override: Dictionary={}) -> Error:
		if force_failure:return ERR_FILE_CANT_WRITE
		var data: Dictionary={"gold":gold,"quest_state":quest_state,"card_draw_fusion":card_draw_fusion.export_state()}
		data.merge(override,true)
		return Writer.write(path,data)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var isolated: String=OS.get_environment("TWILIGHT_TJ_TEST_ROOT")
	check(not isolated.is_empty() and ProjectSettings.globalize_path("user://").begins_with(isolated),"isolate real writer")
	var host=Host.new()
	for category: String in Cards.CATEGORIES:host.catalog_db[category]=[]
	host.catalog_db["변신"]=[{"name":"Synthetic low","grade":"희귀","sourceId":"tj-fixture:101","source_card_id":101,"source_original":{"deck_id":1,"grade_id":3}},{"name":"Synthetic high","grade":"영웅","sourceId":"tj-fixture:100","source_card_id":100,"source_original":{"deck_id":1,"grade_id":4}}]
	host.card_draw_fusion.configure(host.catalog_db)
	var runtime=Runtime.new();runtime.world=host
	var core=runtime.core
	core.definitions={"coupons":{"900001":{"item":{"Name":"Synthetic"},"profile":{"TJCouponHistoryType":1,"OwnerTypeID":1,"BuffCardDeckID":1,"ChoiceFailCardCount":0,"BuffCardMinGrade":2},"effects":[{"BonusTypeID":11551,"Value":6},{"BonusTypeID":492,"Value":0,"BonusApplicationTypeID":298,"BonusApplicationTargetID":3}]}},"histories":[{"ID":31,"HistoryType":1,"OwnerType":1,"MinGrade":3}],"mappings":[{"HistoryType":1,"UnitID":31,"Value":1}],"dates":{"1":{"Year":2026,"Month":1,"Day":1},"2":{"Year":2027,"Month":1,"Day":1},"3":{"Year":2027,"Month":2,"Day":1}},"seasons":[{"ID":882,"HistoryType":1,"Season":6,"ServerLimitSetID":9,"StartDateTimeID":1,"EndDateTimeID":2}],"servers":[{"ServerLimitSetID":9,"ServiceRegionCode":"KR","WorldNo":1}],"cards":{"100":{"BuffCardDeckID":1,"GradeID":4},"101":{"BuffCardDeckID":1,"GradeID":3}},"merge_rules":[{"BuffCardDeckID":1,"GradeID":3,"ServerLimitSetID":0,"SuccessProbability":1000000,"SuccessGradeID":4}]}
	core.state.coupons["900001"]=1
	check(core.record_failure({"adapter":"fusion","history_type":1,"deck":1,"grade":3,"time":core.clock()-100,"context":runtime.context(),"success_candidates":["100"],"fail_candidates":["101"]}),"record genuine event adapter fixture")
	var old: Dictionary=core.export_state();var cards: Dictionary=host.card_draw_fusion.export_state()
	check(host._save_game(true,{Service.KEY:old})==OK,"baseline real atomic writer")
	var sha: String=FileAccess.get_sha256(host.path)
	core.settings.retry_gold_cost=99999
	var poor: Dictionary=runtime.redeem("900001",str(old.history[0].id),int(old.revision),["100"],["101"])
	check(not poor.ok and core.export_state()==old and host.gold==1234,"insufficient explicit cost changes nothing")
	core.settings.retry_gold_cost=0
	host.force_failure=true
	var result: Dictionary=runtime.redeem("900001",str(old.history[0].id),int(old.revision),["100"],["101"])
	check(not result.ok and core.export_state()==old and host.card_draw_fusion.export_state()==cards and host.gold==1234,"failed write publishes no debit reward or RNG state")
	check(FileAccess.get_sha256(host.path)==sha,"failed write preserves save bytes")
	host.force_failure=false
	result=runtime.redeem("900001",str(old.history[0].id),int(old.revision),["100"],["101"])
	check(result.ok and core.state.coupons["900001"]==0,"successful debit")
	check(host.card_draw_fusion.owned["변신"].has("source:tj-fixture:100"),"actual card ownership mutation")
	var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.path))
	check(disk.quest_state.completed==host.quest_state.completed and int(disk.quest_state.revision)==int(host.quest_state.revision) and int(disk.gold)==1234,"unrelated quest and wallet preserved")
	check(disk[Service.KEY].receipts.size()==1 and disk.card_draw_fusion.owned["변신"].has("source:tj-fixture:100"),"receipt coupon record and award saved together")
	var reloaded=Service.new();check(reloaded.import_state(disk[Service.KEY]),"restart imports committed state")
	check(reloaded.state.coupons["900001"]==0 and reloaded.state.used.has(str(old.history[0].id)),"restart preserves consumption")
	sha=FileAccess.get_sha256(host.path)
	result=runtime.redeem("900001",str(old.history[0].id),int(old.revision),["100"],["101"])
	check(not result.ok and FileAccess.get_sha256(host.path)==sha,"duplicate confirmation cannot write twice")
	core.state.last_time=core.clock()+100
	check(not core.resolve("900001",runtime.context(),core.clock()).ok,"clock rollback refuses spend without changing system clock")
	print(JSON.stringify({"TJ523_TRANSACTION_RESULT":failures.is_empty(),"failures":failures,"checks":checks,"actual_Main":false,"production_atomic_writer":true}))
	quit(0 if failures.is_empty() else 1)
