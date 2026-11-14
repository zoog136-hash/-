extends SceneTree
## Original 523 NPC 상점 (source_main_store_window). Synthetic (no original
## files): the window names the client's Store members and fails closed
## without them, finds the talking NPC's merchants by their EarthObject,
## lists every bag stack and physical item, and the HUD opens it for the
## talking NPC before the TWILIGHT shop list.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_store_window.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_STORE_WINDOW_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(WINDOW.ROOT=="UI/Store/Store_All.csb" and WINDOW.BAG=="UI/Store/Store_Inventory.csb" and WINDOW.GOODS=="UI/Store/Store_PurchaseAuto.csb" and WINDOW.ROW=="UI/Store/Store_PurchaseAutoList.csb","the window names the client's store members")
	check(WINDOW.SET=="UI/FloatingUi/Inventory_Slot_Set.csb","the 소지품 grid uses Inventory_Slot_Set lines (QuickSlotEdit_SlotSet is absent)")
	check(WINDOW.LAYOUT_POSITION==Vector2(600.0,-337.5),"the window sits at StoreScene's Store_All_Layout")
	var pack:=FakePack.new()
	var host:=Node.new()
	check(WINDOW.new().configure(pack,host).get("member")==WINDOW.ROOT,"the window fails closed without its CSBs")
	for member: String in WINDOW.REQUIRED:pack.manifest.scenes[member]={}
	pack.manifest.scenes.erase(WINDOW.ROW)
	check(WINDOW.new().configure(pack,host).get("member")==WINDOW.ROW,"a missing goods row member is named")
	host.free()
	var records: Dictionary={"10":{"object_links":[{"earth_object_id":501}]},"20":{"object_links":[{"earth_object_id":777},{"earth_object_id":501}]},"30":{"object_links":[{"earth_object_id":9}]}}
	check(WINDOW.merchants_for(records,501)==[10,20],"every merchant linked to the NPC's EarthObject sells there")
	check(WINDOW.merchants_for(records,0).is_empty() and WINDOW.merchants_for(records,4).is_empty(),"an unlinked NPC has no merchant (no goods)")
	var rows: Array=WINDOW.rows_of({"물약":30,"장검":2,"아데나":999,"빈칸":0},{"a1":{"name":"장검","level":3},"a2":{"name":"장검","level":0}})
	check(rows.size()==3 and rows[0]=={"name":"물약","count":30,"instance_id":""},"stacks list once with their count; Adena and empty stacks stay out")
	check(rows[1].instance_id=="a1" and rows[1].level==3 and rows[2].instance_id=="a2","each physical item is its own slot")
	check(WINDOW.price_text(1234567)=="1,234,567" and WINDOW.price_text(0)=="0","prices group by thousands")
	_sources()
	print("ORIGINAL_UI_STORE_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _sources() -> void:
	var hud_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.contains("func open_npc_shop(npc_id: String = \"\")") and hud_text.contains("try_open_store_window(npc_id)") and hud_text.contains("_report_original_fallback(\"상점\",native)"),"상점 opens the original window for the talking NPC first and reports a fallback")
	check(hud_text.contains("close_store_window()") and hud_text.contains("refresh_store_window()"),"closing, ESC and purchases reach the window")
	var world_text: String=FileAccess.get_file_as_string("res://scripts/world.gd")
	check(world_text.contains("\"shop\": hud.open_npc_shop(npc_id)"),"the NPC dialogue passes its NPC")
	var main_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	for method: String in ["func try_open_store_window","func store_window_is_open","func refresh_store_window"," or store_window_is_open() or "]:
		check(main_text.contains(method),"the original UI controller exposes "+method)
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_store_window.gd")
	check(text.contains("\"quote_merchant\"") and text.contains("\"buy_merchant\""),"quotes and payment stay with world.source_shop")
	check(not text.contains("Image.create") and not text.contains("draw_rect"),"no picture is drawn")
