extends RefCounted
## Owned-ticket redemption; no market purchase, new card pool, or free issuance.
const IDS:Array[int]=[166744,254088,342064,342074,352054,352064]
const UI_POLICY_TEXT:String="TWILIGHT 소지 티켓1개 소비 정책 · 원본 무작위 풀/지급량 · 추가 구매 비용 없음 · 미연결 대상은 소지품 보존"
const CardEngine=preload("res://scripts/card_draw_fusion.gd")
const OriginalInput=preload("res://scripts/shop/current523_ticket_input.gd")
var owner_ref:WeakRef
var runtime:
	get:return owner_ref.get_ref() if owner_ref!=null else null
var document:Dictionary={}
var loaded_sha:String=""
var model_input_identity:Dictionary={}
var last_input_attempt:Dictionary={}
var problem:String=""
var random:=RandomNumberGenerator.new()

func _init() -> void:
	random.randomize()

func configure(owner) -> void:
	owner_ref=weakref(owner)
	var arguments:Dictionary=_input_arguments()
	if arguments.explicit:load_pack(arguments.path,arguments.sha256)
	else:load_original()

func _input_arguments() -> Dictionary:
	var result:Dictionary={"explicit":false,"path":"","sha256":""}
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-ticket-pack"):
			result.explicit=true
			if arg.begins_with("--source523-ticket-pack="):result.path=arg.trim_prefix("--source523-ticket-pack=")
		if arg.begins_with("--source523-ticket-sha256"):
			result.explicit=true
			if arg.begins_with("--source523-ticket-sha256="):result.sha256=arg.trim_prefix("--source523-ticket-sha256=")
	return result

func load_original() -> bool:
	if _input_arguments().explicit:return _reject("명시한 티켓 확장팩 입력을 우회하지 않습니다")
	if not document.is_empty() and not loaded_sha.is_empty() and problem.is_empty():return true
	var input=OriginalInput.new()
	var payload:Dictionary=input.build()
	if payload.is_empty():
		last_input_attempt={"mode":"current523_original","problem":input.problem,"blocked_pools":input.blocked_pools.duplicate(true)}
		return _reject(input.problem)
	var bytes:PackedByteArray=JSON.stringify(payload,"",false,true).to_utf8_buffer()
	if bytes.size()>2*1024*1024:return _reject("티켓 확장팩 크기·접근 오류")
	var hashing:=HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	var actual:String=hashing.finish().hex_encode()
	# The receipt/policy fingerprint remains the actual model payload digest.
	# It is neither the source ZIP hash nor an old extension pack's fingerprint.
	return _accept_input(payload,actual,{"kind":"twilight.source523.original-ticket-input.v1","archive":input.source_identity.duplicate(true),"payload_sha256":actual,"payload_bytes":bytes.size(),"projection":"tools/shop/build_source523_tickets.py"})

func load_pack(path:String,expected:String) -> bool:
	if expected.length()!=64 or not expected.is_valid_hex_number(false) or not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=expected.to_lower():return _reject("티켓 확장팩 해시 확인 실패")
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>2*1024*1024:return _reject("티켓 확장팩 크기·접근 오류")
	var json:=JSON.new()
	if json.parse(file.get_as_text())!=OK or not json.data is Dictionary:return _reject("티켓 확장팩 JSON 오류")
	var data:Dictionary=json.data
	return _accept_input(data,expected.to_lower(),{"kind":"twilight.source523.ticket-pack-input.v1","payload_sha256":expected.to_lower(),"declared_source_zip_sha256":runtime.Catalog.SOURCE_SHA256})

