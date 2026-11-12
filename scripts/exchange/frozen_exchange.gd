extends RefCounted
## Local one-time snapshot marketplace. Never calls the network or refreshes prices.
## Uses the existing shop's lock, clock, native bindings and atomic owner-save.
const Catalog = preload("res://scripts/exchange/frozen_catalog.gd")
const NativeFields = preload("res://scripts/loot/current523_native_fields.gd")
const NativeItems = preload("res://scripts/loot/patch523_monster_drops.gd")
const STATE_KEY: String = "frozen_exchange"
var catalog = Catalog.new()
var world
var shop

static func fresh_state() -> Dictionary:
	return {"version":1,"snapshot_sha256":"","day":0,"consumed":{}}

static func validate_state(value: Variant) -> String:
	if not value is Dictionary or value.get("version") != 1 or not Catalog.integer(value.get("day")) or not value.get("consumed") is Dictionary: return "거래소 저장 형식 오류"
	var hash_value: Variant = value.get("snapshot_sha256")
	if not hash_value is String or (not hash_value.is_empty() and (hash_value.length() != 64 or not hash_value.is_valid_hex_number(false))): return "거래소 스냅샷 저장 해시 오류"
	if hash_value.is_empty() and (not value.consumed.is_empty() or value.day != 0): return "거래소 재고의 스냅샷 정체 누락"
	for id: Variant in value.consumed:
		if not id is String or id.is_empty() or not Catalog.integer(value.consumed[id],1): return "거래소 소비 수량 오류"
	return ""

static func day_at(timestamp: int) -> int:
	# UTC+09:00 minus 05:00 = UTC+04:00. No DST or device timezone.
	return floori(float(timestamp + 14400) / 86400.0)

func configure(host: Node, path: String = Catalog.PATH) -> void:
	world = host
	shop = world.get("source_shop")
	catalog.load_snapshot(path)

func _state() -> Dictionary:
	return shop.state.get(STATE_KEY,fresh_state()).duplicate(true)

func available(row: Dictionary) -> int:
	if shop == null: return 0
	var state: Dictionary = _state()
	if not validate_state(state).is_empty() or (not str(state.snapshot_sha256).is_empty() and state.snapshot_sha256 != catalog.sha256): return 0
	var now: int = maxi(int(shop._now()),int(shop.state.clock_highwater))
	var used: int = int(state.consumed.get(Catalog.key(row),0)) if int(state.day) == day_at(now) else 0
	return maxi(0,int(row.initial_bundles) - used)

