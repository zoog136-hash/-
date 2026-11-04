extends RefCounted

## Read-only source catalogue. Static eligibility never authorizes execution.
const SCHEMA = "twilight.expedition523.v1"
const SOURCE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const P = "MagicDollExpedition"
const MAX_BYTES = 8 * 1024 * 1024
var _tables: Dictionary = {}
var pack_sha256: String = ""
var error: String = "원본 탐험 데이터 팩을 설치하지 않았습니다."

func install(path: String, expected_sha256: String) -> bool:
	# Validate a replacement independently; failure leaves the old catalogue alive.
	if expected_sha256.length() != 64 or not expected_sha256.is_valid_hex_number(false):
		error = "탐험 팩 SHA256이 필요합니다."
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		error = "탐험 팩 파일을 읽을 수 없습니다."
		return false
	var bytes := file.get_buffer(file.get_length())
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	if hash.finish().hex_encode() != expected_sha256.to_lower():
		error = "탐험 팩 SHA256이 다릅니다."
		return false
	var value = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary or value.get("schema") != SCHEMA or value.get("source_sha256") != SOURCE_SHA256:
		error = "누적523 탐험 팩 형식이 아닙니다."
		return false
	var candidate = value.get("tables")
	if not candidate is Dictionary or not _valid_tables(candidate):
		error = "탐험 팩의 표 또는 참조가 손상되었습니다."
		return false
	_tables = candidate.duplicate(true)
	pack_sha256 = expected_sha256.to_lower()
	error = ""
	return true

func _valid_tables(t: Dictionary) -> bool:
	for name in [P+"Spot", P+"SpotAsset", P+"Group", P+"SpotReward", P+"SpotRewardType", P+"CompleteRewardView", P+"SpotEvent", P+"EventView", P+"Bonus", P+"BonusType", P+"Buff", P+"Monster", "BuffCardExpeditionSynergy", "BuffCardExpeditionSynergyCards", "BuffCardExpeditionSynergyBonus", "Grade", "BuffCard", "ConstantData", "Reward", "LuckyBagClass", "LuckyBagEntityView", "ItemClass", "ItemBonus", "Bonus", "BonusType", "Currency", "CurrencyUnitClass"]:
		if not t.get(name) is Array:
			return false
		var ids := {}
		for row in t[name]:
			if not row is Dictionary:
				return false
			if row.has("ID"):
				var key := str(int(row.ID))
				if ids.has(key):
					return false
				ids[key] = true
	if t[P+"Spot"].size() != 29 or t[P+"Group"].size() != 30 or t[P+"SpotReward"].size() != 4487 or t[P+"CompleteRewardView"].size() != 290:
		return false
	var pools := {}
	var completion_pairs := {}
	for row: Dictionary in t[P+"SpotReward"] + t[P+"CompleteRewardView"]:
		var spot := _find(t, P+"Spot", int(row.get(P+"SpotID", -1)))
		var group := _find(t, P+"Group", int(row.get(P+"GroupID", -1)))
		if spot.is_empty() or group.is_empty() or spot.BuffCardDeckID != group.BuffCardDeckID or _find(t, "Reward", int(row.get("RewardID", -1))).is_empty():
			return false
		var pair := "%d:%d" % [int(spot.ID), int(group.ID)]
		if row.has("Probability"):
			if not row.Probability is float and not row.Probability is int:
				return false
			if float(row.Probability) < 0 or float(row.Probability) != floor(float(row.Probability)):
				return false
			pools[pair] = int(pools.get(pair, 0)) + int(row.Probability)
		else:
			if completion_pairs.has(pair) or row.get("GradeID") != group.GradeID or row.get("GroupMinLevel") != group.MinLevel or row.get("GroupMaxLevel") != group.MaxLevel:
				return false
			completion_pairs[pair] = true
	if pools.size() != 284 or completion_pairs.size() != 290:
		return false
	for weight in pools.values():
		if weight != 100000000:
			return false
	return true

func ready() -> bool:
	return not _tables.is_empty()

func rows(name: String) -> Array:
	return _tables.get(name, []).duplicate(true)

func _find(t: Dictionary, name: String, id: int) -> Dictionary:
	for row: Dictionary in t.get(name, []):
		if int(row.get("ID", -1)) == id:
			return row
	return {}

func record(name: String, id: int) -> Dictionary:
	return _find(_tables, name, id).duplicate(true)

func spots(deck: int = 0) -> Array:
	return rows(P+"Spot").filter(func(r: Dictionary) -> bool: return deck == 0 or int(r.BuffCardDeckID) == deck)

func _grade_value(id: int) -> int:
	return int(record("Grade", id).get("GradeValue", -1))

