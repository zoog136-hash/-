extends RefCounted
class_name TwilightQuestService

## Quest goals are displayed and tracked, but TWILIGHT's requested playtest
## mode allows immediate one-tap completion upon obtaining a quest.
## This is NOT a claim that NC's official quest rewards/progress are identical.
const VERIFIED_SOURCE_CATALOG: String = "res://data/quests/verified_source_quests.json"
const CATEGORIES = ["main", "daily", "common", "achievement", "other"]
const SOURCE = preload("res://scripts/quests/source_quest523.gd")
var source = SOURCE.new()
var source_context: Dictionary = {}
var unlocked: Dictionary = {}
var ui_requests: Dictionary = {}
var item_grants: Dictionary = {} # Receipts for shared native supplier transactions.
var source_dummy_rewards: Dictionary = {} # Explicit source exclusions, never issued items.
var save_blocked: bool = false
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
	save_blocked = false
	unlocked.clear()
	ui_requests.clear()
	item_grants.clear()
	source_dummy_rewards.clear()
	source = SOURCE.new()
	var item_names: Dictionary = {}
	var monster_names: Dictionary = {}
	for raw: Variant in items:
		if raw is Dictionary:
			item_names[str((raw as Dictionary).get("name", ""))] = true
	for raw: Variant in monsters:
		if raw is Dictionary:
			monster_names[str((raw as Dictionary).get("name", ""))] = true
	# The pre-November local quest catalog is not used (user decision
	# 2026-11-10): quests come from the original 523 quest pack below.
	# Original third-party quest rows MUST first be examined outside the public
	# repo and projected to this explicit schema with proven source identities.
	# Never promote a desktop L1J quest or guessed NPC name to Lineage M truth.
	if FileAccess.file_exists(VERIFIED_SOURCE_CATALOG):
		if not _append_catalog(VERIFIED_SOURCE_CATALOG, true, item_names, monster_names):
			return false
	for local: Dictionary in quests: local["legacy_retired"] = true
	if source.load_pack():
		for native: Dictionary in source.quests:
			quests.append(native)
			index[str(native.id)] = native
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
		# Retired TWILIGHT rows are history labels, not native dependencies.
		# Original-source catalogs keep their own explicit validation path.
		if requires_proof and ((kind == "kill" and target != "*" and target != "@boss" and not monster_names.has(target)) or (kind == "collect" and not item_names.has(target))):
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
			if (requires_proof and not item_names.has(name_value)) or amount < 1 or amount > MAX_REWARD_ITEM:
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
			if index.has(id) and not bool((index[id] as Dictionary).get("legacy_retired",false)) and not str(id).begins_with("m523:") and str((index[id] as Dictionary).get("category", "")) == "daily":
				claimed.erase(id)
		for id: Variant in progress.keys():
			if index.has(id) and not bool((index[id] as Dictionary).get("legacy_retired",false)) and not str(id).begins_with("m523:") and str((index[id] as Dictionary).get("category", "")) == "daily":
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
	return _entries(level,inventory,now)

## The same complete, independent rows as entries(), restricted to a resident
## category before expensive source materialization and reward planning.
## Categories are preserved verbatim, including retired legacy daily rows.
func entries_for_category(level: int, inventory: Dictionary, category: String, now: int = -1) -> Array[Dictionary]:
	return _entries(level,inventory,now,category)

