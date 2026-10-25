extends "res://scripts/world.gd"
var texture_costs: Array=[]
var map_costs: Array=[]
func _monster_texture(record: Dictionary) -> Texture2D:
	var start: int=Time.get_ticks_usec()
	var result: Texture2D=super._monster_texture(record)
	texture_costs.append({"name":str(record.name),"us":Time.get_ticks_usec()-start})
	return result
func _set_map(map_id: String,keep_position: bool) -> void:
	var start: int=Time.get_ticks_usec()
	super._set_map(map_id,keep_position)
	map_costs.append({"requested":map_id,"active":active_map_id,"us":Time.get_ticks_usec()-start})
func _setup_field_services() -> void:
	y_sort_enabled = true
	monsters_root.y_sort_enabled = true
	monsters_root.z_index = 0
	player.z_index = 0
	$Companion.z_index = 0
	field_population = preload("res://tests/qa_population_entry_meter.gd").new()
	field_population.name = "FieldPopulation"
	add_child(field_population)
	field_population.set_process(false)
	legacy_population = field_population
	original_population = SOURCE_POPULATION.new()
	original_population.name = "OriginalSourcePopulation"
	add_child(original_population)
	original_population.set_process(false)
	field_minimap = FIELD_MINIMAP.new()
	field_minimap.name = "FieldMinimap"
	hud.get_node("Root").add_child(field_minimap)
	field_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	field_minimap.offset_left = -238
	field_minimap.offset_right = -16
	field_minimap.offset_top = 100
	field_minimap.offset_bottom = 291
	field_minimap.z_index = 36

var profile_world_paths: bool=OS.get_environment("TWILIGHT_WORLD_PATH_PROFILE")=="1"
var path_costs: Array=[]
func find_world_path(from_position: Vector2,to_position: Vector2) -> PackedVector2Array:
	if not profile_world_paths:return super.find_world_path(from_position,to_position)
	var graph_before: bool=field_map is NativePngField and field_map.precise_routes!=null
	var failure_hit: bool=graph_before and field_map.precise_routes.has_failed_route(from_position,to_position)
	var begin: int=Time.get_ticks_usec()
	var result: PackedVector2Array=super.find_world_path(from_position,to_position)
	var elapsed: int=Time.get_ticks_usec()-begin
	path_costs.append({"from":[from_position.x,from_position.y],"to":[to_position.x,to_position.y],"us":elapsed,"physics_frame":Engine.get_physics_frames(),"graph_before":graph_before,"graph_after":field_map is NativePngField and field_map.precise_routes!=null,"exact_failure_cache_hit":failure_hit,"points":result.size(),"result":result})
	return result

var physics_profile_script: Script
var physics_profile_installed: int=0
var physics_profile_mismatches: Array=[]
var constrain_costs: Array=[]
func install_physics_profile() -> void:
	physics_profile_script=load("res://tests/qa_first_physics_monster.gd")
	for actor: Node in monsters_root.get_children():install_actor_physics_profile(actor)
func install_actor_physics_profile(actor: Node) -> void:
	if physics_profile_script==null or not actor is TwilightMonster or actor.get_script()==physics_profile_script:return
	var saved: Dictionary={}
	for property: Dictionary in actor.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:saved[property.name]=actor.get(property.name)
	var identity: int=actor.get_instance_id()
	actor.set_script(physics_profile_script)
	for key: String in saved:actor.set(key,saved[key])
	for key: String in saved:
		if actor.get(key)!=saved[key]:physics_profile_mismatches.append({"actor":identity,"property":key})
	physics_profile_installed+=1
func constrain_original_motion(actor: CharacterBody2D) -> void:
	if physics_profile_script==null:super.constrain_original_motion(actor);return
	var begin: int=Time.get_ticks_usec();super.constrain_original_motion(actor)
	constrain_costs.append({"actor_id":actor.get_instance_id(),"us":Time.get_ticks_usec()-begin,"physics_frame":Engine.get_physics_frames(),"monster":actor is TwilightMonster})
func physics_profile_totals() -> Dictionary:
	var totals: Dictionary={"physics_us":0,"physics_calls":0,"ai_us":0,"ai_calls":0,"move_us":0,"move_calls":0}
	for actor: Node in monsters_root.get_children():
		if actor.get_script()!=physics_profile_script:continue
		for key: String in totals:totals[key]+=int(actor.get("profile_"+key))
	return totals

var frame_stage_profile: bool=OS.get_environment("TWILIGHT_FRAME_STAGE_PROFILE")=="1"
var world_process_us: int=0
func _process(delta: float) -> void:
	if not frame_stage_profile:super._process(delta);return
	var begin: int=Time.get_ticks_usec()
	super._process(delta)
	world_process_us+=Time.get_ticks_usec()-begin
