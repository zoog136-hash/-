extends SceneTree
## 퀘스트 보상 카드 사용 (user report 2026-11-26 "퀘스트 보상 카드들은 사용이
## 안 돼"). A quest reward without a reviewed quest owner is issued as a held
## physical ("[원본 보상] …", quest_reward_receipt). The same item from a box,
## drop or the test grant is a native receipted stack and works. Held rewards:
## - card boxes (LuckyBag 78: 변신·인형·성물 카드 확정 상자, 스킬 카드 뽑기팩
##   상자, 희귀 카드 상자) were taken by the events window: its bag check read
##   the catalog record of the held name, the stub without a use rule;
## - fixed cards (변신 카드 아크 나이트 …) had no held owner ("원본 보상 보관
##   중 · 사용 기능 연결 대기"), and the approved TWILIGHT 근사 arc cards
##   (APPROX_TEST_ITEMS) failed the pinned quest row's TestItem flag;
## - quest skill books (각인, BuffCardDrawer) failed their own ledger check
##   (the candidate was changed before matches_payload compared it).
## Without the pinned 523 tables only the rules run. With them (--runtime) each
## representative reward is issued by the actual quest completion (or as an old
## save holds it) and used from the bag in Main, next to the test grant.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const OWN = preload("res://scripts/quests/quest_reward_ownership.gd")
const CONSUME = preload("res://scripts/quests/quest_reward_consumption.gd")
const PROVIDER = preload("res://scripts/quests/quest_item_provider238.gd")
const FIXED = preload("res://scripts/quests/quest_fixed_cards523.gd")
const IDENTITY = preload("res://scripts/cards/current523_card_identity.gd")
const TUTORIAL = preload("res://scripts/content523/tutorial523.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
## 아크 나이트(근사 허용 시험 행 카드), 변신·인형·성물 카드 확정 상자, 희귀 변신
## 카드 상자, 스킬 카드 뽑기팩 상자, 마검사 각인 스킬서, 공허의 사원 희귀 카드
## 상자(연계 콘텐츠 퀘스트: 옛 세이브 보유분).
const REPRESENTATIVE = [1016, 996, 35101, 1067, 123393, 146692, 297858, 155643, 324693, 291202, 328908]
const REPORTED_CARD_IDS = {1016:84, 996:59, 35101:85}
const REPORTED_CARD_QUESTS = {1016:"m523:quest:60291", 996:"m523:quest:59982", 35101:"m523:quest:60441"}
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var w: Node
var base_quest: Dictionary
var base_cards: Dictionary
var base_skills: Dictionary
var base_job: String

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label); printerr("QUEST_REWARD_CARDS_FAIL ", label)

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	check(SOURCE.approximated_item({"ID":1067,"TestItem":true}).get("TestItem") == false, "an approved TWILIGHT 근사 test card reads as an ordinary item")
	check(REPORTED_CARD_IDS.keys().all(func(id: int) -> bool:
		return SOURCE.approximated_item({"ID":id,"TestItem":true}).TestItem), "authorization for a held quest reward does not change general item rules")
	check(SOURCE.approximated_item({"ID":5,"TestItem":true}).get("TestItem") == true, "other test items stay test items")
	var pinned: Dictionary = {"ID":1067,"TestItem":true}
	SOURCE.approximated_item(pinned)
	check(pinned.TestItem == true, "the pinned quest row itself is not changed")
	var stack: String = FileAccess.get_file_as_string("res://scripts/loot/current523_native_stack.gd")
	check(stack.contains('if spec.kind=="fixed_card":return use_fixed_card(world,uid,selected_owned,record,spec,held_test_card)'), "a quest-held fixed card uses the native card owner")
	check(stack.contains('var paid: Dictionary=QUEST_CONSUME.stage(world,[request],str(SOURCE.identity().source_sha256),held_test_card) if is_quest else stage_debit(world,[request])') and stack.contains('if is_quest and not QUEST_CONSUME.matches_payload(world,paid,payload,held_test_card):return _failure("퀘스트 카드'), "a quest card is debited through the quest ledger")
	check(stack.contains('var payload: Dictionary=paid.overrides.duplicate(true);payload["consumable_state"]=state;payload["original_skill_state"]=learned'), "the quest skill book candidate is compared unchanged")
	check(stack.contains('SOURCE.approximated_item(original_item)!=SOURCE.row("ItemClass"'), "the held bag/card row check reads the approved approximation")
	var provider: String = FileAccess.get_file_as_string("res://scripts/quests/quest_item_provider238.gd")
	var routing = PROVIDER.new()
	var fixed_card: Dictionary = {"native_record":{"source_use_spec":{"kind":"fixed_card"}}}
	check(routing._native_held_spec_supported(fixed_card,1067), "an ordinary held fixed card uses the native route")
	check(139781 in FIXED.QUEST_IDS and FIXED.QUEST_IDS.all(func(id: int) -> bool:
		return not routing._native_held_spec_supported(fixed_card,id)), "all reviewed quest cards stay with their dedicated owner")
	check(provider.contains('_native_held_spec_supported(original_definition,int(original_owned.item_class_id))') and provider.contains('stock.call("use_owned_original",world,original_owned.source_item') and provider.contains('if int(owned.item_class_id) in FIXED.QUEST_IDS:'), "the held-use path dispatches to both owners with the tested routing decision")
	var events: String = FileAccess.get_file_as_string("res://scripts/unconfirmed523/runtime.gd")
	check(events.contains("func _box_rule_record(item_name: String, id: int) -> Dictionary:") and events.contains('profile(rule).get("kind","")) in ["bag","selection"]: return false') and events.contains('NATIVE_FIELDS.full(rule).get("source_use_spec",{})'), "the events window reads a held box's own native rule")
	var own: String = FileAccess.get_file_as_string("res://scripts/quests/quest_reward_ownership.gd")
	check(own.contains('approximated_item(owned.source_item).get("TestItem",false)'), "the held debit applies the approved approximation")

