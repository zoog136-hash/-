extends RefCounted
## Wallet quotes and the existing save boundary for caller-owned map movement.
## The caller validates the route/ownership, keeps its rollback field alive,
## moves its candidate, and adopts prepared overrides only after saved == true.

const CURRENCY_ID: int = 1
const MAX_AMOUNT: int = 100000000
## Configurable OWN estimate for ordinary manual Portals with no held fee row.
## This is not a native Portal tariff or inherited LandTeleport declaration.
const OWN_MANUAL_PORTAL_ADENA_V1: int = 100000
const WALLET_POLICY: String = "OWN_WALLET_ADENA_DEBIT_V1"
const FREE_POLICY: String = "OWN_TRAVEL_FREE_V1"
const _OVERRIDE_KEYS: Array[String] = ["gold", "inventory", "item_instances", "quest_state"]
const _SAVE_GUARDS: Dictionary = {
	"quest_service": "save_blocked",
	"equipment_collections": "save_blocked",
	"death_recovery": "save_blocked",
	"fishing523": "blocked",
	"dungeon_play": "save_blocked",
	"source_dungeon_runs": "save_blocked",
	"titles": "blocked",
	"totem_combat": "settings_blocked",
	"totems": "save_blocked",
	"monsterbook523_runtime": "save_blocked",
	"protection523": "save_blocked",
	"source_shop": "save_blocked",
	"expedition_local": "save_blocked",
	"halphas_star": "save_blocked",
	"growth96": "save_blocked",
	"combinations": "save_blocked",
	"half_elixir": "save_blocked",
	"spell_group_conversion": "save_blocked",
	"skill_awakening": "save_blocked",
	"option_awakening": "save_blocked"
}

static func quote(world: Node, amount: Variant) -> Dictionary:
	var protection: Dictionary = _save_protection(world)
	if not protection.is_empty(): return protection
	if not amount is int or amount < 0 or amount > MAX_AMOUNT:
		return _failure("이동 비용은 0~100000000의 정수여야 합니다", ERR_INVALID_PARAMETER)
	var old: Variant = world.get("gold")
	if not old is int or old < 0:
		return _failure("현재 아데나 정수 상태 확인 필요", ERR_INVALID_DATA)
	if amount > old:
		return _failure("이동 비용 아데나가 부족합니다", ERR_UNAVAILABLE)
	return {
		"ok": true,
		"currency_id": CURRENCY_ID,
		"amount": amount,
		"changes": {} if amount == 0 else {"gold": old - amount},
		"prior_gold": old,
		"policy": FREE_POLICY if amount == 0 else WALLET_POLICY,
		"free": amount == 0
	}

static func commit(world: Node, changes: Dictionary) -> Dictionary:
	var protection: Dictionary = _save_protection(world)
	if not protection.is_empty(): return protection
	var old: Variant = world.get("gold")
	if not old is int or old < 0:
		return _failure("현재 아데나 정수 상태 확인 필요", ERR_INVALID_DATA)
	# Route pricing and exact return239 debit/receipt validation belong to their
	# existing callers. Restrict the prepared payload without re-owning either.
	for key: Variant in changes:
		if not key is String or key not in _OVERRIDE_KEYS:
			return _failure("허용되지 않은 이동 저장 변경", ERR_INVALID_PARAMETER)
		if key == "gold":
			if not changes[key] is int or changes[key] < 0:
				return _failure("저장할 아데나 정수 상태 확인 필요", ERR_INVALID_DATA)
		elif not changes[key] is Dictionary:
			return _failure("준비된 이동 소지·퀘스트 저장 형식 확인 필요", ERR_INVALID_DATA)
	var path_value: Variant = world.call("save_path")
	if not path_value is String or path_value.is_empty():
		return _failure("이동 저장 경로 확인 필요", ERR_FILE_BAD_PATH)
	var path: String = path_value
	var before: Dictionary = _fingerprint(path)
	if not before.ok:
		return _failure("기존 저장 파일 확인 실패 · 이동 저장 중지", ERR_FILE_CANT_READ)
	var prepared: Dictionary = changes.duplicate(true)
	# No direct writer, host spatial override, journal or live debit is added.
	var save_result: Variant = world.call("_save_game", true, prepared)
	var save_error: int = ERR_BUG
	if save_result is int: save_error = save_result
	if save_error == OK:
		# Bind this real save call's committed bytes and exact prepared payload.
		# A caller-generated string alone is never evidence of persistence.
		var committed: Dictionary = _fingerprint(path)
		if not committed.ok or not committed.exists or committed.sha256.is_empty():
			return _uncertain_result(world, save_error)
		return {"ok": true, "saved": true, "uncertain": false, "save_error": OK, "rollback_allowed": false,
			"save_fingerprint": committed, "save_path_sha256": path.sha256_text(),
			"prepared_changes_sha256": JSON.stringify(prepared,"",true,true).sha256_text()}
	var after: Dictionary = _fingerprint(path)
	var unchanged: bool = after.ok and before.exists == after.exists and before.sha256 == after.sha256
	if unchanged:
		return _failure("이동 저장 실패 · 이전 위치와 소지 상태를 복원합니다", save_error)
	return _uncertain_result(world, save_error)

