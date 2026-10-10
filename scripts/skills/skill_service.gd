extends RefCounted
class_name TwilightOriginalSkillService

const Catalog = preload("res://scripts/skills/skill_catalog.gd")
const Status = preload("res://scripts/skills/status_service.gd")
const VFX = preload("res://scripts/skills/skill_vfx.gd")
const Summons = preload("res://scripts/skills/summon_service.gd")
var catalog: TwilightOriginalSkillCatalog
var status: TwilightSkillStatusService = Status.new()
var vfx: TwilightOriginalSkillVFX
var world: Node
var proc_depth: int = 0
var counter_depth: int = 0
var shields: Dictionary = {}
var stacks: Dictionary = {}
var marks: Dictionary = {}
var toggles: Dictionary = {}
var counter_counts: Dictionary = {}
var combat_elapsed: float = 100
var recovery_elapsed: float = 0
var event_counts: Dictionary = {}
var last_evaded: bool = false
var equipment_links: Dictionary = {}
var equipment_balance: Dictionary = {}
var runtime_defaults: Dictionary = {}
var summons: TwilightOriginalSummonService = Summons.new()

func configure(owner: Node) -> void:
	world = owner
	catalog = Catalog.new()
	catalog.configure(owner)
	var balances := Catalog.read_json("balance.json")
	equipment_balance = balances.get("equipment", {})
	runtime_defaults = balances.get("runtime_defaults", {})
	for entry: Dictionary in Catalog.read_json("equipment_links.json").get("records", []): equipment_links[str(entry.name)] = entry.links
	vfx = VFX.new()
	vfx.name = "OriginalSkillVFX"
	vfx.z_index = 12
	owner.add_child(vfx)
	summons.configure(self)

func clear() -> void:
	summons.clear()
	status.clear()
	for id: String in shields.keys(): remove_guardian_shield_buff(id)
	shields.clear()
	stacks.clear()
	marks.clear()
	counter_counts.clear()
	if is_instance_valid(vfx): vfx.clear()

func tick(delta: float) -> void:
	status.tick(delta)
	summons.tick(delta)
	combat_elapsed += delta
	recovery_elapsed += delta
	for id: String in shields.keys():
		shields[id].remaining -= delta
		if float(shields[id].remaining) <= 0:
			shields.erase(id)
			remove_guardian_shield_buff(id)
	for id: String in stacks.keys():
		stacks[id].remaining -= delta
		if float(stacks[id].remaining) <= 0: stacks.erase(id)
	for key: int in marks.keys():
		marks[key].remaining -= delta
		var target: Node = marks[key].target.get_ref()
		if not Status.same_life(marks[key], target) or target.dead or float(marks[key].remaining) <= 0: marks.erase(key)
	for name: String in world.active_skill_buffs.keys():
		var buff: Dictionary = world.active_skill_buffs[name]
		var id := str(buff.get("skill_id", ""))
		if id.is_empty(): continue
		var drain := float(buff.get("drain_mp_percent", 0))
		if drain > 0:
			buff["drain_clock"] = float(buff.get("drain_clock", 0)) + delta
			if float(buff.drain_clock) >= 1:
				buff.drain_clock -= 1
				world.mp = maxi(0, world.mp - maxi(1, int(ceil(world._effective_max_mp() * drain))))
				if world.mp <= 0: world.active_skill_buffs.erase(name)
		if not world.active_skill_buffs.has(name): vfx.remove_persistent(id)
	refresh_buff_visuals()
	if recovery_elapsed >= 1:
		recovery_elapsed -= 1
		for record: Dictionary in catalog.records:
			if not catalog.enabled(record): continue
			if record.mode == "recovery" and combat_elapsed >= float(record.get("combat_delay", 5)): heal(record, int(record.get("heal", 5)))
		var hp_regen := int(stat("hpRegen"))
		var mp_regen := int(stat("mpRegen"))
		if hp_regen > 0: world.hp = mini(world._effective_max_hp(), world.hp + hp_regen)
		if mp_regen > 0: world.mp = mini(world._effective_max_mp(), world.mp + mp_regen)

