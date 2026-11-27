extends "res://tests/source_inventory_controls_main_test.gd"
## Actual inventory/detail buttons. The optional private pack is selected at
## boot, and the verified definition archive is admitted after class entry.
const DISSOLVE=preload("res://scripts/refine523/bless_refine523_service.gd")
const DISSOLVE_POPUP=preload("res://scripts/ui/original_ui/source_main_dissolve_popup.gd")
const WEAPON:int=248
const SCROLL:int=6401

func result_marker() -> String:return "SOURCE_BAG_DETAIL_ENTRY_RESULT"

func fallback() -> void:
	h.toggle_inventory()
	await frames()
	ck(bag.inventory_panel.is_visible_in_tree(),"an unconfigured UI still has the offline inventory")
	h.toggle_inventory()
	OS.set_environment("TWILIGHT_SOURCE_UI","user://missing-original-bag-pack")
	OS.set_environment("TWILIGHT_SOURCE_UI_SHA256","a".repeat(64))
	h._bind_selected_original_main_ui()
	var saved: String=hash_file()
	h.toggle_inventory()
	await frames()
	ck(h.requires_original_inventory_ui() and not h.original_inventory_is_open() and not bag.inventory_panel.is_visible_in_tree(),"a rejected selected pack cannot open the homemade bag")
	for method: String in ["open_warehouse","open_shop","open_npc_shop","open_item_sell","open_crafting","_open_enhance_chooser","open_equipment_collections","open_refine523","open_forge"]:
		h.call(method)
		await frames()
		ck(not h.workspace.is_visible_in_tree() and h.active_section.is_empty(),method+" holds the old panel when the chosen original pack is invalid")
	for section: String in ["emblems","guardians"]:
		h.open_growth(section)
		ck(not h.workspace.is_visible_in_tree() and h.active_section.is_empty(),section+" holds its old panel when the chosen original pack is invalid")
	var called: Array[int]=[]
	var on_accept:=func(count: int) -> void:called.append(count)
	ck(not h.confirm_ground_drop("아이템",26,1,on_accept).get("handled",false),"missing original drop confirmation is held")
	ck(not h.confirm_inventory_delete("아이템",26,1,on_accept).get("handled",false),"missing original delete confirmation is held")
	ck(h.confirm_crafting_action("제작 확인","재료 1개","제작",on_accept)==null,"missing original crafting review cannot open a substitute")
	ck(h.confirm_awakening_action("각성 확인","각성서 1개","각성",on_accept)==null,"missing original awakening review cannot open a substitute")
	ck(not h.open_gacha_craft523() and not h.workspace.is_visible_in_tree(),"an unconnected source spellbook scene holds the old crafting screen")
	ck(called.is_empty() and h.get_node_or_null("Root/TwilightConfirmation")==null and hash_file()==saved,"protected actions leave the save alone")
	OS.unset_environment("TWILIGHT_SOURCE_UI")
	OS.unset_environment("TWILIGHT_SOURCE_UI_SHA256")

func exact(archive: String) -> void:
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",archive)
	SOURCE.reset()
	SHOP.release()
	w.skill_awakening=w.SKILL_AWAKENING.new()
	w.skill_awakening.configure(w)
	controller=h.original_main_ui_controller
	if not ck(is_instance_valid(controller) and SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"original UI and definition inputs are active"):return
	for id: int in [WEAPON,SCROLL,DISSOLVE.RULES.BLESS_POWDER_ITEM]:
		var record: Dictionary=w.source_item_definition(id).get("native_record",{})
		if not ck(not record.is_empty(),"original item definition "+str(id)):return
		w.catalog_db["아이템"].append(record)
	w._index_catalog_item_sources()
	var catalog=SHOP.session()
	if catalog.available():w.source_shop.bind_source(catalog)
	# This original ItemClass has linked +7 collection cases. Its +0 item
	# rows exist in the table without a collection link.
	if not ck(grant(WEAPON,2,"same +7 weapon",7) and grant(SCROLL,3,"weapon enchant"),"genuine physical equipment and scrolls added to the test character"):return
	var weapons: Array=refs_for(WEAPON)
	var scrolls: Array=refs_for(SCROLL)
	if not ck(weapons.size()==2 and scrolls.size()==1,"two exact equipment identities and one scroll stock"):return
	var reference: String=weapons[0]
	var other: String=weapons[1]
	await _move_item(reference,other)
	await _registration(reference)
	await _enhancement(reference,scrolls[0])
	await _dissolve(reference,other)
	await _registration(other,true)
	h._close_workspace()