func reset() -> void:
	w.inventory = {}; w.item_instances = {}; w.item_use_cooldowns = {}
	w.quest_service.import_state(base_quest.duplicate(true))
	w.card_draw_fusion.import_state(base_cards.duplicate(true))
	w.original_skills.catalog.import_state(base_skills.duplicate(true))
	w.quest_service.save_blocked = false; w.patch523_owner_state_problem = ""
	w.job_class = base_job
	w.hud.message_label.text = ""
	w._save_game(true)

func close_ui() -> void:
	if is_instance_valid(w.hud.get("card_reveal_stage")) and w.hud.card_reveal_stage.has_method("close_reveal"): w.hud.card_reveal_stage.call("close_reveal")
	w.hud._close_workspace()

func physical_of(id: int) -> String:
	for uid: Variant in w.item_instances:
		var entry: Variant = w.item_instances[uid]
		if entry is Dictionary and (int(entry.get("record",{}).get("source_item_class_id",0)) == id): return str(uid)
	return ""

func activate(id: int) -> Dictionary:
	var uid: String = physical_of(id)
	if uid.is_empty(): return {"ok":false,"why":"no physical"}
	var name: String = str(w.item_instances[uid].name)
	var held: bool = w.item_instances[uid].has("quest_reward_receipt")
	var cards_before: String = JSON.stringify(w.card_draw_fusion.export_state())
	var skills_before: String = JSON.stringify(w.original_skills.catalog.export_state())
	var before: Dictionary = w.inventory.duplicate(true)
	w.hud.message_label.text = ""
	var reference: String = name + "@@@" + uid
	w.hud.refresh_inventory(w.inventory)
	w.hud.toggle_inventory()
	if w.hud.original_inventory_is_open():
		var selected: Dictionary = w.hud.original_inventory_select(reference)
		if not selected.get("ok",false):
			close_ui()
			return {"ok":false,"held":held,"why":selected}
		w.hud.original_inventory_activate_selected(reference)
	else:
		w.hud.lineage_inventory_ui._select_item(reference)
		w.hud.lineage_inventory_ui._activate_selected()
	var gained: Array = []
	for key: Variant in w.inventory:
		if int(w.inventory[key]) > int(before.get(key, 0)): gained.append(str(key))
	var out: Dictionary = {"held":held,"message":str(w.hud.message_label.text),"consumed":int(before.get(name,0)) - int(w.inventory.get(name,0)),
		"card":JSON.stringify(w.card_draw_fusion.export_state()) != cards_before,"skill":JSON.stringify(w.original_skills.catalog.export_state()) != skills_before,"gained":gained,"problem":str(w.patch523_owner_state_problem)}
	out["ok"] = out.consumed == 1 and (out.card or out.skill or not gained.is_empty()) and out.problem.is_empty() and not w.quest_service.save_blocked
	close_ui()
	return out