func refresh_buff_visuals() -> void:
	# Map transitions cancel pending hits, while retained buffs regain their aura.
	var retained: Dictionary = {}
	for buff: Dictionary in world.active_skill_buffs.values():
		var id := str(buff.get("skill_id", ""))
		var base := catalog.record_for(id)
		if base.is_empty() or not catalog.enabled(base) or float(buff.get("remaining", 0)) <= 0: continue
		retained[id] = true
		if vfx.persistent.has(id): vfx.persistent[id].remaining = float(buff.remaining)
		else: vfx.maintain(id, world.player, float(buff.remaining))
	for id: String in vfx.persistent.keys():
		if not retained.has(id): vfx.remove_persistent(id)

func stat(key: String) -> float:
	var result := catalog.stat(key)
	for buff: Dictionary in world.active_skill_buffs.values():
		if buff.has("skill_id"): result += float(buff.get("skill_stats", {}).get(key, 0))
	for entry: Dictionary in stacks.values(): result += float(entry.get("stats", {}).get(key, 0)) * float(entry.get("count", 0))
	return result

func equipment_modifier(skill: Dictionary, key: String) -> float:
	var result := 0.0
	for record: Dictionary in world._all_equipped_records():
		for entry: Dictionary in record.get("skill_modifiers", []):
			if str(entry.get("skill_id", "")) in ["*", str(skill.id)] or str(entry.get("skill_name", "")) == str(skill.name):
				result += float(entry.get(key, 0))
	return result

func cost_reason(skill: Dictionary) -> String:
	if world.mp < int(skill.get("mp", 0)): return "MP 부족"
	if world.hp <= int(skill.get("hp", 0)): return "HP 부족"
	for item: String in skill.get("items", {}):
		if int(world.inventory.get(item, 0)) < int(skill.items[item]): return "%s %d개 필요" % [item, int(skill.items[item])]
	return ""

func spend(skill: Dictionary) -> bool:
	if not cost_reason(skill).is_empty(): return false
	world.mp -= int(skill.get("mp", 0))
	world.hp -= int(skill.get("hp", 0))
	for item: String in skill.get("items", {}): world.inventory[item] = int(world.inventory.get(item, 0)) - int(skill.items[item])
	return true

func ready(skill: Dictionary, announce: bool = false) -> bool:
	var reason := ""
	if not catalog.owned(skill): reason = "미습득 또는 직업 제한"
	elif str(skill.activation) == "passive": reason = "패시브 기술"
	elif not catalog.enabled(skill): reason = "속성 계열 또는 사용 무기 제한"
	elif str(skill.mode) == "summon" and (summons.active() or world.active_skill_buffs.has(str(skill.name))): reason = "가디언 또는 보호막 유지 중"
	elif not world.pending_attack.is_empty(): reason = "시전 중"
	elif world.hp <= 0: reason = "사망 상태"
	elif not bool(skill.get("cast_while_disabled", false)) and (world.player.is_stunned() or world.player.is_feared() or world.player.is_silenced()): reason = "상태이상으로 사용 불가"
	elif world.skill_global_cooldown > 0 or float(world.skill_cooldowns.get(str(skill.name), 0)) > 0: reason = "재사용 대기 중"
	else: reason = cost_reason(catalog.resolve(skill))
	if not reason.is_empty() and announce: world.hud.show_message(reason)
	return reason.is_empty()

