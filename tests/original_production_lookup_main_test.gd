extends "res://tests/source_inventory_controls_main_test.gd"

const ONE := "qa_craft_lookup_iron"
const TWO := "qa_craft_lookup_leather"
const HELMET_ID := "patch523:13"
const HELMET := "해골 투구 (각인) · 원본#4891"
const IRON := "철 · 원본#379"

var production: RefCounted

func result_marker() -> String:return "ORIGINAL_PRODUCTION_LOOKUP_RESULT"

func fallback() -> void:
	h.open_crafting()
	await frames()
	ck(h.workspace.is_visible_in_tree() and h.active_section=="crafting","an unconfigured game keeps its offline crafting route")

func exact(archive: String) -> void:
	controller=h.original_main_ui_controller
	if not ck(is_instance_valid(controller),"pinned original UI is selected"):return
	var heading: String="검증용 철제 투구"
	w.crafting.recipes[ONE]={"name":heading,"category":"방어구","result":{"item":heading,"quantity":1},"materials":[{"item":"검증 철 조각","quantity":1}]}
	w.crafting.recipes[TWO]={"name":heading,"category":"방어구","result":{"item":heading,"quantity":1},"materials":[{"item":"검증 가죽 조각","quantity":1}]}
	h.toggle_menu()
	await frames()
	var tile: Control=h.workspace.find_child("MenuTile_crafting",true,false)
	if not ck(is_instance_valid(tile),"the full HUD menu contains the crafting entry"):return
	h.menu_scroll_view.ensure_control_visible(tile)
	await frames()
	if not await tap(tile,"actual crafting menu entry"):return
	if not ck(controller.production_window_is_open() and not h.workspace.visible,"the original Production window owns crafting"):return
	production=controller.production_window()
	var before: String=hash_file()
	var items: Dictionary=w.inventory.duplicate()
	var gold: int=w.gold
	if not await tap(_button("Nd_TabMenu/Btn_Search_Off"),"original crafting search tab"):return
	ck(production.tab()=="search" and production._item_ids.is_empty(),"empty searches do not scan or display a recipe list")
	if not await _search_for("검증 철 조각",false):return
	ck(production._item_ids==[ONE] and production.selected()==ONE,"material search chooses the matching recipe ID")
	if not await tap(_button("Nd_SearchBar/Btn_Select/Btn_Material"),"original search kind chooser"):return
	if not await tap(_button("Nd_SearchBar/Nd_Popup_Select/Btn_Premium_Off"),"authored result search kind"):return
	if not await _search_for(heading,true):return
	ck(production._item_ids==[ONE,TWO],"result search keeps both distinct recipes for an identical item name")
	ck(w.inventory==items and w.gold==gold and before==hash_file(),"search routing never charges or saves")
	if not await tap(_row_action(TWO,"_toggle_favorite"),"original recipe star"):return
	ck(w.ui_preferences.get("craft_recipe_favorites",{})=={TWO:true},"only the second recipe ID is bookmarked")
	if not await tap(_button("Nd_TabMenu/Btn_Bookmark_Off"),"authored favorites tab"):return
	ck(production.tab()=="favorites" and production._item_ids==[TWO] and not h.workspace.visible,"favorites stay in the original recipe list")
	w.deferred_save.cancel()
	ck(w._save_game(true)==OK,"bookmarks ride the existing settings save")
	w._load_game(true)
	await frames()
	ck(w.ui_preferences.get("craft_recipe_favorites",{})=={TWO:true},"reload retains the exact favorite among equal output names")
	if not await tap(_row_action(TWO,"_toggle_favorite"),"enabled star removes this favorite"):return
	ck(production._item_ids.is_empty() and w.ui_preferences.get("craft_recipe_favorites",{}).is_empty(),"removing the last star empties the original favorites tab")
	ck(w.gold==gold,"saving optional display metadata does not change costs")
	root.size=Vector2i(960,432)
	await frames()
	if not await tap(_button("Nd_TabMenu/Btn_Search_Off"),"search tab remains reachable at compact size"):return
	if not await _search_for(heading,false):return
	if "--actual-recipes" in OS.get_cmdline_user_args():await _actual_recipe(archive)
	h._close_workspace()

