extends RefCounted
## Exact source magnitudes; TWILIGHT's existing combat/status consumers determine resolution.
const EQUIPMENT_IGNORE=preload("res://scripts/resources/current523_equipment_ignore_input.gd")
const Visuals=preload("res://scripts/cards/native_option_combat.gd")
var runtime_ref: WeakRef
var runtime:
	get:return runtime_ref.get_ref() if runtime_ref!=null else null
var world:
	get:return runtime.world if runtime!=null else null
var busy: bool=false
var fired: Array[int]=[]
var visuals=Visuals.new()
func configure(rt) -> void:
	runtime_ref=weakref(rt);visuals.configure(rt)
func enabled_rows(reward_type: int=14) -> Array:
	var result: Array=[]
	if runtime==null or world==null or runtime.development:return result
	for id: String in runtime.state.nodes:
		if not runtime.guardian_source.has_node(id):continue
		var node: Dictionary=runtime.node(id)
		if not runtime.guardian_source.availability(node).is_empty():continue
		if reward_type==24 and runtime.guardian_representative(int(node.category_id))!=id:continue
		for reward: Dictionary in runtime.guardian_rewards(id):
			if int(reward.row.RewardTypeID)==reward_type:result.append(reward)
	return result
func value(name: String,scope: int=-1) -> float:
	var total: float=0
	for reward: Dictionary in enabled_rows():
		if str(reward.bonus_type.Name)!=name:continue
		if scope>=0 and int(reward.bonus.BonusApplicationTargetID)!=scope:continue
		total+=float(reward.get("value",reward.bonus.Value))
	return total
func roll(percent: float) -> bool:
	if percent<=0:return false
	if percent>=100:return true
	return world.rng.randi_range(0,999999)<int(percent*10000)
func pve_numeric_policy() -> Dictionary:
	return runtime.guardian_local_rules.get("combat",{}).get("pvp_numeric_to_pve",{})
func pve_numeric_row(id: int) -> bool:
	# JSON numbers load as floats; normalize source identity before membership.
	for configured: Variant in pve_numeric_policy().get("reward_ids",[]):
		if int(configured)==id:return true
	return false
func pvp_numeric_value(name: String,context: Dictionary) -> float:
	if bool(context.get("pvp",false)):return value(name)
	var policy: Dictionary=pve_numeric_policy()
	if not bool(policy.get("enabled",false)):return 0.0
	var total: float=0
	for reward: Dictionary in enabled_rows():
		if pve_numeric_row(int(reward.row.ID)) and str(reward.bonus_type.Name)==name:
			total+=float(reward.get("value",reward.bonus.Value))
	return total
func pve_numeric_detail(id: String) -> String:
	var policy: Dictionary=pve_numeric_policy()
	var labels: Dictionary={"PiercePVPDamageReduction":"PvE 리덕션 무시","PVPMeleeAdditionDamage":"PvE 근거리 추가 대미지","PVPRangeAdditionDamage":"PvE 원거리 추가 대미지","PVPDamageReduction":"PvE 대미지 리덕션"}
	var parts: Array[String]=[]
	for reward: Dictionary in runtime.guardian_rewards(id):
		if pve_numeric_row(int(reward.row.ID)):
			parts.append(str(labels.get(str(reward.bonus_type.Name),reward.label))+" %+d" % int(reward.get("value",reward.bonus.Value)))
	if parts.is_empty():return ""
	if not bool(policy.get("enabled",false)):return "단독 플레이 수치 호환 꺼짐 · 원본 PvP 조건 유지"
	var pierce: String="리덕션 무시는 PvE 추가 피해로 적용 (기존 단독 정책)" if str(policy.get("pierce_mode","bounded_restoration"))=="flat_addition" else "리덕션 무시는 실제 감소량까지만 복원"
	return "TWILIGHT 단독 플레이 호환 · "+" / ".join(parts)+"\n활성화한 노드에 적용 · 원본 PvP 명칭/값 보존 · "+pierce
func status_hit(kind: String) -> float:
	return value("HitSpecialResistance",6 if kind=="stun" else 8) if kind in ["stun","fear"] else 0.0
func status_resistance(kind: String) -> float:
	return value("SpecialResistance",6 if kind=="stun" else 8) if kind in ["stun","fear"] else 0.0
func critical_resistance(kind: String) -> float:
	return value("MeleeCriticalResist") if kind=="melee" else value("RangeCriticalResist") if kind=="ranged" else 0.0
