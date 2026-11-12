extends RefCounted
## Existing skills only: persisted ON/OFF, explicit native execution and host timing.
const RULES = preload("res://scripts/skills/progression_rules523.gd")
const RECOVERY = preload("res://scripts/skills/recovery_rules523.gd")
var owner_ref: WeakRef
var service: RefCounted:
	get:return owner_ref.get_ref() if owner_ref!=null else null
var on: Dictionary={}
var staged: Variant=null
var clocks: Dictionary={}
var light: PointLight2D
var fired: Dictionary={}

func configure(owner: RefCounted) -> void:owner_ref=weakref(owner)

func source() -> RefCounted:return service.catalog.source523

func spec(record: Dictionary) -> Dictionary:
	var id: String=str(record.get("id",""))
	var profile: Dictionary=source().profiles.get(id,{})
	if profile.is_empty():return {}
	return source().progression_rules.spec_for(id,profile,source().recovery_rules.percent_denominator)

func is_toggle(record: Dictionary) -> bool:
	return str(record.get("progression523",{}).get("kind","")) in ["aura","repeat","static"]

func is_on(record: Dictionary) -> bool:return bool(on.get(str(record.get("id","")),false))

func can_disable(record: Dictionary) -> bool:
	if service==null:return false
	return service.catalog.owned(record) and is_on(record) and is_toggle(service.catalog.resolve(record))

func toggle(record: Dictionary) -> bool:
	var next: Dictionary=on.duplicate(true)
	var id: String=str(record.id)
	next[id]=not bool(next.get(id,false))
	# Export a proposed snapshot without publishing state, costs or aura effects.
	staged=next
	var result: Error=service.world._save_game(true)
	staged=null
	if result!=OK:service.world.hud.show_message("스킬 ON/OFF 저장 실패 · 기존 상태 보존");return false
	on=next
	clocks[id]=0.0
	service.world.hud.show_message(str(record.name)+(" ON" if bool(on[id]) else " OFF"))
	service.world._update_hud()
	return true

func export_state() -> Dictionary:
	return staged.duplicate(true) if staged is Dictionary else on.duplicate(true)

func restore(value: Variant) -> void:
	on.clear();clocks.clear();staged=null
	if value is Dictionary:
		for id: String in value:
			if value[id] is bool:on[id]=value[id]

func suspend() -> void:
	clocks.clear()
	if is_instance_valid(light):light.hide()

func tick(delta: float) -> void:
	for id: String in clocks:clocks[id]=maxf(0,float(clocks[id])-delta)
	var world: Node=service.world
	# Old active-save versions must not stack a converted passive's old package.
	for name: String in world.active_skill_buffs.keys():
		var old: Dictionary=world.active_skill_buffs[name]
		var record: Dictionary=service.catalog.record_for(str(old.get("skill_id",name)))
		if record.is_empty():continue
		var resolved: Dictionary=service.catalog.resolve(record)
		if resolved.has("progression523") and str(resolved.activation)=="passive":
			world.active_skill_buffs.erase(name);service.vfx.remove_persistent(str(record.id))
	update_light()
	if world.hp<=0 or world.player.motion.dead or world.player.is_stunned() or world.player.is_feared() or world.player.is_silenced():return
	for id: String in on:
		if not bool(on[id]) or float(clocks.get(id,0))>0:continue
		var record: Dictionary=service.catalog.record_for(id)
		if record.is_empty() or not service.catalog.enabled(record):continue
		var skill: Dictionary=service.catalog.resolve(record)
		if str(skill.get("progression523",{}).get("kind",""))!="aura":continue
		var config: RefCounted=source().progression_rules
		var detail:=spec(record)
		if detail.is_empty():continue
		var aura:=RULES.node_for(detail.graph,99231)
		var seconds:=RECOVERY.values(aura,"SpellBuffDuration","Seconds")
		if seconds.size()!=1:continue
		var count:=0
		for child: Node in world.monsters_root.get_children():
			if not child is TwilightMonster or child.dead or child.is_boss or child.concealed523:continue
			if child.global_position.distance_to(world.player.global_position)>maxf(24,config.value(id,"radius")) or not world._has_line_of_sight_world(world.player.global_position,child.global_position):continue
			child.aggro_remaining=maxf(child.aggro_remaining,float(seconds[0]));count+=1
			if count>=int(aura.row.TargetLimitCount):break
		clocks[id]=maxf(.1,config.value(id,"interval"))
		if count>0:fired[id]=int(fired.get(id,0))+1;service.vfx.emit_skill(id,"impact",world.player.global_position)

