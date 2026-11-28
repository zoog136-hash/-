extends SceneTree
## C01-C03: a cost is paid only for an attack/skill motion that registers.
## In the actual Main world:
##   C01 a normal bow attack whose registration is refused keeps its arrow;
##   C02 an original skill whose registration is refused keeps MP, HP, items
##       and cooldown; a refused payment (save failure) withdraws only that
##       registration (pending entry, motion, broken buffs), not every combat
##       action; a normal cast still pays once and registers;
##   C03 the older direct status/job skills check the registration before
##       taking MP and report the refusal instead of a success.
## Refusals use real states: a Halphas charge in progress and a CannotCastSpell
## NPC effect (both refuse _queue_player_attack after the caller's checks).
##   godot --headless --path <repo> --script res://tests/combat_cost_registration_test.gd
const QA = preload("res://tests/qa_class_selection.gd")
const CATALOG = preload("res://scripts/skills/skill_catalog.gd")
var checks: int = 0
var failures: Array[String] = []
var report: Dictionary = {}

class SpellBlock extends "res://scripts/monsters/patch523_npc_combat.gd":
	var blocked: Array = []
	func blocks(name: String) -> bool: return blocked.has(name)

## The live service with a payment owner that refuses (a failed save).
class RefusedPayment extends "res://scripts/skills/skill_service.gd":
	var paid: int = 0
	func spend(_skill: Dictionary, _changed: Variant = null) -> bool:
		paid += 1
		return false

class CountedPayment extends "res://scripts/skills/skill_service.gd":
	var plans: int = 0
	func material_plan(skill: Dictionary) -> Dictionary:
		plans += 1
		return super.material_plan(skill)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("COMBAT_COST_REGISTRATION_FAIL: " + label)

func _initialize() -> void: call_deferred("run")

func monster(world: Node, offset: Vector2) -> TwilightMonster:
	var target: TwilightMonster = preload("res://scenes/Monster.tscn").instantiate()
	target.position = world.monsters_root.to_local(world.player.global_position + offset)
	world.monsters_root.add_child(target)
	target.setup({"name":"combat_cost_fixture","hp":1000000000,"lv":1,"atk":0}, world.player, world, null)
	target.set_physics_process(false)
	target.hp = 1000000000
	return target

func idle(world: Node) -> void:
	world.player.cancel_attack()
	world.pending_attack.clear()
	world.auto_attack_timer = 0.0
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0.0
	world.halphas_star.combat.charge = {}

func state(world: Node, skill_name: String = "") -> Dictionary:
	return {"mp":world.mp, "hp":world.hp, "inventory":world.inventory.duplicate(true), "cooldown":float(world.skill_cooldowns.get(skill_name, 0.0)), "global":world.skill_global_cooldown}

## An original magic attack the current class can cast here (learned, Lv.90).
func castable_magic(world: Node, target: TwilightMonster) -> Dictionary:
	var service = world.original_skills
	var catalog = service.catalog
	for record: Dictionary in catalog.records:
		if str(record.get("activation", "")) != "active": continue
		world.job_class = str(record.get("class", world.job_class))
		world.level = 90
		catalog.learned[str(record.id)] = 1
		catalog.revision += 1
		var skill: Dictionary = catalog.resolve(record)
		var usable: bool = str(skill.get("mode", "")) == "attack" and str(skill.get("shape", "single")) == "single" and str(skill.get("attack_type", "magic")) == "magic" and int(skill.get("mp", 0)) > 0 and not skill.has("spell_move523") and not bool(skill.get("local_design", false)) and service.estimated_nodes.kind(skill) != "grab" and catalog.approx_transform_for(str(skill.get("id", ""))).is_empty()
		if usable and service.ready(record) and CATALOG.SOURCE523.target_allowed(skill, target) and world._skill_target(float(skill.get("range", 240))) == target:
			return record
		catalog.learned.erase(str(record.id))
		catalog.revision += 1
	return {}

