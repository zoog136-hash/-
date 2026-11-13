extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Shared exact-ID supplier contract. Prices/recipes/skills remain with owners.
const SUPPLY=preload("res://scripts/cards/native_awakening_supply.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const MAX_EXACT_JSON_INTEGER: int = 9007199254740991

## User decision 2026-11-13: original reward rows of the crafting coins and the
## honor coin add to the existing coin wallets (inventory key = wallet name),
## the same wallets the expedition bridge already credits. The original row
## must still be this exact non-test Currency row of that wallet.
const COIN_WALLETS={3242:"변신 제작 코인",3252:"마법인형 제작 코인",3631:"명예 코인",246058:"성물 제작 코인"}
static func coin_wallet(id: int) -> String:
	if not COIN_WALLETS.has(id):return ""
	var raw: Dictionary=preload("res://scripts/resources/current523_definition_rows.gd").row("ItemClass",id)
	if raw.get("TestItem")!=false or int(raw.get("CategoryID",0))!=122 or int(raw.get("GradeID",0))!=1:return ""
	var bridge: Script=load("res://scripts/expedition/reward_bridge.gd")
	var label: String=preload("res://scripts/loot/currency_drops.gd").canonical_name(str(bridge.call("untagged",str(raw.get("Name","")))))
	return str(COIN_WALLETS[id]) if label==COIN_WALLETS[id] else ""

static func stage(world: Node, grants: Array, origin: Dictionary) -> Dictionary:
	if grants.is_empty() or origin.is_empty(): return {"ok":false,"error":"원본 지급 출처·명세 필요"}
	var inventory: Dictionary = world.inventory.duplicate(true)
	var instances: Dictionary = world.item_instances.duplicate(true)
	var gold: int = world.gold
	for grant: Dictionary in grants:
		for field: String in ["item_class_id","amount","bless_raw","enchant"]:
			var value: Variant = grant.get(field)
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or absf(float(value)) > MAX_EXACT_JSON_INTEGER: return {"ok":false,"error":"원본 지급 수치 형식 확인 실패"}
		var id: String = str(int(grant.get("item_class_id",-1)))
		if not preload("res://scripts/quests/source_dummy523.gd").item_id_evidence(int(id)).is_empty():return {"ok":false,"error":"원본 더미 선언 아이템은 신규 지급에서 제외 · 기존 소유 보존"}
		var coin: String=coin_wallet(int(id))
		if not coin.is_empty():
			if float(grant.get("item_class_id",-1))!=int(id) or float(grant.get("amount",0))!=floorf(float(grant.get("amount",0))) or int(grant.get("amount",0))<1 or float(grant.get("bless_raw",0))!=1 or float(grant.get("enchant",-1))!=0:return {"ok":false,"error":"원본 코인 지급 수량·일반 축복·강화 조건 불일치"}
			var coin_amount: int=int(grant.amount);var coin_before: Variant=inventory.get(coin,0)
			if not D._source_integer(coin_before) or int(coin_before)<0 or int(coin_before)>MAX_EXACT_JSON_INTEGER-coin_amount:return {"ok":false,"error":"원본 코인 지급 후 수량 정수 범위 초과 · 기존 보유 보존"}
			inventory[coin]=int(coin_before)+coin_amount
			continue
		if int(id) in SUPPLY.IDS:
			var amount_value: Variant=grant.get("amount",0)
			if float(grant.get("item_class_id",-1))!=int(id) or float(amount_value)!=floorf(float(amount_value)) or int(amount_value)<1 or grant.get("bless_raw")!=1 or grant.get("enchant")!=0:return {"ok":false,"error":"새 원문 각성 공급 수량·일반 축복·강화 조건 불일치"}
			var current: Dictionary=SUPPLY.record(int(id))
			if current.is_empty() or not SUPPLY.exact(world._catalog_item_from_source_id(str(current.sourceId)),int(id)):return {"ok":false,"error":"새 원문 각성 공급 정의 미등록 · 기존 소유 보존"}
			var name_value: String=SUPPLY.key(current);var previous_amount: Variant=inventory.get(name_value,0)
			if not SUPPLY.integer(previous_amount) or int(previous_amount)>MAX_EXACT_JSON_INTEGER-int(amount_value):return {"ok":false,"error":"원문 공급 수량 범위 초과"}
			var typed: Dictionary=SUPPLY.stage_grant(current,int(amount_value),instances,origin)
			if not typed.get("ok",false):return {"ok":false,"error":"새 원문 각성 공급 영수증 생성 실패"}
			instances=typed.item_instances;inventory[name_value]=int(previous_amount)+int(amount_value)
			continue
		var summary: Dictionary = D.definition_id(id)
		if int(id) <= 0 or float(grant.get("item_class_id",-1)) != int(id) or summary.is_empty() or summary.get("original_item",{}).get("TestItem",true): return {"ok":false,"error":"정상 원본 아이템 ID 확인 실패"}
		var amount: int = int(grant.get("amount",0))
		var bless: int = int(grant.get("bless_raw",0))
		var enchant: int = int(grant.get("enchant",-1))
		if amount <= 0 or amount > 9007199254740991 or bless not in [1,2,3] or enchant < 0 or float(grant.get("amount",0)) != amount or float(grant.get("bless_raw",0)) != bless or float(grant.get("enchant",-1)) != enchant: return {"ok":false,"error":"원본 지급 수량·축복·강화 명세 확인 실패"}
		var base: Dictionary = summary.get("native_record",{})
		var record: Dictionary = D.variant_item(base,bless)
		if record.is_empty():return {"ok":false,"error":"새 원문 아이템 DTO 참조 미해결 · 기존 소유 보존"}
		if not D.matches(world._catalog_item_from_source_id(str(record.sourceId)),record): return {"ok":false,"error":"원본 공급 카탈로그 미등록"}
		if enchant > 0 and not D.equipment(record): return {"ok":false,"error":"비장비 원본 강화값 미지원"}
		var wallet: String = D.currency_identity_name(record)
		var stock: Script=load("res://scripts/loot/current523_native_stack.gd")
		var stack_supported: bool=not stock.call("supply_profile",record).is_empty()
		if not D.equipment(record) and wallet!="아데나" and not stack_supported:return {"ok":false,"error":"새 원문 비장비 물리 수량·소비 소유자 연결 대기 · 입력과 보상 보존"}
		var key: String = wallet if not wallet.is_empty() else str(record.name)
		if wallet == "아데나":
			if gold < 0 or gold > MAX_EXACT_JSON_INTEGER-amount: return {"ok":false,"error":"원본 지급 후 재화 정수 범위 초과 · 기존 보유 보존"}
			gold += amount
		else:
			var previous_value: Variant=inventory.get(key,0)
			if not D._source_integer(previous_value):return {"ok":false,"error":"기존 소지 수량 정수 형식 보존"}
			var previous: int=int(previous_value)
			if previous < 0 or previous > MAX_EXACT_JSON_INTEGER-amount: return {"ok":false,"error":"원본 지급 후 수량 정수 범위 초과 · 기존 보유 보존"}
			inventory[key] = previous+amount
		if bless==1 and int(id) in preload("res://scripts/cards/native_awakening_supply.gd").IDS:
			var typed: Dictionary=preload("res://scripts/cards/native_awakening_supply.gd").stage_grant(record,amount,instances,origin)
			if not typed.get("ok",false):return {"ok":false,"error":"각성 물품 원본 지급 증명 실패"}
			instances=typed.item_instances
		if stack_supported:
			var staged: Dictionary=stock.call("stage_grant",record,amount,instances,origin)
			if not staged.get("ok",false):return {"ok":false,"error":"원본 물리 공급 영수증 생성 실패"}
			instances=staged.item_instances
		if D.equipment(record):
			if amount > 65536: return {"ok":false,"error":"물리 장비 묶음 지급 크기 초과"}
			var state: String = {1:"normal",2:"blessed",3:"cursed"}[bless]
			record["bless_state"] = state
			for index: int in range(amount):
				var uid: String = Crypto.new().generate_random_bytes(16).hex_encode()
				while instances.has(uid): uid = Crypto.new().generate_random_bytes(16).hex_encode()
				instances[uid] = {"name":str(record.name),"record":NATIVE_FIELDS.full(record).duplicate(true),"level":enchant,"element":"","element_level":0,"bless_state":state,"source_m_reward_proof":{"source_snapshot":"patch523","item_class_id":int(id),"source_item_class_id":int(id),"bless":bless,"enchant":enchant,"supplier":origin.duplicate(true)}}
	return {"ok":true,"overrides":{"inventory":inventory,"item_instances":instances,"gold":gold}}

static func commit(world: Node, grants: Array, origin: Dictionary) -> bool:
	var result: Dictionary = stage(world,grants,origin)
	if not result.get("ok",false): world.hud.show_message(str(result.error));return false
	if world._save_game(true,result.overrides) != OK: world.hud.show_message("원본 지급 저장 실패 · 기존 보유 보존");return false
	world.inventory = result.overrides.inventory
	world.item_instances = result.overrides.item_instances
	world.gold = int(result.overrides.gold)
	world.hud.refresh_inventory(world.inventory)
	world._update_hud()
	return true
