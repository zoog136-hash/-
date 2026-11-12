extends RefCounted
class_name TwilightOriginalSkillService

const EQUIPMENT523_COMBAT = preload("res://scripts/equipment523/combat.gd")
const LOCAL = preload("res://scripts/skills/local_skill_runtime.gd")
var local_runtime = LOCAL.new()
var estimated_nodes = preload("res://scripts/skills/estimated_nodes523.gd").new()
var progression = preload("res://scripts/skills/progression_runtime523.gd").new()
var spell_move = preload("res://scripts/skills/spell_move523.gd").new()
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
var relic_buff_signature: String = ""
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
	vfx.source_only_policy = _source_only_skill_presentation
	owner.add_child(vfx)
	summons.configure(self)
	local_runtime.configure(self)
	estimated_nodes.configure(self)
	spell_move.configure(owner)
	progression.configure(self)

func clear() -> void:
	estimated_nodes.clear()
	spell_move.clear()
	if progression.owner_ref!=null:progression.suspend()
	if local_runtime.world != null: local_runtime.suspend()
	summons.clear()
	status.clear()
	for id: String in shields.keys(): remove_guardian_shield_buff(id)
	shields.clear()
	stacks.clear()
	marks.clear()
	counter_counts.clear()
	if is_instance_valid(vfx): vfx.clear()
	relic_buff_signature = ""

func tick(delta: float) -> void:
	vfx.set_detail(str(world.presentation_settings.get("effect_detail", "full")), bool(world.presentation_settings.get("limit_effect_count", false)))
	local_runtime.tick(delta)
	estimated_nodes.tick(delta)
	spell_move.tick(delta)
	status.tick(delta)
	summons.tick(delta)
	progression.tick(delta)
	combat_elapsed += delta
	recovery_elapsed += delta
	refresh_relic_buffs()
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

func refresh_buffs_after_learning(learned_id: String) -> void:
	# An upgrade can be learned while its base buff is already active. Resolve
	# that family's stats before the learning transaction updates HUD/save data;
	# this is not a cast and must not refresh time, costs or unrelated buffs.
	if catalog.relations.get(learned_id, {}).get("upgrades_from") == null: return
	var family: Dictionary = {}
	var cursor := learned_id
	while not cursor.is_empty() and not family.has(cursor):
		family[cursor] = true
		var parent: Variant = catalog.relations.get(cursor, {}).get("upgrades_from")
		cursor = str(parent) if parent != null else ""
	for buff: Dictionary in world.active_skill_buffs.values():
		var id := str(buff.get("skill_id", ""))
		if not family.has(id): continue
		var base := catalog.record_for(id)
		if base.is_empty() or not catalog.owned(base): continue
		var skill := catalog.resolve(base)
		buff["skill_stats"] = skill.get("stats", {}).duplicate(true)
		buff["speed"] = float(buff.skill_stats.get("speed", 1))

func refresh_relic_buffs() -> void:
	var signature: String = catalog._lineage_signature() + catalog._relic_signature()
	if signature == relic_buff_signature: return
	relic_buff_signature = signature
	for buff: Dictionary in world.active_skill_buffs.values():
		var base: Dictionary = catalog.record_for(str(buff.get("skill_id", "")))
		if base.is_empty(): continue
		var skill: Dictionary = catalog.resolve(base)
		if not catalog.RELIC_LEVELS.EFFECTS.needs_buff_refresh(base): continue
		buff["skill_stats"] = skill.get("stats", {}).duplicate(true)
		buff["speed"] = float(buff.skill_stats.get("speed", 1))
	# Never extend remaining time, cast, spend, heal or write a save on refresh.
	world.hp = mini(world.hp, world._effective_max_hp())
	world.mp = mini(world.mp, world._effective_max_mp())
	world._refresh_speed_modifiers()
	if world.player != null: world.player.set_skill_speed_multiplier(world._active_skill_speed_multiplier())

func stat(key: String) -> float:
	refresh_relic_buffs()
	var result: float = catalog.stat(key) + local_runtime.stat(key)
	if key=="lfe" and world.get("growth")!=null: result += world.growth.bonus("life:flat")
	if key=="lfe": result += EQUIPMENT523_COMBAT.lfe(world._all_equipped_records())
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

func material_plan(skill: Dictionary) -> Dictionary:
	var spent: Dictionary = {}
	var physical_ammo: Dictionary={};var physical_materials: Array=[]
	var original_owner: Script=load("res://scripts/loot/current523_native_stack.gd")
	for item: String in skill.get("items", {}):
		var remaining: int = int(skill.items[item])
		var ammo: Dictionary=original_owner.call("original_skill_ammo",world,item,remaining)
		if ammo.get("handled",false):
			if not ammo.get("ok",false) or not physical_ammo.is_empty():return {"reason":str(ammo.get("reason","하나의 스킬에서 서로 다른 실제 탄약 선택은 미지원")),"spent":{}}
			physical_ammo=ammo;continue
		for key: String in Catalog.SOURCE523.inventory_keys(skill, item):
			var available: int = maxi(0,int(world.inventory.get(key,0))-int(spent.get(key,0)))
			var amount: int = mini(remaining,available)
			if amount > 0: spent[key] = int(spent.get(key,0)) + amount
			remaining -= amount
		if remaining > 0:
			var original: Dictionary=original_owner.call("plan_spell_material",world,skill,item,remaining)
			if not original.get("handled",false):return {"reason":"%s %d개 필요" % [item,int(skill.items[item])],"spent":{}}
			if not original.get("ok",false):return {"reason":str(original.get("reason","정확한 원문 스킬 재료 연결 대기")),"spent":{}}
			physical_materials.append_array(original.requests)
	return {"reason":"","spent":spent,"physical_ammo":physical_ammo,"physical_materials":physical_materials}

