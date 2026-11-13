extends SceneTree
## Read-only actual-template-format oracle. No production cache-key override:
## the caller must provide a frozen fixture and its verified SHA explicitly.
const NATIVE = preload("res://scripts/loot/current523_native_item_projection.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var path: String = OS.get_environment("TWILIGHT_WEIGHT_FIXTURE")
	var expected: String = OS.get_environment("TWILIGHT_WEIGHT_FIXTURE_SHA256")
	if expected.length()!=64 or FileAccess.get_sha256(path)!=expected:
		printerr("WEIGHT_FIXTURE_SHA_MISMATCH");quit(2);return
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<8:quit(2);return
	file.seek(file.get_length()-8)
	var end: int=file.get_64()
	if end<0 or end>=file.get_length()-8:quit(2);return
	file.seek(end)
	var index: Variant=file.get_var()
	if not index is Dictionary or index.get("schema")!=NATIVE.TEMPLATE_SCHEMA or not index.get("ids") is PackedStringArray or not index.get("offsets") is PackedInt64Array or index.ids.size()!=index.offsets.size():quit(2);return
	var store:=NATIVE.TemplateStore.new();store.file=file;store.interning=false
	for at: int in index.ids.size():
		if index.offsets[at]<0 or index.offsets[at]>=end:quit(2);return
		store.offsets[index.ids[at]]=index.offsets[at]
	var runs: Array=[]
	for fast: bool in [false,true,true,false]:
		FIELDS.bind(store,NATIVE.TemplateStore)
		if not FIELDS._weight_store_exact:failures.append("production_opt_in_failed")
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
		var usec: int=0;var count: int=0
		for id: String in index.ids:
			var own: Dictionary=store.light(id)
			if own.is_empty():continue
			var begin: int=Time.get_ticks_usec()
			var value: Dictionary
			if fast: value=FIELDS._weight_fields_for_binding(own)
			else:
				var full: Dictionary=FIELDS._full_for_binding(own)
				value={}
				for key: String in ["source_weight_unit","source_original_item","source_weight"]:
					if full.has(key):value[key]=full[key]
			usec+=Time.get_ticks_usec()-begin
			hash.update(var_to_bytes(value));count+=1
		runs.append({"fast":fast,"usec":usec,"records":count,"sha256":hash.finish().hex_encode()})
	for value: Dictionary in runs:
		if value.records!=runs[0].records or value.sha256!=runs[0].sha256:failures.append("selected_fields_differ")
	if runs[0].records<1:failures.append("no_records")
	if FileAccess.get_sha256(path)!=expected:failures.append("fixture_changed")
	FIELDS.bind(null);file.close()
	print("WEIGHT_PROJECTION_RESULT "+JSON.stringify({"failures":failures,"runs":runs,"fixture_sha256":expected,"scope":"read-only frozen template fixture; not startup timing or cache-key acceptance"}))
	quit(0 if failures.is_empty() else 1)
