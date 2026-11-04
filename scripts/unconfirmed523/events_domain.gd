extends RefCounted
## Attendance/pass state and roulette presentation from the imported 523 tables.
## Inventory and persistence are committed by the host only after confirmation.

var _source: Object
var _servers: Dictionary = {}
var _attendance: Dictionary = {}
var _levels: Dictionary = {}
var _quests: Dictionary = {}
var _pools: Dictionary = {}
var _item_contracts: Dictionary = {}
var _luckybags: Dictionary = {}
var _class_limits: Dictionary = {}
var _item_bonuses: Dictionary = {}
var _quest_links: Dictionary = {}
var _quest_rewards: Dictionary = {}
var _quest_prerequisites: Dictionary = {}
var _npc_groups: Dictionary = {}

func setup(source: Object) -> void:
	_source = source
	_servers.clear()
	_attendance.clear()
	_levels.clear()
	_quests.clear()
	_pools.clear()
	_item_contracts.clear()
	_luckybags.clear()
	_class_limits.clear()
	_item_bonuses.clear()
	_quest_links.clear()
	_quest_rewards.clear()
	_quest_prerequisites.clear()
	_npc_groups.clear()
	for row in _rows("ServerLimit"):
		var key := str(int(row.get("ServerLimitSetID", 0)))
		if not _servers.has(key):
			_servers[key] = []
		_servers[key].append(row)
	for row in _rows("AttendanceReward"):
		var key := str(int(row.get("AttendanceVersionID", 0)))
		if not _attendance.has(key):
			_attendance[key] = []
		_attendance[key].append(row)
	for row in _rows("PassSystemLevel"):
		var key := str(int(row.get("PassSystemID", 0)))
		if int(key) == 0:
			continue # Source sentinel is not an actual pass tier.
		if not _levels.has(key):
			_levels[key] = []
		_levels[key].append(row)
	for row in _rows("PassSystemQuest"):
		var key := str(int(row.get("PassSystemQuestListID", 0)))
		if not _quests.has(key):
			_quests[key] = []
		_quests[key].append(int(row.get("QuestID", 0)))
	for link in _rows("QuestGoal"):
		_append(_quest_links, str(int(link.get("QuestID", 0))), link)
	for link in _rows("QuestReward"):
		_append(_quest_rewards, str(int(link.get("QuestID", 0))), int(link.get("RewardID", 0)))
	for link in _rows("QuestPrerequisite"):
		_append(_quest_prerequisites, str(int(link.get("QuestID", 0))), link)
	for link in _rows("NpcClassForNpcGroup"):
		_append(_npc_groups, str(int(link.get("NpcClassID", 0))), link)
	for row in _rows("GotChaEntityView"):
		var key := str(int(row.get("GotChaClassID", 0)))
		if not _pools.has(key):
			_pools[key] = []
		_pools[key].append(row)

	for entity in _rows("LuckyBagEntityView"):
		var key := str(int(entity.get("LuckyBagClassID", 0)))
		if not _luckybags.has(key):
			_luckybags[key] = []
		_luckybags[key].append(entity)
	for limit in _rows("LuckyBagEntityClassLimit"):
		var key := str(int(limit.get("LuckyBagEntityID", 0)))
		if not _class_limits.has(key):
			_class_limits[key] = []
		_class_limits[key].append(int(limit.get("ClassID", 0)))
	for link in _rows("ItemBonus"):
		var bonus := _row("Bonus", int(link.get("BonusID", 0)))
		var item_id := int(link.get("ItemClassID", 0))
		if not _item_bonuses.has(str(item_id)):
			_item_bonuses[str(item_id)] = []
		_item_bonuses[str(item_id)].append(bonus)
		var type_id := int(bonus.get("BonusTypeID", 0))
		if bool(link.get("IsPossession", false)) or type_id not in [110, 5031, 5774]:
			continue
		var item := _row("ItemClass", item_id)
		var category := _row("ItemCategory", int(item.get("CategoryID", 0)))
		if not bool(category.get("IsConsumable", false)):
			continue
		var expected := 78 if type_id == 110 else (10381 if type_id == 5031 else 10394)
		if int(item.get("CategoryID", 0)) != expected:
			continue
		if not _item_contracts.has(str(item_id)):
			_item_contracts[str(item_id)] = []
		_item_contracts[str(item_id)].append({"type": type_id, "target": int(bonus.get("Value", 0))})

func initial_state() -> Dictionary:
	return {"schema": 1, "attendance": {}, "passes": {}, "rng_state": "52338039", "roulette_pool": 0, "uses": {}, "quest_progress": {}, "quest_claims": {}, "latest_at": 0}

func validate_state(value: Variant) -> String:
	if not value is Dictionary or not _whole(value.get("schema"), 1) or int(value.schema) != 1:
		return "출석/패스 저장 형식이 올바르지 않습니다."
	if not value.get("attendance") is Dictionary or not value.get("passes") is Dictionary or not value.get("uses", {}) is Dictionary:
		return "출석/패스 진행 정보가 손상되었습니다."
	if not _whole(value.get("latest_at", 0), 0):
		return "콘텐츠 진행 시각이 손상되었습니다."
	if not value.get("rng_state") is String or not str(value.rng_state).is_valid_int():
		return "보상 난수 상태가 손상되었습니다."
	if not _whole(value.get("roulette_pool", 0), 0):
		return "룰렛 표시 상태가 손상되었습니다."
	if not value.get("quest_progress", {}) is Dictionary or not _claim_map(value.get("quest_claims", {})):
		return "패스 퀘스트 기록이 손상되었습니다."
	for quest_key in value.get("quest_progress", {}):
		if not quest_key is String or not value.quest_progress[quest_key] is Dictionary:
			return "패스 퀘스트 진행이 손상되었습니다."
		var token_error := _validate_quest_token(str(quest_key))
		if not token_error.is_empty():
			return token_error
		var quest_id := str(quest_key).get_slice(":", 1).to_int()
		var goals: Dictionary = {}
		for link in _quest_links.get(str(quest_id), []):
			goals[str(int(link.get("GoalID", 0)))] = _row("Goal", int(link.get("GoalID", 0)))
		for goal_key in value.quest_progress[quest_key]:
			if not goal_key is String or not goals.has(goal_key) or not _whole(value.quest_progress[quest_key][goal_key], 0) or int(value.quest_progress[quest_key][goal_key]) > int(goals[goal_key].get("Amount", 0)):
				return "패스 퀘스트 횟수가 손상되었습니다."
	for token in value.get("quest_claims", {}):
		var token_error := _validate_quest_token(str(token))
		if not token_error.is_empty():
			return token_error
		var quest_id := str(token).get_slice(":", 1).to_int()
		var progress: Dictionary = value.get("quest_progress", {}).get(token, {})
		for link in _quest_links.get(str(quest_id), []):
			var goal := _row("Goal", int(link.get("GoalID", 0)))
			if int(progress.get(str(int(goal.get("ID", 0))), 0)) != int(goal.get("Amount", 0)):
				return "패스 퀘스트 완료 기록이 진행도와 일치하지 않습니다."
	for use_key in value.get("uses", {}):
		if not use_key is String or not _whole(value.uses[use_key], 0):
			return "상자 사용 시간 기록이 손상되었습니다."
	for key in value.attendance:
		var progress: Variant = value.attendance[key]
		if not key is String or not progress is Dictionary:
			return "출석 기록이 손상되었습니다."
		if not _whole(progress.get("count"), 0) or not _whole(progress.get("last_day"), -1):
			return "출석 날짜/횟수가 손상되었습니다."
		if not _claim_map(progress.get("claims")):
			return "출석 수령 기록이 손상되었습니다."
		var version := _row("AttendanceVersion", str(key).get_slice(":", 0).to_int())
		if int(version.get("AttendanceTypeID", 0)) == 1:
			if int(progress.count) != progress.claims.size():
				return "출석 횟수와 수령 기록이 일치하지 않습니다."
			for index in range(1, int(progress.count) + 1):
				if not progress.claims.has(str(index)):
					return "출석 수령 순서가 손상되었습니다."
	for key in value.passes:
		var progress: Variant = value.passes[key]
		if not key is String or not str(key).is_valid_int() or not progress is Dictionary:
			return "패스 기록이 손상되었습니다."
		if not _whole(progress.get("experience"), 0) or not progress.get("base") is bool or not progress.get("premium") is bool:
			return "패스 경험치/구매 기록이 손상되었습니다."
		if bool(progress.premium) and not bool(progress.base):
			return "프리미엄 패스에 기본 패스가 없습니다."
		if not _claim_map(progress.get("claims")):
			return "패스 보상 수령 기록이 손상되었습니다."
		for claim in progress.claims:
			var parts := str(claim).split(":")
			if parts.size() != 2 or not str(parts[0]).is_valid_int() or str(parts[1]) not in ["base", "premium"]:
				return "패스 단계 수령 번호가 손상되었습니다."
			var tier := _row("PassSystemLevel", int(parts[0]))
			if int(tier.get("PassSystemID", 0)) != int(key) or not bool(progress.get(str(parts[1]), false)):
				return "패스 구매와 단계 수령 기록이 일치하지 않습니다."
	return ""

