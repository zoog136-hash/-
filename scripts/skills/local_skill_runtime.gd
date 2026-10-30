extends RefCounted
## Specialized TWILIGHT proc/toggle behavior; generic spells use SkillService.
## All damage observes real gameplay events; texture/animation callbacks are absent.
var owner_ref: WeakRef
var service: RefCounted:
	get: return owner_ref.get_ref()
var world: Node
var windows: Dictionary = {}
var cooldowns: Dictionary = {}
var depth := 0
var proc_events: Dictionary = {}

func configure(owner: RefCounted) -> void:
	owner_ref = weakref(owner)
	world = owner.world

func rows() -> Array:
	return service.catalog.current_official.records

func row_named(name_value: String) -> Dictionary:
	return service.catalog.record_for(name_value)

func active(row: Dictionary) -> bool:
	return bool(row.get("local_design",false)) and service.catalog.enabled(row)

func is_on(row: Dictionary) -> bool:
	return bool(service.toggles.get(str(row.id),false)) and float(windows.get(str(row.id),0)) > 0

func can_disable(row: Dictionary) -> bool:
	return bool(row.get("local_design",false)) and str(row.get("mode")) == "local_toggle" and bool(service.toggles.get(str(row.id),false))

func turn_off(row: Dictionary) -> void:
	if not service.toggles.has(str(row.id)) and not windows.has(str(row.id)) and not world.active_skill_buffs.has(str(row.name)): return
	service.toggles[str(row.id)] = false
	windows.erase(str(row.id))
	world.active_skill_buffs.erase(str(row.name))
	service.vfx.remove_persistent(str(row.id))

func tick(delta: float) -> void:
	for id: String in cooldowns.keys():
		cooldowns[id] = maxf(0,float(cooldowns[id])-delta)
		if float(cooldowns[id]) <= 0: cooldowns.erase(id)
	for id: String in windows.keys():
		windows[id] = float(windows[id])-delta
		var row: Dictionary = service.catalog.record_for(id)
		if row.is_empty() or not active(row) or world.hp <= 0 or float(windows[id]) <= 0: turn_off(row)

func suspend() -> void:
	depth = 0
	for row: Dictionary in rows():
		if str(row.mode)=="local_toggle" and (world.hp<=0 or not active(row)): turn_off(row)

func cast(row: Dictionary) -> bool:
	if can_disable(row):
		turn_off(row)
		world._update_hud(); world._save_game(true)
		return true
	var kind := str(row.local_kind)
	if kind not in ["pride","berserk","aqua_heal","guardian","shooting","dignity","bloody"]: return false
	if kind == "aqua_heal" and world.hp >= world._effective_max_hp(): return false
	var prepared_landing := Vector2.INF
	if kind == "guardian":
		# Validate placement before consuming 600 MP / 100 gems.
		if service.summons.active(): return false
		prepared_landing = service.summons.safe_landing(world.player.global_position,30,72)
		if not prepared_landing.is_finite(): return false
	if not service.spend(row): return false
	world.skill_cooldowns[str(row.name)] = float(row.cooldown) * world._skill_cooldown_factor()
	world.skill_global_cooldown = float(row.global_cooldown)
	service.vfx.begin_cast(str(row.id),world.player)
	match kind:
		"pride","berserk":
			var buff := row.duplicate(true)
			if kind == "berserk": buff.stats.meleeDamage += int(world._effective_attribute("INT") * float(row.int_damage_scale))
			service.apply_buff(buff)
			world.player.set_skill_speed_multiplier(world._active_skill_speed_multiplier())
		"aqua_heal": service.heal(row,int(row.heal))
		"guardian":
			if not service.summons.spawn(row,prepared_landing): return false
		"shooting","dignity","bloody":
			service.toggles[str(row.id)] = true
			windows[str(row.id)] = float(row.duration)
			service.apply_buff(row)
	world.player.pulse_attack()
	world._update_hud();world._save_game(true)
	return true

