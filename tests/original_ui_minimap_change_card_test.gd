extends SceneTree
## User list 2026-11-21 #2: 카드 다시 뽑기 as the original 카드 교체 button
## (Hud_ChangeCard) beside the minimap, in Set_R_Top_MiniMapLayout's
## Nd_Side_Btn group where the client places it. Synthetic (no original
## files): the minimap name contract carries the side group, the project with
## its button / icon / label only, and the button routes to card_swap523; a
## pack without the member keeps the plain name contract; the HUD retries
## the map name without the button if it ever fails.
const MAP = preload("res://scripts/ui/original_ui/source_main_map_bindings.gd")
var checks: int = 0
var failures: Array[String] = []

class FakePack extends RefCounted:
	var with_card: bool = true
	var manifest: Dictionary = {}
	func _init(card: bool) -> void:
		with_card = card
		manifest = {"files":{MAP.MINIMAP_MEMBER:{"sha256":MAP.MINIMAP_SHA256}},"scenes":{MAP.MINIMAP_MEMBER:{}}}
		if card: manifest.scenes[MAP.CHANGE_CARD_MEMBER] = {}
	func scene(member: String) -> Dictionary:
		if member != MAP.MINIMAP_MEMBER: return {}
		var side: Dictionary = {"_offset":MAP.SIDE_GROUP,"classname":"SingleNode","children":[{"_offset":MAP.CHANGE_CARD_PROJECT,"classname":"ProjectNode","children":[]}]}
		return {"nodeTree":{"_offset":172,"children":[{"_offset":MAP.MAP_NAME_TEXT,"children":[]},side]}}

class FakeHud extends Node:
	signal map_pressed
	var routed: Array[String] = []
	func _navigate(section: String) -> void: routed.append(section)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_MINIMAP_CHANGE_CARD_FAIL: " + label)

func _initialize() -> void:
	var hud := FakeHud.new()
	root.add_child(hud)
	var map = MAP.new()
	check(map.configure(FakePack.new(true), hud).get("ok", false), "the minimap bindings configure")
	var contract: Dictionary = map.build_name("기란 마을")
	check(contract.get("ok", false) and bool(contract.get("change_card_connected", false)), "the name contract carries 카드 교체: " + str(contract).left(200))
	var scope: Array = contract.get("source_node_offsets", [])
	check(scope.has(MAP.SIDE_GROUP) and scope.has(MAP.CHANGE_CARD_PROJECT) and scope.has(MAP.MAP_NAME_TEXT), "side group + Hud_ChangeCard in the minimap scope")
	var project: Dictionary = contract.bindings.get(MAP.CHANGE_CARD_PROJECT, {})
	check(project.get("role") == "project" and project.get("visible") == true and project.get("source_node_offsets") == MAP.CHANGE_CARD_SCOPE, "the authored-hidden button is shown with its button / icon / label only")
	var button: Dictionary = project.get("bindings", {}).get(MAP.CHANGE_CARD_BUTTON, {})
	check(button.get("role") == "button" and button.activate.call().get("routed") == "card_swap523" and hud.routed == ["card_swap523"], "the button opens 카드 다시 뽑기")
	var plain: Dictionary = map.build_name("기란 마을", true, false)
	check(not bool(plain.get("change_card_connected", true)) and not plain.source_node_offsets.has(MAP.CHANGE_CARD_PROJECT), "the name-only retry leaves the button out")
	var old_pack = MAP.new()
	old_pack.configure(FakePack.new(false), hud)
	check(not bool(old_pack.build_name("기란 마을").get("change_card_connected", true)), "a UI pack without Hud_ChangeCard keeps the name contract")
	var main_hud: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(main_hud.contains("name_contract=_map_bindings.build_name(map_name,true,false)"), "the HUD retries the map name without the button")
	hud.queue_free()
	print("ORIGINAL_UI_MINIMAP_CHANGE_CARD_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
