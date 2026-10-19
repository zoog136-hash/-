extends SceneTree

const Cards = preload("res://scripts/card_draw_fusion.gd")
const Tickets = preload("res://scripts/card_pack_items.gd")

func _initialize() -> void:
	var expected: Dictionary = {
		"최상급 변신 뽑기권": ["변신", 1],
		"최상급 변신 뽑기권 11회 팩": ["변신", 11],
		"최상급 마법인형 뽑기권": ["마법인형", 1],
		"최상급 마법인형 뽑기권 11회 팩": ["마법인형", 11],
		"최상급 성물 뽑기권": ["성물", 1],
		"최상급 성물 뽑기권 11회 팩": ["성물", 11]
	}
	if Tickets.PACKS.size() != 6:
		_fail("ticket item count")
		return
	var catalog: Dictionary = {}
	for category: String in Cards.CATEGORIES:
		var cards: Array = []
		for grade: String in Cards.DRAW_ORDER:
			cards.append({"sourceId": category + "-" + grade, "name": grade, "grade": grade})
		catalog[category] = cards
	var service = Cards.new()
	service.configure(catalog)
	for item_name: String in expected:
		var definition: Dictionary = Tickets.definition(item_name)
		var values: Array = expected[item_name]
		if str(definition.get("category", "")) != str(values[0]) or int(definition.get("count", 0)) != int(values[1]):
			_fail("bad ticket definition: " + item_name)
			return
		var outcome: Dictionary = service.draw_cards(str(values[0]), int(values[1]))
		if not bool(outcome.get("ok", false)) or (outcome.get("results", []) as Array).size() != int(values[1]):
			_fail("draw count: " + item_name)
			return
		for entry: Variant in outcome.get("results", []):
			if not (entry is Dictionary):
				_fail("invalid result record")
				return
			if not str((entry as Dictionary).get("id", "")).begins_with("source:" + str(values[0]) + "-"):
				_fail("category leakage: " + item_name)
				return
	if bool(service.draw_cards("변신", 2).get("ok", false)):
		_fail("unsupported count accepted")
		return
	if Tickets.is_pack("가짜 뽑기권"):
		_fail("unknown ticket accepted")
		return
	print("CARD_PACK_ITEMS_OK")
	quit(0)

func _fail(message: String) -> void:
	push_error("CARD_PACK_ITEMS_FAIL: " + message)
	quit(1)
