extends SceneTree
## The original 아인하사드의 축복 tooltip (Hud_BlessPoint Nd_Tooltip) shows the
## existing 드래곤의 용옥 timer in its own 드래곤의 보호 rows
## (Text_List_Buff_On / Text_List_Buff_Off), beside the 경험치 / 아데나 rates.
## Synthetic (no original files): the contract names the original offsets,
## the on row carries the remaining days and the off row the client's words.
const BLESSING = preload("res://scripts/ui/original_ui/source_main_blessing_bindings.gd")
var checks: int = 0
var failures: Array[String] = []

class FakePack extends RefCounted:
	var manifest: Dictionary = {"files":{
		BLESSING.WALLET:{"sha256":BLESSING.WALLET_SHA},
		BLESSING.MEMBER:{"sha256":BLESSING.SHA256},
		BLESSING.SLOT:{"sha256":BLESSING.SLOT_SHA}},"node_scopes":{}}

class FakeHud extends Node:
	var v20_ain_state: Dictionary = {}
	var v20_leaf_button: Button
	var v20_ain_panel: Control
	func _toggle_ain_window() -> void: v20_ain_panel.visible = not v20_ain_panel.visible

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_BLESSING_TOOLTIP_FAIL: ", label)

func _initialize() -> void:
	check(BLESSING.buff_text(0) == "드래곤의 보호 버프 없음", "no timer reads the client's off row")
	check(BLESSING.buff_text(20 * 86400 + 5) == "드래곤의 보호 버프 적용 중 (20일)", "days as the client's row reads")
	check(BLESSING.buff_text(7200) == "드래곤의 보호 버프 적용 중 (2시간)", "under a day in hours")
	var hud := FakeHud.new()
	hud.v20_leaf_button = Button.new(); hud.add_child(hud.v20_leaf_button)
	hud.v20_ain_panel = Control.new(); hud.add_child(hud.v20_ain_panel)
	hud.v20_ain_panel.visible = true
	hud.v20_ain_state = {"blessing":1200,"exp_rate":4.0,"adena_rate":1.5,"dragon_orb_remaining":3 * 86400}
	root.add_child(hud)
	var built: Dictionary = BLESSING.build(FakePack.new(), hud)
	check(built.get("ok", false), "the blessing contract builds: " + str(built).left(200))
	if built.get("ok", false):
		var inner: Dictionary = built.bindings[BLESSING.PROJECT]
		var scope: Array = inner.source_node_offsets
		check(scope.has(BLESSING.BUFF_ON) and scope.has(BLESSING.BUFF_OFF), "the 드래곤의 보호 rows are in the tooltip scope")
		var on: Dictionary = inner.bindings.get(BLESSING.BUFF_ON, {})
		var off: Dictionary = inner.bindings.get(BLESSING.BUFF_OFF, {})
		check(on.get("role") == "source_text" and on.get("text") == "드래곤의 보호 버프 적용 중 (3일)" and on.get("visible") == true and off.get("visible") == false, "an active 용옥 shows the on row with its days")
		check(str(inner.bindings[4560].text) == "400%" and str(inner.bindings[4232].text) == "150%", "the rates stay the existing HUD conversion")
	hud.v20_ain_state = {"blessing":1200,"exp_rate":4.0,"adena_rate":1.5,"dragon_orb_remaining":0}
	var idle: Dictionary = BLESSING.build(FakePack.new(), hud)
	if idle.get("ok", false):
		var rows: Dictionary = idle.bindings[BLESSING.PROJECT].bindings
		check(rows[BLESSING.BUFF_ON].visible == false and rows[BLESSING.BUFF_OFF].visible == true, "no 용옥 shows the off row")
	hud.queue_free()
	print("ORIGINAL_UI_BLESSING_TOOLTIP_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