func _accept_input(data:Dictionary,actual_sha:String,input_identity:Dictionary) -> bool:
	if data.get("schema")!="twilight.source523.inventory-ticket-extension.v1" or data.get("source_sha256")!=runtime.Catalog.SOURCE_SHA256 or not data.get("tickets") is Dictionary or data.tickets.size()!=6 or not data.get("pools") is Dictionary or data.get("owned_use_policy")!="twilight_one_owned_ticket_for_linked_products" or not data.get("redeem_owned_when_market_not_on_sale") is bool:return _reject("티켓 확장팩 원본·정책 불일치")
	for id:int in IDS:
		var ticket:Variant=data.tickets.get(str(id))
		if not ticket is Dictionary or ticket.get("original_item")!=runtime.catalog.record("ItemClass",id) or ticket.original_item.get("TestItem",true) or ticket.get("name")!=runtime.catalog.label(int(ticket.original_item.DescID)) or not ticket.get("grants") is Array or ticket.grants.is_empty():return _reject("티켓 원본 아이템·결과 연결 오류")
		var actual:Array=[]
		for relation:Dictionary in runtime.catalog._related("MarketPurchaseProduct",int(ticket.get("market_id",0)))+runtime.catalog._related("MarketBonusForPurchase",int(ticket.get("market_id",0))):
			var product:Dictionary=runtime.catalog.record("MarketProduct",int(relation.MarketProductID))
			if int(product.get("UnitID",0))!=35:return _reject("미지원 티켓 결과 단위")
			actual.append({"product_id":int(product.ID),"pool_id":int(product.ClassID),"count":int(product.Amount)})
		if actual.size()!=ticket.grants.size():return _reject("티켓 원본 지급량 불일치")
		for position:int in range(actual.size()):
			var grant:Variant=ticket.grants[position]
			if not grant is Dictionary:return _reject("티켓 지급 형식 오류")
			for field:String in ["product_id","pool_id","count"]:
				if not runtime.integer(grant.get(field)) or int(grant[field])!=int(actual[position][field]):return _reject("티켓 원본 지급량 불일치")
		for grant:Dictionary in ticket.grants:
			if not runtime.integer(grant.get("count")) or int(grant.count)<1 or int(grant.count)>100 or not data.pools.get(str(int(grant.pool_id))) is Array:return _reject("티켓 추첨 횟수·풀 오류")
	for pool_id:String in data.pools:
		var entries:Variant=data.pools[pool_id];var total:int=0;var seen:Dictionary={}
		if not entries is Array or entries.is_empty() or entries.size()>1000:return _reject("티켓 풀 크기 오류")
		for row:Variant in entries:
			if not row is Dictionary or not runtime.integer(row.get("card_id")) or not runtime.integer(row.get("weight")) or not runtime.integer(row.get("grade_id")) or int(row.card_id)<1 or seen.has(int(row.card_id)):return _reject("티켓 풀 정수·중복 오류")
			seen[int(row.card_id)]=true;total+=int(row.weight)
		if total!=1000000:return _reject("티켓 원본 확률 총합 오류 · 재정규화 없음")
	document=data;loaded_sha=actual_sha;model_input_identity=input_identity.duplicate(true);last_input_attempt={};problem=""
	return true

func _reject(message:String) -> bool:
	problem=message
	return false

static func claims(record:Dictionary) -> bool:
	return int(record.get("source_item_class_id",0)) in IDS

func install() -> Dictionary:
	var bindings:Dictionary={}
	if loaded_sha.is_empty() or not problem.is_empty():return bindings
	for id:int in IDS:
		var spec:Dictionary=document.tickets[str(id)]
		var name:String=str(spec.name)
		var record:Dictionary=runtime.world._find_catalog_item_record(name)
		if not record.is_empty() and (record.get("source")!="twilight-shop523-ticket" or int(record.get("source_item_class_id",0))!=id):continue
		if record.is_empty():
			record={"name":name,"grade":str(spec.grade),"slot":"consumable","type":"원본 뽑기권","source":"twilight-shop523-ticket","source_snapshot":"patch523","source_item_class_id":id,"source_bless_raw":1,"source_ticket_extension_sha":loaded_sha,"source_max_stack":int(spec.original_item.MaxStackAmount),"weight":0,"droppable":bool(spec.original_item.IsDroppable),"storable":bool(spec.original_item.IsStorable),"desc":"소지 티켓1개로 원본 연결 풀 추첨 · TWILIGHT 소지품 소비 정책 · 추가 구매 비용 없음"}
			runtime.world.item_db.append(record.duplicate(true));runtime.world.catalog_db["아이템"].append(record)
		bindings["4:"+str(id)]={"name":name,"record":record.duplicate(true)}
	runtime.world._index_item_weights()
	return bindings

