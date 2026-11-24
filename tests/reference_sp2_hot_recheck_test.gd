extends "res://tests/actor_frame_composite_cache_test.gd"
## Synthetic inputs, real ReferenceBank and preview advancement. In regular
## CI the same integrity cases run without noisy machine-speed assertions.
const LOAD_FIXTURE = preload("res://tests/reference_sp2_load_memo_test.gd")
const EXCLUSION_FIXTURE = preload("res://tests/reference_sp2_shared_exclusions_test.gd")

func _initialize() -> void: call_deferred("run_hot")

func run_hot() -> void:
	directory = "user://sp2_warm_recheck_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var helper := LOAD_FIXTURE.new()
	var info: Dictionary = helper.fixture(directory.path_join("pinned"))
	var bank := CountingBank.new()
	check(helper.open(bank, info).ok, "actual multi-role action pins loaded")
	var body := base_layer(9001, "body")
	var stamps: Dictionary = bank.member_stamps([body])
	check(stamps.ok and bank.recheck_layers(stamps).ok and bank.recheck_layers(stamps).ok, "warm and repeated checks accept exact current bytes")
	# Same action path in a warmed bank; the expiry must reject corruption.
	var action: String = info.path.get_base_dir().path_join("actors/9001/action-3.json")
	var original: PackedByteArray = FileAccess.get_file_as_bytes(action)
	write_bytes(action, original + PackedByteArray([0]))
	BANK.expire_recheck_memo()
	check(bank.recheck_layers(stamps).get("error") == "Pinned source bank metadata changed.", "expired memo still verifies individual action JSON")
	write_bytes(action, original)
	check(bank.recheck_layers(stamps).ok, "failed pin checks are not cached")
	# Refreshing the exact same bank with a different source must replace its
	# memo identity, even while a success for the last source is still cached.
	var other: Dictionary = helper.fixture(directory.path_join("second"))
	check(bank.load_shared_bank(other.path, other.sha, LOAD_FIXTURE.ACTOR, LOAD_FIXTURE.BINDINGS, LOAD_FIXTURE.LOOPS, "test").ok, "other pinned source prepared")
	check(helper.open(bank, info).ok and bank.recheck_layers(stamps).ok, "restored first bank warm")
	check(bank.load_shared_bank(other.path, other.sha, LOAD_FIXTURE.ACTOR, LOAD_FIXTURE.BINDINGS, LOAD_FIXTURE.LOOPS, "test").ok, "other source read through prepared snapshot")
	var other_action: String = other.path.get_base_dir().path_join("actors/9001/action-3.json")
	write_bytes(other_action, FileAccess.get_file_as_bytes(other_action) + PackedByteArray([0]))
	check(bank.recheck_layers(bank.member_stamps([body])).get("error") == "Pinned source bank metadata changed.", "prepared reload does not reuse a previous source's success")

	# A raw member independently rejected by the per-layer lane must not
	# recover an old hit from the warm memo after its verification is erased.
	check(helper.open(bank, info).ok and bank.recheck_layers(stamps).ok, "first bank can warm independently of second source failure")
	check(DirAccess.remove_absolute(info.raw) == OK and not bank.render_layer(body, false).ok, "per-layer path rejects deleted member")
	check(not bank.recheck_layers(stamps).ok, "cached lane rejects deleted member after verified stamp disappears")
	var excl := EXCLUSION_FIXTURE.new()
	var exclusion_data: Dictionary = excl.with_exclusions(helper.fixture(directory.path_join("excluded")), [9100])
	check(helper.open(bank, exclusion_data).ok and bank.recheck_layers(bank.member_stamps([body])).ok, "normal actor warmed with a real exclusion registry")
	var denied := body.duplicate()
	denied.source_sprite_id = 9100
	var verdict: Dictionary = bank.recheck_layers(bank.member_stamps([denied]))
	check(not verdict.ok and verdict.get("excluded_source_actor_id") == 9100 and verdict.has("source_exclusion"), "same raw path's success cannot admit a different excluded actor")
	excl.free()
	helper.free()
	var results: Dictionary = {}
	if "--bench" in OS.get_cmdline_user_args(): results = benchmark_hot()
	print("REFERENCE_SP2_HOT_RECHECK_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"bench":results,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)

func benchmark_hot() -> Dictionary:
	var info: Dictionary = write_bank(directory.path_join("bench"))
	var bank: CountingBank = open_bank(info)
	# Five actually pinned metadata files, as in a multi-action actor.
	for id: int in range(5):
		var file: String = directory.path_join("bench/action-%d.json" % id)
		write_bytes(file, ("{\"action\":%d}" % id).to_utf8_buffer())
		bank._actor_pins[file] = FileAccess.get_sha256(file)
	var track: Dictionary = make_track(bank, {"effect_attrs":["8"]})
	var view: Node2D = make_view(root, bank, track, info.path, false)
	view.use_companion_frame_plans()
	for dir: int in range(4):
		for _frame: int in range(3): view.advance_reference_source(0.1,"idle",dir)
	var stamps: Dictionary = bank.member_stamps(track.directions[0][0].layers + track.directions[0][0].effect_layers)
	check(bank.recheck_layers(stamps).ok, "multi-action warm raw benchmark admitted")
	var rounds: Array = []
	const RECHECKS := 14000
	const ADVANCES := 8000
	for _round: int in range(5):
		var passed: bool = true
		var t := Time.get_ticks_usec()
		for i: int in range(RECHECKS): passed = passed and bank.recheck_layers(stamps).ok
		var proof: float = float(Time.get_ticks_usec() - t) / RECHECKS
		t = Time.get_ticks_usec()
		for i: int in range(ADVANCES): passed = passed and view.advance_reference_source(1.0/30.0,"idle", (i / 45) % 4)
		var advance: float = float(Time.get_ticks_usec() - t) / ADVANCES
		check(passed and view.cached_frame_status().plans == 12, "warm mixed-direction preview maintains every original pose")
		rounds.append({"recheck_us":proof,"preview_us":advance})
	view.free()
	return {"rounds":rounds}
