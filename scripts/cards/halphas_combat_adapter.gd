extends RefCounted
## TWILIGHT custom behavior. Native rows are immutable; no native-fidelity claim.
var _owner: WeakRef
var owner: RefCounted:
	get:return _owner.get_ref() if _owner!=null else null
var states: Dictionary={}
var charge: Dictionary={}
var pending_player: Dictionary={}
func configure(runtime: RefCounted) -> void:_owner=weakref(runtime)
func world() -> Node:return owner.world if owner!=null else null
func enabled() -> bool:
	var policy: Variant=owner.settings.get("custom_combat",{}) if owner!=null else {}
	return policy is Dictionary and policy.get("enabled",false)==true and policy.get("charge_time_formula") in ["source_time_divided_by_one_plus_reduction_percent","linear_percent_with_source_minimum"]
func number(key: String, fallback: float, low: float, high: float) -> float:
	var v: Variant=owner.settings.get("custom_combat",{}).get(key,fallback)
	return clampf(float(v),low,high) if (v is int or v is float) and is_finite(float(v)) else fallback
func state(actor: Node) -> Dictionary:
	if not is_instance_valid(actor):return {}
	var found: Dictionary=states.get(actor.get_instance_id(),{})
	if found.is_empty():return {}
	if found.target.get_ref()!=actor or int(found.generation)!=int(world().combat_generation) or (actor is TwilightMonster and int(found.life)!=actor.life_id):
		states.erase(actor.get_instance_id());return {}
	return found
func remaining(actor: Node, kind: String) -> float:return float(state(actor).get(kind,0)) if enabled() else 0.0
func frozen(actor: Node) -> bool:return owner.settings.get("custom_combat",{}).get("ice_blocks_movement_and_actions",true)==true and remaining(actor,"ice")>0.0
func hit_factor(actor: Node) -> float:return number("dark_hit_multiplier",.5,.05,1.0) if remaining(actor,"dark")>0.0 else 1.0
func resistance(actor: Node, kind: String) -> float:
	if actor==world().get("player"):return float(owner.catalog_bonus(kind+"_resistance"))
	return float(actor.get(kind+"_resistance")) if actor is TwilightMonster else 0.0
func apply_status(actor: Node, kind: String, duration: float) -> bool:
	if not enabled() or kind not in ["dark","ice"] or not is_instance_valid(actor) or not (actor is TwilightPlayer or actor is TwilightMonster) or not is_finite(duration) or duration<=0:return false
	if actor is TwilightMonster and (actor.dead or actor.status_immunities.has(kind)):return false
	if actor==world().get("player") and int(world().hp)<=0:return false
	var row: Dictionary=state(actor)
	if row.is_empty():row={"target":weakref(actor),"generation":world().combat_generation,"life":actor.life_id if actor is TwilightMonster else -1}
	row[kind]=maxf(float(row.get(kind,0)),minf(duration,30.0));states[actor.get_instance_id()]=row
	if kind=="ice":
		if actor.has_method("cancel_attack"):actor.cancel_attack()
		elif actor is TwilightMonster:actor.motion.cancel_attack()
		if actor==world().get("player"):world().pending_attack.clear();world()._clear_skill_charge();cancel_charge()
	actor.show_status_text("암흑 · 자체" if kind=="dark" else "동빙 · 자체")
	return true
func incoming(attacker: TwilightMonster) -> void:
	if not enabled():return
	for kind: String in ["dark","ice"]:
		var accuracy: int=int(attacker.get(kind+"_accuracy"));var duration: float=float(attacker.get(kind+"_duration"))
		if accuracy<=0 or duration<=0:continue
		var chance: float=world()._status_effect_chance(accuracy,attacker.monster_level,int(resistance(world().player,kind)),world().level)
		if world().rng.randf()<chance:apply_status(world().player,kind,duration)
func tick(delta: float) -> void:
	if not is_finite(delta) or delta<0:return
	for key: int in states.keys():
		var row: Dictionary=states[key];var actor: Node=row.target.get_ref()
		if not is_instance_valid(actor) or state(actor).is_empty() or (actor is TwilightMonster and actor.dead):states.erase(key);continue
		for kind: String in ["dark","ice"]:row[kind]=maxf(0.0,float(row.get(kind,0))-delta)
		if float(row.get("dark",0))+float(row.get("ice",0))<=0:states.erase(key)
	if charge.is_empty():return
	var target: Node=charge.target.get_ref()
	if not owner.active() or not is_instance_valid(target) or target.dead or target.life_id!=charge.life or charge.generation!=world().combat_generation or world().hp<=0 or world().player.is_stunned() or world().player.is_feared() or world().player.is_silenced() or frozen(world().player):cancel_charge();return
	charge.elapsed+=delta
	if float(charge.elapsed)>number("charge_timeout_seconds",3.0,.5,10.0):cancel_charge()
