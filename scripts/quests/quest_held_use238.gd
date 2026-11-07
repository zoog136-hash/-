extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Run the unchanged PR238 consumer against an isolated inventory view. Only a
## verified held-stack debit plus the consumer effect is committed to the host.
const CONSUMPTION=preload("res://scripts/quests/quest_reward_consumption.gd")
const OWN = preload("res://scripts/quests/quest_reward_ownership.gd")
const USE = preload("res://scripts/loot/patch523_item_use.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const HP233 = preload("res://scripts/loot/quest_hp233_use.gd")

class InventoryHud extends RefCounted:
	var host: Node
	func show_message(message: String) -> void:host.hud.show_message(message)
	func append_log(message: String) -> void:host.hud.append_log(message)
	func refresh_inventory(_candidate_inventory: Dictionary) -> void:host.hud.refresh_inventory(host.inventory)
	func is_card_reveal_busy() -> bool:return host.hud.has_method("is_card_reveal_busy") and host.hud.is_card_reveal_busy()

class View extends Node:
	const BASE508 = preload("res://scripts/lineagem_base508.gd")
	var host: Node
	var prepared: Dictionary
	var owned: Dictionary
	var canonical: Dictionary
	var inventory: Dictionary
	var item_instances: Dictionary
	var active_item_buffs: Dictionary
	var item_use_cooldowns: Dictionary
	var gold: int
	var hp: int
	var mp: int
	var initial_inventory: Dictionary
	var initial_instances: Dictionary
	var committed: bool=false
	var uncertain: bool=false
	var selection_entity_id: int=0
	var rng: RandomNumberGenerator=RandomNumberGenerator.new()
	var hud: RefCounted
	var effect_stamp: String
	func current_effect_stamp() -> String:
		return JSON.stringify([host.gold,host.hp,host.mp,host.job_class,host.level,host.active_item_buffs,host.item_use_cooldowns,str(host.rng.seed),str(host.rng.state),host.ui_preferences.get("patch523_reward_bag_draw_count",1),host.ui_preferences.get("patch523_source_reward_bags_enabled",true)],"",true,true).sha256_text()
	func _get(key: StringName) -> Variant: return host.get(key) if is_instance_valid(host) else null
	func is_player_concealed() -> bool:return host.is_player_concealed()
	func _option_awakening_busy() -> bool:return host._option_awakening_busy()
	func _format_seconds_short(value: float) -> String:return host._format_seconds_short(value)
	func _effective_max_hp() -> int:return host._effective_max_hp()
	func _effective_max_mp() -> int:return host._effective_max_mp()
	func _patch523_item_allowed() -> bool:return host._patch523_item_allowed()
	func _item_locked(key: String, id: String="") -> bool:return host._item_locked(key,id)
	func _source_hp_potion_parameters(amount: int) -> Dictionary:return host._source_hp_potion_parameters(amount)
	func _source_hp_potion_committed(amount: int) -> void:host._source_hp_potion_committed(amount)
	func _refresh_speed_modifiers() -> void:host._refresh_speed_modifiers()
	func _update_hud() -> void:host._update_hud()
	func _find_catalog_item_record(name_value: String) -> Dictionary:return host._find_catalog_item_record(name_value)
	func _catalog_item_from_source_id(id: String) -> Dictionary:return host._catalog_item_from_source_id(id)
	func _expected_bag() -> Dictionary:
		var spec: Dictionary=NATIVE_FIELDS.full(canonical).get("source_use_spec",{})
		if spec.get("kind") not in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag"]:return {}
		var candidate_rng:=RandomNumberGenerator.new()
		candidate_rng.seed=host.rng.seed;candidate_rng.state=host.rng.state
		var class_id: int=BASE508.source_class_id(host.job_class)
		# Use the existing source selector, full original pool and existing host
		# draw-count setting. This private candidate never advances live RNG.
		var chosen: Dictionary=USE.select_rewards(spec,class_id,candidate_rng,clampi(int(host.ui_preferences.get("patch523_reward_bag_draw_count",1)),1,10))
		if not chosen.get("ok",false):return {"ok":false}
		var expected: Dictionary=initial_inventory.duplicate(true)
		var input_key: String=str(canonical.name)
		var count: int=OWN.positive(expected.get(input_key))
		if count<1:return {"ok":false}
		if count==1:expected.erase(input_key)
		else:expected[input_key]=count-1
		var gold_after: int=host.gold
		var outputs: Dictionary={}
		for reward: Dictionary in chosen.rewards:
			if not USE.class_matches(reward.get("class_ids",[]),class_id):continue
			var definition: Dictionary=D.definition_id(str(int(reward.get("item_class_id",0))))
			var item: Dictionary=D.variant_item(definition.get("native_record",{}),int(reward.get("bless_raw",0)))
			if item.is_empty() or definition.get("original_item",{}).get("TestItem",true) or D.equipment(item) or not preload("res://scripts/quests/source_dummy523.gd").item_evidence(definition.get("original_item",{})).is_empty():return {"ok":false}
			var amount: int=OWN.positive(reward.get("amount"))
			if amount<1:return {"ok":false}
			var wallet: String=D.currency_identity_name(item)
			if wallet=="아데나":
				if gold_after<0 or gold_after>9007199254740991-amount:return {"ok":false}
				gold_after+=amount
			else:
				var key: String=wallet if not wallet.is_empty() else str(item.name)
				var previous: int=int(expected.get(key,0))
				if previous<0 or previous>9007199254740991-amount:return {"ok":false}
				expected[key]=previous+amount
				outputs[key]=int(outputs.get(key,0))+amount
		return {"ok":true,"inventory":expected,"gold":gold_after,"outputs":outputs,"rng_seed":str(candidate_rng.seed),"rng_state":str(candidate_rng.state)}
	func _save_game(_quiet: bool, overrides: Dictionary) -> Error:
		if committed or not OWN.current(host,prepared) or current_effect_stamp()!=effect_stamp:return ERR_INVALID_DATA
		for key: String in overrides:
			if key not in ["inventory","item_instances","gold","active_item_buffs","item_use_cooldowns","hp","mp"]:return ERR_INVALID_PARAMETER
		var proposed: Variant=overrides.get("inventory")
		if not proposed is Dictionary:return ERR_INVALID_DATA
		var virtual_key: String=str(canonical.name)
		var bag: Dictionary=_expected_bag()
		if not bag.is_empty() and (not bag.get("ok",false) or not CONSUMPTION.same(proposed,bag.inventory) or str(rng.seed)!=bag.rng_seed or str(rng.state)!=bag.rng_state):return ERR_INVALID_DATA
		var virtual_output: int=int(bag.get("outputs",{}).get(virtual_key,0))
		if int(proposed.get(virtual_key,0))!=int(owned.quantity)-1+virtual_output or proposed.get(owned.inventory_key)!=initial_inventory.get(owned.inventory_key):return ERR_INVALID_DATA
		var expected_gold: int=int(bag.get("gold",host.gold))
		if expected_gold<0 or not (overrides.get("gold",gold) is int) or int(overrides.get("gold",gold))!=expected_gold:return ERR_INVALID_DATA
		var proposed_instances: Variant=overrides.get("item_instances",initial_instances)
		if not proposed_instances is Dictionary:return ERR_INVALID_DATA
		var added: Dictionary={}
		if proposed_instances!=initial_instances:
			if int(canonical.get("source_item_class_id",0))!=369002 or selection_entity_id<=0:return ERR_INVALID_DATA
			var choices: Array=[]
			for row: Dictionary in NATIVE_FIELDS.full(canonical).get("source_use_spec",{}).get("rewards",[]):
				if int(row.source_entity_id)==selection_entity_id:choices.append(row)
			if choices.size()!=1:return ERR_INVALID_DATA
			var choice: Dictionary=choices[0]
			var definition: Dictionary=D.data().item_definitions.get(str(int(choice.item_class_id)),{}).get("native_record",{})
			var expected: Dictionary=D.variant_item(definition,int(choice.bless_raw))
			for id: String in initial_instances:
				if proposed_instances.get(id)!=initial_instances[id]:return ERR_INVALID_DATA
			for id: String in proposed_instances:
				if initial_instances.has(id):continue
				var item: Variant=proposed_instances[id]
				if not item is Dictionary or host.item_instances.has(id):return ERR_INVALID_DATA
				var proof: Dictionary=item.get("source_m_reward_proof",{})
				if proof.get("source_snapshot")!="patch523" or int(proof.get("item_class_id",0))!=369002 or int(proof.get("source_item_class_id",0))!=int(choice.item_class_id) or int(proof.get("entity_id",0))!=selection_entity_id or int(proof.get("bless",0))!=int(choice.bless_raw):return ERR_INVALID_DATA
				var enchant: int=0 if choice.get("enchant")==null else int(choice.enchant)
				if int(item.get("level",-1))!=enchant or int(proof.get("enchant",-1))!=enchant or not D.matches(item.get("record",{}),expected) or item.get("name")!=expected.get("name"):return ERR_INVALID_DATA
				added[id]=item.duplicate(true)
				added[id]["quest_source_input_receipt"]=host.item_instances[str(prepared.physical_id)].quest_reward_receipt.duplicate(true)
				added[id]["quest_source_input_physical_id"]=str(prepared.physical_id)
			if added.size()!=int(choice.amount):return ERR_INVALID_DATA
		var chosen: Dictionary=host.item_instances[str(prepared.physical_id)]
		var source_step: Dictionary=CONSUMPTION.stage(host,[{"physical_id":str(prepared.physical_id),"quantity":int(prepared.quantity),"expected_quantity":int(owned.quantity),"expected_remaining":int(owned.quantity)-int(prepared.quantity),"quest_reward_receipt":chosen.quest_reward_receipt.duplicate(true)}],str(D.pack_identity().get("sha256","")))
		if not source_step.get("ok",false):return ERR_INVALID_DATA
		var payload: Dictionary=source_step.overrides.duplicate(true)
		if overrides.has("gold"):payload["gold"]=expected_gold
		for id: String in added:payload.item_instances[id]=added[id]
		var keys: Dictionary={}
		for key: String in initial_inventory:keys[key]=true
		for key: String in proposed:keys[key]=true
		for key: String in keys:
			if key in [virtual_key,str(owned.inventory_key)]:continue
			var delta: int=int(proposed.get(key,0))-int(initial_inventory.get(key,0))
			if delta<0:return ERR_INVALID_DATA
			if delta>0:payload.inventory[key]=int(payload.inventory.get(key,0))+delta
		if virtual_output>0:
			var previous: int=int(payload.inventory.get(virtual_key,0))
			if previous<0 or previous>9007199254740991-virtual_output:return ERR_INVALID_DATA
			payload.inventory[virtual_key]=previous+virtual_output
		for key: String in ["active_item_buffs","item_use_cooldowns"]:
			if overrides.has(key):payload[key]=overrides[key].duplicate(true)
		if payload.has("active_item_buffs"):
			payload["hp"]=mini(host.hp,host._effective_max_hp(-1,payload.active_item_buffs))
			payload["mp"]=mini(host.mp,host._effective_max_mp(payload.active_item_buffs))
		if overrides.has("mp"):
			if NATIVE_FIELDS.full(canonical).get("source_use_spec",{}).get("kind")!="source_mp_dice" or not overrides.mp is int or overrides.mp<host.mp or overrides.mp>host._effective_max_mp(payload.get("active_item_buffs")):return ERR_INVALID_DATA
			payload["mp"]=overrides.mp
		if overrides.has("hp"):
			if int(canonical.get("source_item_class_id",0))!=233 or not overrides.hp is int or overrides.hp<host.hp or overrides.hp>host._effective_max_hp():return ERR_INVALID_DATA
			payload["hp"]=overrides.hp
		# Persist the proven binding/use without converting or regranting the
		# held inventory. Original grant quantity and receipt remain immutable.
		if not CONSUMPTION.matches_payload(host,source_step,payload):return ERR_INVALID_DATA
		payload["patch523_transaction_rng"]={"schema":1,"seed":str(rng.seed),"state":str(rng.state)}
		var state: Dictionary=payload.quest_state
		var path: String=host.save_path()
		var prior: String=FileAccess.get_sha256(path)
		var error: Error=host.quest_item_provider.commit_held_save(host,payload)
		if error!=OK:
			if host.get("patch523_owner_state_problem") is String and not host.patch523_owner_state_problem.is_empty():host.quest_service.save_blocked=true;uncertain=true;return error
			var parser:=JSON.new();var parse_error: Error=parser.parse(FileAccess.get_file_as_string(path))
			var durable: Variant=parser.data if parse_error==OK else null
			var expected: Dictionary=JSON.parse_string(JSON.stringify(payload,"",true,true))
			var confirmed: bool=durable is Dictionary
			if confirmed:
				for key: String in expected:
					if durable.get(key)!=expected[key]:confirmed=false;break
			if not confirmed:
				if FileAccess.get_sha256(path)!=prior:host.quest_service.save_blocked=true;uncertain=true
				return error
			if not host.equipment_collections.accept_load(durable):host.quest_service.save_blocked=true;uncertain=true;return error
		host.inventory=payload.inventory;host.item_instances=payload.item_instances
		if payload.has("gold"):host.gold=int(payload.gold)
		if payload.has("active_item_buffs"):host.active_item_buffs=payload.active_item_buffs
		if payload.has("item_use_cooldowns"):host.item_use_cooldowns=payload.item_use_cooldowns
		if payload.has("hp"):host.hp=int(payload.hp)
		if payload.has("mp"):host.mp=int(payload.mp)
		host.rng.seed=rng.seed;host.rng.state=rng.state
		host.quest_service.import_state(state)
		host.deferred_save.cancel()
		committed=true
		return OK

static func make_view(world: Node, prepared: Dictionary, canonical: Dictionary) -> Node:
	var view:=View.new()
	view.host=world;view.prepared=prepared;view.owned=prepared.ownership;view.canonical=USE.action_record(world,canonical)
	view.hud=InventoryHud.new();view.hud.host=world
	view.inventory=world.inventory.duplicate(true);view.item_instances=world.item_instances.duplicate(true)
	view.inventory[str(canonical.name)]=int(view.owned.quantity)
	view.initial_inventory=view.inventory.duplicate(true);view.initial_instances=view.item_instances.duplicate(true)
	view.active_item_buffs=world.active_item_buffs.duplicate(true);view.item_use_cooldowns=world.item_use_cooldowns.duplicate(true)
	view.gold=world.gold;view.hp=world.hp;view.mp=world.mp
	view.rng.seed=world.rng.seed;view.rng.state=world.rng.state
	view.effect_stamp=view.current_effect_stamp()
	return view

static func perform(world: Node, prepared: Dictionary, canonical: Dictionary) -> Dictionary:
	if not OWN.current(world,prepared):return {"handled":true,"committed":false,"uncertain":false}
	var view: Node=make_view(world,prepared,canonical)
	var handled: bool=HP233.use(view,canonical) if int(canonical.get("source_item_class_id",0))==233 else USE.try_use(view,canonical)
	var result: Dictionary={"handled":handled,"committed":view.committed,"uncertain":view.uncertain}
	view.free()
	return result
