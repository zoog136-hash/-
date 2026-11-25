extends SceneTree
## Open original feature windows on a disposable character. Records actual
## mounted callbacks, including inert and untouchable controls. No button is
## pressed and no purchase, claim or enhancement is performed by this audit.
const QA = preload("res://tests/qa_class_selection.gd")
var output: FileAccess
var buttons := {}
var pack: RefCounted

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or FileAccess.file_exists("user://twilight_v20_save.json") or OS.get_environment("TWILIGHT_SOURCE_UI_SHA256").is_empty():
		printerr("Provide a fresh user directory, selected original UI and private JSONL output path")
		quit(1)
		return
	output = FileAccess.open(args[0],FileAccess.WRITE)
	if output==null:
		quit(2)
		return
	root.size=Vector2i(2048,919)
	var world: Node=load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	world.set_process(false)
	world.save_timer=-100000
	if not QA.enter_game(world):
		quit(3)
		return
	await process_frame
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	var hud: Node=world.hud
	var controller: Node=hud.original_main_ui_controller
	pack=controller._pack
	if pack==null or pack.manifest_sha256!=OS.get_environment("TWILIGHT_SOURCE_UI_SHA256"):
		quit(4)
		return
	record_buttons(controller._coordinates,"field")
	hud.toggle_inventory()
	await process_frame
	record_buttons(controller._coordinates,"inventory")
	hud.toggle_inventory()
	var optional := {"card_collection":["변신"],"card_fusion":["변신"]}
	var results := {}
	for key: String in controller.FEATURE_WINDOWS:
		var script: Script=controller.FEATURE_WINDOWS[key]
		var arguments: Array=optional.get(key,[])
		var required := 0
		for method: Dictionary in script.get_script_method_list():
			if method.name=="open":required=method.args.size()-method.default_args.size()-1
		if required>arguments.size():
			results[key]="needs contextual entry"
			continue
		var result: Dictionary=controller.try_open_feature_window(key,arguments)
		results[key]="opened" if result.get("handled",false) else str(result.get("code",result.get("error","unavailable")))
		if result.get("handled",false):
			await process_frame
			record_buttons(controller.feature_window(key)._scene,key)
			controller.feature_window(key).close()
			await process_frame
	for values: Dictionary in buttons.values(): output.store_line(JSON.stringify(values))
	output.close()
	print("UI_BUTTON_RESULT ",JSON.stringify({"distinct_button_nodes":buttons.size(),"first_screen":results}))
	world.queue_free()
	await process_frame
	quit()

func record_buttons(node: Node, screen: String) -> void:
	if node==null or node.is_queued_for_deletion():return
	var identity: Variant=node.get_meta("original_ui_source",{})
	var button: Variant=node.get_meta("source_button") if node.has_meta("source_button") else (node.get_meta("source_checkbox") if node.has_meta("source_checkbox") else null)
	if is_instance_valid(button) and identity is Dictionary and identity.has("node_offset"):
		var member: String=identity.scene
		var key: String=member+"#"+str(identity.node_offset)
		var row: Dictionary=buttons.get(key,{"member":member,"offset":identity.node_offset,"sha256":pack.manifest.files[member].sha256,"actions":{}})
		var callback: Callable=button._activation
		var method: String=str(callback.get_method()) if callback.is_valid() else ""
		var owner: Object=callback.get_object() if callback.is_valid() else null
		var script: Script=owner.get_script() if owner!=null else null
		var route: String=screen+"|"+(script.resource_path.get_file() if script!=null else "")+"|"+method
		row.actions[route]=bool(row.actions.get(route,false)) or button._input_available()
		buttons[key]=row
	for child: Node in node.get_children():record_buttons(child,screen)