func run() -> void:
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world, "기사"), "actual Main class confirmation")
	world.player.set_physics_process(false)
	# Without the installed 523 map (CI) the world has no field and no grid, so
	# nothing is ever visible: give the fixture an open grid around the player.
	if world.field_map == null and world.astar == null:
		var grid := AStarGrid2D.new()
		var cell: Vector2i = world._world_to_cell(world.player.global_position)
		grid.region = Rect2i(cell - Vector2i(16, 16), Vector2i(33, 33))
		grid.cell_size = Vector2(world.tile_size, world.tile_size)
		grid.update()
		world.astar = grid
		report["open_grid_fixture"] = true
	# A visible spot next to the player (the starting square may face a wall).
	var offset := Vector2.ZERO
	for distance: float in [40.0, 32.0, 24.0, 56.0]:
		for step: int in 8:
			var candidate: Vector2 = Vector2.RIGHT.rotated(TAU * step / 8.0) * distance
			if offset == Vector2.ZERO and world._has_line_of_sight_world(world.player.global_position, world.player.global_position + candidate): offset = candidate
	check(offset != Vector2.ZERO, "a visible target spot next to the player")
	var target: TwilightMonster = monster(world, offset)
	report["target_offset"] = [offset.x, offset.y]
	world.selected_monster = target
	world.hp = world._effective_max_hp()
	world.mp = world._effective_max_mp()
	# --- C01: normal ranged attack ---------------------------------------
	world.equipped_items["weapon"] = {"name":"combat_cost_fixture_bow","type":"활","attackKind":"ranged"}
	world._invalidate_equipment_static()
	world.inventory["화살"] = 10
	world.equipped_ammo = "화살"
	world.ammo_unequipped = false
	check(world._current_ammo_name() == "화살" and world._current_attack_kind() == "ranged", "fixture bow uses arrows")
	idle(world)
	check(world._target_in_current_weapon_range(target) and world._has_line_of_sight_world(world.player.global_position, target.global_position), "C01 target is in range and visible")
	world.halphas_star.combat.charge = {"fixture":true}
	world._attack()
	check(int(world.inventory.get("화살", 0)) == 10, "C01 refused attack registration keeps the arrow: %s" % str(world.inventory.get("화살")))
	check(world.pending_attack.is_empty(), "C01 refused attack registers nothing")
	idle(world)
	world._attack()
	check(int(world.inventory.get("화살", 0)) == 9 and not world.pending_attack.is_empty() and bool(world.pending_attack.get("normal", false)), "C01 a registered attack pays one arrow: %s" % str(world.inventory.get("화살")))
	report["c01"] = {"after_refusal":10, "after_attack":int(world.inventory.get("화살", 0))}
	idle(world)
	world.equipped_items.erase("weapon")
	world._invalidate_equipment_static()
	# --- C02: original skill cast ------------------------------------------
	var record: Dictionary = castable_magic(world, target)
	check(not record.is_empty(), "an original magic attack is castable in this build")
	if not record.is_empty():
		var service = world.original_skills
		var skill_name: String = str(record.name)
		var blocker := SpellBlock.new()
		var spells = world.patch523_npc_spells
		world.patch523_npc_spells = blocker
		world.mp = world._effective_max_mp()
		idle(world)
		blocker.blocked = ["CannotCastSpell"]
		var before: Dictionary = state(world, skill_name)
		check(not service.cast(record), "C02 refused registration reports failure")
		check(state(world, skill_name) == before, "C02 refused registration keeps MP/HP/items/cooldown: %s -> %s" % [str(before), str(state(world, skill_name))])
		check(world.pending_attack.is_empty(), "C02 refused registration leaves no pending action")
		blocker.blocked = []
		# A refused payment withdraws only this registration.
		var refusing := RefusedPayment.new()
		for property: String in ["world", "catalog", "vfx", "status", "summons", "local_runtime", "estimated_nodes", "progression", "spell_move", "equipment_links", "equipment_balance", "runtime_defaults"]:
			refusing.set(property, service.get(property))
		world.active_skill_buffs["combat_cost_fixture_buff"] = {"remaining":30.0, "break_on_attack":true, "stats":{}}
		var generation: int = world.combat_generation
		before = state(world, skill_name)
		check(not refusing.cast(record) and refusing.paid == 1, "C02 refused payment reports failure")
		check(state(world, skill_name) == before, "C02 refused payment keeps MP/HP/items/cooldown")
		check(world.pending_attack.is_empty() and not world.player.motion.active, "C02 refused payment withdraws the registered motion")
		check(world.active_skill_buffs.has("combat_cost_fixture_buff"), "C02 refused payment restores the buff its registration broke")
		check(world.combat_generation == generation, "C02 refused payment clears no other combat action (no combat generation reset)")
		world.active_skill_buffs.erase("combat_cost_fixture_buff")
		# The normal cast: pays once, registers, starts the cooldown.
		idle(world)
		world.mp = world._effective_max_mp()
		var mp0: int = world.mp
		var cost: int = int(service.catalog.resolve(record).get("mp", 0))
		check(service.cast(record), "C02 normal cast succeeds")
		check(world.mp == mp0 - cost and not world.pending_attack.is_empty() and world.pending_attack.has("original_skill") and float(world.skill_cooldowns.get(skill_name, 0.0)) >= 0.0 and world.skill_global_cooldown > 0.0, "C02 normal cast pays once and registers")
		var payment := CountedPayment.new()
		payment.world = world
		payment.estimated_nodes = service.estimated_nodes
		payment.progression = service.progression
		var resolved: Dictionary = service.catalog.resolve(record)
		world.mp = 0
		check(not payment.spend(resolved) and payment.plans == 0, "a refused MP cost does not quote materials")
		world.mp = mp0
		check(payment.spend(resolved) and payment.plans == 1 and world.mp == mp0-cost, "one payment quotes the same material plan once")
		report["c02"] = {"skill":skill_name, "mp_cost":cost}
		idle(world)
		world.patch523_npc_spells = spells
		service.catalog.learned.erase(str(record.id))
		service.catalog.revision += 1
	# --- C03: older direct status skills and job skills --------------------
	world.mp = world._effective_max_mp()
	for entry: Array in [["stun", func() -> bool: return world._cast_stun_skill(target)], ["poison", func() -> bool: return world._cast_poison_skill(target)], ["hold", func() -> bool: return world._cast_hold_skill(target)], ["fear", func() -> bool: return world._cast_fear_skill(target)], ["silence", func() -> bool: return world._cast_silence_skill(target)], ["magic", func() -> bool: return world._cast_magic_attack(target, 10, 3, "fixture")], ["bleed", func() -> bool: return world._cast_bleed_skill(target)]]:
		idle(world)
		world.halphas_star.combat.charge = {"fixture":true}
		var mp_before: int = world.mp
		var result: bool = (entry[1] as Callable).call()
		check(not result and world.mp == mp_before and world.pending_attack.is_empty(), "C03 %s: refused registration keeps MP and reports failure (result=%s, mp %d -> %d)" % [entry[0], str(result), mp_before, world.mp])
		idle(world)
		mp_before = world.mp
		result = (entry[1] as Callable).call()
		check(result and world.mp < mp_before and not world.pending_attack.is_empty(), "C03 %s: registered cast pays MP" % entry[0])
	var job: Dictionary = {"name":"combat_cost_fixture_status", "effect":"stun", "mp":7, "range":120, "duration":1.0}
	for kind: String in ["status", "damage", "turn"]:
		idle(world)
		world.mp = world._effective_max_mp()
		world.halphas_star.combat.charge = {"fixture":true}
		var mp_before: int = world.mp
		var result: bool
		if kind == "status": result = world._cast_job_status_skill(job)
		elif kind == "damage": result = world._cast_job_damage_skill(job)
		elif world.has_method("_register_then_spend_skill"): result = world.call("_register_then_spend_skill", job, world._queue_player_attack.bind(target, "magic", func() -> void: pass, 0.4, false, 200.0))
		else:
			check(false, "C03 shared register-then-pay owner exists")
			continue
		check(not result and world.mp == mp_before and world.pending_attack.is_empty(), "C03 job %s: refused registration keeps MP (result=%s)" % [kind, str(result)])
	# A refused payment (MP short) after registration withdraws only that motion.
	idle(world)
	world.active_skill_buffs["combat_cost_fixture_buff"] = {"remaining":30.0, "break_on_attack":true, "stats":{}}
	world.mp = 1
	var generation_before: int = world.combat_generation
	check(world.has_method("_register_then_spend_skill") and not world.call("_register_then_spend_skill", {"name":"x", "mp":999}, world._queue_player_attack.bind(target, "melee", func() -> void: pass, 0.4, false, 200.0)), "C03 refused payment reports failure")
	check(world.mp == 1 and world.pending_attack.is_empty() and not world.player.motion.active and world.active_skill_buffs.has("combat_cost_fixture_buff") and world.combat_generation == generation_before, "C03 refused payment withdraws only its registration")
	world.active_skill_buffs.erase("combat_cost_fixture_buff")
	idle(world)
	world.mp = world._effective_max_mp()
	var paid_before: int = world.mp
	check(world._cast_job_status_skill(job) and world.mp == paid_before - 7 and not world.pending_attack.is_empty(), "C03 job status skill registers and pays once")
	idle(world)
	target.queue_free()
	print("COMBAT_COST_REGISTRATION_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "report":report}))
	quit(0 if failures.is_empty() else 1)