func view(context: Dictionary, state: Dictionary) -> Dictionary:
	var result := {"title": "출석 · 패스 · 룰렛", "notes": [], "rows": []}
	var error := validate_state(state)
	if not error.is_empty():
		result.notes.append(error)
		return result
	result.notes.append("523 원문 기준. 출석 버전과 서버별 대체 보상을 구분하며, 패스 경험치는 원문의 누적 기준입니다.")
	result.notes.append("출석 아인 Amount 0의 미확인 원식은 TWILIGHT 설정: 기본 %d × 기존 레벨 충전 배율로 대체합니다. 상자는 원문 가중치 1회 추첨, 선택 수 기본 1개를 사용합니다." % int(context.get("twilight_policy", {}).get("attendance_blessing_base", 200)))
	result.notes.append("룰렛 Step/Grade/Route/Type 확률은 연출용입니다. 카드 추첨은 기존 카드 메뉴에서 진행합니다.")
	for version in _rows("AttendanceVersion"):
		if int(version.get("AttendanceTypeID", 0)) not in [1, 2] or str(version.get("ServiceRegionCode", "")) != str(context.get("region", "KR")):
			continue
		var key := _attendance_key(version)
		for reward in _attendance.get(str(int(version.ID)), []):
			if not _server_ok(int(reward.get("ServerLimitSetID", 0)), context):
				continue
			var index := int(reward.get("RewardIndex", 0))
			var label := "일일 출석" if int(version.AttendanceTypeID) == 1 else "누적 출석"
			var request := {"action": "attendance_claim", "version_id": int(version.ID), "index": index}
			var reason := _attendance_reason(version, reward, context, state)
			var detail := _reward_summary(int(reward.RewardID), context)
			if int(reward.get("Goal", 0)) > 0:
				detail += " · 누적 출석 %d회" % int(reward.Goal)
			result.rows.append({"id": "attendance:%s:%s" % [key, index], "label": "%s %d회 (v%d)" % [label, index, int(version.Version)], "detail": "%s · %s" % [detail, "수령 가능" if reason.is_empty() else reason], "actions": [_reward_action("수령", request, int(reward.RewardID))] if reason.is_empty() else []})
	for pass_row in _rows("PassSystem"):
		if not _pass_available(pass_row, context).is_empty():
			continue
		var pass_id := int(pass_row.ID)
		var progress := _pass_progress(state, pass_id)
		var actions: Array = []
		for premium in [false, true]:
			var reason := _purchase_reason(pass_row, premium, context, state)
			if reason.is_empty():
				var price := _purchase_price(pass_row, premium)
				actions.append({"label": "%s (%d · 재화 %d)" % ["프리미엄 구매" if premium else "기본 패스 구매", int(price.get("amount", 0)), int(price.get("id", 0))], "request": {"action": "pass_purchase", "pass_id": pass_id, "premium": premium}, "costs": [{"kind": "currency", "id": int(price.get("id", 0)), "amount": int(price.get("amount", 0))}]})
		result.rows.append({"id": "pass:%d" % pass_id, "label": "패스 %d" % pass_id, "detail": "경험치 %d · 기본 %s · 프리미엄 %s · 구매 마감 %s" % [_pass_experience(pass_id, context, state), str(progress.base), str(progress.premium), _date_label(int(pass_row.get("PassPurchaseEndDateTimeID", 0)))], "actions": actions})
		var quest_lists: Array = [int(pass_row.get("PassSystemQuestListID", 0)), int(pass_row.get("PassSystemDailyQuestListID", 0))]
		var shown_quests: Dictionary = {}
		for list_id in quest_lists:
			for quest_id in _quests.get(str(list_id), []):
				if shown_quests.has(str(quest_id)):
					continue
				shown_quests[str(quest_id)] = true
				var quest := _row("QuestView", int(quest_id))
				var quest_reason := _pass_quest_reason(pass_row, quest, context, state)
				var quest_detail := _pass_quest_detail(pass_row, quest, context, state)
				var reward_labels: Array[String] = []
				for quest_reward_id in _quest_rewards.get(str(int(quest_id)), []):
					reward_labels.append(_reward_summary(int(quest_reward_id), context))
				if not reward_labels.is_empty():
					quest_detail += " · " + ", ".join(reward_labels)
				result.rows.append({"id": "pass-quest:%d:%d" % [pass_id, int(quest_id)], "label": "패스 %d 퀘스트 %d" % [pass_id, int(quest_id)], "detail": "%s · %s" % [quest_detail, "수령 가능" if quest_reason.is_empty() else quest_reason], "actions": [{"label": "경험치 수령", "request": {"action": "pass_quest_claim", "pass_id": pass_id, "quest_id": int(quest_id)}}] if quest_reason.is_empty() else []})
		for tier in _levels.get(str(pass_id), []):
			for premium in [false, true]:
				var reason := _tier_reason(pass_row, tier, premium, context, state)
				var reward_id := int(tier.get("PremiumRewardID" if premium else "RewardID", 0))
				var threshold := "캐릭터 레벨 %d" % int(tier.Level) if int(pass_row.get("PassSystemTypeID", 0)) == 2 else "패스 경험치 %d" % int(tier.get("Experience", 0))
				result.rows.append({"id": "pass:%d:%d:%s" % [pass_id, int(tier.ID), str(premium)], "label": "%d 단계 %d %s" % [pass_id, int(tier.Level), "프리미엄" if premium else "기본"], "detail": "%s · %s · %s" % [_reward_summary(reward_id, context), threshold, "수령 가능" if reason.is_empty() else reason], "actions": [_reward_action("수령", {"action": "pass_claim", "pass_id": pass_id, "level_id": int(tier.ID), "premium": premium}, reward_id)] if reason.is_empty() else []})
	for item_key in _item_contracts:
		var item_id := int(item_key)
		var owned := _count(context.get("owned", {}), item_id)
		if owned <= 0:
			continue
		var item := _row("ItemClass", item_id)
		var contract: Dictionary = _item_contracts[item_key][0] if _item_contracts[item_key].size() == 1 else {}
		var request := {"action": "consume_item", "item_id": item_id}
		var actions: Array = []
		var detail := "보유 %d · 원본 상자 1개 소비" % owned
		var reason := _item_reason(item_id, context, state)
		if reason.is_empty() and not contract.is_empty():
			var action := {"label": "열기", "request": request}
			if int(contract.type) == 110:
				var entries := _eligible_bag(int(contract.target), context)
				var options: Array = []
				var total := 0
				for entity in entries:
					if int(entity.LuckyBagEntityTypeID) == 0:
						total += int(entity.get("Probability", 0))
					elif int(entity.LuckyBagEntityTypeID) == 3:
						options.append({"label": _item_label(int(entity.ItemClassID)), "value": int(entity.ID)})
				if not options.is_empty():
					action["required_choices"] = [{"key": "luckybag_selection", "options": options, "count": _selection_count(int(contract.target), context)}]
				detail += " · LuckyBag %d · 원문 가중치 합 %d · TWILIGHT 원문 가중치 1회 추첨" % [int(contract.target), total]
			else:
				var choices := _reward_choices(int(contract.target))
				if not choices.is_empty():
					action["required_choices"] = choices
			actions.append(action)
		else:
			detail += " · " + reason
		result.rows.append({"id": "container:%d" % item_id, "label": _item_label(item_id), "detail": detail, "actions": actions})
	var pool_id := int(state.get("roulette_pool", 0))
	if pool_id == 0 and not _pools.is_empty():
		pool_id = int(_pools.keys()[0])
	for key in _pools:
		result.rows.append({"id": "pool:%s" % key, "label": "GotCha 보상 풀 %s" % key, "detail": "%d개 보상 · 원문 가중치 합 %d" % [_pools[key].size(), _pool_total(_pools[key])], "actions": [{"label": "확률 보기", "request": {"action": "roulette_inspect", "pool_id": int(key)}}]})
	for entity in _pools.get(str(pool_id), []):
		result.rows.append({"id": "pool-entity:%d" % int(entity.ID), "label": "풀 %d · 카드 %d" % [pool_id, int(entity.get("BuffCardID", 0))], "detail": "원문 가중치 %d / %d · Grade %d · Unit %d · Class %d" % [int(entity.get("Probability", 0)), _pool_total(_pools.get(str(pool_id), [])), int(entity.get("Grade", 0)), int(entity.get("UnitID", 0)), int(entity.get("ClassID", 0))], "actions": []})
	for table in ["RouletteDisplayOfGachaProbability", "RouletteDisplayOfMergeProbability"]:
		for row in _rows(table):
			result.rows.append({"id": "%s:%d" % [table, int(row.ID)], "label": "룰렛 연출 · %s" % ("추첨" if table == "RouletteDisplayOfGachaProbability" else "합성"), "detail": "Step %d · Grade %d · Route %d · Type %d · 원문 확률 %d" % [int(row.RouletteDisplayStepID), int(row.GradeID), int(row.RouletteDisplayRouteID), int(row.RouletteDisplayTypeID), int(row.Probability)], "actions": []})
	return result

