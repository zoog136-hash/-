extends RefCounted
## User-authorized local behavior for eight unresolved composition references.
## This is not an interpreter for native node IDs or a restored server formula.
var owner_ref: WeakRef
var service: RefCounted:
	get: return owner_ref.get_ref()
var world: Node
var cloak_lock: float = 0.0
var protection_icd: float = 0.0

func configure(owner: RefCounted) -> void:
	owner_ref = weakref(owner)
	world = owner.world

func clear() -> void:
	cloak_lock = 0
	protection_icd = 0

func tick(delta: float) -> void:
	cloak_lock = maxf(0, cloak_lock - delta)
	protection_icd = maxf(0, protection_icd - delta)

static func kind(skill: Dictionary) -> String:
	return str(skill.get("estimated523", {}).get("kind", ""))

func cost_reason(skill: Dictionary) -> String:
	if cloak_lock > 0 and (str(skill.get("mode", "")) == "stealth" or bool(skill.get("stealth_after", false))): return "탐지 효과 · 재은신 %.1f초 후 가능" % cloak_lock
	return ""

func hidden_targets(skill: Dictionary) -> Array[TwilightMonster]:
	var result: Array[TwilightMonster] = []
	for node: Node in world.monsters_root.get_children():
		if not node is TwilightMonster or node.dead or not node.concealed523: continue
		if world.player.global_position.distance_to(node.global_position) > float(skill.radius): continue
		if not world._has_line_of_sight_world(world.player.global_position, node.global_position): continue
		result.append(node)
	return result

func detect(skill: Dictionary) -> void:
	var targets := hidden_targets(skill)
	for target: TwilightMonster in targets: target.reveal523(float(skill.duration))
	cloak_lock = maxf(cloak_lock, float(skill.duration))
	service.vfx.emit_skill(service.presentation_id(skill), "impact", world.player.global_position)
	world.hud.show_message("카운터 디텍션 · %d명 탐지 · 재은신 %.0f초 차단 (추정)" % [targets.size(), float(skill.duration)])

func dash_plan(skill: Dictionary, target: TwilightMonster) -> Vector2:
	var start: Vector2 = world.player.global_position
	var end: Vector2
	if is_instance_valid(target):
		end = target.global_position + target.global_position.direction_to(start) * 24.0 if start.distance_to(target.global_position) > 36.0 else start
	else:
		var direction: Vector2 = world.player.motion.direction
		if direction.is_zero_approx(): direction = Vector2.DOWN
		end = start + direction.normalized() * float(skill.dash_distance)
	var steps := maxi(1, int(ceil(start.distance_to(end) / 8.0)))
	for index: int in range(1, steps + 1):
		var point := start.lerp(end, float(index) / steps)
		if not world._is_walkable_world(point) or not world.field_map.point_clear(point, 4.0) or not world._has_line_of_sight_world(start, point): return Vector2.INF
	return end

func move_to(end: Vector2) -> void:
	world.player.clear_click_path()
	world.player.global_position = end
	world.player.camera.reset_smoothing()

func incoming(amount: int, attacker: TwilightMonster) -> void:
	if amount <= 0 or protection_icd > 0 or not is_instance_valid(attacker) or attacker.dead: return
	var base: Dictionary = service.catalog.record_for("lmref_32fab3b95ec26e3d")
	if kind(base) != "protection" or not service.catalog.enabled(base): return
	var skill: Dictionary = service.catalog.resolve(base)
	# Start on attempt: multihits cannot obtain a second roll in this window.
	protection_icd = float(skill.shield_cooldown)
	if world.rng.randf() >= float(skill.shield_chance): return
	service.shields[str(skill.id)] = {"amount":int(skill.shield_amount),"remaining":float(skill.shield_duration)}
	var aura := skill.duplicate(true)
	aura["duration"] = float(skill.shield_duration)
	aura["stats"] = {} # Permanent passive stats must not apply twice via its aura.
	service.apply_buff(aura)
	service.event_counts[str(skill.id)] = int(service.event_counts.get(str(skill.id), 0)) + 1
	world.hud.show_message("썬더 프로텍션(미스틱) · 보호막 %d (추정)" % int(skill.shield_amount))
