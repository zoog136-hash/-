extends SceneTree

const QA=preload("res://tests/qa_class_selection.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const SMITH=preload("res://scripts/equipment523/native_elemental_smith.gd")
const DROPS=preload("res://scripts/loot/patch523_monster_drops.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const FORGE=preload("res://scripts/ui/renewal_forge.gd")
const REFINE=preload("res://scripts/refine523/bless_refine523_service.gd")
const ENCHANT=preload("res://scripts/ui/original_ui/source_main_enchant_window.gd")
const NAMED=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const FIRST_SLOT=ENCHANT.P_INV+"ScrollView_Item/Inventory_Slot_Set/Nd_Slot/Slot_1/Btn"

var checks: int=0
var failures: Array[String]=[]
var rejected: Dictionary={}

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ELEMENTAL_SMITH_FAIL: ",label)
	return ok

func _reject(_path: String, candidate: Dictionary) -> Error:
	rejected=candidate
	return ERR_FILE_CANT_WRITE

func _run() -> void:
	if check(SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA and not OS.get_environment("TWILIGHT_SOURCE_UI_SHA256").is_empty(),"verified original definitions and original UI are mounted"):
		await _exercise()
	print("NATIVE_ELEMENTAL_SMITH_BAG_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _exercise() -> void:
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.save_timer=-100000
	if check(QA.enter_game(world,"기사"),"Main entered using the normal character route"):
		await process_frame
		await _exercise_bag(world)
	world.queue_free()
	await process_frame

func _exercise_bag(world: TwilightWorld) -> void:
	check(world.equipment523.store.pack.is_empty(),"the same installed definition ZIP is sufficient without the separate equipment rules pack")
	var rows: Array[Dictionary]=[]
	for item: Array in [[27,2],[223762,2],[223772,1],[224978,1],[365311,1]]:
		rows.append({"item_class_id":item[0],"amount":item[1],"bless_raw":1,"enchant":0})
	rows.append({"item_class_id":223762,"amount":1,"bless_raw":2,"enchant":0})
	if not check(INV.commit(world,rows,{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"}),"native stock and equipment issued through the regular owner"):
		return
	var by_id: Dictionary={}
	for uid: String in world.item_instances:
		var id: int=int(world.item_instances[uid].get("record",{}).get("source_item_class_id",0))
		if not by_id.has(id):by_id[id]=[]
		by_id[id].append(uid)
	if not check(by_id.get(27,[]).size()==2 and by_id.has(223762) and by_id.has(224978) and by_id.has(365311),"physical IDs for both weapons and the normal and limited materials"):
		return
	var weapon: String=by_id[27][0]
	var weaker: String=by_id[27][1]
	var scroll: String=""
	var blessed_scroll: String=""
	for uid: String in by_id[223762]:
		if world.item_instances[uid].record.source_bless_raw==1:scroll=uid
		else:blessed_scroll=uid
	if not check(not scroll.is_empty() and not blessed_scroll.is_empty(),"normal and blessed original scrolls retain separate owned references"):
		return
	var expired: String=by_id[224978][0]
	var limited: String=by_id[365311][0]
	for uid: String in [weapon,weaker]:
		world.item_instances[uid]["element"]="fire"
		world.item_instances[uid]["element_level"]=3 if uid==weapon else 2
	world._update_hud()
	check(world._save_game(true)==OK,"the original compatible and incompatible weapon states persist")
	var saved: String=FileAccess.get_sha256(world.save_path())
	var rng_before: int=world.rng.state
	var gold_before: int=world.gold
	var time_zone: int=int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540))
	var date: Dictionary=SMITH.input(world.item_instances[limited].record)
	var cutoff: int=DROPS.source_deadline_unix(int(date.get("cutoff",0)),time_zone)
	check(cutoff>0 and SMITH.period_error(date,cutoff-1,time_zone).is_empty() and not SMITH.period_error(date,cutoff,time_zone).is_empty(),"the referenced original deadline changes exactly at the boundary")
	var limited_available: bool=SMITH.period_error(date,int(Time.get_unix_time_from_system()),time_zone).is_empty()
	_use(world,limited,"사용")
	var dated_window: Variant=world.hud._original_enchant_window()
	check((dated_window!=null and dated_window.last_result.get("candidates")==1) if limited_available else dated_window==null,"the dated bag route follows the original absolute deadline")
	var normal_rows: Array=FORGE.owned_scrolls(world.hud)
	check(normal_rows.any(func(row: Dictionary)->bool:return row.get("instance_id")==scroll) and not normal_rows.any(func(row: Dictionary)->bool:return row.get("instance_id")==expired),"original scroll tab lists usable stacks and hides expired stacks")
	_use(world,expired,"사용")
	check(world.hud._original_enchant_window()==null and world.hud.message_label.text.contains("만료") and world.item_instances.has(expired),"an expired source scroll keeps its stock and explains why from the bag")
	if by_id.has(223772):
		_use(world,by_id[223772][0],"사용")
		var water: Variant=world.hud._original_enchant_window()
		check(water!=null and water.last_result.get("mode")=="elemental_smith" and water.last_result.get("candidates")==0,"a water scroll lists neither fire weapon")
	_use(world,blessed_scroll,"사용")
	var blessed_window: Variant=world.hud._original_enchant_window()
	if check(blessed_window!=null and blessed_window.last_result.get("material_uid")==blessed_scroll,"the blessed scroll opens with its own physical ID"):
		await _press(blessed_window,FIRST_SLOT)
		var pools: Array=[]
		for slot: Dictionary in blessed_window._smelt_quote.get("slots",[]):pools.append(int(slot.raw.ElementalSmithProbGroupID))
		check(pools==[24,34],"blessed source rates use their own two probability groups")
	_use(world,scroll,"사용")
	check(FileAccess.get_sha256(world.save_path())==saved and world.rng.state==rng_before and world.gold==gold_before,"opening these windows preserves the save, currency and RNG")
	var window: RefCounted=world.hud._original_enchant_window()
	var window_status: Variant=window.last_result if window!=null else world.hud.original_main_ui_status.get("enchant_window",{})
	if not check(window!=null and window_status.get("mode")=="elemental_smith" and window_status.get("material_uid")==scroll and window_status.get("candidates")==1,"the authored 세공 tab opens for the exact stack and only the +3 fire weapon: "+str(window_status)):
		return
	var tab: Dictionary=NAMED.locate(window._scene,window.node_keys(),ENCHANT.P_COMMON+"Tab/Nd_Properties/Btn_Properties_On")
	check(tab.get("ok",false),"the authored 속성 세공 tab is present")
	await _press(window,FIRST_SLOT)
	check(window.selected()==weapon and window._smelt_quote.get("slots",[]).size()==2 and window._smelt_quote.get("gold_cost")==0,"the authored slot opens the original two-pool quote")
	world.equipment_collections.test_save_writer=_reject
	await _press(window,ENCHANT.P_SMELT_START)
	check(rejected.get("item_instances",{}).get(weapon,{}).get("equipment523",{}).has("elemental_smith"),"confirmation stages the exact weapon result in the writer")
	check(STACK.proof(world,scroll).get("remaining",0)==2 and world.rng.state==rng_before and world.gold==gold_before and FileAccess.get_sha256(world.save_path())==saved,"failed write preserves stack, weapon, currency and RNG")
	world.equipment_collections.test_save_writer=Callable()
	await _press(window,FIRST_SLOT)
	await _press(window,ENCHANT.P_SMELT_START)
	var effect: Dictionary=world.item_instances[weapon].get("equipment523",{}).get("elemental_smith",{})
	if not check(effect.get("target_id")==weapon and effect.get("material_source_id")==223762 and effect.get("bonus_ids",[]).size()==2 and STACK.proof(world,scroll).get("remaining",0)==1,"the exact fire scroll and two option rows commit together"):
		return
	check(world.item_instances[weapon].level==0 and world.item_instances[weapon].element_level==3 and not world.item_instances[weaker].get("equipment523",{}).has("elemental_smith"),"ordinary enhancement and the other identical weapon stay intact")
	check(REFINE.equipment(world,weapon).get("code")=="extra_record","refine refuses the newly processed exact weapon with a controlled ownership reason")
	check(window._smith_results.size()==2 and window.last_result.get("stat_rows")==2,"committed option values are displayed in Korean in the source window")
	check(not window._smelt_execute().get("ok",false) and STACK.proof(world,scroll).get("remaining",0)==1,"a repeated confirm does not spend the second copy")
	_use(world,weapon,"장착")
	check(world._is_instance_equipped(weapon),"the processed weapon still equips via the bag")
	check(_combat_connected(world),"equipped damage and critical chance reach the combat stat path")
	check(world._save_game(true)==OK,"equipped state also saves")
	world._load_game(true)
	check(_combat_connected(world) and STACK.proof(world,scroll).get("remaining",0)==1,"effect, selected weapon and exact debit survive reload")
	world.hud._close_workspace()
	var before_refine: String=FileAccess.get_sha256(world.save_path())
	world.hud.open_bless_refine523()
	check(world.hud.original_main_ui_controller.refine_window_is_open() and not world.hud.workspace.visible,"the older refine shortcut mounts the original window in Main")
	check(FileAccess.get_sha256(world.save_path())==before_refine,"opening the original refine window leaves the character unchanged")

func _combat_connected(world: TwilightWorld) -> bool:
	return world._equipment_inven_sum("equipment523_element_flat_fire")>0 and world._equipment_inven_sum("equipment523_element_crit_pct")>0

func _use(world: TwilightWorld, uid: String, action: String) -> void:
	var hud: Node=world.hud
	hud._close_workspace()
	hud.toggle_inventory()
	var reference: String=str(world.item_instances[uid].name)+"@@@"+uid
	if not check(hud.original_inventory_is_open() and hud.original_inventory_select(reference).get("ok",false),"original bag selects "+reference):return
	check(hud.lineage_inventory_ui.item_action_label(reference)==action,"the bag shows the correct action "+action)
	check(hud.original_inventory_activate_selected(reference).get("emitted",false),"the same owned reference goes through the original bag action")

func _press(window: RefCounted, suffix: String) -> void:
	var located: Dictionary=NAMED.locate(window._scene,window.node_keys(),suffix)
	var node: Variant=located.player.source_nodes.get(located.offset) if located.get("ok",false) else null
	var button: Variant=node.get_meta("source_button",null) if is_instance_valid(node) else null
	var area: Variant=button.get("_input_area") if is_instance_valid(button) else null
	if not check(area is Control and area.is_visible_in_tree(),"authored input area "+suffix):return
	var point: Vector2=area.get_global_transform_with_canvas()*(area.size*0.5)
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=0
		event.pressed=pressed
		event.position=point
		root.push_input(event,true)
		await process_frame
