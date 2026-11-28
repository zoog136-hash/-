extends "res://tests/source_inventory_controls_main_test.gd"
## Real Main, pinned 523 definitions, original UI46 and disposable save.
const ACQUISITION = preload("res://scripts/acquisition523/item_acquisition523.gd")
const CATALOG = preload("res://scripts/loot/current523_catalog_stack.gd")
const LONGSWORD := 702
const MAGIC_STONE := 254
const STORAGE_STONE := 19443
const IRON := 379
const HELMET := 4891

func result_marker() -> String: return "ORIGINAL_BAG_LINKED_ACTIONS_RESULT"

func fallback() -> void:
	ck(false,"set TWILIGHT_INVENTORY_CONTROLS_DEFINITIONS and the pinned UI pack")

func exact(archive: String) -> void:
	controller=h.original_main_ui_controller
	if SOURCE.identity().is_empty():
		OS.set_environment("TWILIGHT_PATCH523_CONTENT",archive)
		SOURCE.reset()
		w.skill_awakening=w.SKILL_AWAKENING.new()
		w.skill_awakening.configure(w)
	if not ck(is_instance_valid(controller) and SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"real Main uses the original UI and pinned definition archive"):return
	for item_id: int in [LONGSWORD,MAGIC_STONE,STORAGE_STONE,IRON,HELMET]:
		var record: Dictionary=w.source_item_definition(item_id).get("native_record",{})
		if not ck(not record.is_empty(),"real registered source item %d" % item_id):return
		if w._catalog_item_from_source_id(str(record.sourceId)).is_empty():w.catalog_db["아이템"].append(record)
	w._index_catalog_item_sources()
	if not ck(grant(LONGSWORD,1,"plain equipment",7) and grant(MAGIC_STONE,3,"recipe input") and grant(IRON,20,"iron"),"real original gear and materials are saved by Main"):return
	var weapon: String=physical_reference(LONGSWORD,7)
	var material: String=physical_reference(MAGIC_STONE)
	var iron: String=physical_reference(IRON)
	if not ck(not weapon.is_empty() and not material.is_empty() and not iron.is_empty(),"exact physical references in the bag"):return
	legacy_delete_quote(weapon)
	await equipment_routes(weapon)
	await skill_inspector_route()
	w._release_idle_original_models()
	if not w.crafting.recipes.has("patch523:13"):w._load_patch523_equipment()
	if not ck(w.crafting.recipes.has("patch523:13"),"the ordinary production loader admits the original iron recipe"):return
	ck(ACQUISITION.connected_crafts(STORAGE_STONE,w.crafting.recipes).is_empty(),"same label on #19443 cannot borrow #254's recipes")
	var stone_links: Array[Dictionary]=ACQUISITION.connected_crafts(MAGIC_STONE,w.crafting.recipes)
	var source_recipes: Array[int]=[]
	for row: Dictionary in SOURCE.related("ItemCraftInput","ItemClassID",MAGIC_STONE):
		source_recipes.append(int(row.ItemCraftID))
	print("ITEM_LINK_MAGIC_STONE ",JSON.stringify({"active":stone_links,"reference_ids":source_recipes}))
	if not stone_links.is_empty():await crafting_route(material,MAGIC_STONE)
	else:
		if not await open_details(material):return
		ck(popup_button(controller.item_tooltip(),"ToolTip_Button/BasicInfo/Button")==null,"recipes absent from Production stay out of this item card")
		bag.close_item_info()
	await crafting_route(iron,IRON)

func physical_reference(item_id: int, level: int = -1) -> String:
	for uid: String in w.item_instances:
		var entry: Dictionary=w.item_instances[uid]
		if int(entry.get("record",{}).get("source_item_class_id",0))==item_id and (level<0 or int(entry.get("level",0))==level):return "%s@@@%s" % [entry.name,uid]
	return ""

func legacy_delete_quote(reference: String) -> void:
	var legacy: Dictionary=w._catalog_item_from_source_id(str(LONGSWORD))
	var mapped: Dictionary=CATALOG.native_record(w,legacy)
	if not ck(int(mapped.get("source_item_class_id",0))==LONGSWORD,"older sword carries its exact registered ItemClass"):
		return
	var uid: String=reference.get_slice("@@@",1)
	var saved: Dictionary=w.item_instances[uid]
	var inventory: Dictionary=w.inventory
	w.inventory=inventory.duplicate()
	w.inventory[str(saved.name)]=int(w.inventory.get(saved.name,0))-1
	w.inventory[str(legacy.name)]=int(w.inventory.get(legacy.name,0))+1
	var instance: Dictionary={"name":legacy.name,"level":saved.level,"record":legacy,"sourceId":legacy.sourceId}
	w.item_instances[uid]=instance
	var old_reference: String="%s@@@%s" % [legacy.name,uid]
	var quote: Dictionary=Delete.quote(w,old_reference)
	ck(quote.get("ok",false) and quote.get("item_class_id")==LONGSWORD and quote.get("uid")==uid,"verified legacy gear can request the same exact deletion confirmation")
	instance.sourceId="387"
	ck(not Delete.quote(w,old_reference).get("ok",false),"an inconsistent legacy physical ID is refused")
	w.item_instances[uid]=saved
	w.inventory=inventory