func update_light() -> void:
	var radius: float=service.catalog.stat("lightRadius")
	if radius<=0 or service.world.hp<=0:
		if is_instance_valid(light):light.hide()
		return
	if not is_instance_valid(light):
		light=PointLight2D.new();light.name="Source523PassiveLight";light.position=Vector2(0,-30);light.energy=.35
		var gradient:=Gradient.new();gradient.colors=PackedColorArray([Color(1,.95,.7,.6),Color(1,.95,.7,0)])
		var texture:=GradientTexture2D.new();texture.width=256;texture.height=256;texture.gradient=gradient
		texture.fill=GradientTexture2D.FILL_RADIAL;texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(1,.5)
		light.texture=texture;service.world.player.add_child(light)
	light.texture_scale=radius/128.0;light.show()

func ammo_problem(skill: Dictionary) -> String:
	if not skill.has("progression523"):return ""
	var kind: String=skill.progression523.kind
	if kind!="rapid" and not bool(skill.get("source523_repeated_attack",false)):return ""
	var ammo: String=service.world._current_ammo_name()
	if not ammo.is_empty() and not service.world._ammo_worn(ammo,true):return ammo+" 미착용"
	return ""

func _apply_reviewed_child_element_input(skill: Dictionary, record: Dictionary, detail: Dictionary, node: Dictionary) -> Dictionary:
	# The caller has already selected this reviewed execution effect. Read its
	# own direct original element; never search another child or traverse a graph.
	if service==null or not skill.get("source523") is Dictionary: return skill
	var adapter: RefCounted = source()
	var profile_type: Script = adapter.get_script()
	var constants: Dictionary = profile_type.get_script_constant_map()
	var definitions: Variant = constants.get("SOURCE_ROWS")
	var channels: Variant = constants.get("SOURCE_ELEMENT_CHANNELS")
	var pin: Variant = constants.get("SOURCE_SHA")
	if not definitions is Script or not channels is Dictionary or not pin is String: return skill
	var id: String = str(record.get("id",""))
	var profile: Dictionary = adapter.profiles.get(id,{})
	var binding: Dictionary = adapter.bindings.get("skills",{}).get(id,{})
	var rule: Dictionary = adapter.progression_rules.rules.get(id,{})
	if profile.is_empty() or binding.is_empty() or rule.get("kind") not in ["repeat","static"] or detail.get("meta",{}).get("kind")!=rule.kind: return skill
	if adapter.bindings.get("source_zip_sha256")!=pin or not adapter._profile_problem(id,profile,binding).is_empty(): return skill
	var graph: Dictionary = adapter.progression_rules.graph_for(id,profile)
	if graph.is_empty() or graph!=detail.get("graph",{}): return skill
	var effect_id: Variant = rule.get("effect_id")
	if not profile_type._source_integer(effect_id): return skill
	var selected: Dictionary = RULES.node_for(graph,int(effect_id))
	if selected.is_empty() or selected!=node or not node.get("row") is Dictionary or node.row.get("ID")!=effect_id: return skill
	var identity: Dictionary = definitions.identity()
	if identity.is_empty() or identity.get("source_sha256")!=pin: return skill
	var root: Dictionary = profile.row
	var roots: Array = definitions.related("SpellClass","ID",int(root.ID))
	if roots.size()!=1 or roots[0]!=root or root.get("TestSpell") is not bool or root.TestSpell or not definitions.declared_exclusion("SpellClass",root).is_empty(): return skill
	var children: Array = definitions.related("SpellClass","ID",int(effect_id))
	if children.size()!=1 or children[0]!=node.row: return skill
	var child: Dictionary = children[0]
	if not profile_type._source_integer(child.get("SpellCompositionNode")) or child.SpellCompositionNode!=0 or child.get("TestSpell") is not bool or child.TestSpell or not definitions.declared_exclusion("SpellClass",child).is_empty(): return skill
	var element_id: Variant = child.get("ElementalTypeID")
	if not profile_type._source_integer(element_id) or int(element_id)<0: return skill
	var elements: Array = definitions.related("ElementalType","ID",int(element_id))
	if elements.size()!=1 or not definitions.declared_exclusion("ElementalType",elements[0]).is_empty(): return skill
	var element: Dictionary = elements[0]
	if not channels.has(element.get("Name")) or not channels[element.Name] is String: return skill
	var applied: Variant = skill.source523.get("applied")
	if not applied is Array: return skill
	var prior: Variant = skill.get("element")
	skill["element"] = channels[element.Name]
	if not applied.has("element"): applied.append("element")
	skill.source523["reviewed_child_element_input"] = {"source":identity,"root_spell_id":root.ID,
		"root_bound_row_sha256":binding.row_sha256,"execution_spell_id":effect_id,"source_child_spell":child.duplicate(true),
		"source_field":"SpellClass.ElementalTypeID","elemental_type":element.duplicate(true),
		"prior_host_element":prior,"host_element_input":skill.element,
		"mapping":"existing_SOURCE_ELEMENT_CHANNELS","scope":"existing_selected_reviewed_execution_effect_only"}
	return skill


