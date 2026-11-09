extends RefCounted
## Durable local transactions for source offers. No UI price or grant payload is trusted.
const Catalog = preload("res://scripts/shop/source523_shop_catalog.gd")
const CashMarket = preload("res://scripts/shop/source523_cash_market.gd")
const CashPackages = preload("res://scripts/shop/source523_cash_packages.gd")
const Economy = preload("res://scripts/shop/source523_shop_economy.gd")
const NpcDefinitions = preload("res://scripts/shop/source523_npc_definitions.gd")
const NpcConsumables = preload("res://scripts/shop/source523_npc_consumables.gd")
const InventoryTickets = preload("res://scripts/shop/source523_inventory_tickets.gd")
const SERVER_PROFILE = preload("res://scripts/loot/current523_server_profile.gd")
const SkillBooks = preload("res://scripts/shop/source523_skill_books.gd")
const NpcResets = preload("res://scripts/shop/source523_npc_resets.gd")
const Exact=preload("res://scripts/equipment523/native_catalog.gd")
const Dummy=preload("res://scripts/quests/source_dummy523.gd")
const SAVE_KEY: String = "source_shop"
const LIMIT: int = 9007199254740991
const ITEM_BINDINGS: Dictionary = {549:"드래곤의 다이아몬드",859:"전투 강화의 주문서 (각인)",2501:"마녀의 마력 회복제",6411:"갑옷 마법 주문서 (각인)",65291:"축복 부여 주문서 (각인)",3581:"축복 부여 주문서"}
const INTANGIBLE_BINDINGS: Dictionary = {2:"다이아",1:"마일리지"}
var world
## The original shop model is needed to install bindings at boot and while
## the shop is used; between uses it is released (Lineage M style) and any
## access to `catalog` reads it again.
var _catalog = null
var _catalog_released: bool = false
var catalog:
	get:
		if _catalog == null and _catalog_released:
			_catalog_released = false
			var source = Catalog.session()
			_catalog = source if source.available() else null
		return _catalog
	set(value):
		_catalog = value
		_catalog_released = false
var state: Dictionary = fresh_state()
var save_blocked: bool = false
var problem: String = ""
var _busy: bool = false
var _transaction_time: int = -1
var _bindings: Dictionary = {}
## Explicit adapters only. Missing server/calendar/price knowledge never grants access.
var server_context: Dictionary = {}
## Default calendar: Korea time with the 05:00 reset used everywhere else in
## TWILIGHT, so daily/weekly(Mon, Wed)/monthly purchase limits work without a
## policy file. A policy file can still override (null keeps limits locked).
const DEFAULT_CALENDAR_OFFSET_MINUTES: int = 540
const DEFAULT_PERIOD_RESET_HOUR: Dictionary = {"61":5,"71":5,"81":5,"11311":5}
var calendar_offset_minutes: Variant = DEFAULT_CALENDAR_OFFSET_MINUTES
var period_reset_hour: Dictionary = DEFAULT_PERIOD_RESET_HOUR.duplicate()
var daily_purchase_ids: Array[int] = []
var merchant_prices: Dictionary = {}
var merchant_economy: Dictionary = Economy.defaults()
var policy_sha256: String = ""
var npc_definitions = NpcDefinitions.new()
var npc_resets = NpcResets.new()
## Regression-only clock, like the existing test save writer; never supplied by UI.
var inventory_tickets = InventoryTickets.new()
var test_clock: Callable

static func fresh_state() -> Dictionary:
	return {"version":1,"revision":0,"next_order":1,"clock_highwater":0,"orders":{},"purchases":{},"cumulative":{}}

static func integer(value: Variant) -> bool:
	return Catalog._integer(value) and int(value) >= 0

static func input_identity_problem(value: Variant,model_sha256: String) -> String:
	if not value is Dictionary or value.get("payload_sha256")!=model_sha256 or not integer(value.get("payload_bytes")) or int(value.payload_bytes)<1:return "상점 주문의 실제 모델 입력 증명 불일치"
	if value.get("kind")=="twilight.source523.shop-pack-input.v1":
		return "" if value.get("declared_source_zip_sha256")==Catalog.SOURCE_SHA256 else "상점 주문의 원본 선언 불일치"
	if value.get("kind")!="twilight.source523.original-shop-input.v1":return "상점 입력 증명 종류 미지원"
	var archive: Variant=value.get("archive")
	if not archive is Dictionary or archive.get("kind")!="twilight.current523.original-definitions.v1" or archive.get("source_snapshot")!="patch523" or archive.get("source_sha256")!=Catalog.SOURCE_SHA256 or archive.get("source_bytes")!=25031173:return "상점 원본 ZIP 정체 불일치"
	return "" if value.get("projection")=="tools/shop/build_source523_shop.py" else "상점 원본 투영 계약 불일치"

static func npc_input_identity_problem(value: Variant,npc_sha256: String,shop_sha256: String) -> String:
	if not value is Dictionary or value.get("npc_model_sha256")!=npc_sha256 or value.get("shop_model_sha256")!=shop_sha256 or not integer(value.get("npc_model_bytes")) or int(value.npc_model_bytes)<1 or int(value.npc_model_bytes)>8*1024*1024:return "NPC 주문과 실제 NPC/상점 모델 입력 정체 불일치"
	if value.get("kind")=="twilight.source523.npc-original-input.v1":return "" if value.get("source_archive_sha256")==Catalog.SOURCE_SHA256 else "NPC 원본 입력 출처 불일치"
	if value.get("kind")=="twilight.source523.npc-pack-input.v1":return "" if value.get("declared_source_archive_sha256")==Catalog.SOURCE_SHA256 else "NPC 팩 입력 출처 불일치"
	return "NPC 입력 증명 종류 미지원"

