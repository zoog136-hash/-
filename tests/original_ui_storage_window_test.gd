extends SceneTree
## Original 523 창고 (source_main_storage_window). Synthetic (no original
## files): the window names the client's Storage members and fails closed
## without them, filters the warehouse screen's rows by tab, labels amounts,
## builds the transfer references, asks 보관 / 찾기 through the existing screen,
## and the HUD opens it before the TWILIGHT warehouse list.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_storage_window.gd")
const VIEW=preload("res://scripts/ui/renewal_warehouse.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const DROPS=preload("res://scripts/loot/patch523_monster_drops.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

class FakeScreen extends RefCounted:
	var calls: Array=[]
	func request_drop(reference: String) -> void:calls.append(["drop",reference])
	func request_withdraw(reference: String) -> void:calls.append(["withdraw",reference])

class FakeWarehouse extends RefCounted:
	var stacks: Dictionary={}
	var instances: Dictionary={}

class FakeWorld extends Node:
	var inventory: Dictionary={"물약":150,"주문서":2}
	var item_instances: Dictionary={"e1":{"name":"장검"}}
	var warehouse:=FakeWarehouse.new()
	var refused: String="주문서"
	func _find_catalog_item_record(_name: String) -> Dictionary: return {}
	func _enhancement_kind_for_record(_record: Dictionary) -> String: return ""
	func _is_instance_equipped(_id: String) -> bool: return false

class FakeHud extends Node:
	signal warehouse_transfer_requested(item: String, amount: int, direction: String, id: String)
	var asked: Array=[]
	var approve: Callable
	var has_original_review: bool=true
	func confirm_source_action(title: String, _body: String, _action: String, callback: Callable, original_only: bool=false) -> Control:
		if not original_only or not has_original_review:return null
		asked.append(title)
		approve=callback
		var dialog:=Control.new()
		add_child(dialog)
		return dialog
	func show_message(_text: String) -> void:
		pass

func _move(item: String, amount: int, direction: String, id: String, world: FakeWorld) -> void:
	if item==world.refused:return
	if direction=="deposit":
		if not id.is_empty():
			world.warehouse.instances[id]=world.item_instances[id];world.item_instances.erase(id)
		else:
			world.inventory[item]=int(world.inventory[item])-amount
			world.warehouse.stacks[item]=int(world.warehouse.stacks.get(item,0))+amount

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
	check(WINDOW.amount_text({"count":9,"instance_id":"x","native_stack":true})=="9","a physical consumable shows quantity")
	var window=WINDOW.new()
	var screen:=FakeScreen.new()
	window._screen=weakref(screen)
	window._rows={"bag":[{"name":"물약","count":3,"instance_id":""}],"store":[{"name":"장검","count":1,"instance_id":"s9"}]}
	check(window._slot_pressed("bag",0).get("requested")=="deposit" and screen.calls[0]==["drop","물약"],"a 소지품 item asks 보관 through the warehouse screen")
	check(window._slot_pressed("store",0).get("requested")=="withdraw" and screen.calls[1]==["withdraw","장검@@@s9"],"a 창고 item asks 찾기 through the warehouse screen")
	check(window._slot_pressed("store",3).get("empty_slot",false) and screen.calls.size()==2,"an empty slot asks nothing")
	_batch()
	if not SOURCE.not_installed(): _original_stack_rows()
	_sources()
	print("ORIGINAL_UI_STORAGE_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _original_stack_rows() -> void:
	var record: Dictionary=DROPS.variant_item(DROPS.definition_id("233").get("native_record",{}),1)
	var grant: Dictionary=STACK.stage_grant(record,9,{}, {"kind":"warehouse_ui_regression"})
	check(grant.get("ok",false),"verified original potion stack can be selected")
	if not grant.get("ok",false): return
	var world:=FakeWorld.new()
	var key: String=str(record.name)
	var uid: String=str(grant.id)
	world.inventory={key:9}
	world.item_instances=grant.item_instances
	var view: Control=VIEW.new()
	view.world=world
	var rows: Array[Dictionary]=view.rows_for(true)
	check(rows.size()==1 and rows[0].count==9 and WINDOW.reference_of(rows[0])==key+"@@@"+uid,
		"deposit row preserves the verified stack ID and actual quantity")
	check(view._transfer_limit(key,uid,true)==9 and WINDOW._held(world,"bag",key,uid)==9,
		"single and batch deposit both use the receipt's quantity")
	world.warehouse.stacks={key:9}
	world.warehouse.instances=world.item_instances
	world.inventory={}
	world.item_instances={}
	rows=view.rows_for(false)
	check(rows.size()==1 and rows[0].count==9 and WINDOW.reference_of(rows[0])==key+"@@@"+uid,
		"withdrawal offers the same receipt reference")
	check(view._transfer_limit(key,uid,false)==9 and view._transfer_limit("other",uid,false)==0,"withdrawal validates the selected name and quantity")
	view.free()
	world.free()

## 모두 맡기기: every row of the tab, 99 per move, stopping at a refused row.
func _batch() -> void:
	var world:=FakeWorld.new()
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	hud.warehouse_transfer_requested.connect(_move.bind(world))
	var window=WINDOW.new()
	window._hud=weakref(hud)
	window._rows={"bag":[{"name":"물약","count":150,"instance_id":""},{"name":"장검","count":1,"instance_id":"e1"},{"name":"주문서","count":2,"instance_id":""},{"name":"물약2","count":1,"instance_id":""}],"store":[]}
	hud.has_original_review=false
	check(window._batch_requested("bag").get("code")=="source_storage_batch_review_unavailable" and hud.asked.is_empty() and world.warehouse.stacks.is_empty(),"the missing native review makes no transfer")
	hud.has_original_review=true
	var asked: Dictionary=window._batch_requested("bag")
	check(asked.get("asked","")=="모두 맡기기" and hud.asked==["모두 맡기기"] and world.warehouse.stacks.is_empty(),"모두 맡기기 asks once before making a transfer")
	hud.approve.call(1)
	hud.approve=Callable()
	check(int(world.inventory["물약"])==0 and int(world.warehouse.stacks["물약"])==150 and world.warehouse.instances.has("e1"),"every row moves, a stack of 150 in moves of up to 99")
	check(int(world.inventory["주문서"])==2,"the batch stops at the first move the world refuses")
	check(window._batch_requested("store").get("empty",false),"모두 찾기 with an empty tab moves nothing")
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_storage_window.gd")
	check(text.contains("spec[\"Btn_Sell_On\"]") and text.contains("spec[\"Btn_Confirm_On\"]"),"the original 모두 맡기기 / 모두 찾기 buttons are bound")
	var builder: String=FileAccess.get_file_as_string("res://tools/ui/build_client523_main_ui_pack.py") if FileAccess.file_exists("res://tools/ui/build_client523_main_ui_pack.py") else ""
	if not builder.is_empty():check(builder.contains("[46564, 46252, 45968, 45420, 44044, 42700, 34968,"),"the pack keeps both buttons (their activation effects stay out)")
	world.queue_free()

func _sources() -> void:
	var hud_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.contains("try_open_storage_window(screen)") and hud_text.contains("_hold_original_inventory_window(\"창고\",native)"),"the original warehouse opens first and a rejected selected pack holds the old screen")
	check(hud_text.contains("close_storage_window()") and hud_text.contains("refresh_storage_window()"),"closing, ESC and transfers reach the window")
	var main_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	for method: String in ["func try_open_storage_window","func storage_window_is_open","func refresh_storage_window"," or storage_window_is_open() or "]:
		check(main_text.contains(method),"the original UI controller exposes "+method)
	var warehouse_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_warehouse.gd")
	check(warehouse_text.contains("func rows_for(is_deposit: bool)") and warehouse_text.contains("for row: Dictionary in rows_for(mode.selected == 0):"),"the TWILIGHT list and the original window share one row rule")
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_storage_window.gd")
	check(not text.contains("Image.create") and not text.contains("draw_rect"),"no picture is drawn")
