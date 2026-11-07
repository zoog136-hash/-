extends RefCounted
## Narrow, checked source contract. Generic host enhancement stays independent.
const RULES = preload("res://scripts/crafting/patch523_rules.gd")
const POLICY_PATH: String = "res://data/crafting/patch523_seal_policy.json"

static func policy() -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(POLICY_PATH)) != OK or not parser.data is Dictionary: return {}
	return parser.data

static func quote(book: Object, physical: Dictionary, scroll_id: String, inventory: Dictionary, gold: int, locked: bool) -> Dictionary:
	if locked: return RULES.denied("잠금을 해제하세요")
	var source_id: String = book.identity(physical)
	var level: int = int(physical.get("level", -1))
	var blessing: int = book.bless_code(physical)
	if source_id not in ["30671","130551"] or scroll_id not in ["320802","166044"]:
		return RULES.denied("이 경로는 수호·회복 인장과 영구 빛나는 강화·보호 주문서 전용입니다")
	if not book._state_matches(physical, {"source_id":source_id,"level":level,"bless_code":blessing}, false):
		return RULES.denied("원본 장비 상태·추가 옵션을 확인하세요")
	var protected: bool = scroll_id == "166044"
	# Raw target0 is confirmed only for the public normal-seal branch here.
	# Never infer blessed ordinary-scroll eligibility from a wildcard.
	if (not protected and (blessing!=1 or level<0 or level>7)) or (protected and (blessing not in [1,2] or level<4 or level>7)):
		return RULES.denied("공식 표로 확인된 대상·단계가 아닙니다")
	var settings: Dictionary = policy()
	var economy: Dictionary = settings.get("economy",{})
	for key: String in ["ordinary_normal_success_pct","protected_normal_success_pct","protected_blessed_success_pct"]:
		if not settings.get(key) is Array or settings[key].size()!=(8 if key=="ordinary_normal_success_pct" else 4):
			return RULES.denied("공식 확률 설정 구조를 확인하세요")
	if economy.get("currency","")!="adena": return RULES.denied("지원되는 게임 내 비용 통화를 설정하세요")
	var count: int = int(economy.get("ordinary_zero_consume_scrolls",0))
	if count<1 or count>10000: return RULES.denied("주문서 소비량 설정을 확인하세요")
	if protected: count = [3,10,20,50][level-4]
	var expected_rate: float = float(settings.get("protected_blessed_success_pct" if blessing==2 else "protected_normal_success_pct",[])[level-4]) if protected else float(settings.ordinary_normal_success_pct[level])
	var evidence: Dictionary = book.enhancement_evidence(int(source_id),int(scroll_id),level,blessing,1)
	var group: int = 781 if protected else 81
	if evidence.groups != [group]: return RULES.denied("원본 장비·주문서 그룹 불일치")
	var probability: Dictionary = {}
	var cost_row: Dictionary = {}
	for row: Dictionary in evidence.probabilities:
		if int(row.TargetItemBlessCode)==(blessing if protected else 0): probability=row
	for row: Dictionary in evidence.costs:
		if int(row.TargetItemBlessCode)==(blessing if protected else 0): cost_row=row
	if probability.is_empty() or cost_row.is_empty(): return RULES.denied("원본 확률·비용 행이 없습니다")
	var total: int = int(probability.Success)+int(probability.Remain)+int(probability.Vaporize)+int(probability.SideEffect)
	var expected_cost: int = 11000 if protected else 1000
	if total<=0 or not is_equal_approx(100.0*float(probability.Success)/total,expected_rate) or int(probability.SideEffect)!=0 or int(cost_row.Cost)!=expected_cost or int(cost_row.ConsumeAmount)!=(count if protected else 0):
		return RULES.denied("원본과 공식 확률·소비 조건 불일치")
	if (protected and (int(probability.Vaporize)!=0 or int(probability.Success)+int(probability.Remain)!=total)) or (not protected and int(probability.Remain)!=0):
		return RULES.denied("공식 실패 규칙과 원본이 다릅니다")
	var scroll_record: Dictionary = book.record(scroll_id)
	var scroll_name: String = str(scroll_record.get("name",""))
	if scroll_name.is_empty() or bool(book.item_entry(scroll_id).item_class.TestItem): return RULES.denied("영구 주문서 정보를 확인하세요")
	if int(inventory.get(scroll_name,0))<count or gold<expected_cost: return RULES.denied("주문서 또는 아데나가 부족합니다")
	return {"ok":true,"scroll_name":scroll_name,"scroll_id":scroll_id,"count":count,"cost":expected_cost,
		"success":expected_rate,"protected":protected,"level":level,"item":str(physical.name),
		"economy_label":"통화: 자체 설정 아데나" + (" · 수량0: 자체 설정 %d장" % count if not protected else " · 수량: 원본"),
		"official_version":settings.official_version}

static func open_box(book: Object, source_id: String, inventory: Dictionary, physical: Dictionary, next_id: int, current_weight: int, capacity: int, items: Dictionary, locked: bool) -> Dictionary:
	if locked: return RULES.denied("잠금을 해제하세요")
	var definition: Dictionary = book.data.get("guaranteed_boxes",{}).get(source_id,{})
	var box: Dictionary = book.record(source_id)
	if definition.is_empty() or box.is_empty() or int(inventory.get(str(box.name),0))<1: return RULES.denied("확정 인장 상자가 없습니다")
	if items.get(str(box.name),{}).get("sourceId","")!=source_id: return RULES.denied("상자 원본 ID가 일치하지 않습니다")
	var staged_inventory: Dictionary = inventory.duplicate(true)
	var staged_physical: Dictionary = physical.duplicate(true)
	staged_inventory[str(box.name)] = int(staged_inventory[str(box.name)])-1
	if int(staged_inventory[str(box.name)])==0: staged_inventory.erase(str(box.name))
	var counter: int = maxi(1,next_id)
	var weight: int = current_weight-int(items.get(str(box.name),{}).get("weight",1))
	for reward: Dictionary in definition.rewards:
		var id: String = str(int(reward.ItemClassID))
		var rec: Dictionary = book.record(id)
		if rec.is_empty() or int(reward.LuckyBagEntityTypeID)!=1 or int(reward.ItemBlessCodeID)!=1 or int(reward.ItemEnchant)!=0: return RULES.denied("확정 보상 상태를 확인하세요")
		var item_name: String = str(rec.name)
		var amount: int = int(reward.ItemAmount)
		staged_inventory[item_name] = int(staged_inventory.get(item_name,0))+amount
		weight += amount*int(items.get(item_name,{}).get("weight",1))
		if id in ["30671","130551"]:
			while staged_physical.has(str(counter)): counter+=1
			staged_physical[str(counter)] = {"name":item_name,"level":0,"element":"","element_level":0,
				"sourceId":id,"source_snapshot":"patch523","source_bless_code":1,"bless_state":"normal","record":rec}
			counter+=1
	if weight>capacity: return RULES.denied("상자 보상을 받을 무게가 부족합니다")
	return {"ok":true,"inventory":staged_inventory,"item_instances":staged_physical,"next_item_instance_id":counter}
