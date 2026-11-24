extends SceneTree
## Original 523 selection boxes in the actual game.
## - LuckyBag whose LuckyBagEntityView rows are all LuckyBagEntityType 3
##   "Selectable": the count comes from the item's own description
##   ("다음 아이템 중 1종 선택 획득"); the chosen row is granted with its own
##   item, amount, ItemBlessCodeID and ItemEnchant.
## - The bag use of an owned selection box (this and SelectReward) opens the
##   selection dialog; confirming claims through the physical-stack owner.
## Synthetic rows always run. With the original definition ZIP installed the
## real boxes are also opened in actual Main (grant -> dialog -> claim ->
## save -> reload).
const P = preload("res://scripts/loot/current523_native_item_projection.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const CHOICE = preload("res://scripts/ui/patch523_reward_choice.gd")
const QA = preload("res://tests/qa_class_selection.gd")
## +6 스냅퍼의 반지 선택 상자 (3 rings, +6) and an existing SelectReward box.
const RING_BOX := 187362
## +4 지휘관의 휘장 상자: one IsGiven row (+4 휘장) and ResetAutoSlotByEmpty 1.
const FLAG_BOX := 193581
const FISHING_COIN_BOX := 307781
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEMS523_SELECTION_BOXES_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func no_exclusion(_table: String, _row: Dictionary) -> Dictionary: return {}

func fixture(entities: Array) -> Dictionary:
	var bonus_row: Dictionary = {"ID":9001.0,"IsPossession":false,"bonus_type":{"Name":"LuckyBagClassID"},"unit":{"Name":"LuckyBagClassID"},"bonus":{"ID":9002.0,"Value":77.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0}}
	var definition: Dictionary = {"item_bonus":[bonus_row],"original_item":{"ID":5000.0,"TargettingTypeID":1.0,"ServiceRegionCode":"","CanUseWhenInvisible":true},"category":{"Name":"LuckyBag","IsConsumable":true},"class_rows":[]}
	var graph: Dictionary = {"lucky_bag_class":{"ID":77.0,"Name":"fixture","AbleMultiple":true},"entities":entities}
	return {"definition":definition,"graph":graph}

func entity(id: int, item_id: int, enchant: int, bless: int = 1, type_id: int = 3, test_item: bool = false) -> Dictionary:
	return {"row":{"ID":float(id),"LuckyBagClassID":77.0,"LuckyBagEntityTypeID":float(type_id),"Probability":0.0,"ItemClassID":float(item_id),"ItemAmount":1.0,"ItemBlessCodeID":float(bless),"ItemEnchant":float(enchant),"LimitClass":10000.0},
		"entity_type":{"ID":float(type_id),"Name":"Selectable" if type_id==3 else "IsGiven"},"item_class":{"ID":float(item_id),"Name":"item %d" % item_id,"TestItem":test_item},"class_limits":[]}

func rules() -> void:
	check(P.described_selection_count("사용 시, 다음 아이템 중\n1종 선택 획득 가능") == 1, "'1종 선택' across a line break is 1")
	check(P.described_selection_count("사용 시, 다음 중 1종\n선택 획득 가능") == 1, "'1종\\n선택' is 1")
	check(P.described_selection_count("다음 중 2종을 선택") == 2, "'2종을 선택' is 2")
	check(P.described_selection_count("정해진 확률에 따라 다음 아이템 중 1종 획득") == 0, "no '선택' wording: no count")
	check(P.described_selection_count("1종 선택 … 2종 선택") == 0, "two different counts: no count")
	check(P.described_selection_count("11종 선택") == 11, "11 is not read as 1")
	var classes: Dictionary = {1:{"ID":1.0},2:{"ID":2.0}}
	var slots: Callable = func(_id: int) -> Array: return [{"EquipSlotID":9.0,"slot":{"Name":"Finger"}}]
	var good: Dictionary = fixture([entity(11,100,6),entity(12,101,6,2)])
	var spec: Dictionary = P.selectable_bag(good.definition,good.graph,"다음 아이템 중\n1종 선택 획득",classes,slots,no_exclusion)
	evidence["fixture_spec"] = {"kind":spec.get("kind"),"status":spec.get("activation_status"),"reasons":spec.get("blocked_reasons"),"count":spec.get("select_max_count"),"rewards":spec.get("rewards")}
	check(spec.get("kind")=="source_selectable_bag" and spec.get("activation_status")=="unrestricted" and spec.get("select_max_count")==1, "all-Selectable bag with '1종 선택' is a selection box")
	var rewards: Array = spec.get("rewards",[])
	check(rewards.size()==2 and rewards[0].source_entity_id==11 and rewards[0].item_class_id==100 and rewards[0].enchant==6 and rewards[0].bless_raw==1 and rewards[1].bless_raw==2, "each choice keeps its row's item, +6 and bless code (as ints)")
	check(spec.get("class_eligible_option_counts",{}).get("1")==2 and spec.get("source_class_domain")==[1,2], "class domain from Class.CanCreateClient, 2 options each")
	var no_count: Dictionary = P.selectable_bag(good.definition,good.graph,"선택 상자",classes,slots,no_exclusion)
	check(no_count.get("activation_status")=="blocked" and "unresolved_lucky_bag_selection_count" in no_count.get("blocked_reasons",[]), "without a stated count the box is kept")
	var with_test: Dictionary = fixture([entity(11,100,6),entity(13,102,0,1,3,true)])
	var test_spec: Dictionary = P.selectable_bag(with_test.definition,with_test.graph,"1종 선택",classes,slots,no_exclusion)
	check(test_spec.get("activation_status")=="blocked" and "source_test_or_excluded_reward_item" in test_spec.get("blocked_reasons",[]), "a test item among the choices keeps the whole box (no choice removed)")
	# ResetAutoSlotByEmpty (TrueFalse): satisfied as it stands while the bag
	# cannot sit in an auto slot (an AutoUseRegistrable row still blocks).
	var flagged: Dictionary = fixture([entity(11,100,6),entity(12,101,6,2)])
	var flag_row: Dictionary = {"ID":9003.0,"IsPossession":false,"bonus_type":{"Name":"ResetAutoSlotByEmpty"},"unit":{"Name":"TrueFalse"},"bonus":{"ID":9004.0,"Value":1.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0}}
	flagged.definition.item_bonus.append(flag_row)
	check(P.selectable_bag(flagged.definition,flagged.graph,"1종 선택",classes,slots,no_exclusion).get("activation_status")=="unrestricted", "ResetAutoSlotByEmpty 1 is admitted")
	flag_row.bonus.Value = 2.0
	check(P.selectable_bag(flagged.definition,flagged.graph,"1종 선택",classes,slots,no_exclusion).get("activation_status")=="blocked", "ResetAutoSlotByEmpty 2 is not a TrueFalse value")
	flag_row.bonus.Value = 1.0
	flagged.definition.item_bonus.append({"ID":9005.0,"IsPossession":false,"bonus_type":{"Name":"AutoUseRegistrable"},"unit":{"Name":"TrueFalse"},"bonus":{"ID":9006.0,"Value":1.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0}})
	check("unsupported_item_bonus:AutoUseRegistrable" in P.selectable_bag(flagged.definition,flagged.graph,"1종 선택",classes,slots,no_exclusion).get("blocked_reasons",[]), "an auto-use registrable bag stays blocked")
	var two_slots: Callable = func(_id: int) -> Array: return [{"EquipSlotID":9.0,"slot":{"Name":"Finger"}},{"EquipSlotID":10.0,"slot":{"Name":"Ear"}}]
	var odd: Dictionary = P.selectable_bag(good.definition,good.graph,"1종 선택",classes,two_slots,no_exclusion)
	check("unsupported_lucky_bag_reward_amount_or_variant" in odd.get("blocked_reasons",[]), "an enchanted choice without one equipment slot is kept")

func record(id: int) -> Dictionary:
	return D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)