func stat(key: String) -> float:
	var result := 0.0
	for row: Dictionary in rows():
		if not active(row): continue
		var weapons: Array = row.get("passive_weapons",[])
		if not weapons.is_empty() and not weapons.has(world._current_weapon_type()): continue
		result += float(row.get("passive_stats",{}).get(key,0))
	return result

func auto_wants(row: Dictionary) -> bool:
	match str(row.local_kind):
		"aqua_heal": return float(world.hp)/maxf(1,world._effective_max_hp()) <= float(row.auto_hp_threshold)
		"pride","berserk": return not world.active_skill_buffs.has(str(row.name))
		"guardian": return not service.summons.active()
	return false # AUTO must never alternate a toggle every polling frame.

func attempt(row: Dictionary, channel: String = "") -> bool:
	var key := str(row.id)+channel
	if not active(row) or float(cooldowns.get(key,0)) > 0: return false
	# ICD starts on attempt: secondary weapon hits cannot roll a second proc.
	cooldowns[key] = float(row.proc_cooldown)
	if world.rng.randf() >= float(row.proc_chance): return false
	var cost := row.duplicate(true)
	cost.mp = int(row.proc_mp)
	cost.items = row.get("proc_items",{}).duplicate(true)
	if not service.spend(cost): return false
	proc_events[str(row.id)] = int(proc_events.get(str(row.id),0))+1
	return true

func damage(row: Dictionary, target: TwilightMonster, power: int, from: Vector2 = Vector2.INF) -> int:
	if not is_instance_valid(target) or target.dead: return 0
	var before: int = target.hp
	var amount: int = world._elemental_damage_to_monster(maxi(1,power),str(row.get("element","physical")),target)
	amount = service.target_damage(amount,target)
	# Direct, tagged proc damage avoids normal-hit/weapon/lifesteal recursion.
	target.take_damage(amount,false,"local_skill:"+str(row.id))
	service.vfx.emit_skill(service.presentation_id(row),"impact",target.combat_hit_position(),from)
	service.event_counts[str(row.id)] = int(service.event_counts.get(str(row.id),0))+1
	return maxi(0,before-target.hp)

func on_hit(target: TwilightMonster, source_skill: Dictionary) -> void:
	if depth > 0 or not source_skill.is_empty() or not is_instance_valid(target) or target.dead: return
	depth += 1
	for base: Dictionary in rows():
		var kind := str(base.local_kind)
		if kind not in ["shooting","dignity","bloody","prison","elemental_weapon","wings"] or not active(base): continue
		if kind in ["shooting","bloody"] and not is_on(base): continue
		if not attempt(base): continue
		var row: Dictionary = service.catalog.resolve(base)
		match kind:
			"shooting","dignity","bloody":
				var area := row.duplicate(true)
				area.shape = "area" if kind != "dignity" or is_on(base) else "single"
				var victims: Array[TwilightMonster] = service.targets(area,target)
				var primary_dealt := 0
				for enemy: TwilightMonster in victims:
					var dealt := damage(row,enemy,int(row.power),world.player.global_position)
					if enemy == target: primary_dealt = dealt
				if kind=="bloody" and primary_dealt>0: service.heal(row,mini(primary_dealt,int(row.heal_on_hit)))
			"prison":
				if service.status.apply(row,target,world):
					service.vfx.emit_skill(service.presentation_id(row),"impact",target.combat_hit_position())
					if row.has("shark_power"):
						var dealt := damage(row,target,int(row.shark_power),world.player.global_position)
						service.heal(row,mini(dealt,int(row.heal_on_hit)))
			"elemental_weapon":
				service.status.set_modifiers(target,"local_weapon:"+str(row.id),float(row.debuff_duration),row.debuff)
				row.element = str(service.catalog.schools.get("요정","water"))
				damage(row,target,int(row.power),world.player.global_position)
			"wings":
				var start: Vector2 = world.player.global_position
				var end: Vector2 = start.move_toward(target.global_position,float(row.dash_distance))
				if world._is_walkable_world(end) and world.field_map.point_clear(end,4.0) and world._has_line_of_sight_world(start,end):
					world.player.clear_click_path();world.player.global_position=end
				service.vfx.emit_skill(str(row.id),"impact",world.player.global_position)
	depth -= 1