func cost_reason(skill: Dictionary) -> String:
	if not str(skill.get("source523_block_reason", "")).is_empty(): return str(skill.source523_block_reason)
	if bool(skill.get("runtime_blocked", false)): return Catalog.CURRENT.blocked_reason(skill)
	var estimate_reason: String = estimated_nodes.cost_reason(skill)
	if not estimate_reason.is_empty(): return estimate_reason
	var ammo_reason: String=progression.ammo_problem(skill)
	if not ammo_reason.is_empty():return ammo_reason
	if world.mp < int(skill.get("mp", 0)): return "MP 부족"
	if world.hp <= int(skill.get("hp", 0)): return "HP 부족"
	if skill.get("source523", {}).get("applied", []).has("mana") and world.mp >= world._effective_max_mp(): return "MP가 이미 가득 참"
	return str(material_plan(skill).reason)

func spend(skill: Dictionary) -> bool:
	if not cost_reason(skill).is_empty(): return false
	var plan: Dictionary = material_plan(skill)
	if not str(plan.get("reason","")).is_empty():return false
	var physical: Dictionary=plan.get("physical_ammo",{})
	if not physical.is_empty():
		var owner: Script=load("res://scripts/loot/current523_native_stack.gd")
		var current: Dictionary=owner.call("original_skill_ammo",world,str(physical.cost_role),int(physical.quantity))
		if current!=physical:return false
		var paid: Dictionary=owner.call("consume_ammo",world,str(physical.inventory_key),int(physical.quantity),int(skill.get("mp",0)),null,false,{"hp_cost":int(skill.get("hp",0)),"legacy_spent":plan.spent.duplicate(true),"skill_id":str(skill.get("id","")),"material_requests":plan.get("physical_materials",[]).duplicate(true),"resolved_skill":skill.duplicate(true)})
		if not paid.get("ok",false) or not paid.get("saved",false) or paid.get("consumed")!=physical.quantity:
			world.hud.show_message(str(paid.get("reason","원문 스킬 탄약·비용 저장 연결 대기")));return false
		world._refresh_ammo_counters();return true
	if not plan.get("physical_materials",[]).is_empty():
		var paid: Dictionary=load("res://scripts/loot/current523_native_stack.gd").call("spend_original_skill_materials",world,skill,plan)
		if not paid.get("ok",false) or not paid.get("saved",false):world.hud.show_message(str(paid.get("reason","원문 스킬 재료 저장 연결 대기")));return false
		return true
	world.mp -= int(skill.get("mp", 0))
	world.hp -= int(skill.get("hp", 0))
	for item: String in plan.spent: world.inventory[item] = int(world.inventory.get(item,0)) - int(plan.spent[item])
	return true

func ready(skill: Dictionary, announce: bool = false) -> bool:
	var source_status: Dictionary=catalog.source_learning_status(skill)
	if not source_status.is_empty():
		if announce:world.hud.show_message(str(source_status.message))
		return false
	if world.patch523_npc_spells.blocks("CannotCastSkill"): return false
	if bool(skill.get("runtime_blocked", false)):
		if announce: world.hud.show_message(Catalog.CURRENT.blocked_reason(skill))
		return false
	if local_runtime.can_disable(skill): return true
	if progression.can_disable(skill):return true
	skill = catalog.resolve(skill)
	var reason := ""
	if world.halphas_star.combat.frozen(world.player) or not world.halphas_star.combat.charge.is_empty():reason="자체 동빙 또는 차징 중"
	elif spell_move.busy(): reason = "원본 이동 효과 진행 중"
	elif not catalog.owned(skill): reason = "미습득 또는 직업 제한"
	elif str(skill.activation) == "passive": reason = "패시브 기술"
	elif catalog.level_locked(skill): reason = "Lv.%d 필요" % catalog.minimum_level_for(skill)
	elif not catalog.enabled(skill): reason = "속성 계열 또는 사용 무기 제한"
	elif str(skill.mode) == "summon" and (summons.active() or world.active_skill_buffs.has(str(skill.name))): reason = "가디언 또는 보호막 유지 중"
	elif not world.pending_attack.is_empty(): reason = "시전 중"
	elif world.hp <= 0 or world.player.motion.dead: reason = "사망 상태"
	elif not bool(skill.get("cast_while_disabled", false)) and (world.player.is_stunned() or world.player.is_feared() or world.player.silence_remaining > 0 or (world.player.source_523_spell_blocked and str(skill.get("attack_type","magic")) == "magic")): reason = "상태이상으로 사용 불가"
	elif world.skill_global_cooldown > 0 or float(world.skill_cooldowns.get(str(skill.name), 0)) > 0: reason = "재사용 대기 중"
	else: reason = cost_reason(skill)
	if not reason.is_empty() and announce: world.hud.show_message(reason)
	return reason.is_empty()

