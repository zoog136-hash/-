extends RefCounted
# Safe, local TWILIGHT starter recipes. These are game-authored examples,
# not assertions of official L1J source crafting data.
const MAX_BATCH: int = 50
const RECIPES = {
	"hp_mid": {
		"title":"강력 회복 물약 조제",
		"output":"강력 HP 물약", "output_count":1, "gold":120,
		"materials":{"HP 물약":3}
	},
	"hp_blessed": {
		"title":"축복받은 회복 물약 조제",
		"output":"축복받은 HP 물약", "output_count":1, "gold":550,
		"materials":{"강력 HP 물약":3}
	}
}

static func quote(recipe_id: String, batch: int, inv: Dictionary, wallet: int, item_catalog: Dictionary, weights: Dictionary, carried_weight: int, capacity: int) -> Dictionary:
	if not RECIPES.has(recipe_id):
		return {"ok":false,"reason":"등록되지 않은 제작식입니다"}
	if batch < 1 or batch > MAX_BATCH:
		return {"ok":false,"reason":"제작 횟수가 유효하지 않습니다"}
	if wallet < 0 or carried_weight < 0 or capacity < 0:
		return {"ok":false,"reason":"제작 상태가 올바르지 않습니다"}
	var recipe: Dictionary = RECIPES[recipe_id]
	var output: String = str(recipe["output"])
	var records: Dictionary = item_catalog.get("by_name", {})
	if not records.has(output):
		return {"ok":false,"reason":"제작 결과 아이템이 게임 DB에 없습니다"}
	var result_record: Dictionary = records[output]
	if str(result_record.get("slot","")) != "consumable":
		return {"ok":false,"reason":"제작 결과 유형을 확인할 수 없습니다"}
	var total_cost: int = int(recipe["gold"]) * batch
	if wallet < total_cost:
		return {"ok":false,"reason":"제작 아데나가 부족합니다"}
	var consumed_weight: int = 0
	for raw: Variant in (recipe["materials"] as Dictionary).keys():
		var material: String = str(raw)
		var required: int = int(recipe["materials"][raw]) * batch
		if not records.has(material) or str(records[material].get("slot","")) != "consumable":
			return {"ok":false,"reason":"제작 재료 정보가 올바르지 않습니다"}
		if int(inv.get(material,0)) < required:
			return {"ok":false,"reason":"제작 재료가 부족합니다: " + material}
		consumed_weight += required * maxi(0,int(weights.get(material,3)))
	var result_count: int = int(recipe["output_count"]) * batch
	var projected_weight: int = carried_weight - consumed_weight + maxi(0,int(weights.get(output,3))) * result_count
	if projected_weight > capacity or projected_weight < 0:
		return {"ok":false,"reason":"제작 후 무게 한도를 초과합니다"}
	return {"ok":true,"output":output,"output_count":result_count,"gold":total_cost,"materials":recipe["materials"],"batch":batch}

static func execute(quote_result: Dictionary, inv: Dictionary, wallet: int) -> Dictionary:
	if not bool(quote_result.get("ok",false)):
		return {"ok":false,"reason":"제작 검증에 실패했습니다"}
	var total: int = int(quote_result.get("gold",-1))
	var output: String = str(quote_result.get("output",""))
	var quantity: int = int(quote_result.get("output_count",0))
	var batch: int = int(quote_result.get("batch",0))
	if total < 0 or quantity <= 0 or batch < 1 or batch > MAX_BATCH or wallet < total:
		return {"ok":false,"reason":"제작 거래가 유효하지 않습니다"}
	var materials: Dictionary = quote_result.get("materials",{})
	for raw: Variant in materials.keys():
		var required: int = int(materials[raw]) * batch
		if required < 1 or int(inv.get(raw,0)) < required:
			return {"ok":false,"reason":"제작 재료가 부족합니다"}
	# A no-await transaction; the caller MUST derive quote again against the
	# canonical RECIPES immediately before execute and must use its returned
	# wallet amount, not a UI-submitted quote.
	for raw: Variant in materials.keys():
		inv[raw] = int(inv.get(raw,0)) - int(materials[raw]) * batch
	inv[output] = int(inv.get(output,0)) + quantity
	return {"ok":true,"wallet":wallet-total,"output":output,"quantity":quantity}
