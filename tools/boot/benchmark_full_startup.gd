extends SceneTree
const LOADER_PATH = "res://scripts/boot/loading_screen.gd"
const PROFILE = preload("res://scripts/characters/save_profile.gd")
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
var failures: Array[String] = []
var phases: Dictionary = {}
var samples: Array = []
var started: int
var done: bool = false
var pass_done: bool = false
var pass_ok: bool = false
var last_percent: float = -1
var phase: String = ""
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, label: String) -> bool:
	if not ok: failures.append(label);printerr("FULLSTARTUP_FAIL ",label)
	return ok
func _progress(value: Dictionary) -> void:
	var percent: float = float(value.get("percent",0))
	_check(percent >= last_percent,"monotonic_"+phase)
	last_percent=percent
	samples.append({"phase":phase,"us":Time.get_ticks_usec()-started,"snapshot":value.duplicate(true)})
func _finished(ok: bool) -> void:
	pass_done=true;pass_ok=ok
func _attach(loader: Node, label: String) -> void:
	phase=label;pass_done=false;pass_ok=false;last_percent=-1
	loader.progress_changed.connect(_progress)
	loader.finished.connect(_finished)
func _wait_pass() -> bool:
	var begin: int=Time.get_ticks_msec()
	while not pass_done:
		if Time.get_ticks_msec()-begin>1200000:failures.append("loading_timeout_"+phase);return false
		await process_frame
	return _check(pass_ok and last_percent==100,"finished_"+phase)
func _run() -> void:
	started=Time.get_ticks_usec()
	if not _check(PROFILE.allows_roster(),"production_roster_gate"): _write();return
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("TWILIGHT_ENTRY_OPTIONS")))
	if not _check(value is Dictionary and OPTIONS.write(value)==OK,"production_options"): _write();return
	# Real Loading.tscn; only the explicitly requested headless route/title hooks differ.
	var loading: PackedScene=load("res://scenes/boot/Loading.tscn")
	var loader: Control=loading.instantiate()
	loader.destination="res://scenes/boot/Characters.tscn"
	loader.title_in_headless=true
	_attach(loader,"initial")
	root.add_child(loader);current_scene=loader
	if not await _wait_pass(): _write();return
	phases.initial_finished_us=Time.get_ticks_usec()-started
	while is_instance_valid(loader) and not loader.is_awaiting_title(): await process_frame
	if not _check(is_instance_valid(loader) and loader.is_awaiting_title(),"actual_title_shown"): _write();return
	var title_started: int=Time.get_ticks_usec()
	var event:=InputEventKey.new();event.pressed=true;event.keycode=KEY_ENTER
	loader._input(event)
	while get_first_node_in_group("twilight_loading")!=null:await process_frame
	phases.title_automatic_dispatch_us=Time.get_ticks_usec()-title_started
	phases.user_input_wait_us=0
	var lobby: Node=current_scene
	if not _check(lobby!=null and lobby.get_script().resource_path=="res://scripts/characters/character_lobby.gd" and not paused,"actual_lobby_unpaused"): _write();return
	if not _check(lobby._roster_ready() and str(lobby.catalog.problem).is_empty(),"actual_store_and_class_definitions"): _write();return
	phases.lobby_ready_us=Time.get_ticks_usec()-started
	var setup_started: int=Time.get_ticks_usec()
	var characters: Array=lobby.snapshot.get("characters",[])
	var id: String=""
	if characters.is_empty():
		if not _check(OS.get_environment("TWILIGHT_FULLSTARTUP_CONDITION")=="first","next_character_exists"): _write();return
		var created: Dictionary=lobby.store.create_character("시작측정기사",1,1,lobby.catalog)
		if not _check(created.get("ok",false),"official_character_creation"): _write();return
		id=str(created.id);lobby._show_roster()
	else: id=str(characters[0].id)
	phases.character_creation_setup_us=Time.get_ticks_usec()-setup_started
	var select: Button=lobby.find_child("Character_"+id,true,false)
	var enter: Button=lobby.find_child("EnterCharacter",true,false)
	if not _check(select!=null and enter!=null,"real_lobby_buttons"): _write();return
	var selection_started: int=Time.get_ticks_usec()
	select.pressed.emit()
	if not _check(lobby.selected_id==id and not enter.disabled,"official_selection"): _write();return
	enter.pressed.emit()
	while get_first_node_in_group("twilight_loading")==null:
		if Time.get_ticks_usec()-selection_started>10000000:failures.append("main_overlay_not_opened");_write();return
		await process_frame
	loader=get_first_node_in_group("twilight_loading")
	if not _check(loader.destination=="res://Main.tscn" and not loader.title_after_loading,"official_main_loading_route"): _write();return
	phases.selection_store_and_dispatch_us=Time.get_ticks_usec()-selection_started
	_attach(loader,"main")
	if not await _wait_pass():_write();return
	var world: Node=current_scene
	var readiness: Dictionary=world.loading_readiness() if world!=null and world.has_method("loading_readiness") else {}
	if not _check(readiness.get("ready",false) and not readiness.get("failed",true),"actual_main_readiness"): _write();return
	_check(world.current523_aden_play_active and not world.source_save_blocked and not world.map_bootstrap_blocked,"source_world_active_unblocked")
	phases.main_ready_us=Time.get_ticks_usec()-started
	phases.first_character_save_setup_us=0
	if OS.get_environment("TWILIGHT_FULLSTARTUP_CONDITION")=="first":
		var save_started: int=Time.get_ticks_usec()
		_check(world._save_game(true)==OK,"official_initial_character_save")
		phases.first_character_save_setup_us=Time.get_ticks_usec()-save_started
	_write()
func _write() -> void:
	if done:return
	done=true
	var record: Dictionary={"ok":failures.is_empty(),"failures":failures,"phases_us":phases,"samples":samples,"total_us":Time.get_ticks_usec()-started,"scope":"Actual Loading.tscn, zero-wait title input, production Characters store/buttons and Loading.open(Main) readiness. Existing locally selected source inputs; no download/install/GPU/Android claim."}
	var file:=FileAccess.open(OS.get_environment("TWILIGHT_ENTRY_RESULT"),FileAccess.WRITE)
	if file==null:printerr("FULLSTARTUP_FAIL result_write");quit(2);return
	file.store_string(JSON.stringify(record,"  "));file.close()
	print("FULLSTARTUP_RESULT ",JSON.stringify({"ok":record.ok,"failures":failures,"phases_us":phases}))
	await process_frame
	quit(0 if failures.is_empty() else 1)
