extends SceneTree
## Original 523 skill window (source_main_skill_window, Skill_All) and the
## original-window fallback report. Synthetic (no original files): the window
## names the client CSBs and fails closed without them, the HUD opens it
## first and keeps the existing skills window for details and without the
## pack, a bag item without an original picture no longer sends the whole
## original bag back, and every fallback is logged with a readable reason.
const SKILL=preload("res://scripts/ui/original_ui/source_main_skill_window.gd")
const HUD=preload("res://scripts/ui/renewal_hud.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_SKILL_WINDOW_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(SKILL.ROOT=="UI/FloatingUi/Skill_All.csb" and SKILL.SLOT=="UI/MainFloating/Slot_Skill.csb" and SKILL.TAB=="UI/FloatingUi/Skill_Tab_Btn.csb","the window names the client's Skill_All members")
	var host:=Node.new()
	var result: Dictionary=SKILL.new().configure(FakePack.new(),host)
	check(not result.get("ok",true) and result.get("code")=="source_skill_window_member_missing","the window fails closed without its CSBs")
	host.free()
	check(SKILL._id({"id":"a","name":"b"})=="a" and SKILL._id({"name":"b"})=="b","skills are keyed like the existing window")
	check(HUD._original_fallback_text("source_ui_addon_not_selected").contains("추가 리소스"),"a missing UI add-on is named")
	check(HUD._original_fallback_text("source_main_inventory_identity_mismatch")==HUD.OUTDATED_UI_ADDON_TEXT and HUD._original_fallback_text("source_skill_window_member_missing")==HUD.OUTDATED_UI_ADDON_TEXT,"an older UI add-on (missing member or different Inventory_All) asks for an update")
	check(HUD._original_fallback_text("x_unknown")=="x_unknown" and HUD._original_fallback_text("")=="사유 미상","unknown codes are shown as they are")
	var hud_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.contains("try_open_skill_window()") and hud_text.contains("func open_skills_workspace"),"skills open the original window first and keep the existing one")
	check(hud_text.contains("_report_original_fallback(\"가방\""),"a bag fallback is reported")
	check(hud_text.contains("print(\"ORIGINAL_UI_FALLBACK \""),"fallbacks reach the log")
	var slots_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
	check(slots_text.contains("owned_original_icon_unavailable") and not slots_text.contains("\"code\":\"source_inventory_slots_owned_icon_unavailable\""),"an item without an original picture keeps an empty original slot")
	var main_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(main_text.contains("_inventory_configure_problem"),"the inventory configure reason is kept for the fallback")
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_skill_window.gd")
	check(not text.contains("Image.create") and not text.contains("draw_rect"),"no picture is drawn")
	print("ORIGINAL_UI_SKILL_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