func grant(world: Node, id: int, amount: int) -> String:
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":id,"amount":amount,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok",false), "physical grant of %d: %s" % [id,str(staged.get("error",""))]): return ""
	if not check(world._save_game(true,staged.overrides)==OK, "grant save"): return ""
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	return str(record(id).name)

func open_dialog(world: Node, name: String) -> Control:
	world.item_use_cooldowns.clear()
	if world.hud.has_meta("patch523_reward_choice"):
		var old: Variant = world.hud.get_meta("patch523_reward_choice")
		if is_instance_valid(old): old.free()
		world.hud.remove_meta("patch523_reward_choice")
	world.consumable_service.try_use(name)
	var dialog: Variant = world.hud.get_meta("patch523_reward_choice") if world.hud.has_meta("patch523_reward_choice") else null
	return dialog if is_instance_valid(dialog) else null

func physical(world: Node, name: String) -> int:
	var total: int = 0
	for id: String in world.item_instances:
		var proof: Dictionary = STACK.proof(world,id)
		if not proof.is_empty() and str(proof.record.name)==name: total += int(proof.remaining)
	return total

func table() -> void:
	var spec: Dictionary = record(RING_BOX).get("source_use_spec",{})
	if spec.is_empty(): spec = preload("res://scripts/loot/current523_native_fields.gd").full(record(RING_BOX)).get("source_use_spec",{})
	evidence["ring_box"] = {"kind":spec.get("kind"),"status":spec.get("activation_status"),"reasons":spec.get("blocked_reasons"),"options":spec.get("rewards",[]).size()}
	check(spec.get("kind")=="source_selectable_bag" and spec.get("activation_status")=="unrestricted" and spec.get("rewards",[]).size()==3 and STACK.profile(record(RING_BOX)).get("kind")=="selection", "#187362: 3 Selectable +6 rings, 1종 선택 → selection profile")
	var flag_spec: Dictionary = preload("res://scripts/loot/current523_native_fields.gd").full(record(FLAG_BOX)).get("source_use_spec",{})
	evidence["flag_box"] = {"kind":flag_spec.get("kind"),"status":flag_spec.get("activation_status"),"reasons":flag_spec.get("blocked_reasons")}
	check(flag_spec.get("kind")=="guaranteed_bag" and flag_spec.get("activation_status")=="unrestricted" and STACK.profile(record(FLAG_BOX)).get("kind")=="bag", "#193581 with ResetAutoSlotByEmpty is a usable guaranteed bag")
	# Every non-test all-Selectable original bag is claimed or explained.
	var categories: Dictionary = {}
	for category: Dictionary in SOURCE.rows("ItemCategory"):
		if str(category.get("Name",""))=="LuckyBag": categories[int(category.ID)] = true
	var claimed: int = 0; var held: Dictionary = {}
	for row: Dictionary in SOURCE.rows_matching("ItemClass","CategoryID",categories):
		if row.get("TestItem")!=false: continue
		var item: Dictionary = record(int(row.ID))
		var use: Dictionary = preload("res://scripts/loot/current523_native_fields.gd").full(item).get("source_use_spec",{})
		if use.get("kind")!="source_selectable_bag": continue
		if STACK.profile(item).get("kind")=="selection": claimed += 1
		else: held[int(row.ID)] = use.get("blocked_reasons",[])
	evidence["family"] = {"claimed":claimed,"held":held}
	check(claimed>=96, "all-Selectable LuckyBags with a stated count are selection boxes (%d, held %s)" % [claimed,str(held)])

