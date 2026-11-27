extends RefCounted
const VerifiedBytes = preload("res://scripts/io/verified_source_bytes.gd")
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Owned-ticket redemption; no market purchase, new card pool, or free issuance.
## Every original LinMarketProduct draw ticket whose products are whole
## GotChaClassID pools is redeemable (current523_ticket_input.gd); others are
## listed as unsupported and stay owned. These six keep their host catalog
## records from the first, six-ticket model.
const IDS:Array[int]=[166744,254088,342064,342074,352054,352064]
const SCHEMAS:Array[String]=["twilight.source523.inventory-ticket-extension.v1","twilight.source523.inventory-ticket-extension.v2"]
## Policy fingerprint of the six-ticket model (523 tables d5192c3c...). Its six
## tickets have the same products, pools and weights in the current model, so
## a saved draw stream continues instead of being refused as a policy change.
const PREVIOUS_POLICY_SHA256:Array[String]=["8077b46948a3de832a9275b24a195b9a32346cff07ece8cdba798ee46d763388"]
const CATEGORY:String="LinMarketProduct"
## Most draws one shop purchase may make (11회 x 10; TWILIGHT 근사, keeps a
## save and the reveal bounded).
const MAX_MARKET_DRAWS:int=110
const UI_POLICY_TEXT:String="TWILIGHT 소지 티켓1개 소비 정책 · 원본 무작위 풀/지급량 · 추가 구매 비용 없음 · 미연결 대상은 소지품 보존"
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
const CardEngine=preload("res://scripts/card_draw_fusion.gd")
const OriginalInput=preload("res://scripts/shop/current523_ticket_input.gd")
const PermanentMileage=preload("res://scripts/shop/source523_permanent_mileage_tickets.gd")
const BAKE=preload("res://scripts/resources/current523_bake_cache.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const DROPS=preload("res://scripts/loot/patch523_monster_drops.gd")
const CASH_PACKAGES=preload("res://scripts/shop/source523_cash_packages.gd")
## Original skill cards (BuffCardDeck 41 "Spell") are learned through their
## original skill book item, as the cash-market packs deliver them; a drawn
## skill card is granted as that book's physical stack.
const SPELL_DECK:int=41
const SKILL_BOOKS:String="스킬서"
## Row reading is pinned by the definition store format, not the reader's code.
const MODEL_CODE:Array[String]=["res://scripts/shop/current523_ticket_input.gd"]
var owner_ref:WeakRef
var runtime:
	get:return owner_ref.get_ref() if owner_ref!=null else null
var document:Dictionary={}
var loaded_sha:String=""
var model_input_identity:Dictionary={}
var last_input_attempt:Dictionary={}
var problem:String=""
var random:=RandomNumberGenerator.new()
## Original pools only a market draw offer names (e.g. 상급 성물/마법인형
## 뽑기(아데나) pools 1688/1308): read on demand with the same whole-pool rule
## as the ticket model; kept out of `document` so its policy identity stays.
var market_pools:Dictionary={}

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
	# Building ~4,700 tickets from the tables takes seconds; the exact payload
	# bytes are baked on the device per original and input code, and their
	# SHA-256 stays the policy fingerprint.
	var source_sha:String=str(OriginalInput.SOURCE.identity().get("source_sha256",""))
	var bake_key:String=BAKE.key(["source523_ticket_model",source_sha,preload("res://scripts/resources/current523_definition_rows.gd").STORE_FORMAT,BAKE.code_key(MODEL_CODE)]) if not source_sha.is_empty() else ""
	var baked:Dictionary=BAKE.read_payload("source523_ticket_model",bake_key) if not bake_key.is_empty() else {}
	if not baked.is_empty():
		var parsed:Variant=JSON.parse_string(baked.bytes.get_string_from_utf8())
		if parsed is Dictionary and _accept_input(parsed,str(baked.sha256),baked.identity):return true
	var input=OriginalInput.new()
	var payload:Dictionary=input.build()
	if payload.is_empty():
		last_input_attempt={"mode":"current523_original","problem":input.problem,"blocked_pools":input.blocked_pools.duplicate(true)}
		return _reject(input.problem)
	var bytes:PackedByteArray=JSON.stringify(payload,"",false,true).to_utf8_buffer()
	if bytes.size()>8*1024*1024:return _reject("티켓 확장팩 크기·접근 오류")
	var hashing:=HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	var actual:String=hashing.finish().hex_encode()
	# The receipt/policy fingerprint remains the actual model payload digest.
	# It is neither the source ZIP hash nor an old extension pack's fingerprint.
	var identity:Dictionary={"kind":"twilight.source523.original-ticket-input.v1","archive":input.source_identity.duplicate(true),"payload_sha256":actual,"payload_bytes":bytes.size(),"projection":"scripts/shop/current523_ticket_input.gd"}
	if not _accept_input(payload,actual,identity):return false
	if not bake_key.is_empty():BAKE.write("source523_ticket_model",bake_key,{"bytes":bytes,"sha256":actual,"identity":identity})
	return true

func load_pack(path:String,expected:String) -> bool:
	if expected.length()!=64 or not expected.is_valid_hex_number(false) or not FileAccess.file_exists(path):return _reject("티켓 확장팩 해시 확인 실패")
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>2*1024*1024:return _reject("티켓 확장팩 크기·접근 오류")
	var bytes := VerifiedBytes.read(file,2*1024*1024)
	if VerifiedBytes.sha256(bytes)!=expected.to_lower():return _reject("티켓 확장팩 해시 확인 실패")
	var json:=JSON.new()
	if json.parse(bytes.get_string_from_utf8())!=OK or not json.data is Dictionary:return _reject("티켓 확장팩 JSON 오류")
	var data:Dictionary=json.data
	return _accept_input(data,expected.to_lower(),{"kind":"twilight.source523.ticket-pack-input.v1","payload_sha256":expected.to_lower(),"declared_source_zip_sha256":runtime.Catalog.SOURCE_SHA256})

func _accept_input(data:Dictionary,actual_sha:String,input_identity:Dictionary) -> bool:
	if data.get("schema") not in SCHEMAS or data.get("source_sha256")!=runtime.Catalog.SOURCE_SHA256 or not data.get("tickets") is Dictionary or data.tickets.is_empty() or data.tickets.size()>100000 or not data.get("pools") is Dictionary or data.get("owned_use_policy")!="twilight_one_owned_ticket_for_linked_products" or not data.get("redeem_owned_when_market_not_on_sale") is bool:return _reject("티켓 확장팩 원본·정책 불일치")
	var legacy:bool=data.schema==SCHEMAS[0]
	if legacy and data.tickets.size()!=IDS.size():return _reject("티켓 확장팩 원본·정책 불일치")
	for key:Variant in data.tickets:
		if not key is String or not key.is_valid_int() or str(int(key))!=key:return _reject("티켓 원본 아이템·결과 연결 오류")
		var id:int=int(key);var ticket:Variant=data.tickets[key];var item:Dictionary=runtime.catalog.record("ItemClass",id)
		if legacy and id not in IDS:return _reject("티켓 원본 아이템·결과 연결 오류")
		if not ticket is Dictionary or item.is_empty() or item.get("TestItem",true) or (legacy and ticket.get("original_item")!=item) or (not legacy and int(ticket.get("item_id",0))!=id) or ticket.get("name")!=runtime.catalog.label(int(item.DescID)) or not ticket.get("grants") is Array or ticket.grants.is_empty():return _reject("티켓 원본 아이템·결과 연결 오류")
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

## The owned-ticket service answers for every original draw ticket item, so an
## unsupported one is explained and kept rather than falling to another owner.
static func claims(record:Dictionary) -> bool:
	if int(record.get("source_item_class_id",0)) in IDS:return true
	return record.get("source_m_native_item")==true and record.get("source_snapshot")=="patch523" and NATIVE_FIELDS.field(record,"source_category_name")==CATEGORY

func install() -> Dictionary:
	var bindings:Dictionary={}
	if loaded_sha.is_empty() or not problem.is_empty():return bindings
	for id:int in IDS:
		if not document.tickets.has(str(id)):continue
		var spec:Dictionary=document.tickets[str(id)];var item:Dictionary=runtime.catalog.record("ItemClass",id)
		var name:String=str(spec.name)
		var record:Dictionary=runtime.world._find_catalog_item_record(name)
		if not record.is_empty() and (record.get("source")!="twilight-shop523-ticket" or int(record.get("source_item_class_id",0))!=id):continue
		if record.is_empty():
			record={"name":name,"grade":str(spec.grade),"slot":"consumable","type":"원본 뽑기권","source":"twilight-shop523-ticket","source_snapshot":"patch523","source_item_class_id":id,"source_bless_raw":1,"source_ticket_extension_sha":loaded_sha,"source_max_stack":int(item.MaxStackAmount),"weight":0,"droppable":bool(item.IsDroppable),"storable":bool(item.IsStorable),"desc":"소지 티켓1개로 원본 연결 풀 추첨 · TWILIGHT 소지품 소비 정책 · 추가 구매 비용 없음"}
			runtime.world.item_db.append(record.duplicate(true));runtime.world.catalog_db["아이템"].append(record)
		bindings["4:"+str(id)]={"name":name,"record":record.duplicate(true)}
	runtime.world._index_item_weights()
	return bindings

func _identity(name:String,spec:Dictionary,record:Dictionary) -> bool:
	var id:int=int(record.get("source_item_class_id",0))
	var original:Dictionary=runtime.catalog.record("ItemClass",id)
	if spec.is_empty() or original.is_empty() or record.get("source_bless_raw",1)!=1 or int(record.get("source_enchant",0))!=0:return false
	if record.get("source")=="twilight-shop523-ticket":
		if id not in IDS:return false
		return record.get("name")==spec.name and name==spec.name and record.get("source_snapshot")=="patch523" and record.get("source_ticket_extension_sha")==loaded_sha and record.get("source_bless_raw")==1
	if record.get("source")!="lineagem_patch523" or record.get("source_snapshot")!="patch523":return false
	var key:String=str(id)+":1:0"
	if record.get("expedition_key")==key:
		var issuer:Variant=runtime.world.get("expedition_local")
		var ledger:Variant=issuer.get("state") if issuer is Object else null
		if not ledger is Dictionary or not ledger.get("issued") is Dictionary:return false
		return ledger.issued.get(key)==name and record.get("sourceId")=="m523:expedition:"+key and record.get("source_item")==original and name==str(original.Name)+" (탐험 "+key+")"
	if not record.get("source_m_native_item",false):return false
	# The current original definition owner; the Main scene's script need not
	# expose LOOT_DROP among its own constants.
	var definition:Dictionary=DROPS.definition_id(str(id))
	return definition.get("original_item")==original and DROPS.matches(record,DROPS.variant_item(definition.get("native_record",{}),1))

func quote(name:String,selection:Dictionary={},internal:bool=false,physical_id:String="") -> Dictionary:
	return _quote(name,selection,internal,true,physical_id)

func _quote(name:String,selection:Dictionary,internal:bool,materialize_pool:bool,physical_id:String="") -> Dictionary:
	var ready:Dictionary=runtime._ready_for_action(internal)
	if not ready.ok:return ready
	if runtime.world.hud.is_card_reveal_busy():return runtime.fail("카드 결과 연출 중 · 티켓 보존")
	if loaded_sha.is_empty() or not problem.is_empty():return runtime.fail(problem if not problem.is_empty() else "검증된 티켓 확장팩이 필요합니다 · 소지품 보존")
	if not selection.is_empty():return runtime.fail("원본 뽑기권은 무작위 추첨입니다 · 선택 결과 지정 불가")
	var record:Dictionary=runtime.world._find_catalog_item_record(name)
	var id:int=int(record.get("source_item_class_id",0))
	var spec:Dictionary=document.tickets.get(str(id),{})
	if spec.is_empty() and model_input_identity.get("kind")=="twilight.source523.original-ticket-input.v1" and PermanentMileage.VARIANTS.has(id):
		spec=PermanentMileage.spec(id,runtime.catalog.record("ItemClass",id))
		# New mileage use is a physical-only owner; an old name balance is not
		# proof of acquiring one of these exact permanent tickets.
		if not spec.is_empty() and physical_id.is_empty():return runtime.fail("원본 영구 뽑기권의 실제 소지 칸을 선택하세요 · 티켓 보존")
	if spec.is_empty() and document.get("unsupported",{}).has(str(id)):return runtime.fail("원본 뽑기권 결과 연결 미지원 ("+str(document.unsupported[str(id)])+") · 티켓 보존")
	if spec.is_empty() or not _identity(name,spec,record):return runtime.fail("정확한 티켓 발급원장·원본 ID/Normal/강화0 확인 필요")
	if record.get("source_m_native_item")==true:
		# The original DeleteTime/period rule of the ticket item itself.
		var deadline:String=preload("res://scripts/loot/patch523_monster_drops.gd").deadline_problem(record,int(runtime.world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
		if not deadline.is_empty():return runtime.fail(deadline+" · 티켓 보존")
	if int(runtime.world.inventory.get(name,0))<1 or runtime.world._item_locked(name,""):return runtime.fail("소지 티켓 부족 또는 잠금")
	if not physical_id.is_empty() and _selected_native_ticket(name,physical_id,id).is_empty():return runtime.fail("선택한 원본 티켓의 소유·수량·잠금 확인 필요 · 티켓 보존")
	for field:String in ["expires_at","source_expires_at"]:
		if not record.has(field):continue
		if not runtime.integer(record[field]) or (int(record[field])>0 and int(record[field])<=runtime._now()):return runtime.fail("소지 티켓 기간 만료·형식 오류 · 기한 연장 없음")
	var prior:Dictionary=runtime.state.get("ticket_redemption",{})
	if not prior.is_empty() and prior.get("policy_sha256")!=loaded_sha and prior.get("policy_sha256") not in PREVIOUS_POLICY_SHA256:return runtime.fail("티켓 풀·정책 변경 감지 · 기존 정책 필요")
	var market:Dictionary=runtime.catalog.record("MarketPurchase_Korean",int(spec.market_id))
	if not market.get("OnSale",false) and not document.redeem_owned_when_market_not_on_sale:return runtime.fail("비활성 마켓 참조의 소지 티켓 사용 정책이 꺼져 있습니다")
	var window:Dictionary=runtime._window(runtime.catalog.record("DateTimes_Korean",int(market.get("EffectiveFromId",0))),runtime.catalog.record("DateTimes_Korean",int(market.get("EffectiveToId",0))))
	if not window.ok:return window
	var sets:Array=[]
	for row:Dictionary in runtime.catalog._related("MarketPurchaseServerLimitGroup",int(spec.market_id)):sets.append(int(row.ServerLimitSetID))
	var server:Dictionary=runtime._server(sets)
	if not server.ok:return server
	var drawn:Dictionary=_candidates(spec.grants,materialize_pool)
	if not drawn.ok:return drawn
	var mileage:int=int(spec.get("original_mileage",0))
	if mileage>0:
		var balance:Variant=runtime.world.inventory.get(PermanentMileage.WALLET,0)
		if runtime.INTANGIBLE_BINDINGS.get(1)!=PermanentMileage.WALLET or drawn.category!="마법인형" or not runtime.integer(balance) or int(balance)>runtime.LIMIT-mileage:return runtime.fail("원본 마일리지 수령 조건 불일치 · 티켓 보존")
	return {"ok":true,"can_use":true,"inventory_key":name,"source_item_id":id,"bless_raw":1,"enchant":0,"draw_count":drawn.count,"category":drawn.category,"grants":spec.grants.duplicate(true),"pools":drawn.pools,"original_mileage":mileage,"origin":"TWILIGHT 소지 티켓1개 소비 · 원본 풀/가중치/지급량 · 마켓 판매 상태는 유지"}

## The original candidates of `grants` ([{pool_id, count}], pools of this
## model): {ok, pools, category, count} or the refusal.
func _candidates(grants:Array,materialize_pool:bool=true) -> Dictionary:
	var index:Dictionary={}
	for category:String in CardEngine.CATEGORIES:
		for card:Dictionary in runtime.world.catalog_db.get(category,[]):
			var source_id:int=int(card.get("source_card_id",0))
			if source_id<1:continue
			if index.has(source_id):return runtime.fail("중복 원본 카드 정체 · 풀 보존")
			index[source_id]={"category":category,"record":card,"id":CardEngine.card_id(card)}
	var pools:Dictionary={};var category:String="";var count:int=0;var missing:Array=[]
	var skill_class: int = -1
	for grant:Dictionary in grants:
		var pool_id:String=str(int(grant.pool_id));var candidates:Array=[]
		for entry:Dictionary in pool_entries(int(grant.pool_id)):
			if int(entry.weight)==0:continue
			var card_id:int=int(entry.card_id)
			var spell:Dictionary=runtime.catalog.record("BuffCard",card_id)
			if int(spell.get("BuffCardDeckID",0))==SPELL_DECK:
				if skill_class == -1: skill_class = CASH_PACKAGES.current_class(runtime.world)
				if not CASH_PACKAGES.skill_draw_allows_class(spell,skill_class):
					return runtime.fail("현재 직업의 스킬 카드 뽑기팩을 사용하세요 · 아이템 보존")
				var book:int=CASH_PACKAGES.skill_book_for(card_id)
				var book_record:Dictionary=DROPS.variant_item(DROPS.definition_id(str(book)).get("native_record",{}),1) if book>0 else {}
				if int(spell.GradeID)!=int(entry.grade_id) or STACK.profile(book_record).get("kind")!="skill_book":missing.append(card_id);continue
				var spell_server:Dictionary=runtime._server([] if int(spell.ServerLimitSetID)==0 else [int(spell.ServerLimitSetID)])
				if not spell_server.ok:return spell_server
				if int(spell.StartDateTimeID)!=0 or int(spell.EndDateTimeID)!=0:
					var spell_window:Dictionary=runtime._window(runtime.catalog.record("DateTimes_Korean",int(spell.StartDateTimeID)),runtime.catalog.record("DateTimes_Korean",int(spell.EndDateTimeID)))
					if not spell_window.ok:return spell_window
				if category.is_empty():category=SKILL_BOOKS
				if category!=SKILL_BOOKS:return runtime.fail("복수 분류 카드의 원본 선택 계약 필요")
				if materialize_pool:candidates.append({"weight":int(entry.weight),"entry":{"kind":"skill_book","id":str(card_id),"spell_card_id":card_id,"item_class_id":book,"name":str(book_record.name)}})
				continue
			if not index.has(card_id):missing.append(card_id);continue
			var bound:Dictionary=index[card_id];var original:Dictionary=spell
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
			if materialize_pool:candidates.append({"weight":int(entry.weight),"entry":{"id":str(bound.id),"record":bound.record.duplicate(true)}})
		if materialize_pool:pools[pool_id]=candidates
		count+=int(grant.count)
	if not missing.is_empty():
		var blocked:Dictionary=runtime.fail("추첨 대상 카드 자료가 미설치 상태입니다 · 티켓 보존")
		blocked["missing_card_ids"]=missing;return blocked
	if category.is_empty():return runtime.fail("추첨 대상이 없는 원본 풀입니다")
	return {"ok":true,"pools":pools,"category":category,"count":count}

func use_ticket(name:String,selection:Dictionary={},physical_id:String="") -> Dictionary:
	# Validate before starting a transaction, but only build the drawable pool
	# after _start(): it may flush a map save, so revalidation is still required.
	var measure:int=HITCH.now()
	var prepared:Dictionary=_quote(name,selection,false,false,physical_id)
	HITCH.detail("card.ticket_preflight",measure)
	if not prepared.ok:return prepared
	var started:Dictionary=runtime._start()
	if not started.ok:return started
	measure=HITCH.now()
	prepared=quote(name,selection,true,physical_id)
	HITCH.detail("card.ticket_pool",measure)
	if not prepared.ok:runtime._busy=false;return prepared
	var rng:=RandomNumberGenerator.new()
	var previous:Dictionary=runtime.state.get("ticket_redemption",{})
	rng.state=int(previous.rng_state) if not previous.is_empty() else random.state
	var scratch=CardEngine.new();scratch.configure(runtime.world.catalog_db);scratch.import_state(runtime.world.card_draw_fusion.export_state())
	var drawn:Dictionary=draw(prepared,rng,scratch)
	if not drawn.ok:runtime._busy=false;return runtime.fail(str(drawn.reason)+" · 티켓/난수 보존")
	var results:Array=drawn.results
	var inventory:Dictionary=runtime.world.inventory.duplicate(true)
	var instances:Dictionary=runtime.world.item_instances.duplicate(true)
	var extra:Dictionary={"card_draw_fusion":scratch.export_state()}
	var debit:Dictionary=_native_debit(name,physical_id,int(prepared.source_item_id))
	if debit.has("ok") and not debit.ok:runtime._busy=false;return runtime.fail(str(debit.get("reason","원본 물리 티켓 차감 확인 필요"))+" · 티켓/난수 보존")
	if debit.get("ok",false):
		# A physical original ticket is debited through its own grant receipt.
		inventory=debit.overrides.inventory;instances=debit.overrides.item_instances;extra["consumable_state"]=debit.overrides.consumable_state
	else:
		inventory[name]=int(inventory[name])-1
		if int(inventory[name])==0:inventory.erase(name)
	var mileage:int=int(prepared.get("original_mileage",0))
	if mileage>0:inventory[PermanentMileage.WALLET]=int(inventory.get(PermanentMileage.WALLET,0))+mileage
	if prepared.category==SKILL_BOOKS:
		# Drawn skill cards arrive as their original skill book stacks.
		var counts:Dictionary={}
		for result:Dictionary in results:counts[int(result.item_class_id)]=int(counts.get(int(result.item_class_id),0))+1
		var grants:Array=[]
		for book:int in counts:grants.append({"item_class_id":book,"amount":int(counts[book]),"bless_raw":1,"enchant":0})
		var view:=STACK.SupplierView.new();view.host=runtime.world;view.inventory=inventory;view.item_instances=instances;view.gold=int(runtime.world.gold)
		var staged:Dictionary=load("res://scripts/loot/patch523_item_inventory.gd").stage(view,grants,{"kind":"source523_inventory_ticket_skill_card","ticket_item_class_id":int(prepared.source_item_id),"policy_sha256":loaded_sha})
		view.free()
		if not staged.get("ok",false):runtime._busy=false;return runtime.fail(str(staged.get("error","원본 스킬서 지급 후보 실패"))+" · 티켓/난수 보존")
		inventory=staged.overrides.inventory;instances=staged.overrides.item_instances
	var next:Dictionary=runtime.export_state()
	var uses:int=int(previous.get("uses",0))
	if uses>=runtime.LIMIT:runtime._busy=false;return runtime.fail("티켓 소비 이력 범위 초과")
	next["ticket_redemption"]={"version":1,"policy_sha256":loaded_sha,"rng_state":str(rng.state),"uses":uses+1}
	measure=HITCH.now()
	var saved:Dictionary=runtime._commit(next,inventory,int(runtime.world.gold),instances,int(runtime.world.next_item_instance_id),extra)
	HITCH.detail("card.ticket_commit",measure)
	if not saved.ok:return saved
	random.state=rng.state
	runtime.world.card_draw_fusion.import_state(scratch.export_state())
	# The full publication already invalidates/reconciles card-derived stats
	# and synchronously updates gameplay speed. Only bag presentation batches.
	measure=HITCH.now()
	if runtime.world.hud.has_method("publish_committed_ticket_hud"):
		runtime.world.hud.publish_committed_ticket_hud(runtime.world._update_hud)
	else:
		runtime.world._update_hud()
	HITCH.detail("card.ticket_hud_publish",measure)
	var outcome:Dictionary={"ok":true,"category":prepared.category,"results":results,"count":results.size(),"consumed":1,"inventory_key":name,"source_item_id":prepared.source_item_id,"message":"소지 티켓1개 소비 · 원본 가중치 %d회 추첨 · TWILIGHT 소지품 소비 정책" % results.size()}
	if mileage>0:
		outcome["mileage"]=mileage
		outcome.message+=" · 마일리지 +%d" % mileage
	if prepared.category==SKILL_BOOKS:
		var names:PackedStringArray=[]
		for result:Dictionary in results:names.append(str(result.name))
		outcome.message="소지 티켓1개 소비 · 원본 스킬 카드 %d회 추첨 · 원본 스킬서 지급: %s" % [results.size(),", ".join(names)]
		runtime.world.hud.refresh_inventory(runtime.world.inventory)
		runtime.world.hud.append_log(str(outcome.message))
		return outcome
	runtime.world.hud.set_card_draw_fusion_result(str(prepared.category),str(outcome.message))
	measure=HITCH.now()
	runtime.world.hud.present_card_reveal(str(prepared.category),outcome,false)
	HITCH.detail("card.ticket_reveal_setup",measure)
	return outcome

## Draws every grant of `prepared` ({grants, pools, category}) with `rng`
## into the scratch card engine: {ok, results} (skill cards as book rows).
func draw(prepared:Dictionary,rng:RandomNumberGenerator,scratch) -> Dictionary:
	var results:Array=[]
	for grant:Dictionary in prepared.grants:
		for count:int in range(int(grant.count)):
			var roll:int=rng.randi_range(1,1000000);var cursor:int=0;var chosen:Dictionary={}
			for candidate:Dictionary in prepared.pools[str(int(grant.pool_id))]:
				cursor+=int(candidate.weight)
				if roll<=cursor:chosen=candidate.entry;break
			if chosen.is_empty():return {"ok":false,"reason":"원본 추첨 구간 누락"}
			if chosen.get("kind")=="skill_book":
				results.append({"category":SKILL_BOOKS,"source_buff_card_id":int(chosen.spell_card_id),"item_class_id":int(chosen.item_class_id),"name":str(chosen.name)})
				continue
			if scratch.owned[str(prepared.category)].has(str(chosen.id)) and int(scratch.spare[str(prepared.category)].get(str(chosen.id),0))>=1000000:
				return {"ok":false,"reason":"중복 카드 저장 한도 초과"}
			var received:Dictionary=scratch._receive(str(prepared.category),chosen)
			received["source_buff_card_id"]=int(chosen.record.source_card_id)
			received["category"]=str(prepared.category)
			results.append(received)
	return {"ok":true,"results":results}

## The weighted entries of original pool `pool_id`: the ticket model's, else
## the market-only pool read whole from GotChaEntityView ([] when the pool is
## missing, mistyped, not totalling 1,000,000 or declared excluded).
func pool_entries(pool_id:int) -> Array:
	var key:String=str(pool_id)
	if document.get("pools",{}).get(key) is Array:return document.pools[key]
	if not market_pools.has(key):
		var input=OriginalInput.new()
		market_pools[key]=input._pool(pool_id)
	return market_pools[key]

## An original market draw offer (MarketProduct UnitID 35 = GotChaClassID, e.g.
## 상급 변신 뽑기 1회): `grants` [{product_id, pool_id, count}] are drawn from the
## same original pools and weights as an owned ticket of this model.
func market_draw_quote(grants:Array) -> Dictionary:
	if loaded_sha.is_empty() or not problem.is_empty():return runtime.fail(problem if not problem.is_empty() else "검증된 원본 뽑기 풀이 필요합니다")
	if runtime.world.hud.is_card_reveal_busy():return runtime.fail("카드 결과 연출 중입니다")
	var prior:Dictionary=runtime.state.get("ticket_redemption",{})
	if not prior.is_empty() and prior.get("policy_sha256")!=loaded_sha and prior.get("policy_sha256") not in PREVIOUS_POLICY_SHA256:return runtime.fail("뽑기 풀·정책 변경 감지 · 기존 정책 필요")
	var total:int=0
	for grant:Dictionary in grants:
		if pool_entries(int(grant.pool_id)).is_empty():return runtime.fail("원본 뽑기 풀 연결 없음 (%d)" % int(grant.pool_id))
		total+=int(grant.count)
	if total<1 or total>MAX_MARKET_DRAWS:return runtime.fail("한 번에 %d회까지 뽑을 수 있습니다" % MAX_MARKET_DRAWS)
	var drawn:Dictionary=_candidates(grants)
	if not drawn.ok:return drawn
	return {"ok":true,"grants":grants.duplicate(true),"pools":drawn.pools,"category":drawn.category,"count":drawn.count}

## Draws a paid market draw `plan` (market_draw_quote) on the shared ticket
## stream: {ok, results, card_state, inventory, item_instances, ticket_state}
## for the shop's one save, or the refusal (nothing changed).
func market_draw(plan:Dictionary,inventory:Dictionary,instances:Dictionary) -> Dictionary:
	var rng:=RandomNumberGenerator.new()
	var previous:Dictionary=runtime.state.get("ticket_redemption",{})
	rng.state=int(previous.rng_state) if not previous.is_empty() else random.state
	var scratch=CardEngine.new();scratch.configure(runtime.world.catalog_db);scratch.import_state(runtime.world.card_draw_fusion.export_state())
	var drawn:Dictionary=draw(plan,rng,scratch)
	if not drawn.ok:return runtime.fail(str(drawn.reason))
	if plan.category==SKILL_BOOKS:
		var counts:Dictionary={}
		for result:Dictionary in drawn.results:counts[int(result.item_class_id)]=int(counts.get(int(result.item_class_id),0))+1
		var books:Array=[]
		for book:int in counts:books.append({"item_class_id":book,"amount":int(counts[book]),"bless_raw":1,"enchant":0})
		var view:=STACK.SupplierView.new();view.host=runtime.world;view.inventory=inventory;view.item_instances=instances;view.gold=int(runtime.world.gold)
		var staged:Dictionary=load("res://scripts/loot/patch523_item_inventory.gd").stage(view,books,{"kind":"source523_market_draw_skill_card","policy_sha256":loaded_sha})
		view.free()
		if not staged.get("ok",false):return runtime.fail(str(staged.get("error","원본 스킬서 지급 후보 실패")))
		inventory=staged.overrides.inventory;instances=staged.overrides.item_instances
	var uses:int=int(previous.get("uses",0))
	if uses>=runtime.LIMIT:return runtime.fail("뽑기 이력 범위 초과")
	return {"ok":true,"results":drawn.results,"card_state":scratch.export_state(),"inventory":inventory,"item_instances":instances,"rng_state":rng.state,
		"ticket_state":{"version":1,"policy_sha256":loaded_sha,"rng_state":str(rng.state),"uses":uses+1}}

## After the shop saved a market draw: live card state, stream and the reveal.
func market_draw_presented(plan:Dictionary,outcome:Dictionary,name:String) -> String:
	random.state=int(outcome.rng_state)
	runtime.world.card_draw_fusion.import_state(outcome.card_state)
	runtime.world._invalidate_equipment_static();runtime.world.card_collections.invalidate()
	var results:Array=outcome.results
	if plan.category==SKILL_BOOKS:
		var names:PackedStringArray=[]
		for result:Dictionary in results:names.append(str(result.name))
		var line:String="%s · 원본 스킬 카드 %d회 추첨 · 원본 스킬서 지급: %s" % [name,results.size(),", ".join(names)]
		runtime.world.hud.append_log(line)
		return line
	var message:String="%s · 원본 가중치 %d회 추첨" % [name,results.size()]
	runtime.world.hud.set_card_draw_fusion_result(str(plan.category),message)
	runtime.world.hud.present_card_reveal(str(plan.category),{"ok":true,"category":plan.category,"results":results,"count":results.size(),"message":message},false)
	return message

## Select the exact physical slot before staging a draw. A missing or locked
## chosen receipt is a refusal, not permission to swap to an identically named
## stack. All sources of the same bag name keep their separate receipts.
func _selected_native_ticket(name:String,uid:String,item_id:int) -> Dictionary:
	var world:Node=runtime.world
	var entry:Variant=world.item_instances.get(uid)
	if not entry is Dictionary or entry.get("name")!=name or not entry.has(STACK.RECEIPT) or world._item_locked(name,uid):return {}
	var owned:Dictionary=STACK.proof(world,uid)
	if owned.get("receipt",{}).get("item_class_id")!=item_id:return {}
	return owned

func _stage_ticket(owned:Dictionary,uid:String) -> Dictionary:
	return STACK.stage_debit(runtime.world,[{"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt.duplicate(true)}])

## A name-only legacy caller may redeem an unlocked receipt from its own
## lane. It can fall back to legacy accounting only if there are no native
## receipts for that name at all (all-locked or invalid is a refusal).
func _native_debit(name:String,physical_id:String,item_id:int) -> Dictionary:
	if not physical_id.is_empty():
		var selected:Dictionary=_selected_native_ticket(name,physical_id,item_id)
		if selected.is_empty():return {"ok":false,"reason":"선택한 원본 티켓의 소유·수량·잠금 확인 필요"}
		return _stage_ticket(selected,physical_id)
	var contains_native:bool=false
	for uid:Variant in runtime.world.item_instances:
		var entry:Variant=runtime.world.item_instances[uid]
		if not entry is Dictionary or entry.get("name")!=name or not entry.has(STACK.RECEIPT):continue
		contains_native=true
		if runtime.world._item_locked(name,str(uid)):continue
		var owned:Dictionary=_selected_native_ticket(name,str(uid),item_id)
		if owned.is_empty():return {"ok":false,"reason":"원본 물리 소유·잔량 증명 불일치"}
		return _stage_ticket(owned,str(uid))
	return {"ok":false,"reason":"잠기지 않은 원본 물리 티켓이 없습니다"} if contains_native else {}

static func validate_state(value:Variant) -> String:
	if not value is Dictionary or value.get("version")!=1:return "티켓 소비 저장 버전 오류"
	var sha:Variant=value.get("policy_sha256");var rng:Variant=value.get("rng_state");var uses:Variant=value.get("uses")
	if not sha is String or sha.length()!=64 or not sha.is_valid_hex_number(false) or not rng is String or not rng.is_valid_int() or str(int(rng))!=rng or not (uses is int or uses is float) or not is_finite(float(uses)) or float(uses)!=floor(float(uses)) or int(uses)<0 or int(uses)>9007199254740991:return "티켓 소비 저장 형식 오류"
	return ""
