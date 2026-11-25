extends "res://tests/source_inventory_controls_main_test.gd"
## Reuses the disposable Main, genuine grants and viewport touch driver from
## the inventory controls suite. Private inputs are installed after boot.
const Forge=preload("res://scripts/ui/renewal_forge.gd")
const Box=preload("res://scripts/ui/original_ui/source_main_box_probability_window.gd")
const BagID:=315982
const DaggerID:=357591
const BlessID:=3581
const EnchantID:=6411

func result_marker() -> String:return "SOURCE_ITEM_ACTION_ROUTES_RESULT"

func fallback() -> void:
	var calls: Array=[]
	h.blessing_target_requested.connect(func(scroll: String, target: String) -> void:calls.append([scroll,target]))
	var target: Dictionary={"name":"장비","target_id":"장비@@@target","scroll_reference":"주문서@@@chosen","success_chance":60.0}
	ck(Forge.request_blessing(h,"주문서",target),"existing confirmation opens without a private pack")
	target.scroll_reference="주문서@@@other"
	var confirm: Control=h.get_node("Root/TwilightConfirmation")
	await frames()
	await tap(confirm.confirm_button,"blessing confirmation")
	ck(calls==[["주문서@@@chosen","장비@@@target"]],"confirmation retains both selected references")

func references(id: int) -> Array[String]:
	var result: Array[String]=[]
	for uid: String in w.item_instances:
		var physical: Dictionary=w.item_instances[uid]
		if int(physical.get("record",{}).get("source_item_class_id",0))==id:
			result.append(str(physical.name)+"@@@"+uid)
	result.sort()
	return result

func remaining(reference: String) -> int:
	return int(STACK.proof(w,reference.get_slice("@@@",1)).get("remaining",0))

func exact(archive: String) -> void:
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",archive)
	SOURCE.reset()
	w.skill_awakening=w.SKILL_AWAKENING.new()
	w.skill_awakening.configure(w)
	if not ck(SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"original source archive admitted"):return
	for id: int in [BagID,DaggerID,326,BlessID,EnchantID,234774]:
		var record: Dictionary=w.source_item_definition(id).get("native_record",{})
		if not ck(not record.is_empty(),"original source item "+str(id)):return
		w.catalog_db["아이템"].append(record)
	w._index_catalog_item_sources()
	for id: int in [BagID,DaggerID,326,234774]:
		if not ck(grant(id,1,"owned "+str(id)),"original grant "+str(id)):return
	for id: int in [BlessID,EnchantID]:
		# Each grant is legal. Together they exceed the original stack cap even
		# after a debit, so the ordinary inventory merge keeps both receipts.
		var cap: int=int(SOURCE.row("ItemClass",id).MaxStackAmount)
		if not ck(grant(id,cap,"one") and grant(id,3,"two") and references(id).size()==2,"two separate genuine receipts "+str(id)):return
	controller=h.original_main_ui_controller
	h.toggle_inventory()
	await frames()
	if not ck(h.original_inventory_is_open(),"native main inventory"):return
	view=controller._inventory_view
	await item_detail_routes()
	bag.close_item_info()
	var overlay: RefCounted=controller.feature_window("box_probability")
	if overlay!=null:overlay.close()
	if h.original_inventory_is_open():h.toggle_inventory()
	await frames()
	await coupon_result_routes()
	await enchant_routes()
	await bless_routes(references(326)[0])

