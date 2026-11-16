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

## Applies finished compressions and starts waiting ones. Cheap when idle.
func pump() -> void:
	if _running.is_empty() and _waiting.is_empty(): return
	for index: int in range(_running.size() - 1, -1, -1):
		var job: Array = _running[index]
		if not WorkerThreadPool.is_task_completed(int(job[0])): continue
		WorkerThreadPool.wait_for_task_completion(int(job[0]))
		_running.remove_at(index)
		var texture: ImageTexture = job[1]
		var image: Image = job[2]
		if image.is_compressed():
			texture.set_image(image)
			texture.set_meta("gpu_bytes", image.get_data_size())
			compressed += 1
	while _running.size() < MAX_RUNNING and not _waiting.is_empty():
		var next: Array = _waiting.pop_front()
		var work: Image = next[1]
		_running.append([WorkerThreadPool.add_task(_compress.bind(work, mode()), false, "tile atlas gpu compression"), next[0], work])

static func _compress(image: Image, compression: int) -> void:
	image.fix_alpha_edges()
	image.compress(compression, Image.COMPRESS_SOURCE_GENERIC)

## Waits for every running job (shutdown/tests). Waiting jobs are discarded.
func finish() -> void:
	_waiting.clear()
	for job: Array in _running: WorkerThreadPool.wait_for_task_completion(int(job[0]))
	_running.clear()

func pending() -> int:
	return _running.size() + _waiting.size()
