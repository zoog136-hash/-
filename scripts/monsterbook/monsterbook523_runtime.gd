extends RefCounted
## Optional source pack and host-facing integration; no spawn/population mutation.
const Catalog = preload("res://scripts/monsterbook/monsterbook523.gd")
var catalog = Catalog.new()
var host: Node
var save_blocked: bool = false
var action_authority: Callable
var credit_authority: Callable
## Returns the currently confirmed raw Korean source clock (YYYYMMDDHHMM).
## Missing clock means no timed combat effects; machine UTC is never substituted.
var clock_authority: Callable
## settle(before, proposed, raw_quote, persist) -> bool. It must durably commit
## original costs/rewards and proposed ownership together before publishing.
## No default Gem/EXP/item conversion is inferred from static client data.
var settlement: Callable

func configure(world: Node) -> void:
	host = world
	var path: String = ""
	var digest: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--monsterbook523-pack="): path = arg.trim_prefix("--monsterbook523-pack=")
		if arg.begins_with("--monsterbook523-sha256="): digest = arg.trim_prefix("--monsterbook523-sha256=")
	if not path.is_empty() and not catalog.load_pack(path, digest):
		push_warning("몬스터 도감 자료 확인 실패: " + catalog.last_error)

func persist(proposed: Dictionary, overrides: Dictionary = {}) -> bool:
	var staged := overrides.duplicate(true)
	staged["monsterbook523"] = proposed
	return host.call("_save_game", true, staged) == OK

func commit(before: Dictionary, proposed: Dictionary, quote: Dictionary) -> bool:
	var economic: bool = (quote.action == "register" and int(quote.get("level", {}).get("CurrencyCost", 0)) != 0) or (quote.action == "claim" and not quote.get("rewards", []).is_empty())
	if economic:
		return settlement.is_valid() and settlement.call(before, proposed, quote, Callable(self, "persist")) == true
	return persist(proposed)

func apply_confirmed(receipt: Dictionary) -> bool:
	if save_blocked: return false
	return catalog.apply_confirmed(receipt, Callable(self, "commit"))

func action_status(action: String, book_id: int, level_id: int) -> String:
	if save_blocked: return "저장 기록 확인 필요"
	if not catalog.loaded(): return "도감 자료 필요"
	if int(catalog.row("MonsterBook", book_id).get("NpcGroupID", 0)) == 0: return "현재 대상 연결 없음"
	var progress: Dictionary = catalog.progress(book_id)
	if action == "register" and progress.get("registered", []).has(level_id): return "등록 완료"
	if action == "claim" and progress.get("claimed", []).has(level_id): return "보상 수령 완료"
	if not action_authority.is_valid(): return "처치·등록 판정 연결 대기"
	if action == "claim" and not progress.get("registered", []).has(level_id): return "단계 등록 필요"
	if action == "register" and int(progress.get("counts", {}).get(str(level_id), 0)) < int(catalog.row("MonsterBookLevel", level_id).get("Amount", 1)):
		return "필요 처치 수 미달"
	if not settlement.is_valid() and (action == "claim" or int(catalog.row("MonsterBookLevel", level_id).get("CurrencyCost", 0)) != 0):
		return "비용·보상 지급 연결 대기"
	return ""

func request_action(action: String, book_id: int, level_id: int) -> Dictionary:
	if action not in ["register", "claim"]: return {"ok": false, "message": "지원하지 않는 도감 동작입니다."}
	var blocked := action_status(action, book_id, level_id)
	if not blocked.is_empty(): return {"ok": false, "message": blocked}
	var receipt: Variant = action_authority.call(action, book_id, level_id, catalog.export_state())
	if not receipt is Dictionary or receipt.get("action") != action or int(receipt.get("book_id", -1)) != book_id or int(receipt.get("level_id", -1)) != level_id:
		return {"ok": false, "message": "도감 판정을 확인하지 못했습니다."}
	var ok := apply_confirmed(receipt)
	return {"ok": ok, "message": ("등록 완료" if action == "register" else "보상 수령 완료") if ok else "처리 실패 · 이전 기록과 보상을 유지합니다."}

func on_death(monster: Node) -> void:
	if not catalog.loaded() or not credit_authority.is_valid() or bool(monster.get_meta("summoned", false)): return
	# source_m_npc_id is explicit class identity. No name, sprite or map matching.
	var npc_id: int = int(monster.get("source_m_npc_id"))
	if npc_id <= 0 or catalog.target_books(npc_id).is_empty(): return
	var receipt: Variant = credit_authority.call(npc_id, int(monster.get("life_id")), monster.get_instance_id(), catalog.export_state())
	if not receipt is Dictionary or receipt.get("action") != "count" or int(receipt.get("npc_class_id", -1)) != npc_id: return
	apply_confirmed(receipt)

# Only unconditionally applied Unit.Value rows can feed existing flat consumers.
# The authority explicitly selects effective levels; we do not choose cumulative
# vs replacement stages or scale percentage/fixed-point source units.
func flat_bonus(type_name: String) -> int:
	if not catalog.loaded() or not clock_authority.is_valid() or save_blocked: return 0
	if type_name not in ["MeleeDamage", "RangeDamage", "MagicDamage", "MeleeHit", "RangeHit", "MagicHit", "MagicResist", "DamageReduction"]: return 0
	var clock: Variant = clock_authority.call()
	if not clock is String: return 0
	var total: int = 0
	for book: Dictionary in catalog.books():
		for bonus: Dictionary in catalog.effective_bonuses(int(book.ID), clock):
			var type: Dictionary = catalog.row("BonusType", int(bonus.BonusTypeID))
			var unit: Dictionary = catalog.row("Unit", int(type.get("UnitID", 0)))
			if type.get("Name") == type_name and unit.get("Name") == "Value" and int(bonus.BonusApplicationTypeID) == 0 and int(bonus.BonusApplicationTargetID) == 0:
				total += int(bonus.Value)
	return total