func cast(record: Dictionary) -> bool:
	if not ready(record, true): return false
	var skill := catalog.resolve(record)
	if progression.is_toggle(skill):return progression.toggle(skill)
	if bool(skill.get("local_design",false)) and str(skill.get("local_kind",""))!="generic": return local_runtime.cast(skill)
	# Cast-speed options reduce cooldown through the world's shared policy;
	# they must not also accelerate the contact/presentation timeline.
	skill["cast_time"] = float(skill.get("cast_time", .42))
	var mode := str(skill.mode)
	if bool(skill.get("spell_move523", {}).get("ok", false)): return _cast_spell_move(skill)
	if mode=="teleport" and world.get("growth")!=null and world.growth.travel.enabled():
		world.growth.travel.open({"kind":"original","id":str(record.id)})
		return false # Selection has not cast or spent anything yet.
	var target: TwilightMonster = null
	var dash_only := false
	if mode in ["attack", "status", "turn_undead"] and str(skill.get("shape", "single")) != "self_circle":
		target = world._skill_target(float(skill.get("range", 240)))
		if not is_instance_valid(target) or target.dead:
			# An explicit unreachable selection never redirects into a dash.
			if estimated_nodes.kind(skill) == "grab" and not is_instance_valid(world.selected_monster) and world.world_interactions.selections.is_empty(): dash_only = true
			else: return false
		if not dash_only and not Catalog.SOURCE523.target_allowed(skill, target): return false
	var dash_end := Vector2.INF
	if estimated_nodes.kind(skill) == "grab":
		dash_end = estimated_nodes.dash_plan(skill, target)
		if not dash_end.is_finite(): return false
	if mode == "turn_undead" and turn_undead_chance(skill, target) <= 0:
		world.hud.show_message("턴 언데드 대상이 아니거나 즉사 면역입니다")
		return false
	if mode == "heal" and world.hp >= world._effective_max_hp() and not bool(skill.get("overflow_shield", false)) and skill.get("statuses", []).is_empty(): return false
	if mode == "convert" and world.mp >= world._effective_max_mp(): return false
	if mode == "cleanse" and not world.player.is_poisoned(): return false
	var teleport_landing: Vector2 = Vector2.INF
	if mode == "teleport":
		teleport_landing = world._random_walkable_position(world.player.global_position, 96, 600)
		if not teleport_landing.is_finite():
			world.hud.show_message("이동 가능한 위치가 없습니다")
			return false
	# Validation ends here. Costs and cooldowns happen once, before the marker.
	if not spend(skill): return false
	if dash_end.is_finite(): estimated_nodes.move_to(dash_end)
	var id := str(skill.id)
	var cooldown: float = float(skill.get("cooldown", 0)) * world._skill_cooldown_factor()
	cooldown *= clampf(1 - equipment_modifier(skill, "cooldown_percent") / 100.0, .1, 1)
	world.skill_cooldowns[str(skill.name)] = maxf(0, cooldown)
	world.skill_global_cooldown = float(skill.get("global_cooldown", .3))
	world._break_invisibility()
	if not _is_verified_source_skill(skill): vfx.begin_cast(presentation_id(skill), world.player, target)
	_emit_verified_source_effect(skill, "cast", world.player.global_position)
	match mode:
		"attack", "status", "turn_undead":
			if dash_only:
				world.player.pulse_attack()
			elif str(skill.get("shape", "single")) == "self_circle":
				if not world._queue_player_area_attack(skill): return false
			else:
				var kind := str(skill.get("attack_type", "magic"))
				if kind not in ["magic", "ranged", "melee"]: kind = "melee"
				if not world._queue_player_attack(target, kind, impact.bind(skill, target), float(skill.cast_time), false, float(skill.range)): return false
				world.pending_attack["original_skill"] = skill
				world.pending_attack["original_target_life_id"] = target.life_id
		"buff", "counter", "stealth": apply_buff(skill)
		"detect": estimated_nodes.detect(skill)
		"heal":
			Status.cleanse(world.player, skill.get("statuses", []))
			var amount := int(skill.get("heal", 0)) + int(world._effective_max_hp() * float(skill.get("heal_percent", 0)))
			if skill.has("heal_dice"):
				var dice: Dictionary=skill.heal_dice
				var sp_scale: float=float(dice.sp_scale) if int(catalog.source523.bindings.class_ids.get(str(world.job_class),-1))==int(dice.sp_class_id) else 0.0
				amount=int(dice.base)+int(world._spell_power_stat()*sp_scale)
				for _die: int in range(clampi(int(dice.number),0,100)):
					amount+=int((int(dice.sides)+1)/2.0) if bool(dice.average) else world.rng.randi_range(1,maxi(1,int(dice.sides)))
			heal(skill, amount)
			if bool(skill.get("show_recovery_buff",false)) and skill.get("stats",{}).is_empty():apply_buff(skill)
			if bool(skill.get("stealth_after", false)): apply_buff(skill, true)
		"cleanse":
			Status.cleanse(world.player, skill.get("statuses", []))
			vfx.emit_skill(presentation_id(skill), "impact", world.player.global_position)
			_emit_verified_source_effect(skill, "impact", world.player.global_position)
		"convert":
			var before_mp: int = world.mp
			world.mp = mini(world._effective_max_mp(), world.mp + int(skill.get("mana", 0)))
			if skill.get("source523", {}).get("applied", []).has("mana"):
				world.hud.show_message("%s · MP %d 회복" % [str(skill.name), world.mp - before_mp])
			vfx.emit_skill(id, "impact", world.player.global_position)
			_emit_verified_source_effect(skill, "impact", world.player.global_position)
		"teleport":
			world._clear_combat_actions()
			world.player.global_position = teleport_landing
			world.player.clear_click_path()
			world.player.camera.reset_smoothing()
			vfx.emit_skill(id, "impact", world.player.global_position)
			_emit_verified_source_effect(skill, "impact", world.player.global_position)
		"taunt":
			for monster: TwilightMonster in targets(skill, null): monster.aggro_remaining = maxf(monster.aggro_remaining, float(skill.duration))
			vfx.emit_skill(id, "impact", world.player.global_position)
			_emit_verified_source_effect(skill, "impact", world.player.global_position)
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
		var visual_options := vfx.flight_options(visual_id)
		visual_options.merge({"color":vfx.color_for(visual_id),"motif":vfx.presets.get(visual_id, {}).get("motif", ""),"obstruction":world._has_line_of_sight_world})
		world.combat_flights.launch(world.player.combat_projectile_origin(), target, kind, world._impact_player_attack.bind(shot_action), 1050, hit * .08, visual_options)

func area_marker(skill: Dictionary, generation: int) -> void:
	if not is_instance_valid(world) or world.hp <= 0 or generation != world.combat_generation: return
	if world.player.is_stunned() or world.player.is_feared() or world.player.is_silenced(): return
	vfx.emit_skill(presentation_id(skill), "release", world.player.global_position)
	impact(skill, null)