## Both reviewed shine panels retain their pixels and leave touch with the
## actual result button. Opening an item card never replays the craft.
func coupon_result_routes() -> void:
	for id: int in [266828,266848]:
		var canonical: Dictionary=w.source_item_definition(id).get("native_record",{})
		if not ck(not canonical.is_empty(),"coupon canonical item "+str(id)):return
		w.catalog_db["아이템"].append(canonical)
		w._index_catalog_item_sources()
		var before: String=hash_file()
		var name: String=str(canonical.name)
		var opened: Dictionary=controller.try_open_feature_window("craft_result",[{"name":name,"item_class_id":id,"quantity":1,"batch":1}])
		if not ck(opened.get("filled",{}).get("pictures")==1,"original animated coupon in result "+str(id)):return
		var result: RefCounted=controller.feature_window("craft_result")
		var button: Control
		var activations: Array=[]
		for child: Node in result._scene.find_children("*","Node2D",true,false):
			if child.get_script()!=preload("res://scripts/ui/original_ui/sprite_scene.gd") or child.source_member!=result.SLOT:continue
			var player: Dictionary=child.bound_source_scene(15012)
			if player.get("ok",false):
				ck(player.evidence.playback.clip=="normal" and player.evidence.playback.repeat,"authored coupon clip")
				button=area(child.source_nodes.get(15728))
				child.source_nodes[15728].get_meta("source_button").activation_result.connect(func(result_value:Dictionary)->void:activations.append(result_value.get("ok",false)))
				break
		await frames()
		if not await tap(button,"original coupon slot "+str(id)):return
		ck(controller.item_tooltip_is_open() and controller.item_tooltip().reference==name and before==hash_file() and activations==[true],"slot opens the selected original item without saving "+str([id,activations,controller.item_tooltip().reference,name]))
		controller.close_item_tooltip()
		result.close()
		await frames()

func item_detail_routes() -> void:
	var dagger: String=references(DaggerID)[0]
	if not ck(bag.open_item_info(dagger),"owned dagger detail"):return
	var popup: RefCounted=controller.item_tooltip()
	var slot: Dictionary=TREE.locate(popup._scene,popup._out,"ND_ItemList/Slot/Sp_IconSample")
	var attachment: Dictionary=slot.player.bound_source_scene(slot.offset) if slot.get("ok",false) else {}
	ck(attachment.get("ok",false) and attachment.evidence.member.ends_with("Fx_Item_Weapon_Dagger_Sole_Giltas.csb") and attachment.evidence.playback.get("clip")=="normal" and attachment.evidence.playback.get("repeat")==true,"exact private icon scene plays in the original tooltip Sprite")
	if attachment.get("ok",false) and DisplayServer.get_name()!="headless":
		await check_drawn_icon(attachment.player)
	await frames()
	await tap(popup_button(popup,"Icon_Set/Detail_On/Btn_Icon"),"dagger acquisition button")
	ck(controller.acquisition_is_open() and h.original_main_ui_status.get("acquisition_popup",{}).get("item_picture",false),"dagger keeps its original scene icon on the acquisition screen")
	controller.close_acquisition()
	bag.close_item_info()
	var box: String=references(BagID)[0]
	if not ck(bag.open_item_info(box),"owned original mixed bag detail"):return
	await frames()
	var inventory_before: Dictionary=w.inventory.duplicate()
	var before: String=hash_file()
	var chance_button: Dictionary=TREE.locate(popup._scene,popup._out,"Icon_Set/Probability_On/Btn_Icon")
	if not ck(chance_button.get("ok",false),"held box discloses probability"):return
	var activations: Array=[]
	var node: Node=chance_button.player.source_nodes[chance_button.offset]
	node.get_meta("source_button").activation_result.connect(func(result:Dictionary)->void:activations.append(result))
	if not await tap(area(node),"tooltip probability"):return
	var rewards: RefCounted=controller.feature_window("box_probability")
	if not ck(rewards.is_open() and rewards.last_result.filled.rows==1 and rewards.last_result.filled.pictures==1 and rewards.rows.size()==2,"held box opens its authored fixed tab and reward icon "+str([activations,rewards.last_result]).left(450)):return
	await tap(popup_button(rewards,"Nd_Type02/Nd_Tab/Btn_Probability_Reward_Off"),"probability reward tab")
	ck(not rewards._given_tab and rewards.last_result.filled.rows==1 and rewards.rows.any(func(row: Dictionary) -> bool:return not row.given and is_equal_approx(row.percent,0.01)),"same class and original denominator give 0.01%")
	ck(w.inventory==inventory_before and before==hash_file(),"viewing probabilities spends nothing")
	rewards.close()
	bag.close_item_info()
	var weapon: String=references(326)[0]
	ck(bag.open_item_info(weapon) and popup_button(popup,"Icon_Set/Probability_On/Btn_Icon")==null,"original weapon does not offer bag probability")
	var safe: Dictionary=TREE.locate(popup._scene,popup._out,"Icon_Set/Enchant_On/Text_Enchant")
	var rule: Dictionary=w._source_enhancement_rule(w.item_instances[weapon.get_slice("@@@",1)].record,0,"normal","",w.item_instances[weapon.get_slice("@@@",1)])
	ck(int(rule.get("safe_level",0))>0 and safe.get("ok",false) and safe.player._bindings[safe.offset].text=="+%d" % int(rule.safe_level),"tooltip displays the selected weapon's source safe level")