func inspect(spot_id: int, cards: Array = []) -> Dictionary:
	var spot := record(P+"Spot", spot_id)
	if spot.is_empty():
		return {"error": error if not ready() else "탐험 장소가 없습니다.", "can_start": false}
	var reasons: Array[String] = []
	var unknown: Array[String] = ["활성 조건·이벤트 추첨·진행/완료 처리가 미확정입니다."]
	if cards.size() != int(spot.CardCount):
		reasons.append("소유 카드 %d장이 필요합니다." % int(spot.CardCount))
	if int(spot.ServerLimitsetID) != 0:
		unknown.append("서버 제한 %d의 적용 여부가 미확정입니다." % int(spot.ServerLimitsetID))
	var group_id := 0
	var seen := {}
	for selection in cards:
		if not selection is Dictionary:
			reasons.append("카드 선택 형식이 잘못되었습니다.")
			continue
		var card_id := int(selection.get("source_id", 0))
		var card := record("BuffCard", card_id)
		if card.is_empty() or not bool(selection.get("owned", false)):
			reasons.append("소유가 확인된 원본 카드가 필요합니다.")
			continue
		if seen.has(card_id):
			reasons.append("같은 카드를 중복 선택할 수 없습니다.")
		seen[card_id] = true
		if int(card.BuffCardDeckID) != int(spot.BuffCardDeckID):
			reasons.append("카드 계열이 장소와 다릅니다.")
		if _grade_value(int(card.GradeID)) < _grade_value(int(spot.MinGrade)):
			reasons.append("장소의 최소 등급을 충족하지 않습니다.")
		if int(card.ServerLimitSetID) != 0 or int(card.StartDateTimeID) != 0 or int(card.EndDateTimeID) != 0:
			unknown.append("카드의 서버·기간 조건이 미확정입니다.")
		var level := int(selection.get("skill_awaken_level", 0))
		var match_id := 0
		for group: Dictionary in rows(P+"Group"):
			if int(group.BuffCardDeckID) == int(card.BuffCardDeckID) and int(group.GradeID) == int(card.GradeID) and level >= int(group.MinLevel) and level <= int(group.MaxLevel):
				match_id = int(group.ID)
		if match_id == 0:
			reasons.append("해당 원본 등급·스킬각성 레벨의 탐험 그룹이 없습니다.")
		if cards.size() == 1:
			group_id = match_id
	if cards.size() > 1:
		unknown.append("복수 카드의 대표 보상 그룹·시너지 판정 방식이 미확정입니다.")
	var detail := group_detail(spot_id, group_id)
	detail.merge({"spot": spot, "cards": cards.duplicate(true), "static_conditions_met": reasons.is_empty(), "reasons": reasons, "unknown": unknown, "can_start": false, "group_id": group_id}, true)
	return detail

func group_detail(spot_id: int, group_id: int) -> Dictionary:
	# Presence of these display rows is deliberately independent of eligibility.
	var event_rewards: Array = []
	var complete: Array = []
	var events: Array = []
	for row: Dictionary in rows(P+"SpotReward"):
		if int(row[P+"SpotID"]) == spot_id and int(row[P+"GroupID"]) == group_id:
			event_rewards.append(row)
	for row: Dictionary in rows(P+"CompleteRewardView"):
		if int(row[P+"SpotID"]) == spot_id and int(row[P+"GroupID"]) == group_id:
			var reward := record("Reward", int(row.RewardID))
			complete.append({"view": row, "reward": reward, "item": record("ItemClass", int(reward.get("RewardClassID", 0))), "box_candidates": completion_box_candidates(int(reward.get("RewardClassID", 0)))})
	for link: Dictionary in rows(P+"SpotEvent"):
		if int(link[P+"SpotID"]) == spot_id:
			var event := record(P+"EventView", int(link[P+"EventID"]))
			events.append({"link": link, "event": event, "bonus": record(P+"Bonus", int(event.get(P+"BonusID", 0)))})
	return {"event_rewards": event_rewards, "completion": complete, "events": events}

func completion_box_candidates(item_id: int) -> Array:
	var result: Array = []
	for item_bonus: Dictionary in rows("ItemBonus"):
		if int(item_bonus.ItemClassID) != item_id:
			continue
		var bonus := record("Bonus", int(item_bonus.BonusID))
		var kind := record("BonusType", int(bonus.get("BonusTypeID", 0)))
		if kind.get("Name") == "LuckyBagClassID" and int(kind.get("UnitID", 0)) == 29:
			for candidate: Dictionary in rows("LuckyBagEntityView"):
				if int(candidate.LuckyBagClassID) == int(bonus.Value):
					result.append(candidate)
	return result

func synergy_evidence() -> Array:
	var result: Array = []
	for synergy: Dictionary in rows("BuffCardExpeditionSynergy"):
		var members: Array = []
		var effects: Array = []
		for card: Dictionary in rows("BuffCardExpeditionSynergyCards"):
			if int(card.BuffCardDispatchSynergyID) == int(synergy.ID):
				members.append(card)
		for link: Dictionary in rows("BuffCardExpeditionSynergyBonus"):
			if int(link.BuffCardDispatchSynergyID) == int(synergy.ID):
				var bonus := record("Bonus", int(link.BonusID))
				var buff := record(P+"Buff", int(bonus.get("Value", 0)))
				effects.append({"link": link, "bonus": bonus, "buff": buff, "effect": record(P+"Bonus", int(buff.get(P+"BonusID", 0)))})
		result.append({"synergy": synergy, "members": members, "effects": effects})
	return result

func request_start(_spot_id: int, _cards: Array) -> Dictionary:
	# No timer, currency transaction, reward, RNG, or save mutation is authorized
	# by a display table. Keep this gate explicit for future execution contracts.
	return {"ok": false, "reason": "원본 탐험의 활성·진행·추첨·완료 규칙이 미확정입니다."}
