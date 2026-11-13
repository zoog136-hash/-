extends SceneTree
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const TRACE = preload("res://scripts/monsters/spawn_setup_trace.gd")
var errors: Array[String] = []
var checks: int = 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: errors.append(label)
func _initialize() -> void:
	HITCH.reset_for_test("user://setup_trace_test")
	DirAccess.make_dir_recursive_absolute(HITCH._dir)
	HITCH.frame("test")
	var trace := TRACE.new()
	trace.identify({"source_m_npc_id":123,"source_m_sprite_id":456})
	# Deterministic synthetic timestamp, not a device benchmark.
	trace._started -= 120000
	trace._boundary -= 120000
	trace.phase("definition")
	trace.phase("current_view")
	trace.finish(false)
	var sample: Dictionary = HITCH._slow_spawn.duplicate(true)
	check(sample.npc == 123 and sample.sprite == 456 and not sample.accepted,"failed setup keeps scalar identity")
	var total: int = 0
	for value: int in sample.phases_usec.values(): total += value
	check(total == sample.usec,"exclusive phase boundaries sum to single setup duration")
	check(sample.phases_usec.has("reset") and sample.phases_usec.has("definition") and sample.phases_usec.has("current_view"),"last failure phase is retained")
	check(HITCH._details.has("setup.current_view") and HITCH._sections.is_empty(),"subphases do not inflate exclusive frame sections")
	HITCH.slow_spawn({"usec":100001,"npc":1})
	check(HITCH._slow_spawn.npc == 123,"only longest slow setup is retained")
	HITCH.backdate_frame_for_test(200000)
	HITCH.frame("test")
	check(HITCH.summary().worst[0].slow_spawn == sample,"per-frame sample survives frame reset")
	check(HITCH._slow_spawn.is_empty(),"sample resets each frame")
	HITCH._previous = HITCH.summary()
	check(HITCH.previous_line().contains("단일 NPC 123 setup reset 120ms"),"photo line exposes exclusive phase and actor")
	HITCH.enabled = false
	var disabled := TRACE.new()
	disabled.phase("disabled")
	disabled.finish(true)
	check(HITCH._details.is_empty() and HITCH._slow_spawn.is_empty(),"disabled tracing records nothing")
	HITCH.reset_for_test("user://setup_trace_test")
	print("SPAWN_SETUP_TRACE_RESULT ",JSON.stringify({"checks":checks,"failures":errors}))
	quit(0 if errors.is_empty() else 1)
