extends SceneTree
## Synthetic PR238 identity-contract regression on actual Main; no source pack claim.
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label); printerr("PATCH523_NATIVE_CRAFT_FAIL: ",label)

func _initialize() -> void: call_deferred("run")

func native_record(id: int, label: String) -> Dictionary:
	return {"name":label+" · 원본#"+str(id),"source_display_name":label,"source":"lineagem_patch523","source_snapshot":"patch523","sourceId":"m523:item:"+str(id),"source_item_class_id":id,"source_m_native_item":true,"source_test_item":false,"source_is_stackable":false,"source_level_limit_min":0,"source_level_limit_max":0,"source_class_ids":[],"source_equip_slot_ids":[23],"slot":"earring","type":"fixture_earring","grade":"일반","weight":3,"source_bless_raw":1}

func snapshot(world: TwilightWorld) -> String:
	return JSON.stringify([world.inventory,world.item_instances,world.equipped_items,world.gold,world.next_item_instance_id])

func run() -> void:
	var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world); world.set_process(false); world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main class-selection entered for synthetic contract regression")
	world.player.set_physics_process(false); world.field_population.set_process(false)
	var input: Dictionary=native_record(600001,"fixture_native_input")
	var output: Dictionary=native_record(600002,"fixture_native_output")
	var recipe: Dictionary={"id":"patch523:9000001","name":"Synthetic native identity contract","source_snapshot":"patch523","source_craft_id":9000001,"category":"장신구","adena":5,"popup_text_id":0,
		"materials":[{"item":input.name,"source_id":"600001","quantity":1,"level":3,"bless_code":2,"physical":true}],
		"result":{"item":output.name,"source_id":"600002","quantity":1,"level":1,"bless_code":1,"physical":true}}
	for entry: Array in [["600001",input],["600002",output]]:
		world.patch523_equipment.data.items[entry[0]]={"catalog_record":entry[1],"item_class":{},"item_bonuses":[],"enchant_effects":[]}
	world.patch523_equipment.recipes[recipe.id]=recipe
	world.crafting.recipes[recipe.id]=recipe
	world.inventory.clear(); world.item_instances.clear(); world.equipped_items.clear()
	world.inventory[input.name]=1; world.inventory["fixture_native_input"]=5
	var saved_input: Dictionary=input.duplicate(true); saved_input.source_bless_raw=2; saved_input.bless_state="blessed"
	var proof: Dictionary={"source_snapshot":"patch523","source_npc_id":99001,"source_item_class_id":600001,"bless_raw":2,"bless_state":"blessed","required_quest_id":0,"source_rows":[{"ID":1,"NpcClassID":99001,"ItemClassID":600001,"Bless":2,"RequiredQuestID":0,"source_row_1based":1}],"selection_policy":"host_uniform_distinct_items_then_distinct_variants","quantity_policy":"host_one"}
	saved_input["source_m_drop_proof"]=proof; saved_input["source_m_item_id"]=600001
	world.item_instances["23001"]={"name":input.name,"level":3,"element":"","element_level":0,"record":saved_input,"sourceId":input.sourceId,"bless_state":"blessed","source_bless_code":2}
	world.item_instances["23001"]["source_m_drop_proof"]=proof.duplicate(true)
	world.next_item_instance_id=23002; world.gold=100
	check(world._save_game(true)==OK,"synthetic native baseline saves without global catalog registration")
	check(not world._craft_quote(recipe.id,1).get("ok",false),"private rule alone cannot register or fabricate missing native catalog output")
	check(world._catalog_item_from_source_id(output.sourceId).is_empty(),"missing exact native identity remains absent from current catalog")
	# Explicit synthetic catalog registration models the external prerequisite.
	world.catalog_db["아이템"].append(input); world.catalog_db["아이템"].append(output)
	world._index_catalog_item_sources()
	check(world._craft_quote(recipe.id,1).get("ok",false),"actual registered namespace records make mixed-state native crafting eligible")
	check(world.patch523_equipment._source_ids_match([1,2],[2.0,1.0]) and not world.patch523_equipment._source_ids_match([1],[1.5]),"native class/slot identities compare integer IDs across JSON numeric representation")
	var spoof: Dictionary=world.item_instances["23001"].duplicate(true); spoof.sourceId="600001"
	check(world.patch523_equipment.identity(spoof).is_empty(),"numeric top-level ID cannot impersonate a native ownership namespace")
	spoof=world.item_instances["23001"].duplicate(true); spoof.record.source_class_ids=[9]
	check(not world.patch523_equipment._state_matches(spoof,recipe.materials[0],false),"mismatched registered class metadata protects a native material")
	spoof=world.item_instances["23001"].duplicate(true); spoof.record.source_bless_raw=1
	check(world.patch523_equipment.bless_code(spoof)==-1,"native raw blessing and physical blessing must agree")
	spoof=world.item_instances["23001"].duplicate(true); spoof.record.source_m_drop_proof.required_quest_id=1
	check(not world.patch523_equipment._state_matches(spoof,recipe.materials[0],false),"quest-restricted or disagreeing source drop provenance cannot be consumed")
	# Synthetic supplier evidence uses the exact public f078a465 shape; this
	# verifies the consumer contract, not natural exploration/quest supply.
	var supplied: Dictionary=world.item_instances["23001"].duplicate(true)
	supplied.erase("source_m_drop_proof");supplied.record.erase("source_m_drop_proof");supplied.record.erase("source_m_item_id")
	supplied["source_m_reward_proof"]={"source_snapshot":"patch523","item_class_id":600001,"source_item_class_id":600001,"bless":1,"enchant":0,"supplier":{"fixture":"shared-public-contract"}}
	check(world.patch523_equipment._state_matches(supplied,recipe.materials[0],false),"supplier initial receipt remains valid after legitimate current blessing/enchant change")
	var uuid: String="beef0000000000000000000000000001"
	var quote: Dictionary=world.patch523_equipment.quote(recipe.id,1,world.inventory,world.gold,world._patch523_craft_item_index(),{uuid:supplied},{},100,100000,{}, {},{})
	check(quote.get("ok",false) and quote.get("consumed_ids",[])==[uuid],"shared supplier UUID is selected without coercing it to a numeric ID")
	var locked_quote: Dictionary=world.patch523_equipment.quote(recipe.id,1,world.inventory,world.gold,world._patch523_craft_item_index(),{uuid:supplied},{},100,100000,{str(input.name)+"@@@"+uuid:true},{},{})
	check(not locked_quote.get("ok",false),"shared supplier UUID respects original physical lock")
	for mutation: Dictionary in [{"item_class_id":600002},{"source_item_class_id":600002},{"supplier":{}},{"bless":1.5},{"enchant":-1}]:
		var invalid: Dictionary=supplied.duplicate(true);invalid.source_m_reward_proof.merge(mutation,true)
		check(not world.patch523_equipment._state_matches(invalid,recipe.materials[0],false),"invalid supplier evidence preserves exact physical material "+str(mutation))
	var pending: Dictionary=supplied.duplicate(true);pending["source_pending_use"]=true;pending["source_reward_quantity"]=3
	check(not world.patch523_equipment._state_matches(pending,recipe.materials[0],false),"uninterpreted restricted pending quantity stays with its source owner")
	var stack: Dictionary=native_record(600003,"fixture_receipt_stack");stack.slot="material";stack.source_is_stackable=true
	world.patch523_equipment.data.items["600003"]={"catalog_record":stack,"item_class":{},"item_bonuses":[],"enchant_effects":[]}
	var stack_material: Dictionary={"item":stack.name,"source_id":"600003","quantity":1,"level":0,"bless_code":1,"physical":false}
	check(world.patch523_equipment.available_material(stack_material,{str(stack.name):3},{str(stack.name):stack},{},{},{},false)==3,"ordinary exact stack remains consumable without owned reward entities")
	check(world.patch523_equipment.available_material(stack_material,{str(stack.name):3},{str(stack.name):stack},{"fixture-receipt":{"name":stack.name,"source_pending_use":true,"source_reward_quantity":3}},{},{},false)==0,"synthetic pending-quantity stack is protected until its receipt owner can debit it atomically")
	var before: String=snapshot(world)
	var sha: String=FileAccess.get_sha256(world.save_path())
	world.source_save_blocked=true; world._craft_requested(recipe.id,1)
	check(snapshot(world)==before and FileAccess.get_sha256(world.save_path())==sha,"native transaction save failure preserves ID, blessing, wallet and durable bytes")
	world.source_save_blocked=false
	world.hud.open_crafting(); await process_frame
	var listing: ItemList=world.hud.workspace.find_child("CraftRecipes",true,false)
	var selected: bool=false
	for i: int in range(listing.item_count):
		if listing.get_item_metadata(i)==recipe.id:
			listing.select(i); listing.item_selected.emit(i); selected=true; break
	var action: Button=world.hud.workspace.find_child("CraftExecute",true,false)
	check(selected and not action.disabled,"registered native contract uses existing real crafting UI")
	action.pressed.emit(); await process_frame
	var confirm: Button=world.hud.find_child("ConfirmTransaction",true,false)
	check(confirm!=null,"native ownership contract uses actual confirmation")
	confirm.pressed.emit()
	check(world.gold==95 and not world.inventory.has(input.name) and int(world.inventory.get(output.name,0))==1 and int(world.inventory["fixture_native_input"])==5,"native exact ownership key consumes once without touching same-label host stack")
	check(not world.item_instances.has("23001") and world.item_instances.has("23002") and world.item_instances["23002"].sourceId=="m523:item:600002" and world.item_instances["23002"].record.source_item_class_id==600002,"native output preserves namespace, original ID and new physical ID")
	check(world.patch523_equipment.identity(world.item_instances["23002"])=="600002" and int(world.item_instances["23002"].level)==1,"native output remains usable as an exact future source material")
	world.hud.inventory_item_activated.emit(str(output.name)+"@@@23002")
	check(not world.equipped_items.is_empty(),"native output reaches actual inventory equip path")
	check(world._save_game(true)==OK,"native output and equipment save")
	world._load_game(true)
	check(world.item_instances.has("23002") and world.item_instances["23002"].sourceId=="m523:item:600002" and world.gold==95,"native namespace and cost survive actual Main reload")
	world.queue_free(); await process_frame
	print("PATCH523_NATIVE_CRAFT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"synthetic_contract":true,"pr238_pack_bytes_verified":false}))
	quit(0 if failures.is_empty() else 1)