func refs_for(item_id: int) -> Array:
	var refs: Array=[]
	for uid: String in w.item_instances:
		var entry: Dictionary=w.item_instances[uid]
		if int(entry.get("record",{}).get("source_item_class_id",0))==item_id:refs.append(str(entry.name)+"@@@"+uid)
	refs.sort()
	return refs

func _open_detail(reference: String) -> bool:
	if not h.original_inventory_is_open():
		h.toggle_inventory()
		await frames()
	if not ck(h.original_inventory_is_open(),"normal HUD enters the original inventory"):return false
	view=controller._inventory_view
	if not await select_reference(reference):return false
	if not await tap(view._detail_area,"the original bag magnifier"):return false
	return ck(controller.item_tooltip_is_open() and controller.item_tooltip().member==TOOLTIP.DETAIL_MEMBER and controller.item_tooltip().reference==reference,"magnifier opens the authored detail for the selected physical entry")

func _move_item(first: String,second: String) -> void:
	h.toggle_inventory()
	await frames()
	if not ck(h.original_inventory_is_open(),"normal HUD opens the original bag for reordering"):return
	view=controller._inventory_view
	var before: Array=bag.sorted_references.duplicate()
	var source: String=first if before.find(first)>before.find(second) else second
	var target: String=second if source==first else first
	if not await select_reference(source):return
	var balance: Dictionary=w.inventory.duplicate(true)
	var file: String=hash_file()
	if not await tap(native_button(Chrome.MOVE_BUTTON),"original Move"):return
	ck(h.original_inventory_move_pending() and not bag.item_action_armed(source),"move mode disarms item use and retains the exact source slot")
	if not await tap(native_button(Chrome.MOVE_CANCEL),"original move Cancel"):return
	ck(not h.original_inventory_move_pending() and bag.sorted_references==before and hash_file()==file,"cancelling Move keeps the same order and save")
	if not await tap(native_button(Chrome.MOVE_BUTTON),"original Move again"):return
	if not await tap(view._hits.get(target,{}).get("control"),"exact destination slot"):return
	var expected: Array=before.duplicate()
	expected.erase(source)
	expected.insert(expected.find(target),source)
	ck(not h.original_inventory_move_pending() and bag.sorted_references==expected and w.inventory==balance,"inserting before the chosen slot preserves ownership and the rest of the order")
	w.deferred_save.cancel()
	ck(w._save_game(true)==OK,"the existing save writer stores the order")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
	ck(saved.ui_preferences.inventory_order==expected,"the saved order contains the exact original references")
	w._load_game(true)
	await frames()
	var order: Array=w.ui_preferences.inventory_order
	ck(order.find(source)>=0 and order.find(source)+1==order.find(target),"reload keeps the exact moved item directly before its destination")
	for name: String in balance:
		ck(int(w.inventory.get(name,0))==int(balance[name]),"reload preserves the prior quantity of "+name)

func _registration(reference: String, commit: bool=false) -> void:
	if not await _open_detail(reference):return
	var saved: String=hash_file()
	if not await tap(popup_button(controller.item_tooltip(),"ToolTip_Button/Registration_On/Button"),"original registration button"):return
	if ck(controller.feature_window_is_open("item_book"),"registration enters original ItemBook (%s)" % str(h.original_main_ui_status.get("item_book_window",{}).get("code",""))):
		var page: RefCounted=controller.feature_window("item_book")
		var uid: String=reference.get_slice("@@@",1)
		ck(page._focus_item_class_id==WEAPON and page._focus_item_uid==uid and not page._tab_rows.is_empty(),"only collections matching the original item and its physical identity are opened")
		var register: Control
		var collection_id: String=""
		var card_id: String=""
		for node: Node in page._scene.find_children("*","Node2D",true,false):
			if not node.has_meta("source_button"):continue
			var action: Callable=node.get_meta("source_button")._activation
			if not action.is_valid() or action.get_method()!="_card_pressed":continue
			var args: Array=action.get_bound_arguments()
			var quote: Dictionary=w.item_book523.quote(args[0],args[1],{"item_class_id":WEAPON,"uid":uid})
			if not args[2] and quote.get("ok",false):
				ck(quote.items.size()==1 and quote.items[0].uid==uid,"registration quote pins the exact weapon")
				collection_id=args[0]
				card_id=args[1]
				register=area(node)
				break
		if await tap(register,"held original collection item"):
			var review: Control=h.get_node_or_null("Root/TwilightConfirmation")
			if ck(is_instance_valid(review) and review.get_script().resource_path=="res://scripts/ui/original_ui/source_main_awakening_review.gd","registration uses the original common confirmation"):
				ck(saved==hash_file(),"opening the collection and its review leaves the save intact")
				if commit:
					for _page: int in review._pages.size():
						if not await tap(review.confirm_button,"original registration confirm"):return
					ck(not w.item_instances.has(uid) and saved!=hash_file() and w.item_book523.card_registered(collection_id,card_id),"original confirmation registers and consumes only its displayed weapon")
					w._load_game(true)
					await frames()
					ck(not w.item_instances.has(uid) and w.item_book523.card_registered(collection_id,card_id),"the exact registration survives reload")
				else:
					await tap(review.cancel_button,"original registration cancel")
					ck(saved==hash_file(),"cancelling registration leaves the save and inventory intact")
	h._close_workspace()

