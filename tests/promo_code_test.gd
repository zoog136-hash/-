extends SceneTree
const PROMO = preload("res://scripts/promo/promo_codes.gd")
const VIEW = preload("res://scripts/ui/promo_code_view.gd")
const SIDE_UI = preload("res://scripts/ui/lineage_side_ui.gd")

var failures: int = 0

class FakeWorld:
	extends RefCounted
	var gold: int = 5
	var inventory: Dictionary = {}
	func redeem_promo_code(code: String) -> Dictionary:
		var result: Dictionary = PROMO.apply(code, gold, inventory)
		if bool(result.get("ok", false)):
			gold = int(result.gold)
			inventory[PROMO.DIAMOND_ITEM] = int(result.diamond)
		return result

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		print("PROMO_CODE_FAIL: ", label)

func _initialize() -> void:
	var first: Dictionary = PROMO.apply("111", 0, {})
	_check(bool(first.ok) and int(first.gold) == 1_000_000 and int(first.diamond) == 10_000, "111 grants 1,000,000 adena and 10,000 diamonds")
	var again: Dictionary = PROMO.apply(" 1 1 1 ", int(first.gold), {"다이아": int(first.diamond)})
	_check(bool(again.ok) and int(again.gold) == 2_000_000 and int(again.diamond) == 20_000, "111 is reusable and spaces are ignored")
	_check(not bool(PROMO.apply("112", 0, {}).ok), "unknown code is rejected")
	_check(str(PROMO.apply("   ", 0, {}).reason) == "코드를 입력하세요", "empty input asks for a code")
	var capped: Dictionary = PROMO.apply("111", PROMO.MAX_BALANCE, {"다이아": PROMO.MAX_BALANCE})
	_check(int(capped.gold) == PROMO.MAX_BALANCE and int(capped.diamond) == PROMO.MAX_BALANCE, "balances cap instead of overflowing")
	_check(SIDE_UI.MENU_ITEMS.any(func(row: Array) -> bool: return str(row[0]) == "promo_code"), "side menu has the promo code entry")

	var fake := FakeWorld.new()
	var view = VIEW.new()
	root.add_child(view)
	view.configure(fake)
	for attempt: int in range(3):
		view.code_input.text = "111"
		view.redeem_button.pressed.emit()
	_check(fake.gold == 3_000_005 and int(fake.inventory.get("다이아", 0)) == 30_000, "UI redeems 111 three times")
	_check(view.code_input.text.is_empty() and view.status.text.begins_with("지급 완료"), "UI clears input and reports success")
	view.code_input.text = "abc"
	view.redeem_button.pressed.emit()
	_check(view.status.text == "올바르지 않은 코드입니다" and fake.gold == 3_000_005, "UI rejects a wrong code without paying")
	view.queue_free()

	print("PROMO_CODE_TEST failures=%d" % failures)
	quit(0 if failures == 0 else 1)
