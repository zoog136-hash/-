extends RefCounted
class_name TwilightOriginalSummonService

const Actor = preload("res://scripts/skills/summon_actor.gd")
var owner_ref: WeakRef
var owner_service: RefCounted:
	get: return owner_ref.get_ref() if owner_ref != null else null
var world: Node
var actor: TwilightSkillSummonActor
var skill: Dictionary = {}
var remaining: float = 0
var generation: int = -1
var order: String = "guard"
var designated: WeakRef
var threat: WeakRef
var pending_hit: Dictionary = {}
var attack_clock: float = 0
var path_clock: float = 0
var route: PackedVector2Array = []
var hit_events: int = 0
var shield_events: int = 0

func configure(service: RefCounted) -> void:
	owner_ref = weakref(service)
	world = service.world

func active(id: String = "") -> bool:
	return is_instance_valid(actor) and remaining > 0 and (id.is_empty() or str(skill.get("id","")) == id)

func spawn(record: Dictionary) -> bool:
	if active() or world.hp <= 0: return false
	skill = record.duplicate(true)
	remaining = float(skill.duration)
	generation = world.combat_generation
	order = "guard"
	actor = Actor.new()
	actor.name = "OriginalSkillGuardian"
	actor.tint = owner_service.vfx.color_for(str(skill.id))
	actor.z_index = 10
	world.add_child(actor)
	actor.global_position = world._random_walkable_position(world.player.global_position,30,72)
	owner_service.apply_buff(skill)
	world.active_skill_buffs[str(skill.name)]["summon_stage"] = "creature"
	owner_service.vfx.emit_skill(str(skill.id),"summon",actor.global_position)
	return true

func clear() -> void:
	pending_hit.clear();route.clear()
	designated = null;threat = null
	if is_instance_valid(actor): actor.queue_free()
	actor = null;remaining = 0
	if not skill.is_empty():
		var buff: Dictionary = world.active_skill_buffs.get(str(skill.name),{})
		if str(buff.get("summon_stage","")) == "creature":
			world.active_skill_buffs.erase(str(skill.name))
			owner_service.vfx.remove_persistent(str(skill.id))
	skill = {};attack_clock = 0;path_clock = 0

func command(value: String, enemy: TwilightMonster = null) -> bool:
	if not active() or value not in ["guard","attack","follow","stay","dismiss"]: return false
	if value == "dismiss": clear();return true
	if value == "attack" and (not is_instance_valid(enemy) or enemy.dead): return false
	order = value
	designated = weakref(enemy) if value == "attack" else null
	pending_hit.clear();route.clear();path_clock = 0
	return true

func export_state() -> Dictionary:
	if not active(): return {}
	# Enemy pointers and in-flight strikes never cross a save file boundary.
	return {"skill_id":str(skill.id),"remaining":remaining,"order":"guard" if order == "attack" else order}

func restore_state(saved: Dictionary) -> bool:
	var record: Dictionary = owner_service.catalog.record_for(str(saved.get("skill_id","")))
	if record.is_empty() or str(record.mode) != "summon" or not owner_service.catalog.enabled(record): return false
	var restored: Dictionary = owner_service.catalog.resolve(record)
	restored.duration = clampf(float(saved.get("remaining",0)),0,float(restored.duration))
	if float(restored.duration) <= 0 or not spawn(restored): return false
	var saved_order := str(saved.get("order","guard"))
	command(saved_order if saved_order in ["guard","follow","stay"] else "guard")
	return true

func notify_attack(enemy: TwilightMonster) -> void:
	if active() and is_instance_valid(enemy) and not enemy.dead: designated = weakref(enemy)

func notify_threat(enemy: TwilightMonster) -> void:
	if active() and is_instance_valid(enemy) and not enemy.dead: threat = weakref(enemy)

func living(reference: WeakRef) -> TwilightMonster:
	if reference == null: return null
	var enemy: Node = reference.get_ref()
	return enemy as TwilightMonster if is_instance_valid(enemy) and enemy is TwilightMonster and not enemy.dead else null

func choose_target() -> TwilightMonster:
	if order in ["follow","stay"]: return null
	var enemy := living(designated)
	if enemy == null and order == "guard": enemy = living(threat)
	if enemy == null and order == "guard" and world.player.auto_enabled:
		enemy = world.selected_monster if is_instance_valid(world.selected_monster) and not world.selected_monster.dead else null
	if enemy != null and enemy.global_position.distance_to(world.player.global_position) > float(skill.summon_leash): return null
	return enemy