func quest_grant(id: int, quests: Array, job: String="", held_history: bool=false) -> Dictionary:
	var svc = w.quest_service
	var classes: Array = [base_job]
	for c: Variant in svc.source.class_ids:
		if str(c) not in classes: classes.append(str(c))
	if not job.is_empty():classes=[job]
	var now: int = int(Time.get_unix_time_from_system())
	for qid: String in ([] if held_history else quests):
		var quest: Dictionary = svc.full(svc.index[qid])
		for c: String in classes:
			reset(); w.job_class = c
			for req: Dictionary in quest.get("prerequisites",[]):
				if req.get("type_name") == "Quest": svc.claimed["m523:quest:" + str(int(req.Value))] = true
			w.quest_auto.refresh_context(w)
			if not svc.source.gate(svc.index[qid], w.quest_auto.context, svc.claimed, now).is_empty(): continue
			var plan: Dictionary = svc.source.reward_plan(quest, w.quest_auto.context)
			var has: bool = false
			for item: Dictionary in plan.get("items",[]): has = has or int(item.record.get("source_item_class_id",0)) == id
			if not has: continue
			var ids: Array[String] = [qid]
			if w.quest_auto.complete(w, ids): return {"ok":true,"quest":qid,"class":c,"path":"quest_completion"}
	# A quest that can no longer be completed here (연계 콘텐츠): the held
	# reward exactly as complete() wrote it into an old save.
	for qid: String in quests:
		var quest: Dictionary = svc.full(svc.index[qid])
		for c: String in classes:
			reset(); w.job_class = c; w.quest_auto.refresh_context(w)
			var plan: Dictionary = svc.source.reward_plan(quest, w.quest_auto.context)
			for item: Dictionary in plan.get("items",[]):
				if int(item.record.get("source_item_class_id",0)) != id or not item.record.get("source_pending_use",false): continue
				var uid: String = str(w.next_item_instance_id); w.next_item_instance_id += 1
				var name: String = str(item.record.name)
				w.item_instances[uid] = {"name":name,"level":0,"record":item.record.duplicate(true),"source_reward_quantity":int(item.quantity),"quest_reward_receipt":{"schema":1,"quest_id":qid,"reward_id":int(item.source_reward_id),"item_class_id":id,"bless_code_id":int(item.get("source_bless_code_id",1)),"source_sha256":svc.source.SOURCE_SHA,"quantity":int(item.quantity)}}
				w.inventory[name] = int(w.inventory.get(name,0)) + int(item.quantity)
				svc.claimed[qid] = true
				if w._save_game(true) == OK:
					w._load_game(true)
					if OWN.proof(w,uid).get("ok",false):return {"ok":true,"quest":qid,"class":str(w.job_class),"path":"old_save"}
	return {"ok":false}

func transformation_rewards() -> Array[Dictionary]:
	var svc = w.quest_service
	var matches: Array[Dictionary] = []
	var targets: Dictionary = {}
	for qid: String in svc.index:
		for reward: Dictionary in svc.full(svc.index[qid]).get("source_rewards",[]):
			var item: Dictionary = reward.get("source_item",{})
			if reward.get("type_name")!="Item" or item.get("CategoryID")!=83:continue
			var id: int = int(item.ID)
			if not targets.has(id):
				var ids: Array[int] = []
				for link: Dictionary in SOURCE.related("ItemBonus","ItemClassID",id):
					var bonus: Dictionary = SOURCE.row("Bonus",int(link.BonusID))
					if bonus.get("BonusTypeID")==139: ids.append(int(bonus.Value))
				targets[id] = ids[0] if ids.size()==1 and SOURCE.row("BuffCard",ids[0]).get("BuffCardDeckID")==1 else 0
			if targets[id]>0: matches.append({"quest_id":qid,"reward":reward,"card_id":targets[id]})
	return matches

func card_count(card_id: int) -> int:
	return w.card_draw_fusion.total_count("변신","source:"+IDENTITY.source_id(1,card_id))

