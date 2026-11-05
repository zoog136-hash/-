extends RefCounted
## Source effects plus explicitly labelled, adjustable host estimates.
const POLICY = preload("res://scripts/progression/totem_combat_policy.gd")
var policy = POLICY.new()
var settings_blocked := false
var host_ref: WeakRef
var world: Node:
	get: return host_ref.get_ref() if host_ref != null else null
var barrier_remaining := 0.0
var barrier_capacity := 0
var busy := false
var targets: Array[WeakRef] = []
var fired: Array[int] = []

func configure(host: Node) -> void:
	host_ref = weakref(host)
	policy.load_defaults()

func settings() -> Dictionary:
	if not policy.error.is_empty():return {}
	var saved: Variant = world.ui_preferences.get("totem_combat_settings",policy.defaults)
	return POLICY.normalized(saved) if POLICY.valid(saved) else {}

func settings_token() -> String:
	return JSON.stringify(settings(),"",true,true).sha256_text()

func valid_settings(value: Variant) -> bool:return POLICY.valid(value)

func check_settings_load(data: Dictionary) -> String:
	var prefs: Variant = data.get("ui_preferences",{})
	if prefs is Dictionary and prefs.has("totem_combat_settings") and not POLICY.valid(prefs.totem_combat_settings):return "토템 자체 전투 설정 저장 오류 · 기존 상태 보존"
	return ""

func apply_settings(value: Variant, token: String) -> Dictionary:
	if settings_blocked or busy or token != settings_token():return {"ok":false,"reason":"설정 상태가 바뀌었거나 저장 보호 중입니다"}
	if not POLICY.valid(value) or not policy.error.is_empty():return {"ok":false,"reason":"자체 전투 설정 범위·버전 오류"}
	var next: Dictionary = POLICY.normalized(value)
	busy = true
	var result: Error = world._save_game(true,{"totem_combat_settings":next})
	busy = false
	if result != OK:return {"ok":false,"reason":"설정 저장 실패 · 이전 설정·활성 효과 보존"}
	world.ui_preferences["totem_combat_settings"] = next
	world.hud.show_message("자체 전투 설정 저장 · 다음 발동부터 적용")
	world.hud.refresh_totems()
	return {"ok":true}

func effects() -> Array:
	var result: Array = []
	if world == null or world.totems.save_blocked: return result
	for effect: Dictionary in world.totems.selected_bonuses():
		if effect.type.get("Name") != "InvokeOption" or int(effect.bonus.BonusApplicationTypeID) != 10: continue
		var option: Dictionary = world.totems.row("InvokeOption",int(effect.bonus.BonusApplicationTargetID))
		if not option.is_empty(): result.append({"option":option,"raw_proc_chance":int(effect.bonus.Value)})
	return result

func spell_values(spell_id: int) -> Dictionary:
	var result: Dictionary = {}
	for link: Dictionary in world.totems.rows("SpellBonus"):
		if int(link.SpellClassID) != spell_id: continue
		var effect: Dictionary = world.totems.typed_bonus(int(link.BonusID))
		result[str(effect.type.Name)] = int(effect.bonus.Value)
	return result

func buff_effects(buff_id: int) -> Array:
	var result: Array = []
	for link: Dictionary in world.totems.rows("BuffBonus"):
		if int(link.BuffClassID) == buff_id:
			var effect: Dictionary = world.totems.typed_bonus(int(link.BonusID))
			effect["unit"] = world.totems.row("Unit",int(effect.type.UnitID))
			result.append(effect)
	return result

func roll(raw_chance: int) -> bool:
	return world.rng.randi_range(0,999999) < clampi(raw_chance,0,1000000)

func cooldown_key(option: Dictionary) -> String:
	return "totem|"+str(int(option.ID))

func ready(option: Dictionary) -> bool:
	return float(world.skill_cooldowns.get(cooldown_key(option),0)) <= 0

func commit_proc(option: Dictionary, spell: Dictionary, target: Node) -> void:
	# Existing host CastDelay convention; not a newly asserted server time unit.
	world.skill_cooldowns[cooldown_key(option)] = float(spell.CastDelay)/1000.0
	fired.append(int(option.ID))
	world.option_awakening.combat.emit_spell(spell,target)

func on_hit(target: Node, kind: String, by_spell: bool) -> void:
	fired.clear()
	if busy or not is_instance_valid(target) or target.dead: return
	busy = true
	for effect: Dictionary in effects():
		var option: Dictionary = effect.option
		if int(option.InvokeOptionTypeID) != 1 or bool(option.BySpellAttack) != (by_spell or kind == "magic") or not ready(option): continue
		var spell: Dictionary = world.totems.row("SpellClass",int(option.Param1))
		var values := spell_values(int(option.Param1))
		if spell.is_empty() or not roll(int(effect.raw_proc_chance)): continue
		var applied := false
		if values.get("SpellAttackType") == 1 and values.has("SpellDamageBase"):
			var damage := int(values.SpellDamageBase)
			for die in range(int(values.get("SpellDamageDiceNumber",0))): damage += world.rng.randi_range(1,maxi(1,int(values.get("SpellDamageDiceSpotCount",1))))
			world._deal_successful_player_hit(target,damage,false)
			world.hud.append_log("토템 · 오시리스 추가 물리 피해")
			applied = true
		if values.has("BuffClassID") and not target.dead:
			var supported: Array = []
			for bonus: Dictionary in buff_effects(int(values.BuffClassID)):
				if bonus.type.Name in ["HPPotionDecreasePercent","CannotSee"]: supported.append(bonus)
			if not supported.is_empty():
				var duration: float = world.rng.randf_range(float(values.get("SpellDebuffMinDuration",0)),float(values.get("SpellDebuffMaxDuration",0)))
				if target.apply_source_option_debuff("totem:"+str(int(option.ID)),duration,supported):
					if int(option.ID) == 17524 and bool(settings().get("venom_enabled",false)):
						var poison: Dictionary = {}
						for bonus: Dictionary in buff_effects(int(values.BuffClassID)):poison[str(bonus.type.Name)] = int(bonus.bonus.Value)
						if poison.has("PoisonDamageByMaxHP") and poison.has("MinPoisonDamage") and poison.has("MaxPoisonDamage"):
							if target.configure_totem_venom("totem:17524",float(settings().venom_interval),int(poison.PoisonDamageByMaxHP),int(poison.MinPoisonDamage),int(poison.MaxPoisonDamage),POLICY.ID):
								world.hud.append_log("토템 · 제브레퀴 중독 [자체 주기 %.2f초]" % float(settings().venom_interval))
					targets.append(weakref(target))
					applied = true
					world.hud.append_log("토템 · 오시리스 시야 차단" if int(option.ID) == 17504 else "토템 · 제브레퀴 물약 회복 감소")
		if applied: commit_proc(option,spell,target)
	busy = false