func tick(delta: float) -> void:
	if not active(): return
	if generation != world.combat_generation or world.hp <= 0:
		clear();return
	remaining -= delta
	if remaining <= 0 or not world.active_skill_buffs.has(str(skill.name)):
		clear();return
	attack_clock = maxf(0,attack_clock-delta);path_clock -= delta
	if not pending_hit.is_empty():
		pending_hit.remaining -= delta
		if float(pending_hit.remaining) <= 0: release_hit()
	if not active(): return
	if float(world.hp)/maxf(1,world._effective_max_hp()) <= float(skill.guardian_hp_threshold):
		convert_to_shield();return
	var enemy := choose_target()
	var destination: Vector2 = world.player.global_position+Vector2(-48,32)
	if order == "stay": destination = actor.global_position
	if enemy != null: destination = enemy.global_position
	if actor.global_position.distance_to(world.player.global_position) > float(skill.summon_leash):
		actor.global_position = world._random_walkable_position(world.player.global_position,30,72)
		pending_hit.clear();route.clear()
		owner_service.vfx.emit_skill(str(skill.id),"summon",actor.global_position)
	var can_strike: bool = enemy != null and actor.global_position.distance_to(enemy.global_position) <= float(skill.summon_attack_range) and world._has_line_of_sight_world(actor.global_position,enemy.global_position)
	var direction := actor.global_position.direction_to(destination)
	var moving := false
	if can_strike:
		if attack_clock <= 0 and pending_hit.is_empty() and actor.age >= float(skill.summon_materialize_time):
			pending_hit = {"remaining":float(skill.summon_strike_time),"total":float(skill.summon_strike_time),"target":weakref(enemy),"life":enemy.life_id,"generation":generation}
			attack_clock = float(skill.summon_attack_interval)
	elif pending_hit.is_empty() and actor.global_position.distance_to(destination) > 18:
		if path_clock <= 0:
			path_clock = float(skill.summon_path_interval)
			route = world.find_world_path(actor.global_position,destination)
		while not route.is_empty() and actor.global_position.distance_to(route[0]) < 8: route.remove_at(0)
		if not route.is_empty():
			var next := actor.global_position.move_toward(route[0],float(skill.summon_speed)*delta)
			if world._is_walkable_world(next):
				direction = actor.global_position.direction_to(next)
				actor.global_position = next;moving = true
	var phase: float = -1 if pending_hit.is_empty() else 1-float(pending_hit.remaining)/maxf(.001,float(pending_hit.total))
	actor.update_pose(delta,moving,direction,phase)

func release_hit() -> void:
	var event := pending_hit.duplicate(false)
	pending_hit.clear()
	var enemy := living(event.get("target"))
	if not active() or enemy == null or int(event.generation) != world.combat_generation or enemy.life_id != int(event.life): return
	if actor.global_position.distance_to(enemy.global_position) > float(skill.summon_attack_range) or not world._has_line_of_sight_world(actor.global_position,enemy.global_position): return
	actor.finish_strike(float(skill.summon_recovery_time))
	var accuracy := int(skill.summon_accuracy)+int(world.level)
	var chance: float = world._physical_hit_chance(accuracy,enemy.armor_class,0)
	if world.rng.randf() >= chance:
		enemy.show_miss();return
	var damage := maxi(1,int(skill.summon_power)+int(world._spell_power_stat()*float(skill.summon_sp_scale))-enemy.defense_value)
	damage = world._elemental_damage_to_monster(damage,str(skill.get("element","physical")),enemy)
	# NPC deaths award ordinary owner XP/drop. Guardian attacks never recurse
	# through the caster's weapon procs, double hits, HP steal or counters.
	enemy.take_damage(damage,false,"skill_summon")
	owner_service.vfx.emit_skill(str(skill.id),"impact",enemy.combat_hit_position(),actor.global_position)
	hit_events += 1

func intercept(amount: int) -> void:
	if not active() or amount <= 0: return
	var after: int = world.hp-amount
	if float(after)/maxf(1,world._effective_max_hp()) <= float(skill.guardian_hp_threshold): convert_to_shield()

func convert_to_shield() -> void:
	if not active(): return
	var record := skill.duplicate(true)
	var capacity := int(record.guardian_shield_base)+int(world._spell_power_stat()*float(record.guardian_shield_sp_scale))
	capacity = mini(capacity,int(world._effective_max_hp()*float(record.guardian_shield_hp_cap)))
	var location := actor.global_position
	clear()
	owner_service.shields[str(record.id)] = {"amount":maxi(1,capacity),"remaining":float(record.guardian_shield_duration)}
	var shield := record.duplicate(true)
	shield.duration = float(record.guardian_shield_duration)
	owner_service.apply_buff(shield)
	world.active_skill_buffs[str(record.name)]["summon_stage"] = "shield"
	owner_service.vfx.emit_skill(str(record.id),"end",location)
	owner_service.vfx.emit_skill(str(record.id),"shield",world.player.global_position)
	shield_events += 1
