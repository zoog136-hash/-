extends RefCounted
## Optional host-clock adapter. Does not claim native AI/selection/geometry/formulas.
const DEFAULT_MANIFEST_SHA = "ca260fc0481076fd9de0327cbb4b24df45d75d47d16b4fc6578713a44aff4a64"
const CATALOG = preload("res://scripts/monsters/patch523_npc_catalog.gd")
const DEFAULT_EFFECT_SHA = "507d5e16fe860ad38960adabc2673693fb9479adff3e4b5294561c78c73c54cf"
const PREVIOUS_EFFECT_SHA = "f9e9ce484e45e83fa0cb98a60a3778dc0f482d59968bda4c7ac6a8a602b79f2d"
var catalog: CATALOG = CATALOG.new()
var source_effects = preload("res://scripts/monsters/patch523_effect_frames.gd").new()
var compatibility = preload("res://scripts/monsters/patch523_boss_compat.gd").new()
var extensions = preload("res://scripts/monsters/patch523_npc_extensions.gd").new()
var world: Node
var host_enabled: bool = false
var pending: Dictionary = {}
var cursor: Dictionary = {}
var followups: Dictionary = {}
var effect_status: Dictionary = {}
var player_buffs: Dictionary = {}
var last_event: Dictionary = {}
var generation: int = -1
var effects: Array[Node2D] = []
var effect_manifest: String = ""
var effect_manifest_sha: String = ""
var input_status: Dictionary = {}

func configure(scene: Node) -> bool:
	world = scene
	var path: String = ""; var digest: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-npc-catalog="): path = arg.trim_prefix("--patch523-npc-catalog=")
		if arg.begins_with("--patch523-npc-sha256="): digest = arg.trim_prefix("--patch523-npc-sha256=")
		if arg == "--patch523-host-combat": host_enabled = true
		if arg.begins_with("--patch523-effect-manifest="): effect_manifest = arg.trim_prefix("--patch523-effect-manifest=")
		if arg.begins_with("--patch523-effect-manifest-sha256="): effect_manifest_sha = arg.trim_prefix("--patch523-effect-manifest-sha256=")
	source_effects.load_settings()
	# Original data and visual delivery are independent. No old manifest is
	# selected as a default/fallback, and no unowned new visual pin is fabricated.
	source_effects.records.clear()
	source_effects.root_path = ""
	source_effects.error = "current523_visual_pin_pending"
	var loaded: bool = catalog.configure_original()
	input_status = {"mode":"current523_original","legacy_catalog_input_ignored":not path.is_empty() or not digest.is_empty(),
		"legacy_effect_input_deferred":not effect_manifest.is_empty() or not effect_manifest_sha.is_empty(),
		"visual":"independent_current_visual_pin_required"}
	compatibility.configure(self)
	extensions.configure(self)
	return loaded

func clear() -> void:
	extensions.clear()
	compatibility.clear()
	if is_instance_valid(world) and is_instance_valid(world.get("player")):
		world.player.set("source_523_movement_blocked",false)
	var old_actions: Array = pending.values()
	pending.clear(); cursor.clear(); followups.clear(); player_buffs.clear(); last_event.clear(); effect_status.clear()
	sync_restrictions()
	for action: Dictionary in old_actions:
		var actor: Node = action.actor.get_ref()
		if is_instance_valid(actor) and int(actor.life_id) == int(action.life) and actor.motion.get_instance_id() == int(action.motion_id) and int(actor.motion.sequence) == int(action.sequence):
			actor.motion.cancel_attack()
	for effect: Node2D in effects:
		if is_instance_valid(effect): effect.clear(); effect.queue_free()
	effects.clear()

