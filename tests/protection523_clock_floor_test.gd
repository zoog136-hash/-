extends SceneTree
# The saved protection clock must stay put while nothing time-limited is
# running (identical saves are skipped), keep every crossed buff/cooldown end
# (a rollback never re-opens an expired buff) and, while a buff runs, advance
# by whole minutes only (rollback gain < 60 s).

const Runtime = preload("res://scripts/protection/protection523_runtime.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures: Array[String] = []
	var service = Runtime.new()
	var start: int = 1_800_000_020
	service.state = Runtime.fresh()
	service.state.last_seen = start
	if service.persisted_last_seen(start + 1) != start or service.persisted_last_seen(start + 3600) != start:
		failures.append("idle saves still move the saved clock")
	service.state.active = {"item_id":1,"until":start + 1800}
	service.state.cooldowns = {"1":start + 3600}
	var running: int = service.persisted_last_seen(start + 125)
	if running != start + 125 - posmod(start + 125, 60) or posmod(running, 60) != 0:
		failures.append("active buff clock is not stepped by whole minutes")
	var same_minute: int = start + 125 - posmod(start + 125, 60) + 59
	if service.persisted_last_seen(same_minute) != running:
		failures.append("saved clock changed inside one minute")
	for offset: int in [1, 59, 125, 1799]:
		var seen: int = service.persisted_last_seen(start + offset)
		if seen > start + offset or start + offset - seen >= 60:
			failures.append("rollback gain while the buff runs is not below 60 s at +%d" % offset)
	if service.persisted_last_seen(start + 1801) != start + 1800 or service.persisted_last_seen(start + 3000) != start + 1800:
		failures.append("expired buff end is not kept, so a rollback could re-open it")
	if service.persisted_last_seen(start + 4000) != start + 3600:
		failures.append("crossed cooldown end is not kept")
	service.state.last_seen = start + 9000
	if service.persisted_last_seen(start + 4000) != start + 9000:
		failures.append("saved clock decreased")
	service.policy.elapsed_while_closed = false
	service.state.last_seen = start
	if service.persisted_last_seen(start + 7) != start + 7:
		failures.append("paused-clock policy lost exact play time")
	print("PROTECTION523_CLOCK_FLOOR_RESULT ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
