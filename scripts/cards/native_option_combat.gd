extends RefCounted
## Contextual source invokes. No passive flattening, persistence or nested attacks.
const INPUT=preload("res://scripts/cards/current523_option_combat_input.gd")
const RELIC=preload("res://scripts/cards/patch523_slot_data.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
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
		if effect.type.Name=="InvokeOption":rows.append(effect)
	if rows.is_empty():return
	if not out.has(identity):out[identity]={"native_source":{"card":row.card,"effects":[]}}
	else:out[identity]=out[identity].duplicate(true)
	out[identity].native_source.effects.append_array(rows)
func tick(_delta: float) -> void:
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
	for identity: String in rows:
		for effect: Dictionary in rows[identity].native_source.effects:
			if effect.type.Name!="InvokeOption" or effect.unit.Name!="Percentage" or int(effect.bonus.BonusApplicationTypeID)!=10:continue
			if effect.link.has("Level") and int(effect.link.Level)!=1:continue
			if effect.link.has("CharacterLevel") and (int(effect.link.CharacterLevel)!=0 or int(effect.link.CharacterClass)!=0 or int(effect.link.MinSpellLevel)!=0):continue
			var candidates: Array=INPUT.session().invoke_options.duplicate()
			if identity.begins_with("relic_subslot11:"):candidates.append_array(RELIC.relic_combat.invoke_options)
			candidates=INPUT.union_options(candidates)
			for option: Dictionary in candidates:
				if int(option.ID)==int(effect.bonus.BonusApplicationTargetID):result.append({"origin":identity,"option":option,"weight":int(effect.bonus.Value)})
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
		var buffs: Array=[];var low: int=0;var high: int=0
		for bonus: Dictionary in spell.effects:
			match str(bonus.type.Name):
				"SpellDebuffMinDuration":low=int(bonus.bonus.Value)
				"SpellDebuffMaxDuration":high=int(bonus.bonus.Value)
				"BuffClassID":buffs=INPUT.invoke_buff(str(int(bonus.bonus.Value)))
		if low<=0 or high!=low or buffs.is_empty():continue
		if not roll(int(effect.weight)):continue
		if target.apply_source_option_debuff(str(effect.origin),low,buffs):
			cooldowns[key]=float(spell.source_spell.CastDelay)/1000.0;fired.append(int(option.ID));emit_spell(spell.source_spell,target)
			emit_option_pair(option,runtime.world.player,target)
			var found: bool=false
			for ref: WeakRef in targets:
				if ref.get_ref()==target:found=true;break
			if not found:targets.append(weakref(target))
	busy=false
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

