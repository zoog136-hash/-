extends "res://tests/reference_sp2_load_memo_test.gd"
## Original SP2 bank inputs prepared off the main thread
## (scripts/resources/sp2_background_loader.gd):
## - member/JSON reads, SHA-256, parse and pack run on WorkerThreadPool
##   threads, never the main thread, and touch no Node/SceneTree/frame-hitch
##   log/shared store;
## - the worker parse equals DECODER.parse (FE and Brotli, success and failure)
##   and a background-built bank equals the synchronous one byte for byte;
## - a pending load defers the spawn without blocking, failure backoff or
##   dropping it, and the slot spawns once its inputs are ready;
## - integrity failures (member SHA, JSON SHA, wrong proof) are still rejected,
##   and a prepared result for a changed file is never used;
## - main-thread time per cold spawn and per first effect, before (synchronous
##   path) and after, measured with synthetic banks (no private 523 pack here).
##   godot --headless --path <repo> --script res://tests/sp2_background_load_test.gd
const LOADER = preload("res://scripts/resources/sp2_background_loader.gd")
const PARSE_CACHE = preload("res://scripts/resources/sp2_parse_cache.gd")
const PREPARED = preload("res://scripts/resources/reference_sp2_prepared_bank.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const BUILD = preload("res://tests/sp2_parse_cache_test.gd")
const BROTLI = preload("res://tests/reference_sp2_parsed_payload_test.gd")
const POPULATION = preload("res://scripts/maps/current523_source_population.gd")
const EFFECT = preload("res://scripts/resources/current523_source_effect_selection.gd")

var measured: Dictionary = {}

func _reset() -> void:
	LOADER.reset_for_tests()
	PREPARED.clear()
	BANK._role_memo.clear()
	BANK.forget_verified_members()
	BANK.role_build_budget = -1
	BANK.member_verify_budget = -1
	BANK.background_loading = false
	BANK.background_wait.clear()
	ASSETS.reset_for_tests()

## The load_memo fixture with larger members (realistic parse cost).
func big_fixture(directory: String, frames: int, rows: int) -> Dictionary:
	var data: Dictionary = fixture(directory)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data.path))
	for index: int in range(3):
		var member: String = "Sprite/%d-0.sp2" % (ACTOR + index)
		var raw_path: String = directory.path_join("raw/" + member)
		write_bytes(raw_path, BUILD.build(8, frames, rows, 4))
		manifest.members[member].sha256 = FileAccess.get_sha256(raw_path)
		manifest.members[member].bytes = FileAccess.get_size(raw_path)
	data.sha = write_json(data.path, manifest)
	return data

func shared(bank: RefCounted, data: Dictionary) -> Dictionary:
	return bank.load_shared_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "npc")

## Background attempts with the population's budgets, one per frame, until
## the build is no longer deferred. Main-thread time of each attempt.
func _background_build(data: Dictionary, owners: Array, limit: int = 600) -> Dictionary:
	var result: Dictionary = {}
	var attempts: int = 0
	var total: int = 0
	var worst: int = 0
	var waits: int = 0
	while attempts < limit:
		attempts += 1
		BANK.role_build_budget = POPULATION.ROLE_BUILDS_PER_SPAWN
		BANK.member_verify_budget = POPULATION.MEMBER_VERIFIES_PER_SPAWN
		BANK.background_loading = true
		BANK.background_wait.clear()
		var owner := BANK.new()
		owners.append(owner)
		var started: int = Time.get_ticks_usec()
		result = shared(owner, data)
		var spent: int = Time.get_ticks_usec() - started
		BANK.background_loading = false
		BANK.role_build_budget = -1
		BANK.member_verify_budget = -1
		total += spent
		worst = maxi(worst, spent)
		if result.get("error") != BANK.ROLE_DEFERRED: break
		var wait: Array = BANK.background_wait.duplicate()
		# Like the population: no new attempt while its inputs are pending.
		while LOADER.pending(wait):
			waits += 1
			await process_frame
		await process_frame
	return {"result":result,"attempts":attempts,"total_usec":total,"worst_usec":worst,"wait_frames":waits}