func _plan(id: String, bundles: int, internal: bool = false) -> Dictionary:
	if not catalog.captured(): return _fail(catalog.problem if not catalog.problem.is_empty() else "전 서버 실측 상품 수집 대기 · 임의 가격 없음")
	if shop == null: return _fail("상점 저장 연결 없음")
	var ready: Dictionary = shop._ready_for_action(internal)
	if not ready.ok: return ready
	var state: Dictionary = _state()
	var error: String = validate_state(state)
	if not error.is_empty(): return _fail(error)
	if not str(state.snapshot_sha256).is_empty() and state.snapshot_sha256 != catalog.sha256: return _fail("초기 거래소 스냅샷 변경 감지 · 기존 저장 보존")
	if int(state.day) > day_at(shop._now()): return _fail("거래소 저장 시각 역행 · 재고 보존")
	for consumed_id: String in state.consumed:
		var stored: Dictionary = catalog.listing(consumed_id)
		if stored.is_empty() or int(state.consumed[consumed_id]) > int(stored.initial_bundles): return _fail("거래소 저장 재고·상품 불일치")
	var row: Dictionary = catalog.listing(id)
	if row.is_empty() or bundles < 1 or bundles > 1000 or bundles > available(row): return _fail("구매할 묶음 수량·잔량 오류")
	# The native supplier preserves observed enhancement on verified equipment.
	# Unproved blessing/element/special variants must never become plain items.
	# blessedType=0 is an all-types API filter, never evidence of normal blessing.
	# Only an explicitly observed normal type is supported; preserve and lock
	# every other or unrecognised attribute until its native mapping is proved.
	if not row.element.is_empty() or int(row.element_level) != 0 or row.attributes.size() != 1 or not Catalog.integer(row.attributes.get("blessed_type"),1,1): return _fail("축복 종류·속성·특수 변형의 실제 개체 연결 미검증 · 구매 잠금")
	if bundles > Catalog.LIMIT / int(row.bundle_price) or bundles > Catalog.LIMIT / int(row.bundle_size): return _fail("묶음 합계 범위 초과")
	var original: Dictionary = shop.catalog.record("ItemClass",int(row.item_class_id))
	if original.is_empty() or shop.catalog.label(int(original.get("DescID",0))) != str(row.item_name): return _fail("실측 상품과 원본 ItemClass 이름·ID 불일치")
	var identity: Dictionary = shop._source_item_identity(int(row.item_class_id))
	if identity.get("excluded") == true: return _fail("원본 아이템 선언으로 제외된 상품입니다")
	var internal_name: String = str(original.get("Name",""))
	if original.get("TestItem",false) or internal_name.contains("기간") or internal_name.contains("삭제") or internal_name.contains("이벤트"): return _fail("기간제·삭제·이벤트 상품의 만료 조건 미확인")
	var total: int = int(row.bundle_price) * bundles
	var quantity: int = int(row.bundle_size) * bundles
	if not world.has_method("source_item_definition") or not world.has_method("stage_source_item_grants"): return _fail("원본 아이템 공급 연결 없음 · 구매 잠금")
	# The read-through definition API resolves an unseen ItemClass; the debug
	# source_item_record getter intentionally answers cached IDs only.
	var native_definition: Dictionary = world.source_item_definition(int(row.item_class_id))
	var record: Dictionary = native_definition.get("native_record",{})
	if not record.get("source_m_native_item",false) or record.get("source") != "lineagem_patch523" or record.get("source_snapshot") != "patch523" or int(record.get("source_item_class_id",0)) != int(row.item_class_id) or record.get("sourceId") != "m523:item:" + str(int(row.item_class_id)) or NativeFields.field(record,"source_display_name","") != row.item_name: return _fail("원본 아이템의 실제 공급 개체 미확인 · 구 아이템으로 대체하지 않습니다")
	if int(row.enchant) > 0 and (not NativeItems.equipment(record) or NativeFields.field(record,"source_equipment_status","") != "mapped" or int(record.get("source_bless_raw",0)) != 1 or row.get("observed_item_name","") != "+%d %s" % [int(row.enchant),row.item_name]): return _fail("강화 매물의 일반 원본 장비 연결 미확인 · 구매 잠금")
	if row.item_name == "드래곤의 용옥": return _fail("드래곤의 용옥은 기존 전용 상점의 월 1회 규칙을 이용하세요")
	if not NativeFields.field(record,"source_condition_pending",[]).is_empty() or NativeFields.has_field(record,"source_delete_time_raw") or NativeFields.has_field(record,"source_delete_time_unresolved"): return _fail("원본 아이템 기간·서버 조건 미확인 · 구매 잠금")
	if record.get("blessed",false) or str(record.get("bless_state","")).to_lower() in ["blessed","cursed","축복","저주"] or str(record.get("name","")).begins_with("축복받은 "): return _fail("축복·저주 실제 개체 연결 미검증")
	var payment: Dictionary = shop._resolve({"unit_id":34,"class_id":2,"amount":total},false,world.inventory,int(world.gold))
	if not payment.ok: return payment
	var binding: Dictionary = payment.binding
	if binding.get("gold",false) or int(world.inventory.get(str(binding.name),0)) < total: return _fail("구매 다이아가 부족합니다")
	if world._item_locked(str(binding.name),""): return _fail("잠긴 결제 재화입니다")
	# The native supplier owns exact ItemClass DTOs and physical ownership proofs.
	# Never pass exchange goods through the older name-keyed shop bindings.
	var supplied: Dictionary = world.stage_source_item_grants([{"item_class_id":int(row.item_class_id),"amount":quantity,"bless_raw":1,"enchant":int(row.enchant)}],{"kind":"frozen_exchange","snapshot_sha256":catalog.sha256,"listing_key":id,"bundle_size":int(row.bundle_size),"bundle_price":int(row.bundle_price),"bundles":bundles,"observed_blessed_type":1,"observed_enchant":int(row.enchant),"evidence_url":row.evidence_url})
	if not supplied.get("ok",false): return _fail(str(supplied.get("error","원본 아이템 공급 실패")))
	var staged: Dictionary = supplied.overrides
	var inventory: Dictionary = staged.inventory
	inventory[str(binding.name)] = int(inventory.get(str(binding.name),0)) - total
	if int(inventory[str(binding.name)]) == 0: inventory.erase(str(binding.name))
	var weight: int = 0
	for item_name: String in inventory:
		var amount: int = int(inventory[item_name])
		var unit_weight: int = maxi(0,int(world.item_weight_index.get(item_name,3)))
		if unit_weight > 0 and amount > Catalog.LIMIT / unit_weight: return _fail("무게 범위 초과")
		if weight > Catalog.LIMIT - amount * unit_weight: return _fail("무게 범위 초과")
		weight += amount * unit_weight
	if weight > int(world._carrying_capacity()): return _fail("무게 한도 초과 · 구매하지 않았습니다")
	var grant: Dictionary = {"inventory":inventory,"gold":staged.gold,"instances":staged.item_instances,"next_id":int(world.next_item_instance_id)}
	return {"ok":true,"row":row,"bundles":bundles,"total":total,"quantity":quantity,"grant":grant}

func quote(id: String, bundles: int = 1) -> Dictionary:
	return _plan(id,bundles)

func buy(id: String, bundles: int = 1) -> Dictionary:
	var prepared: Dictionary = _plan(id,bundles)
	if not prepared.ok: return prepared
	var started: Dictionary = shop._start()
	if not started.ok: return started
	# Migration or a second UI click cannot reuse a stale wallet or quote.
	prepared = _plan(id,bundles,true)
	if not prepared.ok: shop._busy = false; return prepared
	var next: Dictionary = shop.export_state()
	var state: Dictionary = _state()
	var day: int = day_at(shop._now())
	if int(state.day) != day: state.consumed = {}
	state.day = day
	state.snapshot_sha256 = catalog.sha256
	state.consumed[id] = int(state.consumed.get(id,0)) + bundles
	next[STATE_KEY] = state
	var grant: Dictionary = prepared.grant
	var result: Dictionary = shop._commit(next,grant.inventory,int(grant.gold),grant.instances,int(grant.next_id))
	if result.ok:
		world._index_item_weights()
		result["reason"] = "고정 가격 %d 다이아 · %d묶음(%d개) 구매 완료" % [prepared.total,bundles,prepared.quantity]
	return result

static func _fail(message: String) -> Dictionary:
	return {"ok":false,"reason":message}