func _identity(name:String,spec:Dictionary,record:Dictionary) -> bool:
	var id:int=int(record.get("source_item_class_id",0))
	if id not in IDS or record.get("source_bless_raw",1)!=1 or int(record.get("source_enchant",0))!=0:return false
	if record.get("source")=="twilight-shop523-ticket":return record.get("name")==spec.name and name==spec.name and record.get("source_snapshot")=="patch523" and record.get("source_ticket_extension_sha")==loaded_sha and record.get("source_bless_raw")==1
	if record.get("source")!="lineagem_patch523" or record.get("source_snapshot")!="patch523":return false
	var key:String=str(id)+":1:0"
	if record.get("expedition_key")==key:
		var issuer:Variant=runtime.world.get("expedition_local")
		var ledger:Variant=issuer.get("state") if issuer is Object else null
		if not ledger is Dictionary or not ledger.get("issued") is Dictionary:return false
		return ledger.issued.get(key)==name and record.get("sourceId")=="m523:expedition:"+key and record.get("source_item")==spec.original_item and name==str(spec.original_item.Name)+" (탐험 "+key+")"
	if not record.get("source_m_native_item",false):return false
	var loot:Variant=runtime.world.get_script().get_script_constant_map().get("LOOT_DROP")
	if not loot is Script:return false
	var provider:Variant=loot.get_script_constant_map().get("PATCH523_DROPS")
	if not provider is Script:return false
	var methods:Array=[]
	for method:Dictionary in provider.get_script_method_list():methods.append(str(method.name))
	for required:String in ["data","matches","variant_item"]:
		if required not in methods:return false
	var definition:Dictionary=provider.data().get("item_definitions",{}).get(str(id),{})
	return definition.get("original_item")==spec.original_item and provider.matches(record,provider.variant_item(definition.get("native_record",{}),1))

