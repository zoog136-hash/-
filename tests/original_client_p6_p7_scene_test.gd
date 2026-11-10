extends "res://tests/original_client_test_base.gd"
## C23 - C27 acceptance tests (C28 sound removed with the cut Sound tables) (design-level; the original binary is never executed).
const SEL = preload("res://scripts/original_client/target_selection.gd")
const INTENT = preload("res://scripts/original_client/client_intents.gd")
const LIFE = preload("res://scripts/original_client/world_session_lifecycle.gd")
const TRACE = preload("res://scripts/original_client/render_trace.gd")
const VISUAL = preload("res://scripts/original_client/world_visual.gd")

func run() -> void:
	# C23
	var st: Dictionary = SEL.make_state()
	var equal: Dictionary = SEL.timer_tick(st, SEL.INTERVAL_F32)
	check("C23-T01", equal.fired == false, "elapsed == interval does not fire")
	var big: Dictionary = SEL.timer_tick(st, 5.0)
	check("C23-T02", big.fired == true and big.state.timer_elapsed > 4.0, "large dt fires once and subtracts one interval only (no catch-up)")
	var cands: Array = [{"oid": 9, "primary": 5, "secondary": 1}, {"oid": 3, "primary": 5, "secondary": 1}, {"oid": 7, "primary": 2, "secondary": 9}]
	var ranked: Array = SEL.rank(cands)
	check("C23-T03", ranked[0].oid == 7 and ranked[1].oid == 9 and ranked[2].oid == 3, "ties keep input order (no LUID sort)")
	check("C23-T03", SEL.score(2, 8, 3) == ((2 << 10) + 16 + 9) and SEL.score(0, 0, 0, 150) == 150, "score = low32((nodes<<10)+dx*dx/4+dy*dy) (+origin bonus)")
	var kept: Dictionary = SEL.retain_front(true, [], false)
	check("C23-T04", kept.retention == true and kept.new_search_blocked == true and kept.reselect_succeeded == false, "retention blocks a new search even if re-selection fails")
	check("C23-T04", SEL.retain_front(true, [1], true).retention == false, "an exclusion lifts retention")
	check("C23-T04", SEL.selector3([{"category": "a", "candidates": []}, {"category": "b", "candidates": [1]}, {"category": "c", "candidates": [2]}]).category == "b", "selector3 returns the first non-empty category, not a union")
	var single: Dictionary = SEL.timer_tick(st, 0.4)
	var acc: Dictionary = st
	var fired_any: bool = false
	for i: int in 25:
		var r: Dictionary = SEL.timer_tick(acc, 0.016)
		acc = r.state
		fired_any = fired_any or r.fired
	check("C23-T05", single.fired == false and fired_any == true, "single 400ms does not fire; 25 x 16ms float32 accumulation can (strict > on rounding)")
	var paused: Dictionary = st.duplicate(true)
	paused.enabled = true
	paused.pause_reasons = ["ui_open"]
	check("C23-T01", paused.enabled and not SEL.is_running(paused), "enabled and pause reasons are separate states")
	var forced: Dictionary = st.duplicate(true)
	forced.current = 5
	forced.forced_state = "force"
	var gated: Dictionary = SEL.request_clear(forced, true)
	check("C23-T04", gated.current == 5 and gated.forced_state == "force" and SEL.request_clear(forced, false).current == null, "a gated clear is a no-op")

	# C24
	var recorder = INTENT.OfflineIntentRecorder.new()
	var entries: Array = [recorder.submit(INTENT.move([1, 2], true, false, false)), recorder.submit(INTENT.attack(77, true, false, true)),
		recorder.submit(INTENT.cast(5, 77, false, 1, false)), recorder.submit(INTENT.local_event_attack({"x": 1}))]
	var keys: Array = entries.map(func(e: Dictionary) -> String: return e.key)
	check("C24-T01", keys == ["wire:96", "wire:97", "wire:98", "local_event:97"] and keys[1] != keys[3], "wire 96/97/98 and local 97 are separate typed namespaces")
	check("C24-T02", INTENT.change_attack_target(0) == null and INTENT.change_attack_target(4).opcode == 0x9B, "CHANGE_ATTACK_TARGET with 0 builds nothing")
	check("C24-T03", INTENT.cast_target_parameter(4, 1234, Vector2i(3, 4)) == 1234 and INTENT.cast_target_parameter(1, 1234, Vector2i(3, 4)) == Vector2i(3, 4), "cast type 4 sends the actor LUID")
	check("C24-T04", entries[0].queued and entries[0].server_accepted == false and entries[0].socket_sent == false and entries[0].server_ack == null, "queue success is not server acceptance")
	check("C24-T03", INTENT.attack_priority(5, 5, true) and not INTENT.attack_priority(5, 6, true) and not INTENT.attack_priority(5, 5, false), "attack priority = remembered LUID AND condition")

	# C25
	var life: Dictionary = LIFE.local2(LIFE.make())
	var gone: Dictionary = LIFE.event3(life)
	check("C25-T01", gone.deleted_slots == ["root+70", "root+78"] and gone.raw_helpers.check_timer_updater.value == null and gone.handler == 0x01CC57A0, "event3 deletes root+70/+78 and nulls them")
	check("C25-T01", (gone.dynamic_loader.slots as Array) == ["root+60", "root+68"] and not ("root+60" in gone.deleted_slots) and not ("root+68" in gone.deleted_slots), "root+60/+68 are never deleted directly")
	var twice: Dictionary = LIFE.local2(life)
	check("C25-T02", (twice.log as Array).size() == 6 and (life.log as Array) == ["ui_state", "grid_init", "helpers_created"], "duplicate local2 re-runs the sequence; idempotence is not assumed")
	check("C25-T03", life.surfaces.source.size == Vector2i(928, 684) and life.surfaces.output.size == Vector2i(1200, 675) and life.surfaces.source.role == "render" and life.surfaces.output.role == "ui", "source/output surface sizes and roles are not swapped")
	check("C25-T03", LIFE.output_node().scale_y == -1.0 and LIFE.output_node().name == "LineageGame", "output node setup")
	check("C25-T01", LIFE.local3(life).grid == null, "local3 cleans the grid after deleting the helpers")

	# C26
	var suffix: Dictionary = TRACE.item_suffix(40, 0, true)
	check("C26-T01", suffix.start_index == 5 and suffix.visited_slots == 35, "V19")
	check("C26-T01", TRACE.item_suffix(40, 3, true).applied == false and TRACE.item_suffix(10, 0, true).visited_slots == 10, "cell+58 != 0 skips; short lists clamp")
	var cell: Dictionary = TRACE.process_cell(TRACE.make(), true, 40, 0, true)
	check("C26-T02", cell.floor_decision.accepted and cell.item_dispatcher_ran, "an accepted floor still runs the item dispatcher")
	var up: Dictionary = TRACE.texture_upload(TRACE.make(), 0, true)
	check("C26-T03", up.texture_upload.api_called and up.texture_upload.returned == false and up.screen_success == "UNOBSERVED", "API call and on-screen success are separate states")

	# C27
	var vs: Dictionary = VISUAL.weather_enqueue(VISUAL.weather_enqueue(VISUAL.make(), 3, 10), 4, 20)
	var tick: Dictionary = VISUAL.weather_tick(vs)
	check("C27-T01", tick.consumed.type == 3 and (tick.state.weather_fifo as Array).size() == 1, "two queued, one tick: one consumed")
	var clear: Dictionary = VISUAL.weather_tick(VISUAL.weather_enqueue(VISUAL.make(), 0, 0))
	check("C27-T02", clear.started_enum == 7 and clear.stopped_all, "type 0 -> clear enum 7 after stopAll")
	check("C27-T02", VISUAL.weather_tick(VISUAL.weather_enqueue(VISUAL.make(), 2, 0)).started_enum == null, "water enum 2 is not selected by this switch")
	var fx: Dictionary = VISUAL.screen_effect_422(VISUAL.screen_effect_422(VISUAL.make(), true, 9), true, 9)
	check("C27-T03", (fx.screen_effect_events as Array).size() == 2 and (VISUAL.screen_effect_422(VISUAL.make(), false, 9).screen_effect_events as Array).is_empty(), "duplicate local-target records are not deduplicated")
	check("C27-T01", VISUAL.light_consumed(5) and not VISUAL.light_consumed(0) and not VISUAL.light_consumed(0x90), "light radius+EC is a signed byte; positive only")
	check("C27-T01", absf(VISUAL.light_step(VISUAL.light_step(0.0, 1.0, 0.5), 1.0, 0.5) - 0.75) < 1e-9, "light step lerps current alpha toward the target each step")

	finish("ORIGINAL_CLIENT_P6_P7_RESULT")