func _entries(level: int, inventory: Dictionary, now: int, category: Variant=null) -> Array[Dictionary]:
	_advance_day(now if now >= 0 else int(Time.get_unix_time_from_system()))
	var result: Array[Dictionary] = []
	# Full scans retain the existing bulk path. A category uses the existing
	# per-record reader without allocating the whole bake; any caller-owned
	# outer bulk buffer remains untouched, including its begin/end lifecycle.
	var bulk: bool = category == null and source != null and source.has_method("begin_bulk")
	if bulk: source.begin_bulk()
	for resident: Dictionary in quests:
		if category!=null and str(resident.get("category",""))!=category:continue
		# Original rows keep only their compact form resident; the complete
		# row is read back from the device record bake (an independent copy,
		# exactly what duplicating the old resident row returned).
		var row: Dictionary = source.detached(resident) if source != null and source.has_method("detached") else resident.duplicate(true)
		var quest: Dictionary = row.duplicate(false) if row.has("source_id") else resident
		var quest_id: String = str(quest["id"])
		row["completed"] = bool(claimed.get(quest_id, false))
		row["available"] = level >= int(quest.get("min_level", 1))
		if quest.has("source_id"):
			var context: Dictionary = source_context.duplicate()
			context["level"] = level
			if row.completed:
				var received: Dictionary = {}
				for receipt: Dictionary in item_grants.get(quest_id,[]): received[str(int(receipt.reward_id))]=true
				for reward_id: String in context.get("held_native_rewards",{}).get(quest_id,{}):received[reward_id]=true
				# Installing a consumer must not relabel old held rewards as
				# received native stacks or silently migrate an old save.
				context["received_native_rewards"]=received
			var gate: String = source.gate(quest,context,claimed,now if now>=0 else int(Time.get_unix_time_from_system()))
			var plan: Dictionary = source.reward_plan(quest,context)
			row["status_reason"] = gate if not gate.is_empty() else str(plan.get("error","완료 · 보상 받기 대기"))
			row["available"] = gate.is_empty() and bool(plan.ok)
			row["rewards"] = plan if plan.ok else {}
		row["progress"] = mini(int((quest["objective"] as Dictionary).get("count", 1)), _progress_value(quest, level, inventory))
		result.append(row)
	if bulk: source.end_bulk()
	return result

## Text-only browser. Page through resident identities, never decode full source
## records or plan rewards merely to display a list. Opening is read-only: no
## daily reset, claim, inventory mutation or save. Acceptance uses the existing
## world transaction, which rechecks eligibility and plans that one quest.
func text_page(level: int, category: String, requested_page: int, page_size: int, query: String = "", state: String = "all", now: int = -1, class_id: int = -1) -> Dictionary:
	var matches: PackedInt32Array = []
	var needle: String = query.strip_edges().to_lower()
	for at: int in quests.size():
		var quest: Dictionary = quests[at]
		var native: bool = quest.has("source_id")
		var completed: bool = bool(claimed.get(str(quest.id),false))
		if not native and (not completed or state!="history"): continue
		if native and state=="history": continue
		var group: String = "common" if not native and quest.get("category")=="daily" else str(quest.get("category",""))
		if group!=category: continue
		if state=="done" and not completed: continue
		if state=="waiting" and completed: continue
		if not needle.is_empty():
			if needle.is_valid_int():
				if int(quest.get("source_id",-1))!=int(needle): continue
			elif not str(quest.get("title","")).to_lower().contains(needle): continue
		matches.append(at)
	var size: int = clampi(page_size,1,60)
	var pages: int = maxi(1,ceili(float(matches.size())/size))
	var page: int = clampi(requested_page,0,pages-1)
	var rows: Array[Dictionary] = []
	var context: Dictionary = source_context.duplicate()
	context["level"] = level
	context["max_level"] = level
	context["class_id"] = class_id
	var at_time: int = now if now>=0 else int(Time.get_unix_time_from_system())
	for index_in_page: int in range(page*size,mini(matches.size(),(page+1)*size)):
		var quest: Dictionary = quests[matches[index_in_page]]
		var completed: bool = bool(claimed.get(str(quest.id),false))
		var reason: String = ""
		if not completed:
			if save_blocked: reason="저장 보호 중"
			elif quest.has("source_id"): reason=source.gate(quest,context,claimed,at_time)
		rows.append({"id":str(quest.id),"source_id":int(quest.get("source_id",0)),"title":str(quest.get("title","")),"completed":completed,"can_accept":not completed and quest.has("source_id") and reason.is_empty(),"status":"완료" if completed else ("수락 가능" if reason.is_empty() else reason)})
	return {"rows":rows,"matches":matches.size(),"page":page,"pages":pages}