func _sync_build(data: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = shared(BANK.new(), data)
	return {"result":result,"usec":Time.get_ticks_usec() - started}

func _worker_source_clean() -> void:
	# Static guard: the code that runs on worker threads names no main-thread
	# only API. (Runtime: Godot reports Node/SceneTree access off the main
	# thread as an engine error, which fails the CI log scan.)
	var loader: String = FileAccess.get_file_as_string("res://scripts/resources/sp2_background_loader.gd")
	var job: String = loader.substr(loader.find("class Job:"), loader.find("## Polls on every") - loader.find("class Job:"))
	var cache: String = FileAccess.get_file_as_string("res://scripts/resources/sp2_parse_cache.gd")
	var worker_parse: String = cache.substr(cache.find("static func parse_off_main"), cache.find("static func apply_off_main_stats") - cache.find("static func parse_off_main"))
	check(not job.is_empty() and not worker_parse.is_empty(), "worker code sections found")
	for token: String in ["Node", "get_tree", "SceneTree", "RenderingServer", "ImageTexture", "FRAME_HITCH", "ASSETS", "_verified_members"]:
		check(job.find(token) < 0, "worker job names no %s" % token)
	for token: String in ["Node", "get_tree", "RenderingServer", "FRAME_HITCH"]:
		check(worker_parse.find(token) < 0, "worker parse names no %s" % token)
	check(worker_parse.find("_quiet.lock()") >= 0, "worker Brotli decompress holds the error-print lock")

func run() -> void:
	scratch = "user://sp2_background_load_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	PARSE_CACHE.reset_for_test(scratch.path_join("parse_cache"))
	_reset()
	_worker_source_clean()
	var main_thread: int = OS.get_main_thread_id()

	# 1. Worker parse equals DECODER.parse, on a worker thread.
	var inputs: Dictionary = {"fe": make_sp2(0xff), "fe_big": BUILD.build(8, 24, 48, 4), "brotli": Marshalls.base64_to_raw(BROTLI.COMPRESSED["tiny"].base64)}
	var broken: PackedByteArray = inputs.brotli.slice(0, inputs.brotli.size() - 9)
	inputs["brotli_truncated"] = broken
	inputs["fe_bad_marker"] = PackedByteArray([254, 7, 0, 0])
	for name: String in inputs:
		var raw: PackedByteArray = inputs[name]
		var box: Dictionary = {}
		var stats: Dictionary = {}
		var hitch_before: int = HITCH._counters.size()
		var hits_before: Array = [PARSE_CACHE.hits, PARSE_CACHE.misses, PARSE_CACHE.writes]
		var task: int = WorkerThreadPool.add_task(func() -> void:
			box["thread"] = OS.get_thread_caller_id()
			box["parsed"] = PARSE_CACHE.parse_off_main(raw, "", stats))
		WorkerThreadPool.wait_for_task_completion(task)
		check(int(box.thread) != main_thread, "worker parse ran off the main thread: " + name)
		check(HITCH._counters.size() == hitch_before and [PARSE_CACHE.hits, PARSE_CACHE.misses, PARSE_CACHE.writes] == hits_before, "worker parse leaves the hitch log and shared counters alone: " + name)
		var direct: Dictionary = DECODER.parse(raw)
		check(var_to_bytes(box.parsed) == var_to_bytes(direct), "worker parse equals DECODER.parse (%s, ok=%s)" % [name, str(direct.get("ok"))])
		check(Engine.print_error_messages, "error printing restored after: " + name)
		# Second parse: from the device cache, still equal.
		if direct.get("ok", false):
			var again: Dictionary = {}
			var cached_stats: Dictionary = {}
			var t2: int = WorkerThreadPool.add_task(func() -> void: again["parsed"] = PARSE_CACHE.parse_off_main(raw, "", cached_stats))
			WorkerThreadPool.wait_for_task_completion(t2)
			# A cache hit re-adds raw/body last, on the main path too.
			check(int(cached_stats.get("hits", 0)) == 1 and var_to_bytes(again.parsed) == var_to_bytes(PARSE_CACHE.parse(raw)) and bytes_equal(again.parsed.groups, direct.groups) and again.parsed.raw == direct.raw and again.parsed.body == direct.body, "worker cache hit equals the main-thread cache hit and the decoder: " + name)
			PARSE_CACHE.apply_off_main_stats(cached_stats)
	check(not inputs.fe.is_empty() and var_to_bytes(PARSE_CACHE._decode_body(inputs.brotli, DECODER.parse(inputs.brotli).body)) == var_to_bytes(DECODER.parse(inputs.brotli)), "the Brotli body path equals the decoder")

	# 2. Background-built bank equals the synchronous one; loads ran on workers.
	_reset()
	var data: Dictionary = fixture(scratch.path_join("equivalence"))
	LOADER.enabled = false
	var oracle: Dictionary = BANK.new().load_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "npc")
	var whole: Dictionary = shared(BANK.new(), data)
	LOADER.enabled = true
	check(oracle.get("ok", false) and whole.get("ok", false), "synchronous fixture builds")
	_reset()
	var owners: Array = []
	HITCH._counters.clear()
	var background: Dictionary = await _background_build(data, owners)
	check(background.result.get("ok", false), "background build completes: " + str(background.result.get("error", "")))
	check(var_to_bytes(background.result) == var_to_bytes(whole), "background build equals the synchronous shared build")
	check(bytes_equal(background.result, oracle), "background build equals the mutable validation oracle")
	check(background.attempts >= 2, "the first attempt deferred while inputs were prepared (%d attempts)" % background.attempts)
	check(LOADER.requested >= 5 and LOADER.completed == LOADER.requested, "2 action JSONs + 3 members prepared by workers (%d/%d)" % [LOADER.completed, LOADER.requested])
	var threads: Array = LOADER.worker_threads.keys()
	check(not threads.is_empty() and not threads.has(main_thread) and not threads.has(-1), "every prepared input was read on a worker thread: %s (main %d)" % [threads, main_thread])
	check(int(HITCH._counters.get("sp2.bg_used", 0)) >= 5, "the bank used the prepared inputs (%d)" % int(HITCH._counters.get("sp2.bg_used", 0)))
	check(int(HITCH._counters.get("sp2.member_verify_deferred", 0)) == 0, "prepared roles skip the member budget")
	check(int(HITCH._counters.get("sp2.bg_role_used", 0)) == BINDINGS.size() and int(HITCH._counters.get("sp2.bg_role_missed", 0)) == 0, "every role was checked and expanded by a worker role build (%d)" % int(HITCH._counters.get("sp2.bg_role_used", 0)))
	check(int(HITCH._counters.get("sp2.layer_validate", 0)) == 0, "no layer was validated on the main thread")
	var snapshot = BANK.IndexSnapshot.new()
	snapshot.entries = {"actors": {"sprite:1": {"0": {}}, "sprite:2": null}}
	check(snapshot.lookup("actors", "sprite:1") == {"0": {}} and not snapshot.contains("actors", "sprite:2") and not snapshot.missed, "a worker index snapshot answers its prepared keys")
	snapshot.lookup("actors", "sprite:3")
	check(snapshot.missed, "any other lookup marks the worker build for the main thread")
	check(LOADER.idle(), "nothing is left in flight or kept after the build: %s" % [LOADER._ready.keys() + LOADER._inflight.keys()])

	# 3. Prefetch, then a synchronous load (an effect at impact) uses it; a
	# load while the tasks still run waits for them instead of reading again.
	_reset()
	var prefetched: int = BANK.new().prefetch(data.path, data.sha, ACTOR, BINDINGS)
	check(prefetched == 2 and LOADER.busy(), "prefetch starts both action JSONs (%d)" % prefetched)
	var frames: int = 0
	while LOADER.busy() and frames < 600:
		frames += 1
		await process_frame
	check(LOADER.completed == 5, "follow-ups started the members of finished JSONs (%d)" % LOADER.completed)
	HITCH._counters.clear()
	var warm: Dictionary = BANK.new().load_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "npc")
	check(bytes_equal(warm, oracle) and int(HITCH._counters.get("sp2.bg_used", 0)) == 5 and int(HITCH._counters.get("sp2.disk_miss", 0)) + int(HITCH._counters.get("sp2.disk_hit", 0)) == 0, "a load after prefetch equals the oracle and parses nothing on the main thread")
	_reset()
	BANK.new().prefetch(data.path, data.sha, ACTOR, BINDINGS)
	var racing: Dictionary = BANK.new().load_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "npc")
	check(bytes_equal(racing, oracle) and LOADER.waited >= 1, "a load racing its prefetch waits for the running tasks and equals the oracle (%d waits)" % LOADER.waited)
	frames = 0
	while LOADER.busy() and frames < 600:
		frames += 1
		await process_frame

	# 4. A prepared result for a file changed after the read is not used.
	_reset()
	BANK.new().prefetch(data.path, data.sha, ACTOR, BINDINGS)
	frames = 0
	while LOADER.busy() and frames < 600:
		frames += 1
		await process_frame
	for key: String in LOADER._ready:
		LOADER._ready[key].result.stamp[1] = int(LOADER._ready[key].result.stamp[1]) - 7
	HITCH._counters.clear()
	var restamped: Dictionary = BANK.new().load_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "npc")
	check(bytes_equal(restamped, oracle) and int(HITCH._counters.get("sp2.bg_used", 0)) == 0 and int(HITCH._counters.get("sp2.bg_stale", 0)) >= 1, "stale prepared results are dropped and the files verified again")

	# 5. Integrity failures are still rejected in background mode.
	for mutation: String in ["member_sha", "json_sha", "wrong_attributes"]:
		_reset()
		var bad: Dictionary = fixture(scratch.path_join("bad_" + mutation), "wrong_attributes" if mutation == "wrong_attributes" else "")
		var expected: String = ""
		if mutation == "member_sha":
			var raw: PackedByteArray = FileAccess.get_file_as_bytes(bad.raw)
			raw[raw.size() - 1] = (raw[raw.size() - 1] + 1) & 255
			write_bytes(bad.raw, raw)
			expected = "Original SP2 SHA256 mismatch"
		elif mutation == "json_sha":
			var action_path: String = bad.path.get_base_dir().path_join("actors/%d/action-0.json" % ACTOR)
			write_bytes(action_path, FileAccess.get_file_as_bytes(action_path) + PackedByteArray([32]))
			expected = "Bank JSON SHA256 mismatch"
		LOADER.enabled = false
		var sync_rejected: Dictionary = shared(BANK.new(), bad)
		LOADER.enabled = true
		_reset()
		var rejected: Dictionary = await _background_build(bad, owners)
		check(not rejected.result.get("ok", true) and rejected.result.get("error") != BANK.ROLE_DEFERRED, "background build rejects %s" % mutation)
		check(rejected.result.get("error") == sync_rejected.get("error") and (expected.is_empty() or str(rejected.result.get("error")).begins_with(expected)), "same rejection as the synchronous path (%s): %s" % [mutation, str(rejected.result.get("error"))])

	# 6. Population: a pending load defers the spawn (no block, no backoff, no
	# drop); the slot is not set up again until its inputs are ready.
	_reset()
	var population := FakePopulation.new()
	var world := FakeWorld.new()
	population.world = world
	population.data = data
	population.owners = owners
	population._fill_remaining = POPULATION.FILL_SECONDS
	population._spawn_tokens = POPULATION.STEADY_SPAWN_BURST
	var key: String = "lineagem_base508:npc:1:spawn:2:territory:3"
	population.records[key] = {"source_m_current523_final": true}
	var slot: Dictionary = {"region": {"monster_types": [key]}, "slot_id": 0, "monster": null, "remaining": 0.0}
	population.field = PlayableField.new()
	await process_frame
	var first_started: int = Time.get_ticks_usec()
	population._spawn_slot(slot)
	var first_usec: int = Time.get_ticks_usec() - first_started
	check(population.attempts == 1 and not population.spawned, "the first attempt defers")
	check(slot.get("background_wait", []).size() >= 1 and slot.get("retry_queued") == true and slot.has("budget_deferred") and not slot.has("patch523_spawn_hold"), "the deferred slot waits for its tasks, queued, without a hold")
	check(int(slot.get("spawn_failures", 0)) == 0, "a background deferral is not a spawn failure")
	var setups_while_pending: int = 0
	frames = 0
	while not population.spawned and frames < 600:
		frames += 1
		var pending_before: bool = slot.has("background_wait") and LOADER.pending(slot.background_wait)
		var attempts_before: int = population.attempts
		population._drain_retry()
		if pending_before and population.attempts > attempts_before: setups_while_pending += 1
		await process_frame
	check(population.spawned and population.result.get("ok", false), "the slot spawns once its inputs are ready (%d frames, %d attempts)" % [frames, population.attempts])
	check(setups_while_pending == 0, "no setup ran while its inputs were pending")
	check(var_to_bytes(population.result) == var_to_bytes(whole), "the spawned bank equals the synchronous build")
	check(int(slot.get("spawn_failures", 0)) == 0 and not slot.has("patch523_spawn_hold"), "no failure or hold recorded")
	check(not BANK.background_loading and BANK.role_build_budget == -1 and BANK.member_verify_budget == -1, "population restores the bank's defaults")
	# After the first fill: a deferral that only started worker tasks does not
	# use up a build token (field_population._take_build_token caps builds).
	_reset()
	population.data = fixture(scratch.path_join("token_cold"))
	population.spawned = false
	population._fill_remaining = 0.0
	population._spawn_tokens = 5.0
	population._build_tokens = 1.0
	population._build_clock_usec = -1
	var token_slot: Dictionary = {"region": {"monster_types": [key]}, "slot_id": 1, "monster": null, "remaining": 0.0}
	await process_frame
	population._spawn_slot(token_slot)
	check(token_slot.has("background_wait") and not population.spawned and population._build_tokens >= 0.99, "a background deferral gives its build token back (%.2f)" % population._build_tokens)
	frames = 0
	while LOADER.busy() and frames < 600:
		frames += 1
		await process_frame
	population.field = null
	population._retry.clear()
	population.free()
	world.monsters_root.free()
	world.free()

	# 6b. Budgeted map objects: a cold sprite waits (not cached as a result)
	# and then equals the synchronous load.
	_reset()
	var objects_script: GDScript = load("res://scripts/maps/current523_bank_objects.gd")
	var sync_objects: Node2D = objects_script.new()
	sync_objects.manifest_path = data.path
	sync_objects.manifest_sha256 = data.sha
	var sync_sprite: Dictionary = sync_objects._sprite(ACTOR)
	_reset()
	var objects: Node2D = objects_script.new()
	objects.manifest_path = data.path
	objects.manifest_sha256 = data.sha
	objects.sprite_load_budget_usec = objects.FRAME_SPRITE_LOAD_BUDGET_USEC
	var first_sprite: Dictionary = objects._sprite(ACTOR)
	check(first_sprite.get("background_pending", false) and not objects._sprites.has(ACTOR) and LOADER.busy(), "a cold map object sprite waits for its worker tasks and is not cached")
	var object_sprite: Dictionary = first_sprite
	frames = 0
	while object_sprite.get("background_pending", false) and frames < 600:
		frames += 1
		await process_frame
		if not LOADER.busy(): object_sprite = objects._sprite(ACTOR)
	check(sync_sprite.get("ok", false) and bytes_equal(object_sprite, sync_sprite) and objects._sprites.has(ACTOR), "the map object sprite then equals the synchronous load")
	check(not BANK.background_loading, "map objects restore the bank default")
	sync_objects.free()
	objects.free()

	# 7. Effect manifest prewarm: adopted from the worker with the same result.
	_reset()
	var effect_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data.path))
	effect_manifest["source_action_domains"] = {}
	var effect_path: String = scratch.path_join("effect/manifest.json")
	var effect_sha: String = write_json(effect_path, effect_manifest)
	EFFECT._manifest = {}
	EFFECT._manifest_path = ""
	var sync_effect: Dictionary = EFFECT._bank({"manifest_path":effect_path,"manifest_sha256":effect_sha})
	EFFECT._manifest = {}
	EFFECT._manifest_path = ""
	LOADER.request_json(effect_path, effect_sha, BANK.MAX_MANIFEST_JSON, Callable(EFFECT, "_prewarmed").bind(effect_path, effect_sha))
	frames = 0
	while LOADER.busy() and frames < 600:
		frames += 1
		await process_frame
	check(EFFECT._manifest_path == effect_path and not EFFECT._manifest.is_empty() and LOADER.idle(), "a finished prewarm is adopted on the main thread")
	var prewarmed_effect: Dictionary = EFFECT._bank({"manifest_path":effect_path,"manifest_sha256":effect_sha})
	check(sync_effect.get("ok", false) and var_to_bytes(prewarmed_effect) == var_to_bytes(sync_effect), "the prewarmed manifest equals the synchronous load")
	EFFECT._manifest = {}
	EFFECT._manifest_path = ""
	LOADER.request_json(effect_path, effect_sha, BANK.MAX_MANIFEST_JSON, Callable(EFFECT, "_prewarmed").bind(effect_path, effect_sha))
	var raced_effect: Dictionary = EFFECT._bank({"manifest_path":effect_path,"manifest_sha256":effect_sha})
	check(var_to_bytes(raced_effect) == var_to_bytes(sync_effect) and LOADER.idle(), "an effect requested during the prewarm waits for it and gets the same manifest")
	var tampered: Dictionary = effect_manifest.duplicate(true)
	tampered["schema"] = 2
	write_json(effect_path, tampered)
	EFFECT._manifest = {}
	EFFECT._manifest_path = ""
	LOADER.request_json(effect_path, effect_sha, BANK.MAX_MANIFEST_JSON, Callable(EFFECT, "_prewarmed").bind(effect_path, effect_sha))
	var pin_changed: Dictionary = EFFECT._bank({"manifest_path":effect_path,"manifest_sha256":effect_sha})
	check(not pin_changed.get("ok", true) and pin_changed.get("reason") == "current523_effect_bank_pin_changed" and EFFECT._manifest.is_empty(), "a prewarmed manifest whose pin changed is rejected")
	EFFECT._manifest = {}
	EFFECT._manifest_path = ""

	# 8. Measurements: main-thread time per cold spawn (shared NPC bank) and
	# per first effect load, synchronous (before) vs background (after).
	for cache_state: String in ["parse_cache_hit", "parse_cache_miss", "parse_cache_disabled"]:
		var big: Dictionary = big_fixture(scratch.path_join("big_" + cache_state), 40, 120)
		var hit: bool = cache_state == "parse_cache_hit"
		PARSE_CACHE.reset_for_test(scratch.path_join("cache_" + cache_state))
		PARSE_CACHE.enabled = cache_state != "parse_cache_disabled"
		_reset()
		if hit:
			# Device parse cache already holds these members (a later session).
			LOADER.enabled = false
			_sync_build(big)
			_reset()
		LOADER.enabled = false
		var before: Dictionary = _sync_build(big)
		# The population's previous synchronous spread (1 role and 2 member
		# parses per attempt) on the main thread.
		if not hit: PARSE_CACHE.reset_for_test(scratch.path_join("cache1_" + cache_state))
		PARSE_CACHE.enabled = cache_state != "parse_cache_disabled"
		_reset()
		LOADER.enabled = false
		var spread: Dictionary = await _background_build(big, owners)
		LOADER.enabled = true
		if not hit: PARSE_CACHE.reset_for_test(scratch.path_join("cache2_" + cache_state))
		PARSE_CACHE.enabled = cache_state != "parse_cache_disabled"
		_reset()
		var after: Dictionary = await _background_build(big, owners)
		check(before.result.get("ok", false) and after.result.get("ok", false) and var_to_bytes(before.result) == var_to_bytes(after.result), "big fixture: background equals synchronous (%s)" % cache_state)
		check(after.worst_usec < before.usec, "big fixture: the longest background attempt is shorter than the synchronous build (%s: %d < %d us)" % [cache_state, after.worst_usec, before.usec])
		check(after.worst_usec < spread.worst_usec, "big fixture: the longest background attempt is shorter than the previous budgeted attempt (%s: %d < %d us)" % [cache_state, after.worst_usec, spread.worst_usec])
		measured["spawn_" + cache_state] = {"sync_one_frame_usec":before.usec,"previous_budgeted_worst_attempt_usec":spread.worst_usec,"previous_budgeted_main_total_usec":spread.total_usec,"previous_budgeted_attempts":spread.attempts,"background_worst_attempt_usec":after.worst_usec,"background_main_total_usec":after.total_usec,"background_attempts":after.attempts,"wait_frames":after.wait_frames}
		# First effect: a synchronous load_bank (overlay path) cold vs prefetched.
		if not hit: PARSE_CACHE.reset_for_test(scratch.path_join("cache3_" + cache_state))
		PARSE_CACHE.enabled = cache_state != "parse_cache_disabled"
		_reset()
		LOADER.enabled = false
		var effect_started: int = Time.get_ticks_usec()
		var cold_effect: Dictionary = BANK.new().load_bank(big.path, big.sha, ACTOR, {"idle":0}, {"idle":false}, "")
		var cold_usec: int = Time.get_ticks_usec() - effect_started
		LOADER.enabled = true
		if not hit: PARSE_CACHE.reset_for_test(scratch.path_join("cache4_" + cache_state))
		PARSE_CACHE.enabled = cache_state != "parse_cache_disabled"
		_reset()
		BANK.new().prefetch(big.path, big.sha, ACTOR, {"idle":0})
		frames = 0
		while LOADER.busy() and frames < 600:
			frames += 1
			await process_frame
		effect_started = Time.get_ticks_usec()
		var warm_effect: Dictionary = BANK.new().load_bank(big.path, big.sha, ACTOR, {"idle":0}, {"idle":false}, "")
		var warm_usec: int = Time.get_ticks_usec() - effect_started
		check(cold_effect.get("ok", false) and bytes_equal(cold_effect, warm_effect), "first effect: prefetched load equals the cold load (%s)" % cache_state)
		check(warm_usec < cold_usec, "first effect: prefetched load is faster on the main thread (%s: %d < %d us)" % [cache_state, warm_usec, cold_usec])
		measured["effect_" + cache_state] = {"cold_sync_usec":cold_usec,"prefetched_usec":warm_usec}
	PARSE_CACHE.enabled = true
	_reset()
	owners.clear()
	print("SP2_BACKGROUND_LOAD_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "synthetic_only": true, "measured": measured}))
	quit(0 if failures.is_empty() else 1)

class FakeWorld extends Node:
	var monsters_root: Node = Node.new()

## The real Current523SourcePopulation pacing/retry code with the monster
## setup replaced by its bank step: a ROLE_DEFERRED view load becomes the
## "current523_view_deferred" hold exactly as monster.setup() returns it.
class FakePopulation extends "res://scripts/maps/current523_source_population.gd":
	var data: Dictionary = {}
	var owners: Array = []
	var attempts: int = 0
	var spawned: bool = false
	var result: Dictionary = {}
	func _zone_active(_region: Dictionary) -> bool: return true
	func _spawn_slot_measured(slot: Dictionary) -> void:
		attempts += 1
		var bank: RefCounted = load("res://scripts/resources/reference_sp2_bank.gd").new()
		owners.append(bank)
		result = bank.load_shared_bank(data.path, data.sha, 9001, {"idle": 0, "attack": 3}, {"idle": true, "attack": false}, "npc")
		if result.get("error") == bank.ROLE_DEFERRED:
			slot.patch523_spawn_hold = "current523_view_deferred"
			return
		spawned = result.get("ok", false)
		slot.remaining = 0.0