func targets(skill: Dictionary, primary: TwilightMonster) -> Array[TwilightMonster]:
	var result: Array[TwilightMonster] = []
	var origin: Vector2 = world.player.global_position
	var shape := str(skill.get("shape", "single"))
	if shape == "single" and is_instance_valid(primary):
		return [primary] if Catalog.SOURCE523.target_allowed(skill, primary) else []
	var center: Vector2 = primary.global_position if is_instance_valid(primary) else origin
	var radius := float(skill.get("radius", skill.get("range", 160)))
	for child: Node in world.monsters_root.get_children():
		if not child is TwilightMonster or child.dead: continue
		var monster := child as TwilightMonster
		if not Catalog.SOURCE523.target_allowed(skill, monster): continue
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
			if status.apply(skill, target, world):
				vfx.emit_skill(presentation_id(skill), "impact", target.combat_hit_position(), Vector2.INF, {"ground_point":target.global_position})
				_emit_verified_source_effect(skill, "impact", target.combat_hit_position())
				_emit_verified_source_effect(skill, "success", target.combat_hit_position())
				vfx.maintain_status(presentation_id(skill), target, str(skill.get("status", "")))
			else:
				vfx.emit_skill(presentation_id(skill), "resist", target.combat_hit_position())
				_emit_verified_source_effect(skill, "fail", target.combat_hit_position())
			continue
		var hit := hit_chance(skill, target)
		if world.rng.randf() >= hit:
			target.show_miss()
			vfx.emit_skill(presentation_id(skill), "resist", target.combat_hit_position())
			_emit_verified_source_effect(skill, "fail", target.combat_hit_position())
			continue
		deal_damage(skill, target)
		if not target.dead and skill.has("status"):
			if status.apply(skill, target, world):
				vfx.maintain_status(presentation_id(skill), target, str(skill.status))
				_emit_verified_source_effect(skill, "success", target.combat_hit_position())
			else:
				vfx.emit_skill(presentation_id(skill), "resist", target.combat_hit_position())
				_emit_verified_source_effect(skill, "fail", target.combat_hit_position())
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
		_emit_verified_source_effect(skill, "fail", target.combat_hit_position())
		world.hud.append_log(str(skill.name) + " · " + target.monster_name + " 저항")
		return
	# Use the NPC death signal/drop/XP path, with no weapon lifesteal, critical
	# roll or recursive on-hit proc attached to this instant-death effect.
	target.take_damage(target.hp, false, "turnUndead")
	vfx.emit_skill(presentation_id(skill), "impact", target.combat_hit_position(), Vector2.INF, {"ground_point":target.global_position})
	_emit_verified_source_effect(skill, "impact", target.combat_hit_position())
	_emit_verified_source_effect(skill, "success", target.combat_hit_position())
	event_counts[str(skill.id)] = int(event_counts.get(str(skill.id), 0)) + 1
	world.hud.append_log(str(skill.name) + " · " + target.monster_name + " 언데드 즉사")

func hit_chance(skill: Dictionary, target: TwilightMonster) -> float:
	if str(skill.get("attack_type", "")) == "magic":
		return world._magic_hit_chance(world._magic_accuracy_stat() + int(stat("magicPenetration")), world.card_collections.magic_resistance_after_pierce(maxi(0, target.magic_resistance + int(status.modifier(target, "mr")))))*world.halphas_star.combat.hit_factor(world.player)
	var accuracy: int = world._ranged_accuracy_stat() if str(skill.get("attack_type", "")) == "ranged" else world._melee_accuracy_stat()
	return physical_hit_chance(accuracy, target,str(skill.get("attack_type","melee")))

func physical_hit_chance(accuracy: int, target: TwilightMonster,attack_kind: String="melee") -> float:
	# Normal attacks and physical skills read the same live, life-scoped defense.
	# Keep the shared formula's AC normalization and nonnegative DG floor.
	var avoidance: float=status.modifier(target,"er" if attack_kind=="ranged" else "dg")
	avoidance+=status.modifier(target,"source_ranged_evasion" if attack_kind=="ranged" else "source_melee_evasion")
	if bool(target.get_meta("is_player_combatant",false)):avoidance-=world.growth.guardian_combat.value("PVPPierceRangeEvasion" if attack_kind=="ranged" else "PVPPierceMeleeEvasion")
	return world._physical_hit_chance(accuracy, target.hit_armor_class() + int(status.modifier(target, "ac")), world.card_collections.avoidance_after_pierce(int(avoidance),attack_kind))*world.halphas_star.combat.hit_factor(world.player)

func deal_damage(skill: Dictionary, target: TwilightMonster, link_from: Vector2 = Vector2.INF) -> void:
	if target.dead: return
	var amount: int = int(skill.get("power", 20)) + int(world.card_collections.spell_damage_bonus(skill)) + int(stat("lfe") * float(skill.get("lfe_scale", 0)))
	var source_kind: String=str(skill.get("attack_type","melee"))
	if world.get("growth")!=null:
		amount+=int(world.growth.bonus("pve_"+source_kind+"_damage:flat"))
		amount+=int(world.growth.bonus(source_kind+"_reduction_ignore:flat"))
		amount+=world.growth.catalog_bonus("damage_reduction_ignore")
	amount = int(amount * (1 + equipment_modifier(skill, "damage_percent") / 100.0))
	amount = int(amount * (1 + equipment_modifier(skill, "level_bonus") * float(runtime_defaults.get("equipment_level_damage_percent", {}).get("value", 2)) / 100.0))
	amount = int(amount * (1 + status.modifier(target, "taken") + (status.modifier(target,"magic_taken") if str(skill.get("attack_type", "")) == "magic" else 0)))
	amount = world._elemental_damage_to_monster(maxi(1, amount), str(skill.get("element", "physical")), target)
	var critical: bool = world.rng.randf() < world._critical_chance(world._player_critical_rate(str(skill.get("attack_type", "melee"))), target.critical_resistance)
	if critical: amount = world._player_critical_damage(amount, str(skill.get("attack_type", "melee")))
	if world.get("growth")!=null:
		world._deal_successful_player_hit(target, maxi(1, amount), critical,str(skill.get("attack_type","magic")),str(skill.get("shape","single"))!="area" or target==world.selected_monster,true)
	else:world._deal_successful_player_hit(target, maxi(1, amount), critical,str(skill.get("attack_type","melee")))
	_emit_verified_source_effect(skill, "impact", target.global_position)
	if critical: _emit_verified_source_effect(skill, "critical", target.global_position)
	if not _is_verified_source_skill(skill):
		vfx.emit_skill(presentation_id(skill), "impact", target.combat_hit_position(), link_from,
			{"direction":world.player.global_position.direction_to(target.global_position), "critical":critical, "ground_point":target.global_position})
	event_counts[str(skill.id)] = int(event_counts.get(str(skill.id), 0)) + 1

