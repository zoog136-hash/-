extends SceneTree
## Optional bounded CPU/Variant comparison; no CI timing threshold.
## git show 28f3084:scripts/ui/original_ui/source_main_quickslot_bindings.gd > /tmp/quickslot-bindings-before.gd
## git show 28f3084:scripts/ui/original_ui/source_main_quickslot_view.gd > /tmp/quickslot-view-before.gd
## XDG_DATA_HOME=/tmp/quickslot-bench-data XDG_CONFIG_HOME=/tmp/quickslot-bench-config \
## XDG_CACHE_HOME=/tmp/quickslot-bench-cache godot --headless --path . \
##   --script res://tools/benchmarks/benchmark_original_ui_quickslot_snapshot.gd \
##   -- --baseline-bindings=/tmp/quickslot-bindings-before.gd \
##      --baseline-view=/tmp/quickslot-view-before.gd --output=/tmp/quickslot.json
## Explicit baselines avoid copying an old implementation into the repository.
## Uses actual view/adapter/count code with ten synthetic ammo-skill entries.
## Setter-only and SourceText/public Noto-font phases exclude original CSBs,
## artwork, World ammo lookup costs, actual drawing, GPU and Android timing.
const VIEW=preload("res://scripts/ui/original_ui/source_main_quickslot_view.gd")
const BINDING=preload("res://scripts/ui/original_ui/source_main_quickslot_bindings.gd")
const TEXT=preload("res://scripts/ui/original_ui/source_text.gd")
var failures: Array[String]=[]
const REFRESHES=200
const MAX_STATIC_GROWTH=64*1024*1024
class World extends Node:
	var page_reads: int=0
	var ammo_reads: int=0
	var ammo: int=7
	func _quickslot_pages() -> Array:page_reads+=1;return [0,0]
	func _quickslot_ammo_source(_entry: Dictionary) -> Dictionary:ammo_reads+=1;return {"ammo_count":ammo,"can_use_without_ammo":false}
class Hud extends Node:
	var quickslot_entries: Array=[]
	var quickslot_captions: Array=[]
	var quickslot_cooldown_labels: Array=[]
	var index_reads: int=0
	func quickslot_index(index: int) -> int:index_reads+=1;return index
	func _emit_quickslot(_index: int) -> void:pass
class Pack extends RefCounted:
	var manifest: Dictionary={"files":{}}
class Sink extends Node2D:
	var source_member: String=BINDING.SLOT_MEMBER
	var texts: Dictionary={}
	var values: Dictionary={}
	var setters: int=0
	func set_bound_text(offset: int,value: String) -> Dictionary:
		setters+=1;values[offset]=value
		return texts[offset].set_source_text(value) if texts.has(offset) else {"ok":true}
	func set_bound_visible(offset: int,value: bool) -> Dictionary:values[str(offset)+"visible"]=value;return {"ok":true}
func _initialize() -> void:_run.call_deferred()
func _script(source: String) -> GDScript:
	var code:=GDScript.new();code.source_code=source
	if code.reload()!=OK:failures.append("temporary candidate failed to compile")
	return code
func _fixture(binding_script: Script,view_script: Script,with_font: bool) -> Dictionary:
	var world:=World.new();var hud:=Hud.new();world.add_child(hud);root.add_child(world)
	for index: int in 10:
		hud.quickslot_entries.append({"kind":"skill","id":"synthetic-ammo-"+str(index)})
		var caption:=Label.new();var cooldown:=Label.new();cooldown.text="0.5"
		hud.add_child(caption);hud.add_child(cooldown)
		hud.quickslot_captions.append(caption);hud.quickslot_cooldown_labels.append(cooldown)
	var pack:=Pack.new()
	pack.manifest.files={BINDING.SET_MEMBER:{"sha256":BINDING.SET_SHA256},BINDING.SLOT_MEMBER:{"sha256":BINDING.SLOT_SHA256}}
	var bindings: RefCounted=binding_script.new();bindings.configure(pack,hud,Callable())
	var view: RefCounted=view_script.new();view._bindings=bindings;view._parent=weakref(root);view._hud=weakref(hud)
	var shell:=Node2D.new();root.add_child(shell);view._scene=shell
	view._identity=VIEW._model_identity(bindings.snapshot())
	var font: FontFile
	if with_font:
		font=FontFile.new();font.data=FileAccess.get_file_as_bytes("res://assets/fonts/NotoSansKR.ttf");font.allow_system_fallback=false
		if font.data.is_empty():failures.append("Public Noto font source bytes are unavailable to this benchmark.")
	for index: int in 10:
		var sink:=Sink.new();shell.add_child(sink)
		if with_font:
			for offset: int in [BINDING.AMOUNT,BINDING.COOLDOWN]:
				var label:=TEXT.new();sink.add_child(label)
				var options: Dictionary={"text":"7","fontSize":16,"widgetOptions":{"ignoreSize":true},"hAlignment":0,"vAlignment":0,"shadowEnabled":false,"outlineEnabled":false}
				if not label.configure(font,options,Vector2(80,20)).get("ok",false):failures.append("synthetic font fixture failed")
				sink.texts[offset]=label
		view._hits[index]={"native_slot_scene":sink}
	return {"view":view,"world":world,"hud":hud,"shell":shell,"bindings":bindings}
