extends RefCounted
## Original current523 SpellMove executor.
## SpellMoveEffectSet (SpellID -> Begin/Middle/End) and SpellMoveEffect
## (EffectSpriteID, ScreenEffectID, SpeedMultiplier, EffectSpriteWatchTargetKind)
## declare which spells are moves and their phase presentation. The movement
## numbers live in the same spell's base-level SpellBonus rows:
##   caster dash  : SpellMoveMultiple (cells), CasterMoveLimitMaxRange (stop
##                  cells from target), SpellMoveLimitPathCount (path cells),
##                  CastSpeedAlterMoveSpeedMultiplier (% of move speed)
##   target pull  : TargetMove, TargetMoveLimitCellCount (cells from caster)
##   knockback    : TargetKnockback/KnockBack, SpellMoveMultiple (cells),
##                  MaxKnockbackDistanceByWeaponType / MaxKnockbackDistance
## A plan whose required numbers are absent is not ready and is never run with
## a substitute. Cells use the existing labelled distance policy (raw cell ->
## host length). SpeedMultiplier's unit is unconfirmed: preserved, not used.
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const POLICY_PATH := "res://data/skills/current523_distance_input_policy.json"
const PVE_TARGET_KINDS := [2, 3, 11, 422] # All, Enemy, AllButMe, AttackableNPC
const HANDLED := ["SpellMoveMultiple", "CasterMoveLimitMaxRange", "SpellMoveLimitPathCount",
	"SpellMovePathFindRange", "CastSpeedAlterMoveSpeedMultiplier", "TargetMove",
	"TargetMoveLimitCellCount", "TargetKnockback", "KnockBack", "MaxKnockbackDistanceByWeaponType",
	"MaxKnockbackDistance", "IgnoreMoveOccupy", "IgnoreCannotMoveTarget"]
const STEP := 8.0
var world: Node
var active: Dictionary = {}
var last_event: Dictionary = {}
static var _plans: Dictionary = {}
static var _plan_key: String = ""
static var _cell: float = -1.0

static func cell_length() -> float:
	if _cell <= 0.0:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
		_cell = float(parsed.get("cast_range_to_host_length", 32.0)) if parsed is Dictionary and bool(parsed.get("enabled", false)) else 32.0
	return _cell

## Plan from the held original archive. {} when the spell has no move set.
static func plan(spell_id: int) -> Dictionary:
	if DEF.identity().is_empty(): return {}
	var key: String = DEF.verified_key()
	if key != _plan_key: _plans.clear(); _plan_key = key
	if _plans.has(spell_id): return (_plans[spell_id] as Dictionary).duplicate(true)
	var result: Dictionary = {}
	var sets: Array[Dictionary] = []
	if spell_id > 0: sets = DEF.related("SpellMoveEffectSet", "SpellID", spell_id)
	if sets.size() == 1:
		var phases: Dictionary = {}
		for phase: String in ["Begin", "Middle", "End"]:
			phases[phase.to_lower()] = DEF.row("SpellMoveEffect", int(sets[0].get(phase + "ID", -1)))
		var bonuses: Array = []
		for link: Dictionary in DEF.related("SpellBonus", "SpellClassID", spell_id):
			var bonus: Dictionary = DEF.row("Bonus", int(link.get("BonusID", -1)))
			var kind: Dictionary = DEF.row("BonusType", int(bonus.get("BonusTypeID", -1))) if not bonus.is_empty() else {}
			if kind.is_empty(): continue
			bonuses.append({"name":str(kind.get("Name", "")), "value":bonus.get("Value"), "min_level":int(link.get("MinSpellLevel", 0)),
				"application":int(bonus.get("BonusApplicationTypeID", 0)), "target":int(bonus.get("BonusApplicationTargetID", 0))})
		result = plan_from(DEF.row("SpellClass", spell_id), sets[0], phases, bonuses)
	elif sets.size() > 1:
		result = {"ok":false, "spell_id":spell_id, "missing":["SpellMoveEffectSet 중복 행"]}
	_plans[spell_id] = result
	return result.duplicate(true)

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