func fishing_checks(world: Node) -> void:
	var item: Dictionary=record(FISHING_COIN_BOX)
	var spec: Dictionary=FIELDS.full(item).get("source_use_spec",{})
	var options: Dictionary={50971:"명예 코인",50981:"변신 제작 코인",50991:"마법인형 제작 코인",51001:"성물 제작 코인"}
	check(spec.get("source_reward_timing_desc_id")==2066161 and STACK.profile(item).get("kind")=="selection", "exact documented fishing selector admitted")
	for unverified: int in [307971]:
		var other: Dictionary=FIELDS.full(record(unverified)).get("source_use_spec",{})
		check(other.get("activation_status")=="blocked" and "unsupported_select_reward_rule:RewardGetTimeTypeID" in other.get("blocked_reasons",[]), "other timing-2 selectors are not admitted")
	var name: String=grant(world,FISHING_COIN_BOX,4)
	if name.is_empty(): return
	for expected_entity: int in options:
		var snapshot: Dictionary=world.inventory.duplicate(true)
		var rng: int=world.rng.state
		var before_save: PackedByteArray=FileAccess.get_file_as_bytes(world.save_path())
		var dialog: Control=open_dialog(world,name)
		if not check(dialog!=null and dialog.choices.item_count==4, "actual use opens four coin choices"): return
		await process_frame
		check(world.inventory==snapshot and rng==world.rng.state and before_save==FileAccess.get_file_as_bytes(world.save_path()), "quote preserves inventory, RNG, and save bytes")
		var choice: int=-1
		for index: int in range(dialog.choices.item_count):
			if int(dialog.choices.get_item_metadata(index))==expected_entity:choice=index
		if not check(choice>=0, "original entity is present"): return
		dialog.choices.select(choice);dialog._claim()
		check(dialog.last_claim.get("ok",false) and dialog.last_claim.get("saved",false) and dialog.last_claim.get("consumed")==1, "claim commits exactly one owned input: "+str(dialog.last_claim.get("reason","")))
		await process_frame
		snapshot[name]=int(snapshot[name])-1
		var wallet: String=options[expected_entity]
		snapshot[wallet]=int(snapshot.get(wallet,0))+10000
		if snapshot[name]==0:snapshot.erase(name)
		check(world.inventory==snapshot and rng==world.rng.state, "only the picked wallet gains 10,000, no RNG")
		# Load converts JSON numeric variants and can migrate unrelated keys.
		# Corrupt only the in-memory selected output, then require durable counts
		# for every wallet plus the owned input, independent of those changes.
		world.inventory.erase(wallet)
		world._load_game(true)
		world.field_population.set_process(false);world.player.set_physics_process(false)
		var restored: bool=int(world.inventory.get(name,0))==int(snapshot.get(name,0)) and physical(world,name)==int(snapshot.get(name,0))
		for key: String in options.values():
			restored=restored and int(world.inventory.get(key,0))==int(snapshot.get(key,0))
		check(restored, "all exact wallet counts and remaining physical stack survive reload")