## Only the attached item scene changes visibility. Count pixels that return
## to their original colors at the same location. Keep all frames in memory.
func check_drawn_icon(icon: Node2D) -> void:
	var mode:=icon.process_mode
	icon.process_mode=Node.PROCESS_MODE_DISABLED
	await RenderingServer.frame_post_draw
	var shown: Image=root.get_texture().get_image()
	var center: Vector2=icon.get_global_transform_with_canvas().origin*Vector2(shown.get_size())/root.get_visible_rect().size
	var rect:=Rect2i(Vector2i(center)-Vector2i(80,80),Vector2i(160,160)).intersection(Rect2i(Vector2i.ZERO,shown.get_size()))
	icon.hide()
	await RenderingServer.frame_post_draw
	var hidden: Image=root.get_texture().get_image()
	icon.show()
	await RenderingServer.frame_post_draw
	var restored: Image=root.get_texture().get_image()
	icon.process_mode=mode
	var pixels: int=0
	for y: int in range(rect.position.y,rect.end.y):
		for x: int in range(rect.position.x,rect.end.x):
			var color:=shown.get_pixel(x,y)
			if color==restored.get_pixel(x,y) and color!=hidden.get_pixel(x,y):pixels+=1
	print("SOURCE_ITEM_ICON_RENDERED_PIXELS ",pixels)
	ck(pixels>0,"original icon contributes actual pixels in its native slot")

func enchant_button(window: RefCounted, path: String) -> Control:
	var located: Dictionary=TREE.locate(window._scene,window.node_keys(),path)
	return area(located.player.source_nodes.get(located.offset)) if located.get("ok",false) else null

func enchant_routes() -> void:
	var refs: Array[String]=references(EnchantID)
	if not ck(refs.size()==2,"two live original enchant stacks"):return
	var name_value: String=refs[0].get_slice("@@@",0)
	h.inventory_item_activated.emit(refs[0])
	await frames()
	var window: RefCounted=controller.enchant_window()
	if not ck(window.is_open() and window._scroll_row.reference==refs[0],"regular enchant opens for selected physical stock"):return
	await tap(enchant_button(window,window.P_COMMON+"Nd_Slot/Inventory_Slot0/Btn"),"open source scroll tab")
	var list: Array=Forge.owned_scrolls(h)
	var index: int=list.find_custom(func(row: Dictionary) -> bool:return row.reference==refs[1])
	if not ck(index>=0 and window.tab()=="scroll","second receipt is displayed"):return
	var bound: Dictionary=window._row_spec(list,index/4,"")
	var callback: Callable=bound[window.SET_SLOTS[index%4]+"/Btn"].activate
	w._set_item_locked(refs[1],true)
	callback.call()
	ck(window._scroll_row.reference==refs[0] and w._enhancement_scroll_selection.uid==refs[0].get_slice("@@@",1),"stale displayed slot never redirects to another owned scroll")
	w._set_item_locked(refs[1],false)
	window._set_tab("scroll")
	callback.call()
	ck(window._scroll_row.reference==refs[1] and window._scroll_row.count==remaining(refs[1]),"same-name scroll tab switches exact receipt and pictured count")
	var target: String=references(234774)[0]
	var sibling: int=remaining(refs[0])
	var chosen: int=remaining(refs[1])
	w.enhancement_series_quiet=true
	h.enhancement_requested.emit(name_value,target)
	ck(remaining(refs[0])==sibling and remaining(refs[1])==chosen-1,"original armor scroll strengthens the original event token using only selected stock")
	h._close_workspace()