## Pure plan builder (rows supplied by the caller; used by tests too).
static func plan_from(spell: Dictionary, move_set: Dictionary, phases: Dictionary, bonuses: Array) -> Dictionary:
	var plain: Dictionary = {}
	var by_weapon: Dictionary = {}
	var unhandled: Dictionary = {}
	for entry: Dictionary in bonuses:
		if int(entry.get("min_level", 0)) != 0: continue # Base spell level only.
		var name: String = str(entry.name)
		if name == "MaxKnockbackDistanceByWeaponType" and int(entry.application) == 22 and _number(entry.value):
			by_weapon[int(entry.target)] = int(entry.value)
		elif name in HANDLED and int(entry.application) == 0 and int(entry.target) == 0 and _number(entry.value):
			plain[name] = int(entry.value)
		elif not name in HANDLED:
			unhandled[name] = true
	var result: Dictionary = {"ok":false, "spell_id":int(spell.get("ID", move_set.get("SpellID", 0))), "spell_name":str(spell.get("Name", "")),
		"move_set_id":int(move_set.get("ID", 0)), "kind":"", "missing":[], "unhandled":unhandled.keys(),
		"cast_range_cells":int(spell.get("CastRange", 0)), "min_cast_range_cells":int(spell.get("MinCastRange", 0)),
		"targeting":int(spell.get("TargettingTypeID", 0)), "target_kind":int(spell.get("TargetKindID", 0)),
		"path_find_cells":int(plain.get("SpellMovePathFindRange", 0)), "path_limit_cells":int(plain.get("SpellMoveLimitPathCount", 0)),
		"speed_percent":int(plain.get("CastSpeedAlterMoveSpeedMultiplier", 0)),
		"ignore_move_occupy":int(plain.get("IgnoreMoveOccupy", 0)) == 1, "ignore_cannot_move_target":int(plain.get("IgnoreCannotMoveTarget", 0)) == 1,
		"phases":{}}
	for phase: String in phases:
		var row: Dictionary = phases[phase]
		result.phases[phase] = {} if row.is_empty() else {"id":int(row.ID), "effect_sprite_id":int(row.get("EffectSpriteID", 0)),
			"screen_effect_id":int(row.get("ScreenEffectID", 0)), "speed_multiplier_raw":int(row.get("SpeedMultiplier", 0)),
			"watch_target_kind":int(row.get("EffectSpriteWatchTargetKind", 0))}
	var missing: Array = result.missing
	for phase: String in ["begin", "middle", "end"]:
		if (result.phases.get(phase, {}) as Dictionary).is_empty(): missing.append("SpellMoveEffect %s 행 없음" % phase)
	if spell.is_empty() or bool(spell.get("TestSpell", false)): missing.append("SpellClass 행 없음 또는 테스트 주문")
	if int(plain.get("TargetKnockback", 0)) == 1 or int(plain.get("KnockBack", 0)) == 1:
		result.kind = "target_knockback"
		if not plain.has("SpellMoveMultiple"): missing.append("넉백 거리(SpellMoveMultiple) 없음")
		result["move_cells"] = int(plain.get("SpellMoveMultiple", 0))
		result["max_cells_by_weapon"] = by_weapon
		if plain.has("MaxKnockbackDistance"): result["max_cells"] = int(plain.MaxKnockbackDistance)
	elif int(plain.get("TargetMove", 0)) == 1:
		result.kind = "target_pull"
		if not plain.has("TargetMoveLimitCellCount"): missing.append("끌어온 뒤 시전자와의 거리(TargetMoveLimitCellCount) 없음")
		result["stop_cells"] = int(plain.get("TargetMoveLimitCellCount", 0))
	elif plain.has("SpellMoveMultiple"):
		result.kind = "caster_dash"
		result["move_cells"] = int(plain.SpellMoveMultiple)
		if not plain.has("CasterMoveLimitMaxRange"): missing.append("돌진 후 대상과의 거리(CasterMoveLimitMaxRange) 없음")
		if not plain.has("CastSpeedAlterMoveSpeedMultiplier"): missing.append("돌진 이동 속도(CastSpeedAlterMoveSpeedMultiplier) 없음")
		result["stop_cells"] = int(plain.get("CasterMoveLimitMaxRange", 0))
	else:
		missing.append("이동 종류(SpellMoveMultiple/TargetMove/TargetKnockback) 미기재")
	if result.targeting != 2: missing.append("TargettingTypeID %d: 단일 대상 외 이동 방향·지점 규칙 없음" % int(result.targeting))
	if not int(result.target_kind) in PVE_TARGET_KINDS: missing.append("TargetKindID %d: 몬스터 대상이 아님(PC 전용 등)" % int(result.target_kind))
	if int(result.min_cast_range_cells) != 0: missing.append("MinCastRange %d 처리 규칙 없음" % int(result.min_cast_range_cells))
	if int(result.cast_range_cells) <= 0: missing.append("CastRange 없음")
	result.ok = missing.is_empty()
	return result

