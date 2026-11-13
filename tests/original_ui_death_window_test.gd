extends SceneTree
## Original 523 사망 복구 window (source_main_death_window, DeathPenalty_All).
## Synthetic (no original files): the window names the client CSBs, fails
## closed without the pack or without the rule ZIP, lists the tab's unclaimed
## losses newest first and drops expired ones, and the death runtime opens the
## original window first and keeps its panel otherwise.
const DEATH=preload("res://scripts/ui/original_ui/source_main_death_window.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

class FakeSource extends RefCounted:
	var ready: bool=false

class FakeService extends RefCounted:
	var source:=FakeSource.new()
	var state: Dictionary={"records":[]}
	var clock: int=1000000
	func now() -> int:
		return clock

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_DEATH_WINDOW_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(DEATH.ROOT=="UI/FloatingUi/DeathPenalty_All.csb" and DEATH.ROW_EXP=="UI/FloatingUi/DeathPenalty_List_ExpRecovery.csb" and DEATH.ROW_ITEM=="UI/FloatingUi/DeathPenalty_List_ItemRecovery.csb","the window names the client's DeathPenalty members")
	check(DEATH.REQUIRED.has("UI/FloatingUi/DeathPenalty_List_Empty.csb") and DEATH.REQUIRED.has("UI/FloatingUi/DeathPenalty_List_Lock.csb"),"free and expansion rows are the original Empty / Lock rows")
	var pack:=FakePack.new()
	var host:=Node.new()
	var configured: Dictionary=DEATH.new().configure(pack,host)
	check(not configured.get("ok",true) and configured.get("code")=="source_death_window_member_missing","the window fails closed without its CSBs")
	for member: String in DEATH.REQUIRED:pack.manifest.scenes[member]={}
	var window=DEATH.new()
	check(window.configure(pack,host).get("ok",false),"a pack with every member configures")
	var service:=FakeService.new()
	check(window.open(host,service).get("code")=="source_death_window_rules_not_installed","without the rule ZIP the panel keeps the death recovery")
	# Rows: unclaimed, within 72 hours, newest first, items only with a lost item.
	var at: int=service.clock
	service.state.records=[
		{"id":"1","at":at-300000,"exp":10,"exp_claimed":false,"item":{},"item_claimed":true},
		{"id":"2","at":at-90000,"exp":20,"exp_claimed":false,"item":{"id":"p2","physical":{"name":"a"}},"item_claimed":false},
		{"id":"3","at":at-100,"exp":30,"exp_claimed":true,"item":{"id":"p3","physical":{"name":"b"}},"item_claimed":false},
		{"id":"4","at":at-50,"exp":40,"exp_claimed":false,"item":{},"item_claimed":true}]
	window.set("_service",service)
	window.set("_tab","exp")
	var exp_rows: Array=window.call("_rows")
	check(exp_rows.map(func(r: Dictionary) -> String: return str(r.id))==["4","2"],"experience rows: unclaimed, not expired, newest first")
	window.set("_tab","item")
	var item_rows: Array=window.call("_rows")
	check(item_rows.map(func(r: Dictionary) -> String: return str(r.id))==["3","2"],"item rows: only losses with an item")
	check(int(item_rows[1].age)==90000,"a row keeps its age for the 24 / 72 hour windows")
	check(DEATH._number(123567890)=="123,567,890","costs are grouped like the client's text")
	host.free()
	var runtime_text: String=FileAccess.get_file_as_string("res://scripts/death/runtime.gd")
	check(runtime_text.contains("try_open_death_window(self)") and runtime_text.contains("recovery_ui.gd"),"the death runtime opens the original window first and keeps its panel")
	var main_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(main_text.contains("func try_open_death_window") and main_text.contains("func close_death_window"),"the original UI controller opens and closes the window")
	var hud_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.contains("close_death_window()"),"closing the workspace closes the original window")
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_death_window.gd")
	check(text.contains("_service.recover(") and text.contains("_service.expand_slot(") and text.contains("confirm_action"),"recovery and slot expansion run the existing transactions behind the existing confirmation")
	check(not text.contains("Image.create") and not text.contains("draw_rect"),"no picture is drawn")
	print("ORIGINAL_UI_DEATH_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