var equipment_source_depth: int=0
func execute_equipment_source_spell(profile: Dictionary,target: TwilightMonster,expected_life: int,context: Dictionary) -> Dictionary:
	if profile.get("mode")!="source_buff_modifiers":return execute_equipment_source_damage(profile,target,expected_life,context)
	var source=preload("res://scripts/crafting/patch523_equipment_spells.gd")
	if equipment_source_depth>0 or not source.eligible(world,profile,target,expected_life,context):return {"ok":false,"error":"원본 장비 버프 실행 조건 확인 필요"}
	var values: Dictionary=source.buff_values(profile)
	if values.is_empty() or (values.modifiers.has("source_hold") and target.status_immunities.has("hold")):return {"ok":false,"error":"원본 버프 단위/면역 확인 필요"}
	equipment_source_depth+=1
	var raw: Dictionary=profile.source_spell
	world.skill_cooldowns["equipment523|"+str(context.instance_id)+"|"+str(int(raw.ID))]=float(raw.CastDelay)/1000.0
	var chance: int=source.buff_chance_raw(world,profile,target)
	if chance<=0 or (chance<1000000 and world.rng.randi_range(0,999999)>=chance):
		equipment_source_depth-=1;target.show_miss()
		return {"ok":true,"hit":false,"applied":false,"damage":0,"spell_class_id":int(raw.ID),"hit_weight":chance}
	var low: float=float(values.SpellDebuffMinDuration);var high: float=float(values.SpellDebuffMaxDuration)
	var duration: float=low if low==high else world.rng.randf_range(low,high)
	var applied: bool=status.set_native_equipment_modifiers(target,profile,duration,values.modifiers,context)
	if applied and values.modifiers.has("source_hold"):target.apply_hold(duration)
	if applied and world.option_awakening!=null:world.option_awakening.combat.emit_spell(raw,target)
	world.hud.append_log("원본 장비 디버프 · %s · %.2f초 · 원본 수치/대상 + TWILIGHT 적중 계산" % [str(raw.Name),duration])
	equipment_source_depth-=1
	return {"ok":true,"hit":true,"applied":applied,"damage":0,"spell_class_id":int(raw.ID),"buff_class_id":int(profile.buff.source_buff.ID),"duration":duration,"hit_weight":chance}

func execute_equipment_source_damage(profile: Dictionary,target: TwilightMonster,expected_life: int,context: Dictionary) -> Dictionary:
	# This is a separate native identity entrypoint on the existing execution
	# owner. It neither grants/learns a curated skill nor charges its cast cost.
	var source=preload("res://scripts/crafting/patch523_equipment_spells.gd")
	if equipment_source_depth>0 or not source.eligible(world,profile,target,expected_life,context):return {"ok":false,"error":"원본 장비 주문의 타깃/소유/실행 조건 확인 필요"}
	var values: Dictionary=source.values(profile)
	var raw: Dictionary=profile.source_spell
	var key: String="equipment523|"+str(context.instance_id)+"|"+str(int(raw.ID))
	if float(world.skill_cooldowns.get(key,0))>0:return {"ok":false,"error":"원본 장비 주문 재사용 대기"}
	equipment_source_depth+=1
	var fixed: bool=profile.mode=="fixed_ignore_mr_dr"
	if not fixed and world.rng.randf()>=hit_chance({"attack_type":"magic"},target):
		target.show_miss();equipment_source_depth-=1
		return {"ok":true,"hit":false,"spell_class_id":int(raw.ID),"damage":0}
	var amount: int=int(values.get("SpellDamageBase",0))
	for die: int in range(int(values.get("SpellDamageDiceNumber",0))):amount+=world.rng.randi_range(1,int(values.get("SpellDamageDiceSpotCount",0)))
	if not fixed:
		var element: String=str({0:"physical",1:"fire",2:"water",3:"wind",4:"earth"}.get(int(raw.get("ElementalTypeID",0)),""))
		if element.is_empty():equipment_source_depth-=1;return {"ok":false,"error":"원본 속성 실행 조건 확인 필요"}
		amount=world._elemental_damage_to_monster(maxi(1,amount),element,target)
		amount=target_damage(amount,target,"magic")
	# A native equipment proc is one effect, not another normal/curated attack.
	# Bypass amplification/critical/drain/on-hit recursion and learned cost APIs.
	world.skill_cooldowns[key]=float(raw.CastDelay)/1000.0
	target.take_damage(maxi(0,amount),false,"magic")
	if world.option_awakening!=null:world.option_awakening.combat.emit_spell(raw,target)
	world.hud.append_log("원본 장비 주문 · %s · 피해 %d · 원본 주사위/조건 + TWILIGHT 전투 단계" % [str(raw.Name),amount])
	equipment_source_depth-=1
	return {"ok":true,"hit":true,"spell_class_id":int(raw.ID),"damage":amount}

func apply_buff(skill: Dictionary, force_stealth: bool = false) -> void:
	var stats: Dictionary = skill.get("stats", {})
	var buff: Dictionary = {"remaining":float(skill.duration),"skill_id":str(skill.id),"skill_stats":stats.duplicate(true),"stealth":force_stealth or skill.mode == "stealth","break_on_damage":bool(skill.get("break_on_damage", false)),"break_on_attack":bool(skill.get("break_on_attack",false)),"drain_mp_percent":float(skill.get("drain_mp_percent", 0)),"speed":float(stats.get("speed", 1))}
	world.active_skill_buffs[str(skill.name)] = buff
	vfx.maintain(str(skill.id), world.player, float(skill.duration))
	# Existing self-buff application is the presentation event. No periodic
	# replay, duration inference or status activation is created by the renderer.
	if str(skill.get("mode","")) in ["buff","counter","stealth"]:
		_emit_verified_source_effect(skill, "effect", world.player.global_position)
		_emit_verified_source_effect(skill, "success", world.player.global_position)
	world._refresh_skill_stealth_visual()
	world._refresh_speed_modifiers()

func dispel_active_buff(name: String) -> bool:
	if not world.active_skill_buffs.has(name): return false
	var buff: Dictionary = world.active_skill_buffs[name]
	var id: String = str(buff.get("skill_id",""))
	var row: Dictionary = catalog.record_for(id)
	if bool(row.get("local_design",false)): local_runtime.turn_off(row)
	if str(buff.get("summon_stage","")) == "shield": remove_guardian_shield_buff(id)
	world.active_skill_buffs.erase(name)
	if not id.is_empty():
		toggles.erase(id); shields.erase(id); vfx.remove_persistent(id)
	refresh_buff_visuals()
	return true