func tick(delta: float) -> void:
	if int(world.get("combat_generation")) != generation or int(world.get("hp")) <= 0:
		clear(); generation = int(world.get("combat_generation"))
	if host_enabled: extensions.tick_player(delta)
	for id: int in player_buffs.keys():
		player_buffs[id].remaining -= maxf(0.0,delta)
		if float(player_buffs[id].remaining) <= 0.0: player_buffs.erase(id)
	if is_instance_valid(world.get("player")):
		world.player.set("source_523_movement_blocked",blocks("CannotMove"))
	for key: int in pending.keys():
		var action: Dictionary = pending[key]
		var actor: Node = action.actor.get_ref()
		if not valid_action(actor,action) or not actor.motion.active or int(actor.motion.sequence) != int(action.sequence):
			compatibility.remove_marker(action.get("compat_warning")); pending.erase(key)
	for key: int in followups.keys():
		var action: Dictionary = followups[key]
		var actor: Node = action.actor.get_ref()
		if not valid_action(actor,action) or int(actor.motion.sequence) != int(action.sequence) or actor.is_stunned() or actor.is_feared() or not actor._target_attackable() or bool(actor.get("returning_home")) or silenced_for_attack(actor,action.attack): followups.erase(key)
	effects = effects.filter(func(effect: Node2D) -> bool: return is_instance_valid(effect) and not effect.is_queued_for_deletion())
	compatibility.tick(delta)
	sync_restrictions()
	extensions.tick_environment(delta)

func forget(actor: Node) -> void:
	extensions.forget_actor(actor)
	compatibility.forget(actor)
	var action: Dictionary = pending.get(actor.get_instance_id(),{})
	pending.erase(actor.get_instance_id()); cursor.erase(actor.get_instance_id()); followups.erase(actor.get_instance_id())
	for effect: Node2D in effects.duplicate():
		if is_instance_valid(effect) and (effect.get_parent() == actor or int(effect.get_meta("patch523_owner_id",0)) == actor.get_instance_id()):
			effect.clear(); effect.queue_free(); effects.erase(effect)
	if not action.is_empty() and int(actor.life_id) == int(action.life) and actor.motion.get_instance_id() == int(action.motion_id) and int(actor.motion.sequence) == int(action.sequence): actor.motion.cancel_attack()

func valid_actor(actor: Node) -> bool:
	if not is_instance_valid(actor) or bool(actor.get("dead")): return false
	var id: int = int(actor.get("source_m_npc_id"))
	var source: Dictionary = catalog.row("NpcClass",id)
	var original: Variant = actor.get("source_m_original")
	return not source.is_empty() and not bool(source.get("TestNPC",false)) and original is Dictionary and int(original.get("ID",-1)) == id and int(original.get("Sprite",-1)) == int(source.get("Sprite",-2))

func owns_actor(actor: Node) -> bool:
	return host_enabled and valid_actor(actor)

func valid_action(actor: Node, action: Dictionary) -> bool:
	return valid_actor(actor) and int(actor.get("life_id")) == int(action.life) and actor.motion.get_instance_id() == int(action.motion_id) and int(world.get("combat_generation")) == int(action.generation) and is_instance_valid(world.get("player")) and world.player.get_instance_id() == int(action.target) and int(world.get("hp")) > 0

func status_plan(spell_id: int) -> Dictionary:
	var duration: Vector2 = catalog.duration(spell_id)
	if duration.x <= 0 or duration.y < duration.x or duration.y > 86400: return {}
	var buffs: Array = []
	for value: Variant in catalog.values("SpellBonus",spell_id,"BuffClassID","BuffClassID"):
		var id: int = int(value)
		var supported: Dictionary = buff_values(id)
		if not supported.is_empty(): buffs.append({"id":id,"values":supported})
	return {"duration":duration,"buffs":buffs} if not buffs.is_empty() else {}

func buff_values(id: int) -> Dictionary:
	var result: Dictionary = {}
	for name: String in ["CannotMove","CannotUseItem","CannotAttack","CannotCastSpell","CannotCastSkill","CannotLoot","CannotTeleport","Stunned"]:
		if catalog.scalar("BuffBonus",id,name,"TrueFalse") == 1: result[name] = 1
	for name: String in ["MeleeHit","ArmorClassBonus","HPHealDecreasePercent","HPPotionDecreasePercent","PoisonDamageDiceNumber","PoisonDamageDiceSpotCount","DamageReduction"]:
		var values: Array = catalog.values("BuffBonus",id,name)
		if values.size() == 1: result[name] = values[0]
	return result

func sync_restrictions() -> void:
	if is_instance_valid(world) and is_instance_valid(world.get("player")):
		world.player.set("source_523_movement_blocked",blocks("CannotMove"))
		if world.player.has_method("set_source_523_restrictions"):
			world.player.set_source_523_restrictions({"spell":blocks("CannotCastSpell"),"stunned":blocks("Stunned"),"attack":blocks("CannotAttack"),"skill":blocks("CannotCastSkill")})

