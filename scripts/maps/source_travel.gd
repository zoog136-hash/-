extends RefCounted
## Validate exact original coordinates before changing active map or consuming items.
const FIELD = preload("res://scripts/maps/source_field.gd")
static func read_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return {}
	return parser.data

static func catalog_entries(path: String = "res://data/original_maps/catalog.json") -> Array:
	var catalog: Dictionary = read_object(path)
	var result: Array = []
	if int(catalog.get("schema",0)) != 2 or not catalog.get("maps") is Array: return result
	for raw: Variant in catalog.maps:
		if not raw is Dictionary: continue
		var record: Dictionary = raw
		if not str(record.get("id","")).begins_with("l1_"): continue
		if not str(record.get("source_definition","")).begins_with("res://data/original_maps/definitions/"): continue
		if bool(record.get("playable",false)): result.append(record)
	return result

static func load_field(record: Dictionary) -> OriginalPlayableField:
	var path: String = str(record.get("source_definition",""))
	if path.is_empty() or not FileAccess.file_exists(path): return null
	var raw: Dictionary = read_object(path)
	if raw.is_empty() or str(raw.get("map_id","")) != str(record.get("id","")): return null
	if int(raw.get("schema",0)) != 2 or not raw.get("navigation") is Dictionary: return null
	for key: String in ["origin","dimensions","spawn_source"]:
		if not raw.get(key) is Array or raw[key].size()!=2: return null
	for key: String in ["npc_spawns","monster_spawns","portals","terrain_chunks"]:
		if not raw.get(key) is Array: return null
	if not raw.navigation.get("chunks") is Array: return null
	var field: OriginalPlayableField = FIELD.new()
	if not field.configure_source(raw): field.close(); return null
	return field

static func enter(world: Node, map_id: String, source_position: Vector2) -> bool:
	if not source_position.is_finite() or not world.maps_by_id.has(map_id): return false
	var preview: OriginalPlayableField = load_field(world.maps_by_id[map_id])
	if preview == null: return false
	var destination: Vector2 = preview.coordinates.to_world(source_position)
	var valid: bool = preview.walkable(destination)
	preview.close()
	if not valid:
		world.hud.show_message("원본 목적지 통행 불가 · 좌표를 임의 변경하지 않았습니다")
		return false
	if world.active_map_id != map_id: world._set_map(map_id,false)
	if world.active_map_id != map_id: return false
	if is_instance_valid(world.world_interactions): world.world_interactions.clear_selection()
	world.player.clear_click_path()
	world.player.velocity = Vector2.ZERO
	world.player.set_touch_vector(Vector2.ZERO)
	world.player.global_position = destination
	world.selected_monster = null
	world.auto_target = null
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.portal_cooldown = 2.0
	world.field_renderer.refresh_visible()
	world.hud.show_message(str(world.active_map.name)+" · 원본 좌표 이동")
	return true

static func return_home(world: Node) -> bool:
	if not (world.field_map is OriginalPlayableField): return false
	var field: OriginalPlayableField = world.field_map
	if not bool(field.definition.rules.get("escapable",0)): return false
	var p: Vector2 = field.coordinates.to_source(world.player.global_position)
	for row: Dictionary in field.definition.getback:
		if not bool(row.scrollescape): continue
		if int(row.area_x1) != 0 and (p.x < int(row.area_x1) or p.x >= int(row.area_x2)+1 or p.y < int(row.area_y1) or p.y >= int(row.area_y2)+1): continue
		for i: int in range(1,4):
			if enter(world,"l1_%d" % int(row.getback_mapid),Vector2(float(row["getback_x%d" % i]),float(row["getback_y%d" % i]))): return true
	world.hud.show_message("검증된 원본 귀환 목적지가 없습니다")
	return false

static func snapshot(world: Node) -> Dictionary:
	if not (world.field_map is OriginalPlayableField): return {}
	var field: OriginalPlayableField = world.field_map
	return {"source_map_id":field.definition.source_map_id,"source":field.coordinates.source_components(world.player.global_position),"grid_sha256":field.definition.source_sha256}

static func restore_position(world: Node, record: Dictionary) -> Array:
	var field: OriginalPlayableField = world.field_map
	if int(record.get("source_map_id",-1)) != int(field.definition.source_map_id) or str(record.get("grid_sha256","")) != str(field.definition.source_sha256): return []
	var source: Array = record.get("source",[])
	if source.size() != 2: return []
	var p: Vector2 = field.coordinates.components_to_world(source)
	return [p.x,p.y] if p.is_finite() and field.walkable(p) else []