func repeat_skill(record: Dictionary) -> Dictionary:
	var detail:=spec(record)
	if detail.is_empty() or str(detail.meta.kind)!="repeat":return {}
	var id: String=str(record.id)
	var rule: Dictionary=source().progression_rules.rules[id]
	var effect:=RULES.node_for(detail.graph,int(rule.effect_id))
	var hits:=RECOVERY.values(effect,"SpellAttackMultiple","Value")
	var attack:=RECOVERY.values(effect,"SpellAttackType","AttackTypeID")
	if hits.size()!=1 or attack.size()!=1 or int(effect.row.TargettingTypeID)!=2 or int(effect.row.TargetAreaRadius)!=0 or not effect.costs.is_empty():return {}
	var skill: Dictionary=service.catalog.resolve(record)
	var policy: RefCounted=source().progression_rules
	skill.merge({"activation":"active","mode":"attack","shape":"single","targets":1,"hits":int(hits[0]),"attack_type":"ranged" if int(attack[0])==2 else "melee","element":"physical","mp":int(effect.row.MPCost),"hp":int(effect.row.HPCost),"items":{},"power":int(policy.value(id,"power")),"range":maxf(24,policy.value(id,"range")),"cast_time":clampf(policy.value(id,"cast_time"),.14,5),"cooldown":maxf(.1,policy.value(id,"cooldown")),"source523_repeated_attack":true,"execution_spell_id":int(effect.row.ID)},true)
	if int(effect.row.SpellMaterialItemAmount)>0:return {}
	skill.source523.target_kind=effect.target_kind.Name
	if int(attack[0])==2:skill.items={"화살":int(hits[0])};skill.weapons=["활"]
	return _apply_reviewed_child_element_input(skill,record,detail,effect)