## The complete row of an index/quests row (original rows are compact in
## memory; local and injected rows are returned unchanged).
func full(row: Dictionary, cache: bool = true) -> Dictionary:
	return source.full(row, cache) if source != null and source.has_method("full") else row

## index.get(quest_id, {}) with the original row materialized.
func full_quest(quest_id: String) -> Dictionary:
	return full(index.get(quest_id, {}))

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
	if quest.has("source_id"):
		return {"ok":false,"error":"원본 퀘스트는 자동 저장 트랜잭션으로 처리합니다"}
	if save_blocked: return {"ok":false,"error":"퀘스트 저장 보호 중"}
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

static func validate_saved_state(saved: Variant) -> String:
	if not saved is Dictionary: return "퀘스트 저장 형식 오류"
	if int(saved.get("schema_version",1)) not in [1,2]: return "지원하지 않는 퀘스트 저장 버전"
	for key: String in ["claimed","progress","unlocked"]:
		var values: Variant = saved.get(key,{})
		if not values is Dictionary or values.size()>20000: return "퀘스트 저장 목록 오류"
		for id: Variant in values:
			if not id is String or id.length()>200: return "퀘스트 저장 ID 오류"
			if key == "progress":
				if not (values[id] is int or values[id] is float) or not is_finite(float(values[id])) or float(values[id])!=floorf(float(values[id])) or float(values[id])<0 or float(values[id])>1000000: return "퀘스트 진행도 오류"
			elif not values[id] is bool: return "퀘스트 완료/획득 상태 오류"
	var day: Variant = saved.get("day_key",0)
	if not (day is int or day is float) or not is_finite(float(day)) or float(day)!=floorf(float(day)) or float(day)<-1 or float(day)>10000000: return "퀘스트 날짜 오류"
	var grants: Variant = saved.get("item_grants",{})
	if not grants is Dictionary or grants.size()>20000: return "원본 아이템 지급 영수증 목록 오류"
	for id: Variant in grants:
		if not id is String or not id.begins_with("m523:quest:") or saved.get("claimed",{}).get(id)!=true or not grants[id] is Array or grants[id].size()>128: return "원본 아이템 지급 영수증 관계 오류"
		var seen: Dictionary = {}
		for receipt: Variant in grants[id]:
			if not receipt is Dictionary or receipt.get("schema")!=1 or not receipt.get("inventory_key") is String or str(receipt.inventory_key).is_empty(): return "원본 아이템 지급 영수증 형식 오류"
			var digest: Variant = receipt.get("pack_sha256")
			if not digest is String or digest.length()!=64 or not digest.is_valid_hex_number(false): return "원본 아이템 소비 팩 영수증 오류"
			for key: String in ["reward_id","item_class_id","quantity","bless_raw"]:
				var value: Variant = receipt.get(key)
				if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)) or value<1 or value>9007199254740991: return "원본 아이템 지급 영수증 값 오류"
			if int(receipt.bless_raw) not in [1,2,3] or seen.has(int(receipt.reward_id)): return "원본 아이템 축복/중복 영수증 오류"
			if receipt.has("origin"):
				if receipt.origin!="held_use" or receipt.get("source_sha256")!=SOURCE.SOURCE_SHA or not str(receipt.inventory_key).begins_with("[원본 보상] "):return "원본 보관 사용 영수증 출처 오류"
				var used: Variant=receipt.get("used_quantity")
				if not (used is int or used is float) or not is_finite(float(used)) or float(used)!=floorf(float(used)) or used<1 or used>receipt.quantity:return "원본 보관 사용 수량 오류"
			seen[int(receipt.reward_id)]=true
	var dummy_rewards: Variant=saved.get("source_dummy_rewards",{})
	if not dummy_rewards is Dictionary or dummy_rewards.size()>20000:return "원본 더미 보상 제외 기록 형식 오류"
	for id: Variant in dummy_rewards:
		if not id is String or not id.begins_with("m523:quest:") or saved.get("claimed",{}).get(id)!=true or not dummy_rewards[id] is Array or dummy_rewards[id].size()>128:return "원본 더미 보상 제외 관계 오류"
		var excluded_ids: Dictionary={}
		for entry: Variant in dummy_rewards[id]:
			if not entry is Dictionary:return "원본 더미 제외 보상 형식 오류"
			for field: String in ["reward_id","item_class_id"]:
				var value: Variant=entry.get(field)
				if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)) or value<1 or value>9007199254740991:return "원본 더미 제외 보상 ID 오류"
			if excluded_ids.has(int(entry.reward_id)):return "원본 더미 제외 보상 중복 오류"
			excluded_ids[int(entry.reward_id)]=true
			var expected: Dictionary=preload("res://scripts/quests/source_dummy523.gd").item_id_evidence(int(entry.get("item_class_id",0)))
			if expected.is_empty() or JSON.parse_string(JSON.stringify(expected))!=JSON.parse_string(JSON.stringify(entry.get("evidence"))):return "원본 더미 선언 근거 불일치 · 제외 기록 보존"
	var requests: Variant = saved.get("ui_requests",{})
	if not requests is Dictionary or requests.size()>20000: return "퀘스트 UI 기록 오류"
	for id: Variant in requests:
		if not id is String or not requests[id] is Array or requests[id].size()>128: return "퀘스트 UI 목록 오류"
		for entry: Variant in requests[id]:
			if not entry is Dictionary: return "퀘스트 UI 항목 오류"
			for key: String in ["reward_id","class_id","raw_amount"]:
				var number: Variant = entry.get(key)
				if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floorf(float(number)) or float(number)<0 or float(number)>9007199254740991: return "퀘스트 UI 값 오류"
	return ""