func cancel_charge() -> void:charge.clear()
func reset() -> void:states.clear();cancel_charge()
func export_player() -> Dictionary:
	var player: Node=world().get("player") if world()!=null else null
	if not is_instance_valid(player):return {}
	return {"dark":remaining(player,"dark"),"ice":remaining(player,"ice")}
static func validate_player(value: Variant) -> bool:
	if not value is Dictionary:return false
	for key: String in value:
		if key not in ["dark","ice"]:return false
		var amount: Variant=value[key]
		if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount)<0 or float(amount)>30:return false
	return true
func restore_player() -> void:
	for kind: String in ["dark","ice"]:
		var time: float=float(pending_player.get(kind,0))
		if time>0:apply_status(world().player,kind,time)
	pending_player.clear()
func step_seconds(source_msec: float) -> float:
	var percent: float=float(owner.effects(int(owner.progress.level)).get("charge_time_reduction_pct",0)) if owner.active() else 0.0
	# Custom reciprocal rule remains positive above100%; source min100ms.
	if owner.settings.get("custom_combat",{}).get("charge_time_formula")=="linear_percent_with_source_minimum":return maxf(.1,source_msec/1000.0*(1.0-maxf(0.0,percent)/100.0))
	return maxf(.1,source_msec/1000.0/(1.0+maxf(0.0,percent)/100.0))
func charge_view() -> Dictionary:
	var elapsed: float=float(charge.get("elapsed",0));var reached: int=0;var total: float=0.0
	for step: Dictionary in owner.Native.DATA.data.charge.steps:
		total+=step_seconds(float(step.Time))
		if elapsed>=total:reached=int(step.Step)
	return {"active":not charge.is_empty(),"elapsed":elapsed,"stage":reached,"total":total}
func start_charge() -> Dictionary:
	if not enabled() or not owner.active():return owner.fail("charge_disabled","할파스 장착·자체 전투·활성 조건이 필요합니다")
	if not charge.is_empty():return owner.fail("charging","이미 자체 차징 중입니다")
	var record: Dictionary=world().original_skills.catalog.record_for("쇼크 스턴")
	if record.is_empty() or not world().original_skills.ready(record,true):return owner.fail("skill","습득한 쇼크 스턴의 직업·레벨·무기·MP·재사용 조건이 필요합니다")
	var skill: Dictionary=world().original_skills.catalog.resolve(record)
	var target: TwilightMonster=world()._skill_target(float(skill.range)+3.0*number("charge_tile_pixels",48.0,1.0,128.0))
	if not is_instance_valid(target):return owner.fail("target","차징 대상이 없습니다")
	charge={"target":weakref(target),"life":target.life_id,"generation":world().combat_generation,"elapsed":0.0,"skill":skill}
	return {"ok":true}
func release_charge() -> Dictionary:
	var info: Dictionary=charge_view()
	if not info.active or int(info.stage)<1:return owner.fail("charge_stage","자체 차징1단계가 필요합니다")
	var current: Dictionary=charge.duplicate();var target: Node=current.target.get_ref()
	if not is_instance_valid(target) or target.dead or target.life_id!=current.life or current.generation!=world().combat_generation or not owner.active():cancel_charge();return owner.fail("target","차징 대상·생명이 변경됐습니다")
	var skill: Dictionary=current.skill.duplicate(true)
	for effect: Dictionary in owner.Native.DATA.data.charge.effects:
		if int(effect.step)!=int(info.stage) or effect.type.Name!="SpellRangeBonus":continue
		skill.range=float(skill.range)+float(effect.bonus.Value)*number("charge_tile_pixels",48.0,1.0,128.0)
	if world().player.global_position.distance_to(target.global_position)>float(skill.range) or not world()._has_line_of_sight_world(world().player.global_position,target.global_position):cancel_charge();return owner.fail("target","차징 대상이 사거리 밖이거나 가려졌습니다 · 소비 없음")
	# Resolve the same paid skill once. Never grant a new skill or double-pay.
	cancel_charge();world().selected_monster=target
	if not world().original_skills.cast(skill):return owner.fail("cast","현재 시전 조건을 충족하지 못했습니다 · 추가 소비 없음")
	return {"ok":true,"stage":int(info.stage),"range":float(skill.range)}
