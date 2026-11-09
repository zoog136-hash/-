extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Execute verified source joins; never infer an item's use from its name.
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
const PRESENTATION_FLAGS: Dictionary = {"UIShowFilter":"Value","NoAnnounce":"TrueFalse"}

static func canonical(record: Dictionary) -> Dictionary:
	if not record.get("source_m_native_item", false):
		var existing: Dictionary = DROPS.item_definition(record)
		var converted: Dictionary = existing.get("native_record", {}).duplicate(true)
		if NATIVE_FIELDS.full(converted).get("source_use_spec", {}).get("kind") not in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag","source_selectable_reward","source_skill_book"]: return {}
		for key: String in ["name", "source", "sourceId", "sourceUrl", "slot", "type", "grade"]: converted[key] = record.get(key, "")
		return converted
	var definition: Dictionary = DROPS.definition_id(str(int(record.get("source_item_class_id", -1))))
	var original: Dictionary = definition.get("native_record", {})
	if original.is_empty(): return {}
	var expected: Dictionary = DROPS.expected_variant(original,record)
	return expected if DROPS.matches(record, expected) else {}

static func action_record(world: Node, saved: Dictionary) -> Dictionary:
	var record: Dictionary = preload("res://scripts/quests/quest_regen523.gd").action(world,canonical(saved))
	if int(record.get("source_item_class_id",0)) in [295544,302461,203422,295504,282793,295524]:
		var reusable: Dictionary=load("res://scripts/quests/quest_reusable523.gd").profile(record)
		if not reusable.is_empty():record=reusable
	record=preload("res://scripts/quests/quest_source_buffs523.gd").action(world,record)
	if int(record.get("source_item_class_id",0))==310:
		var cure: Dictionary=load("res://scripts/quests/quest_cure310.gd").profile(record)
		if not cure.is_empty():record=cure
	var spec: Dictionary = NATIVE_FIELDS.full(record).get("source_use_spec",{})
	if spec.get("activation_status") != "blocked" or not world.ui_preferences.get("patch523_item_presentation_flags_policy",true): return record
	var presentation: Dictionary = {}
	for row: Dictionary in DROPS.item_definition(saved).get("item_bonus",[]):
		var kind: String = str(row.bonus_type.Name)
		if not PRESENTATION_FLAGS.has(kind): continue
		if row.get("IsPossession") != false or int(row.bonus.BonusApplicationTypeID) != 0 or int(row.bonus.BonusApplicationTargetID) != 0 or row.unit.Name != PRESENTATION_FLAGS[kind] or int(row.bonus.Value) not in [0,1]: return record
		presentation["unsupported_item_bonus:"+kind] = true
	if presentation.is_empty(): return record
	var reasons: Array = spec.get("blocked_reasons",[])
	if reasons.is_empty(): return record
	for reason: String in reasons:
		if presentation.has(reason): continue
		if reason in ["source_item_lifetime_unresolved","conditional_or_possession_item_bonus:DeleteTime"] and record.has("source_delete_time_raw") and not record.get("source_delete_time_unresolved",false): continue
		return record
	# Source definitions remain blocked in the private pack. This reducer is an
	# explicit, reversible host interpretation, never new source probability.
	spec = spec.duplicate(true)
	spec["activation_status"] = "unrestricted"
	spec["local_presentation_flags_policy"] = "TWILIGHT_display_metadata_not_use_gate_estimate"
	record["source_use_spec"] = spec
	return record

