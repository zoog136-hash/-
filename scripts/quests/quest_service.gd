extends RefCounted
class_name TwilightQuestService

## Quest goals are displayed and tracked, but TWILIGHT's requested playtest
## mode allows immediate one-tap completion upon obtaining a quest.
## This is NOT a claim that NC's official quest rewards/progress are identical.
const LOCAL_CATALOG: String = "res://data/quests/twilight_quest_catalog.json"
const VERIFIED_SOURCE_CATALOG: String = "res://data/quests/verified_source_quests.json"
const CATEGORIES = ["main", "daily", "achievement"]
const OBJECTIVES = ["kill", "collect", "level"]
const MAX_REWARD_ITEM: int = 10000

var quests: Array[Dictionary] = []
var index: Dictionary = {}
var claimed: Dictionary = {}
var progress: Dictionary = {}
var day_key: int = -1
var problem: String = ""

static func korean_daily_key(unix_time: int) -> int:
	# 05:00 Korea time = 20:00 UTC of the preceding day.
	# A fixed UTC offset is intentional for TWILIGHT's Korean playtest rules.
	return floori(float(unix_time + 4 * 3600) / 86400.0)

func configure(items: Array, monsters: Array) -> bool:
	quests.clear()
	index.clear()
	claimed.clear()
	progress.clear()
	day_key = -1
	problem = ""
	var item_names: Dictionary = {}
	var monster_names: Dictionary = {}
	for raw: Variant in items:
		if raw is Dictionary:
			item_names[str((raw as Dictionary).get("name", ""))] = true
	for raw: Variant in monsters:
		if raw is Dictionary:
			monster_names[str((raw as Dictionary).get("name", ""))] = true
	if not _append_catalog(LOCAL_CATALOG, false, item_names, monster_names):
		return false
	# Original third-party quest rows MUST first be examined outside the public
	# repo and projected to this explicit schema with proven source identities.
	# Never promote a desktop L1J quest or guessed NPC name to Lineage M truth.
	if FileAccess.file_exists(VERIFIED_SOURCE_CATALOG):
		if not _append_catalog(VERIFIED_SOURCE_CATALOG, true, item_names, monster_names):
			return false
	_advance_day(int(Time.get_unix_time_from_system()))
	return not quests.is_empty()

func _append_catalog(path: String, requires_proof: bool, item_names: Dictionary, monster_names: Dictionary) -> bool:
	if not FileAccess.file_exists(path):
		problem = "Missing quest catalog: " + path
		return false
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (raw is Dictionary):
		problem = "Invalid quest catalog JSON: " + path
		return false
	var catalog: Dictionary = raw as Dictionary
	if int(catalog.get("schema_version", 0)) != 1 or not (catalog.get("quests", null) is Array):
		problem = "Unsupported quest schema: " + path
		return false
	if requires_proof:
		var source_digest: String = str(catalog.get("source_sha256", ""))
		if str(catalog.get("provenance", "")) != "verified_original_quest_projection" or source_digest.length() != 64 or not source_digest.is_valid_hex_number(false):
			problem = "Unverified quest-source provenance"
			return false
	for raw_quest: Variant in catalog["quests"]:
		if not (raw_quest is Dictionary):
			problem = "Quest entry must be a dictionary"
			return false
		var quest: Dictionary = (raw_quest as Dictionary).duplicate(true)
		var quest_id: String = str(quest.get("id", ""))
		var title: String = str(quest.get("title", "")).strip_edges()
		var category: String = str(quest.get("category", ""))
		var objective_value: Variant = quest.get("objective", {})
		var rewards_value: Variant = quest.get("rewards", {})
		if quest_id.is_empty() or title.is_empty() or index.has(quest_id) or not CATEGORIES.has(category):
			problem = "Invalid or duplicate quest ID/category: " + quest_id
			return false
		if not (objective_value is Dictionary) or not (rewards_value is Dictionary):
			problem = "Invalid objective or rewards: " + quest_id
			return false
		var goal: Dictionary = objective_value as Dictionary
		var rewards: Dictionary = rewards_value as Dictionary
		var kind: String = str(goal.get("kind", ""))
		var target: String = str(goal.get("target", ""))
		var required: int = int(goal.get("count", 0))
		if not OBJECTIVES.has(kind) or required < 1 or required > 1000000 or int(quest.get("min_level", 1)) < 1:
			problem = "Invalid quest objective: " + quest_id
			return false
		if (kind == "kill" and target != "*" and target != "@boss" and not monster_names.has(target)) or (kind == "collect" and not item_names.has(target)):
			problem = "Unmapped monster/item quest target: " + quest_id
			return false
		var adena: int = int(rewards.get("adena", 0))
		var exp_points: int = int(rewards.get("exp", 0))
		var reward_items: Variant = rewards.get("items", [])
		if adena < 0 or exp_points < 0 or adena > 1000000000 or exp_points > 1000000000 or not (reward_items is Array):
			problem = "Invalid quest rewards: " + quest_id
			return false
		for raw_reward: Variant in reward_items:
			if not (raw_reward is Dictionary):
				problem = "Invalid quest reward row: " + quest_id
				return false
			var reward: Dictionary = raw_reward as Dictionary
			var name_value: String = str(reward.get("name", ""))
			var amount: int = int(reward.get("quantity", 0))
			if not item_names.has(name_value) or amount < 1 or amount > MAX_REWARD_ITEM:
				problem = "Unmapped/invalid reward item: " + quest_id
				return false
		quest["instant_complete"] = true
		quest["provenance"] = "source_verified" if requires_proof else "twilight_local_adaptation"
		quests.append(quest)
		index[quest_id] = quest
	return true

