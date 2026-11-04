extends RefCounted
## Optional host-clock adapter. Does not claim native AI/selection/geometry/formulas.
const DEFAULT_MANIFEST_SHA = "ca260fc0481076fd9de0327cbb4b24df45d75d47d16b4fc6578713a44aff4a64"
const CATALOG = preload("res://scripts/monsters/patch523_npc_catalog.gd")
var catalog: CATALOG = CATALOG.new()
var world: Node
var host_enabled: bool = false
var pending: Dictionary = {}
var cursor: Dictionary = {}
var player_buffs: Dictionary = {}
var last_event: Dictionary = {}
var generation: int = -1
var effects: Array[Node2D] = []
var effect_manifest: String = ""

func configure(scene: Node) -> bool:
	world = scene
	var path: String = ""; var digest: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-npc-catalog="): path = arg.trim_prefix("--patch523-npc-catalog=")
		if arg.begins_with("--patch523-npc-sha256="): digest = arg.trim_prefix("--patch523-npc-sha256=")
		if arg == "--patch523-host-combat": host_enabled = true
		if arg.begins_with("--patch523-effect-manifest="): effect_manifest = arg.trim_prefix("--patch523-effect-manifest=")
	if path.is_empty():
		path = "user://source_npc523/manifest.json"
		digest = DEFAULT_MANIFEST_SHA
	return FileAccess.file_exists(path) and catalog.load_pack(path, digest)

func clear() -> void:
	if is_instance_valid(world) and is_instance_valid(world.get("player")):
		world.player.set("source_523_movement_blocked",false)
	var old_actions: Array = pending.values()
	pending.clear(); cursor.clear(); player_buffs.clear(); last_event.clear()
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
	for id: int in player_buffs.keys():
		player_buffs[id].remaining -= maxf(0.0,delta)
		if float(player_buffs[id].remaining) <= 0.0: player_buffs.erase(id)
	if is_instance_valid(world.get("player")):
		world.player.set("source_523_movement_blocked",blocks("CannotMove"))
	for key: int in pending.keys():
		var action: Dictionary = pending[key]
		var actor: Node = action.actor.get_ref()
		if not valid_action(actor,action) or not actor.motion.active or int(actor.motion.sequence) != int(action.sequence): pending.erase(key)
	effects = effects.filter(func(effect: Node2D) -> bool: return is_instance_valid(effect) and not effect.is_queued_for_deletion())

func forget(actor: Node) -> void:
	var action: Dictionary = pending.get(actor.get_instance_id(),{})
	pending.erase(actor.get_instance_id()); cursor.erase(actor.get_instance_id())
	for effect: Node2D in effects.duplicate():
		if is_instance_valid(effect) and effect.get_parent() == actor:
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
		var supported: Dictionary = {}
		for name: String in ["CannotMove","CannotUseItem"]:
			if catalog.scalar("BuffBonus",id,name,"TrueFalse") == 1: supported[name] = 1
		for name: String in ["MeleeHit","ArmorClassBonus"]:
			var raw: Array = catalog.values("BuffBonus",id,name,"Value")
			if raw.size() == 1: supported[name] = raw[0]
		if not supported.is_empty(): buffs.append({"id":id,"values":supported})
	return {"duration":duration,"buffs":buffs} if not buffs.is_empty() else {}

func support_reason(attack: Dictionary) -> String:
	if not bool(attack.get("IsSpell",false)): return "기존 기본 공격 경로"
	var id: int = int(attack.get("SpellID",0))
	var spell: Dictionary = catalog.row("SpellClass",id)
	if spell.is_empty(): return "주문 정의 미확보"
	if bool(spell.get("TestSpell",false)): return "테스트 정의 · 실행 보류"
	if int(spell.get("TargettingTypeID",0)) != 2 or int(spell.get("TargetKindID",0)) != 3: return "대상·장판·소환 해석 필요"
	if int(spell.get("MPCost",0)) != 0 or int(spell.get("HPCost",0)) != 0 or int(spell.get("VPCost",0)) != 0 or int(spell.get("SpellMaterialItemAmount",0)) != 0: return "자원 소모 계약 필요"
	var category: int = int(spell.get("SpellCategoryID",0))
	if category == 4: return "회복 주문 · 대상 선택 해석 필요"
	if category == 8: return "사용 가능 · 일부 상태" if not status_plan(id).is_empty() else "상태 수식·효과 해석 필요"
	if category != 1: return "주문 종류 실행 규칙 필요"
	var count: int = int(catalog.scalar("SpellBonus",id,"SpellDamageDiceNumber","Value"))
	var spots: int = int(catalog.scalar("SpellBonus",id,"SpellDamageDiceSpotCount","Value"))
	var base: int = int(catalog.scalar("SpellBonus",id,"SpellDamageBase","Value"))
	if count < 0 or count > 1000 or spots < 0 or spots > 1000000 or (count > 0 and spots <= 0) or base < 0: return "피해 파라미터 범위 확인 필요"
	return "사용 가능 · 공격" if base > 0 or count > 0 else "피해 정의 확인 필요"

func supported(attack: Dictionary) -> bool:
	return support_reason(attack).begins_with("사용 가능")