func bless_routes(weapon: String) -> void:
	var refs: Array[String]=references(BlessID)
	if not ck(refs.size()==2,"two live original blessing stacks"):return
	var sibling: int=remaining(refs[0])
	var chosen: int=remaining(refs[1])
	var name_value: String=refs[1].get_slice("@@@",0)
	h.inventory_item_activated.emit(refs[1])
	await frames()
	var window: RefCounted=controller.enchant_window()
	if not ck(window.is_open() and window._blessing and window._scroll_row.reference==refs[1],"source blessing tab receives the selected physical scroll"):return
	window.select_target(references(DaggerID)[0])
	var slot: Dictionary=TREE.locate(window._scene,window.node_keys(),window.P_COMMON+"Nd_Slot/Inventory_Slot1/Sp_IconSample")
	var attachment: Dictionary=slot.player.bound_source_scene(slot.offset) if slot.get("ok",false) else {}
	ck(attachment.get("ok",false) and attachment.evidence.member.ends_with("Fx_Item_Weapon_Dagger_Sole_Giltas.csb") and attachment.evidence.playback.get("playing")==true,"same original animation plays as the selected forge target")
	window.select_target(weapon)
	var chance: float=window._entry().get("success_chance",-1)
	ck(chance>0 and chance<=100 and window._entry().success_basis==preload("res://scripts/equipment_blessing.gd").SOURCE_BASIS,"target's original BlessSuccessRate")
	await tap(enchant_button(window,window.P_ENCHANT+"Btn_Probability_Bless"),"original blessing chance")
	await tap(enchant_button(window,window.P_SMELT_START),"original start blessing")
	var dialog: Control=h.get_node_or_null("Root/TwilightConfirmation")
	if not ck(is_instance_valid(dialog) and remaining(refs[1])==chosen,"original start waits for confirmation"):return
	w._set_item_locked(refs[1],true)
	await tap(dialog.confirm_button,"confirm after selected stock locks")
	ck(remaining(refs[0])==sibling and remaining(refs[1])==chosen,"stale confirmation preserves both stacks")
	w._set_item_locked(refs[1],false)
	var disk: String=hash_file()
	var state: int=w.rng.state
	w.equipment_collections.test_save_writer=func(_path:String,_data:Dictionary)->Error:return ERR_CANT_CREATE
	var applied: bool=w.consumable_service.apply_bless_scroll(refs[1],weapon,0.0)
	w.equipment_collections.test_save_writer=Callable()
	ck(not applied and disk==hash_file() and w.rng.state==state and remaining(refs[1])==chosen and remaining(refs[0])==sibling,"failed save restores both stocks, RNG and original file")
	h.inventory_item_activated.emit(refs[1]);await frames()
	window.select_target(weapon)
	await tap(enchant_button(window,window.P_SMELT_START),"retry original blessing")
	dialog=h.get_node_or_null("Root/TwilightConfirmation")
	if not ck(is_instance_valid(dialog),"confirmation for fresh selected receipt"):return
	await tap(dialog.confirm_button,"confirm original blessing")
	ck(remaining(refs[0])==sibling and remaining(refs[1])==chosen-1,"exactly the confirmed sibling was debited")
	ck(not w.consumable_service.apply_bless_scroll(name_value+"@@@removed",weapon,0.0),"missing UID cannot fall back to name balance")
	w._load_game(true);await frames()
	ck(remaining(refs[0])==sibling and remaining(refs[1])==chosen-1,"reload retains exact physical debit")