func configure(scene: Node) -> void:
	world = scene

func clear() -> void:
	active.clear()

func busy() -> bool:
	return not active.is_empty()

func _clear_point(point: Vector2) -> bool:
	if not world._is_walkable_world(point): return false
	var field: Variant = world.get("field_map")
	if field != null and field.has_method("point_clear") and not field.point_clear(point, 4.0): return false
	return true

func _monster_landing(point: Vector2) -> bool:
	if not _clear_point(point): return false
	var field: Variant = world.get("field_map")
	return not (field != null and field.has_method("is_safe") and field.is_safe(point))

## Straight segment check; returns the last clear point before an obstacle.
func _last_clear(from: Vector2, to: Vector2, landing: Callable) -> Vector2:
	var steps: int = maxi(1, int(ceil(from.distance_to(to) / STEP)))
	var last: Vector2 = from
	for index: int in range(1, steps + 1):
		var point: Vector2 = from.lerp(to, float(index) / steps)
		if not landing.call(point) or not world._has_line_of_sight_world(from, point): return last
		last = point
	return last

func _route_length(route: PackedVector2Array, from: Vector2) -> float:
	var total: float = 0.0
	var previous: Vector2 = from
	for point: Vector2 in route:
		total += previous.distance_to(point); previous = point
	return total

## Validates and starts one move. Nothing is spent or moved on rejection.
func begin(move: Dictionary, target: Node2D, weapon_type_id: int = -1) -> Dictionary:
	var prepared: Dictionary = prepare(move, target, weapon_type_id)
	return commit(prepared) if bool(prepared.get("ok", false)) else prepared

## Applies a prepared move (after the caller has paid for it).
func commit(prepared: Dictionary) -> Dictionary:
	var event: Dictionary = prepared.event
	match str(prepared.get("apply", "")):
		"none":
			last_event = event
		"dash":
			var player: Node2D = world.player
			active = {"kind":"caster_dash", "node":weakref(player), "route":prepared.route, "index":0, "speed":float(prepared.speed), "event":event}
			if player.has_method("clear_click_path"): player.clear_click_path()
		"place":
			var target: Node2D = (prepared.target as WeakRef).get_ref()
			if not is_instance_valid(target): return {"ok":false, "reason":"이동 대상이 사라졌습니다"}
			return _place_target(target, prepared.point, event)
	return {"ok":true, "event":event}