func damage_spec(attack: Dictionary, spell: Dictionary = {}) -> Dictionary:
	var id: int = int(spell.get("ID",0))
	var native_spell: bool = bool(attack.get("IsSpell",false))
	var base: int = int(catalog.scalar("SpellBonus",id,"SpellDamageBase","Value")) if native_spell else int(attack.get("DiceBonus",0))
	var count: int = int(catalog.scalar("SpellBonus",id,"SpellDamageDiceNumber","Value")) if native_spell else int(attack.get("DiceCount",0))
	var spots: int = int(catalog.scalar("SpellBonus",id,"SpellDamageDiceSpotCount","Value")) if native_spell else int(attack.get("DiceSpots",0))
	if base < 0 or count < 0 or count > 1000 or spots < 0 or spots > 1000000 or (count > 0 and spots <= 0) or (base == 0 and count == 0): return {}
	return {"base":base,"count":count,"spots":spots}

func guard_attack_kind(spell: Dictionary, fallback: String = "magic") -> String:
	# SpellAttackType is a typed guard context, not a replacement damage formula.
	var id: int = int(spell.get("ID",0))
	if id <= 0 or catalog.row("SpellClass",id).is_empty(): return fallback
	var found: Array = []
	for detail: Dictionary in catalog.bonuses("SpellBonus",id):
		if detail.type.get("Name","") != "SpellAttackType": continue
		if int(detail.type.get("UnitID",-1)) != 10431 or int(detail.unit.get("ID",-1)) != 10431 or detail.unit.get("Name","") != "AttackTypeID": return fallback
		if int(detail.link.get("MinSpellLevel",0)) != 0 or int(detail.bonus.get("BonusApplicationTypeID",-1)) != 0 or int(detail.bonus.get("BonusApplicationTargetID",-1)) != 0: return fallback
		var value: Variant = detail.bonus.get("Value")
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value) != floorf(float(value)): return fallback
		var attack: int = int(value)
		var expected: String = str({1:"Melee",2:"Range",3:"Magic"}.get(attack,""))
		if expected.is_empty() or catalog.row("AttackType",attack).get("Name","") != expected: return fallback
		found.append({1:"melee",2:"ranged",3:"magic"}[attack])
	return str(found[0]) if found.size() == 1 else fallback

func support_reason(attack: Dictionary) -> String:
	if not bool(attack.get("IsSpell",false)): return "사용 가능 · 기본 공격" if not damage_spec(attack).is_empty() else "기본 피해 정의 확인 필요"
	var id: int = int(attack.get("SpellID",0))
	var spell: Dictionary = catalog.row("SpellClass",id)
	if spell.is_empty(): return "주문 정의 미확보"
	if compatibility.handles(spell): return "사용 가능 · TWILIGHT 자체 후속/지면/소환 규칙"
	if extensions.handles(spell): return "사용 가능 · 자체 대상/해제 계약"
	if bool(spell.get("TestSpell",false)): return "테스트 정의 · 실행 보류"
	if int(spell.get("TargettingTypeID",0)) not in [1,2] or int(spell.get("TargetKindID",0)) != 3: return "대상·장판·소환 해석 필요"
	if not extensions.flat_cost_supported(spell) or (int(spell.get("MPCost",0)) > 0 and not extensions.enabled): return "자원 소모 계약 필요"
	var category: int = int(spell.get("SpellCategoryID",0))
	if category == 4: return "회복 주문 · 대상 선택 해석 필요"
	if category == 8: return "사용 가능 · 일부 상태" if not status_plan(id).is_empty() else "상태 수식·효과 해석 필요"
	if category != 1: return "주문 종류 실행 규칙 필요"
	return "사용 가능 · 공격" if not damage_spec(attack,spell).is_empty() else "피해 정의 확인 필요"

func supported(attack: Dictionary) -> bool:
	return support_reason(attack).begins_with("사용 가능")

func silenced_for_attack(actor: Node, attack: Dictionary) -> bool:
	if not bool(attack.get("IsSpell",false)) or not actor.is_silenced(): return false
	# Caster permission is separate from the target's CannotCastSpell/Skill.
	return catalog.scalar("SpellBonus",int(attack.get("SpellID",0)),"IgnoreCannotCastSpell","TrueFalse") != 1