func poison_damage(amount: int) -> int:
	return maxi(0,int(round(amount*(1-clampf(value("PoisonDamageReductionPercent"),0,100)/100))))
func incoming(attacker: Node,kind: String,amount: int,critical: bool=false,context: Dictionary={}) -> Dictionary:
	var out: Dictionary={"damage":maxi(0,amount),"heal":0,"blocked":false}
	fired.clear()
	if amount<=0:return out
	if kind!="magic" and roll(value("WeaponBlock")):
		out.damage=0;out.blocked=true;return out
	var reduction: float=value("CriticalDamageReduction") if critical else 0.0
	reduction+=pvp_numeric_value("PVPDamageReduction",context)
	if float(world.player.get("stun_remaining"))>0:reduction+=value("DamageReductionForSpecialDebuff",6)
	for tag: Variant in context.get("spell_tags",[]):reduction+=value("DamageReductionForSpellAttackWeapon",int(tag))
	var percent: float=value("DamageReductionPercent")+value("RangeDamageReductionPercent" if kind=="ranged" else "MeleeDamageReductionPercent" if kind=="melee" else "")
	out.damage=maxi(0,int(round((amount-reduction)*(1-clampf(percent,0,100)/100))))
	if busy:return out
	busy=true
	for reward: Dictionary in enabled_rows(24):
		var option: Dictionary=reward.invoke
		var type: int=int(option.InvokeOptionTypeID)
		if type==5 and roll(float(reward.bonus.Value)/10000):
			out.damage=maxi(0,int(out.damage)-int(option.Param1));fired.append(int(option.ID));visuals.emit_sprite(int(option.TargetEffectSpriteID),world.player)
		elif type==2:
			if bool(option.BySpellAttack)!=(kind=="magic") or amount<int(option.Param2):continue
			if int(option.Param3)==1 and not bool(context.get("pvp",false)):continue
			if bool(option.Param5) and float(world.player.get("stun_remaining"))<=0:continue
			var spell: Dictionary=profile(int(option.Param1))
			if not ready(spell) or not roll(float(reward.bonus.Value)/10000):continue
			out.heal+=int(spell.values.get("HPRestoration",0));start_cooldown(spell);fired.append(int(option.ID));visuals.emit_spell(spell.source,world.player)
	busy=false
	return out
func outgoing(target: Node,amount: int,critical: bool,kind: String,context: Dictionary={}) -> int:
	var result: float=amount
	var pvp: bool=bool(context.get("pvp",false))
	result+=pvp_numeric_value("PVPMeleeAdditionDamage" if kind=="melee" else "PVPRangeAdditionDamage" if kind=="ranged" else "",context)
	if pvp:
		if world.original_skills!=null:result-=world.original_skills.status.modifier(target,"pvp_reduction")
	# Original scoped pierce stays bounded. The exact PvE compatibility rows
	# can use the existing game's ignore-as-addition policy, explicitly local.
	var budget: float=maxf(0,float(context.get("flat_reduction",0)))
	var pierce: float=value("PierceDamageReduction")+value("PierceMeleeDamageReduction" if kind=="melee" else "PierceRangeDamageReduction" if kind=="ranged" else "")
	var numeric_pierce: float=pvp_numeric_value("PiercePVPDamageReduction",context)
	if not pvp and str(pve_numeric_policy().get("pierce_mode","bounded_restoration"))=="flat_addition":result+=numeric_pierce
	else:pierce+=numeric_pierce
	result+=minf(budget,maxf(0,pierce))
	var percentage_budget: float=maxf(0,float(context.get("percent_reduction",0)))
	var ignore: float=value("IgnoreDamageReductionPercent")+value("IgnoreMeleeDamageReductionPercent" if kind=="melee" else "IgnoreRangeDamageReductionPercent" if kind=="ranged" else "IgnoreMagicDamageReductionPercent")
	# Exact native equipment operands share this existing percentage-budget receiver.
	ignore+=EQUIPMENT_IGNORE.sum_equipped(world,kind)
	if pvp:ignore+=value("IgnorePVPDamageReductionPercent")
	result*=1-minf(100,maxf(0,percentage_budget-ignore))/100
	if bool(context.get("final_blow",false)):result=result*(1+value("FinalBlowAdditionalScale")/100)+value("FinalBlowAdditionalDmg")
	return maxi(0,int(round(result)))
