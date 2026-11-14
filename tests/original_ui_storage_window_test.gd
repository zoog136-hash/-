extends SceneTree
## Original 523 창고 (source_main_storage_window). Synthetic (no original
## files): the window names the client's Storage members and fails closed
## without them, filters the warehouse screen's rows by tab, labels amounts,
## builds the transfer references, asks 보관 / 찾기 through the existing screen,
## and the HUD opens it before the TWILIGHT warehouse list.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_storage_window.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

class FakeScreen extends RefCounted:
	var calls: Array=[]
	func request_drop(reference: String) -> void:calls.append(["drop",reference])
	func request_withdraw(reference: String) -> void:calls.append(["withdraw",reference])

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_STORAGE_WINDOW_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(WINDOW.ROOT=="UI/Storage/Storage_All.csb" and WINDOW.BAG=="UI/Storage/Storage_Inventory.csb" and WINDOW.STORE=="UI/Storage/Storage_AccountInvGridMode.csb","the window names the client's storage members")
	check(WINDOW.SET=="UI/FloatingUi/Inventory_Slot_Set.csb","both grids use Inventory_Slot_Set lines (QuickSlotEdit_SlotSet is absent)")
	check(WINDOW.LAYOUT_POSITION==Vector2(600.0,-337.5),"the window sits at StorageScene's Storage_All_Layout")
	var pack:=FakePack.new()
	var host:=Node.new()
	check(WINDOW.new().configure(pack,host).get("member")==WINDOW.ROOT,"the window fails closed without its CSBs")
	for member: String in WINDOW.REQUIRED:pack.manifest.scenes[member]={}
	pack.manifest.scenes.erase(WINDOW.BAG)
	check(WINDOW.new().configure(pack,host).get("member")==WINDOW.BAG,"a missing bag grid member is named")
	host.free()
	var rows: Array=[{"name":"a","kind":"equip"},{"name":"b","kind":"consume"},{"name":"c","kind":"etc"}]
	var classify: Callable=func(row: Dictionary) -> String: return str(row.kind)
	check(WINDOW.filter(rows,"all",classify).size()==3,"전체 lists every row")
	check(WINDOW.filter(rows,"equip",classify)==[rows[0]] and WINDOW.filter(rows,"consume",classify)==[rows[1]],"a tab lists its kind only")
	check(WINDOW.kind_of({},true)=="equip" and WINDOW.kind_of({"slot":"consumable"},false)=="consume" and WINDOW.kind_of({"type":"소모품"},false)=="consume" and WINDOW.kind_of({"type":"기타"},false)=="etc","장비 / 소모 / 기타 follow the record")
	check(WINDOW.reference_of({"name":"장검","instance_id":"x1"})=="장검@@@x1" and WINDOW.reference_of({"name":"물약","instance_id":""})=="물약","references match the bag's physical identity")
	check(WINDOW.amount_text({"count":5,"instance_id":""})=="5" and WINDOW.amount_text({"count":1,"instance_id":""})=="","stack counts above one are shown")
	check(WINDOW.amount_text({"count":1,"instance_id":"x","level":7})=="+7" and WINDOW.amount_text({"count":1,"instance_id":"x","level":0})=="","equipment shows its enchant level")
	var window=WINDOW.new()
	var screen:=FakeScreen.new()
	window._screen=weakref(screen)
	window._rows={"bag":[{"name":"물약","count":3,"instance_id":""}],"store":[{"name":"장검","count":1,"instance_id":"s9"}]}
	check(window._slot_pressed("bag",0).get("requested")=="deposit" and screen.calls[0]==["drop","물약"],"a 소지품 item asks 보관 through the warehouse screen")
	check(window._slot_pressed("store",0).get("requested")=="withdraw" and screen.calls[1]==["withdraw","장검@@@s9"],"a 창고 item asks 찾기 through the warehouse screen")
	check(window._slot_pressed("store",3).get("empty_slot",false) and screen.calls.size()==2,"an empty slot asks nothing")
	_sources()
	print("ORIGINAL_UI_STORAGE_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _sources() -> void:
	var hud_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.contains("try_open_storage_window(screen)") and hud_text.contains("_report_original_fallback(\"창고\",native)"),"창고 opens the original window first and reports a fallback")
	check(hud_text.contains("close_storage_window()") and hud_text.contains("refresh_storage_window()"),"closing, ESC and transfers reach the window")
	var main_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	for method: String in ["func try_open_storage_window","func storage_window_is_open","func refresh_storage_window"," or storage_window_is_open() or "]:
		check(main_text.contains(method),"the original UI controller exposes "+method)
	var warehouse_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_warehouse.gd")
	check(warehouse_text.contains("func rows_for(is_deposit: bool)") and warehouse_text.contains("for row: Dictionary in rows_for(mode.selected == 0):"),"the TWILIGHT list and the original window share one row rule")
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_storage_window.gd")
	check(not text.contains("Image.create") and not text.contains("draw_rect"),"no picture is drawn")
