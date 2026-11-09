extends RefCounted
## With the 523 resource pack installed, the starting world "aden_world" is the
## original 523 Aden itself (native Land 4, S32 terrain and tiles) instead of
## the retired source84 picture pack. The existing 523 play mode then opens on
## top of it exactly as it did over the old picture, so travel, population,
## portals, map time and saving keep their current owners.
##
## The host never needs the old pack: with it removed, aden_world still loads,
## saves and restores. Without a configured 523 pack nothing changes.
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const FIELD = preload("res://scripts/maps/current523_source_field.gd")
const RENDERER = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const MAP_ID := "aden_world"
const ADEN_LAND := 4
const META := "current523_host"
static var _stamp: String = ""
static var _requested: bool = false
static var _failed: bool = false
static var problem: String = ""

## The current 523 map selection, read from the play settings file.
static func options() -> Dictionary:
	return OPTIONS.read()

## True when a complete 523 map/tile selection is configured (the resource
## pack installer writes it). Cached on the settings file's time and size:
## save validation asks this for every referenced map.
static func requested() -> bool:
	if _failed: return false
	var stamp: String = ""
	if FileAccess.file_exists(OPTIONS.PATH): stamp = "%d:%d" % [FileAccess.get_modified_time(OPTIONS.PATH), FileAccess.get_size(OPTIONS.PATH)]
	if stamp == _stamp: return _requested
	_stamp = stamp
	var value: Dictionary = OPTIONS.read() if not stamp.is_empty() else {}
	# The selected packs must exist: a remembered selection whose folders are
	# gone (or a test fixture) keeps the old Aden.
	_requested = not value.is_empty() and value.get("navigation_profile") == OPTIONS.GENERIC \
		and str(value.get("source_manifest_sha256", "")).length() == 64 and str(value.get("tile_manifest_sha256", "")).length() == 64 \
		and not str(value.get("raw_root", "")).is_empty() and FileAccess.file_exists(str(value.raw_root).path_join("source523.json")) \
		and not str(value.get("tile_root", "")).is_empty() and FileAccess.file_exists(str(value.tile_root).path_join("tilepack523.json"))
	return _requested

## The 523 selection did not open: use the old Aden for the rest of this run.
static func fail_session() -> void:
	_failed = true

## Forget the cached answer (tests and a newly installed pack).
static func refresh() -> void:
	_stamp = "-"
	_failed = false

static func is_host(field: Variant) -> bool:
	return field is Object and is_instance_valid(field) and (field as Object).has_meta(META) and bool((field as Object).get_meta(META))

static func _interpretation(value: Dictionary) -> Dictionary:
	return {"attribute_rule":str(value.get("attribute_rule","client523_attr_bit0")),"allowed_raw_words":value.get("allowed_raw_words",OPTIONS.SOURCE_WORDS.duplicate()),"path_search_limit":value.get("path_search_limit",8192),"aden_inferred_placement_enabled":value.get("aden_inferred_placement_enabled",true)}

## The 523 Aden field with its spawn at the existing own Aden return point.
## `controller` supplies its verified catalog cache (shared with play mode).
static func load_field(controller: RefCounted) -> OriginalPlayableField:
	problem = ""
	var value: Dictionary = options()
	if not requested(): problem = "523 지도 설정이 없습니다."; return null
	var catalog: RefCounted = controller.call("_catalog_for", value)
	if catalog == null: problem = "523 지도 카탈로그를 확인하지 못했습니다: " + str(controller.get("problem")); return null
	var field: OriginalPlayableField = FIELD.new()
	if not field.configure_verified_catalog(catalog, str(value.source_manifest_sha256), ADEN_LAND, _interpretation(value)):
		problem = str(field.problem); field.close(); return null
	var landing: Dictionary = controller.call("_aden_return_point", field, int(value.get("aden_return_radius", 8)))
	if not landing.get("ok", false):
		problem = str(landing.get("reason", "아덴 시작 위치가 없습니다.")); field.close(); return null
	field.data.spawn_position = [landing.position.x, landing.position.y]
	field.set_meta(META, true)
	return field

## A configured renderer for `field`, already a child of `world`. The player
## must already stand at its position on the field.
static func make_renderer(world: Node, controller: RefCounted, field: OriginalPlayableField) -> FieldRenderer:
	problem = ""
	var value: Dictionary = options()
	var tiles: RefCounted = controller.call("_tiles_for", value)
	if tiles == null: problem = "523 타일 팩을 확인하지 못했습니다: " + str(controller.get("problem")); return null
	var renderer = RENDERER.new()
	renderer.name = "FieldRenderer"
	world.add_child(renderer)
	if not renderer.try_configure(field, world.get("player"), str(value.raw_root), str(value.tile_root), Vector2(int(value.get("offset_x", 0)), int(value.get("offset_y", 0))), str(value.tile_manifest_sha256), controller.call("_catalog_for", value), tiles):
		problem = str(renderer.problem)
		world.remove_child(renderer)
		renderer.queue_free()
		return null
	return renderer
