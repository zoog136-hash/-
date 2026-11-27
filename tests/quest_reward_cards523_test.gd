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
## 아크 나이트(근사 허용 시험 행 카드), 변신·인형·성물 카드 확정 상자, 희귀 변신
## 카드 상자, 스킬 카드 뽑기팩 상자, 마검사 각인 스킬서, 공허의 사원 희귀 카드
## 상자(연계 콘텐츠 퀘스트: 옛 세이브 보유분).
const REPRESENTATIVE = [1067, 123393, 146692, 297858, 155643, 324693, 291202, 328908]
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
	check(SOURCE.approximated_item({"ID":5,"TestItem":true}).get("TestItem") == true, "other test items stay test items")
	var pinned: Dictionary = {"ID":1067,"TestItem":true}
	SOURCE.approximated_item(pinned)
	check(pinned.TestItem == true, "the pinned quest row itself is not changed")
	var stack: String = FileAccess.get_file_as_string("res://scripts/loot/current523_native_stack.gd")
	check(stack.contains('if spec.kind=="fixed_card":return use_fixed_card(world,uid,selected_owned,record,spec)'), "a quest-held fixed card uses the native card owner")
	check(stack.contains('var paid: Dictionary=QUEST_CONSUME.stage(world,[request],str(SOURCE.identity().source_sha256)) if is_quest else stage_debit(world,[request])') and stack.contains('if is_quest and not QUEST_CONSUME.matches_payload(world,paid,payload):return _failure("퀘스트 카드'), "a quest card is debited through the quest ledger")
	check(stack.contains('var payload: Dictionary=paid.overrides.duplicate(true);payload["consumable_state"]=state;payload["original_skill_state"]=learned'), "the quest skill book candidate is compared unchanged")
	check(stack.contains('SOURCE.approximated_item(original_item)!=SOURCE.row("ItemClass"'), "the held bag/card row check reads the approved approximation")
	var provider: String = FileAccess.get_file_as_string("res://scripts/quests/quest_item_provider238.gd")
	check(provider.contains('(held_kind=="fixed_card" and int(original_owned.item_class_id) not in FIXED.QUEST_IDS)'), "held fixed cards route to the native owner; reviewed quest cards keep theirs")
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
		if not selected.get("ok",false):return {"ok":false,"held":held,"why":selected}
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

func quest_grant(id: int, quests: Array, job: String="") -> Dictionary:
	var svc = w.quest_service
	var classes: Array = [base_job]
	for c: Variant in svc.source.class_ids:
		if str(c) not in classes: classes.append(str(c))
	if not job.is_empty():classes=[job]
	var now: int = int(Time.get_unix_time_from_system())
	for qid: String in quests:
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
				if w._save_game(true) == OK and OWN.proof(w, uid).get("ok", false): return {"ok":true,"quest":qid,"class":c,"path":"old_save"}
	return {"ok":false}

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
		check(activate(int(expected[0])).ok and not physical_of(int(expected[1])).is_empty(),"intermediate box supplies its exact fixed card")
		var final: Dictionary=activate(int(expected[1]))
		var identity: String="source:m508:2:"+str(expected[2])
		check(final.ok and w.card_draw_fusion.total_count("마법인형",identity)==1,"exact final doll registers from the bag: "+identity)
		check(w.card_draw_fusion.source_swap_blocked.get("마법인형:"+identity,false),"achievement card retains CannotSwap")

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
	for id: int in REPRESENTATIVE:
		check(rewarded.has(id), "the original quest reward table issues #" + str(id))
		if not rewarded.has(id): continue
		var issued: Dictionary = quest_grant(id, rewarded[id])
		check(issued.get("ok", false), "quest reward #" + str(id) + " is issued")
		if not issued.get("ok", false): continue
		var quest_use: Dictionary = activate(id)
		check(quest_use.held, "#" + str(id) + " is the held quest reward physical")
		check(quest_use.ok, "quest reward #" + str(id) + " is used from the bag: " + JSON.stringify(quest_use))
		reset(); w.job_class = str(issued.get("class", base_job))
		check(INV.commit(w, [{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"}), "test grant #" + str(id))
		var test_use: Dictionary = activate(id)
		check(test_use.ok and test_use.card == quest_use.card and test_use.skill == quest_use.skill, "quest reward #" + str(id) + " acts as the test grant: " + JSON.stringify(test_use))
		results[str(id)] = {"path":issued.path,"card":quest_use.card,"skill":quest_use.skill,"outputs":quest_use.gained.size()}
	evidence["runtime"] = results
	hero_doll_box()
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
