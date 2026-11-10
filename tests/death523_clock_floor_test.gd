extends SceneTree
# The saved death-recovery clock must (a) stay put while nothing rule-relevant
# happens, so identical saves are skipped, and (b) after a clock rollback across
# a restart give the same 24h/hourly-gem/72h rule band as the real time.

const Runtime = preload("res://scripts/death/runtime.gd")

func _initialize() -> void:
	call_deferred("run")

func gem_steps(age: int) -> int:
	# Same expression as Runtime.quote() uses for the extended gem cost.
	return int(ceil(float(age - 86400 + 1) / 3600.0)) if age >= 86400 else 0

func band(age: int) -> Array:
	return [age >= 86400, age >= 259200, gem_steps(age)]

func run() -> void:
	var failures: Array[String] = []
	var service = Runtime.new()
	var at: int = 1_800_000_000
	service.state = Runtime.fresh()
	service.state.last_time = at
	service.state.next_id = 2
	service.state.records = [{"id":"1","at":at,"exp_claimed":false,"item_claimed":true}]
	var floors: Dictionary = {}
	for offset: int in [0, 1, 3600, 86399, 86400, 86401, 89999, 90000, 200000, 259199, 259200, 400000]:
		var floor_time: int = service.persisted_clock_floor(at + offset)
		floors[offset] = floor_time
		if floor_time > at + offset: failures.append("floor ahead of the clock at +%d" % offset)
		# Rolling the wall clock back to anything below the floor after a restart
		# resumes at the floor; it must sit in the same rule band as real time.
		if band(floor_time - at) != band(mini(offset, 259200)):
			failures.append("rollback changes the recovery rule band at +%d" % offset)
	if floors[0] != at or floors[86399] != at:
		failures.append("save clock moved before any rule boundary")
	if floors[86400] != floors[89999] or floors[90000] == floors[89999]:
		failures.append("save clock is not stepped at the hourly gem boundary")
	if floors[259200] != at + 259200 or floors[400000] != at + 259200:
		failures.append("expiry boundary not kept as the high-water mark")
	# A claimed record never moves the saved clock.
	service.state.records[0].exp_claimed = true
	if service.persisted_clock_floor(at + 300000) != at:
		failures.append("claimed record still advances the saved clock")
	# The saved value never goes backwards.
	service.state.last_time = at + 500000
	if service.persisted_clock_floor(at + 300000) != at + 500000:
		failures.append("saved clock decreased")
	print("DEATH523_CLOCK_FLOOR_RESULT ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