static func validate(value: Variant) -> String:
	if not value is Dictionary or value.get("version") != 1: return "상점 저장 버전 오류"
	if value.has("ticket_redemption"):
		var ticket_error: String=InventoryTickets.validate_state(value.ticket_redemption)
		if not ticket_error.is_empty():return ticket_error
	if value.has("policy_sha256") and (not value.policy_sha256 is String or (not value.policy_sha256.is_empty() and (value.policy_sha256.length()!=64 or not value.policy_sha256.is_valid_hex_number(false)))):return "상점 저장 정책 해시 오류"
	if value.has("npc_rule_hashes"):
		if not value.npc_rule_hashes is Dictionary:return "NPC 자체 규칙 저장 형식 오류"
		for id: Variant in value.npc_rule_hashes:
			var hash_value: Variant=value.npc_rule_hashes[id]
			if not id is String or not id.is_valid_int() or int(id)<1 or str(int(id))!=id or not hash_value is String or hash_value.length()!=64 or not hash_value.is_valid_hex_number(false):return "NPC 자체 규칙 저장 해시 오류"
	if value.has("npc_reset_rule_hashes"):
		if not value.npc_reset_rule_hashes is Dictionary:return "NPC 초기화 저장 형식 오류"
		for key: Variant in value.npc_reset_rule_hashes:
			var identity: Variant=value.npc_reset_rule_hashes[key]
			if not key is String or not key.begins_with("merchant:") or key.length()>256 or not identity is String or identity.length()!=64 or not identity.is_valid_hex_number(false):return "NPC 초기화 저장 해시 오류"
	for key: String in ["revision","next_order","clock_highwater"]:
		if not integer(value.get(key)): return "상점 저장 정수 오류: " + key
	if int(value.next_order) < 1: return "상점 주문 번호 오류"
	for key: String in ["orders","purchases","cumulative"]:
		if not value.get(key) is Dictionary: return "상점 저장 항목 오류: " + key
	var highest: int = 0
	for id: Variant in value.orders:
		if not id is String or not id.is_valid_int() or str(int(id)) != id or int(id) < 1: return "상점 주문 ID 오류"
		highest = maxi(highest, int(id))
		var order: Variant = value.orders[id]
		if not order is Dictionary or order.get("status") not in ["pending","claimed"]: return "상점 주문 상태 오류"
		for key: String in ["offer_id","quantity","paid_at","claimed_at"]:
			if not integer(order.get(key)): return "상점 주문 수치 오류"
		if int(order.quantity) < 1 or int(order.quantity) > 1000 or order.get("kind") not in ["market","merchant"]: return "상점 주문 종류 오류"
		for key: String in ["npc_rules_sha256","npc_pack_sha256","npc_reset_identity"]:
			if order.has(key) and (not order[key] is String or order[key].length()!=64 or not order[key].is_valid_hex_number(false)):return "NPC 주문 출처 해시 오류"
		if not order.get("pack_sha256") is String or order.pack_sha256.length() != 64 or not order.pack_sha256.is_valid_hex_number(false): return "상점 주문 원본 해시 오류"
		if order.has("source_input_identity"):
			var input_error: String=input_identity_problem(order.source_input_identity,str(order.pack_sha256))
			if not input_error.is_empty():return input_error
		if order.has("source_npc_input_identity"):
			if order.get("kind")!="merchant" or not integer(order.get("npc_merchant_id")) or int(order.npc_merchant_id)<1:return "NPC 주문의 상인 정체 누락"
			var npc_input_error: String=npc_input_identity_problem(order.source_npc_input_identity,str(order.get("npc_pack_sha256","")),str(order.pack_sha256))
			if not npc_input_error.is_empty():return npc_input_error
		if order.has("received_physical_ids"):
			if not order.received_physical_ids is Array:return "상점 수령 개체 목록 형식 오류"
			var seen: Dictionary={}
			for physical_id: Variant in order.received_physical_ids:
				if not physical_id is String or physical_id.is_empty() or seen.has(physical_id):return "상점 수령 개체 식별 오류"
				seen[physical_id]=true
		if not order.get("goods") is Array or order.goods.is_empty() or not order.get("payment") is Dictionary: return "상점 주문 지급·결제 오류"
		for grant: Variant in order.goods + [order.payment]:
			if not grant is Dictionary: return "상점 주문 재화 오류"
			for key: String in ["unit_id","class_id","amount"]:
				if not integer(grant.get(key)): return "상점 주문 재화 수치 오류"
			if int(grant.amount) < 1: return "상점 주문 수량 오류"
		if order.status == "pending" and int(order.claimed_at) != 0: return "미수령 주문의 수령 시각 오류"
		if order.status == "claimed" and int(order.claimed_at) < int(order.paid_at): return "상점 주문 시각 오류"
	if int(value.next_order) <= highest: return "상점 주문 번호 재사용 오류"
	for key: Variant in value.purchases:
		if not key is String or not value.purchases[key] is Array: return "상점 구매 이력 오류"
		for entry: Variant in value.purchases[key]:
			if not entry is Dictionary or not integer(entry.get("at")) or not integer(entry.get("quantity")) or int(entry.quantity) < 1: return "상점 구매 이력 수량 오류"
	for key: Variant in value.cumulative:
		var event: Variant = value.cumulative[key]
		if not key is String or not event is Dictionary or not event.get("days") is Dictionary or not event.get("claims") is Dictionary: return "누적 보상 저장 오류"
		for day: Variant in event.days:
			if not day is String or event.days[day] != true: return "누적 보상 활성화 오류"
		for claim: Variant in event.claims:
			if not claim is String or event.claims[claim] != true: return "누적 보상 수령 오류"
	return ""

func configure(host: Node) -> void:
	world = host
	# This currency uses the real inventory/save path, never a parallel wallet.
	for name: String in INTANGIBLE_BINDINGS.values():
		if not world._find_catalog_item_record(name).is_empty(): continue
		var record: Dictionary = {"name":name,"grade":"일반","slot":"currency","type":"화폐","weight":0,"droppable":false,"sellable":false,"stackable":true,"desc":"보유 재화"}
		world.item_db.append(record.duplicate(true))
		world.catalog_db["아이템"].append(record)
	world._index_item_weights()
	var configured_source=Catalog.session()
	if configured_source.available():
		bind_source(configured_source)
		release_catalog()

## Releases the original shop model until the shop is used again.
func release_catalog() -> void:
	if _busy or _catalog == null: return
	_catalog = null
	_catalog_released = true
	Catalog.release()

func bind_source(source) -> void:
	if catalog == source and not _bindings.is_empty(): return
	catalog = source
	_bindings.clear()
	if catalog == null or not catalog.available(): return
	for row: Dictionary in world.catalog_db.get("아이템", []):
		var raw_id: String = str(row.get("sourceId", ""))
		if row.get("source") != "inven" or not raw_id.is_valid_int(): continue
		var id: int = int(raw_id)
		var original: Dictionary = catalog.record("ItemClass", id)
		if original.is_empty() or catalog.label(int(original.DescID)) != str(row.get("name", "")): continue
		var key: String = "4:%d" % id
		if _bindings.has(key): _bindings[key] = {}; continue
		_bindings[key] = {"name":str(row.name),"record":row.duplicate(true)}
	for id: int in ITEM_BINDINGS:
		var name: String = ITEM_BINDINGS[id]
		var original: Dictionary = catalog.record("ItemClass", id)
		if original.is_empty() or catalog.label(int(original.DescID)) != name: continue
		var row: Dictionary = world._find_catalog_item_record(name)
		if not row.is_empty(): _bindings["4:%d" % id] = {"name":name,"record":row.duplicate(true)}
	for id: int in INTANGIBLE_BINDINGS:
		if catalog.record("IntangibleItemClass", id).is_empty(): continue
		var name: String = INTANGIBLE_BINDINGS[id]
		_bindings["34:%d" % id] = {"name":name,"record":world._find_catalog_item_record(name).duplicate(true)}
	_bindings["4:26"] = {"gold":true,"name":"아데나"}
	_bindings.merge(NpcConsumables.install(world,catalog))
	_bindings.merge(SkillBooks.install(world,catalog))
	_bindings.merge(preload("res://scripts/shop/source523_wisdom.gd").install(world,catalog))
	_bindings.merge(preload("res://scripts/shop/source523_ammo.gd").install(world,catalog))
	_bindings.merge(preload("res://scripts/shop/source523_restoration.gd").install(world,catalog))
	_bindings.merge(CashPackages.install(world,catalog))
	inventory_tickets.configure(self)
	_bindings.merge(inventory_tickets.install())
	npc_definitions.configure(catalog)
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--source523-shop-policy="): continue
		var expected: String = ""
		for option: String in OS.get_cmdline_user_args():
			if option.begins_with("--source523-shop-policy-sha256="): expected = option.trim_prefix("--source523-shop-policy-sha256=")
		var loaded: Dictionary = load_policy(arg.trim_prefix("--source523-shop-policy="), expected)
		if not loaded.ok: problem = str(loaded.reason)