func _enhancement(reference: String,scroll: String) -> void:
	if not await _open_detail(reference):return
	var saved: String=hash_file()
	if not await tap(popup_button(controller.item_tooltip(),"ToolTip_Button/Enchant_On/Button"),"original equipment enhancement button"):return
	if not ck(controller.enchant_window_is_open() and not h.workspace.visible,"the original scroll chooser opens"):return
	var window: RefCounted=controller.enchant_window()
	ck(window._bag_target==reference and window.tab()=="scroll","entry pins the physical target without selecting a scroll")
	var control: Control
	for node: Node in window._scene.find_children("*","Node2D",true,false):
		if not node.has_meta("source_button"):continue
		var action: Callable=node.get_meta("source_button")._activation
		if action.is_valid() and action.get_method()=="_slot_pressed" and scroll in action.get_bound_arguments():
			control=area(node)
			break
	if not await tap(control,"original held scroll"):return
	ck(window._candidates.size()==1 and window.selected()==reference,"the selected scroll opens the exact compatible equipment (tab %s, candidates %d)" % [window.tab(),window._candidates.size()])
	ck(saved==hash_file(),"choosing the scroll and target does not charge either")
	h._close_workspace()

func _dissolve(reference: String,other: String) -> void:
	var uid: String=reference.get_slice("@@@",1)
	var quote: Dictionary=DISSOLVE.dissolve_quote(w,[uid])
	if not ck(quote.get("ok",false),"the mounted real weapon is eligible for normal dissolution"):return
	var saved: String=hash_file()
	for decision: String in ["cancel","stale","confirm"]:
		if not await _open_detail(reference):return
		if not await tap(popup_button(controller.item_tooltip(),"ToolTip_Button/Solution_On/Button"),"original dissolve button"):return
		if not ck(controller.dissolve_confirm_is_open(),"original dissolve confirmation owns the action"):return
		var popup: RefCounted=controller._dissolve_popup
		ck(popup._scene.source_member==DISSOLVE_POPUP.ROOT and popup._uids==[uid] and int(popup.last_result.total)==int(quote.total),"the actual dialog shows the chosen item and exact output")
		var button: Node=popup._scene.find_child("Btn_Cancel" if decision=="cancel" else "Btn_Yes",true,false)
		var outcomes: Array[Dictionary]=[]
		if decision!="cancel":popup.finished.connect(func(result: Dictionary) -> void:outcomes.append(result),CONNECT_ONE_SHOT)
		if decision=="stale":w.item_instances[uid].level=8
		if not await tap(area(button),"original dissolve decision"):return
		ck(not controller.dissolve_confirm_is_open(),"the original decision closes its modal")
		if decision=="confirm":
			ck(outcomes.size()==1 and outcomes[0].get("ok",false),"the confirmed dissolve transaction reports success (%s)" % str(outcomes[0].get("reason","") if not outcomes.is_empty() else "no outcome"))
		elif decision=="stale":
			ck(outcomes.size()==1 and outcomes[0].get("code")=="stale_dissolve_quote" and saved==hash_file() and w.item_instances.has(uid),"a changed preview never consumes the equipment")
			w.item_instances[uid].level=7
		else:
			ck(saved==hash_file() and w.item_instances.has(uid),"cancelling preserves the selected weapon and save")
	ck(not w.item_instances.has(uid) and w.item_instances.has(other.get_slice("@@@",1)) and saved!=hash_file(),"confirmed dissolution removes only the selected physical weapon")
	ck(int(DISSOLVE.stacks_of(w,int(quote.output_item_class_id)).total)==int(quote.total),"the original powder amount is saved once")
