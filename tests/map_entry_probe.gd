extends SceneTree
const PNG=preload("res://scripts/maps/native_png_registry.gd")
const FIELD=preload("res://scripts/maps/native_png_field.gd")
const QA=preload("res://tests/qa_class_selection.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world);world.set_process(false);world.save_timer=-100000
	var rows: Array=[]
	for mid: String in ["aden_world","escaros_01"]:
		var start: int=Time.get_ticks_usec();world._set_map(mid,false)
		var total_ms: float=(Time.get_ticks_usec()-start)/1000.0
		var field: NativePngField=world.field_map
		world.field_population.set_process(false)
		for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
		var actual_mid: String=PNG.map_for_art(mid)
		start=Time.get_ticks_usec();var second: PlayableField=PNG.load_field(mid)
		var verified_field_ms: float=(Time.get_ticks_usec()-start)/1000.0
		var plan: Dictionary=PNG.plan()
		start=Time.get_ticks_usec();var direct: NativePngField=FIELD.new();direct.configure_png(actual_mid,plan,field.png_manifest,field.png_root)
		var configure_ms: float=(Time.get_ticks_usec()-start)/1000.0
		start=Time.get_ticks_usec();var body: StaticBody2D=direct.build_physics(world)
		var physics_ms: float=(Time.get_ticks_usec()-start)/1000.0
		var shapes: int=body.get_child_count();body.get_parent().remove_child(body);body.free()
		world.field_population.configure(world,null);world._clear_monsters()
		start=Time.get_ticks_usec();world.field_population.configure(world,field)
		var population_ms: float=(Time.get_ticks_usec()-start)/1000.0
		rows.append({"map":mid,"set_map_ms":total_ms,"verified_field_ms":verified_field_ms,"configure_geometry_ms":configure_ms,"physics_build_ms":physics_ms,"physics_shapes":shapes,"population_ms":population_ms,"cells":field.width*field.height,"slots":world.field_population.slots.size(),"materialized":world.monsters_root.get_child_count()})
		print("MAP_ENTRY ",JSON.stringify(rows.back()))
	var file:=FileAccess.open(OS.get_environment("MAP_ENTRY_OUTPUT"),FileAccess.WRITE);file.store_string(JSON.stringify(rows,"  "));file.close()
	world.queue_free();await process_frame;quit()