func item_references(item_id: int) -> Dictionary:
	var source = catalog if catalog != null else Catalog.session()
	if not source.has_method("item_references"):
		return {"item_id":item_id,"unavailable":true,"reference_only":true,"can_purchase":false}
	return source.item_references(item_id)

func _source_item_identity(item_id: int) -> Dictionary:
	if catalog.has_method("item_identity"): return catalog.item_identity(item_id)
	# Preserve the existing contract for an older supplied catalog adapter.
	return {"item_class":catalog.record("ItemClass",item_id),"source_available":false,
		"reference_only":true,"can_activate":false}

func load_policy(path: String, expected_sha: String) -> Dictionary:
	if expected_sha.length()!=64 or not expected_sha.is_valid_hex_number(false) or not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=expected_sha.to_lower(): return fail("상점 정책 파일의 해시 확인 실패")
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>1024*1024: return fail("상점 정책 파일 크기·접근 오류")
	var parser:=JSON.new()
	if parser.parse(file.get_as_text())!=OK or not parser.data is Dictionary: return fail("상점 정책 JSON 오류")
	var policy: Dictionary=parser.data
	if policy.get("schema")!="twilight.source523.shop-policy.v1" or policy.get("pack_sha256")!=catalog.loaded_sha256: return fail("상점 정책의 원본 팩 불일치")
	var offset: Variant=policy.get("calendar_offset_minutes",DEFAULT_CALENDAR_OFFSET_MINUTES)
	if offset!=null and (not Catalog._integer(offset) or int(offset)<-840 or int(offset)>840): return fail("상점 정책의 시간 기준 오류")
	for key: String in ["server_context","period_reset_hour","merchant_prices"]:
		if not policy.get(key,{}) is Dictionary:return fail("상점 정책 항목 오류: "+key)
	var context: Dictionary=policy.get("server_context",{})
	if not context.is_empty() and (not integer(context.get("world_no")) or not context.get("region") is String or context.region.is_empty()):return fail("원본 서버 정책 형식 오류")
	var economy: Variant=policy.get("merchant_economy",Economy.defaults())
	if not economy is Dictionary:return fail("자체 NPC 가격 정책 형식 오류")
	var economic_error: String=Economy.validate(economy)
	if not economic_error.is_empty():return fail(economic_error)
	var npc_rules: Variant=policy.get("npc_local_rules",npc_definitions.rules)
	var npc_rule_error: String=NpcDefinitions.validate_rules(npc_rules)
	if not npc_rule_error.is_empty():return fail(npc_rule_error)
	var npc_reset_rules: Variant=policy.get("npc_reset_rules",npc_resets.rules)
	var npc_reset_error: String=NpcResets.validate(npc_reset_rules)
	if not npc_reset_error.is_empty():return fail(npc_reset_error)
	for id: Variant in policy.get("merchant_prices",{}):
		var profile: Variant=policy.merchant_prices[id]
		if not id is String or not id.is_valid_int() or catalog.merchant_offer(int(id)).is_empty() or not profile is Dictionary or profile.get("goods_sha256")!=merchant_signature(int(id)):return fail("NPC 정책의 원본 판매행 불일치")
		if profile.has("amount"):
			for key: String in ["amount","unit_id","class_id"]:
				if not integer(profile.get(key)):return fail("NPC 명시 가격 정책 오류")
			if not profile.get("origin") is String or profile.origin.is_empty():return fail("NPC 명시 가격의 출처 필요")
	if not policy.get("daily_purchase_ids",[]) is Array:return fail("일일 대상 상품 정책 오류")
	for id: Variant in policy.get("daily_purchase_ids",[]):
		if not integer(id) or catalog.market_offer(int(id)).is_empty(): return fail("일일 대상 상품 연결 오류")
	for key: Variant in policy.get("period_reset_hour",{}):
		if not key is String or key not in ["61","71","81","11311"] or not integer(policy.period_reset_hour[key]) or int(policy.period_reset_hour[key])>23:return fail("구매 한도 초기화 정책 오류")
	server_context=policy.get("server_context",{}).duplicate(true)
	calendar_offset_minutes=offset
	period_reset_hour=DEFAULT_PERIOD_RESET_HOUR.duplicate()
	period_reset_hour.merge(policy.get("period_reset_hour",{}),true)
	daily_purchase_ids.clear()
	for id: Variant in policy.get("daily_purchase_ids",[]):daily_purchase_ids.append(int(id))
	merchant_prices=policy.get("merchant_prices",{}).duplicate(true)
	merchant_economy=economy.duplicate(true)
	npc_definitions.rules=npc_rules.duplicate(true)
	npc_resets.rules=npc_reset_rules.duplicate(true)
	policy_sha256=expected_sha.to_lower()
	problem=""
	return {"ok":true}

func export_state() -> Dictionary:
	return state.duplicate(true)

func check_load(data: Dictionary) -> String:
	return validate(data.get(SAVE_KEY, fresh_state()))

func prepare_load(data: Dictionary, path: String, expected_sha: String) -> String:
	if data.has(SAVE_KEY) or not FileAccess.file_exists(path): return ""
	var backup: String = path + ".pre-source-shop-" + expected_sha
	if FileAccess.get_sha256(path) != expected_sha: return "상점 저장 이전 중 원본 변경 감지"
	if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(path, backup) != OK: return "상점 저장 이전 백업 실패 · 원본 보존"
	if FileAccess.get_sha256(backup) != expected_sha: return "상점 저장 이전 백업 해시 오류"
	return ""

func accept_load(data: Dictionary) -> void:
	state = data.get(SAVE_KEY, fresh_state()).duplicate(true)
	save_blocked = false

func _now() -> int:
	if _busy and _transaction_time >= 0: return _transaction_time
	return int(test_clock.call()) if test_clock.is_valid() else int(Time.get_unix_time_from_system())

static func fail(message: String) -> Dictionary:
	return {"ok":false,"reason":message,"can_purchase":false}

func _ready_for_action(internal: bool = false) -> Dictionary:
	if _busy and not internal: return fail("이전 상점 거래 처리 중입니다")
	if not str(world.get("patch523_owner_state_problem")).is_empty():return fail("공동 저장 결과 확인 필요 · 정상 저장을 다시 불러오세요")
	if not integer(world.gold): return fail("현재 재화 저장 수치가 유효하지 않습니다")
	for amount: Variant in world.inventory.values():
		if not integer(amount): return fail("현재 인벤토리 저장 수치가 유효하지 않습니다")
	if not problem.is_empty():return fail(problem)
	if save_blocked or not validate(state).is_empty(): return fail("상점 저장 보호 중 · 정상 저장을 다시 불러오세요")
	if not str(state.get("policy_sha256", "")).is_empty() and str(state.policy_sha256)!=policy_sha256: return fail("구매·초기화 정책이 변경됐습니다 · 기존 정책으로 확인 필요")
	if catalog == null or not catalog.available(): return fail("검증된 원본 상점 팩이 필요합니다")
	if _now() < int(state.clock_highwater): return fail("시계 역행 감지 · 마지막 거래 시각 이후에 다시 시도하세요")
	return {"ok":true}