## Validation and geometry only: never moves anything.
func prepare(move: Dictionary, target: Node2D, weapon_type_id: int = -1) -> Dictionary:
	if not bool(move.get("ok", false)): return {"ok":false, "reason":"원본 이동 자료 부족: " + ", ".join(PackedStringArray(move.get("missing", [])))}
	if busy(): return {"ok":false, "reason":"이동 효과 진행 중"}
	if not is_instance_valid(target) or bool(target.get("dead")): return {"ok":false, "reason":"이동 대상이 없습니다"}
	var cell: float = cell_length()
	var caster: Vector2 = world.player.global_position
	var start: Vector2 = target.global_position
	var distance: float = caster.distance_to(start)
	if distance > float(move.cast_range_cells) * cell + 0.5: return {"ok":false, "reason":"대상이 사거리 %d칸 밖에 있습니다" % int(move.cast_range_cells)}
	var event: Dictionary = {"spell_id":int(move.spell_id), "kind":str(move.kind), "caster_before":caster, "target_before":start, "cell":cell}
	match str(move.kind):
		"caster_dash":
			var stop: float = float(move.stop_cells) * cell
			var limit: float = float(move.move_cells) * cell
			if int(move.path_limit_cells) > 0: limit = minf(limit, float(move.path_limit_cells) * cell)
			if distance <= stop + 0.5:
				event["moved"] = 0.0; event["caster_after"] = caster
				return {"ok":true, "apply":"none", "event":event}
			var goal: Vector2 = start + start.direction_to(caster) * stop
			var route := PackedVector2Array()
			if _last_clear(caster, goal, _clear_point).distance_to(goal) <= 0.5: route.append(goal)
			elif world.has_method("find_world_path"):
				# Path search stays the existing host path engine; the original
				# path-count limit below is the only distance accepted.
				var found: PackedVector2Array = world.find_world_path(caster, start)
				for point: Vector2 in found:
					if point.distance_to(start) <= stop:
						route.append(start + start.direction_to(route[route.size() - 1] if not route.is_empty() else caster) * stop)
						break
					route.append(point)
			if route.is_empty(): return {"ok":false, "reason":"돌진 경로가 막혀 있습니다"}
			var length: float = _route_length(route, caster)
			if length > limit + 0.5: return {"ok":false, "reason":"돌진 거리 %d칸 초과 (필요 %.1f칸)" % [int(limit / cell), length / cell]}
			var base_speed: float = float(world.player.get("move_speed"))
			for factor: String in ["equipment_move_speed_multiplier", "skill_speed_multiplier"]:
				if world.player.get(factor) != null: base_speed *= float(world.player.get(factor))
			var speed: float = base_speed * float(move.speed_percent) / 100.0
			event["planned_cells"] = length / cell; event["speed"] = speed
			return {"ok":true, "apply":"dash", "route":route, "speed":speed, "event":event}
		"target_pull":
			var stop_pull: float = float(move.stop_cells) * cell
			if distance <= stop_pull + 0.5:
				event["moved"] = 0.0; event["target_after"] = start
				return {"ok":true, "apply":"none", "event":event}
			var landing: Vector2 = caster + caster.direction_to(start) * stop_pull
			# Pulled along the line toward the caster; stop at the last landing.
			return {"ok":true, "apply":"place", "target":weakref(target), "point":_last_clear(start, landing, _monster_landing), "event":event}
		"target_knockback":
			var cells: float = float(move.move_cells)
			var away: Vector2 = caster.direction_to(start)
			if away.is_zero_approx(): return {"ok":false, "reason":"넉백 방향을 정할 수 없습니다"}
			var end: Vector2 = start + away * cells * cell
			var caps: Dictionary = move.get("max_cells_by_weapon", {})
			var cap: int = int(caps.get(weapon_type_id, move.get("max_cells", -1)))
			if cap >= 0: end = caster + away * minf(caster.distance_to(end), float(cap) * cell)
			event["cap_cells"] = cap
			return {"ok":true, "apply":"place", "target":weakref(target), "point":_last_clear(start, end, _monster_landing), "event":event}
	return {"ok":false, "reason":"지원하지 않는 이동 종류"}

## Target moves have no declared speed in these rows: placed at once.
func _place_target(target: Node2D, point: Vector2, event: Dictionary) -> Dictionary:
	target.global_position = point
	if target.get("velocity") != null: target.set("velocity", Vector2.ZERO)
	event["target_after"] = point
	event["moved"] = (event.target_before as Vector2).distance_to(point)
	last_event = event
	return {"ok":true, "moved":event.moved, "event":event}

func tick(delta: float) -> void:
	if active.is_empty(): return
	var node: Node2D = active.node.get_ref()
	if not is_instance_valid(node) or (node.has_method("is_stunned") and node.is_stunned()) or (node.has_method("is_held") and node.is_held()):
		_finish("interrupted"); return
	var remaining: float = maxf(0.0, float(active.speed) * delta)
	var route: PackedVector2Array = active.route
	while remaining > 0.0 and int(active.index) < route.size():
		var waypoint: Vector2 = route[int(active.index)]
		var gap: float = node.global_position.distance_to(waypoint)
		if gap <= 0.5:
			active.index = int(active.index) + 1
			continue
		var step: float = minf(remaining, minf(STEP, gap))
		var next: Vector2 = node.global_position.move_toward(waypoint, step)
		if not _clear_point(next):
			_finish("blocked"); return
		if node.has_method("face_target"): node.face_target(next)
		node.global_position = next
		remaining -= step
	if int(active.index) >= route.size(): _finish("arrived")

func _finish(state: String) -> void:
	var event: Dictionary = active.get("event", {})
	var node: Node2D = active.node.get_ref() if active.has("node") else null
	event["state"] = state
	if is_instance_valid(node):
		event["caster_after"] = node.global_position
		event["moved"] = (event.caster_before as Vector2).distance_to(node.global_position)
	last_event = event
	active.clear()
