extends SceneTree
const SOURCE=preload("res://scripts/quests/source_quest523.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const BRIDGE=preload("res://scripts/quests/quest_return239.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const KEY="귀환 주문서 (각인) · 원본#239"
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("QUEST_RETURN239_FAIL: "+label)
func norm(value: Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func make_world()->TwilightWorld:
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.player.set_physics_process(false)
	check(QA.enter_game(world),"real class-selected Main")
	return world
func held_id(world: TwilightWorld,quantity: int)->String:
	for id: String in world.item_instances:
		var physical: Dictionary=world.item_instances[id]
		if int(physical.get("record",{}).get("source_item_class_id",0))==239 and int(physical.get("source_reward_quantity",0))==quantity:return id
	return ""
func use(world: TwilightWorld,id: String)->Dictionary:
	return world.consumable_service.use_owned_quest_return(id) if not id.is_empty() else world.consumable_service.use_owned_native_return(KEY)
func move_away(world: TwilightWorld,destination: Vector2)->bool:
	# Controlled QA positioning on the actual already-loaded aden field. This
	# does not grant inventory or claim natural random/map-entry coverage.
	for x: int in range(-8,9):
		for y: int in range(-8,9):
			var point: Vector2=destination+Vector2(x*48,y*48)
			if point.distance_to(destination)>96 and world.field_map.walkable(point) and world.field_map.point_clear(point):world.player.global_position=point;return true
	return false
func _initialize()->void:call_deferred("run")
func run()->void:
	var seed: String="";var fresh: bool=false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
		if arg.begins_with("--quest-pack="):fresh=true;check(SOURCE.install_zip(arg.trim_prefix("--quest-pack=")).ok,"unchanged received v1 installs")
	if not fresh:
		check(seed.length()==64 and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"unmodified copy of actual811 source-grant save")
		if not failures.is_empty():quit(1);return
	var world: TwilightWorld=make_world()
	check(world.quest_item_provider.has_definition(239) and world.consumable_service.has_method("use_owned_native_return"),"narrow published result consumer and authenticated native definition installed")
	if fresh:
		for batch: int in range(100):
			world.quest_auto.retry_at=0;world.quest_auto.next_scan=0
			var prior: int=world.quest_service.claimed.size();world.quest_auto.tick(world)
			if prior==world.quest_service.claimed.size():break
		var quantity: int=0
		for rows: Array in world.quest_service.item_grants.values():
			for receipt: Dictionary in rows:
				if int(receipt.item_class_id)==239:quantity+=int(receipt.quantity)
		check(quantity==212 and int(world.inventory.get(KEY,0))==quantity,"real full original auto-acquisition durably issued exact212 native239 with receipts")
	var id: String="" if fresh else held_id(world,5)
	var single: String="" if fresh else held_id(world,1)
	var owned: Dictionary={} if fresh else OWN.proof(world,id)
	check(fresh or (not id.is_empty() and not single.is_empty() and owned.get("ok",false)),"actual already-granted selected239 input has immutable proof")
	if not fresh and not owned.get("ok",false):world.queue_free();quit(1);return
	var key: String=KEY if fresh else str(owned.inventory_key)
	var original_receipt: Dictionary={} if fresh else world.item_instances[id].quest_reward_receipt.duplicate(true)
	var original_quantity: int=int(world.inventory[key])
	var claims: Dictionary=world.quest_service.claimed.duplicate(true)
	var slots: Array=world.quickslots.duplicate(true)
	var destination: Vector2=world.consumable_service._safe_region_position()
	if destination==Vector2.INF:destination=world._spawn_position()
	check(destination.is_finite() and move_away(world,destination),"controlled starting position differs from actual verified aden destination")
	check(world._save_game(true)==OK,"controlled starting position saved without new item ownership")
	var path: String=world.save_path();var hash: String=FileAccess.get_sha256(path)
	var position: Vector2=world.player.global_position
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	var state: Dictionary=world.quest_service.export_state()
	var lock_key: String=key if fresh else key+"@@@"+id
	world.ui_preferences.item_locks[lock_key]=true
	var result: Dictionary=use(world,id)
	check(not result.ok and not result.saved and int(result.consumed)==0 and world.player.global_position==position and FileAccess.get_sha256(path)==hash,"actual selected/stack lock blocks movement and consumption")
	world.ui_preferences.item_locks.erase(lock_key)
	world.player.stun_remaining=1
	result=use(world,id)
	check(not result.ok and world.inventory==inventory and world.player.global_position==position and FileAccess.get_sha256(path)==hash,"controlled stun preserves owned239 and saved location")
	world.player.stun_remaining=0
	var hp: int=world.hp;world.hp=0;result=use(world,id);world.hp=hp
	check(not result.ok and world.inventory==inventory and FileAccess.get_sha256(path)==hash,"dead player cannot consume239")
	world.active_map_id="qa_unvalidated_return_map";result=use(world,id);world.active_map_id="aden_world"
	check(not result.ok and world.inventory==inventory and world.player.global_position==position and FileAccess.get_sha256(path)==hash,"controlled wrong-map context refuses without source-map fabrication")
	result=world.consumable_service.use_owned_native_return(key if not fresh else "귀환 주문서")
	check(not result.ok and int(result.consumed)==0 and FileAccess.get_sha256(path)==hash,"raw held or legacy alias cannot bypass canonical owned-native API")
	if not fresh:
		for field: String in ["source_sha256","quest_id","reward_id","item_class_id","bless_code_id","quantity"]:
			world.item_instances[id].quest_reward_receipt[field]="wrong" if field in ["source_sha256","quest_id"] else 99999
			result=use(world,id)
			check(not result.ok and FileAccess.get_sha256(path)==hash,"tampered239 receipt blocked: "+field)
			world.item_instances[id]=instances[id].duplicate(true)
		world.item_instances[id].erase("quest_reward_receipt");result=use(world,id)
		check(not result.ok and FileAccess.get_sha256(path)==hash,"historical no-receipt input is preserved")
		world.item_instances[id]=instances[id].duplicate(true)
		var quote: Dictionary=BRIDGE.prepare(world,id)
		world.item_instances[id].source_reward_quantity=4
		check(not BRIDGE.current(world,quote),"stale239 debit input is rejected")
		world.item_instances[id]=instances[id].duplicate(true)
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
	result=use(world,id)
	check(not result.ok and not result.saved and int(result.consumed)==0 and world.inventory==inventory and world.item_instances==instances and world.quest_service.export_state()==state,"movement save failure preserves exact inputs and receipts")
	check(world.player.global_position==position and FileAccess.get_sha256(path)==hash,"movement save failure restores position and original bytes")
	world.equipment_collections.test_save_writer=Callable()
	if not fresh:
		var debug_input: Dictionary=BRIDGE.prepare(world,id)
		if not debug_input.get("ok",false):printerr("QUEST_RETURN239_PRE_USE "+JSON.stringify(debug_input))
	if fresh:
		result=use(world,id)
		check(result.ok and result.saved and int(result.consumed)==1 and result.inventory_key==KEY and result.source_item_id==239,"published native result API confirms one genuine quest-owned consumption")
	else:
		var bag: Variant=world.hud.lineage_inventory_ui
		bag.set_character_state(world.hud.character_state);bag.inventory=world.inventory
		bag._select_item(key+"@@@"+id);check(not bag.detail_action.disabled,"actual inventory selected physical239 button available")
		bag.detail_action.pressed.emit()
		check(int(world.item_instances[id].source_reward_quantity)==4 and world.item_instances[id].quest_reward_receipt==original_receipt,"actual inventory UI consumes one of five without changing original proof or physicalID")
		check(not world.inventory.has(KEY),"raw239 use never creates or renames to canonical native stock")
	check(world.player.global_position==destination and int(world.inventory[key])==original_quantity-1,"one owned unit and verified same-map return become live together")
	var durable: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(durable.position==[destination.x,destination.y] and int(durable.inventory[key])==original_quantity-1 and durable.quest_state==norm(world.quest_service.export_state()),"actual movement,debit and receipt commit in the same durable save")
	check(world.quest_service.claimed==claims and world.quickslots==slots,"return preserves all original claim history and50 slots")
	check(move_away(world,destination) and world._save_game(true)==OK,"second controlled same-field position saved")
	world.equipment_collections.test_save_writer=func(target: String,data: Dictionary)->Error:
		var error: Error=WRITER.write(target,data)
		return ERR_FILE_CANT_WRITE if error==OK else error
	result=use(world,"" if fresh else single)
	if not result.get("ok",false):printerr("QUEST_RETURN239_POSTWRITE "+JSON.stringify(result))
	check(result.ok and result.saved and int(result.consumed)==1 and world.player.global_position==destination and not world.quest_service.save_blocked,"write-then-error confirms complete movement/receipt/debit exactly once")
	world.equipment_collections.test_save_writer=Callable()
	hash=FileAccess.get_sha256(path)
	if not fresh:
		result=use(world,single)
		check(not result.ok and not world.item_instances.has(single) and FileAccess.get_sha256(path)==hash,"spent physical reference cannot consume a different same-name239")
	check(not world.quest_auto.complete(world,["m523:quest:9951"]) and FileAccess.get_sha256(path)==hash,"return use never makes its original quest payable again")
	var final_inventory: Dictionary=norm(world.inventory);var final_instances: Dictionary=norm(world.item_instances);var final_state: Dictionary=norm(world.quest_service.export_state())
	world.queue_free();await process_frame;world=make_world()
	check(norm(world.inventory)==final_inventory and norm(world.item_instances)==final_instances and norm(world.quest_service.export_state())==final_state,"new Main preserves actual stock,remainder and receipt state")
	check(world.player.global_position==destination and world.quest_service.claimed==claims,"new Main restores committed aden position and original claims")
	world.quest_auto.refresh_context(world)
	var completed: int=0;var pending: int=0
	for row: Dictionary in world.quest_service.entries(world.level,world.inventory):
		if row.get("source_id")!=null and row.completed:
			completed+=1
			if not row.rewards.get("pending_use",[]).is_empty():pending+=1
	print("QUEST_RETURN239_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"mode":"fresh_native_source_grants" if fresh else "actual_held_receipt_selected","completed":completed,"pending_use_completed":pending,"final_save_sha256":FileAccess.get_sha256(path),"input_save_sha256":seed,"source_item_id":239,"controlled_qa_conditions":["safe-field starting position","lock","stun","dead","wrong-map flag only"],"scope":"same verified aden_world; real original reward ownership; no transient grant/rename/cross-map engine"}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