func quote(name:String,selection:Dictionary={},internal:bool=false) -> Dictionary:
	var ready:Dictionary=runtime._ready_for_action(internal)
	if not ready.ok:return ready
	if runtime.world.hud.is_card_reveal_busy():return runtime.fail("카드 결과 연출 중 · 티켓 보존")
	if loaded_sha.is_empty() or not problem.is_empty():return runtime.fail(problem if not problem.is_empty() else "검증된 티켓 확장팩이 필요합니다 · 소지품 보존")
	if not selection.is_empty():return runtime.fail("이6종은 원본 무작위 추첨입니다 · 선택 결과 지정 불가")
	var record:Dictionary=runtime.world._find_catalog_item_record(name)
	var id:int=int(record.get("source_item_class_id",0))
	var spec:Dictionary=document.tickets.get(str(id),{})
	if spec.is_empty() or not _identity(name,spec,record):return runtime.fail("정확한 티켓 발급원장·원본 ID/Normal/강화0 확인 필요")
	if int(runtime.world.inventory.get(name,0))<1 or runtime.world._item_locked(name,""):return runtime.fail("소지 티켓 부족 또는 잠금")
	for field:String in ["expires_at","source_expires_at"]:
		if not record.has(field):continue
		if not runtime.integer(record[field]) or (int(record[field])>0 and int(record[field])<=runtime._now()):return runtime.fail("소지 티켓 기간 만료·형식 오류 · 기한 연장 없음")
	var prior:Dictionary=runtime.state.get("ticket_redemption",{})
	if not prior.is_empty() and prior.get("policy_sha256")!=loaded_sha:return runtime.fail("티켓 풀·정책 변경 감지 · 기존 정책 필요")
	var market:Dictionary=runtime.catalog.record("MarketPurchase_Korean",int(spec.market_id))
	if not market.get("OnSale",false) and not document.redeem_owned_when_market_not_on_sale:return runtime.fail("비활성 마켓 참조의 소지 티켓 사용 정책이 꺼져 있습니다")
	var window:Dictionary=runtime._window(runtime.catalog.record("DateTimes_Korean",int(market.get("EffectiveFromId",0))),runtime.catalog.record("DateTimes_Korean",int(market.get("EffectiveToId",0))))
	if not window.ok:return window
	var sets:Array=[]
	for row:Dictionary in runtime.catalog._related("MarketPurchaseServerLimitGroup",int(spec.market_id)):sets.append(int(row.ServerLimitSetID))
	var server:Dictionary=runtime._server(sets)
	if not server.ok:return server
	var index:Dictionary={}
	for category:String in CardEngine.CATEGORIES:
		for card:Dictionary in runtime.world.catalog_db.get(category,[]):
			var source_id:int=int(card.get("source_card_id",0))
			if source_id<1:continue
			if index.has(source_id):return runtime.fail("중복 원본 카드 정체 · 풀 보존")
			index[source_id]={"category":category,"record":card,"id":CardEngine.card_id(card)}
	var pools:Dictionary={};var category:String="";var count:int=0;var missing:Array=[]
	for grant:Dictionary in spec.grants:
		var pool_id:String=str(int(grant.pool_id));var candidates:Array=[]
		for entry:Dictionary in document.pools[pool_id]:
			if int(entry.weight)==0:continue
			var card_id:int=int(entry.card_id)
			if not index.has(card_id):missing.append(card_id);continue
			var bound:Dictionary=index[card_id];var original:Dictionary=runtime.catalog.record("BuffCard",card_id)
			if original.is_empty() or int(original.GradeID)!=int(entry.grade_id) or int(bound.record.get("source_grade_id",0))!=int(original.GradeID) or bound.record.get("source_merge_out_disabled",false)!=original.IsNoMergeOut or bound.record.get("source_swap_out_disabled",false)!=original.IsNoSwapOut:return runtime.fail("원본 카드 등급·교체/합성 제한 정체 불일치")
			var deck:int=int(original.BuffCardDeckID)
			var suffix:String=str(deck)+":"+str(card_id)
			if bound.category!={1:"변신",2:"마법인형",98:"성물"}.get(deck,"") or int(bound.record.get("source_deck_id",0))!=deck or str(bound.record.get("sourceId","")) not in ["m508:"+suffix,"m523:"+suffix] or bound.record.get("source") not in ["lineagem_base508","lineagem_patch523"]:return runtime.fail("원본 카드 분류·안정 ID 연결 불일치")
			if not runtime.world.card_draw_fusion.known_ids.get(str(bound.category),{}).has(str(bound.id)):return runtime.fail("현재 카드 소유 API에 등록되지 않은 대상")
			var card_server:Dictionary=runtime._server([] if int(original.ServerLimitSetID)==0 else [int(original.ServerLimitSetID)])
			if not card_server.ok:return card_server
			if int(original.StartDateTimeID)!=0 or int(original.EndDateTimeID)!=0:
				var card_window:Dictionary=runtime._window(runtime.catalog.record("DateTimes_Korean",int(original.StartDateTimeID)),runtime.catalog.record("DateTimes_Korean",int(original.EndDateTimeID)))
				if not card_window.ok:return card_window
			if category.is_empty():category=str(bound.category)
			if category!=str(bound.category):return runtime.fail("복수 분류 카드의 원본 선택 계약 필요")
			candidates.append({"weight":int(entry.weight),"entry":{"id":str(bound.id),"record":bound.record.duplicate(true)}})
		pools[pool_id]=candidates;count+=int(grant.count)
	if not missing.is_empty():
		var blocked:Dictionary=runtime.fail("추첨 대상 카드 자료가 미설치 상태입니다 · 티켓 보존")
		blocked["missing_card_ids"]=missing;return blocked
	return {"ok":true,"can_use":true,"inventory_key":name,"source_item_id":id,"bless_raw":1,"enchant":0,"draw_count":count,"category":category,"grants":spec.grants.duplicate(true),"pools":pools,"origin":"TWILIGHT 소지 티켓1개 소비 · 원본 풀/가중치/지급량 · 마켓 판매 상태는 유지"}