func active_status(totem_id: int) -> String:
	var lines: PackedStringArray = []
	# UNVERIFIED: these names replace only the existing totem identity literals.
	# Effect durations remain owned by their existing spell definitions.
	var teberath_id: Variant = world.totems.source_constant("TeberathID")
	var tikal_id: Variant = world.totems.source_constant("TikalID")
	var atlantis_id: Variant = world.totems.source_constant("AtlantisID")
	var source_options: Dictionary = {}
	if teberath_id != null: source_options[int(teberath_id)] = 17504
	if tikal_id != null: source_options[int(tikal_id)] = 17524
	if atlantis_id != null: source_options[int(atlantis_id)] = 17514
	var origin := "totem:"+str(source_options.get(totem_id,0))
	var is_teberath: bool = teberath_id != null and totem_id == int(teberath_id)
	for ref: WeakRef in targets:
		var target: Node = ref.get_ref()
		if not is_instance_valid(target) or target.dead:continue
		var entry: Dictionary = target.source_option_debuffs.get(origin,{})
		if entry.is_empty() or float(entry.remaining) <= 0:continue
		var line := "%s · %s %.1f초" % [target.monster_name,"시야 차단" if is_teberath else "물약 회복 감소",float(entry.remaining)]
		if entry.has("venom"):line += " · 독 %d / %.2f초 [자체 처리]" % [int(entry.venom.damage),float(entry.venom.interval)]
		if not lines.has(line):lines.append(line)
	if atlantis_id != null and totem_id == int(atlantis_id) and barrier_remaining > 0:lines.append("리덕션 +%d · %.1f초 · 흡수 잔량 %d [자체 용량]" % [barrier_flat(),barrier_remaining,barrier_capacity])
	return "현재 발동 효과 없음" if lines.is_empty() else "\n".join(lines)

func barrier_flat() -> int:
	if barrier_remaining <= 0: return 0
	for bonus: Dictionary in buff_effects(81004):
		if bonus.type.Name == "DamageReduction": return int(bonus.bonus.Value)
	return 0

func incoming(attacker: Node, kind: String, amount: int) -> int:
	fired.clear()
	if busy or amount <= 0 or not is_instance_valid(attacker) or attacker.dead: return amount
	for effect: Dictionary in effects():
		var option: Dictionary = effect.option
		if int(option.InvokeOptionTypeID) != 2 or bool(option.BySpellAttack) != (kind == "magic") or amount < int(option.Param2) or not ready(option): continue
		var values := spell_values(int(option.Param1))
		if not values.has("SpellBuffDuration") or not roll(int(effect.raw_proc_chance)): continue
		var was_active := barrier_remaining > 0
		barrier_remaining = float(values.SpellBuffDuration)
		barrier_capacity = mini(int(settings().get("shield_capacity",0)),world._effective_max_hp()) if bool(settings().get("shield_enabled",false)) else 0
		commit_proc(option,world.totems.row("SpellClass",int(option.Param1)),world.player)
		world.hud.append_log("토템 · 포세이돈 리덕션 적용 · 흡수 용량 %d [자체 설정]" % barrier_capacity)
		if not was_active: amount = maxi(1,amount-barrier_flat())
	var absorbed := mini(amount,barrier_capacity) if barrier_remaining > 0 else 0
	barrier_capacity -= absorbed
	return amount-absorbed

func reconcile() -> void:
	var enabled: Dictionary = {}
	var has_barrier := false
	for effect: Dictionary in effects():
		enabled["totem:"+str(int(effect.option.ID))] = true
		if int(effect.option.InvokeOptionTypeID) == 2: has_barrier = true
	if not has_barrier:
		barrier_remaining = 0
		barrier_capacity = 0
	var retained: Array[WeakRef] = []
	var seen: Dictionary = {}
	for ref: WeakRef in targets:
		var target: Node = ref.get_ref()
		if not is_instance_valid(target) or seen.has(target.get_instance_id()): continue
		seen[target.get_instance_id()] = true
		target.prune_source_option_debuffs(enabled,"totem:")
		if not target.dead: retained.append(ref)
	targets = retained

func tick(delta: float) -> void:
	barrier_remaining = maxf(0,barrier_remaining-maxf(0,delta))
	if barrier_remaining <= 0:barrier_capacity = 0
	if not targets.is_empty() or barrier_remaining > 0: reconcile()

func clear() -> void:
	barrier_remaining = 0
	barrier_capacity = 0
	for ref: WeakRef in targets:
		var target: Node = ref.get_ref()
		if is_instance_valid(target): target.prune_source_option_debuffs({},"totem:")
	targets.clear()