func propose(request: Dictionary, context: Dictionary, state: Dictionary) -> Dictionary:
	var error := validate_state(state)
	if not error.is_empty():
		return _failure(error)
	if int(context.get("now", 0)) < int(state.get("latest_at", 0)):
		return _failure("마지막 진행 시각보다 이전입니다. 기기 시각을 확인하세요.")
	var next := state.duplicate(true)
	next.latest_at = int(context.get("now", 0))
	match str(request.get("action", "")):
		"attendance_claim":
			if not _whole(request.get("version_id"), 1) or not _whole(request.get("index"), 1):
				return _failure("출석 요청 번호가 올바르지 않습니다.")
			var version := _row("AttendanceVersion", int(request.get("version_id", 0)))
			if version.is_empty():
				return _failure("출석 버전을 찾을 수 없습니다.")
			var matches: Array = []
			for reward in _attendance.get(str(int(version.ID)), []):
				if int(reward.get("RewardIndex", 0)) == int(request.get("index", 0)) and _server_ok(int(reward.get("ServerLimitSetID", 0)), context):
					matches.append(reward)
			if matches.size() != 1:
				return _failure("현재 서버의 출석 보상을 하나로 확정할 수 없습니다.")
			var reward: Dictionary = matches[0]
			error = _attendance_reason(version, reward, context, state)
			if not error.is_empty():
				return _failure(error)
			var resolved := _resolve(int(reward.RewardID), request, context, next)
			if not bool(resolved.get("ok", false)):
				return resolved
			var key := _attendance_key(version)
			var progress := _attendance_progress(next, key)
			progress.claims[str(int(reward.RewardIndex))] = true
			if int(version.AttendanceTypeID) == 1:
				progress.count = int(progress.count) + 1
				progress.last_day = _local_day(context)
			next.attendance[key] = progress
			return _success(next, [], resolved.rewards)
		"pass_purchase":
			if not _whole(request.get("pass_id"), 1) or not request.get("premium", false) is bool:
				return _failure("패스 구매 요청이 올바르지 않습니다.")
			var pass_row := _row("PassSystem", int(request.get("pass_id", 0)))
			var premium := bool(request.get("premium", false))
			error = _purchase_reason(pass_row, premium, context, state)
			if not error.is_empty():
				return _failure(error)
			var price := _purchase_price(pass_row, premium)
			if not bool(price.get("ok", false)):
				return _failure(str(price.get("error", "패스 가격을 확인할 수 없습니다.")))
			var currency_id := int(price.id)
			var amount := int(price.amount)
			if _count(context.get("currencies", {}), currency_id) < amount:
				return _failure("패스 구매 재화가 부족합니다.")
			var progress := _pass_progress(next, int(pass_row.ID))
			progress["premium" if premium else "base"] = true
			next.passes[str(int(pass_row.ID))] = progress
			return _success(next, [{"kind": "currency", "id": currency_id, "amount": amount}], [])
		"pass_claim":
			if not _whole(request.get("pass_id"), 1) or not _whole(request.get("level_id"), 1) or not request.get("premium", false) is bool:
				return _failure("패스 수령 요청이 올바르지 않습니다.")
			var pass_row := _row("PassSystem", int(request.get("pass_id", 0)))
			var tier := _row("PassSystemLevel", int(request.get("level_id", 0)))
			var premium := bool(request.get("premium", false))
			error = _tier_reason(pass_row, tier, premium, context, state)
			if not error.is_empty():
				return _failure(error)
			var resolved := _resolve(int(tier.get("PremiumRewardID" if premium else "RewardID", 0)), request, context, next)
			if not bool(resolved.get("ok", false)):
				return resolved
			var progress := _pass_progress(next, int(pass_row.ID))
			progress.claims[_tier_key(tier, premium)] = true
			next.passes[str(int(pass_row.ID))] = progress
			return _success(next, [], resolved.rewards)
		"pass_quest_claim":
			if not _whole(request.get("pass_id"), 1) or not _whole(request.get("quest_id"), 1):
				return _failure("패스 퀘스트 요청이 올바르지 않습니다.")
			var pass_row := _row("PassSystem", int(request.pass_id))
			var quest := _row("QuestView", int(request.quest_id))
			error = _pass_quest_reason(pass_row, quest, context, state)
			if not error.is_empty():
				return _failure(error)
			var rewards: Array = []
			for reward_id in _quest_rewards.get(str(int(quest.ID)), []):
				var resolved := _resolve(int(reward_id), request, context, next)
				if not bool(resolved.get("ok", false)):
					return resolved
				for reward in resolved.rewards:
					if str(reward.get("kind", "")) != "pass_exp" or int(reward.get("id", 0)) != int(pass_row.ID):
						return _failure("현재 패스의 퀘스트 경험치 보상이 아닙니다.")
					rewards.append(reward)
			if rewards.is_empty():
				return _failure("원문 패스 퀘스트 보상이 없습니다.")
			if not next.has("quest_claims"):
				next.quest_claims = {}
			next.quest_claims[_quest_token(pass_row, quest, context)] = true
			return _success(next, [], rewards)
		"consume_item":
			if not _whole(request.get("item_id"), 1):
				return _failure("상자 번호가 올바르지 않습니다.")
			var item_id := int(request.get("item_id", 0))
			error = _item_reason(item_id, context, state)
			if not error.is_empty():
				return _failure(error)
			if _count(context.get("owned", {}), item_id) <= 0:
				return _failure("보유한 원본 상자가 없습니다.")
			var contract: Dictionary = _item_contracts[str(item_id)][0]
			var resolved: Dictionary
			if int(contract.type) == 110:
				resolved = _open_luckybag(int(contract.target), request, context, next)
			else:
				resolved = _resolve(int(contract.target), request, context, next)
			if not bool(resolved.get("ok", false)):
				return resolved
			_record_item_use(item_id, context, next)
			return _success(next, [{"kind": "item", "id": item_id, "amount": 1}], resolved.rewards)
		"roulette_inspect":
			if not _whole(request.get("pool_id"), 1):
				return _failure("추첨 풀 번호가 올바르지 않습니다.")
			var pool_id := int(request.get("pool_id", 0))
			if not _pools.has(str(pool_id)):
				return _failure("원문에 없는 GotCha 보상 풀입니다.")
			next.roulette_pool = pool_id
			return _success(next, [], [])
	return _failure("지원하지 않는 출석/패스 작업입니다.")

