extends SceneTree
## Synthetic manifest and HUD host. No installed original pack is needed.
const ORIGINAL_HUD := "res://scripts/ui/original_ui/source_main_hud.gd"
const LOCAL_SHOP := "res://scripts/ui/renewal_shop.gd"
const NATIVE_SHOP := "res://scripts/ui/original_ui/source_main_shop_window.gd"
const NATIVE_QUEST := "res://scripts/ui/original_ui/source_main_quest_window.gd"
const NATIVE_CHANGE := "res://scripts/ui/original_ui/source_main_change_window.gd"
const MAIN_MEMBER := "UI/MainScene.csb"
const MAIN_SHA := "80c174a87caf5cfbf910336b64616334ac560ed477f7a663aec58ada70d4285f"

class FixtureHud extends Node:
	var workspace_closes := 0

	func _close_workspace() -> void:
		workspace_closes += 1

class FixturePack extends RefCounted:
	var manifest_sha256 := ""
	var manifest := {
		"files": {MAIN_MEMBER: {"sha256": MAIN_SHA}},
		"scenes": {"UI/Shop/Shop_All.csb": {}, "UI/Shop/Shop_Tab_List.csb": {}, "UI/Shop/Shop_List_Slot.csb": {},
			"UI/Quest/Quest_All.csb": {}, "UI/Quest/Quest_Tab_Main.csb": {}, "UI/Quest/Quest_List_Reward.csb": {},
			"UI/Quest/Quest_List_Progress.csb": {}, "UI/Quest/Quest_List_Complete.csb": {}, "UI/Quest/Quest_Slot_Set.csb": {}},
	}

	func scene(member: String) -> Dictionary:
		if member != MAIN_MEMBER: return {}
		return {"_source_sha256": MAIN_SHA, "nodeTree": {"options": {"size": [1200, 675]}}}

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _run() -> void:
	var main := load("res://Main.tscn") as PackedScene
	_check(main != null, "Main can prepare before the roster")
	_check(not ResourceLoader.has_cached(ORIGINAL_HUD), "Main preparation leaves the unselected original HUD cold")
	_check(not ResourceLoader.has_cached(LOCAL_SHOP), "Main preparation leaves the local shop cold")

	var hud := FixtureHud.new()
	root.add_child(hud)
	var canvas := Control.new()
	canvas.name = "Root"
	hud.add_child(canvas)
	var controller: Node = load(ORIGINAL_HUD).new()
	hud.add_child(controller)
	var pack := FixturePack.new()
	_check(controller.configure(pack, hud, canvas).get("ok", false), "native HUD configures with fixture sections")
	for path: String in [NATIVE_SHOP, NATIVE_QUEST, NATIVE_CHANGE]:
		_check(not ResourceLoader.has_cached(path), "native HUD leaves this window cold: " + path)
	_check(not controller.shop_window_is_open() and not controller.quest_window_is_open(), "visibility checks do not prepare optional windows")
	_check(not ResourceLoader.has_cached(NATIVE_SHOP) and not ResourceLoader.has_cached(NATIVE_QUEST), "windows remain cold after visibility checks")

	_check(controller.can_open_shop_window(), "first shop request checks and prepares all its declared members")
	var shop: RefCounted = controller.get("_shop_window")
	_check(shop != null and ResourceLoader.has_cached(NATIVE_SHOP), "shop is loaded and retained after the first request")
	_check(controller.can_open_shop_window() and is_same(shop, controller.get("_shop_window")), "later shop requests reuse the configured view")
	var quest: Dictionary = controller.try_open_quest_window(null, Callable())
	_check(quest.get("code") == "source_quest_window_host_unavailable" and controller.get("_quest_window") != null, "first quest request reaches the authored view after checking its members")
	_check(hud.workspace_closes == 0, "preparing a window leaves workspace state alone")
	if shop != null: shop.emit_signal("closed")
	_check(hud.workspace_closes == 1, "the lazily connected close signal reaches its normal workspace owner")

	var change: Dictionary = controller.try_open_change_window("변신")
	_check(change.get("code") == "source_change_window_pack_scope_unavailable" and controller.get("_change_window") == null, "missing change scope falls back")
	_check(controller.try_open_change_window("변신") == change, "repeated requests retain the same missing-scope result")
	controller.release()
	hud.queue_free()
	await process_frame
	print("STARTUP_OPTIONAL_UI_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
