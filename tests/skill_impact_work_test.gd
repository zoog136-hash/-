extends "res://tests/skill_area_target_scan_test.gd"

const WORLD := preload("res://scripts/world.gd")
const NATIVE_STACK := preload("res://scripts/loot/current523_native_stack.gd")

class CastProbe extends TwilightOriginalSkillService:
	var attempts: int = 0

	func _cast_impl(_record: Dictionary, _manual: bool, _loading: bool, _area_only: bool = false) -> bool:
		attempts += 1
		return false

func _previous_impact(service: TwilightOriginalSkillService, skill: Dictionary) -> Array[TwilightMonster]:
	var origin: Vector2 = service.world.player.global_position
	var targets: Array[TwilightMonster] = service._area_candidates(skill, skill.shape, origin, origin)
	targets.sort_custom(func(a: TwilightMonster, b: TwilightMonster) -> bool:
		return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	if targets.size() > int(skill.targets): targets.resize(int(skill.targets))
	return targets

func _dense_impact() -> Array[Dictionary]:
	var probe: FieldProbe = make_field()
	var field := SOURCE_FIELD_FIXTURE.MemoryField.new()
	field.prepare({})
	probe.navigation = field
	var origin: Vector2 = field.cell_to_world(Vector2i(24, 24))
	probe.player.global_position = origin
	var service := TwilightOriginalSkillService.new()
	service.world = probe
	var skill := {"shape":"self_circle", "radius":144.0, "range":144.0, "targets":8, "source523":{"target_kind":"Enemy"}}
	# Reverse distance order so child order cannot stand in for range order.
	for i: int in range(47, -1, -1):
		spawn(probe, origin + Vector2.from_angle(i * 2.399963) * (18.0 + i * 2.3))
	var previous: Callable = _previous_impact.bind(service, skill)
	var current: Callable = service.targets.bind(skill, null)
	var expected: Array = previous.call()
	var rounds: Array[Dictionary] = []
	check(expected.size() == 8 and current.call() == expected, "dense S32 targets and their exact hit order survive the cap")
	for round_index: int in 3:
		var before: Dictionary
		var after: Dictionary
		if round_index % 2 == 0:
			before = time_queries(probe, previous)
			after = time_queries(probe, current)
		else:
			after = time_queries(probe, current)
			before = time_queries(probe, previous)
		check(before.sight_per_query == 48.0 and after.sight_per_query == 8.0,
			"eight visible victims are enough; each of the forty irrelevant wall calls is removed")
		rounds.append({"before":before, "after":after})
	# Real S32 collision failure at the closest candidate: move it behind a
	# denied cell and require the next reachable target, with the same order.
	var blocked: TwilightMonster = expected[0]
	var blocked_cell := Vector2i(26, 24)
	blocked.global_position = field.cell_to_world(blocked_cell)
	field.attribute(blocked_cell, 0, 1)
	field.attribute(blocked_cell, 1, 1)
	expected = previous.call()
	check(expected.size() == 8 and blocked not in expected and current.call() == expected,
		"a blocked candidate never fills a slot and the next reachable target does")
	field.close()
	probe.queue_free()
	return rounds

func _ties_and_idle_cast() -> void:
	var probe: FieldProbe = make_field()
	var service := CastProbe.new()
	service.world = probe
	var skill := {"shape":"self_circle", "radius":144.0, "targets":3, "source523":{"target_kind":"Enemy"}}
	check(not service.cast_auto_area(skill) and service.attempts == 0, "empty AUTO field does not enter admission or prepare costs")
	for i: int in range(1, 11):
		spawn(probe, Vector2(i * 8, 0))
		spawn(probe, Vector2(-i * 8, 0))
	probe.walls[Vector2(16, 0)] = true
	var before := _previous_impact(service, skill)
	probe.sight_checks = 0
	check(service.targets(skill, null) == before and probe.sight_checks == 20, "same-distance victims keep the full legacy filter and tie order")
	check(not service.cast_auto_area(skill) and service.attempts == 1, "once an actor enters, AUTO uses the normal cast path")
	probe.queue_free()

func _cooldowns() -> void:
	var world := WORLD.new()
	world.skill_global_cooldown = 0.15
	world._tick_skill_cooldowns(0.25)
	check(world.skill_global_cooldown == 0.0 and world.skill_cooldowns.is_empty(), "global skill cooldown advances with no individual cooldowns")
	world.item_use_cooldowns = {"potion":0.25, "scroll":0.75}
	check(not world._tick_item_buffs(0.25, false) and world.item_use_cooldowns == {"scroll":0.5}, "item cooldowns still expire with no active item buffs")
	world.active_skill_buffs = {"speed":{"remaining":1.0}}
	check(not world._tick_skill_buffs(0.25, false) and world.active_skill_buffs.speed.remaining == 0.75, "live skill buff time is updated in its existing record")
	world.free()

func _spell_binding_reads() -> Dictionary:
	var path: String = NATIVE_STACK.SPELL_BINDINGS_PATH
	var original: String = FileAccess.get_file_as_string(path)
	var pinned: Dictionary = NATIVE_STACK._checked_spell_bindings(original)
	check(not pinned.get("material_inventory_keys", {}).is_empty(), "material bindings are the pinned public definition")
	check(is_same(pinned, NATIVE_STACK._checked_spell_bindings(original)), "identical material definitions reuse parsed rows")
	check(NATIVE_STACK._checked_spell_bindings(original + " ").is_empty() and NATIVE_STACK._checked_spell_bindings("").is_empty(),
		"changed bytes and a missing binding file still fail after a valid read")
	var old_samples: Array[int] = []
	var new_samples: Array[int] = []
	for _sample: int in range(90):
		var start: int = Time.get_ticks_usec()
		var text: String = FileAccess.get_file_as_string(path)
		var fresh: Variant = JSON.parse_string(text)
		var digest: String = text.sha256_text()
		old_samples.append(Time.get_ticks_usec() - start)
		start = Time.get_ticks_usec()
		var cached: Dictionary = NATIVE_STACK._checked_spell_bindings(FileAccess.get_file_as_string(path))
		new_samples.append(Time.get_ticks_usec() - start)
		if digest != NATIVE_STACK.SPELL_BINDINGS_SHA or fresh != pinned or not is_same(pinned, cached):
			check(false, "every benchmark read returns the exact binding")
			break
	old_samples.sort()
	new_samples.sort()
	return {"n":old_samples.size(), "before_p95_us":old_samples[ceili(old_samples.size()*0.95)-1],
		"after_p95_us":new_samples[ceili(new_samples.size()*0.95)-1], "kept_bytes":original.to_utf8_buffer().size()}

func run() -> void:
	var rounds: Array[Dictionary] = _dense_impact()
	_ties_and_idle_cast()
	_cooldowns()
	await process_frame
	var bindings: Dictionary = _spell_binding_reads()
	print("SKILL_IMPACT_WORK_RESULT ", JSON.stringify({"checks":checks, "failures":failures, "synthetic_s32":rounds, "material_bindings":bindings}))
	quit(0 if failures.is_empty() else 1)
