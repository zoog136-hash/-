extends RefCounted
## GPU block compression (ETC2 on phones, S3TC elsewhere) of 523 tile atlases,
## off the main thread. A decoded 384x384 RGBA8 atlas costs 576 KiB of texture
## memory; ETC2/S3TC RGBA costs 144 KiB. The atlas is shown uncompressed at
## once (nothing waits); a worker compresses a private copy of its pixels and
## the main thread later swaps the same texture object to the compressed image
## (ImageTexture.set_image), so every holder keeps working and no frame
## compresses. Atlas cells are 24 px, a multiple of the 4x4 block, so blocks
## never mix two tiles. Nothing reads tile atlas pixels back on the CPU.
## Unsupported devices or TWILIGHT_GPU_ACTOR_TEXTURES=0 keep RGBA8.
const GPU = preload("res://scripts/resources/gpu_actor_texture.gd")
const MAX_RUNNING: int = 2
## Waiting decoded copies are CPU memory (576 KiB each): bounded; an atlas
## dropped from the queue simply stays RGBA8.
const MAX_WAITING: int = 48

var _waiting: Array = [] # [texture, image] in load order
var _running: Array = [] # [task_id, texture, image]
var compressed: int = 0
var dropped: int = 0
## queue() and texture_for() can pump repeatedly in one frame. Swaps share
## this allowance; completed jobs retain the texture/image until a later frame.
const MAX_SWAPS_PER_FRAME: int = 1
const SWAP_BUDGET_USEC: int = 2000
var _swap_frame: int = -1
var _swaps_this_frame: int = 0
var _swap_usec: int = 0
var _swap_sequence: int = 0
var _start_sequence: int = 0
var _priority: Dictionary = {} # instance ID only; no extra texture ownership

func prioritize(texture: ImageTexture) -> void:
	_priority[texture.get_instance_id()] = Engine.get_process_frames()

static func mode() -> int:
	return GPU.compression_mode() if GPU.enabled else -1

## Queues `image` (exclusively owned by the caller, not used afterwards) to
## replace the pixels of `texture`. `pump_now` false only queues (tests use it
## to check the waiting bound without racing the worker threads).
func queue(texture: ImageTexture, image: Image, pump_now: bool = true) -> void:
	if mode() < 0 or texture == null or image == null or image.is_compressed() or image.get_width() % 4 != 0 or image.get_height() % 4 != 0: return
	if _waiting.size() >= MAX_WAITING:
		_waiting.pop_front()
		dropped += 1
	_waiting.append([texture, image])
	if pump_now: pump()

## Applies finished compressions within the engine frame allowance, then
## starts waiting work. Every fourth swap/start serves the oldest ready item.
func pump() -> void:
	var frame: int = Engine.get_process_frames()
	if _swap_frame != frame:
		_swap_frame = frame
		_swaps_this_frame = 0
		_swap_usec = 0
		for id: int in _priority.keys():
			if int(_priority[id]) < frame - 1: _priority.erase(id)
	if _running.is_empty() and _waiting.is_empty(): return
	while _swaps_this_frame < MAX_SWAPS_PER_FRAME and (_swaps_this_frame == 0 or _swap_usec < SWAP_BUDGET_USEC):
		var selected: int = -1
		for index: int in _running.size():
			var job: Array = _running[index]
			if not WorkerThreadPool.is_task_completed(int(job[0])): continue
			if selected < 0: selected = index
			if _swap_sequence % 4 == 3: break
			if _is_priority(job[1], frame):
				selected = index
				break
		if selected < 0: break
		var started: int = Time.get_ticks_usec()
		var job: Array = _running[selected]
		WorkerThreadPool.wait_for_task_completion(int(job[0]))
		_running.remove_at(selected)
		var texture: ImageTexture = job[1]
		var image: Image = job[2]
		if image.is_compressed():
			texture.set_image(image)
			texture.set_meta("gpu_bytes", image.get_data_size())
			compressed += 1
		_swap_usec += Time.get_ticks_usec() - started
		_swaps_this_frame += 1
		_swap_sequence += 1
	while _running.size() < MAX_RUNNING and not _waiting.is_empty():
		var selected: int = 0
		if _start_sequence % 4 != 3:
			for index: int in _waiting.size():
				if _is_priority(_waiting[index][0], frame):
					selected = index
					break
		var next: Array = _waiting[selected]
		_waiting.remove_at(selected)
		_start_sequence += 1
		var work: Image = next[1]
		_running.append([WorkerThreadPool.add_task(_compress.bind(work, mode()), false, "tile atlas gpu compression"), next[0], work])

func _is_priority(texture: ImageTexture, frame: int) -> bool:
	return int(_priority.get(texture.get_instance_id(), -2)) >= frame - 1

static func _compress(image: Image, compression: int) -> void:
	image.fix_alpha_edges()
	image.compress(compression, Image.COMPRESS_SOURCE_GENERIC)

## Waits for every running job (shutdown/tests). Waiting jobs are discarded.
func finish() -> void:
	_waiting.clear()
	_priority.clear()
	for job: Array in _running: WorkerThreadPool.wait_for_task_completion(int(job[0]))
	_running.clear()

func pending() -> int:
	return _running.size() + _waiting.size()