func stage_compact_reward(entry: Dictionary) -> String:
	var reward: Dictionary = entry.reward
	var key: String = "[원본 보상] "+str(reward.source_item.Name)
	var uid: String = str(w.next_item_instance_id)
	w.next_item_instance_id += 1
	w.quest_service.claimed[entry.quest_id] = true
	w.inventory[key] = int(w.inventory.get(key,0))+int(reward.Amount)
	w.item_instances[uid] = {"name":key,"level":0,"source_reward_quantity":reward.Amount,
		"record":{"name":key,"grade":"미확인","slot":"quest_reward","type":"원본 보상 보관","source_pending_use":true},
		"quest_reward_receipt":{"schema":1,"quest_id":entry.quest_id,"reward_id":reward.ID,"item_class_id":reward.RewardClassID,
		"bless_code_id":reward.ItemBlessCodeID,"quantity":reward.Amount,"source_sha256":SOURCE.SOURCE_SHA}}
	return uid

func immediate_transformation_claims(graph: Array[Dictionary]) -> void:
	var by_class: Dictionary = {}
	for job: String in w.quest_service.source.class_ids:
		by_class[int(w.quest_service.source.class_ids[job])] = job
	var checked: int = 0
	var retired: int = 0
	for entry: Dictionary in graph:
		var reward: Dictionary = entry.reward
		if not reward.UseImmediately:continue
		var qid: String = entry.quest_id
		var label: String = qid+"/"+str(int(reward.ID))
		reset()
		w.job_class = by_class[int(reward.CharacterClassID)]
		var quest: Dictionary = w.quest_service.full(w.quest_service.index[qid])
		for requirement: Dictionary in quest.prerequisites:
			if requirement.get("type_name")=="Quest":w.quest_service.claimed["m523:quest:"+str(int(requirement.Value))]=true
		w.quest_auto.refresh_context(w)
		var before: int = card_count(entry.card_id)
		var path: String = w.save_path()
		var hash_before: String = FileAccess.get_sha256(path)
		if TUTORIAL.quest(TUTORIAL.quest_row_id(quest)):
			w._claim_quest(qid)
			check(not w.quest_service.claimed.has(qid) and card_count(entry.card_id)==before and FileAccess.get_sha256(path)==hash_before,"retired tutorial stays retired "+label)
			retired += 1
			continue
		w.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_FILE_CANT_WRITE
		w._claim_quest(qid)
		w.equipment_collections.test_save_writer = Callable()
		check(not w.quest_service.claimed.has(qid) and card_count(entry.card_id)==before and FileAccess.get_sha256(path)==hash_before,"failed write keeps quest and card unclaimed "+label)
		w.quest_auto.retry_at = 0.0
		w._claim_quest(qid)
		var receipts: Array = w.card_draw_fusion.source_card_receipts
		var committed: bool = w.quest_service.claimed.get(qid,false) and card_count(entry.card_id)==before+1 and physical_of(int(reward.RewardClassID)).is_empty()
		check(committed,"claim immediately registers exact original card without a bag item "+label+" "+str(w.quest_auto.failures.get(qid,"")))
		if not committed:continue
		check(receipts.back().get("input_receipt",{}).get("reward_id")==reward.ID,"card stores the exact quest reward receipt "+label)
		w._load_game(true)
		var written: String = FileAccess.get_sha256(path)
		w._claim_quest(qid)
		check(w.quest_service.claimed.get(qid,false) and card_count(entry.card_id)==before+1 and FileAccess.get_sha256(path)==written,"reload and repeated claim preserve one registration "+label)
		checked += 1
	evidence["immediate_claims"] = checked
	evidence["retired_immediate_claims"] = retired
	check(checked==6 and retired==1,"every immediate original transformation link was exercised")