func heal(skill: Dictionary, amount: int) -> void:
	var maximum: int = world._effective_max_hp()
	var before: int = world.hp
	var effective := maxi(0, amount + int(stat("lfe") * float(skill.get("lfe_scale", 0))))
	if str(skill.get("mode",""))=="heal" and world.get("growth")!=null: effective = world.growth.magic_healing(effective)
	effective=world.card_collections.magic_heal(effective)
	if str(skill.get("mode","")) in world.PATCH523_ENHANCE.policy().get("healing_magic_modes",[]):
		effective=maxi(0,int(round(float(effective)*(1.0+maxf(0.0,world._equipment_inven_sum("healing_magic_pct"))/100.0))))
	var source_heal_input: int = effective
	effective = EQUIPMENT523_COMBAT.magical_heal(world._all_equipped_records(),effective)
	effective = world.patch523_npc_spells.extensions.healing(effective,false)
	var generation: int = int(world.combat_generation)
	world.apply_patch523_healing(source_heal_input,false)
	if generation != int(world.combat_generation): return
	if bool(skill.get("overflow_shield", false)) and before + effective > maximum:
		var cap := int(maximum * float(skill.get("shield_cap_percent",100)) / 100.0)
		shields[str(skill.id)] = {"amount":mini(cap, before + effective - maximum),"remaining":float(skill.get("shield_duration",skill.get("duration", 12)))}
	if str(skill.get("mode", "")) == "heal" and not skill.get("stats", {}).is_empty(): apply_buff(skill)
	vfx.emit_skill(str(skill.id), "impact", world.player.global_position)
	_emit_verified_source_effect(skill, "impact", world.player.global_position)

func break_attack_buffs() -> void:
	for name: String in world.active_skill_buffs.keys():
		if bool(world.active_skill_buffs[name].get("break_on_attack",false)):world.active_skill_buffs.erase(name)

func stack(id: String, stats: Dictionary, limit: int, duration: float) -> void:
	var count := mini(limit, int(stacks.get(id, {}).get("count", 0)) + 1)
	stacks[id] = {"count":count,"stats":stats,"remaining":duration}
	vfx.emit_skill(id, "impact", world.player.global_position)
	_emit_verified_source_effect({"id":id}, "impact", world.player.global_position)

func trigger(event: String, target: TwilightMonster, source_skill: Dictionary = {}, attack: Dictionary = {}) -> void:
	if event == "on_hit" and str(source_skill.get("mode", "")) != "summon": summons.notify_attack(target)
	# Extra hits, reflected damage, and procs do not recursively proc themselves.
	if proc_depth > 0: return
	proc_depth += 1
	combat_elapsed = 0 if event != "on_skill" else combat_elapsed
	for base: Dictionary in catalog.records:
		if not catalog.enabled(base) or str(base.mode) not in ["proc","mark","toggle_proc","stack_defense","stack_attack"]: continue
		var skill := catalog.resolve(base)
		var expected := str(skill.get("trigger", "on_damaged" if skill.mode == "stack_defense" else "on_hit"))
		var native_delta: float = Catalog.RELIC_LEVELS.EFFECTS.INVOKE.delta_for(skill, attack)
		if event == "on_miss":
			if expected != "on_hit" or native_delta <= 0: continue
		elif expected != event: continue
		var id := str(skill.id)
		if float(world.skill_cooldowns.get(id, 0)) > 0: continue
		var chance: float = native_delta if event == "on_miss" else float(skill.get("proc_chance", 1)) + native_delta
		if world.rng.randf() >= clampf(chance, 0, 1): continue
		match str(skill.mode):
			"stack_defense": stack(id, {"damageReduction":skill.get("reduction_per_stack", 1)}, int(skill.get("max_stacks", 5)), float(skill.duration))
			"stack_attack": stack(id, {"atk":skill.get("atk_per_stack", 1),"meleeHit":skill.get("hit_per_stack", 1)}, int(skill.get("max_stacks", 5)), float(skill.duration))
			"mark":
				if is_instance_valid(target) and not target.dead:
					var key := target.get_instance_id()
					var previous: Dictionary = marks.get(key, {})
					var count := (int(previous.get("count", 0)) if Status.same_life(previous, target) else 0) + 1
					marks[key] = {"target":weakref(target),"life_id":target.life_id,"count":count,"remaining":10.0}
					status.set_modifiers(target, "mark:" + id, 10.0, {"ac":int(abs(target.armor_class) * .05) * count,"dg":-3 * count})
					vfx.emit_skill(id, "impact", target.combat_hit_position())
					_emit_verified_source_effect(skill, "impact", target.combat_hit_position())
					if count >= int(skill.get("stacks", 3)):
						deal_damage(skill, target)
						var control := skill.duplicate(true)
						control.merge({"status":"stun","status_chance":1.0,"duration":.5},true)
						status.apply(control, target, world)
						status.remove_modifiers(target, "mark:" + id)
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
				if skill.has("mana"):
					world.mp = mini(world._effective_max_mp(), world.mp + int(skill.mana))
					vfx.emit_skill(id, "impact", world.player.global_position)
					_emit_verified_source_effect(skill, "impact", world.player.global_position)
				if skill.has("power") and event in ["on_hit", "on_miss"] and is_instance_valid(target) and not target.dead: deal_damage(skill, target)
		world.skill_cooldowns[id] = float(skill.get("proc_cooldown", 0))
	if event == "on_hit" and is_instance_valid(target) and not target.dead:
		progression.on_normal_hit(target,source_skill)
		local_runtime.on_hit(target,source_skill)
		trigger_equipment(target)
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

func target_damage(amount: int, target: TwilightMonster,kind: String="") -> int:
	# One common successful-hit boundary covers normal attacks, skills and
	# equipment procs. Instant death intentionally bypasses that boundary.
	var pierce: float = world.totem_reduction_pierce() if world.has_method("totem_reduction_pierce") else 0.0
	var result: int=status.damage_after_reduction(amount,target,pierce)
	if kind=="ranged":result=maxi(1,result-int(status.modifier(target,"source_ranged_reduction")))
	if kind in ["melee","ranged","magic"]:
		var settings: Dictionary=world.PATCH523_ENHANCE.policy()
		var percentage: float=clampf(status.modifier(target,"source_"+kind+"_reduction_pct"),float(settings.get("source_buff_reduction_min_pct",-300)),float(settings.get("source_buff_reduction_max_pct",90)))
		result=maxi(1,int(round(result*(1-percentage/100.0))))
	return result