func use_ticket(name:String,selection:Dictionary={}) -> Dictionary:
	var prepared:Dictionary=quote(name,selection)
	if not prepared.ok:return prepared
	var started:Dictionary=runtime._start()
	if not started.ok:return started
	prepared=quote(name,selection,true)
	if not prepared.ok:runtime._busy=false;return prepared
	var rng:=RandomNumberGenerator.new()
	var previous:Dictionary=runtime.state.get("ticket_redemption",{})
	rng.state=int(previous.rng_state) if not previous.is_empty() else random.state
	var scratch=CardEngine.new();scratch.configure(runtime.world.catalog_db);scratch.import_state(runtime.world.card_draw_fusion.export_state())
	var results:Array=[]
	for grant:Dictionary in prepared.grants:
		for draw:int in range(int(grant.count)):
			var roll:int=rng.randi_range(1,1000000);var cursor:int=0;var chosen:Dictionary={}
			for candidate:Dictionary in prepared.pools[str(int(grant.pool_id))]:
				cursor+=int(candidate.weight)
				if roll<=cursor:chosen=candidate.entry;break
			if chosen.is_empty():runtime._busy=false;return runtime.fail("원본 추첨 구간 누락 · 티켓/난수 보존")
			if scratch.owned[str(prepared.category)].has(str(chosen.id)) and int(scratch.spare[str(prepared.category)].get(str(chosen.id),0))>=1000000:
				runtime._busy=false;return runtime.fail("중복 카드 저장 한도 초과 · 티켓/난수 보존")
			var received:Dictionary=scratch._receive(str(prepared.category),chosen)
			received["source_buff_card_id"]=int(chosen.record.source_card_id)
			received["category"]=str(prepared.category)
			results.append(received)
	var inventory:Dictionary=runtime.world.inventory.duplicate(true)
	inventory[name]=int(inventory[name])-1
	if int(inventory[name])==0:inventory.erase(name)
	var next:Dictionary=runtime.export_state()
	var uses:int=int(previous.get("uses",0))
	if uses>=runtime.LIMIT:runtime._busy=false;return runtime.fail("티켓 소비 이력 범위 초과")
	next["ticket_redemption"]={"version":1,"policy_sha256":loaded_sha,"rng_state":str(rng.state),"uses":uses+1}
	var saved:Dictionary=runtime._commit(next,inventory,int(runtime.world.gold),runtime.world.item_instances.duplicate(true),int(runtime.world.next_item_instance_id),{"card_draw_fusion":scratch.export_state()})
	if not saved.ok:return saved
	random.state=rng.state
	runtime.world.card_draw_fusion.import_state(scratch.export_state())
	runtime.world._invalidate_equipment_static();runtime.world.card_collections.invalidate();runtime.world._update_hud()
	var outcome:Dictionary={"ok":true,"category":prepared.category,"results":results,"count":results.size(),"consumed":1,"inventory_key":name,"source_item_id":prepared.source_item_id,"message":"소지 티켓1개 소비 · 원본 가중치 %d회 추첨 · TWILIGHT 소지품 소비 정책" % results.size()}
	runtime.world.hud.set_card_draw_fusion_result(str(prepared.category),str(outcome.message))
	runtime.world.hud.present_card_reveal(str(prepared.category),outcome,false)
	return outcome

static func validate_state(value:Variant) -> String:
	if not value is Dictionary or value.get("version")!=1:return "티켓 소비 저장 버전 오류"
	var sha:Variant=value.get("policy_sha256");var rng:Variant=value.get("rng_state");var uses:Variant=value.get("uses")
	if not sha is String or sha.length()!=64 or not sha.is_valid_hex_number(false) or not rng is String or not rng.is_valid_int() or str(int(rng))!=rng or not (uses is int or uses is float) or not is_finite(float(uses)) or float(uses)!=floor(float(uses)) or int(uses)<0 or int(uses)>9007199254740991:return "티켓 소비 저장 형식 오류"
	return ""