func try_begin(actor: Node, line_of_sight: bool) -> bool:
	if not host_enabled or not valid_actor(actor) or not line_of_sight: return false
	if pending.has(actor.get_instance_id()) or actor.motion.active or float(actor.attack_cooldown) > 0 or actor.is_stunned() or actor.is_feared() or actor.is_silenced() or not actor._target_attackable(): return false
	if actor.global_position.distance_to(world.player.global_position) > float(actor.current_attack_range()): return false
	var choices: Array = []
	for attack: Dictionary in catalog.owned("NpcAttack",int(actor.source_m_npc_id)):
		if supported(attack): choices.append(attack)
	if choices.is_empty(): return false
	# Deliberate opt-in host round robin, not source Prob/phase/FixedDelayTime interpretation.
	var key: int = actor.get_instance_id()
	var next: int = int(cursor.get(key,0)) % choices.size()
	var attack: Dictionary = choices[next]
	var sequence: int = actor.motion.begin_attack(minf(.68,float(actor.attack_interval)*.75),world.player.global_position-actor.global_position,"magic",actor.motion.profile.marker_for("magic"))
	if sequence < 0: return false
	cursor[key] = next + 1
	pending[key] = {"actor":weakref(actor),"life":actor.life_id,"generation":world.combat_generation,"target":world.player.get_instance_id(),"sequence":sequence,"motion_id":actor.motion.get_instance_id(),"attack":attack,"reach":float(actor.current_attack_range())}
	actor.attack_cooldown = preload("res://scripts/monsters/monster_ai_policy.gd").attack_interval(float(actor.attack_interval),bool(actor.enraged))
	actor.velocity = Vector2.ZERO
	var spell: Dictionary = catalog.row("SpellClass",int(attack.SpellID))
	world.show_combat_number(actor.global_position+Vector2(0,-actor.visual_height-22),str(spell.Name),Color("efbd75"))
	emit_effect(actor,spell,"CasterEffectSpriteID",actor.global_position)
	last_event = {"phase":"cast","attack_id":attack.ID,"spell_id":attack.SpellID,"selection":"explicit_host_round_robin","native_cast_delay_raw":spell.get("CastDelay",0),"native_fixed_delay_raw":attack.get("FixedDelayTime",0)}
	return true

func cancel(actor: Node, sequence: int) -> void:
	var action: Dictionary = pending.get(actor.get_instance_id(),{})
	if int(action.get("sequence",-1)) == sequence: pending.erase(actor.get_instance_id())

func release(actor: Node, sequence: int) -> bool:
	var key: int = actor.get_instance_id()
	var action: Dictionary = pending.get(key,{})
	if action.is_empty() or int(action.sequence) != sequence: return false
	pending.erase(key) # Consume before callbacks and reentrant death/map transitions.
	if not valid_action(actor,action) or actor.motion.sequence != sequence or not actor.motion.active or not actor.motion.released or actor.is_stunned() or actor.is_feared() or actor.is_silenced() or not actor._target_attackable(): return true
	if actor.global_position.distance_to(world.player.global_position) > float(action.reach) or not world._has_line_of_sight_world(actor.global_position,world.player.global_position): return true
	var spell: Dictionary = catalog.row("SpellClass",int(action.attack.SpellID))
	var id: int = int(spell.ID)
	var hit: bool = false
	if int(spell.SpellCategoryID) == 1:
		var raw: int = int(catalog.scalar("SpellBonus",id,"SpellDamageBase","Value"))
		var count: int = int(catalog.scalar("SpellBonus",id,"SpellDamageDiceNumber","Value"))
		var spots: int = int(catalog.scalar("SpellBonus",id,"SpellDamageDiceSpotCount","Value"))
		for i: int in range(count): raw += world.rng.randi_range(1,spots)
		hit = bool(world.resolve_patch523_npc_hit(actor,raw,spell))
	else:
		hit = world._roll_monster_hit(actor,"magic")
	if not valid_action(actor,action): return true
	if hit:
		var plan: Dictionary = status_plan(id)
		if not plan.is_empty():
			# Use host status resistance once; source probability/level equation remains unverified.
			var chance: float = world._status_effect_chance(int(actor.magic_accuracy),int(actor.monster_level),int(world._effective_mr()),int(world.level))
			if world.rng.randf() < chance:
				for buff: Dictionary in plan.buffs:
					apply_player_buff(int(buff.id),world.rng.randf_range(plan.duration.x,plan.duration.y),buff.values)
		emit_effect(actor,spell,"SuccessEffectSpriteID",world.player.global_position)
	else:
		emit_effect(actor,spell,"FailEffectSpriteID",world.player.global_position)
	emit_effect(actor,spell,"EffectSpriteID",world.player.global_position)
	if hit: emit_effect(actor,spell,"EffectExplosionSpriteID",world.player.global_position)
	last_event = {"phase":"impact","attack_id":action.attack.ID,"spell_id":id,"host_resolved":hit,"followups":catalog.spell_chain(id).get("next",[]),"followup_execution":"pending_native_trigger_and_target_contract"}
	return true

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
	return true

func modifier(name: String) -> float:
	var result: float = 0.0
	for buff: Dictionary in player_buffs.values(): result += float(buff.values.get(name,0))
	return result

func blocks(name: String) -> bool:
	return modifier(name) > 0

func emit_effect(actor: Node, spell: Dictionary, field: String, point: Vector2) -> bool:
	var sprite: int = int(spell.get(field,0))
	if sprite <= 0: return false
	if field == "EffectSpriteID" and int(spell.get("EffectSpriteActionNo",0)) != 0:
		last_event["effect_pending"] = "exact_nonzero_action_binding_required"; return false
	if effect_manifest.is_empty() or not FileAccess.file_exists(effect_manifest) or effects.size() >= 16:
		last_event["effect_pending"] = "original_overlay_not_installed_or_budget_full"; return false
	# Existing renderer validates pixels and strict/compatible timing. Use the exact
	# 523 field rather than looking up a numerically equal 508 spell identity.
	var preview = preload("res://scripts/animation/original_source_preview.gd").new()
	if not preview.configure("overlay:"+str(sprite),effect_manifest): preview.free(); return false
	actor.add_child(preview)
	preview.global_position = point
	preview.set("_overlay_facing",int(actor.motion.facing8))
	effects.append(preview)
	return true