func after_hit(target: Node,critical: bool,kind: String,main_target: bool=true,by_spell: bool=false,available_hp: int=0,available_mp: int=0) -> void:
	if critical:
		var hp_drain: int=mini(available_hp,int(value("CriticalDrainHP")))
		var mp_drain: int=mini(available_mp,int(value("CriticalDrainMP")))
		world.hp=mini(world._effective_max_hp(),world.hp+hp_drain)
		world.mp=mini(world._effective_max_mp(),world.mp+mp_drain)
		if mp_drain>0:target.mp=maxi(0,target.mp-mp_drain)
	if busy or not is_instance_valid(target) or target.dead:return
	busy=true;fired.clear()
	for reward: Dictionary in enabled_rows(24):
		var option: Dictionary=reward.invoke
		var type: int=int(option.InvokeOptionTypeID)
		if type not in [1,27] or (type==27 and not critical):continue
		if bool(option.BySpellAttack)!=(by_spell or kind=="magic"):continue
		if bool(option.Param4) and not main_target:continue
		if int(option.Param6)!=0 and not world.original_skills.catalog.record_for(str(int(option.Param6))).get("owned",false):continue
		var spell: Dictionary=profile(int(option.Param1))
		if not ready(spell) or not roll(float(reward.bonus.Value)/10000):continue
		if cast_spell(spell,target):start_cooldown(spell);fired.append(int(option.ID))
	busy=false
func profile(id: int) -> Dictionary:
	return runtime.guardian_source.data.get("spells",{}).get(str(id),{})
func spell_allowed(id: int,groups: Array=[]) -> bool:
	if not groups.has(241):return true
	for row: Dictionary in runtime.guardian_source.data.source_tables.get("LandGroupAttribute",[]):
		if int(row.LandGroupID)==241 and int(row.Value)==id:return false
	return true
func current_groups() -> Array:
	if world==null or world.field_map==null:return []
	return world.field_map.data.get("source_land_group_ids",[])
func ready(spell: Dictionary) -> bool:
	return not spell.is_empty() and not bool(spell.source.TestSpell) and spell_allowed(int(spell.source.ID),current_groups()) and float(world.skill_cooldowns.get("guardian_spell|"+str(int(spell.source.ID)),0))<=0
func start_cooldown(spell: Dictionary) -> void:
	world.skill_cooldowns["guardian_spell|"+str(int(spell.source.ID))]=float(spell.source.CastDelay)/1000
func cell_distance(a: Vector2,b: Vector2) -> int:
	var delta: Vector2i=world._world_to_cell(a)-world._world_to_cell(b)
	return maxi(absi(delta.x),absi(delta.y))
func cast_spell(spell: Dictionary,target: Node) -> bool:
	if not is_instance_valid(target) or target.dead:return false
	var raw: Dictionary=spell.source
	if int(raw.CastRange)>0 and cell_distance(world.player.global_position,target.global_position)>int(raw.CastRange):return false
	if not world._has_line_of_sight_world(world.player.global_position,target.global_position):return false
	var victims: Array=[target]
	if int(raw.TargetAreaRadius)>0:
		for candidate: Node in world.monsters_root.get_children():
			if candidate==target or bool(candidate.get("dead")):continue
			if cell_distance(candidate.global_position,target.global_position)<=int(raw.TargetAreaRadius) and world._has_line_of_sight_world(world.player.global_position,candidate.global_position):victims.append(candidate)
	for victim: Node in victims:
		var values: Dictionary=spell.values
		if values.has("SpellDamageBase"):
			var damage: int=int(values.SpellDamageBase)
			for die: int in range(int(values.get("SpellDamageDiceNumber",0))):damage+=world.rng.randi_range(1,maxi(1,int(values.get("SpellDamageDiceSpotCount",1))))
			if world.original_skills!=null:damage=world.original_skills.target_damage(damage,victim)
			victim.take_damage(maxi(0,damage),false,"guardian:"+str(int(raw.ID)))
		if values.has("BuffClassID"):apply_buff(spell,victim)
		visuals.emit_spell(raw,victim)
		if victim.has_method("show_status_text"):victim.show_status_text(str(runtime.guardian_source.spell_name(int(raw.ID))))
	return true
