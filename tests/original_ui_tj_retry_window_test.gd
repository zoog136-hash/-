extends SceneTree
## The original 523 TJ의 쿠폰 retry windows (source_main_tj_retry_window.gd)
## over the existing TJ coupon feature. Without arguments (no original
## files): the grade cards come from the owned coupons' usable failure
## records, a grade opens its newest record, the popup takes one 성공 후보
## and the coupon's ChoiceFailCardCount 실패 후보 from that record only,
## 확 인 confirms and calls tj_coupons.redeem with the record's revision,
## the awakening window retries one failed target, and a missing source or
## server context leaves the existing TJ page. Real input: -- --pack=<private
## original main UI pack directory>: Recovery_All_Compose and
## Recovery_All_Awaken mount at every stage.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_tj_retry_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeCore extends RefCounted:
	var definitions: Dictionary={}
	var state: Dictionary={"revision":7}
	var settings: Dictionary={"retry_gold_cost":0}
	var blocked: bool=false
	var events: Dictionary={}
	func clock() -> int:
		return 100
	func candidates(item: String, _context: Dictionary, _now: int) -> Dictionary:
		if not events.has(item):return {"ok":false,"error":"없음"}
		return {"ok":true,"events":events[item],"policy":{"ChoiceFailCardCount":2 if item=="9001" else 0}}

class FakeTj extends RefCounted:
	var core:=FakeCore.new()
	var owned: Dictionary={"9001":1,"9002":0,"9003":2}
	var server: Dictionary={"service_region_code":"KR","world_no":1}
	var loads: int=0
	var redeemed: Array=[]
	var stacks: Dictionary={"selected-stack":{"9001":1}}
	var debited_uid: String=""
	func bag_count(item: String, uid: String) -> int:
		return int(stacks.get(uid,{}).get(item,0))
	func context() -> Dictionary:
		return server
	func owned_count(item: String) -> int:
		return int(owned.get(item,0))
	func load_default_source() -> bool:
		loads+=1
		return false
	func redeem(item: String, event_id: String, revision: int, good: Array, bad: Array, uid: String="") -> Dictionary:
		debited_uid=uid
		redeemed.append([item,event_id,revision,good,bad])
		return {"ok":true,"success":true,"error":"재도전 결과를 저장했습니다"}

class FakeFusion extends RefCounted:
	var pools: Dictionary={"변신":{"영웅":[{"record":{"source_card_id":201,"grade":"영웅","name":"영웅 카드"}}],"전설":[{"record":{"source_card_id":101,"grade":"전설","name":"전설 카드"}}]}}

class FakeWorld extends Node:
	var tj_coupons:=FakeTj.new()
	var card_draw_fusion:=FakeFusion.new()

class FakeHud extends Node:
	var messages: Array[String]=[]
	var confirmations: Array=[]
	var card_collection_state: Dictionary={"owned":{"변신":{}}}
	func show_message(text: String) -> void:
		messages.append(text)
	func confirm_action(title: String, body: String, action: String, callback: Callable, _maximum: int=0) -> Control:
		confirmations.append([title,body,action])
		callback.call(1)
		return null

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _host() -> Dictionary:
	var world:=FakeWorld.new()
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	var core: FakeCore=world.tj_coupons.core
	core.definitions={"coupons":{"9001":{"item":{"Name":"TJ의 쿠폰(변신 합성)"}},"9002":{"item":{"Name":"빈 쿠폰"}},"9003":{"item":{"Name":"TJ의 쿠폰(변신 각성)"}}},
		"merge_rules":[{"BuffCardDeckID":1,"GradeID":4,"ServerLimitSetID":0,"SuccessProbability":155000},{"BuffCardDeckID":2,"GradeID":4,"ServerLimitSetID":0,"SuccessProbability":1}],
		"cards":{"101":{"Name":"전설 A"},"102":{"Name":"전설 B"},"201":{"Name":"영웅 A"},"202":{"Name":"영웅 B"},"203":{"Name":"영웅 C"},"301":{"Name":"각성 대상"}}}
	core.events={"9001":[{"id":"failure-1","adapter":"fusion","deck":1,"grade":4,"success_candidates":["101","102"],"fail_candidates":["201","202","203"]},
		{"id":"failure-2","adapter":"fusion","deck":2,"grade":5,"success_candidates":["101"],"fail_candidates":["201"]}],
		"9002":[{"id":"failure-9","adapter":"fusion","deck":1,"grade":32,"success_candidates":["101"],"fail_candidates":["201"]}],
		"9003":[{"id":"failure-3","adapter":"awakening","deck":1,"grade":4,"success_candidates":["301"],"fail_candidates":["301"],"target_identity":"x"}]}
	return {"world":world,"hud":hud}