func _date(row: Dictionary) -> int:
	if row.is_empty(): return -1
	return int(Time.get_unix_time_from_datetime_dict({"year":int(row.Year),"month":int(row.Month),"day":int(row.Day),"hour":int(row.Hour),"minute":int(row.Minute),"second":0}))

func _window(start: Dictionary, end: Dictionary) -> Dictionary:
	var first: int = _date(start)
	var last: int = _date(end)
	if first < 0 or last <= first: return fail("판매 기간 연결 오류")
	var now: int = _now()
	if calendar_offset_minutes != null:
		now += int(calendar_offset_minutes) * 60
		return {"ok":true} if now >= first and now < last else fail("판매·행사 기간이 아닙니다")
	# With no source timezone contract, only a point far inside the common
	# interval can authorize a purchase. Near-boundary offers stay locked.
	if now < first - 172800 or now >= last + 172800: return fail("판매·행사 기간이 아닙니다")
	if now < first + 172800 or now >= last - 172800: return fail("원본 시간대 미확정 · 기간 경계 구매 대기")
	return {"ok":true}

## An explicit policy server context wins; otherwise the shared item server
## profile (declared card-collection context, else offline Korean world 1).
func effective_server_context() -> Dictionary:
	if server_context.has("world_no") and server_context.has("region"): return server_context
	var current: Dictionary = SERVER_PROFILE.profile(world)
	return {"region":str(current.ServiceRegionCode),"world_no":int(current.WorldNo),"origin":"twilight_offline_server_profile"}

func _server(sets: Array) -> Dictionary:
	if sets.is_empty(): return {"ok":true}
	var context: Dictionary = effective_server_context()
	for set: Variant in sets:
		if not SERVER_PROFILE.rows_allow(catalog._related("ServerLimit", int(set)), str(context.region), int(context.world_no)): return fail("서버 조건 미충족 또는 미해석 서버세트")
	return {"ok":true}

func _period(unit: int, at: int, reset: int, offset: Variant = null) -> String:
	if unit == 111: return "lifetime"
	if offset == null: offset = calendar_offset_minutes
	if offset == null: return ""
	var day_seconds: int = 86400
	var shifted: int = at + int(offset) * 60 - reset * 3600
	var day: int = floori(float(shifted) / day_seconds)
	var date: Dictionary = Time.get_datetime_dict_from_unix_time(shifted)
	match unit:
		61: return str(day)
		71: return str(day - posmod(int(date.weekday) - 1, 7))
		11311: return str(day - posmod(int(date.weekday) - 3, 7))
		81: return "%04d-%02d" % [date.year,date.month]
	return ""

func _restrictions(id: int, rows: Array, quantity: int, counter_key: String = "") -> Dictionary:
	for row: Dictionary in rows:
		if int(row.ValueUnitId) != 1: return fail("구매 제한의 값 단위 미해석")
		if int(row.MarketRestrictionTypeId) == 5:
			if int(world.level) < int(row.Value): return fail("구매 레벨이 부족합니다")
		elif int(row.MarketRestrictionTypeId) == 3:
			if int(row.DurationValue) != 1: return fail("구매 제한 기간 배수 미해석")
			var unit: int = int(row.DurationUnitId)
			# Converted cash offers use TWILIGHT's offline default (05:00 KST) unless
			# an explicit policy supplies the reset; other offers stay fail-closed.
			var cash: bool = counter_key.is_empty() and CashMarket.listed(id)
			var reset: int = int(period_reset_hour.get(str(unit), CashMarket.RESET_HOUR if cash else 0))
			var offset: Variant = calendar_offset_minutes if calendar_offset_minutes != null or not cash else CashMarket.CALENDAR_OFFSET_MINUTES
			if unit != 111 and not period_reset_hour.has(str(unit)) and not cash: return fail("구매 한도 초기화 시각 미확정")
			var bucket: String = _period(unit, _now(), reset, offset)
			if bucket.is_empty(): return fail("구매 한도 시간 기준 미확정")
			var count: int = 0
			for purchase: Dictionary in state.purchases.get(counter_key if not counter_key.is_empty() else str(id), []):
				if _period(unit, int(purchase.at), reset, offset) == bucket: count += int(purchase.quantity)
			if count + quantity > int(row.Value): return fail("계정 구매 한도를 초과합니다")
		else:
			return fail("미해석 구매 제한 · 유형 %d" % int(row.MarketRestrictionTypeId))
	return {"ok":true}

func _token(unit: int, id: int, amount: int) -> Dictionary:
	return {"unit_id":unit,"class_id":id,"amount":amount}

func _resolve(token: Dictionary, giving: bool, inventory: Dictionary, gold: int) -> Dictionary:
	if int(token.unit_id)==4:
		var original: Dictionary=catalog.record("ItemClass",int(token.class_id))
		var package: bool=giving and original.get("TestItem",false) and CashPackages.is_package(int(token.class_id))
		if original.is_empty() or (original.get("TestItem",false) and not package) or not Dummy.item_evidence(original).is_empty():return fail("미확인·시험·원본 더미 품목은 상점 지급·차감 연결에서 제외")
	if int(token.unit_id) != 201:
		var binding: Dictionary = _bindings.get("%d:%d" % [int(token.unit_id),int(token.class_id)], {})
		if not binding.is_empty() and not binding.get("gold",false):
			var name: String=str(binding.get("name",""))
			var physical_output: bool=giving and not world._enhancement_kind_for_record(binding.get("record",{})).is_empty()
			if not physical_output:
				for value: Variant in world.item_instances.values():
					if value is Dictionary and value.get("name")==name:return fail("같은 보유 키의 물리 개체·소비 영수증 소유자 연결 필요 · 상점 잔량 보존")
		return {"ok":true,"binding":binding} if not binding.is_empty() else fail("아이템·재화의 실제 인벤토리 연결 미확인")
	var currency: Dictionary = catalog.currency(int(token.class_id))
	if currency.is_empty(): return fail("재화 정의 누락")
	var candidates: Array = currency.for_give if giving else currency.sources
	if giving and candidates.size() != 1: return fail("재화 지급용 원천이 없거나 유일하지 않습니다")
	var funded: Array = []
	for source: Dictionary in candidates:
		if int(source.UnitID) not in [4,34]:
			if giving: return fail("재화 원천 단위 미해석")
			continue
		var resolved: Dictionary = _resolve(_token(int(source.UnitID),int(source.ClassID),int(token.amount)), giving, inventory, gold)
		if not resolved.ok:
			if giving: return resolved
			continue
		var binding: Dictionary = resolved.binding
		var balance: int = gold if binding.get("gold", false) else int(inventory.get(str(binding.name), 0))
		if giving: return resolved
		if balance > 0: funded.append({"binding":binding,"balance":balance})
	if funded.size() > 1: return fail("여러 재화 원천의 소모 우선순위 미확정")
	if funded.is_empty() or int(funded[0].balance) < int(token.amount): return fail("구매 재화가 부족합니다")
	return {"ok":true,"binding":funded[0].binding}

