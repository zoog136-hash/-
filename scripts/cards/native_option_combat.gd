extends RefCounted
## Contextual source invokes. No passive flattening, persistence or nested attacks.
const INPUT=preload("res://scripts/cards/current523_option_combat_input.gd")
const RELIC=preload("res://scripts/cards/patch523_slot_data.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const DARKNESS_OPTION := 15138 # InvokeOption -> SpellClass 86588 -> BuffClass 75428
const DARKNESS_STATUS := {"status":"dark","status_chance":1.0}
const DARKNESS_SPELL_UNITS := {
	"SpellDebuffMinDuration":"Seconds","SpellDebuffMaxDuration":"Seconds",
	"BuffClassID":"BuffClassID","SpecialResistanceTypeID":"SpecialResistanceTypeID",
}
const ANTARAS_HOLD_OPTION := 751
const ANTARAS_HOLD_UNITS := {
	"SpecialResistanceTypeID":"SpecialResistanceTypeID","BuffClassID":"BuffClassID",
	"SpellDebuffMinDuration":"Seconds","SpellDebuffMaxDuration":"Seconds",
	"SpellHitProbabilityBase":"Percentage","SpellHitProbabilityMax":"Percentage",
}
var runtime_ref: WeakRef
var runtime: RefCounted:
	get:return runtime_ref.get_ref() if runtime_ref!=null else null
var cooldowns: Dictionary:
	get:return runtime.world.skill_cooldowns if runtime!=null and runtime.world!=null else {}
var targets: Array[WeakRef]=[]
var busy: bool=false
var fired: Array[int]=[]
var visual_results: Dictionary={}
func configure(value: RefCounted) -> void:runtime_ref=weakref(value)
func active() -> Dictionary:
	var out: Dictionary={}
	if runtime==null or not is_instance_valid(runtime.world) or runtime.save_blocked or not runtime.problem.is_empty() or not runtime.core.native_mode:return out
	runtime._sync_native_context()
	for category: String in Cards.CATEGORIES:
		var record: Dictionary=runtime.world.equipped_catalog.get(category,{})
		if not preload("res://scripts/lineagem_base508.gd").native(record):continue
		var identity: String=Cards.card_id(record)
		if runtime.is_awakened(category,identity):out[identity]=runtime.core.definition(category,identity)
		if category in ["변신","성물"] and runtime.core.owned({"owned":runtime.world.card_draw_fusion.owned},category,identity):
			var verified: Dictionary = preload("res://scripts/lineagem_base508.gd").canonical(record)
			var base_rows: Array = verified.get("source_card_base_invokes",[])
			if not base_rows.is_empty() and runtime.core.native_material_available(verified):
				_append_base_invokes(out,identity,verified.get("source_original_card",{}),base_rows)
	var main: Dictionary=runtime.world.equipped_catalog.get("마법인형",{})
	if preload("res://scripts/lineagem_base508.gd").native(main):
		var identity: String=Cards.card_id(main)
		if runtime.core.owned({"owned":runtime.world.card_draw_fusion.owned},"마법인형",identity) and runtime.core.native_material_available(main):_add_doll_invokes(out,identity,false)
	var secondary: Dictionary=runtime.subslot_view(false)
	if secondary.active:_add_doll_invokes(out,str(secondary.identity),true)
	var relic: Dictionary=runtime.relic_subslot_view(false)
	if relic.active:
		var row: Dictionary=RELIC.relic_subslot_buff(preload("res://scripts/cards/native_relic_subslot.gd").identity_key(str(relic.identity)))
		if not row.is_empty():out["relic_subslot11:"+str(relic.identity)]={"native_source":{"card":row.card,"effects":row.effects}}
	return out
func _add_doll_invokes(out: Dictionary,identity: String,secondary: bool) -> void:
	var row: Dictionary=preload("res://scripts/cards/native_doll_subslot.gd").subslot_row(identity) if secondary else INPUT.primary_doll_buff(identity)
	if row.is_empty():return
	var rows: Array=[]
	for effect: Dictionary in row.effects:
		if effect.type.Name!="InvokeOption":continue
		if not secondary and int(row.card.ID)==11692 and int(effect.bonus.BonusApplicationTargetID)==ANTARAS_HOLD_OPTION:
			var primary_effect: Dictionary=effect.duplicate()
			primary_effect["base_card"]=true
			rows.append(primary_effect)
		else:
			rows.append(effect)
	if rows.is_empty():return
	_append_base_invokes(out,identity,row.card,rows)

static func _append_base_invokes(out: Dictionary,identity: String,card: Dictionary,rows: Array) -> void:
	if not out.has(identity):out[identity]={"native_source":{"card":card,"effects":[]}}
	else:
		# The underlying source rows are read-only. Only detach the array and
		# the two dictionaries that own it before appending equipped effects.
		var combined: Dictionary=out[identity].duplicate()
		var source: Dictionary=combined.native_source.duplicate()
		source.effects=source.effects.duplicate()
		combined.native_source=source
		out[identity]=combined
	var effects_for_card: Array = out[identity].native_source.effects
	var bonus_ids: Dictionary = {}
	for effect: Dictionary in effects_for_card:bonus_ids[int(effect.bonus.ID)]=true
	for effect: Dictionary in rows:
		var id: int = int(effect.bonus.ID)
		if bonus_ids.has(id):continue
		bonus_ids[id]=true
		effects_for_card.append(effect)
func tick(_delta: float) -> void:
	if targets.is_empty():return
	var enabled: Dictionary=active()
	var retained: Array[WeakRef]=[]
	for ref: WeakRef in targets:
		var target: Node=ref.get_ref()
		if not is_instance_valid(target):continue
		if target.has_method("prune_source_option_debuffs"):target.prune_source_option_debuffs(enabled)
		if not bool(target.get("dead")) and not target.source_option_debuffs.is_empty():retained.append(ref)
	targets=retained
func effects(rows: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var by_scope: Dictionary={}
	for identity: String in rows:
		for effect: Dictionary in rows[identity].native_source.effects:
			if effect.type.Name!="InvokeOption" or effect.unit.Name!="Percentage" or int(effect.bonus.BonusApplicationTypeID)!=10:continue
			if effect.link.has("Level") and int(effect.link.Level)!=1:continue
			if effect.link.has("CharacterLevel") and (int(effect.link.CharacterLevel)!=0 or int(effect.link.CharacterClass)!=0 or int(effect.link.MinSpellLevel)!=0):continue
			var subslot: bool=identity.begins_with("relic_subslot11:")
			if not by_scope.has(subslot):
				var candidates: Array=INPUT.session().invoke_options.duplicate()
				if subslot:candidates.append_array(RELIC.relic_combat.invoke_options)
				var by_id: Dictionary={}
				for option: Dictionary in INPUT.union_options(candidates):by_id[int(option.ID)]=option
				by_scope[subslot]=by_id
			var option: Dictionary=by_scope[subslot].get(int(effect.bonus.BonusApplicationTargetID),{})
			if not option.is_empty():result.append({"origin":identity,"option":option,"weight":int(effect.bonus.Value),"base_card":bool(effect.get("base_card",false))})
	return result
func roll(weight: int) -> bool:
	# Percentage has 10,000 raw units per percent: 80,000 = 8%.
	return runtime.world.rng.randi_range(0,999999)<clampi(weight,0,1000000)
func incoming(attacker: Node,kind: String,amount: int) -> Dictionary:
	var result: Dictionary={"damage":maxi(0,amount),"heal":0}
	fired.clear()
	if busy or amount<=0 or not is_instance_valid(attacker) or bool(attacker.get("dead")):return result
	busy=true
	for effect: Dictionary in effects(active()):
		var option: Dictionary=effect.option
		if int(option.InvokeOptionTypeID)==5:
			if int(option.MaterialAmount)!=0 or int(option.Param3)!=0:continue
			if roll(int(effect.weight)):
				result.damage=maxi(0,int(result.damage)-int(option.Param1));fired.append(int(option.ID));emit_option_pair(option,attacker,runtime.world.player)
		elif int(option.InvokeOptionTypeID)==2:
			if bool(option.BySpellAttack)!=(kind=="magic") or amount<int(option.Param2) or int(option.Param3)!=0 or int(option.MaterialAmount)!=0:continue
			var key: String="native_option|"+str(effect.origin)+"|"+str(int(option.Param1))
			if float(cooldowns.get(key,0))>0:continue
			var spell: Dictionary=_invoke_spell(int(option.Param1))
			var healing: Dictionary=_spell_values(spell,["HPRestoration","HPRestorationDiceNumber","HPRestorationDiceSpotCount"])
			if not _free_spell(spell,1) or not healing.has("HPRestoration"):continue
			if int(healing.get("HPRestorationDiceNumber",0))>0 and int(healing.get("HPRestorationDiceSpotCount",0))<=0:continue
			if roll(int(effect.weight)):
				var amount_healed: int=int(healing.HPRestoration)
				for die: int in range(int(healing.get("HPRestorationDiceNumber",0))):amount_healed+=runtime.world.rng.randi_range(1,int(healing.HPRestorationDiceSpotCount))
				result.heal+=amount_healed;cooldowns[key]=float(spell.source_spell.CastDelay)/1000.0;fired.append(int(option.ID));emit_spell(spell.source_spell,runtime.world.player)
				emit_option_pair(option,attacker,runtime.world.player)
	busy=false
	return result
func on_hit(target: Node,attack_kind: String="melee",main_target: bool=true,by_spell: bool=false) -> void:
	fired.clear()
	if busy or not is_instance_valid(target) or bool(target.get("dead")) or not target.has_method("apply_source_option_debuff"):return
	busy=true
	for effect: Dictionary in effects(active()):
		var option: Dictionary=effect.option
		if int(option.InvokeOptionTypeID)!=1 or int(option.MaterialAmount)!=0 or int(option.Param6)!=0:continue
		if bool(option.BySpellAttack)!=(by_spell or attack_kind=="magic"):continue
		if bool(option.Param4) and not main_target:continue
		var key: String="native_option|"+str(effect.origin)+"|"+str(int(option.Param1))
		if float(cooldowns.get(key,0))>0:continue
		var spell: Dictionary=_invoke_spell(int(option.Param1))
		if spell.is_empty():continue
		if effect.get("base_card",false) and int(option.ID)==ANTARAS_HOLD_OPTION:
			_apply_antaras_hold(effect,spell,target,key)
			continue
		var fixed: Dictionary=_spell_values(spell,["SpellDamageBase","SpellDamageDiceNumber","SpellDamageDiceSpotCount","FixedMagicDamage","IgnoreMagicResistance","IgnoreDamageReductionCalculation"])
		if _free_spell(spell,2) and fixed.size()==6 and int(fixed.FixedMagicDamage)==1 and int(fixed.IgnoreMagicResistance)==1 and int(fixed.IgnoreDamageReductionCalculation)==1:
			if int(fixed.SpellDamageBase)<0 or int(fixed.SpellDamageDiceNumber)<0 or int(fixed.SpellDamageDiceSpotCount)<1:continue
			if not roll(int(effect.weight)):continue
			var damage: int=int(fixed.SpellDamageBase)
			for die: int in range(int(fixed.SpellDamageDiceNumber)):damage+=runtime.world.rng.randi_range(1,int(fixed.SpellDamageDiceSpotCount))
			emit_spell(spell.source_spell,target)
			emit_option_pair(option,runtime.world.player,target)
			target.take_damage(damage,false,"magic")
			cooldowns[key]=float(spell.source_spell.CastDelay)/1000.0;fired.append(int(option.ID));continue
		if effect.get("base_card",false):
			if int(option.ID)==DARKNESS_OPTION:
				_apply_base_darkness(effect,spell,target,key)
			else:
				_apply_base_damage_proc(effect,spell,target,key)
			continue
		var buffs: Array=[];var low: int=0;var high: int=0
		for bonus: Dictionary in spell.effects:
			match str(bonus.type.Name):
				"SpellDebuffMinDuration":low=int(bonus.bonus.Value)
				"SpellDebuffMaxDuration":high=int(bonus.bonus.Value)
				"BuffClassID":buffs=INPUT.invoke_buff(str(int(bonus.bonus.Value)))
		if low<=0 or high!=low or buffs.is_empty():continue
		if not roll(int(effect.weight)):continue
		if target.apply_source_option_debuff(str(effect.origin),low,buffs):
			_finish_debuff(option,spell.source_spell,target,key)
	busy=false

func _finish_debuff(option: Dictionary,raw: Dictionary,target: Node,cooldown_key: String) -> void:
	cooldowns[cooldown_key]=float(raw.CastDelay)/1000.0
	fired.append(int(option.ID))
	emit_spell(raw,target)
	emit_option_pair(option,runtime.world.player,target)
	for ref: WeakRef in targets:
		if ref.get_ref()==target:return
	targets.append(weakref(target))

func _apply_antaras_hold(effect: Dictionary,spell: Dictionary,target: Node,cooldown_key: String) -> void:
	var option: Dictionary=effect.option
	if not target is TwilightMonster or not _single_target_base_spell(spell,option) or target.source_option_petrified() or target.status_immunities.has("lapidification"):return
	var raw: Dictionary=spell.source_spell
	if int(raw.ID)!=33102 or not option.Param4 or not roll(int(effect.weight)):return
	var values: Dictionary={}
	for row: Dictionary in spell.effects:
		var kind: String=row.type.Name
		if values.has(kind) or ANTARAS_HOLD_UNITS.get(kind)!=row.unit.Name or int(row.link.MinSpellLevel)!=0 or int(row.bonus.BonusApplicationTypeID)!=0 or int(row.bonus.BonusApplicationTargetID)!=0:return
		values[kind]=int(row.bonus.Value)
	if values.size()!=6 or int(values.BuffClassID)!=115 or int(values.SpecialResistanceTypeID)!=2 or float(values.SpellDebuffMinDuration)<=0.0 or float(values.SpellDebuffMaxDuration)<float(values.SpellDebuffMinDuration):return
	var hit: int=mini(int(values.SpellHitProbabilityBase),int(values.SpellHitProbabilityMax))
	# The original row exceeds 100%, which saturates under the existing
	# proc roll. Then apply the host's axis-2 and boss control policy.
	var world: Node=runtime.world
	var resistance: float=target.source_equipment_modifier("status_resistance_2")
	var chance: float=clampf(float(hit)/1000000.0,0.0,1.0)*(1.0-clampf(resistance/100.0,0.0,1.0))
	var duration_factor: float=1.0
	if target.is_boss:
		var policy: Dictionary=world.PATCH523_ENHANCE.policy()
		chance*=clampf(float(policy.get("invoke_debuff_boss_chance_factor",0.35)),0.0,1.0)
		duration_factor=clampf(float(policy.get("invoke_debuff_boss_duration_factor",0.35)),0.0,1.0)
	if chance<=0.0 or duration_factor<=0.0 or (chance<1.0 and world.rng.randf()>=chance):return
	var buffs: Array=INPUT.invoke_buff(str(values.BuffClassID))
	var duration: float=world.rng.randf_range(values.SpellDebuffMinDuration,values.SpellDebuffMaxDuration)*duration_factor
	if target.apply_source_option_petrification(str(effect.origin),duration,buffs):
		_finish_debuff(option,raw,target,cooldown_key)

func _apply_base_darkness(effect: Dictionary,spell: Dictionary,target: Node,cooldown_key: String) -> void:
	if not target is TwilightMonster or not _single_target_base_spell(spell,effect.option):return
	var raw: Dictionary=spell.source_spell
	var option: Dictionary=effect.option
	var world: Node=runtime.world
	if int(raw.ID)!=86588 or not option.Param4 or world.original_skills==null:return
	# No source hit formula is declared. The existing TWILIGHT status policy
	# handles immunity, resistance and bosses after the source invoke roll.
	var status: RefCounted=world.original_skills.status
	if not status.can_affect(DARKNESS_STATUS,target) or not roll(int(effect.weight)):return
	var stats: Dictionary={}
	for row: Dictionary in spell.effects:
		var kind: String=row.type.Name
		if stats.has(kind) or DARKNESS_SPELL_UNITS.get(kind)!=row.unit.Name or int(row.link.MinSpellLevel)!=0 or int(row.bonus.BonusApplicationTypeID)!=0 or int(row.bonus.BonusApplicationTargetID)!=0:return
		stats[kind]=int(row.bonus.Value)
	if stats.size()!=4 or stats.BuffClassID!=75428 or stats.SpecialResistanceTypeID!=5 or stats.SpellDebuffMinDuration<=0 or stats.SpellDebuffMaxDuration<stats.SpellDebuffMinDuration:return
	var buffs: Array=INPUT.invoke_buff(str(stats.BuffClassID))
	if buffs.is_empty():return
	var chance: float=status.chance(DARKNESS_STATUS,target,world)
	if chance<1.0 and world.rng.randf()>=chance:return
	var duration: float=world.rng.randf_range(stats.SpellDebuffMinDuration,stats.SpellDebuffMaxDuration)
	if target.apply_source_option_debuff(str(effect.origin),duration,buffs,true):
		_finish_debuff(option,raw,target,cooldown_key)

func _single_target_base_spell(spell: Dictionary, option: Dictionary) -> bool:
	if not _free_spell(spell,2):return false
	for field: String in ["AttackTypeID","WeaponGroupID","Param2","Param3","Param5","ShieldTypeID","SuccessedInvokeOptionID","TargetKind","SiegeTargetKind"]:
		if int(option.get(field,0))!=0:return false
	var raw: Dictionary=spell.source_spell
	# The supported single-target source profile uses AllButMe.
	return not option.get("IsAmmoAttack",false) and int(raw.get("TargetKindID",-1))==11 and int(raw.get("SiegeTargetKindID",-1))==0 and raw.get("IncludeTargettingTarget")==true

## Plain direct spell: exact source dice, one target, and the current
## magic hit/element/reduction pipeline. Never recurse into another proc.
func _apply_base_damage_proc(effect: Dictionary, spell: Dictionary, target: Node, cooldown_key: String) -> void:
	var option: Dictionary=effect.option
	if not _single_target_base_spell(spell,option):return
	var values: Dictionary=_spell_values(spell,["SpellDamageBase","SpellDamageDiceNumber","SpellDamageDiceSpotCount"])
	if values.size()!=3 or int(values.SpellDamageBase)<0 or int(values.SpellDamageDiceNumber)<0 or int(values.SpellDamageDiceSpotCount)<1:return
	var raw: Dictionary=spell.source_spell
	var element: String=str({0:"physical",1:"fire",2:"water",3:"wind",4:"earth"}.get(int(raw.get("ElementalTypeID",-1)),""))
	var world: Node=runtime.world
	if element.is_empty() or world.get("original_skills")==null or not target is TwilightMonster:return
	if not roll(int(effect.weight)):return
	if float(raw.CastDelay)>0.0:cooldowns[cooldown_key]=float(raw.CastDelay)/1000.0
	if world.rng.randf()>=world.original_skills.hit_chance({"attack_type":"magic"},target):
		target.show_miss()
		return
	var damage: int=int(values.SpellDamageBase)
	for die: int in range(int(values.SpellDamageDiceNumber)):
		damage+=world.rng.randi_range(1,int(values.SpellDamageDiceSpotCount))
	damage=world._elemental_damage_to_monster(maxi(1,damage),element,target)
	damage=world.original_skills.target_damage(damage,target,"magic")
	emit_spell(raw,target)
	emit_option_pair(option,world.player,target)
	target.take_damage(maxi(0,damage),false,"magic")
	fired.append(int(option.ID))

func emit_spell(spell: Dictionary,target: Node2D) -> void:
	var seen: Dictionary={}
	var player: Node=runtime.world.player
	var preview: Node=null;var manifest: String="";var facing: int=5
	for property: Dictionary in player.get_property_list():
		if property.name=="original_source_preview":preview=player.get(property.name)
		if property.name=="original_source_manifest":manifest=str(player.get(property.name))
		if property.name=="motion" and player.get(property.name)!=null:facing=int(player.get(property.name).facing8)
	for stage: String in {"effect":"EffectSpriteID","success":"SuccessEffectSpriteID"}:
		var field: String="EffectSpriteID" if stage=="effect" else "SuccessEffectSpriteID"
		var sprite: int=int(spell.get(field,0))
		if sprite<=0 or seen.has(sprite):continue
		if preview!=null and (preview.has_method("notify_current_source_spell_event") or (preview.has_method("notify_source_spell_event") and not manifest.is_empty())):
			var live: Array[Node2D]=[]
			for node: Variant in preview._overlay_nodes:
				if is_instance_valid(node):live.append(node)
			preview._overlay_nodes=live
			if preview.has_method("notify_source_spell_event") and not manifest.is_empty() and preview.notify_source_spell_event(int(spell.ID),stage,target.global_position,facing,manifest):
				seen[sprite]=true;visual_results[str(sprite)]="played_original";continue
			if preview.has_method("notify_current_source_spell_event") and preview.notify_current_source_spell_event(spell,stage,target.global_position,facing):
				seen[sprite]=true;visual_results[str(sprite)]="played_current_source";continue
		emit_sprite(sprite,target)
		# A pending EffectSpriteActionNo must not consume a later success-stage
		# request. Deduplicate only an effect the existing renderer accepted.
		if visual_results.get(str(sprite),"")=="played_original":seen[sprite]=true
func emit_option_pair(option: Dictionary,attacker: Node,target: Node) -> void:
	# Called only inside an already accepted Invoke branch. The existing owner
	# supplies both participants; visual selection never rolls or fires an option.
	if is_instance_valid(attacker) and attacker is Node2D:
		emit_option_effect(option,"AttackerEffectSpriteID",attacker)
	if is_instance_valid(target) and target is Node2D:
		emit_option_effect(option,"TargetEffectSpriteID",target)

func emit_option_effect(option: Dictionary,field: String,target: Node2D) -> void:
	var sprite: int=int(option.get(field,0))
	if sprite<=0 or not is_instance_valid(target):return
	emit_sprite(sprite,target)
	if visual_results.get(str(sprite),"")=="played_original":return
	var preview: Variant=null
	for property: Dictionary in runtime.world.player.get_property_list():
		if property.name=="original_source_preview":preview=runtime.world.player.get(property.name);break
	if preview!=null and preview.has_method("notify_current_source_invoke_effect") and preview.notify_current_source_invoke_effect(option,field,target.global_position,5):
		visual_results[str(sprite)]="played_current_invoke_source"

func emit_sprite(sprite: int,target: Node2D,current_item: Dictionary={}) -> void:
	# Existing private source compositor only. Missing bindings remain absent.
	if sprite<=0 or not is_instance_valid(target):return
	visual_results[str(sprite)]="original_binding_unavailable"
	var player: Node=runtime.world.player
	var preview: Variant=null
	for property: Dictionary in player.get_property_list():
		if property.name=="original_source_preview":preview=player.get(property.name);break
	if preview!=null and (preview.has_method("spawn_source_overlay") or (not current_item.is_empty() and preview.has_method("notify_current_source_item_consume"))):
		# Shared compositor cleanup must accept freed handles before its typed filter.
		var live: Array[Node2D]=[]
		for node: Variant in preview._overlay_nodes:
			if is_instance_valid(node):live.append(node)
		preview._overlay_nodes=live
		if preview.has_method("spawn_source_overlay") and preview.spawn_source_overlay(sprite,5,target.global_position):
			visual_results[str(sprite)]="played_original"
			return
		if not current_item.is_empty() and preview.has_method("notify_current_source_item_consume") and preview.notify_current_source_item_consume(current_item,sprite,target.global_position,5):
			visual_results[str(sprite)]="played_current_item_source"

func _invoke_spell(identity: int) -> Dictionary:
	# Same precedence as before: the option input's own spell when it has one.
	var own: Variant=INPUT.invoke_spell(str(identity))
	return own if own!=null else RELIC.relic_combat.invoke_spells.get(str(identity),{})

func _free_spell(spell: Dictionary,target: int) -> bool:
	if spell.is_empty():return false
	var raw: Dictionary=spell.source_spell
	if bool(raw.TestSpell) or int(raw.TargettingTypeID)!=target or int(raw.TargetAreaRadius)!=0 or int(raw.HPCost)!=0 or int(raw.MPCost)!=0 or int(raw.get("VPCost",0))!=0:return false
	# The source's explicit None material type overrides an unused default amount.
	for kind: Dictionary in INPUT.session().spell_material_types:
		if int(kind.ID)==int(raw.SpellMaterialTypeID):return kind.Name=="None"
	return false
func _spell_values(spell: Dictionary,allowed: Array) -> Dictionary:
	var values: Dictionary={}
	if spell.is_empty():return values
	for effect: Dictionary in spell.effects:
		if effect.type.Name not in allowed or (effect.unit.Name!="Value" and not (effect.type.Name in ["FixedMagicDamage","IgnoreMagicResistance"] and effect.unit.Name=="TrueFalse")) or int(effect.link.MinSpellLevel)!=0 or int(effect.bonus.BonusApplicationTypeID)!=0 or int(effect.bonus.BonusApplicationTargetID)!=0 or values.has(effect.type.Name):return {}
		values[effect.type.Name]=int(effect.bonus.Value)
	return values

