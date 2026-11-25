extends SceneTree
## Opt-in first-NPC-pose preparation. Synthetic TWCA only; no source art.
const STORE = preload("res://scripts/resources/cooked_actor_store.gd")
const FORMAT = preload("res://scripts/resources/cooked_actor_format.gd")
const VIEW = preload("res://scripts/monsters/current523_source_bank_view.gd")
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const SP2 = preload("res://scripts/resources/sp2_background_loader.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var directory: String

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("COOKED_PAGE_PREPARE_FAIL: ", label)

func _initialize() -> void: run.call_deferred()
func next_frame() -> void:
	var before: int = Engine.get_process_frames()
	while before == Engine.get_process_frames(): await process_frame

func selected(sprite: int, consumer: String = "npc") -> Dictionary:
	return {"ok":true,"consumer":consumer,"sprite_id":sprite,"manifest_path":directory.path_join("bank.json"),"manifest_sha256":"a".repeat(64),"role_actions":{"idle":3},"loop_policy":{"idle":false},"host_policy":"fixture"}

func fixture(sprite: int, pages: int = 2, size: int = 64, consumer: String = "npc") -> Dictionary:
	var inputs: Dictionary = STORE.selection_inputs(selected(sprite, consumer))
	var path: String = directory.path_join(FORMAT.FORMAT_TAG).path_join(STORE.file_for(inputs))
	var images: Array = []
	var table := PackedInt32Array()
	var first := PackedInt32Array()
	var next := PackedInt32Array()
	for page: int in pages:
		var image := Image.create_empty(size,size,false,Image.FORMAT_RGBA8)
		image.fill(Color(0.2 + page * 0.1,0.3,0.7,0.5 if page % 2 else 1.0))
		images.append(image)
		table.append_array(PackedInt32Array([page,0,0,size,size]))
		# Original order, positions, z and transparency must be identical.
		first.append_array(PackedInt32Array([page,page * 3,0,0,page,-1,0,0]))
		next.append_array(PackedInt32Array([page,page * 7,3,0,page,-1,0,0]))
	var direction: Dictionary = {"durations":PackedFloat64Array([0.01,0.02]),"source_frames":PackedInt32Array([0,1]),"source_groups":PackedInt32Array([0,1]),"seg_start":PackedInt32Array([0,1,2]),"seg_end":PackedFloat64Array([0.01,0.02]),"seg_state":PackedInt32Array([0,1]),"end_state":1}
	var directions: Array = []
	for _i: int in 8: directions.append(direction.duplicate(true))
	var entry: Dictionary = {"inputs":inputs,"tracks":{"idle":{"loop":false,"static_pending_timing":false,"directions":directions}}}
	var index: Dictionary = {"images":table,"states":[first,next],"entries":[entry],"colors":PackedFloat32Array([1,1,1,1])}
	check(FORMAT.write(path,index,images).ok,"fixture writes")
	var found: Dictionary = STORE.lookup_inputs(inputs)
	check(not found.is_empty(),"fixture is accepted through the real lookup/selection checks")
	return found

func drain(found: Dictionary, state: int = 0) -> Dictionary:
	var out: Dictionary = {}
	for _frame: int in 180:
		out = STORE.prepare_state(found.actor,state)
		if out.status == "ready": return out
		await next_frame()
	check(false,"normal preparation completes within 180 frames")
	return out

func layout(sprites: Array[Sprite2D]) -> Array:
	var rows: Array = []
	for sprite: Sprite2D in sprites:
		rows.append([sprite.texture.get_image().get_data(),sprite.position,sprite.region_rect,sprite.z_index,sprite.modulate,sprite.visible])
	return rows

func first_pose() -> void:
	STORE.reset_for_tests()
	var found: Dictionary = fixture(1,3)
	STORE.npc_page_prewarm = false
	check(VIEW.prepare_first_cooked_pose(selected(1)).status == "unsupported" and STORE.prepared_page_stats().jobs == 0,"default does not change first paint or start workers")
	STORE.npc_page_prewarm = true
	var started: int = Time.get_ticks_usec()
	var first: Dictionary = VIEW.prepare_first_cooked_pose(selected(1))
	evidence["first_request_usec"] = Time.get_ticks_usec()-started
	check(first.status == "pending" and STORE.prepared_page_stats().jobs == 3,"cold first pose defers before admission")
	var submitted: int = int(STORE.stats().counters.get("page_prepare_submitted",0))
	for _i: int in 12: VIEW.prepare_first_cooked_pose(selected(1))
	check(int(STORE.stats().counters.get("page_prepare_submitted",0)) == submitted,"repeated requests share each page job")
	var ready: Dictionary = await drain(found)
	check(ready.status == "ready" and ready.textures.size() == 3 and STORE.prepared_page_stats().jobs == 0,"all layers are ready before the pose is admitted")
	var owner := Node2D.new()
	var sprites: Array[Sprite2D] = []
	var sync_owner := Node2D.new()
	var sync_sprites: Array[Sprite2D] = []
	check(STORE.apply_state(owner,sprites,found.actor,0),"first ready pose applies completely")
	var sync: Dictionary = STORE.load_actor(found.actor.path)
	STORE.apply_state(sync_owner,sync_sprites,sync.actor,0)
	check(layout(sprites) == layout(sync_sprites),"first pixels/alpha/regions/positions/draw order match the synchronous pose")
	owner.free(); sync_owner.free()

func frame_cap_and_eviction() -> void:
	STORE.reset_for_tests()
	var found: Dictionary = fixture(2,3)
	STORE.budget_bytes = 1
	STORE.prepare_state(found.actor,0)
	# Wait for CPU completion without pumping any GPU upload.
	for _frame: int in 180:
		var done: bool = true
		for job: Dictionary in STORE._page_jobs.values(): done = done and WorkerThreadPool.is_task_completed(int(job.task))
		if done: break
		await next_frame()
	await next_frame()
	var before: int = int(STORE.stats().counters.get("page_prepared_upload",0))
	for _i: int in 20: STORE.pump_prepared_pages()
	check(int(STORE.stats().counters.get("page_prepared_upload",0))-before == 1,"twenty pumps share one actual engine-frame upload allowance")
	var ready: Dictionary = await drain(found)
	check(ready.status == "ready" and ready.textures.size() == 3,"whole-pose reservations prevent starvation under cache eviction")
	var owner := Node2D.new()
	var sprites: Array[Sprite2D] = []
	var loads: int = int(STORE.stats().counters.get("page_loaded",0))
	check(STORE.apply_state(owner,sprites,found.actor,0) and sprites.size() == 3,"tiny reserve still admits a complete first pose")
	check(int(STORE.stats().counters.get("page_loaded",0)) == loads,"first draw reuses retained weak pages without a synchronous reread")
	var texture: Texture2D = sprites[0].texture
	ready.clear()
	check(STORE.page_texture(found.actor,0) == texture,"on-screen texture survives prewarm result release and reserve eviction")
	owner.free()

func failure_and_bounds() -> void:
	STORE.reset_for_tests()
	var found: Dictionary = fixture(3)
	var path: String = found.actor.path
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	DirAccess.remove_absolute(path)
	STORE.prepare_state(found.actor,0)
	var result: Dictionary = {}
	for _frame: int in 180:
		result = STORE.prepare_state(found.actor,0)
		if result.has("error"): break
		await next_frame()
	check(result.get("error") == "cooked_actor_page" and not found.actor.page_retry_after.is_empty(),"failed read keeps the existing page retry contract and does not paint")
	var submitted: int = int(STORE.stats().counters.get("page_prepare_submitted",0))
	for _i: int in 10: STORE.prepare_state(found.actor,0)
	check(int(STORE.stats().counters.get("page_prepare_submitted",0)) == submitted,"failed read does not spin before its retry deadline")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(bytes); file.close()
	await create_timer(0.26).timeout
	check((await drain(found)).status == "ready","repaired same file recovers through normal verified page decoding")
	STORE.reset_for_tests()
	var big: Dictionary = fixture(4,5,1024)
	check(STORE.prepare_state(big.actor,0).status == "unsupported" and STORE.prepared_page_stats().jobs == 0,"whole-pose unpacked reservation above the cap retains the synchronous path")
	var one: Dictionary = fixture(5,1)
	one.actor.index.pages[0].bytes = STORE.PREPARE_PACKED_BYTES + 1
	check(STORE.prepare_state(one.actor,0).status == "unsupported" and STORE.prepared_page_stats().packed_bytes == 0,"compressed input is bounded independently of unpacked image bytes")
	var eight: Dictionary = fixture(6,8)
	STORE.prepare_state(eight.actor,0)
	var another: Dictionary = fixture(7,2)
	check(STORE.prepare_state(another.actor,0).status == "pending" and STORE.prepared_page_stats().jobs == 8,"capacity pressure admits no partial extra pose")
	check((await drain(eight)).status == "ready" and (await drain(another)).status == "ready","queued poses both complete after capacity becomes free")
	check(STORE.prepared_page_stats().raw_bytes == 0 and STORE.prepared_page_stats().packed_bytes == 0,"finished pose releases all queue reservations")

static func delayed_read(input: Array, result: Array, gate: Semaphore) -> void:
	gate.wait()
	STORE._read_prepared_page(input,result)

func hold_worker(job: Dictionary) -> Semaphore:
	WorkerThreadPool.wait_for_task_completion(int(job.task))
	job.result[0] = null
	var gate := Semaphore.new()
	job.task = WorkerThreadPool.add_task(delayed_read.bind(job.input,job.result,gate))
	return gate

func wait_for_cpu(job: Dictionary) -> bool:
	for _frame: int in 180:
		if WorkerThreadPool.is_task_completed(int(job.task)): return true
		await next_frame()
	return false

func concurrent_demand() -> void:
	for source: String in ["decoded", "published", "blocked"]:
		STORE.reset_for_tests()
		var found: Dictionary = fixture(21,1)
		STORE.prepare_state(found.actor,0)
		var job: Dictionary = STORE._page_jobs.values()[0]
		var gate: Semaphore
		if source == "blocked":
			gate = hold_worker(job)
		else:
			check(await wait_for_cpu(job),"CPU preparation completes before the pose requests the page")
		if source == "published": STORE.pump_prepared_pages()
		var expected: Texture2D = job.get("texture")
		var demand: Texture2D = STORE.page_texture(found.actor,0)
		var disk: Image = FORMAT.read_page(FileAccess.open(found.actor.path,FileAccess.READ),found.actor.index.pages[0],found.actor.data_start)
		var counters: Dictionary = STORE.stats().counters
		check(demand != null and job.get("texture") == demand,"the visible pose and admission job hold a single texture: " + source)
		check(demand != null and disk != null and demand.get_image().get_data() == disk.get_data(),"overlap preserves the verified page pixels: " + source)
		check(counters.get("page_demand_read",0) == (1 if source == "blocked" else 0),"only unfinished preparation needs the original immediate read: " + source)
		if source == "decoded": check(counters.get("page_demand_reuse_image",0) == 1,"CPU-ready image is uploaded without reading the file again")
		if source == "published": check(demand == expected and counters.get("page_demand_reuse_texture",0) == 1,"a published texture needs no second upload")
		if source == "blocked":
			check(not WorkerThreadPool.is_task_completed(int(job.task)),"the draw never joins the blocked worker")
			var admitted: Dictionary = STORE.prepare_state(found.actor,0)
			check(admitted.status == "ready" and admitted.textures[0] == demand,"admission can use the visible texture before the redundant worker returns")
			check(STORE.prepare_state(found.actor,0).status == "ready","another fully warm admission ignores the retiring worker")
			gate.post()
			check(await wait_for_cpu(job),"blocked worker finishes after demand has drawn")
			STORE.pump_prepared_pages()
			check(STORE.prepared_page_stats().jobs == 0,"the redundant CPU result is retired after the demand upload")
		var ready: Dictionary = await drain(found)
		check(ready.status == "ready" and ready.textures[0] == demand,"admitted pose reuses the exact same texture: " + source)
		check(STORE.stats().counters.get("page_prepared_upload",0) == (1 if source == "published" else 0),"only one GPU upload takes place: " + source)
		check(STORE.prepared_page_stats().jobs == 0 and STORE.prepared_page_stats().raw_bytes == 0,"overlap releases all preparation reservations")
		if source == "published":
			STORE._install_page_texture(found.actor,0,demand,disk.get_data_size())
			check(found.actor.textures[0] == demand and STORE.stats().bytes == disk.get_data_size(),"replacing the same reserved page leaves one resident reference")

func cancellation() -> void:
	STORE.reset_for_tests()
	var found: Dictionary = fixture(8,1)
	STORE.prepare_state(found.actor,0)
	var job: Dictionary = STORE._page_jobs.values()[0]
	# Substitute a delayed private read only after the original test task has
	# finished; no production delay hook or shared actor ever enters a worker.
	var gate: Semaphore = hold_worker(job)
	var before: int = int(STORE.stats().counters.get("page_prepared_upload",0))
	var started: int = Time.get_ticks_usec()
	var pending: Dictionary = STORE.prepare_state(found.actor,0)
	evidence["delayed_request_usec"] = Time.get_ticks_usec()-started
	check(pending.status == "pending" and not WorkerThreadPool.is_task_completed(int(job.task)),"a blocked private read returns pending without waiting or publishing")
	started = Time.get_ticks_usec()
	STORE.cancel_prepared_pages()
	evidence["cancel_inflight_usec"] = Time.get_ticks_usec()-started
	check(STORE.prepared_page_stats().jobs == 1 and STORE.prepared_page_stats().raw_bytes > 0,"cancel does not join a worker or free its reservation early")
	gate.post()
	for _frame: int in 180:
		STORE.pump_prepared_pages()
		if STORE.prepared_page_stats().jobs == 0: break
		await next_frame()
	check(STORE.prepared_page_stats().jobs == 0 and int(STORE.stats().counters.get("page_prepared_upload",0)) == before,"cancelled result is discarded without texture creation")
	STORE.prepare_state(found.actor,0)
	STORE.root_override = directory.path_join("other")
	DirAccess.make_dir_recursive_absolute(STORE.root_override.path_join(FORMAT.FORMAT_TAG))
	STORE._root_known = false
	check(STORE.prepare_state(found.actor,0).status == "unsupported","pack-root change cannot publish an earlier pack into a new request")
	STORE.finish_prepared_pages()
	check(STORE.prepared_page_stats().jobs == 0 and STORE.prepared_page_stats().raw_bytes == 0,"explicit teardown drains private jobs and all reservations")
	STORE.root_override = directory
	STORE._root_known = false
	STORE.prepare_state(found.actor,0)
	for group: Dictionary in STORE._page_groups.values(): group.touched = Time.get_ticks_msec() - STORE.PREPARE_IDLE_MSEC - 1
	for _frame: int in 180:
		STORE.pump_prepared_pages()
		if STORE.prepared_page_stats().jobs == 0: break
		await next_frame()
	check(STORE.prepared_page_stats().jobs == 0,"abandoned spawn reservations expire without an actor reference")

class FakeWorld extends Node:
	var monsters_root := Node.new()

## Exercise production population deferral/retry; only replace the expensive
## source selection/stat fixture with the same cooked first-pose admission.
class SpawnProbe extends "res://scripts/maps/current523_source_population.gd":
	var selection: Dictionary
	var preview: Node2D
	var admitted: bool = false
	func _zone_active(_region: Dictionary) -> bool: return true
	func _spawn_slot_measured(slot: Dictionary) -> void:
		var view = load("res://scripts/monsters/current523_source_bank_view.gd")
		var prepared: Dictionary = view.prepare_first_cooked_pose(selection)
		if prepared.status == "pending":
			slot.patch523_spawn_hold = "current523_view_deferred"
			return
		var store = load("res://scripts/resources/cooked_actor_store.gd")
		preview = load("res://scripts/animation/original_source_preview.gd").new()
		preview._configure_cooked(store.lookup(selection),selection.manifest_path,"idle","npc",int(selection.sprite_id))
		preview.advance_reference_source(0.0,"idle",5)
		admitted = preview._cooked_state >= 0 and not preview._cooked_sprites.is_empty()

func spawn_gate() -> void:
	STORE.reset_for_tests()
	fixture(9,3)
	var population := SpawnProbe.new()
	var world := FakeWorld.new()
	population.world = world
	population.selection = selected(9)
	population.field = PlayableField.new()
	population._fill_remaining = population.FILL_SECONDS
	population.records["npc"] = {"source_m_current523_final":true}
	var slot: Dictionary = {"region":{"monster_types":["npc"]},"monster":null,"remaining":0.0}
	population._spawn_slot(slot)
	check(not population.admitted and population.preview == null and slot.monster == null,"pending first paint creates no targetable actor/preview")
	check(slot.get("budget_deferred",false) and population._retry.size() == 1 and not slot.has("patch523_spawn_hold"),"production population converts the deferred slot to a retry without a permanent hold")
	for _frame: int in 180:
		if population.admitted: break
		await next_frame()
		population._drain_retry()
	check(population.admitted and population.preview._cooked_sprites.size() == 3 and population.preview._clock == 0.0,"retry admits the entire original first pose with an unadvanced clock")
	if population.preview != null: population.preview.free()
	population.free(); world.monsters_root.free(); world.free()

func sharing_and_live_index() -> void:
	STORE.reset_for_tests()
	var found: Dictionary = fixture(11,3)
	# Two different poses share pages: releasing one cannot cancel the other.
	found.actor.index.states[1] = found.actor.index.states[0].slice(0,FORMAT.ITEM_STRIDE)
	STORE.prepare_state(found.actor,0)
	STORE.prepare_state(found.actor,1)
	check(STORE.prepared_page_stats().jobs == 3 and STORE.prepared_page_stats().groups == 2,"two pose tickets deduplicate shared pages")
	var one: Dictionary = await drain(found,1)
	var all: Dictionary = await drain(found,0)
	check(one.status == "ready" and all.status == "ready" and one.textures[0] == all.textures[0],"releasing one ticket preserves the shared immutable texture for the other")
	var texture: Texture2D = all.textures[0]
	for i: int in STORE.INDEX_CACHE_MAX: STORE._cache["fake%d" % i] = STORE.CookedActor.new()
	STORE._trim()
	var revisit: Dictionary = STORE.lookup(selected(11))
	check(revisit.actor == found.actor and STORE.page_texture(revisit.actor,0) == texture,"index eviction still uses #848's live bundle and texture reuse")
	# The first source frame may have zero duration: preflight selects exactly
	# what the real preview chooses at t=0, not necessarily state zero.
	var track: Dictionary = found.entry.runtime_tracks.idle
	for frames: Array in track.directions: frames[0].duration = 0.0
	var preview := PREVIEW.new()
	preview._configure_cooked(found,selected(11).manifest_path,"idle","npc",11)
	preview.advance_reference_source(0.0,"idle",5)
	check(STORE.initial_state(found.entry,"idle",5) == preview._cooked_state and preview._cooked_state == 1,"zero-duration boundary chooses the real initial state")
	preview.free()

func synchronous_consumers() -> void:
	STORE.reset_for_tests()
	STORE.npc_page_prewarm = true
	for consumer: String in ["player","transform","effect"]:
		var found: Dictionary = fixture(10,2,64,consumer)
		check(VIEW.prepare_first_cooked_pose(selected(10,consumer)).status == "unsupported","pilot excludes " + consumer)
		var preview := PREVIEW.new()
		root.add_child(preview)
		check(preview._configure_cooked(found,selected(10,consumer).manifest_path,"idle",consumer,10),"unchanged preview configures " + consumer)
		preview.advance_reference_source(0.0,"idle",5)
		check(preview._cooked_state == 0 and preview._cooked_sprites.size() == 2 and preview._clock == 0.0,"first 10 ms pose is present before the short consumer clock advances: " + consumer)
		preview.advance_reference_source(0.015,"idle",5)
		check(preview._cooked_state == 1 and is_equal_approx(preview._clock,0.015),"short consumer duration and next pose are unchanged: " + consumer)
		preview.free()
	check(STORE.prepared_page_stats().jobs == 0,"player/card/effect previews never enqueue a pilot read")

func benchmark() -> void:
	STORE.reset_for_tests()
	var found: Dictionary = fixture(20,1,1024)
	var started: int = Time.get_ticks_usec()
	STORE.page_texture(found.actor,0)
	evidence["sync_1024_first_usec"] = Time.get_ticks_usec()-started
	started = Time.get_ticks_usec()
	STORE.page_texture(found.actor,0)
	evidence["sync_1024_warm_usec"] = Time.get_ticks_usec()-started
	STORE.reset_for_tests()
	found = STORE.lookup(selected(20))
	started = Time.get_ticks_usec()
	STORE.prepare_state(found.actor,0)
	evidence["async_1024_request_usec"] = Time.get_ticks_usec()-started
	var first_frame: int = Engine.get_process_frames()
	var ready: Dictionary = await drain(found)
	evidence["async_1024_ready_frames"] = Engine.get_process_frames()-first_frame
	evidence["async_1024_ready_usec"] = Time.get_ticks_usec()-started
	check(ready.status == "ready","normal first paint becomes ready")
	started = Time.get_ticks_usec()
	var warm: Dictionary = STORE.prepare_state(found.actor,0)
	evidence["async_1024_warm_usec"] = Time.get_ticks_usec()-started
	check(warm.status == "ready" and STORE.prepared_page_stats().jobs == 0,"warm pose is immediately ready without another job")

func demand_benchmark() -> void:
	STORE.reset_for_tests()
	fixture(22,1,1024)
	var samples: Array[Array] = [[],[]]
	for run: int in 12:
		for ready_cpu: int in ([0,1] if run%2==0 else [1,0]):
			STORE.reset_for_tests()
			var found: Dictionary = STORE.lookup(selected(22))
			if ready_cpu == 1:
				STORE.prepare_state(found.actor,0)
				var job: Dictionary = STORE._page_jobs.values()[0]
				check(await wait_for_cpu(job),"benchmark CPU read completes before demand")
			var start: int = Time.get_ticks_usec()
			var texture: Texture2D = STORE.page_texture(found.actor,0)
			var elapsed: int = Time.get_ticks_usec()-start
			check(texture != null,"benchmark produces a valid 1024 square texture")
			if run >= 2: samples[ready_cpu].append(elapsed)
	for sample: Array in samples: sample.sort()
	evidence["demand_1024_sync_p50_usec"] = (samples[0][4]+samples[0][5])/2.0
	evidence["demand_1024_worker_ready_p50_usec"] = (samples[1][4]+samples[1][5])/2.0

func run() -> void:
	directory = ProjectSettings.globalize_path("user://cooked-page-pilot")
	STORE.root_override = directory
	var sp2_enabled: bool = SP2.enabled
	await first_pose()
	await frame_cap_and_eviction()
	await failure_and_bounds()
	await concurrent_demand()
	await cancellation()
	await spawn_gate()
	await sharing_and_live_index()
	synchronous_consumers()
	await benchmark()
	if "--page-demand-benchmark" in OS.get_cmdline_user_args(): await demand_benchmark()
	check(SP2.enabled == sp2_enabled,"the pilot never changes the original SP2 worker setting")
	STORE.npc_page_prewarm = false
	STORE.reset_for_tests()
	STORE.root_override = ""
	print("COOKED_PAGE_PREPARE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