func incoming(attacker: TwilightMonster, kind: String, amount: int) -> int:
	if depth > 0 or not is_instance_valid(attacker) or attacker.dead or amount <= 0: return amount
	depth += 1
	var riposte := row_named("리포스트")
	if kind in ["melee","charge"] and attempt(riposte):
		damage(riposte,attacker,maxi(1,int(amount*float(riposte.counter_multiplier))),world.player.global_position)
		amount = maxi(0,int(amount*float(riposte.received_factor)))
		if kind=="charge" and not attacker.dead: attacker.apply_stun(float(riposte.charge_stun))
	var wings := row_named("엘븐 윙 슈즈")
	if attempt(wings,":wing"):
		amount = maxi(0,amount-int(wings.wing_reduction))
		service.vfx.emit_skill(str(wings.id),"impact",world.player.global_position)
	depth -= 1
	return amount

func guardian_impact(row: Dictionary, primary: TwilightMonster, from: Vector2) -> void:
	var area := row.duplicate(true)
	area.shape = "area"
	area.element = str(service.catalog.schools.get("요정","water"))
	var power := int(row.summon_power)+int(world._spell_power_stat()*float(row.summon_sp_scale))
	for enemy: TwilightMonster in service.targets(area,primary): damage(area,enemy,maxi(1,power-enemy.defense_value),from)

func buy_reagents(row: Dictionary) -> bool:
	if not bool(row.get("local_design",false)) or not service.catalog.permitted(row): return false
	var amounts: Dictionary = row.get("items",{}).duplicate(true)
	for item: String in row.get("proc_items",{}): amounts[item]=maxi(int(amounts.get(item,0)),int(row.proc_items[item])*10)
	var prices: Dictionary = service.catalog.current_official.local_design.get("reagent_prices",{})
	var price := 0
	for item: String in amounts:
		if not prices.has(item) or int(prices[item]) <= 0 or int(amounts[item])<=0: return false
		price += int(prices[item])*int(amounts[item])
	if price <= 0 or world.gold < price: return false
	world.gold -= price
	for item: String in amounts: world.inventory[item]=int(world.inventory.get(item,0))+int(amounts[item])
	world._update_hud();world._save_game(true)
	return true

func export_state() -> Dictionary:
	return {"windows":windows.duplicate(true),"cooldowns":cooldowns.duplicate(true)}

func restore(saved: Dictionary) -> void:
	windows.clear();cooldowns.clear();depth=0
	for row: Dictionary in rows():
		var id := str(row.id)
		for key: String in [id,id+":wing"]:
			var left := clampf(float(saved.get("cooldowns",{}).get(key,0)),0,float(row.get("proc_cooldown",0)))
			if left>0:cooldowns[key]=left
		if str(row.mode)!="local_toggle":continue
		var left := clampf(float(saved.get("windows",{}).get(id,0)),0,float(row.duration))
		if bool(service.toggles.get(id,false)) and active(row) and world.hp>0 and left>0:
			windows[id]=left
			service.apply_buff(row)
			world.active_skill_buffs[str(row.name)].remaining=left
		else:turn_off(row)
	for row: Dictionary in rows():
		if str(row.local_kind)=="berserk" and world.active_skill_buffs.has(str(row.name)):
			var stats: Dictionary = row.stats.duplicate(true)
			stats.meleeDamage += int(world._effective_attribute("INT")*float(row.int_damage_scale))
			world.active_skill_buffs[str(row.name)].skill_stats=stats

func attack_range_bonus() -> int:
	var row := row_named("버서커스")
	if not active(row) or not world.active_skill_buffs.has(str(row.name)): return 0
	return int(row.stats.get("attackRangeCells",0))
