extends RefCounted
## Stage rewards and completion together, then acknowledge only durable writes.
var retry_at: float = 0.0
var busy: bool = false
var failures: Dictionary = {}
var context: Dictionary = {}
var last_signature: String = ""
var next_scan: float = 0.0
var held_index: Dictionary = {}
var indexed_instances: Dictionary = {}
var indexed_size: int = -1
const ITEM_BINDINGS = preload("res://scripts/quests/quest_item_bindings.gd")
const FAILED_SCAN_SECONDS: float = 5.0

func held_record(name_value: String, instances: Dictionary) -> Dictionary:
	# These names deliberately have no legacy catalog row. Index the physical
	# source records once per transaction instead of scanning 2,000+ unrelated
	# catalog rows for every held stack on every HUD/save synchronization.
	if not is_same(indexed_instances,instances) or indexed_size!=instances.size():
		held_index.clear()
		indexed_instances = instances
		indexed_size = instances.size()
		for id: String in instances:
			var physical: Dictionary = instances[id]
			var name: String = str(physical.get("name",""))
			if name.begins_with("[원본 보상] ") and not held_index.has(name): held_index[name]=id
	var id: String = str(held_index.get(name_value,""))
	var candidate: Dictionary = instances.get(id,{})
	if candidate.get("name")!=name_value: indexed_size=-1;return {}
	var record: Dictionary = candidate.get("record",{})
	return record.duplicate(true) if bool(record.get("source_pending_use",false)) else {}

func refresh_context(world: Node) -> void:
	var service: Variant = world.quest_service
	# Packed lookup with index()'s candidates (no per-item Dictionary/Array).
	var source_items: RefCounted = ITEM_BINDINGS.lookup([world.item_db,world.catalog_db.get("아이템",[])])
	# Bind the existing production consumer directly: no speculative foreign
	# provider and no Callable(self) cycle retaining this runner after restart.
	context = {"level":world.level,"max_level":world.level,"class_id":service.source.class_ids.get(str(world.job_class),-1),"source_items":source_items,"source_item_consumer":Callable(world.growth.source523,"material"),"currency_items":world.loot_catalog.get("by_name",{})}
	context["quest_item_provider"]=Callable(world.quest_item_provider,"resolve")
	context["held_native_rewards"]=world.quest_item_provider.supported_held(world)
	service.source_context = context

func tick(world: Node) -> void:
	if busy or world.quest_service.source.quests.is_empty(): return
	var now: float = Time.get_unix_time_from_system()
	var signature: String = "%s:%s" % [str(world.level),str(world.job_class)]
	if now < retry_at or (signature == last_signature and now < next_scan): return
	last_signature = signature
	next_scan = now+1.0
	refresh_context(world)
	# No acquisition runs until character creation/load guards permit saving.
	if world.source_save_blocked or world.equipment_collections.save_blocked or not world.pending_map_save_record.is_empty(): return
	var ids: Array[String] = []
	var offered: Dictionary = world.quest_service.claimed.duplicate()
	for quest: Dictionary in world.quest_service.source.quests:
		var id: String = str(quest.id)
		if world.quest_service.claimed.has(id): continue
		var gate: String = world.quest_service.source.gate(quest,context,offered,int(now))
		if not gate.is_empty(): continue
		var plan: Dictionary = world.quest_service.source.reward_plan(quest,context)
		if not plan.ok:
			failures[id] = str(plan.error)
			continue
		ids.append(id)
		offered[id] = true
		# Parents and their newly acquired children can share one atomic write.
		# Staging rechecks each prerequisite in the same ordered transaction.
		if ids.size() == 32: break
	if ids.is_empty(): return
	# Continue prerequisite chains on the next frame only after a completed
	# write. A completion that stages nothing or is refused (save pending,
	# reward check, already claimed) used to rescan all quests and copy the
	# whole bag on every frame; it now waits like an ordinary scan.
	if complete(world,ids):
		if retry_at <= now: next_scan = 0.0
	else: next_scan = maxf(next_scan, now + FAILED_SCAN_SECONDS)

