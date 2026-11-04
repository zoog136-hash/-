extends RefCounted
## Optional source pack and host-facing integration; no spawn/population mutation.
const Catalog = preload("res://scripts/monsterbook/monsterbook523.gd")
var catalog = Catalog.new()
var host: Node
var local = preload("res://scripts/monsterbook/monsterbook523_local.gd").new()
var items = preload("res://scripts/monsterbook/monsterbook523_items.gd").new()
var economy = preload("res://scripts/monsterbook/monsterbook523_economy.gd").new()
var pending_deaths: Array = []
var next_retry_ms: int = 0
var next_effect_check_ms: int = 0
var last_effect_hash: int = 0
var save_blocked: bool = false
var action_authority: Callable
var credit_authority: Callable
## Current Korean source clock (YYYYMMDDHHMM), using the existing game calendar
## by default; external confirmed server adapters may replace this callable.
var clock_authority: Callable
## settle(before, proposed, raw_quote, persist) -> bool. It must durably commit
## original costs/rewards and proposed ownership together before publishing.
## The default adapter keeps exact source costs/items and labels custom EXP rates.
var settlement: Callable

func configure(world: Node) -> void:
	host = world
	local.configure(self,world)
	items.configure(self,world)
	economy.configure(self,world)
	action_authority = Callable(local,"action_receipt")
	credit_authority = Callable(local,"credit")
	clock_authority = Callable(local,"source_clock")
	settlement = Callable(items,"settle")
	catalog.changed.connect(_catalog_changed)
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
	var economic: bool = (quote.action == "register" and int(quote.get("level", {}).get("CurrencyCost", 0)) != 0) or (quote.action in ["claim", "claim_rewards"] and not quote.get("rewards", []).is_empty())
	if economic:
		return settlement.is_valid() and settlement.call(before, proposed, quote, Callable(self, "persist")) == true
	return persist(proposed)

func apply_confirmed(receipt: Dictionary) -> bool:
	if save_blocked: return false
	var checked := receipt.duplicate(true)
	if checked.get("action") == "claim_rewards" and settlement == Callable(items,"settle"):
		var records: Dictionary = {}
		var conversions: Dictionary = {}
		for id: Variant in checked.get("reward_ids",[]):
			var reward: Dictionary = catalog.row("Reward",int(id))
			if not items.reward_problem(reward).is_empty(): return false
			if int(reward.RewardTypeID) != 2:
				conversions[str(int(reward.ID))] = {"source_amount":int(reward.Amount),"local_exp":economy.experience_amount(reward),"provenance":"twilight_custom_holy_water_ratio_v1","numerator":int(economy.BALANCE.data.exp_numerator),"denominator":int(economy.BALANCE.data.exp_denominator)}
				continue
			var record: Dictionary = items.definition(reward)
			records[record.name] = record
		checked["source_item_records"] = records
		checked["reward_conversions"] = conversions
	var applied: bool = catalog.apply_confirmed(checked, Callable(self, "commit"))
	if applied and checked.get("action") == "claim_rewards": host.call("_refresh_inventory_hud")
	return applied

func action_status(action: String, book_id: int, level_id: int) -> String:
	if save_blocked: return "저장 기록 확인 필요"
	if not catalog.loaded(): return "도감 자료 필요"
	if action_authority == Callable(local,"action_receipt"): return local.status(action,book_id,level_id)
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
	if action not in ["register", "claim", "instant", "effects"]: return {"ok": false, "message": "지원하지 않는 도감 동작입니다."}
	var blocked := action_status(action, book_id, level_id)
	if not blocked.is_empty(): return {"ok": false, "message": blocked}
	var receipt: Variant = action_authority.call(action, book_id, level_id, catalog.export_state())
	var allowed: Array = ["effects"] if action == "effects" else (["instant_complete"] if action == "instant" else (["register","achieve"] if action == "register" else ["claim","claim_rewards"]))
	if not receipt is Dictionary or receipt.get("action") not in allowed or int(receipt.get("book_id", -1)) != book_id or int(receipt.get("level_id", -1)) != level_id:
		return {"ok": false, "message": "도감 판정을 확인하지 못했습니다."}
	var ok := apply_confirmed(receipt)
	if action == "effects": return {"ok":ok,"message":"지원 옵션 적용 완료 · 한 단계 선택 방식" if ok else "옵션 적용 실패 · 이전 상태 유지"}
	return {"ok": ok, "message": ("즉시 완료 · 원본 다이아 비용 차감" if action == "instant" else ("등록 완료" if action == "register" else ("보상 수령 완료" if catalog.progress(book_id).get("claimed",[]).has(level_id) else "보상 일부 수령 완료 · 남은 보상은 별도 표시"))) if ok else "처리 실패 · 이전 기록과 보상을 유지합니다."}

func on_death(monster: Node) -> void:
	if not catalog.loaded() or not credit_authority.is_valid() or bool(monster.get_meta("summoned", false)): return
	# source_m_npc_id is explicit class identity. No name, sprite or map matching.
	var npc_id: int = int(monster.get("source_m_npc_id"))
	if npc_id <= 0 or catalog.target_books(npc_id).is_empty(): return
	var receipt: Variant = credit_authority.call(npc_id, int(monster.get("life_id")), monster.get_instance_id(), catalog.export_state())
	if not receipt is Dictionary or receipt.get("action") != "count" or int(receipt.get("npc_class_id", -1)) != npc_id: return
	if credit_authority != Callable(local,"credit"):
		apply_confirmed(receipt)
		return
	var key: String = str(receipt.get("local_life_key",""))
	if key.is_empty() or local.credited_lives.has(key): return
	local.credited_lives[key] = true
	pending_deaths.append(receipt.duplicate(true))
	retry_pending(true)

