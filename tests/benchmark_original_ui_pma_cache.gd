extends SceneTree
## Optional synthetic CPU/API benchmark, never a CI latency threshold.
## Preserve the old consumer outside the repository (do not copy it here):
## git show 11df087:scripts/ui/original_ui/source_asset_pixels.gd > /tmp/pma-before.gd
## Run with isolated writable data/cache directories, for example:
## XDG_DATA_HOME=/tmp/pma-bench-data XDG_CONFIG_HOME=/tmp/pma-bench-config XDG_CACHE_HOME=/tmp/pma-bench-cache \
##   godot --headless --path . --script res://tests/benchmark_original_ui_pma_cache.gd \
##   -- --baseline=/tmp/pma-before.gd
## The baseline argument is required. Generated PNG files are synthetic noise
## and are removed after the run. Dummy-renderer calls do not measure real
## GPU upload/readback, private original packs, or Android device latency.
const PIXELS=preload("res://scripts/ui/original_ui/source_asset_pixels.gd")
const IMAGE_PACK=preload("res://scripts/resources/source523_image_pack.gd")
var sink: Variant
var rows: Array=[]
var failures: Array[String]=[]
var directory: String=""
var generated: Array[String]=[]

func _initialize() -> void:_run.call_deferred()

func _image(size: int) -> Image:
	var data:=PackedByteArray()
	data.resize(size*size*4)
	var rng:=RandomNumberGenerator.new()
	rng.seed=123456789+size
	for at: int in range(0,data.size(),4):
		var value: int=rng.randi()
		data[at]=value&255
		data[at+1]=(value>>8)&255
		data[at+2]=(value>>16)&255
		data[at+3]=(value>>24)&255
	return Image.create_from_data(size,size,false,Image.FORMAT_RGBA8,data)

func _stats(name: String, times: Array[int]) -> Dictionary:
	times.sort()
	var total: int=0
	for elapsed: int in times:total+=elapsed
	return {"operation":name,"calls":times.size(),"median_usec":times[times.size()/2],"mean_usec":float(total)/times.size(),"min_usec":times[0],"max_usec":times[-1]}

func _sample(name: String, operation: Callable, count: int) -> Dictionary:
	sink=operation.call()
	var times: Array[int]=[]
	for iteration: int in range(count):
		var started: int=Time.get_ticks_usec()
		sink=operation.call()
		times.append(Time.get_ticks_usec()-started)
	return _stats(name,times)

func _run() -> void:
	var baseline_path: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--baseline="):baseline_path=value.trim_prefix("--baseline=")
	if baseline_path.is_empty() or not baseline_path.is_absolute_path() or not FileAccess.file_exists(baseline_path):
		failures.append("An existing absolute --baseline=/path/to/oldconsumer.gd is required; see the script header.")
		_finish()
		return
	var before:=GDScript.new()
	before.source_code=FileAccess.get_file_as_string(baseline_path)
	if before.reload()!=OK or not before.has_method("consume_owner_result"):
		failures.append("The supplied baseline must parse and provide consume_owner_result.")
		_finish()
		return
	directory=ProjectSettings.globalize_path("user://benchmark_pma_synthetic").path_join(str(OS.get_process_id()))
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:
		failures.append("Cannot create isolated synthetic image directory.")
		_finish()
		return
	for size: int in [64,256,1024]:_measure(before,size)
	_finish()

func _measure(before: Script, size: int) -> void:
	var image: Image=_image(size)
	var original:=ImageTexture.create_from_image(image)
	var owner: Dictionary={"ok":true,"texture":original,"status":"synthetic-only","provenance":{"member":{"format":"PNG","sha256":"synthetic-member"},"pack_sha":"synthetic-pack"}}
	var count: int=30 if size==64 else (10 if size==256 else 4)
	var operations: Array=[]
	operations.append(_sample("baseline_consume_no_owner_io",func() -> Variant:return before.call("consume_owner_result",owner),count))
	var first: Array[int]=[]
	for iteration: int in range(count):
		PIXELS._pma_cache.clear()
		var started: int=Time.get_ticks_usec()
		sink=PIXELS.consume_owner_result(owner)
		first.append(Time.get_ticks_usec()-started)
	operations.append(_stats("production_first_consume_no_owner_io_clear_outside_timing",first))
	var held: Texture2D=PIXELS.consume_owner_result(owner).texture
	var conversions_before: int=PIXELS._pma_cache.metrics().conversions
	operations.append(_sample("production_consume_warm_no_owner_io",func() -> Variant:return PIXELS.consume_owner_result(owner),50))
	if PIXELS.consume_owner_result(owner).texture!=held:failures.append("Warm consumer texture identity changed.")
	var extra_conversions: int=PIXELS._pma_cache.metrics().conversions-conversions_before
	if extra_conversions!=0:failures.append("Warm consumer unexpectedly repeated pixel conversion.")
	var bytes: PackedByteArray=image.save_png_to_buffer()
	var name: String="noise-%d.png"%size
	var path: String=directory.path_join(name)
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:failures.append("Cannot write synthetic PNG.");return
	file.store_buffer(bytes)
	file.close()
	generated.append(path)
	var pack=IMAGE_PACK.new()
	pack._root=directory
	pack._members[name]={"file":name,"plain_bytes":bytes.size(),"sha256":FileAccess.get_sha256(path),"format":"PNG","width":size,"height":size}
	var resident: Dictionary=pack._texture(name,{})
	if not resident.get("ok",false):failures.append("Synthetic owner texture fixture failed.");return
	var owner_held: Texture2D=PIXELS.consume_owner_result(resident).texture
	operations.append(_sample("production_owner_texture_strict_verify_then_consume_warm",func() -> Variant:return PIXELS.consume_owner_result(pack._texture(name,{})),40))
	if PIXELS.consume_owner_result(pack._texture(name,{})).texture!=owner_held:failures.append("Verified-owner warm texture identity changed.")
	rows.append({"size":size,"synthetic_encoded_png_bytes":bytes.size(),"warm_consumer_extra_conversions":extra_conversions,"operations":operations,"owner_cache_metrics":pack.texture_cache_metrics()})

func _finish() -> void:
	for path: String in generated:
		if DirAccess.remove_absolute(path)!=OK:failures.append("Synthetic PNG cleanup failed.")
	if not directory.is_empty():
		if DirAccess.remove_absolute(directory)!=OK:failures.append("Synthetic benchmark directory cleanup failed.")
		DirAccess.remove_absolute(directory.get_base_dir())
	PIXELS._pma_cache.clear()
	print("ORIGINAL_UI_PMA_CACHE_BENCHMARK ",JSON.stringify({"engine":Engine.get_version_info().string,"headless_dummy_only":DisplayServer.get_name()=="headless","private_pack_used":false,"scope":"synthetic CPU/API; owner IO excluded or strict SHA included as labelled; no GPU/device latency claim","rows":rows,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