func cast(record: Dictionary) -> bool:
	if not ready(record, true): return false
	var skill := catalog.resolve(record)
	skill["cast_time"] = float(skill.get("cast_time", .42)) / clampf(1 + stat("castSpeed") / 100.0, 1, 4)
	var mode := str(skill.mode)
	var target: TwilightMonster = null
	if mode in ["attack", "status", "turn_undead"] and str(skill.get("shape", "single")) != "self_circle":
		target = world._skill_target(float(skill.get("range", 240)))
		if not is_instance_valid(target) or target.dead: return false
	if mode == "turn_undead" and turn_undead_chance(skill, target) <= 0:
		world.hud.show_message("턴 언데드 대상이 아니거나 즉사 면역입니다")
		return false
	if mode == "heal" and world.hp >= world._effective_max_hp() and not bool(skill.get("overflow_shield", false)) and skill.get("statuses", []).is_empty(): return false
	if mode == "convert" and world.mp >= world._effective_max_mp(): return false
	if mode == "cleanse" and not world.player.is_poisoned(): return false
	# Validation ends here. Costs and cooldowns happen once, before the marker.
	if not spend(skill): return false
	var id := str(skill.id)
	var cooldown: float = float(skill.get("cooldown", 0)) * world._skill_cooldown_factor()
	cooldown *= clampf(1 - equipment_modifier(skill, "cooldown_percent") / 100.0, .1, 1)
	world.skill_cooldowns[str(skill.name)] = maxf(0, cooldown)
	world.skill_global_cooldown = float(skill.get("global_cooldown", .3))
	world._break_invisibility()
	vfx.emit_skill(presentation_id(skill), "cast", world.player.global_position)
	match mode:
		"attack", "status", "turn_undead":
			if str(skill.get("shape", "single")) == "self_circle":
				world.player.pulse_attack()
				# A timer carries the same map generation as queued target attacks.
				world.get_tree().create_timer(float(skill.cast_time) * .48).timeout.connect(area_marker.bind(skill, world.combat_generation))
			else:
				var kind := str(skill.get("attack_type", "magic"))
				if kind not in ["magic", "ranged", "melee"]: kind = "melee"
				world._queue_player_attack(target, kind, impact.bind(skill, target), float(skill.cast_time), false, float(skill.range))
				world.pending_attack["original_skill"] = skill
				world.pending_attack["original_target_life_id"] = target.life_id
		"buff", "counter", "stealth": apply_buff(skill)
		"heal":
			Status.cleanse(world.player, skill.get("statuses", []))
			var amount := int(skill.get("heal", 0)) + int(world._effective_max_hp() * float(skill.get("heal_percent", 0)))
			heal(skill, amount)
			if bool(skill.get("stealth_after", false)): apply_buff(skill, true)
		"cleanse": Status.cleanse(world.player, skill.get("statuses", []))
		"convert": world.mp = mini(world._effective_max_mp(), world.mp + int(skill.get("mana", 0)))
		"teleport":
			world._clear_combat_actions()
			world.player.global_position = world._random_walkable_position(world.player.global_position, 96, 600)
			world.player.clear_click_path()
			world.player.camera.reset_smoothing()
			vfx.emit_skill(id, "impact", world.player.global_position)
		"taunt":
			for monster: TwilightMonster in targets(skill, null): monster.aggro_remaining = maxf(monster.aggro_remaining, float(skill.duration))
			vfx.emit_skill(id, "impact", world.player.global_position)
		"toggle_proc":
			toggles[id] = not bool(toggles.get(id, false))
			world.hud.show_message(str(skill.name) + (" ON" if toggles[id] else " OFF"))
		"summon": summons.spawn(skill)
		_: return false
	if mode not in ["attack","status","turn_undead"]: world.player.pulse_attack()
	trigger("on_skill", target, skill)
	world._update_hud()
	return true

func launch_at_marker(action: Dictionary, target: TwilightMonster) -> void:
	var target_life := int(action.get("original_target_life_id", target.life_id))
	if target.life_id != target_life: return
	var skill: Dictionary = action.original_skill
	var hits := clampi(int(skill.get("hits", 1)), 1, 12)
	for hit: int in range(hits):
		var shot_action := action.duplicate(false)
		shot_action["callback"] = impact.bind(skill, target, target_life)
		var kind := str(action.kind) if str(action.kind) in ["magic","ranged"] else "timed"
		var visual_id := presentation_id(skill)
		world.combat_flights.launch(world.player.combat_projectile_origin(), target, kind, world._impact_player_attack.bind(shot_action), 1050, hit * .08, {"color":vfx.color_for(visual_id),"motif":vfx.presets.get(visual_id, {}).get("motif", ""),"obstruction":world._has_line_of_sight_world})

func area_marker(skill: Dictionary, generation: int) -> void:
	if not is_instance_valid(world) or world.hp <= 0 or generation != world.combat_generation: return
	if world.player.is_stunned() or world.player.is_feared() or world.player.is_silenced(): return
	impact(skill, null)