func retry_pending(force: bool = false) -> void:
	if pending_deaths.is_empty() or save_blocked: return
	if not force and Time.get_ticks_msec() < next_retry_ms: return
	next_retry_ms = Time.get_ticks_msec() + 1000
	while not pending_deaths.is_empty():
		var receipt: Dictionary = pending_deaths[0].duplicate(true)
		var saved: Dictionary = catalog.export_state().books.get(str(int(receipt.book_id)),{})
		receipt.sequence = int(saved.get("sequence",0))+1
		receipt.start_epoch = saved.get("current_epoch","") != receipt.epoch
		if not apply_confirmed(receipt): return
		pending_deaths.pop_front()

func reset_pending() -> void:
	pending_deaths.clear()
	local.credited_lives.clear()

func _catalog_changed() -> void:
	items.install(catalog.export_state().get("source_items",{}))
	_refresh_effect_fingerprint()

# Only unconditionally applied Unit.Value rows can feed existing flat consumers.
# The authority explicitly selects effective levels; we do not choose cumulative
# vs replacement stages. The default UI selects one stage explicitly.
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

func tick() -> void:
	retry_pending()
	if not catalog.loaded() or Time.get_ticks_msec() < next_effect_check_ms: return
	next_effect_check_ms = Time.get_ticks_msec() + 1000
	_refresh_effect_fingerprint()

func _refresh_effect_fingerprint() -> void:
	if not clock_authority.is_valid() or not catalog.loaded(): return
	var clock: Variant = clock_authority.call()
	if not clock is String: return
	var effects: Array = []
	for book: Dictionary in catalog.books():
		for bonus: Dictionary in catalog.effective_bonuses(int(book.ID),clock): effects.append(int(bonus.ID))
	var fingerprint: int = hash(effects)
	if fingerprint != last_effect_hash:
		last_effect_hash = fingerprint
		if is_instance_valid(host):
			host.call("_invalidate_equipment_static")
			host.set("stat_hud_refresh_pending",true)

# Typed consumers already used by native doll options and existing world stats.
# Percentage/Weight scaling comes from exact source UIUnit.Denominator, not guesswork.
const EXTRA_MAP := {"ArmorClass":"def","CarryPlus":"weightBonus","MeleeCritical":"meleeCrit","RangeCritical":"rangedCrit","MagicCritical":"magicCrit","AttackSpeedBonus":"attackSpeed","MoveSpeedBonus":"moveSpeedPct","ExperienceAdditionPercent":"xpPct","RangeEvasion":"er","CriticalMeleeDamage":"melee_critical_damage","CriticalRangeDamage":"ranged_critical_damage","CriticalMagicDamage":"magic_critical_damage","PVEDamageReduction":"pve_damage_reduction","PVEDamageReductionPercent":"pve_damage_reduction_pct","DamageReductionPercent":"damage_reduction_pct","RegenMP":"mp_regeneration","PierceMeleeEvasion":"melee_evasion_ignore","PierceRangeEvasion":"ranged_evasion_ignore"}

func bonus_status(bonus: Dictionary) -> String:
	var type: Dictionary = catalog.row("BonusType",int(bonus.BonusTypeID))
	if int(bonus.BonusApplicationTypeID) != 0 or int(bonus.BonusApplicationTargetID) != 0: return "조건 판정 연결 필요 · 원문 보존"
	if EXTRA_MAP.has(str(type.get("Name",""))) or type.get("Name") in ["MeleeDamage","RangeDamage","MagicDamage","MeleeHit","RangeHit","MagicHit","MagicResist","DamageReduction"]: return ""
	return "전투 소비자 연결 필요 · 원문 보존"
func extra_stats() -> Dictionary:
	var stats: Dictionary = {}
	if not catalog.loaded() or not clock_authority.is_valid() or save_blocked: return stats
	var clock: Variant = clock_authority.call()
	if not clock is String: return stats
	for book: Dictionary in catalog.books():
		for bonus: Dictionary in catalog.effective_bonuses(int(book.ID),clock):
			if int(bonus.BonusApplicationTypeID) != 0 or int(bonus.BonusApplicationTargetID) != 0: continue
			var type: Dictionary = catalog.row("BonusType",int(bonus.BonusTypeID))
			if not EXTRA_MAP.has(str(type.get("Name",""))): continue
			var unit: Dictionary = catalog.row("Unit",int(type.UnitID))
			var amount: float = float(bonus.Value)
			if unit.get("Name") in ["Percentage","ValuePercent","Weight"]:
				var denominator: float = 0
				for display: Dictionary in catalog.table_rows("UIUnit"):
					if int(display.UnitID) == int(type.UnitID): denominator = float(display.Denominator)
				if denominator <= 0: continue
				amount /= denominator
			elif unit.get("Name") != "Value": continue
			var key: String = EXTRA_MAP[type.Name]
			stats[key] = float(stats.get(key,0)) + amount
	return stats

func stat_record() -> Dictionary:
	var stats := extra_stats()
	if stats.is_empty(): return {}
	var record := stats.duplicate(true)
	if stats.has("moveSpeedPct"): record["speed"] = 1.0 + float(stats.moveSpeedPct)/100.0
	if stats.has("xpPct"): record["xp"] = float(stats.xpPct)/100.0
	return record

func catalog_bonus(key: String) -> int:
	var stats := extra_stats()
	if key == "pve_damage_reduction_pct": return int(stats.get(key,0)) + int(stats.get("damage_reduction_pct",0))
	return int(stats.get(key,0)) if key in ["weightBonus","pve_damage_reduction"] else 0