func export_state() -> Dictionary:
	_advance_day(int(Time.get_unix_time_from_system()))
	var result: Dictionary = {"schema_version":2, "claimed":claimed.duplicate(true), "progress":progress.duplicate(true), "day_key":day_key,"unlocked":unlocked.duplicate(true),"ui_requests":ui_requests.duplicate(true)}
	if not item_grants.is_empty(): result["item_grants"]=item_grants.duplicate(true)
	if not source_dummy_rewards.is_empty():result["source_dummy_rewards"]=source_dummy_rewards.duplicate(true)
	return result

func import_state(saved: Variant, now: int = -1) -> bool:
	var error: String = validate_saved_state(saved)
	if not error.is_empty():
		problem = error
		save_blocked = true
		return false
	claimed.clear()
	progress.clear()
	unlocked.clear()
	ui_requests = saved.get("ui_requests",{}).duplicate(true)
	item_grants = saved.get("item_grants",{}).duplicate(true)
	source_dummy_rewards=saved.get("source_dummy_rewards",{}).duplicate(true)
	save_blocked = false
	var at: int = now if now >= 0 else int(Time.get_unix_time_from_system())
	day_key = korean_daily_key(at)
	for id: String in saved.get("claimed",{}):
		if bool(saved.claimed[id]) and (index.has(id) or id.begins_with("m523:quest:") or id.begins_with("twilight:")): claimed[id] = true
	for id: String in saved.get("progress",{}):
		if index.has(id) or id.begins_with("m523:quest:") or id.begins_with("twilight:"): progress[id] = int(saved.progress[id])
	for id: String in saved.get("unlocked",{}):
		if bool(saved.unlocked[id]): unlocked[id] = true
	# Retain the saved high-water date even if the device clock moved backwards.
	day_key = maxi(0,int(saved.get("day_key",day_key)))
	_advance_day(at)
	return true