func try_begin(actor: Node, line_of_sight: bool, explicit_attack_id: int = -1) -> bool:
	if not host_enabled or not valid_actor(actor) or not line_of_sight: return false
	if pending.has(actor.get_instance_id()) or actor.motion.active or float(actor.attack_cooldown) > 0 or actor.is_stunned() or actor.is_feared() or not actor._target_attackable(): return false
	if actor.global_position.distance_to(world.player.global_position) > float(actor.current_attack_range()): return false
	if explicit_attack_id < 0:
		var linked: Dictionary = compatibility.take_ready(actor)
		if not linked.is_empty():
			var source_attack: Dictionary = linked.action.attack
			var child_spell: Dictionary = catalog.row("SpellClass",int(linked.spell_id))
			if compatibility.handles(child_spell) and not (actor.is_silenced() and catalog.scalar("SpellBonus",int(child_spell.ID),"IgnoreCannotCastSpell","TrueFalse") != 1):
				var began: bool = begin_action(actor,source_attack,[],"host_conditional_NextSpell_at_source_minimum_delay",child_spell,linked)
				if began: compatibility.waiting.erase(linked)
				return began
	var key: int = actor.get_instance_id()
	var attack: Dictionary = {}
	var seen: Array = []
	var selection: String = "explicit_host_source_graph_roots"
	if explicit_attack_id > 0:
		attack = catalog.attack(int(actor.source_m_npc_id),explicit_attack_id)
		selection = "explicit_host_start_attack_id"
		followups.erase(key)
		if attack.is_empty(): return false
	elif followups.has(key):
		var queued: Dictionary = followups[key]
		followups.erase(key)
		if valid_action(actor,queued) and int(actor.motion.sequence) == int(queued.sequence):
			attack = queued.attack; seen = queued.chain.duplicate()
			selection = "exact_source_NextAttack_at_host_clock"
	if attack.is_empty():
		var choices: Array = []
		for candidate: Dictionary in catalog.attack_roots(int(actor.source_m_npc_id)):
			if supported(candidate) and not silenced_for_attack(actor,candidate) and extensions.can_start(actor,candidate): choices.append(candidate)
		if choices.is_empty(): return false
		var next: int = int(cursor.get(key,0)) % choices.size()
		attack = choices[next]; cursor[key] = next + 1
	if not supported(attack) or silenced_for_attack(actor,attack) or not extensions.can_start(actor,attack): return false
	return begin_action(actor,attack,seen,selection)

func begin_action(actor: Node, attack: Dictionary, seen: Array, selection: String, spell_override: Dictionary = {}, linked: Dictionary = {}) -> bool:
	var key: int = actor.get_instance_id()
	var native_spell: bool = bool(attack.get("IsSpell",false))
	var kind: String = "magic" if native_spell else str(actor.current_attack_type())
	var style: String = "magic" if native_spell else (str(actor.motion.profile.motion_style) if kind == "melee" else ("bow" if kind == "ranged" else "magic"))
	var sequence: int = actor.motion.begin_attack(minf(.68,float(actor.attack_interval)*.75),world.player.global_position-actor.global_position,style,actor.motion.profile.marker_for(style))
	if sequence < 0: return false
	pending[key] = {"actor":weakref(actor),"life":actor.life_id,"generation":world.combat_generation,"target":world.player.get_instance_id(),"sequence":sequence,"motion_id":actor.motion.get_instance_id(),"attack":attack,"reach":float(actor.current_attack_range()),"kind":kind,"chain":seen}
	if not spell_override.is_empty():
		pending[key]["spell_override"] = spell_override
		pending[key]["compat_point"] = linked.point
		pending[key]["compat_warning"] = linked.marker
	actor.attack_cooldown = preload("res://scripts/monsters/monster_ai_policy.gd").attack_interval(float(actor.attack_interval),bool(actor.enraged))
	actor.velocity = Vector2.ZERO
	var spell: Dictionary = spell_override if not spell_override.is_empty() else catalog.row("SpellClass",int(attack.get("SpellID",0))) if native_spell else {}
	world.show_combat_number(actor.global_position+Vector2(0,-actor.visual_height-22),str(spell.get("Name","기본 공격")),Color("efbd75"))
	last_event = {"phase":"cast","attack_id":attack.ID,"spell_id":spell.get("ID",0),"selection":selection,"native_cast_delay_raw":spell.get("CastDelay",0),"native_fixed_delay_raw":attack.get("FixedDelayTime",0)}
	if native_spell: emit_effect(actor,spell,"CasterEffectSpriteID",actor.global_position)
	return true