func add_pass_exp(state: Dictionary, pass_id: int, amount: int) -> Dictionary:
	# Privileged host adapter for already resolved source rewards. Never exposed
	# through propose(), so arbitrary UI requests cannot mint experience.
	var error := validate_state(state)
	if not error.is_empty():
		return _failure(error)
	var pass_row := _row("PassSystem", pass_id)
	if pass_row.is_empty() or int(pass_row.get("PassSystemTypeID", 0)) != 12 or amount <= 0:
		return _failure("원문 시즌 패스 경험치 대상/수량이 올바르지 않습니다.")
	var next := state.duplicate(true)
	var progress := _pass_progress(next, pass_id)
	var current := int(progress.experience)
	if current > 9223372036854775807 - amount:
		return _failure("시즌 패스 경험치 범위를 초과합니다.")
	progress.experience = current + amount
	next.passes[str(pass_id)] = progress
	return _success(next, [], [])

func _attendance_reason(version: Dictionary, reward: Dictionary, context: Dictionary, state: Dictionary) -> String:
	if int(version.get("AttendanceTypeID", 0)) not in [1, 2]:
		return "개인 일일/누적 출석만 지원합니다."
	if str(version.get("ServiceRegionCode", "")) != str(context.get("region", "KR")) or not _server_ok(int(reward.get("ServerLimitSetID", 0)), context):
		return "현재 지역/서버의 보상이 아닙니다."
	var progress := _attendance_progress(state, _attendance_key(version))
	var index := int(reward.get("RewardIndex", 0))
	if progress.claims.has(str(index)):
		return "이미 수령했습니다."
	if int(version.AttendanceTypeID) == 1:
		if int(progress.last_day) >= _local_day(context):
			return "오늘 출석을 이미 수령했습니다."
		if index != int(progress.count) + 1:
			return "앞선 출석 보상부터 수령하세요."
	else:
		var daily_count := 0
		for daily in _rows("AttendanceVersion"):
			if int(daily.get("AttendanceTypeID", 0)) == 1 and int(daily.get("Version", -1)) == int(version.get("Version", -2)) and str(daily.get("ServiceRegionCode", "")) == str(version.get("ServiceRegionCode", "")):
				daily_count = int(_attendance_progress(state, _attendance_key(daily)).count)
		if daily_count < int(reward.get("Goal", 0)):
			return "누적 출석 %d회 필요" % int(reward.get("Goal", 0))
	return ""

func _pass_available(pass_row: Dictionary, context: Dictionary) -> String:
	if pass_row.is_empty() or not bool(pass_row.get("IsActive", false)):
		return "활성 패스가 아닙니다."
	if not _server_ok(int(pass_row.get("ServerLimitSetID", 0)), context):
		return "현재 서버의 패스가 아닙니다."
	return _window(int(pass_row.get("SeasonStartDateTimeID", 0)), int(pass_row.get("SeasonEndDateTimeID", 0)), context)

func _purchase_reason(pass_row: Dictionary, premium: bool, context: Dictionary, state: Dictionary) -> String:
	var reason := _pass_available(pass_row, context)
	if not reason.is_empty():
		return reason
	var progress := _pass_progress(state, int(pass_row.ID))
	if bool(progress.get("premium" if premium else "base", false)):
		return "이미 구매했습니다."
	if premium and not bool(progress.base):
		return "기본 패스 구매가 필요합니다."
	var end_id := int(pass_row.get("PassPurchaseEndDateTimeID", 0))
	if end_id != 0:
		var end := _timestamp(end_id, context)
		if end < 0:
			return "패스 구매 마감 시간을 확인할 수 없습니다."
		if int(context.get("now", 0)) >= end:
			return "패스 구매 기간이 끝났습니다."
	var purchase := _row("MarketPurchase_Korean", int(pass_row.get("PremiumMarketPurchaseID" if premium else "MarketPurchaseID", 0)))
	if purchase.is_empty() or not bool(purchase.get("OnSale", false)):
		return "현재 판매 중인 패스가 아닙니다."
	reason = _window(int(purchase.get("EffectiveFromId", 0)), int(purchase.get("EffectiveToId", 0)), context)
	if not reason.is_empty():
		return "패스 상품 판매 기간이 아닙니다."
	var price := _purchase_price(pass_row, premium)
	return "" if bool(price.get("ok", false)) else str(price.get("error", "패스 가격 오류"))

func _purchase_price(pass_row: Dictionary, premium: bool) -> Dictionary:
	var purchase := _row("MarketPurchase_Korean", int(pass_row.get("PremiumMarketPurchaseID" if premium else "MarketPurchaseID", 0)))
	var payment := _row("MarketPayment_Korean", int(purchase.get("MarketPaymentID", 0)))
	if payment.is_empty() or int(payment.get("MarketPaymentTypeID", 0)) != 4 or int(payment.get("UnitID", 0)) != 201 or int(payment.get("Amount", 0)) <= 0:
		return {"ok": false, "error": "원문 재화 결제 가격을 확인할 수 없습니다."}
	if _row("Currency", int(payment.get("ClassID", 0))).is_empty():
		return {"ok": false, "error": "원문 결제 재화를 찾을 수 없습니다."}
	return {"ok": true, "id": int(payment.ClassID), "amount": int(payment.Amount)}

func _tier_reason(pass_row: Dictionary, tier: Dictionary, premium: bool, context: Dictionary, state: Dictionary) -> String:
	var reason := _pass_available(pass_row, context)
	if not reason.is_empty():
		return reason
	if tier.is_empty() or int(tier.get("PassSystemID", 0)) != int(pass_row.get("ID", -1)):
		return "패스와 단계가 일치하지 않습니다."
	var progress := _pass_progress(state, int(pass_row.ID))
	if not bool(progress.get("premium" if premium else "base", false)):
		return "해당 패스를 먼저 구매하세요."
	if progress.claims.has(_tier_key(tier, premium)):
		return "이미 수령했습니다."
	if int(pass_row.get("PassSystemTypeID", 0)) == 2:
		if int(context.get("level", 1)) < int(tier.get("Level", 0)):
			return "캐릭터 레벨 %d 필요" % int(tier.get("Level", 0))
		var list_id := int(tier.get("PassSystemQuestListID", 0))
		if list_id != 0 and not _quests.has(str(list_id)):
			return "성장 패스 선행 퀘스트 원문이 없습니다."
		for quest_id in _quests.get(str(list_id), []):
			if not _quest_completed(int(quest_id), context):
				return "성장 패스 퀘스트 %d 완료 필요" % int(quest_id)
	elif int(pass_row.get("PassSystemTypeID", 0)) == 12:
		if _pass_experience(int(pass_row.ID), context, state) < int(tier.get("Experience", 0)):
			return "패스 경험치 %d 필요" % int(tier.get("Experience", 0))
	else:
		return "지원하지 않는 패스 유형입니다."
	if int(tier.get("PremiumRewardID" if premium else "RewardID", 0)) <= 0:
		return "이 단계의 보상이 없습니다."
	return ""

