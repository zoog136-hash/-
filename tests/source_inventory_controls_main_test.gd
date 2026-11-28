extends SceneTree
## Actual Main and touch. The optional exact UI45/523 path uses a disposable
## save with two genuine physical leather receipts and original equipment.
const QA=preload("res://tests/qa_class_selection.gd")
const Chrome=preload("res://scripts/ui/original_ui/source_main_inventory_bindings.gd")
const Delete=preload("res://scripts/loot/inventory_item_delete.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const SUPPLY=preload("res://scripts/loot/patch523_item_inventory.gd")
const SHOP=preload("res://scripts/shop/source523_shop_catalog.gd")
const TREE=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const TOOLTIP=preload("res://scripts/ui/original_ui/source_main_item_tooltip.gd")
const BOX_ID: int=315982
var checks: int=0
var failures: Array[String]=[]
var w: Node
var h: Node
var bag: Control
var controller: Node
var view: RefCounted

func _initialize() -> void:run.call_deferred()

func ck(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:failures.append(label);printerr("SOURCE_INVENTORY_CONTROLS_FAIL ",label)
	return ok

func run() -> void:
	var source: String=OS.get_environment("TWILIGHT_INVENTORY_CONTROLS_DEFINITIONS")
	root.size=Vector2i(2048,919)
	if ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated Main user directory"):
		w=load("res://Main.tscn").instantiate()
		root.add_child(w);current_scene=w;w.set_process(false);w.save_timer=-100000
		ck(QA.enter_game(w),"actual Main enters")
		await frames()
		w.field_population.set_process(false);w.player.set_physics_process(false)
		h=w.hud;bag=h.lineage_inventory_ui
		if source.is_empty():await fallback()
		else:await exact(source)
		if is_instance_valid(w):w.queue_free()
		await frames()
	print(result_marker()," ",JSON.stringify({"checks":checks,"failures":failures,"original_checked":not source.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func result_marker() -> String:return "SOURCE_INVENTORY_CONTROLS_RESULT"

func frames() -> void:
	await process_frame
	await process_frame

func tap(control: Control, label: String) -> bool:
	if not ck(is_instance_valid(control) and control.is_visible_in_tree(),label+" touch owner is visible"):return false
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=7;event.pressed=pressed;event.position=point
		root.push_input(event,true)
		await process_frame
	return true

func area(node: Node) -> Control:
	var button: Node=node.get_meta("source_button",null) if is_instance_valid(node) else null
	return button.get("_input_area") if is_instance_valid(button) else null

func native_button(offset: int) -> Control:
	return area(view._inventory_scene.source_nodes.get(offset))

func popup_button(owner: RefCounted, suffix: String) -> Control:
	var exact_node: Dictionary=TREE.locate(owner._scene,owner._out,suffix)
	return area(exact_node.player.source_nodes.get(exact_node.offset)) if exact_node.get("ok",false) else null

func fallback() -> void:
	var label: String="원본 삭제 조건 없는 검증 물품"
	var other: String="검색에서 빠지는 물품"
	for name_value: String in [label,other]:
		w.catalog_db["아이템"].append({"name":name_value,"slot":"material","type":"재료","grade":"일반"})
		w.inventory[name_value]=2
	w._index_catalog_item_sources()
	w._update_hud();h.refresh_inventory(w.inventory)
	h.toggle_inventory();await frames()
	if not ck(not h.original_inventory_is_open() and bag.inventory_panel.is_visible_in_tree(),"actual no-pack fallback opens"):return
	if not await tap(bag.slot_buttons.get(label),"non-original inventory item"):return
	var entire: Dictionary=w.inventory.duplicate()
	var saved: String=hash_file()
	await tap(bag.find_child("InventoryDelete",true,false),"fallback delete button")
	ck(w.inventory==entire and saved==hash_file() and h.get_node("Root").get_node_or_null("TwilightConfirmation")==null,"unverified source row is kept without opening a misleading confirmation")
	if not await tap(bag.find_child("InventorySearch",true,false),"fallback search") or not await type_query(bag.search_line,label):return
	ck(bag.sorted_references.has(label) and not bag.sorted_references.has(other),"fallback bag filters using the owner editor")
	await tap(bag.find_child("InventoryClearSearch",true,false),"fallback clear search")
	ck(bag.search_line.text.is_empty() and bag.sorted_references.has(label) and bag.sorted_references.has(other),"fallback clear restores both rows")
	ck(w.inventory==entire and hash_file()==saved,"search and clear leave items and save unchanged")
	await restart_routes()

func type_query(editor: LineEdit, query: String) -> bool:
	if not await tap(editor,"inventory search field"):return false
	for i: int in query.length():
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = query.unicode_at(i)
		root.push_input(event,true)
	await frames()
	return ck(editor.text == query,"typed search query is received")

func restart_routes() -> void:
	if h.get("active_section") != "":h._close_workspace()
	h.toggle_menu()
	await frames()
	var tile: Control = h.workspace.find_child("MenuTile_restart",true,false)
	if not await tap(tile,"full menu restart"):return
	var dialog: Control = h.get_node_or_null("Root/TwilightConfirmation")
	if not ck(is_instance_valid(dialog),"restart asks for confirmation"):return
	var saved: String = hash_file()
	await tap(dialog.cancel_button,"cancel restart")
	ck(current_scene==w and not w.returning_to_character_lobby and saved==hash_file(),"cancel stays in the same game and does not save or switch characters")
	w.source_save_blocked = true
	if not await tap(tile,"restart with blocked save"):return
	dialog = h.get_node_or_null("Root/TwilightConfirmation")
	if not ck(is_instance_valid(dialog),"restart confirmation can reopen"):return
	await tap(dialog.confirm_button,"confirm restart with blocked save")
	ck(current_scene==w and not w.returning_to_character_lobby and saved==hash_file(),"save refusal preserves the active world and existing bytes")
	w.source_save_blocked = false
	w.gold += 123
	var expected_gold: int = w.gold
	var path: String = w.save_path()
	if not await tap(tile,"restart with writable save"):return
	dialog = h.get_node_or_null("Root/TwilightConfirmation")
	if not ck(is_instance_valid(dialog),"restart confirmation opens after refusal"):return
	await tap(dialog.confirm_button,"confirm restart with writable save")
	await frames()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	ck(is_instance_valid(current_scene) and current_scene.scene_file_path=="res://scenes/boot/Characters.tscn" and data is Dictionary and int(data.get("gold",-1))==expected_gold,"ordinary menu restart saves actual character state before opening the character lobby")

func grant(id: int,amount: int,fixture: String,level: int=0) -> bool:
	var staged: Dictionary=SUPPLY.stage(w,[{"item_class_id":id,"amount":amount,"bless_raw":1,"enchant":level}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero","controls_test_origin":fixture})
	if not staged.get("ok",false):
		print("SOURCE_INVENTORY_CONTROLS_GRANT_DIAG ",id," ",staged.get("error"))
		return false
	var stored: Error=w._save_game(false,staged.overrides)
	if stored!=OK:
		print("SOURCE_INVENTORY_CONTROLS_GRANT_DIAG ",id," save=",error_string(stored)," source=",w.source_save_blocked," source_items=",w.source_item_save_blocked)
		return false
	w.inventory=staged.overrides.inventory;w.item_instances=staged.overrides.item_instances
	w._publish_player_hud(false);h.refresh_inventory(w.inventory)
	return true

func hash_file() -> String:
	return FileAccess.get_sha256(w.save_path()) if FileAccess.file_exists(w.save_path()) else ""

func select_reference(reference: String) -> bool:
	var selected: bool=await tap(view._hits.get(reference,{}).get("control"),"owned slot")
	return ck(selected and bag.selected_item==reference,"Main gesture selects exactly its physical bag reference")

func delete_dialog() -> RefCounted:
	return controller.drop_confirm_popup()

func open_delete() -> bool:
	if not await tap(native_button(Chrome.DELETE_BUTTON),"original Delete"):return false
	return ck(controller.drop_confirm_is_open() and delete_dialog().last_result.get("permanent_delete",false),"native original keypad/confirmation opens for permanent deletion")

func advance_one() -> bool:
	if not ck(delete_dialog().stage=="keypad" and delete_dialog().count()==1,"original count keypad defaults to one"):return false
	if not await tap(popup_button(delete_dialog(),"Btn_Select"),"original quantity confirm"):return false
	return ck(delete_dialog().stage=="confirm","separate permanent confirmation still required")

func exact(archive: String) -> void:
	if not ck(not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty(),"exact original UI in use"):return
	# Start the ordinary Main before mounting the private test source, but every
	# issued record, condition and renderer used below is from the pinned bank.
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",archive);SOURCE.reset();SHOP.release()
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	if not ck(SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"exact original 523 definitions verified"):return
	for id: int in [366,326,289062,BOX_ID]:
		var native: Dictionary=w.source_item_definition(id).get("native_record",{})
		if not ck(not native.is_empty(),"exact item catalog #"+str(id)):return
		w.catalog_db["아이템"].append(native)
	w._index_catalog_item_sources()
	var catalog=SHOP.session()
	if catalog.available():w.source_shop.bind_source(catalog)
	if not ck(grant(366,4,"leather A") and grant(366,3,"leather B") and grant(326,1,"weapon") and grant(289062,1,"forbidden") and grant(BOX_ID,1,"probability box"),"genuine source grants with durable receipts"):return
	var a: String="";var b: String="";var weapon: String="";var prohibited: String="";var leather: String="";var box: String=""
	for uid: String in w.item_instances:
		var entry: Dictionary=w.item_instances[uid]
		var id: int=int(entry.get("record",{}).get("source_item_class_id",0))
		var reference: String=str(entry.name)+"@@@"+uid
		if id==366:
			var receipt: Dictionary=STACK.proof(w,uid)
			if int(receipt.get("remaining",0))==4:a=reference;leather=str(entry.name)
			if int(receipt.get("remaining",0))==3:b=reference
		elif id==326:weapon=reference
		elif id==289062:prohibited=reference
		elif id==BOX_ID:box=reference
	if not ck(not a.is_empty() and not b.is_empty() and not weapon.is_empty() and not prohibited.is_empty() and not box.is_empty(),"separate exact selected receipts, equipment and original box and forbidden rows"):return
	var uid_a: String=a.get_slice("@@@",1)
	var uid_b: String=b.get_slice("@@@",1)
	var weapon_uid: String=weapon.get_slice("@@@",1)
	w._set_item_locked(b,true)
	w.deferred_save.cancel()
	ck(w._save_game(true)==OK,"fixture locks and initial items are durable")
	ck(not Delete.quote(w,leather).get("ok",false),"ambiguous display name never substitutes for a physical item")
	ck(not Delete.quote(w,b).get("ok",false) and not Delete.quote(w,prohibited).get("ok",false),"locked and IsDeletable=false records stay protected")
	w.equipped_items["weapon"]={"instance_id":weapon_uid}
	ck(not Delete.quote(w,weapon).get("ok",false),"matching equipped physical weapon is protected even with true ItemClass flag")
	w.equipped_items.erase("weapon")
	ck(Delete.quote(w,weapon).get("maximum")==1,"an unequipped native equipment reference has a single exact item")
	h.toggle_inventory();await frames()
	controller=h.original_main_ui_controller
	if not ck(h.original_inventory_is_open(),"actual original inventory opens"):return
	view=controller._inventory_view
	if not ck(view._hits.has(a) and view._hits.has(b) and view._hits.has(weapon),"actual native slot references exist"):return
	if not await select_reference(weapon):return
	var before_worn: Dictionary=w.equipped_items.duplicate(true)
	var before_owned: Dictionary=w.inventory.duplicate(true)
	if not await tap(native_button(Chrome.LOCK_BUTTON),"authored exact weapon lock"):return
	ck(bag.selected_item==weapon and not bag.item_action_armed(weapon),"lock keeps the exact selection but removes its activation marker")
	ck(w._item_locked(weapon.get_slice("@@@",0),weapon_uid) and w._item_locked(leather,uid_b) and not w._item_locked(leather,uid_a) and w.equipped_items==before_worn and w.inventory==before_owned,"lock button affects only the chosen weapon UID, without touching item activation or siblings")
	ck(w._save_game(true)==OK,"the real profile writer persists the authored lock action")
	w._load_game(true);await frames()
	ck(w._item_locked(weapon.get_slice("@@@",0),weapon_uid) and w._item_locked(leather,uid_b),"reload retains the exact selected lock and the prior different item lock")
	if not await select_reference(weapon) or not await tap(native_button(Chrome.LOCK_BUTTON),"authored unlock"):return
	ck(not w._item_locked(weapon.get_slice("@@@",0),weapon_uid) and w._item_locked(leather,uid_b),"unlock action changes only the exact selected lock before writing")
	ck(w._save_game(true)==OK,"authored unlock is durable")
	w._load_game(true);await frames()
	ck(not w._item_locked(weapon.get_slice("@@@",0),weapon_uid) and w._item_locked(leather,uid_b) and not w._item_locked(leather,uid_a),"unlock and reload preserve the other UID's lock")
	ck(w.item_instances.has(weapon_uid) and not w._is_instance_equipped(weapon_uid) and int(w.inventory.get(weapon.get_slice("@@@",0),0))==int(before_owned[weapon.get_slice("@@@",0)]) and int(w.inventory[leather])==7,"neither lock gesture activated, equipped, or consumed the tested items")
	var detail_inventory: Dictionary = w.inventory.duplicate()
	if not await select_reference(weapon) or not await tap(view._detail_area,"owned weapon details"):return
	if not await tap(popup_button(controller.item_tooltip(),"ItemInfo/Nd_Unlock/Btn_Lock"),"original detail lock"):return
	ck(controller.item_tooltip_is_open() and controller.item_tooltip().reference==weapon and w._item_locked(weapon.get_slice("@@@",0),weapon_uid) and w._item_locked(leather,uid_b) and popup_button(controller.item_tooltip(),"Icon_Set/Del_On/Btn_Icon")==null,"locking here keeps that exact selection and removes Delete immediately")
	if not await tap(popup_button(controller.item_tooltip(),"ItemInfo/Nd_Lock/Btn_Lock"),"original detail unlock"):return
	var unlocked: bool = not w._item_locked(weapon.get_slice("@@@",0),weapon_uid)
	var peer_locked: bool = w._item_locked(leather,uid_b)
	ck(unlocked and peer_locked and w.inventory==detail_inventory,"unlock changes only the selected item without consuming it: "+str([unlocked,peer_locked,w.inventory==detail_inventory]))
	w.deferred_save.cancel()
	bag.close_item_info()
	if not await select_reference(b):return
	if not await tap(view._detail_area,"locked item original details"):return
	ck(controller.item_tooltip_is_open() and popup_button(controller.item_tooltip(),"Icon_Set/Del_On/Btn_Icon")==null,"locked item never gets an active tooltip delete control")
	bag.close_item_info()
	await frames()
	if not await select_reference(a):return
	ck(view._detail_reference==a and view._detail_scene.source_member=="UI/CommonUi/Common_Slot.csb","only selected original detail icon is mounted")
	if not await tap(view._detail_area,"authored slot detail icon"):return
	if not ck(controller.item_tooltip_is_open() and controller.item_tooltip().last_result.get("item_class_id")==366 and controller.item_tooltip().reference==a and int(w.inventory[leather])==7,"details show exact selected original item with no implicit use"):return
	var detail_hash: String=hash_file()
	if not await tap(popup_button(controller.item_tooltip(),"Icon_Set/Del_On/Btn_Icon"),"original detail deletion entry"):return
	if not ck(controller.drop_confirm_is_open() and not controller.item_tooltip_is_open(),"tooltip delete opens the same separate confirmation"):return
	await tap(popup_button(delete_dialog(),"Btn_Cancel"),"tooltip deletion cancel")
	ck(int(w.inventory[leather])==7 and hash_file()==detail_hash,"tooltip deletion cancel also preserves disk and ownership")
	if not await tap(view._detail_area,"reopen selected details"):return
	if not await tap(popup_button(controller.item_tooltip(),"ToolTip_Button/ItemDrop_On/Button"),"authored acquisition list"):return
	var acquisition: Dictionary=h.original_main_ui_status.get("acquisition_popup",{})
	ck(controller.acquisition_is_open() and acquisition.get("handled",false) and bag.last_acquisition.get("item_class_id")==366 and bag.selected_item==a and int(w.inventory[leather])==7 and hash_file()==detail_hash,"acquisition touch opens the original exact leather source list without use or save")
	controller.close_acquisition();await frames()
	var initial_order: Array=w.ui_preferences.inventory_order.duplicate()
	var held: Dictionary=w.inventory.duplicate(true)
	if not await tap(native_button(Chrome.SORT_BUTTON),"authored sort menu"):return
	ck(view._inventory_scene.source_nodes[Chrome.SORT_OPTIONS].is_visible_in_tree(),"original sort options show only after touch")
	for criterion: String in ["weight","category","expiry"]:
		if not await tap(native_button(int(Chrome.SORT_KEYS[criterion])),"original sort "+criterion):return
		var order: Array=w.ui_preferences.inventory_order
		ck(order.has(a) and order.has(b) and bag.selected_item==a and w.inventory==held and bag.sorted_references.find(a)==order.find(a),"verified criterion reprojects the native owner order, keeping selection and counters")
		if criterion=="weight":
			ck(order.find(weapon)<order.find(a) and (order.find(a)<order.find(b))==(initial_order.find(a)<initial_order.find(b)),"heaviest first; same weight retains actual incoming UID order")
			if not await tap(native_button(int(Chrome.SORT_KEYS["weight"])),"reverse original weight arrow"):return
			var reversed: Array=w.ui_preferences.inventory_order
			ck(reversed.find(weapon)>reversed.find(a) and (reversed.find(a)<reversed.find(b))==(initial_order.find(a)<initial_order.find(b)),"reversed weight still preserves same-weight ties")
		if criterion=="category":ck(order.find(weapon)<order.find(a),"exact category grouping")
	await tap(native_button(Chrome.SORT_BUTTON),"close authored sort menu")
	ck(not view._inventory_scene.source_nodes[Chrome.SORT_OPTIONS].is_visible_in_tree(),"sort menu closes without changing inventory")
	# Apply a real bag category filter after the one-shot sort; the full order
	# must be restored when the filter clears, not replaced by its subset.
	var saved_order: Array=w.ui_preferences.inventory_order.duplicate()
	await tap(native_button(int(Chrome.TABS["장비"][1])),"original equipment filter")
	ck(not bag.sorted_references.has(a) and bag.sorted_references.has(weapon) and w.ui_preferences.inventory_order==saved_order,"filter shows only its own rows without destroying stored order")
	await tap(native_button(int(Chrome.TABS["전체"][1])),"original all filter")
	ck(bag.sorted_references==saved_order,"clearing filter restores exact order")
	await expanded_search(bag._display_item_name(bag._find_item_record(a),a), a, weapon, saved_order)
	await box_details(box)
	if not bag.selected_item==a and not await select_reference(a):return
	# Keeping original mode/scene, exercise cancel then changed selection.
	var disk: String=hash_file()
	var original: Dictionary=w.inventory.duplicate(true)
	if not await open_delete() or not await advance_one():return
	await tap(popup_button(delete_dialog(),"Btn_Cancel"),"original cancel")
	ck(not controller.drop_confirm_is_open() and w.inventory==original and hash_file()==disk,"cancellation leaves memory, receipt and disk unchanged")
	if not await open_delete() or not await advance_one():return
	await tap(view._hits[b].control,"underlying sibling while confirmation is active")
	ck(bag.selected_item==a and controller.drop_confirm_is_open(),"modal suppresses underlying slot touches")
	bag._select_item(b)
	await tap(popup_button(delete_dialog(),"Btn_Yes"),"stale selection confirm")
	ck(w.inventory==original and hash_file()==disk and int(STACK.proof(w,uid_a).remaining)==4 and int(STACK.proof(w,uid_b).remaining)==3,"a stale selection cannot delete either same-name receipt")
	if not await select_reference(a):return
	if not await open_delete() or not await advance_one():return
	# A real independent, authenticated change to this same receipt can
	# occur while a UI waits. The old frozen modal cannot apply to new stock.
	var prior: Dictionary=STACK.proof(w,uid_a)
	var used: Dictionary=STACK.stage_debit(w,[{"physical_id":uid_a,"quantity":1,"expected_quantity":prior.remaining,"expected_remaining":3,"source_native_stack_receipt":prior.receipt}])
	if not ck(used.get("ok",false) and STACK.sealed_save(w,used.overrides)==OK,"test fixture commits independent quantity change via the existing receipt ledger"):return
	w.inventory=used.overrides.inventory;w.item_instances=used.overrides.item_instances
	w.consumable_service.import_state(used.overrides.consumable_state)
	disk=hash_file();original=w.inventory.duplicate()
	await tap(popup_button(delete_dialog(),"Btn_Yes"),"stale same-receipt quantity")
	ck(w.inventory==original and hash_file()==disk and int(STACK.proof(w,uid_a).remaining)==3 and int(STACK.proof(w,uid_b).remaining)==3,"new quantity cannot be debited by a stale confirmation")
	w._publish_player_hud(false);h.refresh_inventory(w.inventory);await frames()
	if not await open_delete() or not await advance_one():return
	w.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary)->Error:return ERR_CANT_CREATE
	await tap(popup_button(delete_dialog(),"Btn_Yes"),"failed durable confirmation")
	w.equipment_collections.test_save_writer=Callable()
	ck(w.inventory==original and hash_file()==disk and int(STACK.proof(w,uid_a).remaining)==3,"failed save changes neither owned units nor prior bytes")
	if not await open_delete() or not await advance_one():return
	await tap(popup_button(delete_dialog(),"Btn_Yes"),"durable permanent deletion")
	ck(int(w.inventory[leather])==5 and int(STACK.proof(w,uid_a).remaining)==2 and int(STACK.proof(w,uid_b).remaining)==3 and w._item_locked(leather,uid_b) and hash_file()!=disk,"only one exact native quantity leaves, with durable source ledger and sibling preserved")
	w._load_game(true);await frames()
	ck(int(w.inventory[leather])==5 and w._item_locked(leather,uid_b) and int(STACK.proof(w,uid_b).remaining)==3,"reload preserves the permanent deletion and the other same-name lock")
	var new_index: int=(w.ui_preferences.inventory_order as Array).size()
	ck(grant(366,2,"new acquisition"),"a later genuine leather pickup is accepted")
	bag.prepare_source_inventory_model(true)
	ck(w.ui_preferences.inventory_order.size()==new_index+1 and w.ui_preferences.inventory_order[-1] not in saved_order,"one-shot sort does not move later acquisitions ahead of existing items")
	await merging_detail_lock(a, b, leather)
	await restart_routes()

func merging_detail_lock(reference: String, peer: String, item_name: String) -> void:
	var uid: String = reference.get_slice("@@@",1)
	var peer_uid: String = peer.get_slice("@@@",1)
	var locked_amount: int = int(STACK.proof(w,uid).remaining) + int(STACK.proof(w,peer_uid).remaining)
	var owned: int = int(w.inventory[item_name])
	# Keep the already locked peer first in this disposable fixture so the
	# existing merge absorbs the selected receipt during lock publication.
	var entry: Dictionary = w.item_instances[uid]
	w.item_instances.erase(uid)
	w.item_instances[uid] = entry
	await frames()
	if not await select_reference(reference) or not await tap(view._detail_area,"details of the second compatible stack"):return
	if not await tap(popup_button(controller.item_tooltip(),"ItemInfo/Nd_Unlock/Btn_Lock"),"lock the second stack"):return
	var peer_proof: Dictionary = STACK.proof(w,peer_uid)
	ck(not w.item_instances.has(uid) and w._item_locked(item_name,peer_uid) and int(peer_proof.get("remaining",0))==locked_amount and int(w.inventory[item_name])==owned,"the existing merge keeps the full amount and locks the surviving receipt")
	ck(not controller.item_tooltip_is_open() and bag.selected_item.is_empty(),"the absorbed receipt cannot leave a live tooltip or stale selection")
	w.deferred_save.cancel()

func box_details(reference: String) -> void:
	if not await select_reference(reference) or not await tap(view._detail_area,"owned box details"):return
	var popup: RefCounted = controller.item_tooltip()
	if not ck(controller.item_tooltip_is_open() and popup.member==TOOLTIP.DETAIL_MEMBER and popup.last_result.get("item_class_id")==BOX_ID,"the exact box uses the right-hand detail with its own class ID"):return
	var saved: String = hash_file()
	var inventory_before: Dictionary = w.inventory.duplicate(true)
	var acquisition: Control = popup_button(popup,"ToolTip_Button/ItemDrop_On/Button")
	var probability: Control = popup_button(popup,"Icon_Set/Probability_On/Btn_Icon")
	if not ck(is_instance_valid(acquisition) and acquisition.is_visible_in_tree() and is_instance_valid(probability) and probability.is_visible_in_tree(),"acquisition and probabilities are both available in the same box detail"):return
	if not await tap(acquisition,"box acquisition"):return
	ck(controller.acquisition_is_open() and bag.last_acquisition.get("item_class_id")==BOX_ID,"acquisition opens for this exact class")
	controller.close_acquisition()
	if not await tap(view._detail_area,"reopen box details") or not await tap(popup_button(popup,"Icon_Set/Probability_On/Btn_Icon"),"box probability"):return
	var rewards: RefCounted = controller.feature_window("box_probability")
	if not ck(rewards.is_open() and rewards.rows.size()==2,"probability opens the existing exact reward table"):return
	var reward_tab: Control = popup_button(rewards,"Nd_Type02/Nd_Tab/Btn_Probability_Reward_Off")
	var activations: Array=[]
	if is_instance_valid(reward_tab):reward_tab.get_parent().activation_result.connect(func(result: Dictionary) -> void: activations.append(result))
	await tap(reward_tab,"box probability reward tab")
	ck(not rewards._given_tab and rewards.rows.any(func(row: Dictionary) -> bool: return not row.given and is_equal_approx(row.percent,0.01)),"the original reward still shows its source 0.01 percent: "+str([rewards._given_tab,activations,rewards.rows.map(func(row: Dictionary) -> float: return row.percent)]))
	ck(w.inventory==inventory_before and hash_file()==saved,"both item information actions leave ownership and disk unchanged")
	rewards.close()
	bag.close_item_info()

func expanded_search(query: String, matching: String, unmatched: String, saved_order: Array) -> void:
	var inventory_before: Dictionary = w.inventory.duplicate()
	var saved: String = hash_file()
	if not await tap(native_button(Chrome.EXTENSION_BUTTON),"original bag expansion"):return
	if not ck(h.original_inventory_is_open() and view._native_capacity==8,"original eight-column bag opens: "+str(h.original_main_ui_status.get("inventory",{}))):return
	if not await tap(native_button(Chrome.SEARCH_BUTTON),"original expanded search"):return
	if not ck(controller.inventory_search_is_open(),"original search uses the shared editor"):return
	var search: RefCounted = view._search
	if not await type_query(search.input_control(),query):return
	if not await tap(area(search._renderer.source_nodes.get(5072)),"original Search apply"):return
	if not await tap(area(search._renderer.source_nodes.get(2808)),"original Search close"):return
	ck(bag.sorted_references.has(matching) and view._hits.has(matching) and not bag.sorted_references.has(unmatched) and not view._hits.has(unmatched),"applied search changes actual original slots: "+str([bag.sorted_references.has(matching),view._hits.has(matching),bag.sorted_references.has(unmatched),view._hits.has(unmatched)]))
	if not await tap(native_button(Chrome.CLEAR_SEARCH_BUTTON),"original search reset"):return
	ck(bag.search_line.text.is_empty() and bag.sorted_references==saved_order and view._hits.has(unmatched),"reset restores original bag slots in their saved acquisition order")
	ck(w.inventory==inventory_before and hash_file()==saved,"search and reset never consume inventory or write the save")
	await tap(native_button(Chrome.EXTENSION_BUTTON),"return to the original compact bag")