func _run() -> void:
	var host: Dictionary=_host()
	var tj: FakeTj=host.world.tj_coupons
	var window=WINDOW.new()
	window._hud=weakref(host.hud)
	var usable: Array=window.usable_records()
	check(usable.size()==3 and usable.all(func(row: Dictionary) -> bool:return str(row.coupon)!="9002"),"only owned coupons' records are usable: "+str(usable.size()))
	check(usable[1].category=="마법인형" and usable[2].kind=="awakening" and int(usable[0].fail_count)==2 and int(usable[2].fail_count)==1,"records keep their deck category, adapter and the coupon's fail count")
	window.kind="fusion"
	window.category="변신"
	check(window._probability(4).get("percent",0.0)==15.5 and host.hud.messages[-1].contains("영웅 변신 합성 재도전 성공 확률 15.5%"),"확률 보기 shows the original merge rule's chance: "+str(host.hud.messages.slice(-1)))
	check(not window._probability(5).get("ok",true),"no merge rule: no chance")
	check(not window._grade(32).get("ok",true) and host.hud.messages[-1].contains("이력이 없습니다"),"a grade without a usable record stays closed (the 9002 coupon is not owned)")
	window._grade(4)
	check(window.stage=="popup" and window.coupon=="9001" and str(window.retry_event.id)=="failure-1" and window.fail_count==2 and window.revision==7,"a grade opens its record with the coupon, fail count and revision")
	window._pick("201")
	check(window.picked_success.is_empty(),"a 실패 후보 is not a 성공 후보")
	window._pick("102")
	check(window.picked_success==["102"] and window._phase()=="fail","one 성공 후보, then the 실패 phase")
	window._pick("201")
	window._pick("999")
	window._pick("202")
	window._pick("203")
	check(window.picked_fail==["201","202"],"실패 후보 only from the record, at most ChoiceFailCardCount: "+str(window.picked_fail))
	window._pick("201")
	check(window.picked_fail==["202"],"a second tap deselects a 실패 후보")
	check(not window._popup_ok().get("ok",true) and window.stage=="popup","확 인 waits for the full selection")
	window._pick("203")
	window._popup_ok()
	check(window.stage=="retry","확 인 shows the chosen cards")
	window._redeem()
	check(tj.redeemed.size()==1 and tj.redeemed[0]==["9001","failure-1",7,["102"],["202","203"]],"확 인 confirms and redeems through tj_coupons: "+str(tj.redeemed))
	check(host.hud.confirmations.size()==1 and window.stage=="select" and host.hud.messages[-1].ends_with("성공"),"the result message shows and the window returns to the grade cards")
	window._grade(4)
	window._pick("101")
	window._unpick("101")
	check(window.picked_success.is_empty() and window.picked_fail.is_empty(),"removing the 성공 후보 restarts the selection")
	window._popup_close()
	check(window.stage=="select" and window.retry_event.is_empty(),"closing the popup returns to the grade cards")
	window.kind="awakening"
	window._grade(4)
	check(window.stage=="popup" and window.retry_event.is_empty(),"the awakening popup lists the failed targets")
	check(not window._popup_ok().get("ok",true),"각 성 waits for a target")
	window._pick("301")
	window._popup_ok()
	window._redeem()
	check(tj.redeemed.size()==2 and tj.redeemed[1]==["9003","failure-3",7,["301"],["301"]],"the awakening retry redeems its record: "+str(tj.redeemed))
	var parent:=Node2D.new()
	root.add_child(parent)
	tj.server={}
	check(not window.open(parent).get("handled",true),"no server context: the existing TJ page")
	tj.server={"service_region_code":"KR","world_no":1}
	var definitions: Dictionary=tj.core.definitions
	tj.core.definitions={}
	check(not window.open(parent).get("handled",true) and tj.loads==1,"no TJ source: the source read is tried, then the existing TJ page")
	tj.core.definitions=definitions
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("_open_original_feature(\"tj_coupons\")") and renewal.contains("func open_tj_coupons_native"),"TJ 쿠폰 opens the original window first")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	parent.queue_free()
	host.world.queue_free()
	print("ORIGINAL_UI_TJ_RETRY_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var host: Dictionary=_host()
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,host.hud).get("ok",false),"window configures")
	var opened: Dictionary=window.open(parent)
	check(opened.get("handled",false) and opened.member==WINDOW.COMPOSE and int(opened.filled.grades)==1,"Recovery_All_Compose mounts with the usable grade: "+str(opened).left(400))
	check(opened.filled.states=={"Btn_Unique":"Disabled","Btn_Legend":"Active","Btn_Epic":"Disabled","Btn_Myth":"Disabled"},"grade cards play the original Active / Disabled clips: "+str(opened.filled.states))
	var popup: Dictionary=window._grade(4)
	check(popup.get("handled",false) and int(popup.filled.cards)==2,"Recovery_Popup_CardList mounts the 성공 후보: "+str(popup).left(400))
	window._pick("101")
	var fail: Dictionary=window.last_result
	check(fail.get("handled",false) and int(fail.filled.cards)==3,"the 실패 후보 phase lists the record's candidates: "+str(fail).left(300))
	window._pick("201")
	window._pick("202")
	var retry: Dictionary=window._popup_ok()
	check(retry.get("handled",false) and int(retry.filled.cards)==3,"Nd_ChangeRetry shows 1 + 2 chosen cards: "+str(retry).left(300))
	check(window._cancel().get("handled",false),"취 소 returns to the grade cards")
	var tj: FakeTj=host.world.tj_coupons
	tj.core.definitions.coupons["9001"].item.CategoryID=10272
	tj.core.definitions.coupons["9001"]["profile"]={"BuffCardDeckID":1,"TJCouponHistoryType":1,"UITypeID":161}
	var physical: Dictionary=window.open(parent,"","","9001","selected-stack")
	check(physical.get("handled",false) and physical.member==WINDOW.COMPOSE and window._usable_here().size()==1,"physical coupon opens only its original deck and failure lane")
	window._grade(4)
	window._pick("101")
	window._pick("201")
	window._pick("202")
	window._popup_ok()
	window._redeem()
	check(tj.debited_uid=="selected-stack" and tj.redeemed[-1][0]=="9001","original confirmation passes the selected physical identity")
	tj.stacks.clear()
	check(window._usable_here().is_empty() and not window.open(parent,"","","9001","selected-stack").get("handled",false),"removed physical cannot use matching menu or other coupons")
	var awaken: Dictionary=window.open(parent,"awakening","변신")
	check(awaken.get("handled",false) and awaken.member==WINDOW.AWAKEN,"Recovery_All_Awaken mounts: "+str(awaken).left(300))
	check(window._physical_id.is_empty() and window._focused_item.is_empty(),"menu opening clears prior physical focus")
	var list: Dictionary=window._grade(4)
	check(list.get("handled",false) and int(list.filled.cards)==1,"Recovery_Popup_Awaken_CardList lists the target: "+str(list).left(300))
	window._pick("301")
	check(window._popup_ok().get("handled",false),"Nd_Retry mounts with the target")
	for name: String in ["마법인형","성물"]:
		check(window.open(parent,"fusion",name).get("handled",false),name+" 합성 재도전 mounts")
	window.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