func _resolve(reward_id: int, request: Dictionary, context: Dictionary, next: Dictionary) -> Dictionary:
	if _source == null or not _source.has_method("resolve_reward"):
		return _failure("보상 해석기를 사용할 수 없습니다.")
	var selection: Variant = request.get("selection", {})
	if not selection is Dictionary:
		return _failure("선택 보상 지정이 올바르지 않습니다.")
	var reward := _row("Reward", reward_id)
	if str(request.get("action", "")) == "attendance_claim" and int(reward.get("RewardTypeID", 0)) == 5 and int(reward.get("Amount", -1)) == 0 and int(reward.get("RewardClassID", 0)) == 97121:
		var base: Variant = context.get("twilight_policy", {}).get("attendance_blessing_base", 200)
		if not _whole(base, 1):
			return _failure("TWILIGHT 출석 아인 설정이 올바르지 않습니다.")
		var level := int(context.get("level", 1))
		var multiplier := 1
		for threshold in [85, 87, 88, 89]:
			if level >= threshold:
				multiplier += 1
		return {"ok": true, "rewards": [{"kind": "blessing", "id": 0, "amount": int(base) * multiplier, "source_reward_id": reward_id, "policy": "TWILIGHT attendance_blessing_base"}]}
	var reward_context := context.duplicate(true)
	if str(request.get("action", "")) == "pass_claim":
		var pass_id := int(request.get("pass_id", 0))
		var pass_row := _row("PassSystem", pass_id)
		reward_context["pass_id"] = pass_id
		reward_context["pass_expires_at"] = _timestamp(int(pass_row.get("SeasonEndDateTimeID", 0)), context) if int(pass_row.get("SeasonEndDateTimeID", 0)) != 0 else 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 52338039
	rng.state = int(next.rng_state)
	var resolved: Dictionary = _source.call("resolve_reward", reward_id, reward_context, selection, rng)
	if not bool(resolved.get("ok", false)):
		return _failure(str(resolved.get("error", "이 보상 유형을 적용할 수 없습니다.")))
	if not resolved.get("rewards") is Array:
		return _failure("보상 결과가 올바르지 않습니다.")
	next.rng_state = str(rng.state)
	return {"ok": true, "rewards": resolved.rewards.duplicate(true)}

func _window(start_id: int, end_id: int, context: Dictionary) -> String:
	var now := int(context.get("now", 0))
	if start_id != 0:
		var start := _timestamp(start_id, context)
		if start < 0:
			return "시작 시간을 확인할 수 없습니다."
		if now < start:
			return "아직 시작하지 않았습니다."
	if end_id != 0:
		var end := _timestamp(end_id, context)
		if end < 0:
			return "종료 시간을 확인할 수 없습니다."
		if now >= end:
			return "기간이 끝났습니다."
	return ""

func _timestamp(id: int, context: Dictionary) -> int:
	if _source != null and _source.has_method("timestamp"):
		return int(_source.call("timestamp", id, context))
	var date := _row("DateTimes_Korean", id)
	if date.is_empty():
		return -1
	var parts := {"year": int(date.get("Year", 0)), "month": int(date.get("Month", 0)), "day": int(date.get("Day", 0)), "hour": int(date.get("Hour", 0)), "minute": int(date.get("Minute", 0)), "second": int(date.get("Second", 0))}
	if parts.year < 1970 or parts.month < 1 or parts.month > 12 or parts.day < 1 or parts.day > 31:
		return -1
	return int(Time.get_unix_time_from_datetime_dict(parts)) - _offset_minutes(context) * 60

func _date_label(id: int) -> String:
	if id == 0:
		return "원문 제한 없음"
	var date := _row("DateTimes_Korean", id)
	if date.is_empty():
		return "시간 원문 누락"
	return "%04d-%02d-%02d %02d:%02d (원문 로컬 시각)" % [int(date.Year), int(date.Month), int(date.Day), int(date.Hour), int(date.Minute)]

func _offset_minutes(context: Dictionary) -> int:
	var policy: Dictionary = context.get("time_policy", {})
	return int(policy.get("utc_offset_minutes", Time.get_time_zone_from_system().get("bias", 0)))

func _local_day(context: Dictionary) -> int:
	var policy: Dictionary = context.get("time_policy", {})
	return int(floor(float(int(context.get("now", 0)) + _offset_minutes(context) * 60 - int(policy.get("attendance_reset_hour", 0)) * 3600) / 86400.0))

func _server_ok(set_id: int, context: Dictionary) -> bool:
	if set_id == 0:
		return true
	for server in _servers.get(str(set_id), []):
		if str(server.get("ServiceRegionCode", "")) == str(context.get("region", "KR")) and int(server.get("WorldNo", -1)) == int(context.get("world_no", 1)):
			return true
	return false

func _attendance_key(version: Dictionary) -> String:
	return "%d:%d:%s" % [int(version.get("ID", 0)), int(version.get("Version", 0)), str(version.get("ServiceRegionCode", ""))]

func _attendance_progress(state: Dictionary, key: String) -> Dictionary:
	return state.get("attendance", {}).get(key, {"count": 0, "last_day": -1, "claims": {}}).duplicate(true)

func _pass_progress(state: Dictionary, pass_id: int) -> Dictionary:
	return state.get("passes", {}).get(str(pass_id), {"experience": 0, "base": false, "premium": false, "claims": {}}).duplicate(true)

func _pass_experience(pass_id: int, context: Dictionary, state: Dictionary) -> int:
	var progress := _pass_progress(state, pass_id)
	var supplied := _count(context.get("pass_exp", {}), pass_id)
	var counter := int(context.get("event_counters", {}).get("pass_exp:%d" % pass_id, 0))
	return maxi(int(progress.experience), maxi(supplied, counter))

func _quest_completed(quest_id: int, context: Dictionary) -> bool:
	var completed: Variant = context.get("completed_quests", {})
	if completed is Dictionary and bool(completed.get(str(quest_id), completed.get(quest_id, false))):
		return true
	return int(context.get("event_counters", {}).get("completed_quest:%d" % quest_id, 0)) > 0

func _tier_key(tier: Dictionary, premium: bool) -> String:
	return "%d:%s" % [int(tier.get("ID", 0)), "premium" if premium else "base"]

func _pool_total(pool: Array) -> int:
	var total := 0
	for entity in pool:
		total += int(entity.get("Probability", 0))
	return total

func _count(values: Variant, id: int) -> int:
	if not values is Dictionary:
		return 0
	return int(values.get(str(id), values.get(id, 0)))