func _button(suffix: String) -> Control:
	var located: Dictionary=TREE.locate(production._scene,production.node_keys(),suffix)
	return area(located.player.source_nodes.get(located.offset)) if located.get("ok",false) else null

func _row_action(id: String, method: String) -> Control:
	var row: Node2D=production._item_rows.get(production._item_ids.find(id))
	if not is_instance_valid(row):return null
	for node: Node in row.find_children("*","Node2D",true,false):
		if not node.has_meta("source_button"):continue
		var button: Node=node.get_meta("source_button")
		var action: Callable=button._activation
		if action.is_valid() and action.get_method()==method and action.get_bound_arguments()==[id] and button._input_available() and button._input_area.is_visible_in_tree():return area(node)
	return null

func _search_for(query: String, enter: bool) -> bool:
	if not await tap(_button("Nd_SearchBar/Btn_Search"),"original production search keypad entry"):return false
	if not ck(production.search_is_open() and controller.crafting_search_is_open(),"the authored keypad is the active modal"):return false
	var modal: Dictionary=production.search_presentation()
	var editor: LineEdit=modal.editor
	editor.clear()
	var previous: Array=production._item_ids.duplicate()
	if not await type_query(editor,query):return false
	ck(production._item_ids==previous,"typing alone does not rebuild the recipe list")
	if enter:
		var key:=InputEventKey.new()
		key.pressed=true
		key.keycode=KEY_ENTER
		root.push_input(key,true)
		await frames()
	else:
		if not await tap(area(modal.renderer.source_nodes.get(5072)),"authored keypad search button"):return false
	return ck(not production.search_is_open() and production._query==query,"submitting returns to the original results list")

func _actual_recipe(archive: String) -> void:
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",archive)
	SOURCE.reset()
	w.skill_awakening=w.SKILL_AWAKENING.new()
	w.skill_awakening.configure(w)
	for id: int in [379,4891]:
		var item: Dictionary=w.source_item_definition(id).get("native_record",{})
		if not ck(not item.is_empty(),"the source defines the exact recipe input or output "+str(id)):return
		w.catalog_db["아이템"].append(item)
	w._index_catalog_item_sources()
	w._load_patch523_equipment()
	if not ck(SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA and w.crafting.recipes.has(HELMET_ID),"the verified rules install the real helmet recipe (%s)" % w.patch523_equipment.problem):return
	w.inventory[IRON]=20
	w.gold=10500
	h.refresh_inventory(w.inventory)
	if not await _search_for("해골 투구",true):return
	if not ck(production._item_ids.has(HELMET_ID),"the actual source recipe appears in the native search list"):return
	if production.selected()!=HELMET_ID and not await tap(_row_action(HELMET_ID,"_select"),"actual result row"):return
	if not ck(production.selected()==HELMET_ID and w._craft_quote(HELMET_ID,1).get("ok",false),"the search selection uses the real craft quote"):return
	var original: String=hash_file()
	for accept: bool in [false,true]:
		if not await tap(_button("Production_Tab_List/Nd_Production/Btn_Production"),"actual recipe's authored craft button"):return
		var review: Control=h.get_node_or_null("Root/TwilightConfirmation")
		if not ck(is_instance_valid(review) and review.get_script().resource_path=="res://scripts/ui/original_ui/source_main_awakening_review.gd","the actual craft asks for the original confirmation"):return
		if accept:
			for _page: int in review._pages.size():
				if not await tap(review.confirm_button,"original craft confirm"):return
		else:
			await tap(review.cancel_button,"original craft cancel")
			ck(w.gold==10500 and w.inventory.get(IRON)==20 and original==hash_file(),"cancelling an actual craft from search spends nothing")
	ck(w.gold==500 and int(w.inventory.get(IRON,0))==0 and int(w.inventory.get(HELMET,0))==1 and original!=hash_file(),"confirmed original recipe spends the exact cost and saves one helmet")
