extends RefCounted
## Local promotion codes (TWILIGHT has no server). Each entry is redeemable
## without a use limit. The world applies the result and saves.

const DIAMOND_ITEM: String = "다이아"
const MAX_BALANCE: int = 9_000_000_000_000_000 # keep int64 sums from wrapping

const CODES: Dictionary = {
	"111": {"gold": 1_000_000, "diamond": 10_000},
}

static func normalize(raw: String) -> String:
	return raw.strip_edges().replace(" ", "").to_upper()

static func reward_for(raw: String) -> Dictionary:
	var code: String = normalize(raw)
	if code.is_empty() or not CODES.has(code):
		return {}
	return (CODES[code] as Dictionary).duplicate()

## Pure balance calculation; does not touch any game state.
static func apply(raw: String, gold: int, inventory: Dictionary) -> Dictionary:
	if normalize(raw).is_empty():
		return {"ok": false, "reason": "코드를 입력하세요"}
	var reward: Dictionary = reward_for(raw)
	if reward.is_empty():
		return {"ok": false, "reason": "올바르지 않은 코드입니다"}
	var gold_gain: int = int(reward.get("gold", 0))
	var diamond_gain: int = int(reward.get("diamond", 0))
	var diamonds: int = int(inventory.get(DIAMOND_ITEM, 0))
	return {
		"ok": true,
		"code": normalize(raw),
		"gold_gain": gold_gain,
		"diamond_gain": diamond_gain,
		"gold": mini(MAX_BALANCE, maxi(0, gold) + gold_gain),
		"diamond": mini(MAX_BALANCE, maxi(0, diamonds) + diamond_gain),
	}