func _claim_map(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in value:
		if not key is String or not value[key] is bool or not bool(value[key]):
			return false
	return true

func _whole(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == float(int(value)) and int(value) >= minimum

func _rows(table: String) -> Array:
	if _source == null:
		return []
	return _source.call("rows", table)

func _row(table: String, id: int) -> Dictionary:
	if _source == null or id == 0:
		return {}
	return _source.call("row", table, id)

func _success(state: Dictionary, costs: Array, rewards: Array) -> Dictionary:
	return {"ok": true, "error": "", "state": state, "costs": costs, "rewards": rewards, "rng_state": state.rng_state}

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}

func _item_reason(item_id: int, context: Dictionary, state: Dictionary = {}) -> String:
	if not _item_contracts.has(str(item_id)) or _item_contracts[str(item_id)].size() != 1:
		return "원문 소비 보상 연결을 하나로 확정할 수 없습니다."
	var item := _row("ItemClass", item_id)
	if item.is_empty() or bool(item.get("TestItem", false)):
		return "일반 플레이용 원본 상자가 아닙니다."
	var region := str(item.get("ServiceRegionCode", ""))
	if not region.is_empty() and region != str(context.get("region", "KR")):
		return "현재 지역에서 사용할 수 없는 상자입니다."
	var level := int(context.get("level", 1))
	if level < int(item.get("LevelLimitMin", 0)) or (int(item.get("LevelLimitMax", 0)) > 0 and level > int(item.LevelLimitMax)):
		return "상자의 캐릭터 레벨 조건을 충족하지 못했습니다."
	var max_min := int(item.get("MaxLevelLimitMin", 0))
	var max_max := int(item.get("MaxLevelLimitMax", 0))
	if max_min > 0 or max_max > 0:
		if not _whole(context.get("max_level"), 1):
			return "최고 레벨 기록을 확인할 수 없어 상자를 보존합니다."
		var max_level := int(context.max_level)
		if max_level < max_min or (max_max > 0 and max_level > max_max):
			return "상자의 최고 레벨 사용 조건을 충족하지 못했습니다."
	for limit in _rows("ItemClassLimit"):
		if int(limit.get("ItemClassID", 0)) == item_id:
			var permitted := false
			for candidate in _rows("ItemClassLimit"):
				if int(candidate.get("ItemClassID", 0)) == item_id and int(candidate.get("ClassID", 0)) == int(context.get("class_id", 0)):
					permitted = true
			if not permitted:
				return "현재 직업이 사용할 수 없는 상자입니다."
			break
	for bonus in _item_bonuses.get(str(item_id), []):
		var type_id := int(bonus.get("BonusTypeID", 0))
		match type_id:
			110, 5031, 5774:
				pass
			492:
				var expiry := _bonus_expiry(bonus, context)
				if expiry < 0:
					return "원문 삭제 시간을 확인할 수 없습니다."
				if int(context.get("now", 0)) >= expiry:
					return "삭제 시간이 지난 상자입니다."
			6714:
				if not _server_ok(int(bonus.get("Value", 0)), context):
					return "현재 서버에서 사용할 수 없는 상자입니다."
			451, 1022:
				var interval := int(bonus.get("Value", 0))
				var key := "item:%d" % item_id
				if type_id == 1022:
					key = "class:%d" % int(item.get("CategoryID", 0))
				if int(state.get("uses", {}).get(key, -1)) + interval > int(context.get("now", 0)):
					return "상자 재사용 대기 시간이 남았습니다."
			_:
				return "추가 원문 사용 조건(%d)을 해석할 수 없어 상자를 보존합니다." % type_id
	for limit in _rows("ItemUsageLimitGroup"):
		if int(limit.get("ItemClassID", 0)) != item_id:
			continue
		var group_id := int(limit.get("GroupID", 0))
		var group := _row("ItemUsageLimitGroupType", group_id)
		if group.is_empty():
			return "원문 상자 재사용 그룹을 확인할 수 없습니다."
		if int(state.get("uses", {}).get("group:%d" % group_id, -1)) + int(group.get("UsageInterval", 0)) > int(context.get("now", 0)):
			return "같은 그룹의 상자 재사용 대기 시간이 남았습니다."
	return ""

func _bonus_expiry(bonus: Dictionary, context: Dictionary) -> int:
	if int(bonus.get("BonusApplicationTypeID", 0)) == 298:
		return _timestamp(int(bonus.get("BonusApplicationTargetID", 0)), context)
	var raw := str(int(bonus.get("Value", 0)))
	if raw.length() != 10:
		return -1
	var parts := {"year": int(raw.substr(0, 4)), "month": int(raw.substr(4, 2)), "day": int(raw.substr(6, 2)), "hour": int(raw.substr(8, 2)), "minute": 0, "second": 0}
	if parts.year < 1970 or parts.month < 1 or parts.month > 12 or parts.day < 1 or parts.day > 31 or parts.hour > 23:
		return -1
	return int(Time.get_unix_time_from_datetime_dict(parts)) - _offset_minutes(context) * 60

func _record_item_use(item_id: int, context: Dictionary, state: Dictionary) -> void:
	if not state.has("uses"):
		state.uses = {}
	var now := int(context.get("now", 0))
	state.uses["item:%d" % item_id] = now
	var item := _row("ItemClass", item_id)
	state.uses["class:%d" % int(item.get("CategoryID", 0))] = now
	for limit in _rows("ItemUsageLimitGroup"):
		if int(limit.get("ItemClassID", 0)) == item_id:
			state.uses["group:%d" % int(limit.get("GroupID", 0))] = now

func _eligible_bag(bag_id: int, context: Dictionary) -> Array:
	var result: Array = []
	for entity in _luckybags.get(str(bag_id), []):
		var limits: Array = _class_limits.get(str(int(entity.get("ID", 0))), [])
		if not limits.is_empty():
			if int(context.get("class_id", 0)) not in limits:
				continue
		elif int(entity.get("LimitClass", 10000)) != 10000:
			continue
		result.append(entity)
	return result

func _open_luckybag(bag_id: int, request: Dictionary, context: Dictionary, next: Dictionary) -> Dictionary:
	for raw_entity in _luckybags.get(str(bag_id), []):
		if int(raw_entity.get("LimitClass", 10000)) != 10000 and not _class_limits.has(str(int(raw_entity.get("ID", 0)))):
			return _failure("원문 보상 직업 제한을 해석할 수 없어 상자를 보존합니다.")
	var entries := _eligible_bag(bag_id, context)
	if entries.is_empty() or _row("LuckyBagClass", bag_id).is_empty():
		return _failure("현재 직업의 원문 상자 보상 풀이 없습니다.")
	var guaranteed: Array = []
	var random_entries: Array = []
	var choices: Array = []
	var total := 0
	for entity in entries:
		if int(entity.get("ItemAmount", 0)) <= 0 or _row("ItemClass", int(entity.get("ItemClassID", 0))).is_empty():
			return _failure("원문 상자 보상 아이템을 확인할 수 없습니다.")
		if _source.has_method("item_eligibility"):
			var eligibility: Dictionary = _source.call("item_eligibility", int(entity.ItemClassID), context)
			if not bool(eligibility.get("ok", false)):
				return _failure("상자 보상 제한을 충족하지 못해 보존합니다: " + str(eligibility.get("error", "unknown")))
		match int(entity.get("LuckyBagEntityTypeID", -1)):
			0:
				var weight := int(entity.get("Probability", 0))
				if weight < 0:
					return _failure("원문 상자 가중치가 올바르지 않습니다.")
				if weight > 0:
					random_entries.append(entity)
					total += weight
			1:
				guaranteed.append(entity)
			3:
				choices.append(entity)
			_:
				return _failure("추가 원문 최종 보상 규칙을 확인할 수 없어 상자를 보존합니다.")
	if not choices.is_empty():
		var selected: Variant = request.get("luckybag_selection", [])
		if selected is int or selected is float:
			selected = [int(selected)]
		if not selected is Array or selected.size() != _selection_count(bag_id, context):
			return _failure("원하는 상자 보상을 명시적으로 선택하세요.")
		var seen: Dictionary = {}
		for raw_id in selected:
			if not _whole(raw_id, 1) or seen.has(str(int(raw_id))):
				return _failure("선택 보상이 중복되거나 올바르지 않습니다.")
			seen[str(int(raw_id))] = true
			var found := false
			for choice in choices:
				if int(choice.ID) == int(raw_id):
					guaranteed.append(choice)
					found = true
			if not found:
				return _failure("현재 상자/직업에서 고를 수 없는 보상입니다.")
	if not random_entries.is_empty():
		var policy: Dictionary = context.get("twilight_policy", {})
		var mode := str(policy.get("luckybag_random_mode", "source_weights"))
		if mode not in ["source_weights", "strict_10000000"]:
			return _failure("TWILIGHT 상자 추첨 설정이 올바르지 않습니다.")
		if mode == "strict_10000000" and total != 10000000:
			return _failure("원문 확률 합이 확정되지 않아 상자를 보존합니다.")
		var rng := RandomNumberGenerator.new()
		rng.seed = 52338039
		rng.state = int(next.rng_state)
		# TWILIGHT policy: one weighted draw; retain the exact source weights.
		var roll := rng.randi_range(1, total)
		for entity in random_entries:
			roll -= int(entity.Probability)
			if roll <= 0:
				guaranteed.append(entity)
				break
		next.rng_state = str(rng.state)
	if guaranteed.is_empty():
		return _failure("수령 가능한 원문 상자 보상이 없습니다.")
	var rewards: Array = []
	for entity in guaranteed:
		rewards.append({"kind": "item", "id": int(entity.ItemClassID), "amount": int(entity.ItemAmount), "enchant": int(entity.get("ItemEnchant", 0)), "bless_code": int(entity.get("ItemBlessCodeID", 1))})
	return {"ok": true, "rewards": rewards}

func _selection_count(bag_id: int, context: Dictionary) -> int:
	var policy: Dictionary = context.get("twilight_policy", {})
	var counts: Variant = policy.get("luckybag_selection_counts", {})
	return int(counts.get(str(bag_id), 1)) if counts is Dictionary else 1

func _item_label(item_id: int) -> String:
	var item := _row("ItemClass", item_id)
	return str(item.get("Name", "아이템 %d" % item_id))


func _reward_summary(reward_id: int, context: Dictionary = {}) -> String:
	# Description only: never resolve, select or roll a reward while viewing it.
	var reward := _row("Reward", reward_id)
	if reward.is_empty():
		return "보상 정보 확인 필요"
	var amount := int(reward.get("Amount", 0))
	var class_id := int(reward.get("RewardClassID", 0))
	match int(reward.get("RewardTypeID", 0)):
		1:
			return "경험치 %d" % amount
		2:
			return "%s ×%d" % [_item_label(class_id), amount]
		5:
			if amount == 0 and class_id == 97121:
				if not context.has("level"):
					return "TWILIGHT 축복 충전"
				var multiplier := 1
				for threshold in [85, 87, 88, 89]:
					if int(context.level) >= threshold:
						multiplier += 1
				return "TWILIGHT 축복 충전 %d" % (int(context.get("twilight_policy", {}).get("attendance_blessing_base", 200)) * multiplier)
			return "축복 충전 %d" % amount if amount > 0 else "축복 충전 (정보 확인 필요)"
		6:
			return "젬 ×%d" % amount
		101:
			return "무작위 보상"
		111:
			return "선택 보상"
		124:
			return "묶음 보상"
		172:
			return "패스 경험치 %d" % amount
		184:
			var bonus := _row("Bonus", class_id)
			var bonus_type := _row("BonusType", int(bonus.get("BonusTypeID", 0)))
			var name := str(bonus_type.get("Name", ""))
			if name.is_empty():
				return "보너스"
			var labels := {"ExperienceAdditionPercent": "획득 경험치", "AbsoluteExperienceAdditionPercent": "획득 경험치", "MeleeDamage": "근거리 대미지", "RangeDamage": "원거리 대미지", "MagicDamage": "마법 대미지", "HPPlus": "최대 HP", "MPPlus": "최대 MP"}
			var label := str(labels.get(name, name))
			var unit := _row("Unit", int(bonus_type.get("UnitID", 0)))
			if str(unit.get("Name", "")) == "Percentage":
				# Same verified fixed-point percentage namespace as source.bonus_stats.
				var percent := float(bonus.get("Value", 0)) / 10000.0
				var value_text := String.num(percent, 4)
				if "." in value_text:
					while value_text.ends_with("0"):
						value_text = value_text.trim_suffix("0")
					value_text = value_text.trim_suffix(".")
				return "보너스: %s %s%s%%" % [label, "+" if percent > 0 else "", value_text]
			return "보너스: %s" % label
	var type := _row("RewardType", int(reward.get("RewardTypeID", 0)))
	return "보상: %s" % str(type.get("Name", "정보 확인 필요"))

func _reward_action(label: String, request: Dictionary, reward_id: int) -> Dictionary:
	var action := {"label": label, "request": request}
	var choices := _reward_choices(reward_id)
	if not choices.is_empty():
		action["required_choices"] = choices
	return action

func _reward_choices(reward_id: int, depth: int = 0) -> Array:
	if depth > 12:
		return []
	var reward := _row("Reward", reward_id)
	var result: Array = []
	if int(reward.get("RewardTypeID", 0)) == 111:
		var choice := _row("SelectReward", int(reward.get("RewardClassID", 0)))
		var options: Array = []
		for entity in _rows("SelectRewardEntity"):
			if int(entity.get("SelectRewardID", 0)) == int(reward.get("RewardClassID", 0)):
				var label := _reward_summary(int(entity.get("RewardID", 0)))
				options.append({"label": label, "value": int(entity.get("ID", 0))})
		result.append({"key": "selection.%d" % reward_id, "options": options, "count": int(choice.get("SelectMaxCount", 1)), "min_count": 1, "max_count": int(choice.get("SelectMaxCount", 1))})
	elif int(reward.get("RewardTypeID", 0)) == 124:
		for group in _rows("ComplexReward"):
			if int(group.get("ComplexRewardGroupID", 0)) != int(reward.get("RewardClassID", 0)):
				continue
			var options: Array = []
			for entity in _rows("ComplexRewardEntity"):
				if int(entity.get("ComplexRewardID", 0)) != int(group.get("ID", 0)):
					continue
				if int(group.get("ComplexRewardTypeID", 0)) == 14:
					options.append({"label": _reward_summary(int(entity.get("RewardID", 0))), "value": int(entity.get("ID", 0))})
				else:
					result.append_array(_reward_choices(int(entity.get("RewardID", 0)), depth + 1))
			if not options.is_empty():
				result.append({"key": "selection.%d" % int(group.ID), "options": options, "count": int(group.get("MaxCount", 1)), "min_count": 1, "max_count": int(group.get("MaxCount", 1))})
	return result

func event(event_data: Dictionary, context: Dictionary, state: Dictionary) -> Dictionary:
	# Only the real gameplay host calls this adapter. There is no completion
	# request that can manufacture quest counts.
	var error := validate_state(state)
	if not error.is_empty():
		return _failure(error)
	if int(context.get("now", 0)) < int(state.get("latest_at", 0)):
		return _failure("이전 시각의 패스 진행 이벤트입니다.")
	if not _whole(event_data.get("amount", 1), 1) or not _whole(event_data.get("source_id", 0), 0):
		return _failure("패스 진행 이벤트가 올바르지 않습니다.")
	var next := state.duplicate(true)
	next.latest_at = int(context.get("now", 0))
	if not next.has("quest_progress"):
		next.quest_progress = {}
	for pass_row in _rows("PassSystem"):
		if int(pass_row.get("PassSystemTypeID", 0)) != 12 or not _pass_available(pass_row, context).is_empty():
			continue
		var seen: Dictionary = {}
		for list_id in [int(pass_row.get("PassSystemQuestListID", 0)), int(pass_row.get("PassSystemDailyQuestListID", 0))]:
			for quest_id in _quests.get(str(list_id), []):
				if seen.has(str(quest_id)):
					continue
				seen[str(quest_id)] = true
				var quest := _row("QuestView", int(quest_id))
				if not _pass_quest_eligible(pass_row, quest, context).is_empty():
					continue
				var token := _quest_token(pass_row, quest, context)
				if state.get("quest_claims", {}).has(token):
					continue
				var progress: Dictionary = next.quest_progress.get(token, {}).duplicate(true)
				for link in _quest_links.get(str(quest_id), []):
					var goal := _row("Goal", int(link.get("GoalID", 0)))
					if _goal_event_matches(goal, event_data, context):
						var key := str(int(goal.ID))
						progress[key] = mini(int(goal.get("Amount", 0)), int(progress.get(key, 0)) + int(event_data.get("amount", 1)))
				if not progress.is_empty():
					next.quest_progress[token] = progress
	return _success(next, [], [])

func _pass_quest_eligible(pass_row: Dictionary, quest: Dictionary, context: Dictionary) -> String:
	var error := _pass_available(pass_row, context)
	if not error.is_empty():
		return error
	if int(pass_row.get("PassSystemTypeID", 0)) != 12 or quest.is_empty() or int(quest.get("TypeID", 0)) != 102:
		return "시즌 패스 전용 퀘스트가 아닙니다."
	var quest_id := int(quest.ID)
	var membership := false
	for list_id in [int(pass_row.get("PassSystemQuestListID", 0)), int(pass_row.get("PassSystemDailyQuestListID", 0))]:
		membership = membership or quest_id in _quests.get(str(list_id), [])
	if not membership:
		return "현재 패스의 퀘스트가 아닙니다."
	if not _server_ok(int(quest.get("ServerLimitSetID", 0)), context):
		return "현재 서버의 퀘스트가 아닙니다."
	error = _window(int(quest.get("StartTime", 0)), int(quest.get("EndTime", 0)), context)
	if not error.is_empty():
		return error
	if not _quest_prerequisites.get(str(quest_id), []).is_empty():
		return "추가 선행 조건이 있는 패스 퀘스트입니다."
	if int(quest.get("QuestResetType", 0)) not in [0, 11]:
		return "원문 퀘스트 초기화 규칙을 확인할 수 없습니다."
	var links: Array = _quest_links.get(str(quest_id), [])
	if links.is_empty():
		return "원문 퀘스트 목표가 없습니다."
	for link in links:
		var goal := _row("Goal", int(link.get("GoalID", 0)))
		if int(link.get("GoalPredicateTypeID", 0)) != 1 or int(goal.get("Amount", 0)) <= 0:
			return "추가 원문 목표 조건을 확인할 수 없습니다."
		if int(goal.get("GoalTypeID", 0)) not in [10, 17, 21, 62, 72, 142, 211, 324, 742, 851]:
			return "현재 플레이 범위에 연결되지 않은 패스 목표입니다."
		var class_id := int(goal.get("CharacterClassID", 0))
		if class_id != 0 and class_id != int(context.get("class_id", 0)):
			return "현재 직업의 목표가 아닙니다."
	return ""

func _pass_quest_reason(pass_row: Dictionary, quest: Dictionary, context: Dictionary, state: Dictionary) -> String:
	var error := _pass_quest_eligible(pass_row, quest, context)
	if not error.is_empty():
		return error
	var token := _quest_token(pass_row, quest, context)
	if state.get("quest_claims", {}).has(token):
		return "이미 경험치를 수령했습니다."
	var progress: Dictionary = state.get("quest_progress", {}).get(token, {})
	for link in _quest_links.get(str(int(quest.ID)), []):
		var goal := _row("Goal", int(link.get("GoalID", 0)))
		if int(progress.get(str(int(goal.ID)), 0)) < int(goal.get("Amount", 0)):
			return "실제 플레이 목표를 진행하세요."
	return ""

func _quest_token(pass_row: Dictionary, quest: Dictionary, context: Dictionary) -> String:
	var reset := "season"
	if int(quest.get("QuestResetType", 0)) == 11:
		var date := _row("DateTimes_Korean", int(quest.get("StartTime", 0)))
		var hour := int(context.get("time_policy", {}).get("pass_reset_hour", date.get("Hour", 5)))
		reset = str(int(floor(float(int(context.get("now", 0)) + _offset_minutes(context) * 60 - hour * 3600) / 86400.0)))
	return "%d:%d:%s" % [int(pass_row.get("ID", 0)), int(quest.get("ID", 0)), reset]

func _goal_event_matches(goal: Dictionary, event_data: Dictionary, context: Dictionary) -> bool:
	var kind := str(event_data.get("kind", ""))
	var class_id := int(goal.get("GoalClassID", 0))
	var source_id := int(event_data.get("source_id", 0))
	match int(goal.get("GoalTypeID", 0)):
		62:
			return kind == "kill"
		72:
			if kind != "kill" or source_id <= 0:
				return false
			for link in _npc_groups.get(str(source_id), []):
				if int(link.get("NpcGroupID", 0)) == class_id and _server_ok(int(link.get("ServerLimitSetID", 0)), context):
					return true
		10:
			return kind == "blessing_use"
		17:
			return kind == "enchant_success"
		21:
			return kind == "craft"
		142:
			return kind == "card_compose" and source_id == class_id
		211:
			return kind == "challenge_complete"
		324:
			return kind == "party_dungeon_complete"
		742:
			return kind == "card_buy_adena" and source_id == class_id
		851:
			return kind == "fishing_success"
	return false

func _pass_quest_detail(pass_row: Dictionary, quest: Dictionary, context: Dictionary, state: Dictionary) -> String:
	var token := _quest_token(pass_row, quest, context)
	var progress: Dictionary = state.get("quest_progress", {}).get(token, {})
	var labels: Array[String] = []
	var names: Dictionary = {10: "아인 사용", 17: "장비 강화 성공", 21: "제작", 62: "몬스터 처치", 72: "지정 몬스터군 처치", 142: "카드 합성", 211: "시련 완료", 324: "파티 던전 완료", 742: "아데나 카드 구매", 851: "낚시 성공"}
	for link in _quest_links.get(str(int(quest.get("ID", 0))), []):
		var goal := _row("Goal", int(link.get("GoalID", 0)))
		labels.append("%s %d/%d" % [str(names.get(int(goal.get("GoalTypeID", 0)), "미연결 목표")), int(progress.get(str(int(goal.get("ID", 0))), 0)), int(goal.get("Amount", 0))])
	return " · ".join(labels)

func _append(target: Dictionary, key: String, value: Variant) -> void:
	if not target.has(key):
		target[key] = []
	target[key].append(value)

func _validate_quest_token(token: String) -> String:
	var parts := token.split(":")
	if parts.size() != 3 or not str(parts[0]).is_valid_int() or not str(parts[1]).is_valid_int():
		return "패스 퀘스트 식별자가 손상되었습니다."
	var pass_row := _row("PassSystem", int(parts[0]))
	var quest := _row("QuestView", int(parts[1]))
	if pass_row.is_empty() or quest.is_empty() or int(quest.get("TypeID", 0)) != 102:
		return "원문에 없는 패스 퀘스트 기록입니다."
	var member := false
	for list_id in [int(pass_row.get("PassSystemQuestListID", 0)), int(pass_row.get("PassSystemDailyQuestListID", 0))]:
		member = member or int(quest.ID) in _quests.get(str(list_id), [])
	if not member:
		return "패스와 퀘스트 저장 기록이 일치하지 않습니다."
	if int(quest.get("QuestResetType", 0)) == 11:
		if not str(parts[2]).is_valid_int() or int(parts[2]) < 0:
			return "일일 패스 퀘스트 날짜가 손상되었습니다."
	elif str(parts[2]) != "season":
		return "시즌 패스 퀘스트 기간이 손상되었습니다."
	return ""