static func _uncertain_result(world: Node, save_error: int) -> Dictionary:
	# A changed/unreadable file, including missing evidence after an OK return,
	# cannot authorize a refund or adoption. Retain the existing reload hold.
	var quest_owner: Object = _property(world, "quest_service")
	quest_owner.set("save_blocked", true)
	var reason: String = "이동 저장 결과 미확정 · 재시도 중지, 정상 저장 불러오기 필요"
	return {
		"ok": false,
		"saved": false,
		"uncertain": true,
		"save_error": save_error,
		"rollback_allowed": false,
		"retry_allowed": false,
		"reload_required": true,
		"reason": reason,
		"message": reason
	}

static func _fingerprint(path: String) -> Dictionary:
	var exists: bool = FileAccess.file_exists(path)
	var sha: String = FileAccess.get_sha256(path) if exists else ""
	return {"ok": not exists or not sha.is_empty(), "exists": exists, "sha256": sha}

static func _save_protection(world: Node) -> Dictionary:
	if world == null or not is_instance_valid(world) or not world.has_method("_save_game") or not world.has_method("save_path"):
		return _failure("기존 이동 저장 소유자 연결 확인 필요", ERR_UNAVAILABLE)
	var quest_owner: Variant = _property(world, "quest_service")
	if not quest_owner is Object or not is_instance_valid(quest_owner) or not _property(quest_owner, "save_blocked") is bool:
		return _failure("기존 퀘스트 저장 보호 연결 확인 필요", ERR_UNAVAILABLE)
	var blocked: bool = false
	for key: String in ["source_save_blocked", "source_item_save_blocked"]:
		if _property(world, key) == true: blocked = true
	for key: String in ["patch523_owner_state_problem", "migration_pointer_error"]:
		var problem: Variant = _property(world, key)
		if problem is String and not problem.is_empty(): blocked = true
	for owner_name: String in _SAVE_GUARDS:
		var owner: Variant = _property(world, owner_name)
		if owner is Object and is_instance_valid(owner) and _property(owner, str(_SAVE_GUARDS[owner_name])) == true:
			blocked = true
	var coupons: Variant = _property(world, "tj_coupons")
	if coupons is Object and is_instance_valid(coupons):
		var core: Variant = _property(coupons, "core")
		if core is Object and is_instance_valid(core) and _property(core, "blocked") == true: blocked = true
	if blocked:
		var result: Dictionary = _failure("저장 보호 중 · 정상 저장 불러오기 필요", ERR_UNAVAILABLE)
		result["reload_required"] = true
		result["retry_allowed"] = false
		return result
	return {}

static func _property(target: Object, property_name: String, fallback: Variant = null) -> Variant:
	if target == null or not is_instance_valid(target): return fallback
	for entry: Dictionary in target.get_property_list():
		if str(entry.get("name", "")) == property_name:
			return target.get(property_name)
	return fallback

static func _failure(reason: String, save_error: int) -> Dictionary:
	return {
		"ok": false,
		"saved": false,
		"uncertain": false,
		"save_error": save_error,
		"rollback_allowed": true,
		"reason": reason,
		"message": reason
	}
