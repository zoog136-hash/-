extends SceneTree
## Real Main, five retained 523 selectors, all 14 exact collection outcomes.
## Set TWILIGHT_EXACT_CHOICE_DEFINITIONS and optional UI44/images selectors.
const SRC=preload("res://scripts/resources/current523_definition_rows.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const PROJ=preload("res://scripts/loot/current523_native_item_projection.gd")
const IMG=preload("res://scripts/ui/source523_image_assets.gd")
var sibling_uid:String=""
var checks:int=0
var failures:Array[String]=[]
var grants:int=0
var denied:Dictionary={}

func _initialize()->void:run.call_deferred()

func ck(value:bool,title:String)->bool:
	checks+=1
	if not value:failures.append(title);printerr("EXACT_CHOICE_FAIL ",title)
	return value

func run()->void:
	ck(PROJ.EXACT_SELECTION_CARDS.size()==5,"scoped to five exact boxes")
	ck(PROJ.exact_selection_card(164643,{},{},{},{})=={},"does not admit the historical/complex box")
	var source:String=OS.get_environment("TWILIGHT_EXACT_CHOICE_DEFINITIONS")
	if not source.is_empty() and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated profile"):
		await live(source)
		ck(grants==14,"all fourteen selection rows were actually consumed once")
	print("EXACT_CHOICE_RESULT ",JSON.stringify({"checks":checks,"grants":grants,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func point(control:Control)->Vector2:
	return control.get_global_transform_with_canvas()*(control.size*0.5)

func tap(where:Vector2,touch:bool=true)->void:
	for down:bool in [true,false]:
		if touch:
			var event:=InputEventScreenTouch.new()
			event.index=14;event.position=where;event.pressed=down
			root.push_input(event,true)
		else:
			var event:=InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT;event.position=where;event.pressed=down
			root.push_input(event,true)

func native_btn(window:RefCounted, suffix:String)->Control:
	var bound:Dictionary=window._locate(window.input_scene(),window._out,suffix)
	if not bound.get("ok",false):return null
	var base:Node=bound.player.source_nodes.get(bound.offset)
	return base.get_meta("source_button")._input_area if is_instance_valid(base) and base.has_meta("source_button") else null

func row_btn(window:RefCounted,index:int)->Control:
	return window._row_buttons[index]._input_area if index<window._row_buttons.size() and is_instance_valid(window._row_buttons[index]) else null

func save_denied(_path:String,data:Dictionary)->Error:
	denied=data
	return ERR_CANT_CREATE

func live(source:String)->void:
	root.size=Vector2i(2048,919)
	var w:Node=load("res://Main.tscn").instantiate()
	root.add_child(w);current_scene=w;w.set_process(false);w.save_timer=-100000
	if not ck(QA.enter_game(w),"actual Main enters in isolated game"):w.queue_free();return
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",source);SRC.reset()
	if not ck(SRC.identity().get("source_sha256")==SRC.SOURCE_SHA,"exact original archive"):w.queue_free();return
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	# Optional private fixture mounted after Main entry: apply the same
	# production catalogue/collection registration that normally runs at boot.
	w.catalog_db=w.BASE508.apply_catalog(w.catalog_db)
	w.card_draw_fusion.configure(w.catalog_db)
	if IMG.selected():ck(IMG.selection_status().ready,"original image reader opened: "+str(IMG.selection_status()))
	var h:Node=w.hud
	for id:int in PROJ.EXACT_SELECTION_CARDS:
		var record:Dictionary=w.source_item_definition(id).get("native_record",{})
		var spec:Dictionary=STACK.profile(record).get("spec",{})
		var expected:Array=PROJ.EXACT_SELECTION_CARDS[id][2]
		if not ck(spec.get("kind")=="source_selectable_reward" and spec.get("rewards",[]).size()==expected.size(),"every actual original row is projected for #"+str(id)+" "+str(spec.get("blocked_reasons",[]))):continue
		for r:Dictionary in spec.rewards:
			ck(not STACK.card_binding(w,str(r.exact_choice_card.card_kind),int(r.exact_choice_card.card_id)).is_empty(),"real registered source collection card")
			ck(r.get("exact_choice_card",{}).get("source_choice_label","").length()>0 and SRC.row("ItemClass",int(r.item_class_id)).get("TestItem")==true and w.source_item_definition(int(r.item_class_id)).get("native_record",{}).is_empty(),"original label only; wrapper never supplied to bag")
		w.catalog_db["아이템"].append(record)
		w._index_catalog_item_sources()
		if not ck(INV.commit(w,[{"item_class_id":id,"amount":expected.size(),"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"}),"exact physical grant #"+str(id)):continue
		var uid:String=""
		for key:String in w.item_instances:
			if STACK.proof(w,key).get("receipt",{}).get("item_class_id")==id:uid=key;break
		if not ck(not uid.is_empty(),"financially durable original input in bag"):continue
		var name:String=str(w.item_instances[uid].name)
		var reference:String=name+"@@@"+uid
		if id==230602:
			var held:Dictionary=INV.stage(w,[{"item_class_id":int(id),"amount":1,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
			if not ck(held.get("ok",false),"additional same-name physical box fixture"):break
			for key:String in held.overrides.item_instances:
				if key!=uid and held.overrides.item_instances[key].get("name")==name:sibling_uid=key;break
			if not ck(not sibling_uid.is_empty(),"separate same-name physical receipt"):break
			w.ui_preferences.item_locks[name+"@@@"+sibling_uid]=true
			if not ck(w._save_game(true,held.overrides)==OK,"save independent sibling and its lock"):break
			w.inventory=held.overrides.inventory;w.item_instances=held.overrides.item_instances
		w._update_hud();h.refresh_inventory(w.inventory)
		if not h.original_inventory_is_open() and not h.lineage_inventory_ui.inventory_panel.is_visible_in_tree():h.toggle_inventory()
		await process_frame
		var native:bool=h.original_inventory_is_open()
		if OS.has_environment("TWILIGHT_SOURCE_UI"):ck(native,"real UI44 inventory must be mounted")
		for index:int in range(expected.size()):
			w.item_use_cooldowns.clear()
			h.lineage_inventory_ui.disarm_item_action();h.pointer_transfer.reset_tap_history()
			var bag_slot:Control=h.original_main_ui_controller._inventory_view._hits.get(reference,{}).get("control") if native else h.lineage_inventory_ui.slot_buttons.get(reference)
			if not ck(is_instance_valid(bag_slot),"selected physical slot is visible"):break
			var saved_before:String=FileAccess.get_sha256(w.save_path())
			var count:int=int(w.inventory.get(name,0))
			var physical_count:int=int(STACK.proof(w,uid).get("remaining",0))
			tap(point(bag_slot),native)
			ck(h.lineage_inventory_ui.item_action_label(reference)=="사용","first real slot gesture arms use")
			tap(point(bag_slot),native)
			await process_frame
			var dialog:Control=h.get_meta("patch523_reward_choice") if h.has_meta("patch523_reward_choice") else null
			if not ck(is_instance_valid(dialog),"second bag gesture opens selection: "+h.message_label.text):break
			ck(FileAccess.get_sha256(w.save_path())==saved_before and STACK.proof(w,uid).remaining==physical_count,"opening spends nothing")
			var entity:Array=expected[index]
			ck(dialog.original_rows()[index].entity_id==entity[0] and dialog.original_rows()[index].item_class_id==entity[2],"row identity is original, not UI index or card ID")
			var model:RefCounted=h.original_main_ui_controller.feature_window("reward_select") if native else null
			if native and not ck(model!=null and model.is_open() and not dialog.visible,"original RewardSelectBoxScene mounted, fallback hidden"):break
			if IMG.selected():
				var box:Dictionary=dialog.box_info()
				ck(box.item_class_id==id and dialog.choices.get_item_icon(index) is Texture2D,"bound original choice icon at actual row")
				if native:ck(model.last_result.get("filled",{}).get("pictures",0)==expected.size()+1,"all pressed box and original row textures actually mounted")
			if index==0:
				var cancel:Control=native_btn(model,"Btn_Cancel") if native else dialog.find_child("CancelSourceReward",true,false)
				if not ck(is_instance_valid(cancel),"actual cancel control"):break
				tap(point(cancel),native);await process_frame
				ck(not h.has_meta("patch523_reward_choice") and FileAccess.get_sha256(w.save_path())==saved_before and STACK.proof(w,uid).remaining==physical_count,"actual cancellation keeps exact receipt and quantity")
				h.lineage_inventory_ui.disarm_item_action();h.pointer_transfer.reset_tap_history()
				tap(point(bag_slot),native);tap(point(bag_slot),native);await process_frame
				dialog=h.get_meta("patch523_reward_choice") if h.has_meta("patch523_reward_choice") else null
				if not ck(is_instance_valid(dialog),"reopen through the same actual bag control"):break
				model=h.original_main_ui_controller.feature_window("reward_select") if native else null
			if native:
				var row:Control=row_btn(model,index)
				if not ck(is_instance_valid(row),"original Common_Slot has a button role"):break
				tap(point(row),true)
				if not ck(model.chosen==index,"actual touch selected the exact original row "+str(model.chosen)+" vs "+str(index)+" at "+str(point(row))):break
			else:
				var item_rect:Rect2=dialog.choices.get_item_rect(index)
				tap(dialog.choices.get_global_transform_with_canvas()*item_rect.get_center(),false)
				if not ck(dialog.choices.get_selected_items().size()==1 and dialog.choices.get_selected_items()[0]==index,"actual fallback gesture selects same source row"):break
			var confirm:Control=native_btn(model,"Btn_OK") if native else dialog.confirm
			if not ck(is_instance_valid(confirm),"actual confirm control"):break
			var before_rng:int=w.rng.state
			var previous_receipts:int=w.card_draw_fusion.source_card_receipts.size()
			if id==230602 and index==0:
				w.equipment_collections.test_save_writer=save_denied
				tap(point(confirm),native)
				ck(not denied.is_empty() and FileAccess.get_sha256(w.save_path())==saved_before and STACK.proof(w,uid).remaining==physical_count and w.card_draw_fusion.source_card_receipts.size()==previous_receipts and w.rng.state==before_rng,"actual confirm with denied disk leaves input/collection/RNG and file unchanged")
				w.equipment_collections.test_save_writer=Callable();w.patch523_owner_state_problem=""
			tap(point(confirm),native)
			var receipts:Array=w.card_draw_fusion.source_card_receipts
			var receipt:Dictionary=receipts[-1] if not receipts.is_empty() else {}
			if ck(int(w.inventory.get(name,0))==count-1 and receipts.size()==previous_receipts+1 and receipt.get("card_id")==entity[3] and receipt.get("selection_entity_id")==entity[0] and receipt.get("input_physical_id")==uid and w.rng.state==before_rng,"actual confirm saves only chosen card plus one physical debit: #"+str(id)+" / "+str(index)+" / "+h.message_label.text):
				grants+=1
			if id==230602:ck(STACK.proof(w,sibling_uid).get("remaining")==1,"same-name sibling never consumed by selected box")
			await process_frame
			ck(not h.has_meta("patch523_reward_choice") and FileAccess.get_sha256(w.save_path())!=saved_before,"successful box result persisted")
	if grants>0:
		w._load_game(true)
		ck(w.card_draw_fusion.source_card_receipts.size()>=grants,"collection receipts survived actual Main reload")
		ck(not sibling_uid.is_empty() and STACK.proof(w,sibling_uid).get("remaining")==1,"same-name sibling survives reload unchanged")
	w.queue_free();await process_frame