func _products(offer: Dictionary, quantity: int) -> Dictionary:
	var goods: Array = []
	var source_items: Dictionary = {}
	var cash: bool = CashMarket.listed(int(offer.purchase.get("ID", 0)))
	for link: Dictionary in offer.products + offer.bonuses:
		var product: Dictionary = link.product.definition
		# User decision: diamonds inside a converted cash offer are not granted.
		if cash and CashMarket.strip(int(offer.purchase.ID), product): continue
		if product.is_empty() or not link.product.additional.is_empty() or product.get("ClassChangeDiscount", false): return fail("지급 상품의 추가 조건 미해석")
		var multiplied: Dictionary = Catalog._checked_product([product.get("Amount", -1), quantity])
		if not multiplied.ok or int(multiplied.value) < 1: return fail("상품 지급 수량 오류")
		var token: Dictionary = _token(int(product.UnitID),int(product.ClassID),int(multiplied.value))
		if int(token.unit_id) == 4:
			var identity: Dictionary = _source_item_identity(int(token.class_id))
			if identity.get("excluded") == true and not (cash and CashPackages.is_package(int(token.class_id))): return fail("원본 아이템 선언으로 제외된 상품입니다")
			source_items[str(int(token.class_id))] = identity
			var item: Dictionary = catalog.record("ItemClass", int(token.class_id))
			var original_name: String = str(item.get("Name", ""))
			var package: bool = cash and CashPackages.is_package(int(token.class_id))
			# Cash package boxes carry the original BM deletion note in their internal
			# name; offline TWILIGHT keeps them (see source523_cash_packages.gd).
			if (item.get("TestItem", false) and not package) or (not package and (original_name.contains("삭제") or original_name.contains("기간") or original_name.contains("이벤트"))):
				return fail("테스트·기간제 상품의 사용·만료 조건 미확인")
		var resolved: Dictionary = _resolve(token, true, world.inventory, int(world.gold))
		if not resolved.ok: return resolved
		if resolved.binding.get("name")=="드래곤의 용옥":return fail("드래곤의 용옥은 기존 전용 상점의 월 1회·가격 규칙을 이용하세요")
		goods.append(token)
	if goods.is_empty(): return fail("지급 상품이 없습니다")
	return {"ok":true,"goods":goods,"source_items":source_items}

func quote(id: int, quantity: int = 1) -> Dictionary:
	return _quote(id, quantity, false)

func _quote(id: int, quantity: int, internal: bool) -> Dictionary:
	var ready: Dictionary = _ready_for_action(internal)
	if not ready.ok: return ready
	var offer: Dictionary = catalog.market_offer(id)
	if offer.is_empty() or offer.purchase.get("OnSale") != true or offer.displays.is_empty(): return fail("현재 판매·진열 중인 상품이 아닙니다")
	# Converted cash offers (user decision: all of them) are sold in TWILIGHT's
	# single offline world regardless of the original store server group/period.
	var cash: bool = CashMarket.listed(id)
	if not cash:
		var window: Dictionary = _window(offer.effective_from, offer.effective_to)
		if not window.ok: return window
		var sets: Array = []
		for row: Dictionary in offer.server_limits: sets.append(int(row.ServerLimitSetID))
		var server: Dictionary = _server(sets)
		if not server.ok: return server
	var restrictions: Dictionary = _restrictions(id, offer.restrictions, quantity)
	if not restrictions.ok: return restrictions
	var price: Dictionary = catalog.payment_quote(id, quantity)
	if not price.get("ok", false) or int(price.get("total", 0)) <= 0: return fail(str(price.get("reason", "외부 결제·쿠폰 상품은 구매할 수 없습니다")))
	var payment: Dictionary = _token(int(price.unit_id),int(price.class_id),int(price.total))
	var debit: Dictionary = _resolve(payment, false, world.inventory, int(world.gold))
	if not debit.ok: return debit
	var binding: Dictionary = debit.binding
	if binding.get("gold", false):
		if int(world.gold) < int(payment.amount): return fail("구매 아데나가 부족합니다")
	else:
		if int(world.inventory.get(str(binding.name), 0)) < int(payment.amount): return fail("구매 재화가 부족합니다")
		if not world._enhancement_kind_for_record(binding.get("record", {})).is_empty(): return fail("장비 개체를 결제 재료로 사용할 수 없습니다")
		if world._item_locked(str(binding.name), ""): return fail("잠긴 결제 재료입니다")
	var goods: Dictionary = _products(offer, quantity)
	if not goods.ok: return goods
	return {"ok":true,"can_purchase":true,"offer_id":id,"quantity":quantity,"name":offer.name,"payment":payment,"payment_binding":binding,"goods":goods.goods,
		"source_reference":{"items":goods.source_items,"purchase":offer.purchase,"restrictions":offer.restrictions,"server_limits":offer.server_limits,"reference_only":true,"can_purchase":false}}

func _start() -> Dictionary:
	var ready: Dictionary = _ready_for_action()
	if not ready.ok: return ready
	_transaction_time = _now()
	_busy = true
	# Finish an existing map-save migration before staging a paid transaction.
	if not world.pending_map_save_record.is_empty() and world._save_game(true) != OK:
		_busy = false
		return fail("이전 저장 활성화 실패 · 구매하지 않았습니다")
	return {"ok":true}

func _commit(next: Dictionary, inventory: Dictionary, gold: int, instances: Dictionary, next_instance: int, extra: Dictionary = {}) -> Dictionary:
	if not integer(gold) or next_instance < 1 or next_instance > LIMIT:
		_busy = false
		return fail("거래 후 재화·장비 번호 범위 오류")
	next.clock_highwater = maxi(int(next.clock_highwater), _now())
	next.revision = int(next.revision) + 1
	next["policy_sha256"]=policy_sha256
	var error: String = validate(next)
	if not error.is_empty(): _busy = false; return fail(error)
	for key: String in extra:
		if key not in ["card_draw_fusion","consumable_state"]:_busy=false;return fail("미지원 티켓 원자 저장 필드")
	var overrides: Dictionary={SAVE_KEY:next,"inventory":inventory,"gold":gold,"item_instances":instances,"next_item_instance_id":next_instance}
	overrides.merge(extra,false)
	var result: Error = world._save_game(true, overrides)
	if result != OK:
		# A response error may follow an atomic disk commit or map-pointer
		# write. Do not issue another purchase from stale live order balances.
		save_blocked=true
		_busy = false
		return fail("상점 저장 응답 확인 필요 · 라이브 재화 보존, 정상 저장을 다시 불러온 뒤 거래하세요")
	state = next
	world.inventory = inventory
	world.gold = gold
	world.item_instances = instances
	world.next_item_instance_id = next_instance
	# A physical original ticket's use ledger was saved with the same commit.
	if extra.has("consumable_state"): world.consumable_service.import_state(extra.consumable_state)
	_busy = false
	return {"ok":true}

func buy(id: int, quantity: int = 1) -> Dictionary:
	var prepared: Dictionary = quote(id, quantity)
	if not prepared.ok: return prepared
	var started: Dictionary = _start()
	if not started.ok: return started
	# _start can commit a migration. Re-read all authoritative values afterward.
	prepared = _quote(id, quantity, true)
	if not prepared.ok: _busy = false; return prepared
	return _purchase(prepared, "market", str(id))