static func eligibility(world: Node, record: Dictionary) -> String:
	if record.is_empty(): return "원본 아이템 자료를 확인할 수 없습니다"
	var dummy: String=preload("res://scripts/quests/source_dummy523.gd").reason(record)
	if not dummy.is_empty():return dummy
	if not record.get("source_condition_pending",[]).is_empty():return "원본 서비스·서버·기간 조건 연결 필요 · 아이템 보존"
	if record.get("source_test_item", false): return "원본 테스트 아이템은 사용할 수 없습니다"
	var deadline: String = DROPS.deadline_problem(record,int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
	if not deadline.is_empty(): return deadline
	if int(record.get("source_bless_raw", 1)) not in [1, 2, 3]: return "원본 축복 상태 미지원"
	var full: Dictionary = NATIVE_FIELDS.full(record)
	if not full.get("source_unresolved_class_ids", []).is_empty(): return "원본 사용 직업 조건 미확인"
	var classes: Array = full.get("source_class_names", [])
	if not classes.is_empty() and not classes.has(world.job_class): return "원본 사용 직업 조건에 맞지 않습니다"
	var level: int = world.level
	for prefix: String in ["source_level_limit_", "source_max_level_limit_"]:
		var minimum: int = int(record.get(prefix+"min", 0))
		var maximum: int = int(record.get(prefix+"max", 0))
		# TWILIGHT's level only increases, so its current level is also its peak.
		if level < minimum or (maximum > 0 and level > maximum): return "원본 사용 레벨 조건에 맞지 않습니다"
	return ""

static func try_use(world: Node, saved: Dictionary) -> bool:
	if int(saved.get("source_item_class_id",0))==310:
		load("res://scripts/quests/quest_cure310.gd").perform(world,saved)
		return true
	if int(saved.get("source_item_class_id",0)) in [203422,295504,295544,302461,282793,295524]:
		load("res://scripts/quests/quest_reusable523.gd").perform(world,saved)
		return true
	var record: Dictionary = action_record(world,saved)
	if not saved.get("source_m_native_item", false) and record.is_empty(): return false
	var problem: String = eligibility(world, record)
	if int(record.get("source_item_class_id",0)) in [376,385] and world.hp<=0:problem="사망 상태 · 원본 재생 물약 보존"
	if not problem.is_empty():
		world.hud.show_message(problem)
		return true
	if DROPS.equipment(record): return false
	if not preload("res://scripts/loot/patch523_ammo.gd").profile(record).is_empty(): return false
	# Source HP potions retain the existing shared HP-potion rules.
	if not record.get("heal_spec", {}).is_empty():
		var hp_problem: String = DROPS.hp_use_problem(record,world.is_player_concealed(),int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
		if not hp_problem.is_empty():
			world.hud.show_message(hp_problem)
			return true
		return false
	var name_value: String = str(record.name)
	if int(world.inventory.get(name_value, 0)) < 1:
		world.hud.show_message("아이템이 없습니다")
		return true
	var spec: Dictionary = NATIVE_FIELDS.full(record).get("source_use_spec", {})
	if spec.get("activation_status", "") != "unrestricted":
		world.hud.show_message("원본 사용 조건·효과 미지원 · 아이템을 보존했습니다")
		return true
	var requirements: Dictionary = spec.get("item_requirements", {})
	if int(requirements.get("targetting_type_id", -1)) != 1 or not str(requirements.get("service_region_code", "")).is_empty():
		world.hud.show_message("원본 사용 대상·서비스 조건 미지원 · 아이템 보존")
		return true
	if not requirements.get("can_use_when_invisible", false) and world.is_player_concealed():
		world.hud.show_message("원본 조건: 은신 중 사용할 수 없습니다")
		return true
	var cooldown_key: String = "m523:item:"+str(int(record.source_item_class_id))
	if float(world.item_use_cooldowns.get(cooldown_key, 0.0)) > 0.0:
		world.hud.show_message("원본 아이템 재사용 대기 %s" % world._format_seconds_short(float(world.item_use_cooldowns[cooldown_key])))
		return true
	if world._option_awakening_busy() or (world.hud.has_method("is_card_reveal_busy") and world.hud.is_card_reveal_busy()): return true
	match str(spec.get("kind", "")):
		"fixed_card": _fixed_card(world, record, spec)
		"source_timed_buff": _flat_buff(world, record, spec)
		"source_mp_dice": _mp_potion(world, record, spec)
		"source_selectable_reward": _open_selection(world, record)
		"source_skill_book": preload("res://scripts/loot/patch523_skill_book.gd").use(world, record, spec)
		"guaranteed_bag": _guaranteed_bag(world, record, spec)
		"source_weighted_bag", "mixed_rewards_bag":
			if world.ui_preferences.get("patch523_source_reward_bags_enabled",true): _guaranteed_bag(world,record,spec)
			else: world.hud.show_message("TWILIGHT 원본 상자 선택 규칙 사용 안함 · 아이템 보존")
		_: world.hud.show_message("원본 사용 효과 미지원 · 아이템을 보존했습니다")
	return true

static func debit(world: Node, item_name: String) -> Dictionary:
	var staged: Dictionary = world.inventory.duplicate(true)
	var amount: int = int(staged.get(item_name, 0))-1
	if amount <= 0: staged.erase(item_name)
	else: staged[item_name] = amount
	return staged

static func _fixed_card(world: Node, record: Dictionary, spec: Dictionary) -> void:
	var category: String = str(spec.get("card_kind", ""))
	var candidates: Array[Dictionary] = []
	for card: Dictionary in world.catalog_db.get(category, []):
		if card.get("source") in ["lineagem_base508","lineagem_patch523"] and int(card.get("source_card_id", -1)) == int(spec.get("card_id", -2)) and card.get("source_original_card", {}) == spec.get("original_card", {}): candidates.append(card)
	if candidates.size() != 1:
		world.hud.show_message("원본 카드 ID·정의 일치 확인 실패 · 아이템 보존")
		return
	var before: Dictionary = world.card_draw_fusion.export_state()
	var outcome: Dictionary = world.card_draw_fusion.receive_source_card(category, candidates[0], {
		"source_snapshot":"patch523", "item_class_id":int(record.source_item_class_id),
		"card_id":int(spec.card_id), "buff_card_cannot_swap":bool(spec.get("buff_card_cannot_swap", false)),
		"bless":int(record.get("source_bless_raw", 1))})
	var after: Dictionary = world.card_draw_fusion.export_state()
	world.card_draw_fusion.import_state(before)
	if not outcome.get("ok", false):
		world.hud.show_message(str(outcome.get("error", "원본 카드 지급 실패")))
		return
	var inventory: Dictionary = debit(world, str(record.name))
	if world._save_game(true, {"inventory":inventory, "card_draw_fusion":after}) != OK:
		world.hud.show_message("카드 지급 저장 실패 · 아이템과 기존 카드 보유 상태 보존")
		return
	world.inventory = inventory
	world.card_draw_fusion.import_state(after)
	world._invalidate_equipment_static()
	world.hud.refresh_inventory(world.inventory)
	world._update_hud()
	var message: String = "원본 지정 카드 지급 · %s (%s)" % [str(candidates[0].name), category]
	world.hud.show_message(message)
	world.hud.append_log(message)
	if int(spec.get("consume_effect_sprite_id",0)) > 0: world.option_awakening.combat.emit_sprite(int(spec.consume_effect_sprite_id),world.player,DROPS.item_definition(record).get("original_item",{}))
	world.hud.set_card_draw_fusion_result(category, message)
	world.hud.present_card_reveal(category, outcome, false)

static func _flat_buff(world: Node, record: Dictionary, spec: Dictionary) -> void:
	var duration: float = float(spec.get("duration_seconds", 0.0))
	var source: Dictionary = spec.get("source_buff_class", {})
	var group: Dictionary = spec.get("source_buff_group", {})
	if duration <= 0.0 or source.is_empty() or group.is_empty() or spec.get("typed_effects", {}).is_empty(): return
	var buffs: Dictionary = world.active_item_buffs.duplicate(true)
	for key: String in buffs.keys():
		var old: Dictionary = buffs[key]
		if not old.has("source_buff_class"): continue
		var previous: Dictionary = old.source_buff_class
		if int(previous.ID) == int(source.ID) or (not group.get("IsAllowOverlap", false) and int(previous.BuffGroupID) == int(source.BuffGroupID)): buffs.erase(key)
	var value: Dictionary = spec.typed_effects.duplicate(true)
	value.merge({"remaining":duration,"duration":duration,"source_buff_class":source.duplicate(true),"source_buff_group":group.duplicate(true),"source_item_class_id":int(record.source_item_class_id),"source_snapshot":"patch523"})
	buffs[str(record.name)] = value
	var inventory: Dictionary = debit(world, str(record.name))
	var cooldowns: Dictionary = next_cooldowns(world, record, spec)
	if world._save_game(true, {"inventory":inventory,"active_item_buffs":buffs,"item_use_cooldowns":cooldowns}) != OK:
		world.hud.show_message("버프 저장 실패 · 아이템과 기존 버프 보존")
		return
	world.inventory = inventory
	world.active_item_buffs = buffs
	world.item_use_cooldowns = cooldowns
	world.hp = mini(world.hp, world._effective_max_hp())
	world.mp = mini(world.mp, world._effective_max_mp())
	world._refresh_speed_modifiers()
	world.hud.refresh_inventory(world.inventory)
	world._update_hud()
	var message: String = "%s · 원본 버프 %s" % [str(record.source_display_name),world._format_seconds_short(duration)]
	world.hud.show_message(message)
	world.hud.append_log(message)
	if int(spec.get("consume_effect_sprite_id",0)) > 0: world.option_awakening.combat.emit_sprite(int(spec.consume_effect_sprite_id),world.player,DROPS.item_definition(record).get("original_item",{}))

static func next_cooldowns(world: Node, record: Dictionary, spec: Dictionary) -> Dictionary:
	var result: Dictionary = world.item_use_cooldowns.duplicate(true)
	var delay: float = float(spec.get("consume_delay_ms", 0))/1000.0
	if delay > 0.0:
		result["m523:item:"+str(int(record.source_item_class_id))] = delay
		result[str(record.name)] = delay
	return result

static func _mp_potion(world: Node, record: Dictionary, spec: Dictionary) -> void:
	var maximum: int = world._effective_max_mp()
	if world.mp >= maximum:
		world.hud.show_message("MP가 가득 찼습니다")
		return
	var before: int = world.rng.state
	var amount: int = int(spec.get("base", 0))
	var count: int = int(spec.get("dice_number", 0))
	var sides: int = int(spec.get("dice_spot_count", 0))
	if count < 0 or count > 1000 or (count > 0 and (sides < 1 or sides > 1000000)): return
	for die: int in range(count): amount += world.rng.randi_range(1, sides)
	var mp: int = mini(maximum, world.mp+amount)
	var inventory: Dictionary = debit(world, str(record.name))
	var cooldowns: Dictionary = next_cooldowns(world, record, spec)
	if world._save_game(true, {"inventory":inventory,"mp":mp,"item_use_cooldowns":cooldowns}) != OK:
		world.rng.state = before
		world.hud.show_message("MP 회복 저장 실패 · 물약과 MP 보존")
		return
	world.inventory = inventory
	world.mp = mp
	world.item_use_cooldowns = cooldowns
	world.hud.refresh_inventory(world.inventory)
	world._update_hud()
	world.hud.show_message("%s · MP %d 회복" % [str(record.source_display_name),amount])
	if int(spec.get("consume_effect_sprite_id",0)) > 0: world.option_awakening.combat.emit_sprite(int(spec.consume_effect_sprite_id),world.player,DROPS.item_definition(record).get("original_item",{}))

static func _guaranteed_bag(world: Node, record: Dictionary, spec: Dictionary) -> void:
	var class_id: int = world.BASE508.source_class_id(world.job_class)
	# Validate every eligible award before advancing the random stream.
	for reward: Dictionary in spec.get("rewards", []):
		if not class_matches(reward.get("class_ids",[]),class_id): continue
		if int(reward.get("entity_type_id",1)) == 0 and int(reward.get("probability_raw",0)) <= 0: continue
		if not preload("res://scripts/quests/source_dummy523.gd").item_id_evidence(int(reward.item_class_id)).is_empty():
			world.hud.show_message("원본 더미 보상이 포함된 상자는 보존합니다 · 후보 제거·확률 재배분 없음")
			return
		var base: Dictionary = DROPS.data().get("item_definitions",{}).get(str(int(reward.item_class_id)),{}).get("native_record",{})
		if base.is_empty() or base.get("source_test_item",true) or not DROPS.matches(world._find_catalog_item_record(str(DROPS.variant_item(base,int(reward.bless_raw)).name)),DROPS.variant_item(base,int(reward.bless_raw))):
			world.hud.show_message("원본 보상 정의·등록 확인 실패 · 상자 보존")
			return
	var rng_before: int = world.rng.state
	var chosen: Dictionary = select_rewards(spec,class_id,world.rng,clampi(int(world.ui_preferences.get("patch523_reward_bag_draw_count",1)),1,10))
	if not chosen.get("ok",false):
		world.rng.state = rng_before
		world.hud.show_message("원본 보상 직업·확률 검증 실패 · 상자 보존")
		return
	_commit_rewards(world, record, spec, chosen.rewards, rng_before)

static func _commit_rewards(world: Node, record: Dictionary, spec: Dictionary, selected: Array, rng_before: int) -> bool:
	var inventory: Dictionary = debit(world, str(record.name))
	var instances: Dictionary = world.item_instances.duplicate(true)
	var gold: int = world.gold
	var rewards: PackedStringArray = []
	var class_id: int = world.BASE508.source_class_id(world.job_class)
	for reward: Dictionary in selected:
		var classes: Array = reward.get("class_ids", [])
		if not class_matches(classes,class_id): continue
		if not preload("res://scripts/quests/source_dummy523.gd").item_id_evidence(int(reward.item_class_id)).is_empty():
			world.rng.state=rng_before
			world.hud.show_message("원본 더미 보상 연결 제외 · 상자와 기존 소유 보존")
			return false
		var definition: Dictionary = DROPS.data().get("item_definitions", {}).get(str(int(reward.item_class_id)), {})
		var base: Dictionary = definition.get("native_record", {})
		var enchant: int = int(reward.get("enchant", 0)) if reward.get("enchant") != null else 0
		var local_initial: bool = reward.get("enchant") == null and DROPS.equipment(base)
		if local_initial and (spec.get("kind") != "source_selectable_reward" or not world.ui_preferences.get("patch523_select_reward_initial_zero_enabled",true)):
			world.hud.show_message("선택 장비 초기 +0 자체 규칙 사용 안함 · 상자 보존")
			return false
		if base.is_empty() or base.get("source_test_item", true) or int(reward.amount) < 1 or enchant < 0 or (enchant > 0 and not DROPS.equipment(base)) or int(reward.bless_raw) not in [1,2,3]:
			world.rng.state = rng_before
			world.hud.show_message("원본 보상 아이템·상태 확인 실패 · 상자 보존")
			return false
		var item: Dictionary = DROPS.variant_item(base, int(reward.bless_raw))
		if not DROPS.matches(world._find_catalog_item_record(str(item.name)), item):
			world.rng.state = rng_before
			world.hud.show_message("원본 보상 아이템 등록 미확인 · 상자 보존")
			return false
		var wallet: String = DROPS.currency_identity_name(item)
		var name_value: String = wallet if not wallet.is_empty() else str(item.name)
		if wallet == "아데나": gold += int(reward.amount)
		else: inventory[name_value] = int(inventory.get(name_value, 0))+int(reward.amount)
		if DROPS.equipment(item):
			var state: String = {1:"normal",2:"blessed",3:"cursed"}[int(reward.bless_raw)]
			item["bless_state"] = state
			for index: int in range(int(reward.amount)):
				var identity: String = Crypto.new().generate_random_bytes(16).hex_encode()
				while instances.has(identity): identity = Crypto.new().generate_random_bytes(16).hex_encode()
				instances[identity] = {"name":str(item.name),"level":enchant,"element":"","element_level":0,"record":NATIVE_FIELDS.full(item).duplicate(true),"bless_state":state,"source_m_reward_proof":{"source_snapshot":"patch523","item_class_id":int(record.source_item_class_id),"source_item_class_id":int(reward.item_class_id),"lucky_bag_class_id":int(spec.get("lucky_bag_class_id",0)),"select_reward_id":int(spec.get("select_reward_id",0)),"entity_id":int(reward.source_entity_id),"bless":int(reward.bless_raw),"enchant":enchant,"initial_enchant_origin":"twilight_configured_default_zero" if local_initial else str(reward.get("enchant_origin","source_bag_initial_enchant")),"original_initial_enchant":reward.get("enchant")}}
		rewards.append("%s ×%d" % [str(base.source_display_name),int(reward.amount)])
	if rewards.is_empty():
		world.rng.state = rng_before
		world.hud.show_message("현재 직업에 해당하는 원본 보상이 없습니다 · 상자 보존")
		return false
	var cooldowns: Dictionary = next_cooldowns(world, record, spec)
	if world._save_game(true, {"inventory":inventory,"item_instances":instances,"gold":gold,"item_use_cooldowns":cooldowns}) != OK:
		world.rng.state = rng_before
		world.hud.show_message("상자 보상 저장 실패 · 상자·추첨 상태·기존 보유 상태 보존")
		return false
	world.inventory = inventory
	world.item_instances = instances
	world.gold = gold
	world.item_use_cooldowns = cooldowns
	world.hud.refresh_inventory(world.inventory)
	world._update_hud()
	var prefix: String = "원본 확정 보상 · " if spec.kind == "guaranteed_bag" else "원본 확률·수량 보상 · 선택 횟수는 TWILIGHT 설정 · "
	if spec.kind == "source_selectable_reward": prefix = "원본 선택 보상 · 장비 초기 +0은 TWILIGHT 설정 · "
	var message: String = prefix + ", ".join(rewards)
	world.hud.show_message(message)
	world.hud.append_log(message)

	return true

static func select_rewards(spec: Dictionary, class_id: int, rng: RandomNumberGenerator, draws: int = 1) -> Dictionary:
	var given: Array[Dictionary] = []
	var weighted: Array[Dictionary] = []
	var total: int = 0
	for reward: Dictionary in spec.get("rewards",[]):
		if not class_matches(reward.get("class_ids",[]),class_id): continue
		if int(reward.get("entity_type_id",1)) == 1: given.append(reward)
		elif int(reward.get("entity_type_id",-1)) == 0:
			var weight: int = int(reward.get("probability_raw",0))
			if weight < 0: return {"ok":false}
			total += weight
			if weight > 0: weighted.append(reward)
		else: return {"ok":false}
	if spec.get("kind") != "guaranteed_bag":
		if total != 10000000 or int(spec.get("source_probability_denominator",0)) != total or weighted.is_empty(): return {"ok":false}
		for index: int in range(clampi(draws,1,10)):
			var roll: int = rng.randi_range(0,total-1)
			var upper: int = 0
			for reward: Dictionary in weighted:
				upper += int(reward.probability_raw)
				if roll < upper:
					given.append(reward)
					break
	return {"ok":not given.is_empty(),"rewards":given}

static func class_matches(classes: Array, class_id: int) -> bool:
	if classes.is_empty(): return true
	for value: Variant in classes:
		if int(value) == class_id: return true
	return false

static func clear_on_death(world: Node) -> void:
	for key: String in world.active_item_buffs.keys():
		var buff: Dictionary = world.active_item_buffs[key]
		if buff.has("source_buff_class") and not buff.source_buff_class.get("IsImmuneToDead", false): world.active_item_buffs.erase(key)

static func _open_selection(world: Node, record: Dictionary) -> void:
	if record.get("source_projection")=="current523_original_typed_game_dto_v1":
		world.hud.show_message("원본 UI와 선택한 물리 개체의 보상 요청 연결 필요 · 아이템 보존")
		return
	var existing: Variant = world.hud.get_meta("patch523_reward_choice") if world.hud.has_meta("patch523_reward_choice") else null
	if is_instance_valid(existing):
		world.hud.show_message("열려 있는 원본 선택 보상을 먼저 확인하세요")
		return
	var dialog: Control = preload("res://scripts/ui/patch523_reward_choice.gd").new()
	dialog.configure(world, record)
	world.hud.set_meta("patch523_reward_choice", dialog)
	world.hud.add_child(dialog)

static func claim_selection(world: Node, saved: Dictionary, entity_id: int, ownership: Dictionary={}) -> bool:
	var current: Dictionary=canonical(saved)
	if current.get("source_projection")=="current523_original_typed_game_dto_v1":
		if ownership.is_empty():
			world.hud.show_message("선택한 원본 물리 개체·수량·영수증 요청 필요 · 아이템 보존")
			return false
		var result: Dictionary=world.consumable_service.claim_owned_original_selection(NATIVE_FIELDS.full(current).get("source_original_item",{}),ownership,entity_id)
		world.hud.show_message(str(result.get("message",result.get("reason","원본 선택 보상 연결 대기"))))
		return result.get("ok",false) and result.get("saved",false) and result.get("consumed")==1
	# Re-read the pinned pack and ownership at confirmation, never trust the UI row.
	var record: Dictionary = action_record(world,saved)
	var problem: String = eligibility(world, record)
	if not problem.is_empty():
		world.hud.show_message(problem)
		return false
	var spec: Dictionary = NATIVE_FIELDS.full(record).get("source_use_spec", {})
	if spec.get("kind") != "source_selectable_reward" or spec.get("activation_status") != "unrestricted" or int(spec.get("select_max_count",0)) != 1: return false
	if int(world.inventory.get(str(record.name),0)) < 1: return false
	var requirements: Dictionary = spec.get("item_requirements", {})
	if int(requirements.get("targetting_type_id",-1)) != 1 or not str(requirements.get("service_region_code","")).is_empty(): return false
	if world.is_player_concealed() and not requirements.get("can_use_when_invisible",false): return false
	if float(world.item_use_cooldowns.get("m523:item:"+str(int(record.source_item_class_id)),0.0)) > 0.0: return false
	var choices: Array[Dictionary] = []
	for reward: Dictionary in spec.get("rewards",[]):
		if int(reward.source_entity_id) == entity_id and class_matches(reward.get("class_ids",[]),world.BASE508.source_class_id(world.job_class)): choices.append(reward)
	if choices.size() != 1: return false
	return _commit_rewards(world,record,spec,choices,world.rng.state)
