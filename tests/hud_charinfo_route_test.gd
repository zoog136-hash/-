extends SceneTree
## The HUD top-left character area opens the original character window
## (CharacterInfo_All: equipped slots + 스탯 정보 tab) from both of its
## original buttons (user list 2026-11-26 #15: "왼쪽 위 레벨·체력 등이 있는
## 곳을 누르면 착용 장비와 능력치"). Hud_CharInfo authors Btn_FloatingInven
## (20060, the class/level badge, 0..70) and Btn_Status (20552, the HP/MP
## bars, 60..296); FloatingUiScene places CharacterInfo_All_Layout for them.
## The bag stays on Hud_TopMenu Btn_Inventory. Neither button reaches the
## TWILIGHT potion slot to the right of the bars (#800, long press): the
## buttons keep their authored rectangles.
##   godot --headless --path <repo> --script res://tests/hud_charinfo_route_test.gd
const VITALS = preload("res://scripts/ui/original_ui/source_main_vitals_bindings.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("HUD_CHARINFO_ROUTE_FAIL: " + label)

class FakePack extends RefCounted:
	var manifest: Dictionary = {}

class FakeHud extends Node:
	signal inventory_pressed
	var opened: int = 0
	var bag: int = 0
	func open_character() -> void: opened += 1
	func _init() -> void: inventory_pressed.connect(func() -> void: bag += 1)

func _initialize() -> void:
	var pack := FakePack.new()
	pack.manifest = {"files":{VITALS.CHAR_MEMBER:{"sha256":VITALS.CHAR_SHA256}}}
	var hud := FakeHud.new()
	root.add_child(hud)
	var contract: Dictionary = VITALS.build_char_info(pack, hud, {"hp":5,"max_hp":10,"mp":1,"max_mp":2,"level":3})
	check(contract.get("ok", false), "fixture Hud_CharInfo contract: " + str(contract.get("code", "")))
	if contract.get("ok", false):
		for offset: int in [20552, 20060]:
			check(contract.source_node_offsets.has(offset), "original button %d is mounted" % offset)
			var before: int = hud.opened
			var result: Dictionary = (contract.bindings[offset].activate as Callable).call()
			check(result.get("ok", false) and hud.opened == before + 1, "original button %d opens the character window" % offset)
		check(hud.bag == 0, "the top-left area does not open the bag")
	hud.free()
	print("HUD_CHARINFO_ROUTE_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