func growth_coin_checks(world: Node) -> void:
	var spec: Dictionary=FIELDS.full(record(289702)).get("source_use_spec",{})
	check(spec.get("source_reward_timing_desc_id")==1844122 and spec.get("activation_status")=="unrestricted", "original growth pass selector admitted")
	var name: String=grant(world,289702,4)
	if name.is_empty():return
	for expected: Array in [[44642,289842],[44652,289862],[44662,289852],[44672,289872]]:
		var dialog: Control=open_dialog(world,name)
		if not check(dialog!=null and dialog.choices.item_count==4,"growth pass opens four original box choices"):return
		await process_frame
		var output: Dictionary=record(expected[1])
		var output_name: String=str(output.name)
		check(STACK.profile(output).get("kind")=="bag","chosen child is an exact supported native bag")
		var count: int=int(world.inventory.get(output_name,0));var rng: int=world.rng.state
		var choice: int=-1
		for index: int in range(dialog.choices.item_count):
			if int(dialog.choices.get_item_metadata(index))==expected[0]:choice=index
		if not check(choice>=0,"original growth pass entity present"):return
		dialog.choices.select(choice);dialog._claim()
		check(dialog.last_claim.get("ok",false) and dialog.last_claim.get("saved",false) and dialog.last_claim.get("consumed")==1,"growth pass choice commits: "+str(dialog.last_claim.get("reason","")))
		await process_frame
		check(int(world.inventory.get(output_name,0))==count+1 and physical(world,output_name)==count+1 and world.rng.state==rng,"one exact child box with physical receipt; no RNG")

