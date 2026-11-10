extends RefCounted
## First-run verification of the installed 523 pack's big lists (images,
## original UI, map members, tiles), done by the loading screen before the
## game scene loads.
##
## Each loader verifies its pinned manifest once and keeps the result in a
## device bake (current523_bake_cache.gd); that first verification needs a few
## hundred MB of temporary memory. Left to the game, it happened whenever a
## screen first asked, on top of everything already loaded (the UI pack at
## about 1.4 GB in use). Here it runs on a nearly empty heap and the freed
## memory is reused by the game afterwards. Later starts skip baked steps.
const IMAGE_PACK = preload("res://scripts/resources/source523_image_pack.gd")
const UI_PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
const SOURCE_PACK = preload("res://scripts/maps/current523_source_pack.gd")
const TILE_PACK = preload("res://scripts/maps/current523_tile_pack.gd")
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const BOOT_LOG = preload("res://scripts/boot/boot_progress_log.gd")

## [{"id", "label"}] for the selected packs that are not baked yet.
static func pending() -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var images: Dictionary = _pin("TWILIGHT_SOURCE523_IMAGES")
	if not images.is_empty() and not IMAGE_PACK.baked(images.sha): steps.append({"id":"images","label":"그림 목록","root":images.root,"sha":images.sha})
	var ui: Dictionary = _pin("TWILIGHT_SOURCE_UI")
	if not ui.is_empty() and not UI_PACK.baked(ui.sha): steps.append({"id":"ui","label":"원작 UI","root":ui.root,"sha":ui.sha})
	var maps: Dictionary = OPTIONS.read() if FileAccess.file_exists(OPTIONS.PATH) else {}
	if _usable(maps.get("raw_root"), maps.get("source_manifest_sha256")) and not SOURCE_PACK.baked(str(maps.source_manifest_sha256)):
		steps.append({"id":"maps","label":"지도 목록","root":str(maps.raw_root),"sha":str(maps.source_manifest_sha256)})
	if _usable(maps.get("tile_root"), maps.get("tile_manifest_sha256")) and not TILE_PACK.baked(str(maps.tile_manifest_sha256)):
		steps.append({"id":"tiles","label":"타일 목록","root":str(maps.tile_root),"sha":str(maps.tile_manifest_sha256)})
	return steps

## Verifies and bakes one step; the loader instance is discarded. A failure is
## only recorded: the game reports it where the pack is used, as before.
static func run(step: Dictionary) -> bool:
	var started: int = BOOT_LOG.begin("prebake_" + str(step.id))
	var ok: bool = false
	match str(step.id):
		"images": ok = bool(IMAGE_PACK.open(str(step.root), str(step.sha)).get("ok", false))
		"ui": ok = bool(UI_PACK.new().open(str(step.root), str(step.sha)).get("ok", false))
		"maps": ok = SOURCE_PACK.new().load_catalog(str(step.root), str(step.sha))
		"tiles": ok = TILE_PACK.new().load_pack(str(step.root), str(step.sha))
	BOOT_LOG.end("prebake_" + str(step.id), started, {"ok": ok})
	return ok

static func _pin(variable: String) -> Dictionary:
	var root: String = OS.get_environment(variable)
	var sha: String = OS.get_environment(variable + "_SHA256").to_lower()
	return {"root":root,"sha":sha} if _usable(root, sha) else {}

static func _usable(root: Variant, sha: Variant) -> bool:
	return root is String and not (root as String).is_empty() and sha is String and (sha as String).length() == 64
