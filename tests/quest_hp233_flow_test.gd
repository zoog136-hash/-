extends SceneTree
const SOURCE=preload("res://scripts/quests/source_quest523.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const KEY="체력 회복제 (각인) · 원본#233"
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("QUEST_HP233_FAIL: "+label)
func norm(value: Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func make_world()->TwilightWorld:
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.player.set_physics_process(false)
	check(QA.enter_game(world),"actual saved/created class-selected Main")
	return world
func use(world: TwilightWorld,id: String)->void:
	if id.is_empty():world._on_inventory_item_activated(KEY);return
	var bag: Variant=world.hud.lineage_inventory_ui
	bag.set_character_state(world.hud.character_state);bag.inventory=world.inventory
	bag._select_item(str(world.item_instances[id].name)+"@@@"+id)
	check(not bag.detail_action.disabled,"actual selected physical potion button enabled")
	bag.detail_action.pressed.emit()
func _initialize()->void:call_deferred("run")
func run()->void:
	var seed: String="";var fresh: bool=false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
		if arg.begins_with("--quest-pack="):fresh=true;check(SOURCE.install_zip(arg.trim_prefix("--quest-pack=")).ok,"unchanged original v1 installed")
	if not fresh:
		check(seed.length()==64 and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"untouched copy of actual original811-grant save")
		if not failures.is_empty():quit(1);return
	var world: TwilightWorld=make_world()
	check(world.quest_item_provider.has_definition(233),"verified full-row HP consumer available")
	if fresh:
		for batch: int in range(100):
			world.quest_auto.retry_at=0;world.quest_auto.next_scan=0
			var prior: int=world.quest_service.claimed.size();world.quest_auto.tick(world)
			if prior==world.quest_service.claimed.size():break
		var quantity: int=0
		for rows: Array in world.quest_service.item_grants.values():
			for receipt: Dictionary in rows:
				if int(receipt.item_class_id)==233:quantity+=int(receipt.quantity)
		check(quantity==6940 and int(world.inventory.get(KEY,0))==quantity,"all72 original HP rewards actually issued exact6940 native units with quest receipts")
	var id: String="";var owned: Dictionary={}
	if not fresh:
		for physical_id: String in world.item_instances:
			var physical: Dictionary=world.item_instances[physical_id]
			if int(physical.get("record",{}).get("source_item_class_id",0))==233 and int(physical.get("source_reward_quantity",0))==100:id=physical_id;break
		owned=OWN.proof(world,id)
		check(owned.get("ok",false) and int(owned.original_quantity)==100,"real quest491 selected HP stack has original100-unit proof")
		if not owned.get("ok",false):world.queue_free();quit(1);return
	var key: String=KEY if fresh else str(owned.inventory_key)
	var definition: Dictionary=D.definition_id("233")
	var spec: Dictionary=definition.native_record.heal_spec
	check(spec.kind=="source_hp_dice" and int(spec.HPRestoration)==20 and int(spec.HPRestorationDiceNumber)==2 and int(spec.HPRestorationDiceSpotCount)==6,"original exact20+2d6 checked instead of a name-derived flat heal")
	var details: Dictionary=preload("res://scripts/loot/quest_hp233_use.gd").metadata(D.variant_item(definition.native_record,1))
	check(details.get("ok",false) and details.get("auto_use_registrable",false) and int(details.get("source_consume_delay_ms",0))==1000,"all six original joins validate, including explicit AutoUseRegistrable=TrueFalse/1")
	# Fresh defaults contain automatic skill seeds that Main sanitizes on
	# reload. Use an explicit valid50-slot edit fixture, as the prior native
	# integration test does; this adds no item ownership. Old actual saves
	# are never edited here.
	if fresh:
		for index: int in range(50):world.quickslots[index]={"kind":"item","id":"HP 물약"} if index%3==0 else {}
		world.ui_preferences.edited_quickslots[world.job_class]=true
	var claims: Dictionary=world.quest_service.claimed.duplicate(true);var slots: Array=world.quickslots.duplicate(true)
	var path: String=world.save_path();var hash: String=FileAccess.get_sha256(path)
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	var quantity: int=int(inventory[key]);var hp: int=world.hp;var rng_before: int=world.rng.state
	world.hp=world._effective_max_hp();use(world,id)
	check(world.inventory==inventory and world.rng.state==rng_before and FileAccess.get_sha256(path)==hash,"full HP consumes no unit or RNG/save")
	world.hp=maxi(1,world._effective_max_hp()-200)
	world.item_use_cooldowns.erase(world.HP_POTION_COOLDOWN_KEY)
	check(world._save_game(true)==OK,"controlled missing200HP baseline saved without fabricating item ownership")
	hp=world.hp;hash=FileAccess.get_sha256(path)
	var locked: String=key if fresh else key+"@@@"+id
	world.ui_preferences.item_locks[locked]=true;use(world,id)
	check(world.hp==hp and world.inventory==inventory and FileAccess.get_sha256(path)==hash,"source potion lock preserves HP/ownership/save")
	world.ui_preferences.item_locks.erase(locked)
	var original_npc: Dictionary=world.patch523_npc_spells.player_buffs.duplicate(true)
	world.patch523_npc_spells.player_buffs[-233]={"values":{"CannotUseItem":1}}
	use(world,id)
	check(world.hp==hp and world.inventory==inventory and world.rng.state==rng_before and FileAccess.get_sha256(path)==hash,"existing NPC item-use restriction retained")
	# Controlled existing NPC modifier, not a claimed natural encounter.
	world.patch523_npc_spells.player_buffs[-233]={"values":{"HPPotionDecreasePercent":500000}}
	var shadow:=RandomNumberGenerator.new();shadow.seed=world.rng.seed;shadow.state=world.rng.state
	var expected_roll: int=20+shadow.randi_range(1,6)+shadow.randi_range(1,6)
	var expected_heal: int=int(world._source_hp_potion_parameters(expected_roll).heal_amount)/2
	check(expected_roll>=22 and expected_roll<=32,"controlled next native dice roll remains in original22..32 range")
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
	use(world,id)
	check(world.hp==hp and world.inventory==inventory and world.item_instances==instances and world.rng.state==rng_before and world.item_use_cooldowns.is_empty() and FileAccess.get_sha256(path)==hash,"failed real heal saves no HP,debit,cooldown,receipt or random advance")
	world.equipment_collections.test_save_writer=Callable()
	use(world,id)
	check(world.hp==hp+expected_heal and world.rng.state==shadow.state and int(world.inventory[key])==quantity-1,"actual source dice and existing50percent NPC reduction heal with one exact unit")
	check(float(world.item_use_cooldowns.get(world.HP_POTION_COOLDOWN_KEY,0))>0,"existing shared1s cooldown and growth modifier applied")
	if not fresh:
		check(int(world.item_instances[id].source_reward_quantity)==99 and world.item_instances[id].quest_reward_receipt==instances[id].quest_reward_receipt and not world.inventory.has(KEY),"partial100to99 retains physicalID/original receipt without canonical conversion")
	var durable: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(int(durable.hp)==world.hp and int(durable.inventory[key])==quantity-1 and durable.quest_state==norm(world.quest_service.export_state()) and durable.item_use_cooldowns==norm(world.item_use_cooldowns),"HP/exact stock/shared cooldown/receipt saved atomically")
	hash=FileAccess.get_sha256(path);rng_before=world.rng.state;hp=world.hp;use(world,id)
	check(world.hp==hp and int(world.inventory[key])==quantity-1 and world.rng.state==rng_before and FileAccess.get_sha256(path)==hash,"unelapsed shared cooldown blocks another heal/debit/roll")
	world.patch523_npc_spells.player_buffs=original_npc.duplicate(true)
	world._tick_item_buffs(2.0)
	check(not world.item_use_cooldowns.has(world.HP_POTION_COOLDOWN_KEY),"actual game cooldown tick expires shared delay")
	if fresh:
		world._on_quickslot_assignment_requested(49,"item",KEY)
		check(world.quickslots[49].get("id")==KEY,"exact source stock can be registered without replacing existing49 user slots")
		slots=world.quickslots.duplicate(true)
	world.equipment_collections.test_save_writer=func(target: String,data: Dictionary)->Error:
		var error: Error=WRITER.write(target,data)
		return ERR_FILE_CANT_WRITE if error==OK else error
	if fresh:world._on_quickslot_pressed(49)
	else:use(world,id)
	durable=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(int(durable.inventory[key])==quantity-2 and int(durable.hp)>hp,"write-then-error leaves exactly one committed second source heal")
	if fresh:check(world.quest_service.save_blocked,"native uncertain live view blocks transactions until confirmed reload")
	else:check(not world.quest_service.save_blocked and int(world.item_instances[id].source_reward_quantity)==98 and world.hp==int(durable.hp),"selected held consumer confirms complete saved heal and remainder98")
	world.equipment_collections.test_save_writer=Callable()
	hash=FileAccess.get_sha256(path)
	check(not world.quest_auto.complete(world,["m523:quest:491"]) and FileAccess.get_sha256(path)==hash,"healing never regrants its original quest")
	world.queue_free();await process_frame;world=make_world()
	check(norm(world.inventory)==durable.inventory and norm(world.item_instances)==durable.item_instances and world.hp==int(durable.hp) and norm(world.quest_service.export_state())==durable.quest_state,"fresh Main restores committed source HP and all quantity/receipt state")
	check(world.quest_service.claimed==claims and norm(world.quickslots)==norm(slots),"all source claims and50 user slots survive reconnect")
	check(not world.quest_service.save_blocked,"confirmed fresh load clears native uncertain protection")
	world.quest_auto.refresh_context(world)
	var completed: int=0;var pending: int=0
	for row: Dictionary in world.quest_service.entries(world.level,world.inventory):
		if row.get("source_id")!=null and row.completed:
			completed+=1
			if not row.rewards.get("pending_use",[]).is_empty():pending+=1
	print("QUEST_HP233_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"mode":"actual_fresh_native6940" if fresh else "actual_held100_partial","completed":completed,"pending_use_completed":pending,"source_hp_dice":{"base":20,"number":2,"sides":6},"controlled_roll":expected_roll,"controlled_half_heal":expected_heal,"final_save_sha256":FileAccess.get_sha256(path),"input_save_sha256":seed,"controlled_qa":["missing200HP","NPC restriction/reduction fixture","specific quickslot49 in fresh profile","injected writer failures"],"scope":"actual source ownership to original dice/HP/cooldown/atomic receipt/quantity/reconnect; no whole probability or natural encounter claim"}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
