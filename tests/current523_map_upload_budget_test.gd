extends SceneTree
## Real worker completion + ImageTexture publication, using test pixels only.
const PACK = preload("res://scripts/maps/current523_tile_pack.gd")
const GPU = preload("res://scripts/maps/current523_tile_gpu.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

class SlowPack extends PACK:
	func _publish(id: int, job: Dictionary) -> Texture2D:
		OS.delay_msec(3)
		return super._publish(id, job)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("MAP_UPLOAD_BUDGET_FAIL: ", label)

func _initialize() -> void: _run.call_deferred()

func next_frame() -> void:
	var frame: int = Engine.get_process_frames()
	while Engine.get_process_frames() == frame: await process_frame

static func pixels(id: int) -> Image:
	var out := Image.create_empty(384, 384, false, Image.FORMAT_RGBA8)
	out.fill(Color8(id * 13 % 255, 80, 190, 255))
	return out

static func completed() -> void: pass

func queue_decoded(pack: RefCounted, id: int, failed: bool = false) -> void:
	pack._blocks[id] = 256
	pack._jobs[id] = {"task":WorkerThreadPool.add_task(completed), "image":null if failed else pixels(id), "problem":"synthetic pinned decode failure" if failed else ""}

func wait_decoded(pack: RefCounted) -> void:
	for _step: int in 200:
		var ready: bool = true
		for job: Dictionary in pack._jobs.values(): ready = ready and WorkerThreadPool.is_task_completed(int(job.task))
		if ready: return
		await create_timer(0.001).timeout
	check(false, "test workers complete")

func publish_frames() -> void:
	var pack := PACK.new()
	pack.loaded = true
	pack.background_only = true
	pack.hold_published = true
	pack.compress_for_gpu = false
	for id: int in 8: queue_decoded(pack, id)
	await wait_decoded(pack)
	pack.prioritize(7)
	var start_frame: int = Engine.get_process_frames()
	var before: int = pack.atlas_loads
	for _call: int in 20:
		pack.pump_jobs()
		pack.pump_gpu()
		pack.texture_for(7)
	check(Engine.get_process_frames() == start_frame and pack.atlas_loads - before <= PACK.MAX_PUBLISH_PER_FRAME, "repeated pump_jobs/pump_gpu/texture_for calls share one engine-frame publication cap")
	check(pack.texture_for(7) != null and pack.atlas_loads > 0, "a ready visible atlas paints in the first eligible frame")
	check(pack.pending_jobs() > 0, "remaining completed decodes retain their images for later frames")
	var first_ids: PackedInt32Array = pack.completed_atlases_this_frame()
	check(first_ids.size()==pack.atlas_loads-before and first_ids[0]==7,"completion IDs follow publication order and share its cap")
	var held: Texture2D = pack.texture_for(7)
	var identity: int = held.get_instance_id()
	var frames: int = 1
	while pack.pending_jobs() > 0 and frames < 20:
		await next_frame()
		check(pack.completed_atlases_this_frame().is_empty(),"previous frame completion IDs never wake current retries")
		before = pack.atlas_loads
		for _call: int in 20: pack.pump_gpu()
		check(pack.atlas_loads - before > 0 and pack.atlas_loads - before <= PACK.MAX_PUBLISH_PER_FRAME, "each following frame progresses within the publication cap")
		frames += 1
	evidence["eight_ready_atlas_frames"] = frames
	check(pack.pending_jobs() == 0 and pack.atlas_loads == 8, "all completed atlases eventually publish")
	check(pack.texture_for(7).get_instance_id() == identity and pack.held_size() == 8, "publication preserves held texture identity and lifetime")
	# Check pixels via the actual publication method's job, not a replacement.
	var image: Image = pixels(11)
	queue_decoded(pack, 11)
	var supplied: Image = pack._jobs[11].image
	check(supplied.get_data() == image.get_data(), "test supplies deterministic pixels")
	await wait_decoded(pack)
	await next_frame()
	pack.pump_jobs()
	check(supplied.get_data() == image.get_data() and pack.texture_for(11) != null, "publication scheduling does not modify source pixels")
	# Exceed cache capacity; an existing block/holder reference stays alive.
	for id: int in range(20, 60):
		queue_decoded(pack, id)
		await wait_decoded(pack)
		await next_frame()
		pack.pump_jobs()
	pack.release_held()
	check(is_instance_valid(held) and held.get_instance_id() == identity and held.get_size() == Vector2(384,384) and pack.cache_size() == PACK.MAX_CACHED_ATLASES, "cache eviction and held release do not invalidate a retained texture")

func fairness_and_time() -> void:
	var pack := PACK.new()
	pack.loaded = true
	pack.background_only = true
	pack.compress_for_gpu = false
	queue_decoded(pack, 0)
	var served: bool = false
	for frame: int in 8:
		for id: int in range(1 + frame * 2, 3 + frame * 2):
			queue_decoded(pack, id)
			pack.prioritize(id)
		await wait_decoded(pack)
		pack.pump_jobs()
		if pack._cache.has(0): served = true; break
		await next_frame()
	check(served and pack._publish_sequence <= 4, "continuous visible arrivals cannot starve the oldest completed atlas")
	pack._drop_jobs()
	var slow := SlowPack.new()
	slow.loaded = true
	slow.background_only = true
	slow.compress_for_gpu = false
	for id: int in 3: queue_decoded(slow, id)
	await wait_decoded(slow)
	var start: int = Time.get_ticks_usec()
	for _call: int in 10: slow.pump_jobs()
	evidence["slow_publication_slice_usec"] = Time.get_ticks_usec() - start
	check(slow.atlas_loads == 1 and slow.pending_jobs() == 2, "one slow upload uses the time allowance across repeated pumps")
	await next_frame()
	check(slow.pump_jobs() == 1, "the next engine frame gets a fresh time allowance")
	slow._drop_jobs()
	# Failures complete and retain their exact diagnostic instead of starving.
	await next_frame()
	queue_decoded(pack, 99, true)
	await wait_decoded(pack)
	pack.pump_jobs()
	check(pack.prefetch(99) and pack.texture_for(99) == null and pack.problem == "synthetic pinned decode failure", "a failed decode publishes the original error without a substitute texture")

func swaps() -> void:
	# Image compression is CPU-side and available in this editor test binary,
	# even when the headless renderer reports no supported GPU format.
	var gpu := GPU.new()
	var textures: Array[ImageTexture] = []
	var images: Array[Image] = []
	for id: int in 2:
		var image: Image = pixels(id)
		var texture := ImageTexture.create_from_image(image)
		textures.append(texture)
		var compressed: Image = image.duplicate()
		var result: Error = compressed.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_GENERIC)
		check(result == OK and compressed.is_compressed(), "test compression succeeds")
		images.append(compressed)
		gpu._running.append([WorkerThreadPool.add_task(completed), texture, compressed])
	for _step: int in 200:
		if WorkerThreadPool.is_task_completed(int(gpu._running[0][0])) and WorkerThreadPool.is_task_completed(int(gpu._running[1][0])): break
		await create_timer(0.001).timeout
	gpu.prioritize(textures[1])
	var identity: int = textures[1].get_instance_id()
	var frame: int = Engine.get_process_frames()
	for _call: int in 20: gpu.pump()
	check(frame == Engine.get_process_frames() and gpu.compressed == 1 and gpu.pending() == 1, "repeated compression pumps swap only one texture in the engine frame")
	check(textures[1].has_meta("gpu_bytes") and not textures[0].has_meta("gpu_bytes"), "ready visible compression swaps before older nonvisible work")
	check(textures[1].get_instance_id() == identity and textures[1].get_size() == Vector2(384,384), "the swap retains the exact texture object and geometry")
	await next_frame()
	gpu.pump()
	check(gpu.compressed == 2 and gpu.pending() == 0 and textures[0].has_meta("gpu_bytes"), "deferred compression swaps on a following frame without starvation")
	gpu.finish()
	# Keep a ready old swap waiting while new visible jobs arrive. The fourth
	# completion must serve that old texture, independent of pump frequency.
	var fair := GPU.new()
	var old := ImageTexture.create_from_image(pixels(20))
	fair._running.append([WorkerThreadPool.add_task(completed), old, images[0]])
	for step: int in 6:
		var fresh := ImageTexture.create_from_image(pixels(21 + step))
		fair._running.append([WorkerThreadPool.add_task(completed), fresh, images[1]])
		for _poll: int in 200:
			var all_done: bool = true
			for job: Array in fair._running: all_done = all_done and WorkerThreadPool.is_task_completed(int(job[0]))
			if all_done: break
			await create_timer(0.001).timeout
		fair.prioritize(fresh)
		for _call: int in 10: fair.pump()
		if old.has_meta("gpu_bytes"): break
		await next_frame()
	check(old.has_meta("gpu_bytes") and fair.compressed <= 4, "continuous visible compressions cannot starve an older ready swap")
	fair.finish()

func _run() -> void:
	await publish_frames()
	await fairness_and_time()
	await swaps()
	print("MAP_UPLOAD_BUDGET_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