func complete(world: Node, ids: Array[String]) -> bool:
	if busy or world.quest_service.save_blocked: return false
	refresh_context(world)
	var service: Variant = world.quest_service
	var staged_state: Dictionary = service.export_state().duplicate(true)
	var staged_inventory: Dictionary = world.inventory.duplicate(true)
	var staged_instances: Dictionary = world.item_instances.duplicate(true)
	var next_id: int = world.next_item_instance_id
	var adena: int = 0
	var experience: int = 0
	var completed: Array[String] = []
	var native_grants: Array = []
	var native_receipts: Array = []
	for id: String in ids:
		var quest: Dictionary = service.index.get(id,{})
		if quest.is_empty() or staged_state.claimed.has(id) or not service.source.gate(quest,context,staged_state.claimed,int(Time.get_unix_time_from_system())).is_empty(): continue
		var plan: Dictionary = service.source.reward_plan(quest,context)
		if not plan.ok:
			failures[id] = str(plan.error)
			continue
		for item: Dictionary in plan.items:
			var record: Dictionary = item.record
			var name_value: String = str(record.name)
			var amount: int = int(item.quantity)
			if item.get("native_supplier",false):
				if not staged_state.has("item_grants"): staged_state["item_grants"]={}
				if not staged_state.item_grants.has(id): staged_state.item_grants[id]=[]
				var receipt: Dictionary = {"schema":1,"reward_id":int(item.source_reward_id),"item_class_id":int(record.source_item_class_id),"quantity":amount,"bless_raw":int(item.source_bless_code_id),"inventory_key":name_value,"pack_sha256":str(item.pack_sha256)}
				staged_state.item_grants[id].append(receipt)
				var supplier_receipt: Dictionary = receipt.duplicate(true);supplier_receipt["quest_id"]=id
				native_receipts.append(supplier_receipt)
				native_grants.append({"item_class_id":int(record.source_item_class_id),"amount":amount,"bless_raw":int(item.source_bless_code_id),"enchant":0})
				continue
			# Every native item is pinned to its exact record and physical ID,
			# including non-equipment materials that have source-specific use.
			if amount < 1 or (amount > 10000 and not bool(item.get("stack_only",false))):
				failures[id] = "보상 아이템 수량 확인 필요"
				return false
			staged_inventory[name_value] = int(staged_inventory.get(name_value,0))+amount
			if bool(item.get("stack_only",false)): continue
			# Held native items keep one physical provenance record per reward
			# stack. Ten thousand tokens must not create ten thousand equipment
			# instances or expand every subsequent save by tens of megabytes.
			var held: bool = bool(record.get("source_pending_use",false))
			for count: int in range(1 if held else amount):
				while staged_instances.has(str(next_id)): next_id += 1
				staged_instances[str(next_id)] = {"name":name_value,"level":0,"record":record.duplicate(true)}
				staged_instances[str(next_id)]["quest_reward_receipt"] = {"schema":1,"quest_id":id,"reward_id":int(item.source_reward_id),"item_class_id":int(record.source_item_class_id),"bless_code_id":int(item.get("source_bless_code_id",1)),"source_sha256":service.source.SOURCE_SHA,"quantity":amount if held else 1}
				if held: staged_instances[str(next_id)]["source_reward_quantity"] = amount
				next_id += 1
		adena += int(plan.adena)
		experience += int(plan.exp)
		staged_state.claimed[id] = true
		if not plan.get("source_dummy_rewards",[]).is_empty():
			if not staged_state.has("source_dummy_rewards"):staged_state["source_dummy_rewards"]={}
			staged_state.source_dummy_rewards[id]=plan.source_dummy_rewards.duplicate(true)
		for unlocked: int in plan.quests: staged_state.unlocked["m523:quest:"+str(unlocked)] = true
		if not plan.ui_requests.is_empty(): staged_state.ui_requests[id]=plan.ui_requests.duplicate(true)
		completed.append(id)
	if completed.is_empty(): return false
	var staged: Dictionary = {"quest_state":staged_state,"inventory":staged_inventory,"item_instances":staged_instances,"next_item_instance_id":next_id,"gold":world.gold+adena,"experience":world.experience+experience}
	if not native_grants.is_empty():
		# The shared supplier returns COMPLETE candidate values. Its base must
		# already include this batch's held rewards and gold; never overwrite
		# prior reward/debit candidates by staging against the live world.
		var supplied: Dictionary = world.quest_item_provider.stage(world,staged,native_grants,native_receipts)
		if not supplied.get("ok",false):
			for id: String in completed: failures[id]=str(supplied.get("error","원본 공급 준비 실패"))
			return false
		staged_inventory=supplied.overrides.inventory;staged_instances=supplied.overrides.item_instances
		staged.merge(supplied.overrides,true)
	# Run the existing level curve without UI effects, snapshot the result, and
	# restore live fields before writing. EXP overflow can never be lost through
	# load-time migration if the app stops immediately after the atomic save.
	var growth_keys: Array[String] = ["level","experience","exp_need","max_hp","max_mp","hp","mp","attack_power","defense","stat_points"]
	var before_growth: Dictionary = {}
	for key: String in growth_keys: before_growth[key] = world.get(key)
	world.experience = staged.experience
	world._check_level_up(true)
	for key: String in growth_keys:
		staged["attack" if key=="attack_power" else key] = world.get(key)
		world.set(key,before_growth[key])
	busy = true
	var path: String = world.save_path()
	var before_hash: String = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	var error: Error = world._save_game(true,staged)
	if error != OK:
		# A post-write error must never cause a second grant. Inspect the target
		# before deciding whether the staged transaction actually committed.
		var durable: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		var committed: bool = durable is Dictionary
		if committed:
			# JSON's numeric representation differs from typed live dictionaries.
			# Compare the complete serialized transaction, as a restart reads it.
			var serialized: Dictionary = JSON.parse_string(JSON.stringify(staged))
			for key: String in staged:
				if durable.get(key) != serialized[key]: committed=false;break
		if not committed:
			if FileAccess.file_exists(path) and FileAccess.get_sha256(path)!=before_hash:
				service.save_blocked = true
				world.hud.show_message("저장 결과 확인 필요 · 다시 불러오기 전 자동 보상 중지")
			for id: String in completed: failures[id] = "저장 실패 · 보상/완료 미적용 · 자동 재시도 대기"
			retry_at = Time.get_unix_time_from_system()+30.0
			busy = false
			return false
		# Adopt the verified disk identity through the existing load validator,
		# so its stale-write guard does not reject our confirmed committed write.
		if not world.equipment_collections.accept_load(durable):
			service.save_blocked = true
			busy = false
			return false
	world.gold = staged.gold
	world.experience = staged.experience
	world.inventory = staged_inventory
	world.item_instances = staged_instances
	world.next_item_instance_id = next_id
	for key: String in growth_keys: world.set(key,staged["attack" if key=="attack_power" else key])
	service.import_state(staged_state)
	for id: String in completed: failures.erase(id)
	world.deferred_save.cancel()
	if world.level != int(before_growth.level): world._update_hud()
	else:
		world._refresh_inventory_hud()
		world._refresh_combat_hud()
	if world.hud.has_method("refresh_quests"): world.hud.refresh_quests()
	world.hud.append_log("원본 퀘스트 자동 완료 %d개 · 아데나 +%d · EXP +%d" % [completed.size(),adena,experience])
	busy = false
	return true
