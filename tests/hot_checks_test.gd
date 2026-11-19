extends SceneTree
## Hot per-frame checks kept to the same results with less work:
## the SHA/CRC text rule (exact length, lower-case hex, no sign) and the boss
## HUD's cached list of boss slots (rebuilt when the slot list changes).
##   godot --headless --path <repo> --script res://tests/hot_checks_test.gd
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const BOSS_HUD = preload("res://scripts/monsters/boss_hud.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("HOT_CHECKS_FAIL: " + label)

class FakeController extends Node:
	var slots: Array[Dictionary] = []

func _initialize() -> void:
	var good: String = "0123456789abcdef".repeat(4)
	check(BANK.valid_sha(good), "lower-case 64 hex is a SHA-256")
	check(not BANK.valid_sha(good.to_upper()), "upper-case hex is refused")
	check(not BANK.valid_sha("+" + good.substr(1)) and not BANK.valid_sha("-" + good.substr(1)), "a sign is refused")
	check(not BANK.valid_sha(good.substr(1)) and not BANK.valid_sha(good + "0"), "wrong length is refused")
	check(not BANK.valid_sha(good.substr(0, 63) + "g") and not BANK.valid_sha(good.substr(0, 63) + " "), "a non-hex character is refused")
	check(not BANK.valid_sha("0x" + good.substr(2)) and not BANK.valid_sha(null) and not BANK.valid_sha(7), "prefix and non-strings are refused")
	check(BANK.valid_crc("00ff12ab") and not BANK.valid_crc("00FF12AB") and not BANK.valid_crc("00ff12a"), "CRC uses the same rule at 8 characters")
	var controller := FakeController.new()
	var hud = BOSS_HUD.new()
	hud.controller = controller
	controller.slots = [{"region": {"mode": "boss"}}, {"region": {"mode": "normal"}}, {"region": {}}]
	check(hud._boss_slots().size() == 1 and is_same(hud._boss_slots()[0], controller.slots[0]), "only boss slots are scanned")
	controller.slots.append({"region": {"mode": "boss"}})
	check(hud._boss_slots().size() == 2, "a grown slot list is rescanned")
	controller.slots.clear()
	controller.slots.append({"region": {"mode": "normal"}})
	controller.slots.append({"region": {"mode": "normal"}})
	controller.slots.append({"region": {"mode": "normal"}})
	controller.slots.append({"region": {"mode": "boss"}})
	check(hud._boss_slots().size() == 1 and is_same(hud._boss_slots()[0], controller.slots[3]), "a refilled list of the same size is rescanned")
	hud.free(); controller.free()
	print("HOT_CHECKS_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
