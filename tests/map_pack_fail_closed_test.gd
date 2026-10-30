extends SceneTree
const PNG=preload("res://scripts/maps/native_png_registry.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var failures: Array[String]=[]
var checks: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("PACK_CLOSED_FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for mid: String in ["albino_01","albino_02","escaros_01","escaros_02","escaros_03","escaros_04","escaros_05","faith_01","faith_02","faith_03","faith_04"]:
		check(PNG.supports(mid),"current protected map stays on native pack path: "+mid)
		var field: PlayableField=PNG.load_field(mid)
		check(field!=null,"real protected pack headers and SHA validate: "+mid)
		if field!=null:check(field.point_clear(Vector2(field.data.spawn_position[0],field.data.spawn_position[1]),4),"protected entry body clear: "+mid)
	var world: TwilightWorld=load("res://Main.tscn").instantiate();world.active_map_id="source_77";root.add_child(world)
	world.set_process(false);world.save_timer=-100000;world.portal_cooldown=10000;QA.enter_game(world)
	var current: PlayableField=world.field_map
	var old_extra: String=OS.get_environment("TWILIGHT_ADEN_FAITH_PNG_PACK")
	OS.set_environment("TWILIGHT_ADEN_FAITH_PNG_PACK","/workspace/map-main-tests/missing-public-pack")
	world._set_map("faith_01",false)
	check(world.active_map_id=="source_77" and world.field_map==current,"missing current pack cannot switch to authored old background")
	var folder: String=ProjectSettings.globalize_path("user://bad-map-pack")
	DirAccess.make_dir_recursive_absolute(folder)
	var f:=FileAccess.open(folder+"/index.json",FileAccess.WRITE);f.store_string("{}");f.close()
	OS.set_environment("TWILIGHT_ADEN_FAITH_PNG_PACK",folder)
	world._set_map("faith_01",false)
	check(world.active_map_id=="source_77" and world.field_map==current,"wrong manifest cannot switch to old background")
	var script: String=ProjectSettings.globalize_path("user://ordinary-legacy-arguments.gd")
	f=FileAccess.open(script,FileAccess.WRITE)
	f.store_string("extends SceneTree\nfunc _initialize():call_deferred('run')\nfunc run():\n var legacy=preload('res://scripts/maps/legacy_layout_policy.gd')\n var png=preload('res://scripts/maps/native_png_registry.gd')\n if legacy.active('--legacy-map-layouts') or legacy.active('--legacy-aden-faith-layouts') or legacy.active('--no-native-png-auto'):quit(1);return\n var world=load('res://Main.tscn').instantiate();world.active_map_id='faith_01';root.add_child(world)\n var ok=png.supports('faith_01') and png.load_field('faith_01')==null and world.field_map==null and world.source_save_blocked and world._save_game(true)!=OK\n world.queue_free();quit(0 if ok else 1)\n")
	f.close()
	var old_base: String=OS.get_environment("TWILIGHT_NATIVE_PNG_PACK")
	OS.set_environment("TWILIGHT_NATIVE_PNG_PACK",folder)
	var output: Array=[]
	var code: int=OS.execute(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script",script,"--","--legacy-map-layouts","--legacy-aden-faith-layouts","--no-native-png-auto"]),output,true)
	check(code==0,"ordinary external helper cannot force legacy; failed first pack blocks fresh save")
	for line: Variant in output:print(line)
	OS.set_environment("TWILIGHT_ADEN_FAITH_PNG_PACK",old_extra);OS.set_environment("TWILIGHT_NATIVE_PNG_PACK",old_base)
	world._set_map("faith_01",false)
	check(world.active_map_id=="faith_01" and world.field_map is NativePngField,"restored correct pack supports retry")
	print("MAP_PACK_FAIL_CLOSED_", "OK" if failures.is_empty() else "FAILED"," checks=",checks)
	world.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
