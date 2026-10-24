extends RefCounted
class_name TwilightCardPackItems

# Six category-locked physical inventory items. Never ask the user to choose
# a category when consuming one of these items.
const PACKS: Dictionary = {
	"최상급 변신 뽑기권": {"category": "변신", "count": 1},
	"최상급 변신 뽑기권 11회 팩": {"category": "변신", "count": 11},
	"최상급 마법인형 뽑기권": {"category": "마법인형", "count": 1},
	"최상급 마법인형 뽑기권 11회 팩": {"category": "마법인형", "count": 11},
	"최상급 성물 뽑기권": {"category": "성물", "count": 1},
	"최상급 성물 뽑기권 11회 팩": {"category": "성물", "count": 11}
}

static func definition(item_name: String) -> Dictionary:
	return (PACKS.get(item_name, {}) as Dictionary).duplicate()

static func is_pack(item_name: String) -> bool:
	return PACKS.has(item_name)