func cancel(actor: Node, sequence: int) -> void:
	compatibility.cancel(actor,sequence)
	var action: Dictionary = pending.get(actor.get_instance_id(),{})
	if int(action.get("sequence",-1)) == sequence:
		compatibility.remove_marker(action.get("compat_warning")); pending.erase(actor.get_instance_id())
	var queued: Dictionary = followups.get(actor.get_instance_id(),{})
	if int(queued.get("sequence",-1)) == sequence: followups.erase(actor.get_instance_id())

func release(actor: Node, sequence: int) -> bool:
	var key: int = actor.get_instance_id()
	var action: Dictionary = pending.get(key,{})
	if action.is_empty() or int(action.sequence) != sequence: return false
	pending.erase(key) # Consume before callbacks and reentrant death/map transitions.
	compatibility.remove_marker(action.get("compat_warning"))
	if not valid_action(actor,action) or actor.motion.sequence != sequence or not actor.motion.active or not actor.motion.released or actor.is_stunned() or actor.is_feared() or not actor._target_attackable(): return true
	if actor.global_position.distance_to(world.player.global_position) > float(action.reach) or not world._has_line_of_sight_world(actor.global_position,world.player.global_position): return true
	var attack: Dictionary = action.attack
	var native_spell: bool = bool(attack.get("IsSpell",false))
	var spell: Dictionary = action.get("spell_override",catalog.row("SpellClass",int(attack.get("SpellID",0))) if native_spell else {})
	if native_spell and actor.is_silenced() and catalog.scalar("SpellBonus",int(spell.get("ID",0)),"IgnoreCannotCastSpell","TrueFalse") != 1: return true
	var id: int = int(spell.get("ID",0))
	var hit: bool = false
	if native_spell and int(spell.get("MPCost",0)) > 0:
		if not extensions.enabled or not extensions.flat_cost_supported(spell) or not extensions.can_pay(actor,spell): return true
		actor.mp -= int(spell.MPCost)
	if native_spell and extensions.handles(spell):
		hit = extensions.release(actor,spell,true)
	elif native_spell and compatibility.handles(spell):
		hit = bool(compatibility.release(actor,spell,action).get("hit",false))
	elif not native_spell or int(spell.get("SpellCategoryID",0)) == 1:
		var dice: Dictionary = damage_spec(attack,spell)
		if dice.is_empty(): return true
		var raw: int = int(dice.base)
		for i: int in range(int(dice.count)): raw += world.rng.randi_range(1,int(dice.spots))
		hit = bool(world.resolve_patch523_npc_hit(actor,raw,spell,str(action.kind)))
	else:
		var dice: Dictionary = damage_spec(attack,spell)
		if not dice.is_empty():
			var raw: int = int(dice.base)
			for n: int in int(dice.count): raw += world.rng.randi_range(1,int(dice.spots))
			hit = bool(world.resolve_patch523_npc_hit(actor,raw,spell,str(action.kind)))
		else: hit = world._roll_monster_hit(actor,"magic")
	if not valid_action(actor,action): return true
	last_event = {"phase":"impact","attack_id":attack.ID,"spell_id":id,"host_resolved":hit,"followups":catalog.spell_chain(id).get("next",[]) if native_spell else [],"followup_execution":"NextSpell pending native trigger/target; NextAttack uses explicit host-release contract"}
	if native_spell and compatibility.handles(spell):
		last_event["host_compat_rules"] = compatibility.last_event.duplicate(true)
		last_event["followup_execution"] = "TWILIGHT conditional followup/ground/summon policy; native activation/geometry/membership not asserted"
	if native_spell:
		if hit:
			var plan: Dictionary = {} if extensions.handles(spell) else status_plan(id)
			if not plan.is_empty():
				var chance: float = world._status_effect_chance(int(actor.magic_accuracy),int(actor.monster_level),int(world._effective_mr()),int(world.level))
				if world.rng.randf() < chance:
					for buff: Dictionary in plan.buffs: apply_player_buff(int(buff.id),world.rng.randf_range(plan.duration.x,plan.duration.y),buff.values)
			emit_effect(actor,spell,"SuccessEffectSpriteID",world.player.global_position)
		else: emit_effect(actor,spell,"FailEffectSpriteID",world.player.global_position)
		var center: Vector2 = actor.global_position if int(spell.get("TargettingTypeID",0)) == 1 else world.player.global_position
		emit_effect(actor,spell,"EffectSpriteID",center)
		if hit: emit_effect(actor,spell,"EffectExplosionSpriteID",world.player.global_position)
	if not action.has("spell_override"): queue_next_attack(actor,action)
	return true

