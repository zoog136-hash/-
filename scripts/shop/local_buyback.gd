extends RefCounted
# Local TWILIGHT buyback valuations, NOT source L1J prices.
# Exact physical instance IDs are checked before destroying equipment.
const MAX_STACK_SALE: int = 99
const GRADE_BUYBACK = {"일반":40,"고급":200,"희귀":800,"영웅":4500,"전설":10000,"신화":30000,"유일":80000}

static func _is_equipped(instance_id: String, equipped: Dictionary) -> bool:
	for raw: Variant in equipped.values():
		if raw is Dictionary and str((raw as Dictionary).get("instance_id","")) == instance_id:
			return true
	return false

static func quote(item_name: String, quantity: int, instance_id: String, inventory: Dictionary, records: Dictionary, physical: Dictionary, equipped: Dictionary, wallet: int) -> Dictionary:
	if quantity < 1 or quantity > MAX_STACK_SALE:
		return {"ok":false,"reason":"판매 수량이 유효하지 않습니다"}
	if wallet < 0 or not records.has(item_name):
		return {"ok":false,"reason":"판매할 수 없는 아이템입니다"}
	if item_name == "아데나" or item_name.contains("각인"):
		return {"ok":false,"reason":"재화·각인 아이템은 매입하지 않습니다"}
	var record: Dictionary = records[item_name]
	var slot: String = str(record.get("slot",""))
	if slot.is_empty() or slot == "currency" or not bool(record.get("tradeable",true)) or bool(record.get("bound",false)) or bool(record.get("quest_item",false)):
		return {"ok":false,"reason":"판매가 제한된 아이템입니다"}
	if int(inventory.get(item_name,0)) < quantity:
		return {"ok":false,"reason":"판매할 수량이 부족합니다"}
	var is_equipment: bool = slot != "consumable"
	var enhancement: int = 0
	if is_equipment:
		if quantity != 1 or instance_id.is_empty() or not physical.has(instance_id):
			return {"ok":false,"reason":"장비는 고유 ID를 지정해 한 개씩 판매해야 합니다"}
		var instance: Dictionary = physical[instance_id]
		if str(instance.get("name","")) != item_name or _is_equipped(instance_id,equipped):
			return {"ok":false,"reason":"장착 장비 또는 다른 아이템은 판매할 수 없습니다"}
		enhancement = clampi(int(instance.get("level",0)),0,20)
	elif not instance_id.is_empty():
		return {"ok":false,"reason":"소모품에 장비 ID를 사용할 수 없습니다"}
	var unit_price: int = int(GRADE_BUYBACK.get(str(record.get("grade","일반")),0))
	if unit_price <= 0:
		return {"ok":false,"reason":"아이템 매입가가 정의되지 않았습니다"}
	# The priced instance is the exact instance removed, not a different
	# item with the same name and a higher or lower enchantment.
	var payment: int = unit_price * quantity + enhancement * unit_price / 10
	if payment <= 0 or wallet > 9000000000000000000 - payment:
		return {"ok":false,"reason":"판매 금액이 허용 범위를 초과합니다"}
	return {"ok":true,"item_name":item_name,"quantity":quantity,"instance_id":instance_id,"payment":payment,"enhancement":enhancement}

static func apply(valid_quote: Dictionary, inventory: Dictionary, physical: Dictionary, wallet: int) -> Dictionary:
	if not bool(valid_quote.get("ok",false)):
		return {"ok":false,"reason":"매입 거래가 승인되지 않았습니다"}
	var item_name: String = str(valid_quote.get("item_name",""))
	var quantity: int = int(valid_quote.get("quantity",0))
	var instance_id: String = str(valid_quote.get("instance_id",""))
	var payment: int = int(valid_quote.get("payment",0))
	if quantity < 1 or quantity > MAX_STACK_SALE or payment < 1 or wallet < 0 or int(inventory.get(item_name,0)) < quantity:
		return {"ok":false,"reason":"아이템 수량이나 금액이 변경되었습니다"}
	if not instance_id.is_empty():
		if quantity != 1 or not physical.has(instance_id) or str((physical[instance_id] as Dictionary).get("name","")) != item_name:
			return {"ok":false,"reason":"판매할 장비 개체를 찾지 못했습니다"}
		physical.erase(instance_id)
	inventory[item_name] = int(inventory.get(item_name,0)) - quantity
	return {"ok":true,"wallet":wallet+payment,"payment":payment,"quantity":quantity}
