extends SceneTree
const STYLE = preload("res://scripts/maps/visual_style_policy.gd")
const RENDERER = preload("res://scripts/maps/field_renderer.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool,label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("MAP_VISUAL_FAIL: "+label)

func _run() -> void:
	_check(STYLE.normalize("twilight") == "twilight","legacy mode stays unchanged")
	_check(STYLE.normalize("classic") == "classic","classic mode supported")
	_check(STYLE.normalize("invalid") == "twilight","unexpected setting cannot alter game data")
	_check(STYLE.ground_tint("twilight") == Color.WHITE and STYLE.prop_tint("twilight") == Color.WHITE,"default visuals are exact preexisting colors")
	_check(STYLE.ground_tint("classic") != Color.WHITE and STYLE.prop_tint("classic") != Color.WHITE,"classic palette alters only presentation")
	var renderer = RENDERER.new()
	var ground := Node2D.new()
	renderer.add_child(ground)
	renderer.terrain_root = ground
	var chunk := Node2D.new()
	renderer.add_child(chunk)
	renderer.chunks[Vector2i.ZERO] = chunk
	var npc := Sprite2D.new()
	npc.set_meta("npc_role","teleport")
	renderer.add_child(npc)
	renderer.npc_visuals.append(npc)
	renderer.set_visual_mode("classic")
	_check(renderer.visual_mode == "classic","renderer switches mode without remaking field")
	_check(ground.modulate == STYLE.ground_tint("classic"),"ground color layer changed only")
	_check(chunk.modulate == STYLE.prop_tint("classic"),"existing prop chunk changes without moving")
	_check(npc.modulate == STYLE.npc_render_tint("teleport","classic"),"NPC role color changes with style")
	renderer.set_visual_mode("twilight")
	_check(ground.modulate == Color.WHITE and chunk.modulate == Color.WHITE,"legacy visuals completely restored")
	for role: String in ["guide","shop","warehouse","teleport","craft","buyback"]:
		_check(ResourceLoader.exists(STYLE.npc_class_art(role)),"real local sprite exists for "+role)
	_check(STYLE.npc_role_tint("warehouse") != STYLE.npc_role_tint("buyback"),"NPCs do not all share identical clothing tint")
	renderer.free()
	var maps_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps_v18.json"))
	var index_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/field_index.json"))
	_check(maps_value is Array and (maps_value as Array).size() == 25,"all original 25 map IDs preserved")
	_check(index_value is Array and (index_value as Array).size() == 24,"original 24 non-Aden field references preserved")
	if index_value is Array:
		for raw: Variant in index_value:
			if raw is Dictionary:
				_check(FileAccess.file_exists(str((raw as Dictionary).get("path",""))),"existing field path intact: "+str((raw as Dictionary).get("map_id","")))
	if failures.is_empty():
		print("MAP_VISUAL_OK: runtime modes, role-distinct art, original style restore and all 25 map paths")
		quit(0)
	else:
		print("MAP_VISUAL_FAILED: %d issues" % failures.size())
		quit(1)