func _run() -> void:
	var binding_path: String=""
	var view_path: String=""
	var output_path: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--baseline-bindings="):binding_path=value.trim_prefix("--baseline-bindings=")
		elif value.begins_with("--baseline-view="):view_path=value.trim_prefix("--baseline-view=")
		elif value.begins_with("--output="):output_path=value.trim_prefix("--output=")
	if not binding_path.is_absolute_path() or not view_path.is_absolute_path() or not FileAccess.file_exists(binding_path) or not FileAccess.file_exists(view_path):
		printerr("QUICKSLOT_SNAPSHOT_BENCHMARK requires --baseline-bindings=/absolute/file.gd and --baseline-view=/absolute/file.gd exported from 28f3084.")
		quit(2);return
	var counter_var: String="var snapshot_calls: int=0\nvar _pack: RefCounted"
	var counter_body: String="func snapshot() -> Dictionary:\n\tsnapshot_calls+=1"
	var before_binding: Script=_script(FileAccess.get_file_as_string(binding_path).replace("var _pack: RefCounted",counter_var).replace("func snapshot() -> Dictionary:",counter_body))
	var before_view: Script=_script(FileAccess.get_file_as_string(view_path))
	var current_binding: Script=_script(FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_quickslot_bindings.gd").replace("var _pack: RefCounted",counter_var).replace("func snapshot() -> Dictionary:",counter_body))
	if not failures.is_empty():quit(2);return
	var baseline_static: int=OS.get_static_memory_usage()
	var reports: Array=[]
	for with_font: bool in [false,true]:
		var results: Array=[]
		for pair: Array in [["baseline",before_binding,before_view],["one_snapshot",current_binding,VIEW]]:
			var f: Dictionary=_fixture(pair[1],pair[2],with_font)
			f.view.refresh()
			f.world.ammo_reads=0;f.world.page_reads=0;f.hud.index_reads=0;f.bindings.snapshot_calls=0
			var count: int=REFRESHES
			for index: int in 10:f.view._hits[index].native_slot_scene.setters=0
			var started: int=Time.get_ticks_usec()
			for cycle: int in count:
				if not f.view.refresh().get("ok",false):failures.append("refresh failed")
			var elapsed: int=Time.get_ticks_usec()-started
			var values: Array=[];var text_setters: int=0
			for index: int in 10:
				var sink: Sink=f.view._hits[index].native_slot_scene
				values.append(sink.values.duplicate(true));text_setters+=sink.setters
			results.append({"case":pair[0],"refreshes":count,"mean_usec":float(elapsed)/count,"snapshot_calls":f.bindings.snapshot_calls,"ammo_reads":f.world.ammo_reads,"page_reads":f.world.page_reads,"visible_index_reads":f.hud.index_reads,"text_setters":text_setters,"display_digest":var_to_bytes(values).hex_encode().sha256_text()})
			if f.bindings.snapshot_calls!=(count*11 if pair[0]=="baseline" else count):failures.append("Unexpected snapshot count; supply the actual baseline and current implementation.")
			if f.world.ammo_reads!=f.bindings.snapshot_calls*10:failures.append("Ammo projection counts changed.")
			if text_setters!=count*20:failures.append("Live label setter count changed.")
			f.view.close();f.world.free();f.shell.free()
		if results[0].display_digest!=results[1].display_digest:failures.append("display fields differ")
		reports.append({"font_backed_setters":with_font,"measurements":results})
		if OS.get_static_memory_usage()-baseline_static>MAX_STATIC_GROWTH:
			failures.append("64MiB engine static growth guard reached; remaining phases skipped.")
			break
	var report: Dictionary={"engine":Engine.get_version_info().string,"baseline_bindings_sha256":FileAccess.get_sha256(binding_path),"baseline_view_sha256":FileAccess.get_sha256(view_path),"scope":"actual QuickslotView.refresh + count adapter, synthetic 10 ammo-skill HUD; setter sink or actual SourceText/public Noto font; no original CSB/image/upload/World ammo lookup cost/draw/GPU/Android timing; engine static is not RSS/GPU","static_growth_guard_bytes":MAX_STATIC_GROWTH,"reports":reports,"failures":failures}
	if not output_path.is_empty():
		var file:=FileAccess.open(output_path,FileAccess.WRITE)
		if file==null:failures.append("Cannot write --output: "+str(FileAccess.get_open_error()))
		else:file.store_string(JSON.stringify(report,"\t"));file.close()
	print("QUICKSLOT_SNAPSHOT_BENCHMARK ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