func queue_next_attack(actor: Node, action: Dictionary) -> void:
	var next: int = int(action.attack.get("NextAttack",0))
	if next <= 0: return
	var target: Dictionary = catalog.attack(int(actor.source_m_npc_id),next)
	var seen: Array = action.chain.duplicate(); seen.append(int(action.attack.ID))
	var reason: String = ""
	if target.is_empty(): reason = "missing_or_different_npc_attack"
	elif seen.has(next) or seen.size() >= 32: reason = "cycle_or_depth_limit"
	elif not supported(target): reason = support_reason(target)
	if not reason.is_empty():
		last_event["next_attack_pending"] = {"id":next,"reason":reason}
		return
	var queued: Dictionary = action.duplicate()
	queued["attack"] = target; queued["chain"] = seen
	followups[actor.get_instance_id()] = queued
	last_event["queued_next_attack_id"] = next
	last_event["next_attack_clock"] = "after valid host impact attempt; existing recovery/cooldown; native trigger/time not asserted"

func apply_player_buff(id: int, seconds: float, values: Dictionary) -> bool:
	var source: Dictionary = catalog.row("BuffClass",id)
	if source.is_empty() or seconds <= 0 or seconds > 86400: return false
	var group: int = int(source.get("BuffGroupID",0))
	var definition: Dictionary = catalog.row("BuffGroup",group)
	for old_id: int in player_buffs.keys():
		var old_source: Dictionary = catalog.row("BuffClass",old_id)
		if int(old_source.get("BuffGroupID",-1)) == group and old_id != id:
			if definition.is_empty(): return false # No inferred group policy.
			if not bool(definition.get("IsAllowOverlap",false)):
				# Priority numbers remain evidence until replacement ordering is
				# established. Never guess a winning barrier/debuff variant.
				return false
	player_buffs[id] = {"id":id,"remaining":seconds,"values":values.duplicate(true)}
	sync_restrictions()
	return true

func modifier(name: String) -> float:
	var result: float = 0.0
	for buff: Dictionary in player_buffs.values(): result += float(buff.values.get(name,0))
	return result

func blocks(name: String) -> bool:
	return modifier(name) > 0

func remaining_effect_bytes() -> int:
	var result: int = 64*1024*1024
	for effect: Node2D in effects:
		if is_instance_valid(effect) and not effect.is_queued_for_deletion(): result -= int(effect.get_meta("patch523_frame_bytes",0))
	return maxi(0,result)

func emit_effect(actor: Node, spell: Dictionary, field: String, point: Vector2) -> bool:
	var sprite: int = int(spell.get(field,0))
	if sprite <= 0: return false
	var key: String = "%d:%s" % [int(spell.get("ID",0)),field]
	effect_status[key] = {"sprite_id":sprite,"state":"pending"}
	var requested_action: int = int(spell.get("EffectSpriteActionNo",0)) if field == "EffectSpriteID" else -1
	var visual_policy: Variant = actor.get_meta("current523_source_only_visual",{})
	if visual_policy is Dictionary and visual_policy.get("required") == true:
		# The admitted actor's final source policy excludes both former candidate
		# effect packs and old card-manifest overlays. The event owner is unchanged.
		return _emit_source_bank_visual(actor,spell,field,point,key)
	if source_effects.records.has(str(sprite)):
		if effects.size() >= 16: return false
		var pose: Variant = actor.get("motion")
		var candidate: Node2D = source_effects.make_effect(sprite,requested_action,remaining_effect_bytes(),int(pose.facing8) if pose != null else 0)
		if candidate == null:
			effect_status[key].state = "candidate_disabled_budget_or_frame_rejected"; return false
		candidate.set_meta("patch523_owner_id",actor.get_instance_id())
		world.add_child(candidate); candidate.global_position = point; effects.append(candidate)
		effect_status[key].state = "M_source_pixels_candidate_raster_timing_blend; native_runtime_not_verified"
		return true
	# Keep the existing renderer first. Only presentation construction falls
	# through; this caller still owns the admitted Spell, stage, point and limits.
	if _emit_legacy_source_overlay(actor,sprite,requested_action,point,key): return true
	return _emit_source_bank_visual(actor,spell,field,point,key)