func attack_context(kind: String, by_spell: bool, hit: bool, main_target: bool = true) -> Dictionary:
	return {"confirmed":true,"attack_type":kind,"by_spell":by_spell,"hit":hit,"main_target":main_target,"source_weapon_type":preload("res://scripts/animation/source_weapon_banks.gd").local_type(world._current_weapon_type())}

func trigger_relic_miss(target: TwilightMonster, kind: String) -> void:
	if proc_depth > 0 or not is_instance_valid(target) or target.dead: return
	var attack: Dictionary = attack_context(kind, false, false)
	# No new event/RNG side effects when no active native miss increment exists.
	for base: Dictionary in catalog.records:
		if not catalog.enabled(base) or base.mode != "proc": continue
		if Catalog.RELIC_LEVELS.EFFECTS.INVOKE.delta_for(catalog.resolve(base), attack) > 0:
			trigger("on_miss", target, {}, attack)
			return

func outgoing_damage(amount: int, attack: Dictionary = {}) -> int:
	if proc_depth > 0 or counter_depth > 0: return amount
	var multiplier := 1.0
	for buff: Dictionary in world.active_skill_buffs.values():
		var stats: Dictionary = buff.get("skill_stats", {})
		if world.rng.randf() < float(stats.get("doubleChance", 0)): multiplier = maxf(multiplier, float(stats.get("doubleMultiplier", 1)))
	for record: Dictionary in catalog.records:
		if not catalog.enabled(record): continue
		var skill: Dictionary = catalog.resolve(record)
		if skill.mode != "amplify": continue
		var chance: float = float(skill.get("proc_chance", 0)) + Catalog.RELIC_LEVELS.EFFECTS.INVOKE.delta_for(skill, attack)
		if world.rng.randf() < clampf(chance, 0, 1): multiplier = maxf(multiplier, float(skill.get("multiplier", 1)))
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
	vfx.emit_skill(presentation_id(best), "release", world.player.combat_projectile_origin(), Vector2.INF,
		{"direction":world.player.global_position.direction_to(attacker.global_position)})
	var id := str(best.id)
	var count := int(counter_counts.get(id, 0)) + 1
	if count >= int(best.get("counter_evades", 1)):
		counter_counts[id] = 0
		var damage := maxi(1, int(world._effective_attack() * float(best.counter_multiplier)))
		attacker.take_damage(damage, false, "skill_counter")
		if world.rng.randf() < float(best.get("counter_heal_chance", .2)): heal(best, int(best.get("counter_heal", 0)))
		vfx.emit_skill(id, "impact", attacker.combat_hit_position(), world.player.global_position)
		_emit_verified_source_effect(best, "impact", attacker.combat_hit_position())
	else: counter_counts[id] = count
	counter_depth -= 1
	return true

static func roll_counter(random: RandomNumberGenerator, chance: float) -> bool:
	return random.randf() < clampf(chance, 0, 1)

func auto_wants(skill: Dictionary, target: TwilightMonster = null) -> bool:
	if not ready(skill): return false
	skill = catalog.resolve(skill)
	if str(skill.get("mode",""))=="source_toggle":return false
	if str(skill.get("mode", "")) in ["attack", "status", "turn_undead"] and is_instance_valid(target) and not Catalog.SOURCE523.target_allowed(skill, target): return false
	if bool(skill.get("local_design",false)) and str(skill.get("local_kind",""))!="generic": return local_runtime.auto_wants(skill)
	match str(skill.mode):
		"turn_undead": return turn_undead_chance(skill, target) > 0
		"heal": return float(world.hp) / float(world._effective_max_hp()) <= float(skill.get("auto_hp_threshold", .65))
		"convert": return float(world.mp) / float(world._effective_max_mp()) <= .35 and float(world.hp) / float(world._effective_max_hp()) > .55
		"cleanse": return world.player.is_poisoned()
		"detect": return not estimated_nodes.hidden_targets(skill).is_empty()
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
	amount = local_runtime.incoming(attacker,kind,amount)
	if stat("invulnerable") > 0: return 0
	if counter(attacker, kind, amount):
		last_evaded = true
		return 0
	var multiplier := 1.0
	for buff: Dictionary in world.active_skill_buffs.values(): multiplier *= float(buff.get("skill_stats", {}).get("receivedMultiplier", 1))
	var reduction := stat("damageReduction") + stat("receivedReduction")
	# This entry point receives TwilightMonster attacks, so keep native PvE
	# reduction separate from general/PvP stats.
	reduction += stat("pveDamageReduction")
	if kind != "magic": reduction += stat("physicalReduction")
	if kind == "ranged": reduction += stat("rangedReduction")
	var result := maxi(0, int(amount * multiplier) - int(reduction))
	if kind != "magic": result = int(result * (1 - clampf(stat("physicalResistance") / 100.0,0,.8)))
	estimated_nodes.incoming(result, attacker)
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
	var resolved := catalog.resolve(record) if not record.is_empty() else {}
	if resolved.has("recovery523") and bool(resolved.get("overflow_shield",false)):
		world.active_skill_buffs.erase(str(record.name))
		vfx.remove_persistent(id)
		return
	if estimated_nodes.kind(record) == "protection":
		world.active_skill_buffs.erase(str(record.name))
		vfx.remove_persistent(id)
		return
	if record.is_empty() or str(record.mode) != "summon": return
	var name := str(record.name)
	if str(world.active_skill_buffs.get(name,{}).get("summon_stage","")) != "shield": return
	world.active_skill_buffs.erase(name)
	vfx.remove_persistent(id)

func export_state() -> Dictionary:
	return {"local_design":local_runtime.export_state(),"toggles":toggles.duplicate(true),"shields":shields.duplicate(true),"summon":summons.export_state(),"source523_toggles":progression.export_state()}