func targets(skill: Dictionary, primary: TwilightMonster) -> Array[TwilightMonster]:
	var result: Array[TwilightMonster] = []
	var origin: Vector2 = world.player.global_position
	var shape := str(skill.get("shape", "single"))
	if shape == "single" and is_instance_valid(primary): return [primary]
	var center: Vector2 = primary.global_position if is_instance_valid(primary) else origin
	var radius := float(skill.get("radius", skill.get("range", 160)))
	for child: Node in world.monsters_root.get_children():
		if not child is TwilightMonster or child.dead: continue
		var monster := child as TwilightMonster
		if not world._has_line_of_sight_world(origin, monster.global_position): continue
		var include := monster.global_position.distance_to(center) <= radius
		if shape == "line":
			var end := origin + origin.direction_to(center) * float(skill.range)
			include = Geometry2D.get_closest_point_to_segment(monster.global_position, origin, end).distance_to(monster.global_position) <= radius
		if include: result.append(monster)
	result.sort_custom(func(a: TwilightMonster,b: TwilightMonster) -> bool: return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	if result.size() > int(skill.get("targets", 6)): result.resize(int(skill.get("targets", 6)))
	return result

func impact(skill: Dictionary, primary: TwilightMonster, expected_life: int = -1) -> void:
	if expected_life >= 0 and (not is_instance_valid(primary) or primary.life_id != expected_life): return
	combat_elapsed = 0
	for target: TwilightMonster in targets(skill, primary):
		if not is_instance_valid(target) or target.dead: continue
		if str(skill.mode) == "turn_undead":
			resolve_turn_undead(skill, target)
			continue
		if str(skill.mode) == "status":
			if status.apply(skill, target, world): vfx.emit_skill(str(skill.id), "status", target.combat_hit_position())
			continue
		var hit := hit_chance(skill, target)
		if world.rng.randf() >= hit:
			target.show_miss()
			continue
		deal_damage(skill, target)
		if not target.dead and skill.has("status") and status.apply(skill, target, world): vfx.emit_skill(str(skill.id), "status", target.combat_hit_position())
		if not target.dead: trigger("on_hit", target, skill)
	if skill.has("self_stacks"):
		var config: Dictionary = skill.self_stacks
		stack(str(skill.id), {"atk":config.get("atk", 2)}, int(config.get("max", 3)), float(config.get("duration", 15)))
	world._refresh_combat_hud()

static func presentation_id(skill: Dictionary) -> String:
	return str(skill.get("visual_skill_id", skill.get("id", "")))

func turn_undead_chance(skill: Dictionary, target: TwilightMonster) -> float:
	if not is_instance_valid(target) or target.dead or not target.is_undead(): return 0.0
	if target.status_immunities.has("turnUndead") or target.status_immunities.has("turn_undead"): return 0.0
	# The original formula is undisclosed. These bounds, the upgrade bonus and
	# the default boss exclusion are explicitly CUSTOM_BALANCE in balance.json.
	var chance := clampf(hit_chance(skill, target) + float(skill.get("turn_accuracy_bonus", 0)), float(skill.get("turn_min_chance", .05)), float(skill.get("turn_max_chance", .99)))
	if target.is_boss: chance *= clampf(float(skill.get("turn_boss_factor", 0)), 0, 1)
	return chance

static func roll_turn_undead(random: RandomNumberGenerator, chance: float) -> bool:
	return random.randf() < clampf(chance, 0, 1)

func resolve_turn_undead(skill: Dictionary, target: TwilightMonster) -> void:
	var chance := turn_undead_chance(skill, target)
	# Recheck at impact: changing race, gaining immunity or a stale target must
	# not turn a previously valid projectile into an ordinary damage spell.
	if chance <= 0: return
	if not roll_turn_undead(world.rng, chance):
		target.show_miss()
		vfx.emit_skill(presentation_id(skill), "resist", target.combat_hit_position())
		world.hud.append_log(str(skill.name) + " · " + target.monster_name + " 저항")
		return
	# Use the NPC death signal/drop/XP path, with no weapon lifesteal, critical
	# roll or recursive on-hit proc attached to this instant-death effect.
	target.take_damage(target.hp, false, "turnUndead")
	vfx.emit_skill(presentation_id(skill), "impact", target.combat_hit_position())
	event_counts[str(skill.id)] = int(event_counts.get(str(skill.id), 0)) + 1
	world.hud.append_log(str(skill.name) + " · " + target.monster_name + " 언데드 즉사")

func hit_chance(skill: Dictionary, target: TwilightMonster) -> float:
	if str(skill.get("attack_type", "")) == "magic":
		return world._magic_hit_chance(world._magic_accuracy_stat() + int(stat("magicPenetration")), maxi(0, target.magic_resistance + int(status.modifier(target, "mr"))))
	var accuracy: int = world._ranged_accuracy_stat() if str(skill.get("attack_type", "")) == "ranged" else world._melee_accuracy_stat()
	return world._physical_hit_chance(accuracy, target.armor_class + int(status.modifier(target, "ac")), int(status.modifier(target, "dg")))

func deal_damage(skill: Dictionary, target: TwilightMonster, link_from: Vector2 = Vector2.INF) -> void:
	if target.dead: return
	var amount := int(skill.get("power", 20)) + int(stat("lfe") * float(skill.get("lfe_scale", 0)))
	amount = int(amount * (1 + equipment_modifier(skill, "damage_percent") / 100.0))
	amount = int(amount * (1 + equipment_modifier(skill, "level_bonus") * float(runtime_defaults.get("equipment_level_damage_percent", {}).get("value", 2)) / 100.0))
	amount = int(amount * (1 + status.modifier(target, "taken") + (status.modifier(target,"magic_taken") if str(skill.get("attack_type", "")) == "magic" else 0)))
	amount = world._elemental_damage_to_monster(maxi(1, amount), str(skill.get("element", "physical")), target)
	var critical: bool = world.rng.randf() < world._critical_chance(world._player_critical_rate(str(skill.get("attack_type", "melee"))), target.critical_resistance)
	if critical: amount = world._critical_damage(amount)
	world._deal_successful_player_hit(target, maxi(1, amount), critical)
	vfx.emit_skill(str(skill.id), "impact", target.combat_hit_position(), link_from)
	event_counts[str(skill.id)] = int(event_counts.get(str(skill.id), 0)) + 1

func apply_buff(skill: Dictionary, force_stealth: bool = false) -> void:
	var stats: Dictionary = skill.get("stats", {})
	var buff: Dictionary = {"remaining":float(skill.duration),"skill_id":str(skill.id),"skill_stats":stats.duplicate(true),"stealth":force_stealth or skill.mode == "stealth","break_on_damage":bool(skill.get("break_on_damage", false)),"drain_mp_percent":float(skill.get("drain_mp_percent", 0)),"speed":float(stats.get("speed", 1))}
	world.active_skill_buffs[str(skill.name)] = buff
	vfx.maintain(str(skill.id), world.player, float(skill.duration))
	world._refresh_skill_stealth_visual()
	world._refresh_speed_modifiers()

func heal(skill: Dictionary, amount: int) -> void:
	var maximum: int = world._effective_max_hp()
	var before: int = world.hp
	var effective := maxi(0, amount + int(stat("lfe") * float(skill.get("lfe_scale", 0))))
	world.hp = mini(maximum, before + effective)
	if bool(skill.get("overflow_shield", false)) and before + effective > maximum:
		shields[str(skill.id)] = {"amount":mini(maximum, before + effective - maximum),"remaining":float(skill.get("duration", 12))}
	if str(skill.get("mode", "")) == "heal" and not skill.get("stats", {}).is_empty(): apply_buff(skill)
	vfx.emit_skill(str(skill.id), "impact", world.player.global_position)

func stack(id: String, stats: Dictionary, limit: int, duration: float) -> void:
	var count := mini(limit, int(stacks.get(id, {}).get("count", 0)) + 1)
	stacks[id] = {"count":count,"stats":stats,"remaining":duration}

func trigger(event: String, target: TwilightMonster, source_skill: Dictionary = {}) -> void:
	if event == "on_hit" and str(source_skill.get("mode", "")) != "summon": summons.notify_attack(target)
	# Extra hits, reflected damage, and procs do not recursively proc themselves.
	if proc_depth > 0: return
	proc_depth += 1
	combat_elapsed = 0 if event != "on_skill" else combat_elapsed
	for base: Dictionary in catalog.records:
		if not catalog.enabled(base) or str(base.mode) not in ["proc","mark","toggle_proc","stack_defense","stack_attack"]: continue
		var skill := catalog.resolve(base)
		var expected := str(skill.get("trigger", "on_damaged" if skill.mode == "stack_defense" else "on_hit"))
		if expected != event: continue
		var id := str(skill.id)
		if float(world.skill_cooldowns.get(id, 0)) > 0: continue
		if world.rng.randf() >= float(skill.get("proc_chance", 1)): continue
		match str(skill.mode):
			"stack_defense": stack(id, {"damageReduction":skill.get("reduction_per_stack", 1)}, int(skill.get("max_stacks", 5)), float(skill.duration))
			"stack_attack": stack(id, {"atk":skill.get("atk_per_stack", 1),"meleeHit":skill.get("hit_per_stack", 1)}, int(skill.get("max_stacks", 5)), float(skill.duration))
			"mark":
				if is_instance_valid(target) and not target.dead:
					var key := target.get_instance_id()
					var previous: Dictionary = marks.get(key, {})
					var count := (int(previous.get("count", 0)) if Status.same_life(previous, target) else 0) + 1
					marks[key] = {"target":weakref(target),"life_id":target.life_id,"count":count,"remaining":10.0}
					status.debuffs[key] = {"target":weakref(target),"life_id":target.life_id,"remaining":10.0,"values":{"ac":int(abs(target.armor_class) * .05) * count,"dg":-3 * count}}
					if count >= int(skill.get("stacks", 3)):
						deal_damage(skill, target)
						var control := skill.duplicate(true)
						control.merge({"status":"stun","status_chance":1.0,"duration":.5},true)
						status.apply(control, target, world)
						marks.erase(key)
			"toggle_proc":
				if not is_instance_valid(target) or target.dead: continue
				if bool(toggles.get(id, false)):
					var cost := skill.duplicate(true)
					cost["mp"] = 0
					if not spend(cost): continue
					var last: TwilightMonster = target
					var visited: Array[TwilightMonster] = []
					for _bounce: int in range(int(skill.get("targets", 3))):
						if last == null: break
						var from: Vector2 = world.player.combat_projectile_origin() if visited.is_empty() else visited.back().combat_hit_position()
						deal_damage(skill, last, from)
						visited.append(last)
						last = next_chain_target(last, visited, float(skill.radius))
				else: deal_damage(skill, target)
			"proc":
				if event == "on_skill" and str(source_skill.get("school", "")) != str(skill.get("trigger_school", "rune")): continue
				if skill.has("heal"): heal(skill, int(skill.heal))
				if skill.has("mana"): world.mp = mini(world._effective_max_mp(), world.mp + int(skill.mana))
				if skill.has("power") and event == "on_hit" and is_instance_valid(target) and not target.dead: deal_damage(skill, target)
		world.skill_cooldowns[id] = float(skill.get("proc_cooldown", 0))
	if event == "on_hit" and is_instance_valid(target) and not target.dead: trigger_equipment(target)
	proc_depth -= 1

func trigger_equipment(target: TwilightMonster) -> void:
	var fired: Dictionary = {}
	for record: Dictionary in world._all_equipped_records():
		var links: Array = equipment_links.get(str(record.get("name", "")), []).duplicate(true)
		links.append_array(record.get("skill_procs", []))
		for entry: Dictionary in links:
			var id := str(entry.get("skill_id", ""))
			if id.is_empty() or fired.has(id) or entry.get("status", "") == "BLOCKED": continue
			var chance := float(entry.get("chance", equipment_balance.get(str(entry.get("key", "")), {}).get("value", 0)))
			if world.rng.randf() >= chance: continue
			var skill := catalog.record_for(id).duplicate(true)
			if skill.is_empty(): continue
			var ancestry: Array[String] = []
			while str(skill.mode) == "upgrade":
				ancestry.push_front(str(skill.id))
				if ancestry.size() > catalog.records.size(): break
				skill = catalog.record_for(str(catalog.relations.get(str(skill.id), {}).get("upgrades_from", ""))).duplicate(true)
				if skill.is_empty(): break
			if skill.is_empty(): continue
			for augment_id: String in ancestry: skill.merge(catalog.relations[augment_id].get("patch", {}), true)
			fired[id] = true
			match str(skill.mode):
				"attack", "status", "turn_undead": impact(skill, target)
				"heal": heal(skill, int(skill.get("heal", 0)))
				"buff": apply_buff(skill)

func next_chain_target(previous: TwilightMonster, visited: Array[TwilightMonster], radius: float) -> TwilightMonster:
	var result: TwilightMonster = null
	var distance := radius * radius
	for child: Node in world.monsters_root.get_children():
		if not child is TwilightMonster or child.dead or visited.has(child): continue
		var d := previous.global_position.distance_squared_to(child.global_position)
		if d < distance and world._has_line_of_sight_world(previous.global_position, child.global_position):
			result = child
			distance = d
	return result

func target_damage(amount: int, target: TwilightMonster) -> int:
	# One common successful-hit boundary covers normal attacks, skills and
	# equipment procs. Instant death intentionally bypasses that boundary.
	return status.damage_after_reduction(amount, target)

func outgoing_damage(amount: int) -> int:
	if proc_depth > 0 or counter_depth > 0: return amount
	var multiplier := 1.0
	for buff: Dictionary in world.active_skill_buffs.values():
		var stats: Dictionary = buff.get("skill_stats", {})
		if world.rng.randf() < float(stats.get("doubleChance", 0)): multiplier = maxf(multiplier, float(stats.get("doubleMultiplier", 1)))
	for record: Dictionary in catalog.records:
		if record.mode == "amplify" and catalog.enabled(record) and world.rng.randf() < float(record.get("proc_chance", 0)): multiplier = maxf(multiplier, float(record.get("multiplier", 1)))
	return maxi(0, int(amount * multiplier))

func on_evaded(attacker: TwilightMonster) -> void:
	for name: String in world.active_skill_buffs:
		var base := catalog.record_for(name)
		if base.is_empty() or not catalog.enabled(base): continue
		var skill := catalog.resolve(base)
		var config: Dictionary = skill.get("evade_proc", {})
		if not config.is_empty() and world.rng.randf() < float(config.get("chance", 0)):
			var proc := skill.duplicate(true)
			proc["power"] = int(config.get("power", 25))
			proc_depth += 1
			deal_damage(proc, attacker)
			proc_depth -= 1

func counter(attacker: TwilightMonster, kind: String, amount: int) -> bool:
	if counter_depth > 0 or proc_depth > 0 or kind != "melee" or not is_instance_valid(attacker) or attacker.dead: return false
	var best: Dictionary = {}
	for name: String in world.active_skill_buffs:
		var base := catalog.record_for(name)
		if base.is_empty() or base.mode != "counter" or not catalog.enabled(base): continue
		var skill := catalog.resolve(base)
		if float(skill.counter_chance) > float(best.get("counter_chance", 0)): best = skill
	if best.is_empty() or not roll_counter(world.rng, float(best.counter_chance)): return false
	counter_depth += 1
	var id := str(best.id)
	var count := int(counter_counts.get(id, 0)) + 1
	if count >= int(best.get("counter_evades", 1)):
		counter_counts[id] = 0
		var damage := maxi(1, int(world._effective_attack() * float(best.counter_multiplier)))
		attacker.take_damage(damage, false, "skill_counter")
		if world.rng.randf() < float(best.get("counter_heal_chance", .2)): heal(best, int(best.get("counter_heal", 0)))
		vfx.emit_skill(id, "impact", attacker.combat_hit_position(), world.player.global_position)
	else: counter_counts[id] = count
	counter_depth -= 1
	return true

static func roll_counter(random: RandomNumberGenerator, chance: float) -> bool:
	return random.randf() < clampf(chance, 0, 1)

func auto_wants(skill: Dictionary, target: TwilightMonster = null) -> bool:
	if not ready(skill): return false
	skill = catalog.resolve(skill)
	match str(skill.mode):
		"turn_undead": return turn_undead_chance(skill, target) > 0
		"heal": return float(world.hp) / float(world._effective_max_hp()) <= float(skill.get("auto_hp_threshold", .65))
		"convert": return float(world.mp) / float(world._effective_max_mp()) <= .35 and float(world.hp) / float(world._effective_max_hp()) > .55
		"cleanse": return world.player.is_poisoned()
		"buff", "counter": return not world.active_skill_buffs.has(str(skill.name))
		"summon": return not summons.active() and not world.active_skill_buffs.has(str(skill.name))
		"status":
			if not status.can_affect(skill, target): return false
			var kind := str(skill.get("status", ""))
			if kind in ["stun","hold","fear","silence","poison","bleed","slow"] and float(target.get(kind + "_remaining")) > 0: return false
		"attack":
			if str(skill.get("shape", "")) == "self_circle" and targets(skill, null).is_empty(): return false
	return true

func incoming_damage(attacker: TwilightMonster, kind: String, amount: int) -> int:
	combat_elapsed = 0
	summons.notify_threat(attacker)
	last_evaded = false
	if stat("invulnerable") > 0: return 0
	if counter(attacker, kind, amount):
		last_evaded = true
		return 0
	var multiplier := 1.0
	for buff: Dictionary in world.active_skill_buffs.values(): multiplier *= float(buff.get("skill_stats", {}).get("receivedMultiplier", 1))
	var reduction := stat("damageReduction") + stat("receivedReduction")
	if kind != "magic": reduction += stat("physicalReduction")
	if kind == "ranged": reduction += stat("rangedReduction")
	var result := maxi(0, int(amount * multiplier) - int(reduction))
	if kind != "magic": result = int(result * (1 - clampf(stat("physicalResistance") / 100.0,0,.8)))
	# Convert before the triggering hit is applied, including lethal damage.
	summons.intercept(result)
	for id: String in shields.keys():
		var absorb := mini(result, int(shields[id].amount))
		result -= absorb
		shields[id].amount -= absorb
		if int(shields[id].amount) <= 0:
			shields.erase(id)
			remove_guardian_shield_buff(id)
	# Losing HP ends shadow hiding; ordinary invisibility only ends on attack.
	if result > 0:
		for name: String in world.active_skill_buffs.keys():
			if bool(world.active_skill_buffs[name].get("break_on_damage", false)): world.active_skill_buffs.erase(name)
		world._refresh_skill_stealth_visual()
	return result

func remove_guardian_shield_buff(id: String) -> void:
	var record := catalog.record_for(id)
	if record.is_empty() or str(record.mode) != "summon": return
	var name := str(record.name)
	if str(world.active_skill_buffs.get(name,{}).get("summon_stage","")) != "shield": return
	world.active_skill_buffs.erase(name)
	vfx.remove_persistent(id)

func export_state() -> Dictionary:
	return {"toggles":toggles.duplicate(true),"shields":shields.duplicate(true),"summon":summons.export_state()}

func import_state(data: Dictionary) -> void:
	clear()
	toggles = data.get("toggles", {}).duplicate(true)
	for id: String in data.get("shields", {}):
		if catalog.record_for(id).is_empty(): continue
		var value: Dictionary = data.shields[id]
		shields[id] = {"amount":clampi(int(value.get("amount", 0)), 0, world._effective_max_hp()),"remaining":clampf(float(value.get("remaining", 0)), 0, 60)}
		var record := catalog.record_for(id)
		if str(record.mode) == "summon" and catalog.enabled(record) and int(shields[id].amount) > 0 and float(shields[id].remaining) > 0:
			var shield := catalog.resolve(record)
			shield.duration = float(shields[id].remaining)
			apply_buff(shield)
			world.active_skill_buffs[str(record.name)]["summon_stage"] = "shield"
	summons.restore_state(data.get("summon",{}))
	for name: String in world.active_skill_buffs.keys():
		var buff: Dictionary = world.active_skill_buffs[name]
		var base := catalog.record_for(str(buff.get("skill_id", name)))
		if base.is_empty() or not catalog.enabled(base): continue
		if str(base.mode) == "summon":
			var stage := str(buff.get("summon_stage",""))
			if (stage == "creature" and not summons.active(str(base.id))) or (stage == "shield" and not shields.has(str(base.id))):
				world.active_skill_buffs.erase(name)
				continue
		var skill := catalog.resolve(base)
		buff["skill_stats"] = skill.get("stats", {}).duplicate(true)
		vfx.maintain(str(skill.id), world.player, float(buff.get("remaining", 0)))
