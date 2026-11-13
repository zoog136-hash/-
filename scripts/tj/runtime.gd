extends RefCounted
const Service = preload("res://scripts/tj/coupon_service.gd")
const Source = preload("res://scripts/tj/source523.gd")
const Definitions = preload("res://scripts/resources/current523_definition_rows.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
var core = Service.new()
var world
var loading := false
var source_problem: String = ""
var source_state: String = "not_loaded"
var source_input_identity: Dictionary = {}
class SourceJob extends Node:
	signal completed(result: Dictionary)
	var thread := Thread.new()
	func begin(path: String) -> void:
		var error: Error=thread.start(func() -> Dictionary:return Source.install(path))
		if error!=OK:
			set_process(false);call_deferred("failed");return
		set_process(true)
	func failed() -> void:
		completed.emit({});queue_free()
	func _process(_delta: float) -> void:
		if thread.is_alive():return
		var data: Dictionary=thread.wait_to_finish()
		set_process(false);completed.emit(data);queue_free()
	func _exit_tree() -> void:
		if thread.is_started():thread.wait_to_finish()
func configure(host) -> void:
	world=host
	# Source parsing starts on the TJ page, never on ordinary Main startup.
	var config := ConfigFile.new()
	if config.load("user://tj523-policy.cfg")==OK:
		for key: String in ["allow_no_season","allow_unknown_expiry"]:
			var value: Variant=config.get_value("local_policy",key,false)
			if value is bool:core.settings[key]=value
		var mode: String=str(config.get_value("local_policy","legacy_time_mode","blocked"))
		if mode in ["blocked","calendar_yyyymmddhh"]:core.settings.legacy_time_mode=mode
		var offset: int=int(config.get_value("local_policy","utc_offset_minutes",540))
		if offset>=-840 and offset<=840:core.settings.utc_offset_minutes=offset
		var fee: int=int(config.get_value("local_policy","retry_gold_cost",0))
		if fee>=0 and fee<=1000000000000:core.settings.retry_gold_cost=fee
func context() -> Dictionary:
	var native: Dictionary=world.card_collections.source_server_context() if world.card_collections!=null else {}
	if native.is_empty():return {}
	return {"service_region_code":str(native.get("ServiceRegionCode","")),"world_no":int(native.get("WorldNo",-1))}
func install(path: String) -> bool:
	if loading:return false
	var data: Dictionary=Source.install(path)
	if data.is_empty():return false
	core.definitions=data
	return true
func load_default_source() -> bool:
	# This read is requested by the existing TJ page, never Main startup. It
	# neither installs an archive nor changes a source/save binding.
	if loading:
		source_problem = "TJ 원본 입력을 이미 읽고 있습니다."
		return false
	var path: String = Source.CACHE
	var input_origin: String = "dedicated_original_archive"
	var cached: FileAccess = FileAccess.open(path,FileAccess.READ)
	var cache_error: Error = FileAccess.get_open_error()
	if cached != null:
		cached.close()
	elif cache_error != ERR_FILE_NOT_FOUND or FileAccess.file_exists(path):
		source_problem = "전용 TJ 원문 ZIP을 열지 못했습니다: "+str(cache_error)
		source_state = "unavailable"
		return false
	else:
		path = Definitions.archive_path()
		input_origin = "held_original_archive"
		if path.is_empty():
			source_problem = Definitions.problem()
			if source_problem.is_empty(): source_problem = "보유한 현재523 원문 ZIP 입력이 없습니다."
			source_state = "unavailable"
			return false
	var data: Dictionary = Source.load_zip(path)
	if data.is_empty():
		source_problem = Source.problem
		if source_problem.is_empty(): source_problem = "TJ 원문 입력을 읽지 못했습니다."
		source_state = "unavailable"
		return false
	# Adopt only a complete result from the existing whole-original parser.
	var identity: Dictionary = data.get("sourceInputIdentity",{}).duplicate(true)
	identity["input_origin"] = input_origin
	core.definitions = data
	source_input_identity = identity
	source_problem = ""
	source_state = "ready"
	return true
func capture_fusion(result: Dictionary) -> void:
	var entries: Array=result.get("results",[]) if bool(result.get("batch",false)) else [result]
	for row: Dictionary in entries:
		var event: Dictionary=row.get("tj_event",{})
		if event.is_empty():continue
		event=event.duplicate(true)
		event["context"]=context();event["time"]=core.clock()
		core.record_failure(event)
func grant_for_test(item: String) -> Dictionary:
	if not OS.is_debug_build() or not core.definitions.get("coupons",{}).has(item) or core.blocked:return {"ok":false,"error":"검증된 테스트 쿠폰만 지급할 수 있습니다"}
	var next: Dictionary=core.export_state()
	next.coupons[item]=mini(10000,int(next.coupons.get(item,0))+1)
	next.revision=int(next.revision)+1
	if world._save_game(true,{Service.KEY:next})!=OK:return {"ok":false,"error":"저장 실패로 지급하지 않았습니다"}
	core.import_state(next)
	return {"ok":true}
## Physical original TJ coupons in the bag (user decision 2026-11-13): the
## receipted stacks of this exact ItemClass. They count with this screen's own
## coupon record and are spent through the bag's physical debit, never copied.
func bag_stacks(item: String) -> Array:
	var found: Array=[]
	if world==null or not item.is_valid_int():return found
	for uid: Variant in world.item_instances:
		var entry: Variant=world.item_instances[uid]
		if not entry is Dictionary or not entry.has(STACK.RECEIPT):continue
		var owned: Dictionary=STACK.proof(world,str(uid))
		if owned.is_empty() or STACK.whole(owned.record.get("source_item_class_id"))!=int(item) or int(owned.record.get("source_bless_raw",1))!=1:continue
		if world._item_locked(str(entry.get("name","")),str(uid)) or world._item_locked(str(entry.get("name",""))):continue
		found.append({"uid":str(uid),"owned":owned})
	return found
func bag_count(item: String) -> int:
	var total: int=0
	for stack: Dictionary in bag_stacks(item):total+=int(stack.owned.remaining)
	return total
func owned_count(item: String) -> int:
	return int(core.state.coupons.get(item,0))+bag_count(item)
func _bag_debit(item: String) -> Dictionary:
	var stacks: Array=bag_stacks(item)
	if stacks.is_empty():return {"ok":false,"error":"가방의 원본 TJ 쿠폰을 찾지 못했습니다 · 변경 없음"}
	var owned: Dictionary=stacks[0].owned
	var debit: Dictionary=STACK.stage_debit(world,[{"physical_id":str(stacks[0].uid),"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt.duplicate(true)}])
	if not debit.get("ok",false):return {"ok":false,"error":str(debit.get("reason","가방 쿠폰 차감 확인 실패"))+" · 변경 없음"}
	return debit
func _apply_bag_debit(debit: Dictionary) -> void:
	if debit.is_empty():return
	world.inventory=debit.overrides.inventory;world.item_instances=debit.overrides.item_instances
	world.consumable_service.import_state(debit.overrides.consumable_state)
	world.hud.refresh_inventory(world.inventory)
func redeem(item: String, event_id: String, revision: int, success_ids: Array, fail_ids: Array) -> Dictionary:
	if world._option_awakening_busy():return {"ok":false,"error":"다른 카드 거래가 진행 중입니다"}
	var prepared: Dictionary=core.prepare(item,event_id,context(),core.clock(),revision,success_ids,fail_ids,bag_count(item))
	if not prepared.ok:return prepared
	if int(world.gold)<int(core.settings.retry_gold_cost):return {"ok":false,"error":"TWILIGHT 추가 거래 비용 아데나가 부족합니다"}
	core.busy=true
	if int(prepared.event.get("deck",0))==41:
		core.busy=false
		return {"ok":false,"error":"기존 게임에 스킬 카드 합성 실패 엔진이 없어 별도 연결이 필요합니다. 소유 쿠폰은 유지됩니다"}
	if str(prepared.event.get("adapter",""))=="awakening":return redeem_awakening(prepared)
	var event: Dictionary=prepared.event
	var rules: Array=[]
	for row: Dictionary in core.definitions.merge_rules:
		if int(row.BuffCardDeckID)==int(event.deck) and int(row.GradeID)==int(event.grade) and core.server_matches(int(row.ServerLimitSetID),context()):rules.append(row)
	if rules.size()!=1:
		core.busy=false
		return {"ok":false,"error":"현재 서버의 단일 원본 합성 확률을 확인할 수 없습니다"}
	# TWILIGHT adapter: one reward, no additional mystery reward. Native chance
	# is preserved; server candidate construction is not claimed to be recovered.
	var rng := RandomNumberGenerator.new()
	rng.state=int(core.state.get("rng_state",str(world.card_draw_fusion.rng.state)))
	var success: bool=rng.randi_range(0,999999)<int(rules[0].SuccessProbability)
	for id: String in prepared.success_ids:
		if int(core.definitions.cards[id].GradeID)!=int(rules[0].get("SuccessGradeID",-1)):
			core.busy=false
			return {"ok":false,"error":"성공 후보의 등급이 원본 합성 규칙과 다릅니다"}
	for id: String in prepared.fail_ids:
		if int(core.definitions.cards[id].GradeID)!=int(event.grade):
			core.busy=false
			return {"ok":false,"error":"실패 후보의 등급이 실제 기록과 다릅니다"}
	var candidates: Array=prepared.success_ids if success else prepared.fail_ids
	var selected: String=str(candidates[rng.randi_range(0,candidates.size()-1)])
	var category := ""
	for name: String in Service.DECK:
		if int(Service.DECK[name])==int(event.deck):category=name
	var entry: Dictionary={}
	for pool: Array in world.card_draw_fusion.pools.get(category,{}).values():
		for candidate: Dictionary in pool:
			if str(int(candidate.record.get("source_card_id",0)))==selected:entry=candidate
	if not entry.is_empty():
		var current: Dictionary=entry.record.get("source_original",{})
		var original: Dictionary=core.definitions.cards.get(selected,{})
		if int(current.get("grade_id",-1))!=int(original.get("GradeID",-2)) or int(current.get("deck_id",-1))!=int(original.get("BuffCardDeckID",-2)):entry={}
	if entry.is_empty():
		core.busy=false
		return {"ok":false,"error":"선택한 실제 카드가 현재 게임 카탈로그에 없습니다"}
	var cards=Cards.new()
	cards.configure(world.catalog_db)
	cards.import_state(world.card_draw_fusion.export_state())
	var awarded: Dictionary=cards._receive(category,entry)
	var next: Dictionary=prepared.state
	next["rng_state"]=str(rng.state)
	next.receipts.append({"revision":next.revision,"coupon":item,"event":event_id,"card":selected,"success":success,"time":next.last_time,"adapter":"TWILIGHT single-result source-chance retry"})
	var overrides: Dictionary={Service.KEY:next,"card_draw_fusion":cards.export_state(),"gold":int(world.gold)-int(core.settings.retry_gold_cost)}
	var debit: Dictionary={}
	if prepared.get("bag_debit",false):
		debit=_bag_debit(item)
		if not debit.get("ok",false):core.busy=false;return debit
		overrides.merge(debit.overrides)
	var saved: Error=world._save_game(true,overrides)
	core.busy=false
	if saved!=OK:return {"ok":false,"error":"저장 실패 · 쿠폰과 카드 및 실패 이력을 유지했습니다"}
	core.import_state(next);_apply_bag_debit(debit)
	world.gold=int(world.gold)-int(core.settings.retry_gold_cost)
	world.card_draw_fusion.import_state(cards.export_state())
	world._invalidate_equipment_static()
	world._update_hud()
	return {"ok":true,"success":success,"result":awarded,"error":"재도전 결과를 저장했습니다. 쿠폰 한 장과 선택한 이력을 사용했습니다"}
func capture_awakening(category: String, identity: String, result: Dictionary) -> void:
	if not bool(result.get("ok",false)) or bool(result.get("success",true)):return
	var definition: Dictionary=world.option_awakening.core.definition(category,identity)
	var raw: Dictionary=definition.get("native_source",{}).get("card",{})
	if raw.is_empty():return
	var id: String=str(int(raw.ID))
	core.record_failure({"adapter":"awakening","history_type":{"변신":41,"마법인형":51,"성물":61}.get(category,0),"deck":Service.DECK.get(category,0),"grade":int(raw.GradeID),"time":core.clock(),"context":context(),"success_candidates":[id],"fail_candidates":[id],"target_identity":identity,"category":category})
func redeem_awakening(prepared: Dictionary) -> Dictionary:
	var event: Dictionary=prepared.event
	var adapter=world.option_awakening
	if adapter.save_blocked or not adapter.problem.is_empty():core.busy=false;return {"ok":false,"error":"각성 저장 또는 원본 설정 보호 중"}
	var compatible: String=awakening_compatibility(adapter.core.definition(str(event.category),str(event.target_identity)))
	if not compatible.is_empty():core.busy=false;return {"ok":false,"error":compatible}
	adapter._sync_native_context()
	var rng := RandomNumberGenerator.new();rng.state=adapter.rng.state
	# Explicit local policy: preserve existing engine costs and feeding guards.
	# No invented free experience or native material exemption is granted.
	var result: Dictionary=adapter.core.prepare_awaken(adapter.export_state(),world.card_draw_fusion.export_state(),int(world.gold),str(event.category),str(event.target_identity),rng.randi_range(0,9999))
	if not result.get("ok",false):core.busy=false;return result
	if int(result.gold)<int(core.settings.retry_gold_cost):core.busy=false;return {"ok":false,"error":"각성 비용과 추가 거래 비용을 함께 지불할 수 없습니다"}
	result.gold=int(result.gold)-int(core.settings.retry_gold_cost)
	result.state["rng_state"]=str(rng.state)
	var next: Dictionary=prepared.state
	next.receipts.append({"revision":next.revision,"coupon":prepared.item,"event":event.id,"success":result.success,"time":next.last_time,"adapter":"existing option awakening, ordinary costs preserved"})
	var overrides: Dictionary={Service.KEY:next,"card_option_awakening":result.state,"card_draw_fusion":result.card_state,"gold":result.gold}
	var debit: Dictionary={}
	if prepared.get("bag_debit",false):
		debit=_bag_debit(str(prepared.item))
		if not debit.get("ok",false):core.busy=false;return debit
		overrides.merge(debit.overrides)
	var saved: Error=world._save_game(true,overrides)
	core.busy=false
	if saved!=OK:return {"ok":false,"error":"저장 실패 · 쿠폰·각성·재료·아데나를 유지했습니다"}
	core.import_state(next);_apply_bag_debit(debit);adapter.progress=result.state.duplicate(true);adapter.rng.state=rng.state;adapter._bonus_signature=""
	world.card_draw_fusion.import_state(result.card_state);world.gold=int(result.gold)
	world._invalidate_equipment_static();world._sync_option_awakening_auras();world._update_hud()
	return {"ok":true,"success":result.success,"error":"각성 재도전과 기존 엔진 비용을 함께 저장했습니다"}

func set_context(region: String, number: String) -> Dictionary:
	if core.blocked or core.busy or region.strip_edges().is_empty() or not number.is_valid_int() or int(number)<1:return {"ok":false,"error":"실제 서비스 지역과 양수 월드 번호를 입력하세요"}
	var next: Dictionary=core.export_state()
	next["server_context"]={"service_region_code":region.strip_edges(),"world_no":int(number)}
	next.revision=int(next.revision)+1
	if world._save_game(true,{Service.KEY:next})!=OK:return {"ok":false,"error":"서버 문맥 저장 실패 · 이전 설정 유지"}
	core.import_state(next);restore_context()
	return {"ok":true,"error":"입력한 서버 문맥을 저장했습니다"}
func restore_context() -> void:
	var saved: Dictionary=core.state.get("server_context",{})
	if not saved.is_empty():world.card_collections.set_source_server_context({"source_snapshot":"base508","ServiceRegionCode":str(saved.service_region_code),"WorldNo":int(saved.world_no)})

func awakening_compatibility(definition: Dictionary) -> String:
	# An existing engine is reused only when its actual inputs equal latest523.
	var source: Dictionary=definition.get("native_source",{})
	if source.is_empty():return "최신 원본과 연결되지 않은 각성 정의입니다"
	var raw: Dictionary=source.get("card",{})
	if raw!=core.definitions.cards.get(str(int(raw.get("ID",0))),{}):return "현재 각성 카드 정의가 최신 523과 다릅니다"
	var groups: Array=[source.get("group",{})]
	groups.append_array(source.get("secondary_groups",[]))
	for group: Dictionary in groups:
		if group!=core.definitions.awakening_groups.get(str(int(group.get("ID",0))),{}):return "현재 각성 그룹이 최신 523과 다릅니다"
		if not core.server_matches(int(group.get("ServerLimitsetID",0)),context()):return "최신 523 각성 그룹의 서버 조건을 만족하지 않습니다"
	for effect: Dictionary in source.get("effects",[]):
		var link: Dictionary=effect.get("link",{})
		if link!=core.definitions.awakening_links.get(str(int(link.get("ID",0))),{}):return "각성 효과 연결이 최신 523에서 변경되어 기존 어댑터로 실행하지 않습니다"
		var bonus: Dictionary=effect.get("bonus",{})
		if bonus!=core.definitions.awakening_bonuses.get(str(int(bonus.get("ID",0))),{}):return "각성 보너스가 최신 523과 다릅니다"
	var economy: Dictionary=preload("res://data/cards/base508_option_extensions.json").data.economy
	for values: Dictionary in economy.values():
		for row: Dictionary in values.values():
			if int(row.BuffCardDeckID)==int(raw.BuffCardDeckID) and row!=core.definitions.awakening_values.get(str(int(row.ID)),{}):return "각성 비용 또는 경험치 원값이 최신 523과 다릅니다"
	return ""

func install_async(path: String) -> bool:
	if loading:return false
	loading=true
	var job:=SourceJob.new()
	world.add_child(job)
	job.begin(path)
	var data: Dictionary=await job.completed
	loading=false
	if data.is_empty():return false
	core.definitions=data
	return true