func open_details(reference: String) -> bool:
	if not h.original_inventory_is_open():h.toggle_inventory()
	await frames()
	view=controller._inventory_view
	if not ck(h.original_inventory_is_open(),"original main bag is active"):return false
	if not await select_reference(reference):return false
	if not await tap(view._detail_area,"held item detail button"):return false
	return ck(controller.item_tooltip_is_open() and controller.item_tooltip().reference==reference,"exact item detail is on screen")

func equipment_routes(reference: String) -> void:
	if not await open_details(reference):return
	var popup: RefCounted=controller.item_tooltip()
	var before: String=hash_file()
	if not await tap(popup_button(popup,"ToolTip_Button/Enchant_On/Button"),"equipment Enhance"):return
	var forge: RefCounted=controller.enchant_window()
	ck(is_instance_valid(forge) and forge.is_open() and forge._bag_target==reference,"enhance opens on this exact gear instance")
	ck(hash_file()==before,"opening the forge consumes nothing")
	h._close_workspace()
	if not await open_details(reference):return
	if not await tap(popup_button(popup,"ToolTip_Button/Registration_On/Button"),"equipment Collection Registration"):return
	var book: RefCounted=controller.feature_window("item_book")
	ck(is_instance_valid(book) and book.is_open() and book._focus_item_uid==reference.get_slice("@@@",1),"the original collection receives the selected physical item")
	ck(hash_file()==before,"opening the collection consumes nothing")
	h._close_workspace()
	if not await open_details(reference):return
	if not await tap(popup_button(popup,"Icon_Set/Del_On/Btn_Icon"),"equipment Delete"):return
	var confirmation: RefCounted=controller.drop_confirm_popup()
	if not ck(confirmation.is_open() and confirmation.last_result.get("permanent_delete",false),"deletion asks in its own original confirmation"):return
	await tap(popup_button(confirmation,"Btn_Cancel"),"cancel equipment deletion")
	ck(w.item_instances.has(reference.get_slice("@@@",1)) and hash_file()==before,"cancel preserves the equipment and durable inventory")

func crafting_route(reference: String, item_id: int) -> void:
	var links: Array[Dictionary]=ACQUISITION.connected_crafts(item_id,w.crafting.recipes)
	if not ck(not links.is_empty(),"live recipes include ItemClass #%d" % item_id):return
	if not await open_details(reference):return
	var popup: RefCounted=controller.item_tooltip()
	var before: String=hash_file()
	if not await tap(popup_button(popup,"ToolTip_Button/BasicInfo/Button"),"Craft shortcut for ItemClass #%d" % item_id):return
	if not ck(controller.acquisition_is_open(),"the card opens the authored recipe choices"):return
	var picker: RefCounted=controller._acquisition_popup
	ck(picker.last_result.mode=="craft" and picker.last_result.item_class_id==item_id and picker.last_result.crafts_connected==links.size(),"recipe choice contains only connected recipes for this ItemClass")
	var recipe_id: String=links[0].recipe_id
	if not await tap(routed_button(picker._scene,&"_open_craft",[recipe_id]),"recipe choice in the original popup"):return
	var production: RefCounted=controller.production_window()
	ck(is_instance_valid(production) and production.is_open() and production.selected()==recipe_id,"recipe touch selects the correct live recipe without executing it")
	ck(hash_file()==before,"opening the production route preserves ownership and save bytes")
	h._close_workspace()

func routed_button(scene: Node, method: StringName, args: Array = []) -> Control:
	for node: Node in scene.find_children("*","Node2D",true,false):
		if not node.has_meta("source_button"):continue
		var source: Variant=node.get_meta("source_button")
		if not is_instance_valid(source):continue
		var action: Callable=source._activation
		if action.get_method()==method and action.get_bound_arguments()==args and source._input_available():return source._input_area
	return null

func skill_inspector_route() -> void:
	h._close_workspace()
	h.open_skills()
	await frames()
	var skills: RefCounted=controller.skill_window()
	if not ck(is_instance_valid(skills) and skills.is_open() and not skills._slots.is_empty(),"top HUD opens the original skill list"):return
	var slot: Dictionary=skills._slots[0]
	if not await tap(slot.area,"original skill slot"):return
	if not ck(skills.selected()==slot.id and skills.is_open(),"single tap selects the original skill"):return
	if not await tap(skills._slots[0].area,"same skill again"):return
	if not ck(skills.is_open() and not h.workspace.is_visible_in_tree(),"repeated skill tap keeps the original list"):return
	if not await tap(routed_button(skills._scene,&"_detail_requested"),"explicit skill details"):return
	var inspector: Control=h.skills_view
	if not ck(is_instance_valid(inspector),"existing inspector is open"):return
	ck(inspector.focus_only and inspector.selected.get("id")==slot.id and inspector.cards.item_count==0 and not inspector.cards.is_visible_in_tree(),"the selected inspector opens without instantiating the whole fallback list")
	h._go_back()
	await frames()
	ck(skills.is_open() and not h.workspace.is_visible_in_tree(),"back from the inspector restores the original skill list")
