extends SceneTree
## Optional synthetic CPU benchmark; no original pack or GPU upload is measured.
## Reproduce with Godot 4.7.2 after importing the project:
##   git show 11df087:scripts/ui/original_ui/source_pack.gd > /tmp/source-pack-before.gd
##   mkdir -p /tmp/twilight-pma-benchmark/data /tmp/twilight-pma-benchmark/config /tmp/twilight-pma-benchmark/cache
##   XDG_DATA_HOME=/tmp/twilight-pma-benchmark/data XDG_CONFIG_HOME=/tmp/twilight-pma-benchmark/config XDG_CACHE_HOME=/tmp/twilight-pma-benchmark/cache godot --headless --path . --script res://tests/benchmark_original_ui_premultiply.gd -- --baseline=/tmp/source-pack-before.gd
## Timings are observations, never test thresholds or device FPS claims.
const AFTER=preload("res://scripts/ui/original_ui/cocos_premultiply_pixels.gd")

func _initialize() -> void:
	_run.call_deferred()

func _fail(reason: String) -> void:
	printerr("ORIGINAL_UI_PREMULTIPLY_BENCHMARK_FAILED "+reason)
	quit(2)

static func _image(size_value: int) -> Image:
	var random:=RandomNumberGenerator.new()
	random.seed=20261112+size_value
	var pixels:=PackedByteArray()
	pixels.resize(size_value*size_value*4)
	for at: int in range(0,pixels.size(),4):pixels.encode_u32(at,random.randi())
	return Image.create_from_data(size_value,size_value,false,Image.FORMAT_RGBA8,pixels)

func _run() -> void:
	var baseline_path: String=""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline="):baseline_path=argument.trim_prefix("--baseline=")
	if baseline_path.is_empty() or not baseline_path.is_absolute_path() or not FileAccess.file_exists(baseline_path):
		_fail("Pass --baseline=/absolute/path.gd; see this script's reproduction commands.")
		return
	var baseline:=GDScript.new()
	baseline.source_code=FileAccess.get_file_as_string(baseline_path)
	if baseline.source_code.is_empty() or baseline.reload()!=OK:
		_fail("Baseline GDScript is empty, unreadable, or invalid.")
		return
	var before_op:=Callable(baseline,"cocos_premultiply")
	var after_op:=Callable(AFTER,"convert")
	if not before_op.is_valid() or not after_op.is_valid():
		_fail("Expected baseline cocos_premultiply(Image) and optimized convert(Image).")
		return
	var samples: Array=[]
	for size_value: int in [64,256,1024]:
		var image: Image=_image(size_value)
		var original: PackedByteArray=image.get_data()
		var before: Image=before_op.call(image)
		var after: Image=after_op.call(image)
		if before==null or after==null or before.get_data()!=after.get_data() or original!=image.get_data():
			_fail("Full-byte equivalence or source preservation failed at "+str(size_value))
			return
		var before_times: Array[int]=[]
		var after_times: Array[int]=[]
		var repeats: int=20 if size_value<1024 else 6
		for iteration: int in repeats:
			# Alternate execution order to avoid always warming one producer first.
			for improved: bool in ([false,true] if iteration%2==0 else [true,false]):
				var operation: Callable=after_op if improved else before_op
				var started: int=Time.get_ticks_usec()
				var output: Image=operation.call(image)
				var elapsed: int=Time.get_ticks_usec()-started
				if output==null:_fail("Producer returned no image.");return
				if improved:after_times.append(elapsed)
				else:before_times.append(elapsed)
		before_times.sort();after_times.sort()
		samples.append({"size":size_value,"calls_each":repeats,"before_median_usec":before_times[repeats/2],"after_median_usec":after_times[repeats/2],"byte_equal":true,"source_unchanged":true})
	print("ORIGINAL_UI_PREMULTIPLY_BENCHMARK ",JSON.stringify({"scope":"synthetic_RGBA8_CPU_only_no_GPU_or_private_pack","engine":Engine.get_version_info().string,"baseline":baseline_path,"samples":samples}))
	quit()
