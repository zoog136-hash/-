extends RefCounted
class_name TwilightCardPackItems

# Six category-locked inventory consumables. TWILIGHT-authored SVG art follows
# the visual hierarchy of the Inven draw-ticket/11-card pack references; no
# third-party pixels or original-game artwork are redistributed.
const PACKS: Dictionary = {
	"최상급 변신 뽑기권": {"category": "변신", "count": 1, "image_path": "res://assets/card_packs/transformation_ticket.svg"},
	"최상급 변신 뽑기권 11회 팩": {"category": "변신", "count": 11, "image_path": "res://assets/card_packs/transformation_pack.svg"},
	"최상급 마법인형 뽑기권": {"category": "마법인형", "count": 1, "image_path": "res://assets/card_packs/doll_ticket.svg"},
	"최상급 마법인형 뽑기권 11회 팩": {"category": "마법인형", "count": 11, "image_path": "res://assets/card_packs/doll_pack.svg"},
	"최상급 성물 뽑기권": {"category": "성물", "count": 1, "image_path": "res://assets/card_packs/relic_ticket.svg"},
	"최상급 성물 뽑기권 11회 팩": {"category": "성물", "count": 11, "image_path": "res://assets/card_packs/relic_pack.svg"}
}

static func definition(item_name: String) -> Dictionary:
	return (PACKS.get(item_name, {}) as Dictionary).duplicate()

static func is_pack(item_name: String) -> bool:
	return PACKS.has(item_name)

static func inventory_record(item_name: String) -> Dictionary:
	var spec: Dictionary = definition(item_name)
	if spec.is_empty():
		return {}
	return {
		"name": item_name,
		"slot": "consumable",
		"type": "뽑기권",
		"grade": "희귀",
		"image_path": str(spec["image_path"]),
		"desc": "%s 카드 %d회 뽑기 · 사용 시 즉시 결과 확인" % [str(spec["category"]), int(spec["count"])]
	}