func _purchase(prepared: Dictionary, kind: String, counter_key: String) -> Dictionary:
	var id: int = int(prepared.offer_id)
	var quantity: int = int(prepared.quantity)
	var inventory: Dictionary = world.inventory.duplicate(true)
	var gold: int = int(world.gold)
	var binding: Dictionary = prepared.payment_binding
	if binding.get("gold", false): gold -= int(prepared.payment.amount)
	else:
		var name: String = str(binding.name)
		inventory[name] = int(inventory.get(name, 0)) - int(prepared.payment.amount)
		if int(inventory[name]) == 0: inventory.erase(name)
	var next: Dictionary = export_state()
	var order_id: String = str(int(next.next_order))
	next.next_order = int(next.next_order) + 1
	next.orders[order_id] = {"kind":kind,"display_name":str(prepared.name),"offer_id":id,"quantity":quantity,"status":"pending","paid_at":_now(),"claimed_at":0,"payment":prepared.payment.duplicate(true),"goods":prepared.goods.duplicate(true),"pack_sha256":catalog.loaded_sha256}
	var input: Variant=catalog.get("model_input_identity")
	if input is Dictionary and not input.is_empty():
		var input_error: String=input_identity_problem(input,str(catalog.loaded_sha256))
		if not input_error.is_empty():_busy=false;return fail(input_error)
		next.orders[order_id]["source_input_identity"]=input.duplicate(true)
	if prepared.has("npc_rules_sha256"):
		if not next.has("npc_rule_hashes"):next["npc_rule_hashes"]={}
		next.npc_rule_hashes[str(int(prepared.npc_merchant_id))]=str(prepared.npc_rules_sha256)
		next.orders[order_id]["npc_rules_sha256"]=str(prepared.npc_rules_sha256)
		next.orders[order_id]["npc_pack_sha256"]=str(prepared.npc_pack_sha256)
		next.orders[order_id]["rule_origin"]=str(prepared.rule_origin)
		if prepared.has("source_npc_input_identity"):
			var npc_input_error: String=npc_input_identity_problem(prepared.source_npc_input_identity,str(prepared.npc_pack_sha256),str(catalog.loaded_sha256))
			if not npc_input_error.is_empty():_busy=false;return fail(npc_input_error)
			next.orders[order_id]["npc_merchant_id"]=int(prepared.npc_merchant_id)
			next.orders[order_id]["source_npc_input_identity"]=prepared.source_npc_input_identity.duplicate(true)
	if prepared.has("npc_reset_identity"):
		if not next.has("npc_reset_rule_hashes"):next["npc_reset_rule_hashes"]={}
		next.npc_reset_rule_hashes[counter_key]=str(prepared.npc_reset_identity)
		next.orders[order_id]["npc_reset_identity"]=str(prepared.npc_reset_identity)
	if not next.purchases.has(counter_key): next.purchases[counter_key] = []
	next.purchases[counter_key].append({"at":_now(),"quantity":quantity})
	var result: Dictionary = _commit(next, inventory, gold, world.item_instances.duplicate(true), int(world.next_item_instance_id))
	if result.ok: result.merge({"order_id":order_id,"name":prepared.name,"quantity":quantity,"reason":"구매 완료 · 보관함에서 수령하세요"})
	return result

func merchant_signature(id: int) -> String:
	var offer: Dictionary=catalog.merchant_offer(id)
	return JSON.stringify(offer.get("goods",{}),"",true,true).sha256_text()

func merchant_price(id: int) -> Dictionary:
	var offer: Dictionary=catalog.merchant_offer(id)
	if offer.is_empty():return fail("NPC 판매행 없음")
	var profile: Variant=merchant_prices.get(str(id),{})
	if not profile is Dictionary:return fail("NPC 가격 정책 형식 오류")
	if not profile.is_empty() and profile.get("goods_sha256")!=merchant_signature(id):return fail("NPC 정책의 원본 판매행 불일치")
	if profile.has("amount"):
		for key: String in ["unit_id","class_id","amount"]:
			if not integer(profile.get(key)) or int(profile.amount)<1:return fail("NPC 명시 가격 정책 오류")
		if not profile.get("origin") is String or profile.origin.is_empty():return fail("NPC 명시 가격의 출처 필요")
		return {"ok":true,"unit_id":int(profile.unit_id),"class_id":int(profile.class_id),"amount":int(profile.amount),"origin":str(profile.origin),"reference_url":str(profile.get("reference_url",""))}
	var price: Dictionary=Economy.price(offer.item,offer.goods,merchant_economy)
	var source_currency: int=npc_definitions.currency_for(int(offer.goods.MerchantsID))
	if price.ok and source_currency>0 and not catalog.record("Currency",source_currency).is_empty():
		price.unit_id=201
		price.class_id=source_currency
		price.origin=str(price.origin)+" · 원본 NPC 재화"
	return price

func npc_label(merchant_id: int) -> String:
	if npc_definitions.loaded_sha256.is_empty():return ""
	return str(npc_definitions.rule_for(merchant_id).get("label",""))