func all_held_transformations(graph: Array[Dictionary]) -> void:
	var cohorts: Dictionary = {}
	var items: Dictionary = {}
	var original_icons: Dictionary = {}
	for entry: Dictionary in graph:
		var class_id: int = int(entry.reward.CharacterClassID)
		if not cohorts.has(class_id):cohorts[class_id]=[]
		cohorts[class_id].append(entry)
	var spent: int = 0
	for class_id: int in cohorts:
		reset()
		var uid_map: Dictionary = {}
		for entry: Dictionary in cohorts[class_id]:uid_map[stage_compact_reward(entry)] = entry
		check(w._save_game(true)==OK,"serialize prior-claim inventory class #"+str(class_id))
		w._load_game(true)
		var bag: Control = w.hud.lineage_inventory_ui
		var visible_refs: Dictionary = {}
		for row: Dictionary in bag._inventory_entries(): visible_refs[row.reference] = true
		for uid: String in uid_map:
			var entry: Dictionary = uid_map[uid]
			var label: String = entry.quest_id+"/"+str(int(entry.reward.ID))
			var owned: Dictionary = OWN.proof(w,uid)
			check(owned.get("ok",false),"reloaded compact reward retains exact ownership "+label+" "+str(owned.get("reason","")))
			if not owned.get("ok",false):continue
			var reference: String = str(owned.inventory_key)+"@@@"+uid
			check(visible_refs.has(reference) and bag.item_action_kind(reference)=="사용","bag publishes the exact usable row "+label)
			if not original_icons.has(owned.item_class_id):
				var presentation: Dictionary = bag._item_visual_record(reference,owned.record)
				var icon: Dictionary = IMAGES.describe_item(presentation,str(owned.inventory_key))
				var linked: bool = icon.get("status")=="original_linked" and icon.get("item_class_id")==owned.item_class_id and icon.get("original_bytes_unchanged",false)
				check(linked,"original icon is linked for the exact prior card #"+str(owned.item_class_id))
				original_icons[owned.item_class_id] = linked
			var before: int = card_count(entry.card_id)
			w._activate_inventory_input(reference)
			var used: bool = not w.item_instances.has(uid) and card_count(entry.card_id)==before+1
			check(used,"bag activates the exact registered card and debits one physical reward "+label+" "+str(w.hud.message_label.text))
			close_ui()
			if not used:continue
			items[int(entry.reward.RewardClassID)] = true
			spent += 1
		w._load_game(true)
		check(uid_map.keys().all(func(uid: String) -> bool:return not w.item_instances.has(uid)),"all consumed quantities stay spent after reload for class #"+str(class_id))
	check(items.size()==64 and spent==146,"all original direct transformation cards and quest links were used")
	evidence["held_transformations"] = {"item_classes":items.size(),"quest_rewards":spent,"original_icons":original_icons.values().count(true)}

func inventory_granted_transformations(graph: Array[Dictionary]) -> void:
	var checked: Dictionary = {}
	for entry: Dictionary in graph:
		var item_id: int = int(entry.reward.RewardClassID)
		if checked.has(item_id) or SOURCE.row("ItemClass",item_id).get("TestItem",true):continue
		var source_id: String = "m523:item:"+str(item_id)
		reset()
		w._grant_playtest_catalog_variant(source_id,1)
		w._load_game(true)
		var used: Dictionary = activate(item_id)
		check(used.get("ok",false) and not used.get("held",true) and card_count(entry.card_id)==1,"catalog-granted card works from the bag after reload "+source_id+" "+JSON.stringify(used))
		checked[item_id] = used.get("ok",false)
	check(checked.size()==16 and not checked.values().has(false),"all 16 catalog-grantable items in the quest transformation graph register")
	evidence["inventory_catalog_grants"] = checked.values().count(true)

