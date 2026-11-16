extends SceneTree
## Original 523 map picture/name for current523 fields: the picture's world
## rectangle follows UIMapImageInfo (Ratio/BaseLoc/BasePixel) with the same OWN
## registration as the world-map click owner, the minimap draws it clipped to
## its area instead of the own S32 blocks, and names come from DescData_Korean.
const IMAGES = preload("res://scripts/maps/current523_map_images.gd")
const CLICK = preload("res://scripts/maps/current523_world_map_coordinates.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []

class FakeCoordinates extends RefCounted:
	var valid: bool = true
	var basis_x := Vector2(24, 12)
	var basis_y := Vector2(-24, 12)
	func components_to_world(source: Array) -> Vector2:
		var x: float = float(source[0]) - 32000.0
		var y: float = float(source[1]) - 32000.0
		return basis_x * x + basis_y * y
	func components_to_world_checked(source: Array) -> Vector2: return components_to_world(source)

class FakeField extends RefCounted:
	var coordinates := FakeCoordinates.new()
	var data: Dictionary = {"source_land_id": 4}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 20: failures.append(label)

func _initialize() -> void:
	var info: Dictionary = {"Ratio": 24.0, "BaseLocX": 33430, "BaseLocY": 32813, "BasePixelX": 1590, "BasePixelY": 790}
	var field := FakeField.new()
	var rect: Rect2 = IMAGES.world_rect(field.coordinates, info, Vector2(3200, 1974))
	var anchor: Vector2 = field.coordinates.components_to_world([33430.5, 32813.5])
	check(rect.size == Vector2(3200, 1974) * 24.0, "picture covers size * Ratio world units")
	check(rect.position + Vector2(1590, 790) * 24.0 == anchor, "BasePixel lands on the BaseLoc cell centre")
	# Same registration as the world-map click owner (pixel -> source cell).
	field.set_meta("current523_source_field", true)
	var pixel: Dictionary = {"native_texture_pixel_registration_complete": true, "pixel_space": "intrinsic_texture_top_left_x_right_y_down",
		"pixel_coordinate_convention": "continuous_edges_before_display_flips", "raw_pixel": Vector2(2000, 1000), "texture_size": Vector2(3200, 1974), "source_image_info": info}
	var projected: Dictionary = CLICK.project(field, pixel)
	var expected: Vector2 = rect.position + Vector2(2000, 1000) * 24.0
	check(projected.get("ok", false) and (projected.world_position as Vector2).distance_to(expected) < 0.01, "minimap picture and world-map click agree")
	check(not IMAGES.world_rect(field.coordinates, {"Ratio": 0.0, "BaseLocX": 1, "BaseLocY": 1, "BasePixelX": 1, "BasePixelY": 1}, Vector2(10, 10)).has_area(), "Ratio 0 has no placement")
	check(not IMAGES.minimap_image(RefCounted.new()).get("ok", true), "only current523 source fields")
	var minimap: String = FileAccess.get_file_as_string("res://scripts/maps/field_minimap.gd")
	check(minimap.contains("MAP_IMAGES.minimap_image(field)") and minimap.contains("draw_texture_rect_region(source_overview, shown, source)") and minimap.contains("overview_world_rect = owner.overview_world_rect"), "minimap draws the original picture by its rectangle (also in the raster copy)")
	var hud: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud.contains("_select_current_world_map()") and hud.contains("\"select_offered_world\""), "world map selects the current Land's offered World on open")
	# Map window copy: shrunk storage, original pixel size reported to the window.
	var adapter: String = FileAccess.get_file_as_string("res://scripts/maps/source523_map_image_adapter.gd")
	check(adapter.contains("MAP_IMAGES.window_texture(") and IMAGES.WINDOW_MAX_EDGE <= 2048, "map window uses the shrunk premultiplied copy")
	var small := Image.create_empty(1600, 987, false, Image.FORMAT_RGBA8)
	var copy := ImageTexture.create_from_image(small)
	copy.set_size_override(Vector2i(3200, 1974))
	check(copy.get_width() == 3200 and copy.get_height() == 1974 and copy.get_size() == Vector2(3200, 1974), "size override keeps original pixel geometry")
	check(not hud.contains("original_main_ui_status[\"world_map_selection\"]=view.call("), "HUD status keeps no texture reference")
	var evidence: String = "not_installed"
	if DEF.row_count("UIMapWorld") > 0:
		evidence = "installed"
		check(IMAGES.korean_name(4) == "아덴대륙" and IMAGES.korean_name(0) == "말하는 섬", "original Korean Land names")
		check(int(IMAGES.world_row(4).get("ID", -1)) == 5 and int(IMAGES.world_row(4).get("MapImageInfoID", -1)) == 19, "Aden World 5 -> W_aden image info 19")
		check(str(IMAGES.area_at(4, Vector2i(33465, 32658)).get("name", "")) == "기란 마을", "original zone name at a Giran cell")
	print("CURRENT523_MAP_IMAGES_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "original": evidence}))
	quit(0 if failures.is_empty() else 1)