func quote_merchant(id: int, quantity: int = 1, internal: bool = false) -> Dictionary:
	var ready: Dictionary=_ready_for_action(internal)
	if not ready.ok:return ready
	var offer: Dictionary=catalog.merchant_offer(id)
	var price: Dictionary=merchant_price(id)
	if not price.ok:return price
	var profile: Dictionary=merchant_prices.get(str(id),{})
	if quantity<1 or quantity>1000:return fail("구매 수량 오류")
	var row: Dictionary=offer.goods
	for key: String in ["ClanLevelMin","LimitMinClanLevel","DaysAfterClanJoin","LimitDaysAfterClanJoin","LimitServerCount","LimitBuffCardID","Enchant","ElementalEnchant"]:
		if int(row.get(key,0))!=0:return fail("NPC의 혈맹·서버·카드·장비 조건 미해석")
	if int(row.get("LimitRepeatedBuyCardID",0))>0:
		var qualification: Dictionary=SkillBooks.qualification(world,row)
		if not qualification.ok:return fail(str(qualification.reason))
	if row.get("LimitClanMemberRank",false) or row.get("AvailableSiegeTime")!=true or row.get("LimitNotInSiegeTime")!=false:return fail("NPC 공성·혈맹 권한 조건 미해석")
	if int(row.get("DialogActionTypeID",0))!=1:return fail("NPC 원본 판매 동작 조건 미충족")
	var local_context: Dictionary={}
	if profile.get("time_unrestricted")!=true:
		local_context=npc_definitions.context(int(row.MerchantsID),id)
		if not local_context.ok:return fail(str(local_context.reason))
		if int(world.level)<int(local_context.get("minimum_level",0)):return fail("NPC 원격 목록 접근은 %d레벨 이상 · %s" % [int(local_context.minimum_level),str(local_context.origin)])
		if not npc_definitions.rules.zero_hours_are_open or not npc_definitions.rules.zero_dates_are_open:return fail("NPC 0시간·0날짜 자체 동작이 비활성입니다")
		var saved_rule: String=str(state.get("npc_rule_hashes",{}).get(str(int(row.MerchantsID)),""))
		if not saved_rule.is_empty() and saved_rule!=str(local_context.rules_sha256):return fail("NPC 자체 규칙 변경 감지 · 기존 규칙으로 확인 필요")
	for key: String in ["LimitStartTime","LimitEndTime","LimitStartHour","LimitEndHour"]:
		if int(row.get(key,0))!=0:return fail("NPC 원본 시간 조건 해석 필요")
	if int(world.level)<int(row.LimitMinLevel) or (int(row.LimitMaxLevel)>0 and int(world.level)>int(row.LimitMaxLevel)):return fail("NPC 구매 레벨 조건 미충족")
	var quota: Dictionary={}
	if int(row.LimitCount)>0:
		var counter_key: String="merchant:"+str(row.get("MerchantGoodGUID",id))
		if row.LimitCountPerAccount and integer(profile.get("refresh_unit")):
			var limit: Dictionary=_restrictions(id,[{"MarketRestrictionTypeId":3,"ValueUnitId":1,"Value":int(row.LimitCount),"DurationUnitId":int(profile.refresh_unit),"DurationValue":1}],quantity,counter_key)
			if not limit.ok:return limit
		elif not local_context.is_empty():
			quota=npc_resets.allowance(row,state.purchases.get(counter_key,[]),quantity,_now(),str(state.get("npc_reset_rule_hashes",{}).get(counter_key,"")))
			if not quota.ok:return quota
		else:return fail("NPC 구매 한도 범위·갱신 정책 필요")
	var total: Dictionary=Catalog._checked_product([price.amount,quantity])
	var count: Dictionary=Catalog._checked_product([row.Amount,quantity])
	if not total.ok or not count.ok or int(total.value)<1 or int(count.value)<1:return fail("NPC 금액·상품 수량 범위 오류")
	var payment: Dictionary=_token(int(price.unit_id),int(price.class_id),int(total.value))
	var debit: Dictionary=_resolve(payment,false,world.inventory,int(world.gold))
	if not debit.ok:return debit
	var binding: Dictionary=debit.binding
	var balance: int=int(world.gold) if binding.get("gold",false) else int(world.inventory.get(str(binding.name),0))
	if balance<int(payment.amount):return fail("NPC 구매 재화 부족")
	if not binding.get("gold",false) and (world._item_locked(str(binding.name),"") or not world._enhancement_kind_for_record(binding.get("record",{})).is_empty()):return fail("잠긴 재료·장비를 결제에 사용할 수 없습니다")
	var token: Dictionary=_token(4,int(row.ItemClassID),int(count.value))
	var target: Dictionary=_resolve(token,true,world.inventory,int(world.gold))
	if not target.ok:return target
	var stack_limit: int=int(target.binding.get("record",{}).get("source_max_stack",0))
	if stack_limit>0 and int(world.inventory.get(str(target.binding.get("name","")),0))>stack_limit-int(count.value):return fail("원본 단일 스택 수량 한도 초과")
	if target.binding.get("name")=="드래곤의 용옥":return fail("드래곤의 용옥은 기존 전용 상점의 월 1회·가격 규칙을 이용하세요")
	if not world._enhancement_kind_for_record(target.binding.get("record",{})).is_empty():
		var record: Dictionary=target.binding.get("record",{})
		if local_context.is_empty() or not npc_definitions.supports_normal_equipment(int(row.MerchantsID),int(row.get("ItemBlessCodeID",0))) or record.get("blessed",false) or str(record.get("bless_state","")).to_lower() in ["blessed","cursed","축복","저주"] or str(record.get("name","")).begins_with("축복받은 "):return fail("NPC 장비 축복·강화 지급 조건 미확정")
	var original_name: String=str(offer.item.get("Name",""))
	if offer.item.get("TestItem",false) or original_name.contains("기간") or original_name.contains("삭제") or original_name.contains("이벤트"):return fail("NPC 기간제·테스트 상품 조건 미확정")
	var identity: Dictionary=_source_item_identity(int(row.ItemClassID))
	if identity.get("excluded")==true:return fail("원본 아이템 선언으로 제외된 NPC 상품입니다")
	var quoted: Dictionary={"ok":true,"can_purchase":true,"offer_id":id,"quantity":quantity,"name":str(target.binding.name),"payment":payment,"payment_binding":binding,"goods":[token],"price_origin":str(price.origin)}
	quoted["source_reference"]={"item":identity,"goods":row,"reference_only":true,"can_purchase":false}
	if target.binding.get("record",{}).has("source523_shop_use_origin") and npc_definitions.source_semantics.get("item_bless_codes",{}).get(str(int(row.get("ItemBlessCodeID",0))))!="Normal":return fail("NPC 소모품 축복·저주 스택은 별도 연결 필요")
	if target.binding.get("record",{}).has("source523_shop_use_origin"):quoted["use_origin"]=str(target.binding.record.source523_shop_use_origin)
	if not quota.is_empty():quoted.merge({"quota_text":quota.quota_text,"remaining":quota.remaining,"next_reset_at":quota.next_reset_at,"npc_reset_identity":quota.reset_identity})
	if not local_context.is_empty():quoted.merge({"npc_label":local_context.label,"rule_origin":local_context.origin,"npc_merchant_id":int(row.MerchantsID),"npc_rules_sha256":local_context.rules_sha256,"npc_pack_sha256":local_context.npc_pack_sha256})
	if not local_context.is_empty() and not npc_definitions.input_identity.is_empty():
		var npc_input_error: String=npc_input_identity_problem(npc_definitions.input_identity,str(local_context.npc_pack_sha256),str(catalog.loaded_sha256))
		if not npc_input_error.is_empty():return fail(npc_input_error)
		quoted["source_npc_input_identity"]=npc_definitions.input_identity.duplicate(true)
	return quoted

func buy_merchant(id: int, quantity: int = 1) -> Dictionary:
	var prepared: Dictionary=quote_merchant(id,quantity)
	if not prepared.ok:return prepared
	var started: Dictionary=_start()
	if not started.ok:return started
	prepared=quote_merchant(id,quantity,true)
	if not prepared.ok:_busy=false;return prepared
	return _purchase(prepared,"merchant","merchant:"+str(catalog.merchant_offer(id).goods.get("MerchantGoodGUID",id)))

func orders() -> Array:
	var result: Array = []
	for id: String in state.orders:
		if state.orders[id].status != "pending": continue
		var row: Dictionary = state.orders[id].duplicate(true)
		row["id"] = id
		result.append(row)
	return result

func _grant(goods: Array, inventory: Dictionary, gold: int, instances: Dictionary, next_id: int) -> Dictionary:
	for token: Dictionary in goods:
		if not integer(token.get("amount")) or int(token.amount) < 1: return fail("지급 수량 오류")
		var resolved: Dictionary = _resolve(token, true, inventory, gold)
		if not resolved.ok: return resolved
		var binding: Dictionary = resolved.binding
		var amount: int = int(token.amount)
		if binding.get("gold", false):
			if gold > LIMIT - amount: return fail("아데나 보유 범위 초과")
			gold += amount
		else:
			var name: String = str(binding.name)
			if int(inventory.get(name, 0)) > LIMIT - amount: return fail("아이템 보유 범위 초과")
			var record: Dictionary = binding.get("record", {})
			var stack_limit: int = int(record.get("source_max_stack",0))
			if stack_limit>0 and int(inventory.get(name,0))>stack_limit-amount:return fail("원본 단일 스택 수량 한도 초과 · 보관함 주문 유지")
			inventory[name] = int(inventory.get(name, 0)) + amount
			if not world._enhancement_kind_for_record(record).is_empty():
				if amount > 1000: return fail("한 번에 수령할 장비가 너무 많습니다")
				for unused: int in range(amount):
					while instances.has(str(next_id)): next_id += 1
					if next_id >= LIMIT: return fail("장비 개체 번호 범위 초과")
					instances[str(next_id)] = {"name":name,"level":0,"element":"","element_level":0,"record":record.duplicate(true),"sourceId":str(record.get("sourceId", ""))}
					next_id += 1
	var weight: int = 0
	for name: String in inventory:
		var amount: int = int(inventory[name])
		var unit_weight: int = maxi(0, int(world.item_weight_index.get(name, 3)))
		if unit_weight > 0 and amount > LIMIT / unit_weight: return fail("무게 범위 초과")
		if weight > LIMIT - amount * unit_weight: return fail("무게 범위 초과")
		weight += amount * unit_weight
	if weight > int(world._carrying_capacity()): return fail("무게 한도 초과 · 보관함 주문은 유지됩니다")
	return {"ok":true,"inventory":inventory,"gold":gold,"instances":instances,"next_id":next_id}