func apply_buff(spell: Dictionary,target: Node) -> void:
	var values: Dictionary=spell.values
	var buff: Dictionary=runtime.guardian_source.data.buffs.get(str(int(values.BuffClassID)),{})
	var low: float=float(values.get("SpellDebuffMinDuration",0));var high: float=float(values.get("SpellDebuffMaxDuration",low))
	var duration: float=world.rng.randf_range(low,maxf(low,high))
	var modifiers: Dictionary={}
	var mapping: Dictionary={"RangeEvasion":"er","MagicResist":"mr","DamageReduction":"reduction","Strength":"str","Dexterity":"dex","Intelligence":"int","Constitution":"con","Wisdom":"wis","Charisma":"cha","StrengthScale":"str_percent","DexterityScale":"dex_percent","IntelligenceScale":"int_percent","PVPDamageReduction":"pvp_reduction"}
	for effect: Dictionary in buff.get("effects",[]):
		var name: String=str(effect.type.Name)
		if mapping.has(name):modifiers[mapping[name]]=float(effect.value)
		elif name=="ArmorClass":modifiers.ac=-float(effect.value)
		elif name=="SpecialResistance":modifiers["status_resistance_"+str(int(effect.bonus.BonusApplicationTargetID))]=float(effect.value)
	if values.has("SpellHitProbabilityBase"):
		# Existing TWILIGHT status policy, not an inferred original server level formula.
		var chance: float=float(values.SpellHitProbabilityBase)/100
		var dice: int=0;var faces: int=1
		for effect: Dictionary in buff.get("effects",[]):
			if effect.type.Name=="PoisonDamageDiceNumber":dice=int(effect.value)
			if effect.type.Name=="PoisonDamageDiceSpotCount":faces=int(effect.value)
		var damage: int=0
		for die: int in range(dice):damage+=world.rng.randi_range(1,maxi(1,faces))
		if world.original_skills!=null:
			world.original_skills.status.apply({"id":"guardian:"+str(int(spell.source.ID)),"status":"poison","status_chance":chance,"duration":duration,"tick_damage":damage,"tick_interval":float(runtime.guardian_local_rules.combat.poison_tick_interval_seconds)},target,world)
	if not modifiers.is_empty() and world.original_skills!=null:
		world.original_skills.status.set_modifiers(target,"guardian:"+str(int(spell.source.ID)),duration,modifiers)

func final_blow_chance() -> float:
	if value("FinalBlowAdditionalDmg")==0 and value("FinalBlowAdditionalScale")==0:return 0
	var total: float=0
	for record: Dictionary in world._all_equipped_records():
		for effect: Dictionary in record.get("source_bonuses",[]):
			var bonus: Dictionary=effect.get("bonus",{})
			if int(bonus.get("BonusTypeID",0))==6121 and int(bonus.get("BonusApplicationTypeID",-1))==0 and int(bonus.get("BonusApplicationTargetID",-1))==0:total+=float(bonus.Value)/10000
	return total

func attribute(target: Node,name: String) -> Dictionary:
	var source: Dictionary=target.get("source_m_original")
	if source.is_empty() and target.has_method("original_attribute_input"):
		source=target.original_attribute_input()
	var original: String=name.capitalize()
	if world==null or not source.has(original) or world.original_skills==null:return {"known":false,"before":0,"after":0}
	var before: float=float(source[original])
	var flat: float=world.original_skills.status.modifier(target,name)
	var percent: float=world.original_skills.status.modifier(target,name+"_percent")
	return {"known":true,"before":before,"after":maxf(0,before*(1+percent/100)+flat)}

func npc_accuracy_delta(target: Node,kind: String) -> int:
	var stats: Dictionary=attribute(target,"int" if kind=="magic" else "dex" if kind=="ranged" else "str")
	return int(stats.after-stats.before)

func npc_damage_delta(target: Node,kind: String) -> int:
	var stats: Dictionary=attribute(target,"int" if kind=="magic" else "dex" if kind=="ranged" else "str")
	# Reuse current character stat steps for the local NPC adapter; never infer a server formula.
	var baseline: int=8 if kind=="magic" else 10
	return world._stat_step_bonus(int(stats.after),baseline,2.0)-world._stat_step_bonus(int(stats.before),baseline,2.0) if world!=null else 0

func npc_max_hp_delta(target: Node) -> int:
	if world==null or world.original_skills==null or not world.original_skills.status.debuffs.has(target.get_instance_id()):return 0
	var stats: Dictionary=attribute(target,"con")
	return int(stats.after-stats.before)*10

func npc_mr_delta(target: Node) -> int:
	var stats: Dictionary=attribute(target,"wis")
	return int(stats.after-stats.before)*2

func npc_ac_delta(target: Node) -> int:
	var stats: Dictionary=attribute(target,"dex")
	return -(world._stat_step_bonus(int(stats.after),10,3.0)-world._stat_step_bonus(int(stats.before),10,3.0)) if world!=null else 0
