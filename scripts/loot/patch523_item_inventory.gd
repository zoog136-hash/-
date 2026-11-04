extends RefCounted
## Shared exact-ID supplier contract. Prices/recipes/skills remain with owners.
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const MAX_EXACT_JSON_INTEGER: int = 9007199254740991

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
		var summary: Dictionary = D.data().get("item_definitions",{}).get(id,{})
		if int(id) <= 0 or float(grant.get("item_class_id",-1)) != int(id) or summary.is_empty() or summary.get("original_item",{}).get("TestItem",true): return {"ok":false,"error":"정상 원본 아이템 ID 확인 실패"}
		var amount: int = int(grant.get("amount",0))
		var bless: int = int(grant.get("bless_raw",0))
		var enchant: int = int(grant.get("enchant",-1))
		if amount <= 0 or amount > 9007199254740991 or bless not in [1,2,3] or enchant < 0 or float(grant.get("amount",0)) != amount or float(grant.get("bless_raw",0)) != bless or float(grant.get("enchant",-1)) != enchant: return {"ok":false,"error":"원본 지급 수량·축복·강화 명세 확인 실패"}
		var base: Dictionary = summary.get("native_record",{})
		var record: Dictionary = D.variant_item(base,bless)
		if not D.matches(world._catalog_item_from_source_id(str(record.sourceId)),record): return {"ok":false,"error":"원본 공급 카탈로그 미등록"}
		if enchant > 0 and not D.equipment(record): return {"ok":false,"error":"비장비 원본 강화값 미지원"}
		var wallet: String = D.currency_identity_name(record)
		var key: String = wallet if not wallet.is_empty() else str(record.name)
		if wallet == "아데나":
			if gold < 0 or gold > MAX_EXACT_JSON_INTEGER-amount: return {"ok":false,"error":"원본 지급 후 재화 정수 범위 초과 · 기존 보유 보존"}
			gold += amount
		else:
			var previous: int = int(inventory.get(key,0))
			if previous < 0 or previous > MAX_EXACT_JSON_INTEGER-amount: return {"ok":false,"error":"원본 지급 후 수량 정수 범위 초과 · 기존 보유 보존"}
			inventory[key] = previous+amount
		if D.equipment(record):
			if amount > 65536: return {"ok":false,"error":"물리 장비 묶음 지급 크기 초과"}
			var state: String = {1:"normal",2:"blessed",3:"cursed"}[bless]
			record["bless_state"] = state
			for index: int in range(amount):
				var uid: String = Crypto.new().generate_random_bytes(16).hex_encode()
				while instances.has(uid): uid = Crypto.new().generate_random_bytes(16).hex_encode()
				instances[uid] = {"name":str(record.name),"record":record.duplicate(true),"level":enchant,"element":"","element_level":0,"bless_state":state,"source_m_reward_proof":{"source_snapshot":"patch523","item_class_id":int(id),"source_item_class_id":int(id),"bless":bless,"enchant":enchant,"supplier":origin.duplicate(true)}}
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