func import_state(data: Dictionary) -> void:
	clear()
	toggles = data.get("toggles", {}).duplicate(true)
	progression.restore(data.get("source523_toggles",{}))
	var saved_shields: Variant = data.get("shields", {})
	if saved_shields is Dictionary:
		for id: String in saved_shields:
			var record: Dictionary = catalog.record_for(id)
			# A persisted shield must still belong to a learned, currently usable
			# ability. Never let a non-shield skill ID absorb damage after a load.
			if record.is_empty() or not catalog.enabled(record): continue
			var skill: Dictionary = catalog.resolve(record)
			var mode := str(record.get("mode", ""))
			if mode != "summon" and (mode != "heal" or not bool(skill.get("overflow_shield", false))): continue
			var value: Variant = saved_shields[id]
			if typeof(value) != TYPE_DICTIONARY: continue
			var amount := clampi(int(value.get("amount", 0)), 0, world._effective_max_hp())
			var remaining := clampf(float(value.get("remaining", 0)), 0, 60)
			if amount <= 0 or remaining <= 0: continue
			shields[id] = {"amount":amount, "remaining":remaining}
			if mode == "summon":
				skill.duration = remaining
				apply_buff(skill)
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
		if skill.has("progression523") and str(skill.activation)=="passive":
			world.active_skill_buffs.erase(name)
			continue
		buff["skill_stats"] = skill.get("stats", {}).duplicate(true)
		vfx.maintain(str(skill.id), world.player, float(buff.get("remaining", 0)))
	local_runtime.restore(data.get("local_design",{}))

func _source_only_skill_presentation() -> bool:
	return is_instance_valid(world) and is_instance_valid(world.player) and world.player.original_source_preview.current523_source_only_presentation()

func _emit_verified_source_effect(skill: Dictionary, stage: String, point: Vector2) -> void:
	if _is_verified_source_skill(skill):
		if world.player.original_source_preview.notify_source_spell_event(int(skill.source_m_spell_id), stage, point, world.player.motion.facing8, world.player.original_source_manifest): return
	# Reuse the already admitted skill's pinned current-source profile. This
	# changes only its existing cast/impact presentation call, not skill identity,
	# admission, costs, proc timing, damage, progression or saved state.
	var profile: Dictionary = catalog.source523.profiles.get(str(skill.get("id","")),{})
	var row: Variant = profile.get("row")
	if not row is Dictionary or row.is_empty(): return
	if catalog.source523.active_sha256.is_empty():
		# The raw-definition owner admits profiles without assigning the compiled
		# pack fingerprint. Read its optional contract dynamically for older owners.
		var owner: Object = catalog.source523
		var source_mode: String = ""
		var source_identity: Variant = {}
		var fallback_status: Variant = {}
		for property: Dictionary in owner.get_property_list():
			match str(property.name):
				"source_mode":
					var value: Variant = owner.get("source_mode")
					if value is String: source_mode = value
				"source_identity": source_identity = owner.get("source_identity")
				"source_fallback_status": fallback_status = owner.get("source_fallback_status")
		if source_mode != "original_bound_profiles" or not source_identity is Dictionary or not fallback_status is Dictionary: return
		var source_archive_sha: String = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
		if source_identity.get("kind") != "twilight.current523.original-definitions.v1" or source_identity.get("source_snapshot") != "patch523" or source_identity.get("source_sha256") != source_archive_sha or source_identity.get("source_bytes") != 25031173: return
		var id: String = str(skill.get("id",""))
		var applied: Variant = fallback_status.get("applied")
		var deferred: Variant = fallback_status.get("deferred")
		if fallback_status.get("state") != "loaded" or not applied is Array or not applied.has(id) or not deferred is Dictionary or deferred.has(id): return
		var bindings: Dictionary = catalog.source523.bindings
		var skills: Variant = bindings.get("skills")
		if not skills is Dictionary: return
		var binding: Variant = skills.get(id)
		if bindings.get("source_zip_sha256") != source_archive_sha or not binding is Dictionary or binding.get("spell_id") != row.get("ID"): return
	world.player.original_source_preview.notify_current_source_spell_event(row,stage,point,world.player.motion.facing8)

## Original SpellMove skill: validation first, then the same cost/cooldown
## bookkeeping as other casts. Follow-up spells of the move are not run here.
func _cast_spell_move(skill: Dictionary) -> bool:
	var move: Dictionary = skill.spell_move523
	var target: TwilightMonster = world._skill_target(float(move.cast_range_cells) * spell_move.cell_length())
	if not is_instance_valid(target) or target.dead:
		world.hud.show_message("이동 대상이 사거리 %d칸 안에 없습니다" % int(move.cast_range_cells))
		return false
	if world.player.has_method("is_held") and world.player.is_held() and str(move.kind) == "caster_dash":
		world.hud.show_message("이동 불가 상태에서는 돌진할 수 없습니다")
		return false
	if not cost_reason(skill).is_empty() or not str(material_plan(skill).get("reason","")).is_empty():
		world.hud.show_message("원본 이동 스킬 비용 부족")
		return false
	var weapon := preload("res://scripts/cards/polymorph_weapon_limit523.gd").weapon_type_id(world._equipped_weapon_record()) if world.has_method("_equipped_weapon_record") else -1
	var prepared: Dictionary = spell_move.prepare(move, target, weapon)
	if not bool(prepared.get("ok", false)):
		world.hud.show_message(str(prepared.get("reason", "원본 이동 효과를 시작할 수 없습니다")))
		return false
	if not spend(skill): return false
	spell_move.commit(prepared)
	world.skill_cooldowns[str(skill.name)] = maxf(0, float(skill.get("cooldown", 0)) * world._skill_cooldown_factor())
	world.skill_global_cooldown = float(skill.get("global_cooldown", .3))
	world._break_invisibility()
	world.selected_monster = target
	world.hud.append_log("%s · 원본 이동 %s" % [str(skill.name), {"caster_dash":"돌진","target_pull":"끌어오기","target_knockback":"넉백"}.get(str(move.kind), str(move.kind))])
	return true

func _is_verified_source_skill(skill: Dictionary) -> bool:
	return skill.has("source_m_spell_id") and str(skill.get("source_m_snapshot", "")) == "base508"




