extends RefCounted
## Confirmed components on existing TWILIGHT hit boundaries; no Shield454 body.
var host_ref: WeakRef
var world: Node:
	get: return host_ref.get_ref() if host_ref != null else null
var barrier_remaining := 0.0
var busy := false
var targets: Array[WeakRef] = []
var fired: Array[int] = []

func configure(host: Node) -> void: host_ref = weakref(host)

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
		if values.get("SpellAttackType") == 1 and values.has("SpellDamageBase"):
			var damage := int(values.SpellDamageBase)
			for die in range(int(values.get("SpellDamageDiceNumber",0))): damage += world.rng.randi_range(1,maxi(1,int(values.get("SpellDamageDiceSpotCount",1))))
			world._deal_successful_player_hit(target,damage,false)
			world.hud.append_log("토템 · 오시리스 추가 물리 피해")
		elif values.has("BuffClassID"):
			var supported: Array = []
			for bonus: Dictionary in buff_effects(int(values.BuffClassID)):
				if bonus.type.Name == "HPPotionDecreasePercent": supported.append(bonus)
			if supported.is_empty(): continue
			var duration: float = world.rng.randf_range(float(values.get("SpellDebuffMinDuration",0)),float(values.get("SpellDebuffMaxDuration",0)))
			if not target.apply_source_option_debuff("totem:"+str(int(option.ID)),duration,supported): continue
			targets.append(weakref(target))
			world.hud.append_log("토템 · 제브레퀴 물약 회복 감소")
		else: continue
		commit_proc(option,spell,target)
	busy = false

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
		commit_proc(option,world.totems.row("SpellClass",int(option.Param1)),world.player)
		world.hud.append_log("토템 · 포세이돈 리덕션 적용 · 보호막 수치 미제공")
		if not was_active: amount = maxi(1,amount-barrier_flat())
	return amount

func reconcile() -> void:
	var enabled: Dictionary = {}
	var has_barrier := false
	for effect: Dictionary in effects():
		enabled["totem:"+str(int(effect.option.ID))] = true
		if int(effect.option.InvokeOptionTypeID) == 2: has_barrier = true
	if not has_barrier: barrier_remaining = 0
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
	if not targets.is_empty() or barrier_remaining > 0: reconcile()

func clear() -> void:
	barrier_remaining = 0
	for ref: WeakRef in targets:
		var target: Node = ref.get_ref()
		if is_instance_valid(target): target.prune_source_option_debuffs({},"totem:")
	targets.clear()
