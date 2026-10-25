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
