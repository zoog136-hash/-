extends RefCounted
## Exact held-ID selection. The predicates below are configurable host policy,
## not an inferred implementation of the native virtual selector constants.
const MARKER: String = "twilight_equipment_category_v1"
const SELECTORS = {
	45011:{"label":"일반 장비","constant":"AutoSaleItemCommonTradable","grade":"일반","marking":0},
	45021:{"label":"일반 장비 (각인)","constant":"AutoSaleItemCommon","grade":"일반","marking":1},
	45031:{"label":"고급 장비","constant":"AutoSaleItemRareTradable","grade":"고급","marking":0},
	45041:{"label":"고급 장비 (각인)","constant":"AutoSaleItemRare","grade":"고급","marking":1}}
const SLOTS = {"weapon":"무기","offhand":"방패/가더","helmet":"투구","tshirt":"티셔츠","body":"갑옷","pants":"하의","cloak":"망토","shoulder":"견갑","gaiters":"각반","boots":"신발","gloves":"장갑","ring":"반지","earring":"귀걸이","belt":"벨트","bracelet":"팔찌","badge":"휘장","seal":"인장","crystal":"수정","catalyst":"카탈리스트","rune":"룬","necklace":"목걸이"}
const GRADES = ["일반","고급","희귀","영웅","전설","신화","유일"]
var owner_reference: WeakRef
var owner:
	get: return owner_reference.get_ref() if owner_reference != null else null
func configure(service) -> void: owner_reference = weakref(service)

static func fresh(selector: int = 45011) -> Dictionary:
	var hint: Dictionary = SELECTORS.get(selector,SELECTORS[45011])
	return {"version":1,"basis":MARKER,"selector_id":selector,"enabled":false,"grade":hint.grade,"slot":"","marking":hint.marking,"max_enchant":0,"targets":[]}

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	if raw.is_empty(): return true
	if not _integer(raw.get("version")) or int(raw.version) != 1 or raw.get("basis") != MARKER or not raw.get("enabled") is bool: return false
	if not _integer(raw.get("selector_id")) or not SELECTORS.has(int(raw.selector_id)): return false
	if raw.get("grade") not in GRADES or not raw.get("slot") is String or (raw.slot != "" and not SLOTS.has(raw.slot)): return false
	if raw.enabled and raw.slot == "": return false
	if not _integer(raw.get("marking")) or int(raw.marking) not in [0,1,2]: return false
	if not _integer(raw.get("max_enchant")) or raw.max_enchant < 0 or raw.max_enchant > 20: return false
	var targets: Variant = raw.get("targets")
	if not targets is Array or targets.size() > 256 or (not raw.enabled and not targets.is_empty()): return false
	var seen: Dictionary = {}
	for target: Variant in targets:
		if not target is Dictionary or not target.get("name") is String or target.name.is_empty() or not target.get("id") is String or target.id.is_empty(): return false
		if not target.get("identity") is String or target.identity.length() != 64 or not target.identity.is_valid_hex_number() or seen.has(target.id): return false
		seen[target.id] = true
	return true

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floorf(float(value))

func settings(selector: int = 45011) -> Dictionary:
	var saved: Dictionary = owner.state.get("equipment_category",{})
	return saved.duplicate(true) if not saved.is_empty() and int(saved.selector_id) == selector else fresh(selector)

func _marked(name: String, record: Dictionary, physical: Dictionary) -> bool:
	var custom: Dictionary = physical.get("record",{})
	return name.contains("각인") or name.contains("귀속") or bool(record.get("bound",false)) or record.get("tradeable",true) == false or bool(custom.get("bound",false)) or custom.get("tradeable",true) == false