func _advance_day(now: int) -> void:
	var today: int = korean_daily_key(now)
	if day_key < 0:
		day_key = today
	elif today > day_key:
		for id: Variant in claimed.keys():
			if index.has(id) and str((index[id] as Dictionary).get("category", "")) == "daily":
				claimed.erase(id)
		for id: Variant in progress.keys():
			if index.has(id) and str((index[id] as Dictionary).get("category", "")) == "daily":
				progress.erase(id)
		day_key = today
	# Never grant a second daily reset by moving the device clock backwards.

func _progress_value(quest: Dictionary, level: int, inventory: Dictionary) -> int:
	var objective: Dictionary = quest["objective"] as Dictionary
	var quest_id: String = str(quest["id"])
	var kind: String = str(objective["kind"])
	if kind == "level":
		return level
	if kind == "collect":
		return maxi(int(progress.get(quest_id, 0)), int(inventory.get(str(objective.get("target", "")), 0)))
	return int(progress.get(quest_id, 0))

func entries(level: int, inventory: Dictionary, now: int = -1) -> Array[Dictionary]:
	_advance_day(now if now >= 0 else int(Time.get_unix_time_from_system()))
	var result: Array[Dictionary] = []
	for quest: Dictionary in quests:
		var row: Dictionary = quest.duplicate(true)
		var quest_id: String = str(quest["id"])
		row["completed"] = bool(claimed.get(quest_id, false))
		row["available"] = level >= int(quest.get("min_level", 1))
		row["progress"] = mini(int((quest["objective"] as Dictionary).get("count", 1)), _progress_value(quest, level, inventory))
		result.append(row)
	return result

func record_kill(monster_name: String, is_boss: bool) -> void:
	for quest: Dictionary in quests:
		var id: String = str(quest["id"])
		if claimed.has(id):
			continue
		var objective: Dictionary = quest["objective"]
		if str(objective.get("kind", "")) != "kill":
			continue
		var target: String = str(objective.get("target", ""))
		if target != "*" and target != monster_name and not (target == "@boss" and is_boss):
			continue
		progress[id] = mini(int(objective.get("count", 1)), int(progress.get(id, 0)) + 1)

func record_pickup(item_name: String, quantity: int) -> void:
	if quantity <= 0:
		return
	for quest: Dictionary in quests:
		var id: String = str(quest["id"])
		if claimed.has(id):
			continue
		var objective: Dictionary = quest["objective"]
		if str(objective.get("kind", "")) == "collect" and str(objective.get("target", "")) == item_name:
			progress[id] = mini(int(objective.get("count", 1)), int(progress.get(id, 0)) + quantity)

func complete_instantly(quest_id: String, level: int, now: int = -1) -> Dictionary:
	_advance_day(now if now >= 0 else int(Time.get_unix_time_from_system()))
	var quest: Dictionary = index.get(quest_id, {})
	if quest.is_empty():
		return {"ok":false, "error":"퀘스트가 없습니다"}
	if claimed.has(quest_id):
		return {"ok":false, "error":"이미 완료한 퀘스트입니다"}
	if level < int(quest.get("min_level", 1)):
		return {"ok":false, "error":"퀘스트 수령 레벨이 부족합니다"}
	# Requested TWILIGHT one-tap convenience. No monster/item farming, NPC
	# return trip, objective completion or quest-item consumption required.
	claimed[quest_id] = true
	return {"ok":true, "title":str(quest["title"]), "rewards":(quest["rewards"] as Dictionary).duplicate(true)}

func export_state() -> Dictionary:
	_advance_day(int(Time.get_unix_time_from_system()))
	return {"schema_version":1, "claimed":claimed.duplicate(true), "progress":progress.duplicate(true), "day_key":day_key}

func import_state(saved: Variant, now: int = -1) -> void:
	claimed.clear()
	progress.clear()
	var at: int = now if now >= 0 else int(Time.get_unix_time_from_system())
	day_key = korean_daily_key(at)
	if saved is Dictionary:
		var data: Dictionary = saved as Dictionary
		if int(data.get("schema_version", 1)) == 1:
			var saved_claimed: Variant = data.get("claimed", {})
			var saved_progress: Variant = data.get("progress", {})
			if saved_claimed is Dictionary:
				for id: Variant in saved_claimed:
					if index.has(id) and bool(saved_claimed[id]):
						claimed[id] = true
			if saved_progress is Dictionary:
				for id: Variant in saved_progress:
					if index.has(id):
						var required: int = int(((index[id] as Dictionary).get("objective", {}) as Dictionary).get("count", 1))
						progress[id] = clampi(int(saved_progress[id]), 0, required)
			day_key = clampi(int(data.get("day_key", day_key)), 0, korean_daily_key(at))
	_advance_day(at)
