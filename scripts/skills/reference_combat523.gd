extends RefCounted
## Local PvE receivers for the public-reference catalog. Persistent status and
## resource ownership stay with the existing skill, actor and inventory owners.
var damage_link: Dictionary = {}


static func uses_local_effect(skill: Dictionary) -> bool:
	return bool(skill.get("reference_approx523", false)) or bool(skill.get("reference_upgrade523", false))

func clear() -> void:
	damage_link.clear()

static func forward_landing(world: Node, skill: Dictionary, target: TwilightMonster) -> Vector2:
	var origin: Vector2 = world.player.global_position
	var direction: Vector2 = world.player.motion.direction.normalized()
	if direction.is_zero_approx(): direction = Vector2.DOWN
	var distance: float = clampf(float(skill.get("dash_distance", 140)), 16, 320)
	if is_instance_valid(target):
		direction = origin.direction_to(target.global_position)
		distance = maxf(0, origin.distance_to(target.global_position) - 26.0)
	var steps := maxi(1, ceili(distance / 8.0))
	var landing := origin
	for step: int in range(1, steps + 1):
		var point := origin + direction * (distance * float(step) / float(steps))
		if not world._is_walkable_world(point) or (world.field_map != null and not world.field_map.point_clear(point, 4.0)) \
			or not world._has_line_of_sight_world(landing, point):
			if is_instance_valid(target): return Vector2.INF
			break
		landing = point
	if not is_instance_valid(target) and landing.distance_squared_to(origin) < 40.0: return Vector2.INF
	return landing

static func apply_cast_effects(service, skill: Dictionary) -> void:
	var world: Node = service.world
	TwilightSkillStatusService.cleanse(world.player, skill.get("reference_cleanse", []))
	for name: String in skill.get("reference_reset_skills", []):
		world.skill_cooldowns.erase(name)
	if skill.get("mode") == "heal":
		world.mp = mini(world._effective_max_mp(),world.mp + int(skill.get("mana", 0)))
	if skill.get("reference_mark_nearest", false):
		var target: TwilightMonster = world._skill_target(float(skill.radius))
		if is_instance_valid(target):
			service.status.set_modifiers(target, "reference:" + str(skill.id), float(skill.duration), {"taken":.05})
			service._emit_verified_source_effect(skill, "success", target.combat_hit_position())
	var kind: String = str(skill.get("reference_deck", ""))
	if kind.is_empty(): return
	# A class spell can activate an already owned selected look. Ownership,
	# card effects and a player's saved deck selection are unchanged.
	world.apply_reference_skill_look(kind)

static func temporary_buff(service, skill: Dictionary) -> void:
	var config: Dictionary = skill.get("reference_self_buff", {})
	if config.is_empty(): return
	var buff: Dictionary = skill.duplicate(false)
	buff.merge(config, true)
	buff.erase("reference_pulse")
	buff["mode"] = "buff"
	service.apply_buff(buff)

func contact(service, skill: Dictionary, target: TwilightMonster, damage: int) -> void:
	var world: Node = service.world
	var steal: float = float(skill.get("reference_lifesteal", 0))
	if damage > 0 and steal > 0:
		world.hp = mini(world._effective_max_hp(), world.hp + mini(100, int(damage * steal)))
	if not is_instance_valid(target) or target.dead: return
	var id: String = "reference:" + str(skill.id)
	var duration: float = float(skill.get("duration", 5))
	if skill.get("reference_dispel", false):
		world.patch523_npc_spells.extensions.dispel_reference_target(target)
	if skill.get("reference_taunt", false):
		target.aggro_remaining = maxf(target.aggro_remaining, duration)
	if skill.get("reference_pull", false) and not target.is_boss:
		_pull(world, target)
	var mana: int = mini(target.mp, int(skill.get("reference_mana_gain", 0)))
	if mana > 0:
		mana = mini(mana, world._effective_max_mp() - world.mp)
		target.mp -= mana
		world.mp += mana
	var modifiers: Dictionary = skill.get("reference_debuff", {})
	if not modifiers.is_empty():
		service.status.set_reference_modifiers(target, id, duration, modifiers, int(skill.get("reference_debuff_stacks", 1)),
			bool(skill.get("reference_one_magic", false)))
	var extension: float = float(skill.get("reference_extend_debuff", 0))
	if extension > 0: service.status.extend_reference_modifiers(target, extension)
	var tick: int = int(skill.get("reference_dot", 0))
	if tick > 0:
		service.status.apply({"id":skill.id,"status":"bleed","status_chance":1.0,"duration":float(skill.get("reference_dot_seconds", 4)),
			"tick_damage":tick,"tick_interval":1.0}, target, world)
	var heal_amount: int = int(skill.get("reference_self_heal",0))
	if heal_amount > 0: service.heal(skill, heal_amount)