func candidates(config: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not valid(config) or config.slot == "": return result
	var world: Node = owner.world
	var ids: Array = world.item_instances.keys()
	ids.sort()
	for raw: Variant in ids:
		var id: String = str(raw)
		var physical: Dictionary = world.item_instances[raw]
		var name: String = str(physical.get("name",""))
		if name == "" or int(world.inventory.get(name,0)) <= 0: continue
		var record: Dictionary = world._find_catalog_item_record(name)
		if record.is_empty() or str(world._enhancement_kind_for_record(record)) == "": continue
		var slot: String = str(world._equipment_slot_base(record))
		if record.get("grade","") != config.grade or slot != config.slot: continue
		var marked: bool = _marked(name,record,physical)
		if (int(config.marking) == 0 and marked) or (int(config.marking) == 1 and not marked): continue
		var level: Variant = physical.get("level",0)
		if not _integer(level) or level < 0 or level > int(config.max_enchant): continue
		var reason: String = ""
		if owner._protected(name,id,"sell"): reason = "잠금·장착·귀속·퀘스트 등 기존 보호"
		var custom: Dictionary = physical.get("record",{})
		if (custom.has("grade") and custom.grade != record.grade) or (custom.has("slot") and str(world._equipment_slot_base(custom)) != slot): reason = "개별 장비의 분류와 현재 도감이 다름"
		for existing: Dictionary in owner.state.sell:
			if existing.name == name and str(existing.get("id","")) == id and existing.get("category_owner","") != MARKER: reason = "별도 자동 대상에 등록됨 · 기존 남김 규칙 유지"
		var quote: Dictionary = owner.sale_quote(name,1,id,world.inventory,world.item_instances,world.gold,false)
		if not quote.get("ok",false): reason = str(quote.get("reason","매입 불가"))
		result.append({"name":name,"id":id,"identity":owner._identity(name,id),"grade":str(record.grade),"slot":slot,"level":int(level),"marked":marked,"ok":reason == "","reason":reason,"payment":int(quote.get("payment",0)),"price_basis":str(quote.get("price_basis","TWILIGHT 기존 매입가"))})
	return result

func _prepare(config: Dictionary, allow_custom: bool) -> Dictionary:
	if not valid(config) or not config.enabled or config.targets.is_empty(): return _fail("범주 사용·등급·슬롯·정확한 소지 ID를 직접 선택해주세요")
	if owner.state.get("source_only",false) and not allow_custom: return _fail("자체 범주 사용을 위해 원본 ID 전용 모드 해제를 명시적으로 선택해주세요")
	var current: Dictionary = {}
	for candidate: Dictionary in candidates(config): current[candidate.id] = candidate
	var next: Dictionary = owner.state.duplicate(true)
	var targets: Array = []
	for rule: Dictionary in next.sell:
		if rule.get("category_owner","") != MARKER: targets.append(rule)
	for target: Dictionary in config.targets:
		var candidate: Dictionary = current.get(target.id,{})
		if candidate.is_empty() or not candidate.ok or candidate.name != target.name or candidate.identity != target.identity: return _fail("선택한 ID·장비 정보·조건·보호 상태가 바뀌었습니다. 목록을 새로 확인해주세요")
		targets.append({"name":target.name,"id":target.id,"identity":target.identity,"keep":0,"category_owner":MARKER})
	if targets.size() > 256: return _fail("자동 판매 대상은 최대256개입니다")
	next["sell"] = targets
	next["equipment_category"] = config.duplicate(true)
	if owner.state.get("source_only",false): next["source_only"] = false
	if next.has("maintenance"): next.maintenance["armed"] = false
	return {"ok":true,"state":next}

func preview(config: Dictionary, allow_custom: bool = false) -> Dictionary:
	var prepared: Dictionary = _prepare(config,allow_custom)
	if not prepared.get("ok",false): return prepared
	var plan: Dictionary = owner.preview("sell",{},prepared.state)
	if not plan.get("ok",false): return plan
	if plan.cart.is_empty(): return _fail("판매할 소지 장비가 없습니다")
	plan["selection_state"] = prepared.state
	return plan

func activate(config: Dictionary, stamp: String, allow_custom: bool = false) -> Dictionary:
	if stamp == "" or stamp != owner._stamp("sell"): return _fail("소지품·조건이 변경됐습니다. 다시 미리보기 해주세요")
	var plan: Dictionary = preview(config,allow_custom)
	if not plan.get("ok",false): return plan
	return owner.save_settings(plan.selection_state)

func execute(config: Dictionary, stamp: String, allow_custom: bool = false) -> Dictionary:
	if stamp == "" or stamp != owner._stamp("sell"): return _fail("소지품·조건이 변경됐습니다. 다시 미리보기 해주세요")
	var plan: Dictionary = preview(config,allow_custom)
	if not plan.get("ok",false): return plan
	var result: Dictionary = owner.commit_plan(plan)
	if result.get("ok",false): owner.maintenance.reset_session()
	return result

func disable() -> Dictionary:
	var next: Dictionary = owner.state.duplicate(true)
	var remaining: Array = []
	for rule: Dictionary in next.sell:
		if rule.get("category_owner","") != MARKER: remaining.append(rule)
	next["sell"] = remaining
	var config: Dictionary = next.get("equipment_category",fresh()).duplicate(true)
	config["enabled"] = false
	config["targets"] = []
	next["equipment_category"] = config
	return owner.save_settings(next)

static func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