func try_repeat(target: TwilightMonster) -> bool:
	if not is_instance_valid(target) or target.dead:return false
	for id: String in on:
		if not bool(on[id]):continue
		var record: Dictionary=service.catalog.record_for(id)
		if record.is_empty() or not service.catalog.enabled(record):continue
		var skill:=repeat_skill(record)
		if skill.is_empty():continue
		var world: Node=service.world
		if world.hp<=0 or world.player.motion.dead or world.player.is_stunned() or world.player.is_feared() or world.player.is_silenced() or not world.pending_attack.is_empty() or world.skill_global_cooldown>0 or float(world.skill_cooldowns.get(str(record.name),0))>0:return false
		if service.catalog.level_locked(record) or not ammo_problem(skill).is_empty() or not service.cost_reason(skill).is_empty():return false
		if service.world.player.global_position.distance_to(target.global_position)>float(skill.range) or not service.world._has_line_of_sight_world(service.world.player.global_position,target.global_position):return false
		if not service.catalog.SOURCE523.target_allowed(skill,target):return false
		# Queue first; a refused motion never spends. Validation and payment are synchronous.
		if not service.world._queue_player_attack(target,str(skill.attack_type),service.impact.bind(skill,target),float(skill.cast_time),false,float(skill.range)):return false
		if not service.spend(skill):service.world._clear_combat_actions();return false
		service.world.pending_attack["original_skill"]=skill
		service.world.pending_attack["original_target_life_id"]=target.life_id
		service.world.skill_cooldowns[str(record.name)]=float(skill.cooldown)*service.world._skill_cooldown_factor()
		service.world.skill_global_cooldown=.3
		service.world._break_invisibility();service.vfx.begin_cast(str(id),service.world.player,target)
		service.world._update_hud()
		return true
	return false

func on_normal_hit(target: TwilightMonster, source_skill: Dictionary) -> void:
	if not source_skill.is_empty() or not is_instance_valid(target) or target.dead:return
	var id: String="lm_b08f206fe97abc83"
	var record: Dictionary=service.catalog.record_for(id)
	if record.is_empty() or not is_on(record) or not service.catalog.enabled(record) or float(clocks.get(id,0))>0:return
	var detail:=spec(record)
	if detail.is_empty():return
	var option:=RULES.option_for(detail.graph,19153,"Attack_Spell")
	var parent:=RULES.node_for(detail.graph,70961)
	var chances: Array=[]
	for buff: Dictionary in parent.buffs:
		for entry: Dictionary in buff.bonuses:
			if str(entry.type.Name)=="InvokeOption" and int(entry.link.MinSpellLevel)==0 and int(entry.bonus.BonusApplicationTypeID)==10 and int(entry.bonus.BonusApplicationTargetID)==19153:chances.append(float(entry.bonus.Value)/(source().recovery_rules.percent_denominator*100))
	if chances.size()!=1:return
	var bridge: Dictionary=source().bindings.material_inventory_keys.get(str(int(option.MaterialTypeID)),{})
	if bridge.is_empty() or source().material_holds.has(str(int(option.MaterialTypeID))):return
	var skill: Dictionary=service.catalog.resolve(record)
	skill.merge({"mode":"attack","shape":"self_circle","attack_type":"melee","element":"physical","items":{str(bridge.inventory_key):int(option.MaterialAmount)},"targets":6,"stats":{}},true)
	skill.source523.target_kind="Enemy";skill.source523.applied=["materials","reviewed_execution"]
	var effect:=RULES.node_for(detail.graph,107963)
	var base:=RECOVERY.values(effect,"SpellDamageBase","Value")
	var dice:=RECOVERY.values(effect,"SpellDamageDiceNumber","Value")
	var sides:=RECOVERY.values(effect,"SpellDamageDiceSpotCount","Value")
	if base.size()!=1 or dice.size()!=1 or sides.size()!=1:return
	skill = _apply_reviewed_child_element_input(skill,record,detail,effect)
	if not service.cost_reason(skill).is_empty() or service.world.rng.randf()>=float(chances[0]):return
	if not service.spend(skill):return
	var policy: RefCounted=source().progression_rules
	skill["power"]=int(base[0]);skill["radius"]=maxf(24,policy.value(id,"radius"))
	for _die: int in range(clampi(int(dice[0]),0,100)):
		skill.power+=int((int(sides[0])+1)/2.0) if policy.value(id,"average_dice")>=.5 else service.world.rng.randi_range(1,int(sides[0]))
	clocks[id]=maxf(.1,policy.value(id,"interval"))
	skill = _apply_reviewed_child_element_input(skill,record,detail,effect)
	for victim: TwilightMonster in service.targets(skill,null):service.deal_damage(skill,victim)
	fired[id]=int(fired.get(id,0))+1
	service.world.hud.show_message("스태틱 필드 발동 · 번개석 "+str(int(option.MaterialAmount))+"개")