func tap_original_bag_slot(point: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.pressed = pressed
		event.position = point
		root.push_input(event,true)
		await process_frame

func compact_bag_taps(graph: Array[Dictionary]) -> void:
	var tested: Dictionary = {}
	for entry: Dictionary in graph:
		var item_id: int = int(entry.reward.RewardClassID)
		if tested.has(item_id) or not REPORTED_CARD_QUESTS.has(item_id) or entry.quest_id!=REPORTED_CARD_QUESTS[item_id]:continue
		reset()
		var uid: String = stage_compact_reward(entry)
		var key: String = str(w.item_instances[uid].name)
		var reference: String = key+"@@@"+uid
		check(w._save_game(true)==OK,"save issued compact card #"+str(item_id))
		w._load_game(true)
		var before: int = card_count(entry.card_id)
		var bag: Control = w.hud.lineage_inventory_ui
		w.hud.toggle_inventory()
		await process_frame
		var controller: Node = w.hud.original_main_ui_controller
		var hit: Dictionary = controller._inventory_view._hits.get(reference,{}) if w.hud.original_inventory_is_open() else {}
		var control: Control = hit.get("control")
		var label: String = "compact card #"+str(item_id)
		check(is_instance_valid(control) and hit.get("texture") is Texture2D,label+" shows its original icon and touch target")
		if is_instance_valid(control):
			var point: Vector2 = control.get_global_transform_with_canvas()*(control.size*0.5)
			await tap_original_bag_slot(point)
			check(bag.selected_item==reference and bag.item_action_label(reference)=="사용" and card_count(entry.card_id)==before,label+" first touch selects and arms the exact card")
			await tap_original_bag_slot(point)
			check(not w.item_instances.has(uid) and card_count(entry.card_id)==before+1,label+" second touch registers exactly one copy")
			tested[item_id] = not w.item_instances.has(uid) and card_count(entry.card_id)==before+1
		close_ui()
		await process_frame
	check(tested.size()==3 and not tested.values().has(false),"three reported original slots respond to real touch input")
	evidence["native_bag_touch"] = tested.values().count(true)

func hero_doll_box() -> void:
	# The source grants a class-specific box, then one fixed doll card with
	# the achievement card's CannotSwap restriction. Keep those as three taps.
	var cases: Dictionary={"기사":[96054,98494,42],"요정":[96064,98504,43],"마법사":[96074,98514,40]}
	for job: String in cases:
		var path: Dictionary=quest_grant(96114,["m523:quest:71834"],job)
		check(path.get("ok",false),"original #71834 issues hero doll box to "+job)
		if not path.get("ok",false):continue
		var expected: Array=cases[job]
		var outer: Dictionary=activate(96114)
		check(outer.ok and not physical_of(int(expected[0])).is_empty(),"hero box opens only the assigned intermediate box for "+job)
		if not outer.ok:continue
		for other: Array in cases.values():
			if other!=expected:check(physical_of(int(other[0])).is_empty(),"other job's box was not granted")
		var middle: Dictionary=activate(int(expected[0]))
		check(middle.get("ok",false) and not physical_of(int(expected[1])).is_empty(),"intermediate box supplies its exact fixed card: "+JSON.stringify(middle))
		var final: Dictionary=activate(int(expected[1]))
		var identity: String="source:m508:2:"+str(expected[2])
		check(final.get("ok",false) and w.card_draw_fusion.total_count("마법인형",identity)==1,"exact final doll registers from the bag: "+identity+" "+JSON.stringify(final))
		var receipts: Array=w.card_draw_fusion.source_card_receipts
		check(receipts.any(func(row: Dictionary)->bool:return row.identity==identity and row.get("buff_card_cannot_swap",false)),"achievement card retains CannotSwap")
		check(not w.card_draw_fusion.pending_acquisition_confirmation.get("마법인형",{}).has(identity),"the restricted card does not enter the reroll queue")

func runtime() -> void:
	w = load("res://Main.tscn").instantiate()
	root.add_child(w)
	w.set_process(false); w.player.set_physics_process(false); w.field_population.set_process(false); w.save_timer = -100000
	check(QA.enter_game(w, "마검사"), "actual Main map entry")
	await process_frame
	var save_path: String = w.save_path()
	var had_save: bool = FileAccess.file_exists(save_path)
	var original_save: PackedByteArray = FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	w._clear_monsters(); w._clear_drops()
	w.level = 90
	base_quest = w.quest_service.export_state().duplicate(true)
	base_cards = w.card_draw_fusion.export_state().duplicate(true)
	base_skills = w.original_skills.catalog.export_state().duplicate(true)
	base_job = str(w.job_class)
	var rewarded: Dictionary = {}
	for qid: String in w.quest_service.index:
		for reward: Dictionary in w.quest_service.full(w.quest_service.index[qid]).get("source_rewards",[]):
			var id: int = int(reward.get("RewardClassID",0))
			if str(reward.get("type_name")) == "Item" and id in REPRESENTATIVE:
				if not rewarded.has(id): rewarded[id] = []
				rewarded[id].append(qid)
	var results: Dictionary = {}
	var recovered: Dictionary={}
	for id: int in REPRESENTATIVE:
		check(rewarded.has(id), "the original quest reward table issues #" + str(id))
		if not rewarded.has(id): continue
		var candidates: Array=rewarded[id]
		if REPORTED_CARD_QUESTS.has(id):
			var matched: bool=candidates.has(REPORTED_CARD_QUESTS[id])
			check(matched,"the specific reported receipt comes from the original quest #"+str(id))
			if not matched:continue
			candidates=[REPORTED_CARD_QUESTS[id]]
		var issued: Dictionary = quest_grant(id,candidates,"",id==996)
		check(issued.get("ok", false), "quest reward #" + str(id) + " is issued")
		if not issued.get("ok", false): continue
		if REPORTED_CARD_IDS.has(id):
			var uid: String=physical_of(id)
			w._load_game(true)
			var proof: Dictionary=OWN.proof(w,uid)
			check(proof.get("ok",false) and proof.source_item.TestItem,"reloaded quest receipt keeps the unchanged original flag #"+str(id))
			check(proof.get("source_reward_timing")== (1 if id==996 else 2) and proof.get("source_use_immediately")== (id==996),"receipt comes from the expected instant or held original reward")
			check(OWN.held_test_card_spec(proof).get("card_id",0)==REPORTED_CARD_IDS[id],"only verified receipt reveals fixed effect #"+str(id))
			var request: Dictionary={"physical_id":uid,"quantity":1,"expected_quantity":1,"expected_remaining":0,"quest_reward_receipt":w.item_instances[uid].quest_reward_receipt}
			var digest: String=str(SOURCE.identity().source_sha256)
			check(not OWN.prepare_debit(w,uid,1).get("ok",false) and not CONSUME.stage(w,[request],digest).get("ok",false),"ordinary quest and crafting debits still reject the raw test card #"+str(id))
			check(w.quest_item_provider.quickslot_held_supported(w,uid),"owned card supports the same manual quickslot path #"+str(id))
			var inventory_key: String=str(proof.get("inventory_key",""))
			w.ui_preferences.item_locks[inventory_key+"@@@"+uid]=true
			var before: String=FileAccess.get_sha256(save_path)
			check(not activate(id).get("ok",false) and w.item_instances.has(uid) and FileAccess.get_sha256(save_path)==before,"locked quest card preserves ownership and saved bytes #"+str(id))
			w.ui_preferences.item_locks.erase(inventory_key+"@@@"+uid)
		var quest_use: Dictionary = activate(id)
		check(quest_use.held, "#" + str(id) + " is the held quest reward physical")
		check(quest_use.ok, "quest reward #" + str(id) + " is used from the bag: " + JSON.stringify(quest_use))
		if REPORTED_CARD_IDS.has(id):
			w._load_game(true)
			var source_id: String=IDENTITY.source_id(1,int(REPORTED_CARD_IDS[id]))
			check(w.card_draw_fusion.total_count("변신","source:"+source_id)==1 and physical_of(id).is_empty(),"the correct card and one-item debit persist on reload #"+str(id))
			check(D.definition_id(str(id)).get("native_record",{}).is_empty() and SOURCE.row("ItemClass",id).TestItem,"general loot and crafting still see the original test designation #"+str(id))
			recovered[str(id)]={"quest":issued.quest,"path":issued.path,"card":source_id,"spent":quest_use.consumed}
			continue
		reset(); w.job_class = str(issued.get("class", base_job))
		check(INV.commit(w, [{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"}), "test grant #" + str(id))
		var test_use: Dictionary = activate(id)
		check(test_use.get("ok",false) and test_use.get("card",false) == quest_use.get("card",false) and test_use.get("skill",false) == quest_use.get("skill",false), "quest reward #" + str(id) + " acts as the test grant: " + JSON.stringify(test_use))
		results[str(id)] = {"path":issued.path,"card":quest_use.get("card",false),"skill":quest_use.get("skill",false),"outputs":quest_use.get("gained",[]).size()}
	evidence["runtime"] = results
	evidence["recovered"] = recovered
	hero_doll_box()
	var graph: Array[Dictionary] = transformation_rewards()
	immediate_transformation_claims(graph)
	if "--coverage" in OS.get_cmdline_user_args():
		await compact_bag_taps(graph)
		all_held_transformations(graph)
		inventory_granted_transformations(graph)
	reset()
	w.queue_free()
	await process_frame
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null: file.store_buffer(original_save); file.close()
	elif FileAccess.file_exists(save_path): DirAccess.remove_absolute(save_path)

func run() -> void:
	rules()
	if not SOURCE.not_installed() and "--runtime" in OS.get_cmdline_user_args(): await runtime()
	print("QUEST_REWARD_CARDS523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