func status_applied(service, skill: Dictionary, target: TwilightMonster) -> void:
	contact(service, skill, target, 0)
	var fraction: float = float(skill.get("reference_damage_link", 0))
	if fraction > 0:
		damage_link = {"target":weakref(target),"life_id":target.life_id,"fraction":fraction,
			"range":float(skill.get("range",240)),"remaining":float(skill.get("reference_status_duration", 5))}
	var execute: int = int(skill.get("reference_status_execute", 0))
	if execute > 0 and service.world.rng.randf() < .25 and not target.dead:
		target.take_damage(execute + mini(100, int(float(target.max_hp - target.hp) * .06)), false, "skill_status")

static func _pull(world: Node, target: TwilightMonster) -> void:
	var start: Vector2 = target.global_position
	var toward: Vector2 = world.player.global_position
	var landing: Vector2 = start.move_toward(toward, clampf(start.distance_to(toward) - 30.0, 0, 135))
	if not world._is_walkable_world(landing) or (world.field_map != null and not world.field_map.point_clear(landing, 4.0)): return
	if world._has_line_of_sight_world(start, landing): target.global_position = landing

func tick_link(delta: float) -> void:
	if damage_link.is_empty(): return
	damage_link.remaining -= delta
	if float(damage_link.remaining) <= 0: damage_link.clear()

func linked_damage(service, amount: int) -> int:
	if damage_link.is_empty() or amount <= 0: return amount
	var target: TwilightMonster = damage_link.target.get_ref()
	if not TwilightSkillStatusService.same_life(damage_link, target) or target.dead:
		damage_link.clear()
		return amount
	if target.global_position.distance_squared_to(service.world.player.global_position) > float(damage_link.range) ** 2:
		target.apply_hold(float(damage_link.remaining))
		damage_link.clear()
		return amount
	var moved: int = int(amount * float(damage_link.fraction))
	if moved > 0: target.take_damage(moved, false, "skill_reflected")
	return amount - moved

static func pulse(service, name: String, buff: Dictionary, delta: float) -> void:
	var config: Dictionary = buff.get("reference_pulse", {})
	if config.is_empty(): return
	buff["pulse_clock"] = float(buff.get("pulse_clock", 0.0)) - delta
	if float(buff.pulse_clock) > 0.0: return
	buff.pulse_clock = float(config.interval)
	var world: Node = service.world
	var mana: int = int(config.get("mp", 0)) + ceili(float(config.get("mp_percent", 0)) * world._effective_max_mp())
	if mana > 0 or not config.get("items", {}).is_empty():
		var payment: Dictionary = {"id":buff.skill_id,"reference_approx523":true,"mp":mana,"items":config.get("items", {})}
		if not service.spend(payment):
			world.active_skill_buffs.erase(name)
			return
	TwilightSkillStatusService.cleanse(world.player, config.get("cleanse", []))
	var radius: float = float(config.get("radius", 0))
	if radius <= 0: return
	var skill: Dictionary = service.catalog.resolve(service.catalog.record_for(str(buff.skill_id)))
	for target: TwilightMonster in service.targets({"shape":"self_circle","radius":radius,"targets":4},null):
		var amount: int = int(config.get("damage", 0))
		if amount > 0: target.take_damage(amount, false, "skill_pulse")
		if not target.dead:
			service.status.set_modifiers(target, "reference:" + str(buff.skill_id), float(config.interval), config.get("modifiers", {}))
			if config.has("slow"): target.apply_slow(float(config.interval), float(config.slow))
		service._emit_verified_source_effect(skill, "impact", target.combat_hit_position())

static func proc_allowed(skill: Dictionary, target: TwilightMonster, source: Dictionary, attack: Dictionary, world: Node) -> bool:
	if bool(skill.get("reference_normal_only", false)) and (bool(attack.get("by_spell", false)) or not source.is_empty()): return false
	if bool(skill.get("reference_critical_only", false)) and not bool(attack.get("critical", false)): return false
	if skill.has("reference_attack_kind") and attack.get("attack_type") != skill.reference_attack_kind: return false
	if skill.has("reference_trigger_name") and source.get("name") != skill.reference_trigger_name: return false
	if skill.get("reference_undead_only", false) and (not is_instance_valid(target) or not target.is_undead()): return false
	if skill.has("reference_health_below") and float(world.hp) > float(world._effective_max_hp()) * float(skill.reference_health_below): return false
	return not bool(skill.get("reference_passive_counter", false)) and not bool(skill.get("reference_survival", false))

static func reset_on_kill(service, skill: Dictionary) -> void:
	if not bool(skill.get("reference_reset_on_kill", false)): return
	var throttle: String = "reference_kill_reset:" + str(skill.id)
	var cooldowns: Dictionary = service.world.skill_cooldowns
	if float(cooldowns.get(throttle, 0)) > 0: return
	cooldowns.erase(str(skill.name))
	cooldowns[throttle] = 2.0
