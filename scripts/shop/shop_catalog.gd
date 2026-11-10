extends RefCounted
# Server-authoritative price and quantity policy. Values are TWILIGHT's
# local shop prices, not claims about official Lineage prices.
const MAX_QUANTITY: int = 1000
const REVIEWED = preload("res://addons/twilight_l1j/twilight_reviewed_shops.gd")
const STOCK = preload("res://scripts/shop/consumable_stock.gd")
# Pre-November local goods are not sold (user decision 2026-11-10); the shop
# sells only the original 523 shop tables (source523_shop_catalog.gd).
const LEGACY_GOODS: Array = []
# UI and transaction validation share the exact same (empty) registry.
static var GOODS: Array = []

static func price_for(item_name: String) -> int:
	for entry: Array in GOODS:
		if str(entry[0]) == item_name:
			return int(entry[1])
	return -1

# This check is repeated when the transaction executes; UI quotes have no
# authority. Counts are bounded before multiplication.
static func quote(item_name: String, quantity: int, wallet: int, carried_weight: int, capacity: int, unit_weight: int) -> Dictionary:
	var unit_price: int = price_for(item_name)
	return _quote_at_price(item_name, unit_price, quantity, wallet, carried_weight, capacity, unit_weight)

static func quote_reviewed(vendor_id: String, item_name: String, quantity: int, catalog: Array, wallet: int, carried_weight: int, capacity: int, unit_weight: int) -> Dictionary:
	var offer: Dictionary = REVIEWED.offer_for(vendor_id, item_name, catalog)
	if offer.is_empty(): return {"ok":false, "reason":"상점에 등록되지 않은 아이템입니다"}
	var result: Dictionary = _quote_at_price(item_name, int(offer.price), quantity, wallet, carried_weight, capacity, unit_weight)
	if bool(result.get("ok", false)): result["offer"] = offer
	return result

static func _quote_at_price(item_name: String, unit_price: int, quantity: int, wallet: int, carried_weight: int, capacity: int, unit_weight: int) -> Dictionary:
	if unit_price <= 0:
		return {"ok":false, "reason":"판매하지 않는 상품입니다"}
	if quantity < 1 or quantity > MAX_QUANTITY:
		return {"ok":false, "reason":"구매 수량이 유효하지 않습니다"}
	if wallet < 0 or carried_weight < 0 or capacity < 0 or unit_weight < 0:
		return {"ok":false, "reason":"거래 상태가 유효하지 않습니다"}
	if item_name == "드래곤의 용옥" and quantity != 1:
		return {"ok":false, "reason":"드래곤의 용옥은 한 번에 1개만 구매할 수 있습니다"}
	var total: int = unit_price * quantity
	if wallet < total:
		return {"ok":false, "reason":"아데나가 부족합니다"}
	if carried_weight + unit_weight * quantity > capacity:
		return {"ok":false, "reason":"무게 한도를 초과합니다"}
	return {"ok":true, "total":total, "unit_price":unit_price, "quantity":quantity}