func claim(order_id: String) -> Dictionary:
	var started: Dictionary = _start()
	if not started.ok: return started
	var order: Dictionary = state.orders.get(order_id, {})
	if order.is_empty() or order.get("status") != "pending": _busy = false; return fail("미수령 주문이 아닙니다")
	if order.pack_sha256 != catalog.loaded_sha256: _busy = false; return fail("구매 당시 원본 팩을 확인할 수 없습니다 · 주문 보존")
	if order.has("source_input_identity") and not Exact.same(order.source_input_identity,catalog.get("model_input_identity")):
		_busy=false
		return fail("구매 당시 실제 원본/팩 입력 정체가 다릅니다 · 미수령 주문 보존")
	if order.has("source_npc_input_identity") and not Exact.same(order.source_npc_input_identity,npc_definitions.input_identity):
		_busy=false
		return fail("구매 당시 NPC 입력 정체가 다릅니다 · 주문과 지불 이력 보존")
	var granted: Dictionary = _grant(order.goods, world.inventory.duplicate(true), int(world.gold), world.item_instances.duplicate(true), int(world.next_item_instance_id))
	if not granted.ok: _busy = false; return granted
	var next: Dictionary = export_state()
	next.orders[order_id].status = "claimed"
	next.orders[order_id].claimed_at = _now()
	var received: Array=[]
	for id: String in granted.instances:
		if not world.item_instances.has(id):received.append(id)
	next.orders[order_id]["received_physical_ids"]=received
	if order.kind=="market":_activate_cumulative(next, int(order.offer_id))
	var result: Dictionary = _commit(next, granted.inventory, int(granted.gold), granted.instances, int(granted.next_id))
	if result.ok: result["reason"] = "보관함 수령 완료"
	return result

func _event(id: int) -> Dictionary:
	var event: Dictionary = catalog.record("CumulativePurchase", id)
	if event.is_empty(): return fail("누적 보상 정의 없음")
	var window: Dictionary = _window(catalog.record("DateTimes_Korean", int(event.StartTimeID)), catalog.record("DateTimes_Korean", int(event.EndTimeID)))
	if not window.ok: return window
	var server: Dictionary = _server([] if int(event.ServerLimitsetID) == 0 else [int(event.ServerLimitsetID)])
	if not server.ok: return server
	if calendar_offset_minutes == null: return fail("누적 보상 시간 기준 미확정")
	return {"ok":true,"event":event,"day":_period(61,_now(),5),"week":_period(11311,_now(),5)}

func _activate_cumulative(next: Dictionary, purchase_id: int) -> void:
	if not daily_purchase_ids.has(purchase_id): return
	for event: Dictionary in catalog.rows("CumulativePurchase"):
		var active: Dictionary = _event(int(event.ID))
		if not active.ok: continue
		var key: String = "%d:%s" % [int(event.ID),active.week]
		if not next.cumulative.has(key): next.cumulative[key] = {"days":{},"claims":{}}
		next.cumulative[key].days[active.day] = true

func cumulative_view(id: int) -> Dictionary:
	var ready: Dictionary = _ready_for_action()
	if not ready.ok: return ready
	var active: Dictionary = _event(id)
	if not active.ok: return active
	var key: String = "%d:%s" % [id,active.week]
	var progress: Dictionary = state.cumulative.get(key, {"days":{},"claims":{}})
	active["activated_days"] = progress.days.size()
	active["claims"] = progress.claims.duplicate(true)
	return active

func cumulative_quote(id: int, step: int) -> Dictionary:
	var ready: Dictionary = _ready_for_action()
	if not ready.ok: return ready
	return _cumulative_plan(id, step)

func _cumulative_plan(id: int, step: int) -> Dictionary:
	if step < 0 or step > 6: return fail("누적 보상 단계 오류")
	var active: Dictionary = _event(id)
	if not active.ok: return active
	var key: String = "%d:%s" % [id,active.week]
	var progress: Dictionary = state.cumulative.get(key, {"days":{},"claims":{}})
	var claim_key: String = "daily:" + str(active.day) if step == 0 else "step:%d" % step
	if progress.claims.has(claim_key): return fail("이미 수령한 보상입니다")
	var reward_id: int = int(active.event.DailyRewardID) if step == 0 else 0
	if step > 0:
		if progress.days.size() < step: return fail("누적 구매 활성 일수가 부족합니다")
		for row: Dictionary in catalog.rows("CumulativePurchaseStep"):
			if int(row.CumulativePurchaseID) == id and int(row.Step) == step: reward_id = int(row.RewardID)
	var reward: Dictionary = catalog.record("Reward", reward_id)
	if reward.is_empty() or int(reward.get("RewardTypeID", 0)) != 2 or reward.get("ClanOnly", false) or reward.get("UseImmediately", false) or int(reward.get("CharacterClassID", 0)) != 0:
		return fail("누적 보상의 지급 조건 미해석")
	var goods: Array = [_token(4,int(reward.RewardClassID),int(reward.Amount))]
	var granted: Dictionary = _grant(goods, world.inventory.duplicate(true), int(world.gold), world.item_instances.duplicate(true), int(world.next_item_instance_id))
	if not granted.ok: return granted
	return {"ok":true,"key":key,"claim_key":claim_key,"granted":granted}

func claim_cumulative(id: int, step: int) -> Dictionary:
	var started: Dictionary = _start()
	if not started.ok: return started
	var plan: Dictionary = _cumulative_plan(id, step)
	if not plan.ok: _busy = false; return plan
	var granted: Dictionary = plan.granted
	var next: Dictionary = export_state()
	if not next.cumulative.has(plan.key): next.cumulative[plan.key] = {"days":{},"claims":{}}
	next.cumulative[plan.key].claims[plan.claim_key] = true
	var result: Dictionary = _commit(next, granted.inventory, int(granted.gold), granted.instances, int(granted.next_id))
	if result.ok: result["reason"] = "누적 보상 수령 완료"
	return result

func quote_inventory_ticket(item_key: String, selection: Dictionary = {}) -> Dictionary:
	return inventory_tickets.quote(item_key,selection)

func use_inventory_ticket(item_key: String, selection: Dictionary = {}) -> Dictionary:
	var result: Dictionary=inventory_tickets.use_ticket(item_key,selection)
	result["handled"]=InventoryTickets.claims(world._find_catalog_item_record(item_key))
	return result

func try_use_inventory_ticket(item_key: String) -> bool:
	if not InventoryTickets.claims(world._find_catalog_item_record(item_key)):return false
	var result: Dictionary=use_inventory_ticket(item_key)
	world.hud.show_message(str(result.get("message",result.get("reason","티켓 처리 결과 확인 필요"))))
	return true