func complex_checks(world: Node) -> void:
	for held: int in [164643,165633]:
		check(STACK.profile(record(held)).get("kind")!="selection", "unverified complex family members remain held")
	for inputs: Array in [[164623,160463,22,3],[164633,160463,23,4],[167404,155994,9,4],[167424,155994,22,3]]:
		var item: Dictionary=record(inputs[0])
		var spec: Dictionary=FIELDS.full(item).get("source_use_spec",{})
		check(spec.get("source_complex_reward",false) and spec.get("activation_status")=="unrestricted", "source fixed+choice projection: "+str(inputs[0]))
		var name: String=grant(world,inputs[0],1)
		if name.is_empty():continue
		var before: Dictionary=world.inventory.duplicate(true);var rng: int=world.rng.state
		var dialog: Control=open_dialog(world,name)
		if not check(dialog!=null and dialog.choices.item_count==inputs[3],"complex UI displays only exact choices for #"+str(inputs[0])):continue
		await process_frame
		var pending: Dictionary=dialog.pending
		check(pending.get("entity_id_namespace")=="ComplexRewardEntity.ID" and world.inventory==before and rng==world.rng.state,"correct source namespace; no payout before confirmation")
		var uid: String=str(pending.ownership_request.physical_id)
		var chosen: Dictionary=pending.choices[0]
		var chosen_name: String=str(record(int(chosen.item_class_id)).name)
		var fixed_name: String=str(record(inputs[1]).name)
		var strict_before: bool=D.rotate_ended_dates
		D.rotate_ended_dates=false
		var rejected: Dictionary=world.consumable_service.claim_owned_original_selection(FIELDS.full(item).source_original_item,pending.ownership_request,int(chosen.source_entity_id))
		D.rotate_ended_dates=strict_before
		check(not rejected.get("ok",false) and world.inventory==before and not STACK.proof(world,uid).is_empty(), "strict source date preserves input and both outputs")
		dialog.choices.select(0);dialog._claim()
		check(dialog.last_claim.get("ok",false) and dialog.last_claim.get("saved",false) and dialog.last_claim.get("consumed")==1 and dialog.last_claim.get("rewards",[]).size()==2, "one atomic debit + fixed + selected: "+str(dialog.last_claim.get("reason","")))
		await process_frame
		before.erase(name)
		before[chosen_name]=int(before.get(chosen_name,0))+1
		before[fixed_name]=int(before.get(fixed_name,0))+int(inputs[2])
		check(world.inventory==before and rng==world.rng.state and STACK.proof(world,uid).is_empty(),"exact two outputs, no extra selections, no RNG")
		world.inventory.erase(chosen_name);world.inventory.erase(fixed_name)
		world._load_game(true)
		world.field_population.set_process(false);world.player.set_physics_process(false)
		check(int(world.inventory.get(chosen_name,0))==int(before[chosen_name]) and int(world.inventory.get(fixed_name,0))==int(before[fixed_name]) and physical(world,fixed_name)>=int(inputs[2]) and int(world.inventory.get(name,0))==0 and STACK.proof(world,uid).is_empty(),"both payouts and debit survive reload")

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false); world.player.auto_enabled = false
	world._clear_monsters(); world._clear_drops()
	world.inventory = {}; world.item_instances = {}
	if "--reward-gap-only" in OS.get_cmdline_user_args():
		await fishing_checks(world)
		await growth_coin_checks(world)
		await complex_checks(world)
		world.queue_free();await process_frame;return
	await fishing_checks(world)
	await growth_coin_checks(world)
	await complex_checks(world)
	var name: String = grant(world,RING_BOX,2)
	if name.is_empty(): world.queue_free(); await process_frame; return
	var dialog: Control = open_dialog(world,name)
	if not check(dialog != null, "using the box opens the selection dialog"): world.queue_free(); await process_frame; return
	await process_frame
	var list: ItemList = dialog.choices
	evidence["dialog"] = {"rows":list.item_count,"first":list.get_item_text(0) if list.item_count>0 else ""}
	check(list.item_count==3 and list.get_item_text(0).contains("+6") and not list.get_item_text(0).begins_with("?"), "dialog lists the 3 original rows by name with +6")
	check(int(world.inventory.get(name,0))==2 and physical(world,name)==2, "opening the dialog debits nothing")
	dialog.queue_free(); await process_frame
	check(int(world.inventory.get(name,0))==2, "cancelling keeps the box")
	dialog = open_dialog(world,name); await process_frame
	var chosen_entity: int = int(dialog.choices.get_item_metadata(1))
	var chosen: Dictionary = {}
	for reward: Dictionary in dialog.pending.choices:
		if int(reward.source_entity_id)==chosen_entity: chosen = reward
	var output: String = str(record(int(chosen.item_class_id)).name)
	var before_output: int = int(world.inventory.get(output,0))
	dialog.choices.select(1); dialog._claim()
	evidence["claim"] = {"ok":dialog.last_claim.get("ok"),"reason":dialog.last_claim.get("reason",dialog.last_claim.get("message","")),"chosen":chosen}
	check(dialog.last_claim.get("ok",false) and dialog.last_claim.get("saved",false) and dialog.last_claim.get("consumed")==1, "confirming claims the chosen row: %s" % str(dialog.last_claim.get("reason","")))
	await process_frame
	check(int(world.inventory.get(name,0))==1 and physical(world,name)==1, "one box used")
	check(int(world.inventory.get(output,0))==before_output+1, "the chosen ring is in the bag")
	var levels: Array = []
	for id: String in world.item_instances:
		var entry: Variant = world.item_instances[id]
		if entry is Dictionary and str(entry.get("name",""))==output: levels.append(int(entry.get("level",0)))
	evidence["granted_levels"] = levels
	check(levels.has(6), "the ring is +6 (the row's ItemEnchant)")
	check(world._save_game(true)==OK, "save")
	world.inventory.erase(name); world.inventory.erase(output)
	world._load_game(true)
	check(int(world.inventory.get(name,0))==1 and int(world.inventory.get(output,0))==before_output+1 and physical(world,name)==1, "box 1 and the ring survive reload")
	dialog = open_dialog(world,name)
	check(dialog != null and dialog.choices.item_count==3, "the reloaded box opens the dialog again")
	if dialog != null: dialog.queue_free()
	await process_frame
	# A ResetAutoSlotByEmpty bag opens as its rows say (+4 휘장).
	var flag_name: String = grant(world,FLAG_BOX,1)
	var badge_row: Dictionary = SOURCE.related("LuckyBagEntityView","LuckyBagClassID",int(preload("res://scripts/loot/current523_native_fields.gd").full(record(FLAG_BOX)).get("source_use_spec",{}).get("lucky_bag_class_id",0)))[0]
	var badge: String = str(record(int(badge_row.ItemClassID)).name)
	world.item_use_cooldowns.clear()
	var opened: Dictionary = STACK.try_use(world,flag_name)
	var badge_levels: Array = []
	for id: String in world.item_instances:
		var entry: Variant = world.item_instances[id]
		if entry is Dictionary and str(entry.get("name",""))==badge: badge_levels.append(int(entry.get("level",0)))
	evidence["flag_open"] = {"ok":opened.get("ok"),"reason":opened.get("reason",opened.get("message","")),"levels":badge_levels}
	check(opened.get("ok",false) and int(world.inventory.get(flag_name,0))==0 and badge_levels.has(int(badge_row.ItemEnchant)), "#193581 opens: box used, +%d badge granted" % int(badge_row.ItemEnchant))
	# An existing SelectReward box goes through the same dialog now.
	var select_id: int = 0
	if true:
		var categories: Dictionary = {}
		for category: Dictionary in SOURCE.rows("ItemCategory"):
			if str(category.get("Name",""))=="SelectReward": categories[int(category.ID)] = true
		for row: Dictionary in SOURCE.rows_matching("ItemClass","CategoryID",categories):
			if row.get("TestItem")!=false: continue
			var item: Dictionary = record(int(row.ID))
			var use: Dictionary = preload("res://scripts/loot/current523_native_fields.gd").full(item).get("source_use_spec",{})
			if STACK.profile(item).get("kind")!="selection" or use.get("kind")!="source_selectable_reward" or D.deadline_problem(item,540)!="": continue
			var all_ok: bool = true
			for reward: Dictionary in use.get("rewards",[]):
				if reward.get("requires_local_initial_enchant_rule",false) or not reward.get("class_ids",[]).is_empty(): all_ok = false
			if all_ok: select_id = int(row.ID); break
	evidence["select_reward_box"] = select_id
	if check(select_id>0, "an existing SelectReward box is available"):
		var select_name: String = grant(world,select_id,1)
		var select_dialog: Control = open_dialog(world,select_name)
		if check(select_dialog != null and select_dialog.choices.item_count>0, "SelectReward box #%d opens the dialog" % select_id):
			await process_frame
			select_dialog.choices.select(0); select_dialog._claim()
			evidence["select_claim"] = {"ok":select_dialog.last_claim.get("ok"),"reason":select_dialog.last_claim.get("reason",select_dialog.last_claim.get("message",""))}
			check(select_dialog.last_claim.get("ok",false) and int(world.inventory.get(select_name,0))==0, "SelectReward box #%d is claimed through the dialog" % select_id)
	check(world.patch523_owner_state_problem.is_empty(), "no owner problem")
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		if "--reward-gap-only" not in OS.get_cmdline_user_args():table()
		await runtime()
	elif "--reward-gap-only" in OS.get_cmdline_user_args():check(false,"verified source ZIP required")
	print("ITEMS523_SELECTION_BOXES_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