func _emit_legacy_source_overlay(actor: Node, sprite: int, requested_action: int, point: Vector2, key: String) -> bool:
	if requested_action > 0:
		effect_status[key].state = "exact_nonzero_action_binding_required"
		last_event["effect_pending"] = "exact_nonzero_action_binding_required"; return false
	if effect_manifest.is_empty() or not FileAccess.file_exists(effect_manifest) or effects.size() >= 16:
		effect_status[key].state = "original_overlay_not_installed_or_budget_full"
		last_event["effect_pending"] = "original_overlay_not_installed_or_budget_full"; return false
	var manifest_file: FileAccess = FileAccess.open(effect_manifest,FileAccess.READ)
	if manifest_file == null or manifest_file.get_length() > CATALOG.MAX_BYTES or effect_manifest_sha.length() != 64 or FileAccess.get_sha256(effect_manifest) != effect_manifest_sha:
		effect_status[key].state = "effect_manifest_pin_or_size_rejected"
		return false
	# Existing renderer consumes declared frames and strict/compatible timing. Use the exact
	# 523 field rather than looking up a numerically equal 508 spell identity.
	var preview = preload("res://scripts/animation/original_source_preview.gd").new()
	if not preview.configure("overlay:"+str(sprite),effect_manifest):
		effect_status[key].state = "exact_overlay_not_available"
		preview.free(); return false
	actor.add_child(preview)
	preview.global_position = point
	preview.set("_overlay_facing",int(actor.motion.facing8))
	effects.append(preview)
	effect_status[key].state = "external_overlay_configured; native_523_pixel_timing_equivalence_not_verified"
	return true

func _emit_source_bank_visual(actor: Node, spell: Dictionary, field: String, point: Vector2, key: String) -> bool:
	if effects.size() >= 16: return false
	var budget: int = remaining_effect_bytes()
	if budget <= 0: return false
	var stage: String = ""
	for name: String in preload("res://scripts/resources/current523_source_effect_selection.gd").STAGES:
		if preload("res://scripts/resources/current523_source_effect_selection.gd").STAGES[name] == field:
			stage = name
			break
	if stage.is_empty(): return false
	var pose: Variant = actor.get("motion")
	var facing: int = int(pose.facing8) if pose != null else 0
	var factory = preload("res://scripts/animation/original_source_preview.gd").new()
	# Keep this effect on the bank selected for its admitted NPC, including
	# an explicit private config. The factory still checks the complete Spell row.
	var source_context: Dictionary = {}
	var selected_visual: Variant = actor.get_meta("current523_source_bank_selection",{})
	# Core body actions can be pending after a successful source selection.
	# Its retained bank context is still the input for this separately admitted
	# Spell event; effect selection performs its own complete-row/pin checks.
	if selected_visual is Dictionary and selected_visual.get("consumer") == "npc" and selected_visual.get("source_snapshot") == "patch523":
		var selected_context: Variant = selected_visual.get("source_bank_context",{})
		if selected_context is Dictionary: source_context = selected_context.duplicate(true)
	var candidate: Node2D = factory.make_current_source_spell_effect(spell,stage,facing,source_context,budget)
	var result: Dictionary = factory.source_effect_status.duplicate(true)
	factory.free()
	effect_status[key]["source_bank"] = result
	if candidate == null: return false
	# Conservatively reserve the available existing budget for this source view.
	# Its shared texture-cache limit also covers independent source children.
	candidate.set_meta("patch523_frame_bytes",budget)
	candidate.set_meta("patch523_owner_id",actor.get_instance_id())
	actor.add_child(candidate)
	candidate.global_position = point
	if not bool(candidate.call("advance_reference_source",0.0,"idle",int(candidate.get("_overlay_facing")))):
		result["ok"] = false
		result["status"] = "initial_source_frame_unavailable"
		result["frame_problem"] = candidate.get("reference_bank_status").duplicate(true)
		candidate.free()
		return false
	effects.append(candidate)
	result["status"] = "configured_existing_source_effect"
	var previous_state: String = str(effect_status[key].get("state","pending"))
	effect_status[key]["previous_renderer_state"] = previous_state
	effect_status[key].state = "current_source_bank_visual; native_trigger_and_composition_unverified"
	if str(last_event.get("effect_pending","")) == previous_state: last_event.erase("effect_pending")
	return true
