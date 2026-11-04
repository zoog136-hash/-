extends RefCounted
## Explicit TWILIGHT currency integration, not a name-based source-ID resolver.
const ITEM_NAMES := {3631:"명예 코인",3252:"마법인형 제작 코인",3242:"변신 제작 코인",246058:"성물 제작 코인",327824:"시련의 증표",327834:"혹독한 시련의 증표"}

static func count(value: Variant) -> int:
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < 0 or float(value) > 9000000000000000: return -1
	return int(value)

static func install_definitions(world: Node, rules: RefCounted) -> void:
	for id: int in [327824,327834]:
		var name: String = ITEM_NAMES[id]
		var existing := false
		for item: Dictionary in world.item_db:
			if item.get("name","") == name: existing = true
		if not existing and not rules.data.is_empty():
			world.item_db.append({"name":name,"type":"화폐","slot":"currency","grade":"일반","weight":0,"stackable":true,"droppable":false,"sellable":false,"source":"lineagem_current523","source_snapshot":"current523","sourceId":"m523:item:"+str(id),"source_item_class_id":id})

static func payment(world: Node, currency_id: int, amount: int) -> Dictionary:
	if amount < 1 or amount > 100000000: return {"ok":false,"reason":"재화 비용을 확인할 수 없습니다."}
	if currency_id == 174:
		var ain: Dictionary = world.ain_service.export_state().duplicate(true)
		if int(ain.blessing) < amount: return {"ok":false,"reason":"아인하사드가 부족합니다."}
		ain.blessing = int(ain.blessing) - amount
		return {"ok":true,"ainhasad_state":ain}
	if currency_id == 4:
		# Existing TWILIGHT Gem currency, not the separately typed Item549.
		var record: Dictionary = world._find_catalog_item_record("다이아")
		if record.get("slot","") != "currency" or count(world.inventory.get("다이아",0)) < amount: return {"ok":false,"reason":"다이아가 부족하거나 재화 정의가 다릅니다."}
		var inventory: Dictionary = world.inventory.duplicate(true)
		inventory["다이아"] = int(inventory["다이아"]) - amount
		if int(inventory["다이아"]) == 0: inventory.erase("다이아")
		return {"ok":true,"inventory":inventory}
	if currency_id != 764: return {"ok":false,"reason":"이 재화의 소모 경로를 확인할 수 없습니다."}
	# Item549 only. A name-only diamond or Item113892 must never pay Currency764.
	var candidates: Array[String] = []
	var name := ""
	for id: String in world.item_instances:
		var physical: Dictionary = world.item_instances[id]
		var record: Variant = physical.get("record",{})
		if not record is Dictionary: continue
		var source_id: Variant = record.get("source_item_class_id",0)
		if not (source_id is int or source_id is float) or float(source_id) != 549.0: continue
		if record.get("source","") != "lineagem_current523" or record.get("source_snapshot","") != "current523" or record.get("sourceId","") != "m523:item:549": continue
		if name.is_empty(): name = str(physical.get("name",""))
		if name.is_empty() or physical.get("name","") != name or count(physical.get("level",0)) != 0: continue
		candidates.append(id)
	if candidates.size() < amount or count(world.inventory.get(name,0)) < amount: return {"ok":false,"reason":"원본 ID가 확인된 드래곤의 다이아몬드가 부족합니다."}
	candidates.sort()
	var inventory: Dictionary = world.inventory.duplicate(true)
	var instances: Dictionary = world.item_instances.duplicate(true)
	for index: int in range(amount): instances.erase(candidates[index])
	inventory[name] = int(inventory[name]) - amount
	if int(inventory[name]) == 0: inventory.erase(name)
	return {"ok":true,"inventory":inventory,"item_instances":instances}

static func rewards(world: Node, rows: Array, payment_plan: Dictionary) -> Dictionary:
	var changes: Dictionary = payment_plan.duplicate(true)
	changes.erase("ok")
	var inventory: Dictionary = changes.get("inventory",world.inventory).duplicate(true)
	var gold: int = int(world.gold)
	var experience: int = int(world.experience)
	for reward: Dictionary in rows:
		var row: Dictionary = reward.row
		if row.get("ClanOnly",true) or row.get("UseImmediately",true) or int(row.get("CharacterClassID",-1)) != 0 or int(row.get("RewardEnhancementTypeID",0)) != 1 or int(row.get("ItemBlessCodeID",0)) != 1 or int(row.Amount) < 1: return {"ok":false,"reason":"이 보상 조건의 처리 경로를 확인할 수 없습니다."}
		if reward.type == "Exp" and int(row.RewardClassID) == 281:
			experience += int(row.Amount)
		elif reward.type == "Item":
			var id := int(row.RewardClassID)
			if id == 26:
				if reward.item.name != "아데나": return {"ok":false,"reason":"아데나 원본 식별이 다릅니다."}
				gold += int(row.Amount)
			elif ITEM_NAMES.has(id):
				var name: String = ITEM_NAMES[id]
				if reward.item.name != name: return {"ok":false,"reason":"보상 아이템 식별이 다릅니다."}
				var record: Dictionary = world._find_catalog_item_record(name)
				if record.is_empty() or record.get("slot","") != "currency": return {"ok":false,"reason":"보상 재화의 인벤토리 정의를 확인할 수 없습니다."}
				if id in [327824,327834] and (record.get("source_snapshot","") != "current523" or record.get("sourceId","") != "m523:item:"+str(id)): return {"ok":false,"reason":"시련의 증표 원본 ID 연결이 다릅니다."}
				if record.has("source_item_class_id") and int(record.source_item_class_id) != id: return {"ok":false,"reason":"기존 재화의 원본 ID와 다릅니다."}
				if count(inventory.get(name,0)) < 0: return {"ok":false,"reason":"기존 재화 수량을 확인할 수 없습니다."}
				inventory[name] = count(inventory.get(name,0)) + int(row.Amount)
			else: return {"ok":false,"reason":"이 보상 아이템의 지급 연결이 없습니다."}
		else: return {"ok":false,"reason":"이 보상 종류의 지급 연결이 없습니다."}
		if gold > 99999999999 or experience > 9000000000000000: return {"ok":false,"reason":"보상 저장 수량 한도를 초과합니다."}
	changes.merge({"ok":true,"inventory":inventory,"gold":gold,"experience":experience},true)
	return changes
