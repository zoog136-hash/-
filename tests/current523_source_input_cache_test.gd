extends SceneTree
## Actual externally pinned metadata can be shared; failed updates cannot evict it.
const CONTROLLER=preload("res://scripts/maps/current523_aden_play_controller.gd")
const RAW=preload("res://scripts/maps/current523_source_pack.gd")
const TILES=preload("res://scripts/maps/current523_tile_pack.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func arg(prefix: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(prefix):return a.trim_prefix(prefix)
	return ""
func _initialize() -> void:
	var controller:=CONTROLLER.new()
	var options: Dictionary={"raw_root":arg("--source-root="),"source_manifest_sha256":arg("--source-sha="),"tile_root":arg("--tile-root="),"tile_manifest_sha256":arg("--tile-sha=")}
	var actual: bool=not options.raw_root.is_empty()
	if actual:
		var source: RefCounted=controller._catalog_for(options)
		check(source!=null,"actual source catalog accepted")
		check(controller._catalog_for(options)==source and controller.input_cache_metrics().source_catalog_loads==1,"same immutable source catalog is parsed once")
		var tile: RefCounted=controller._tiles_for(options)
		check(tile!=null,"actual tile metadata accepted")
		check(controller._tiles_for(options)==tile and controller.input_cache_metrics().tile_catalog_loads==1,"same immutable tile metadata is parsed once")
		var bad: Dictionary=options.duplicate();bad.source_manifest_sha256="0".repeat(64);bad.tile_manifest_sha256="0".repeat(64)
		check(controller._catalog_for(bad)==null and controller.get("_cached_catalog")==source and source.catalog_identity().manifest_sha256==options.source_manifest_sha256,"bad source update retains old verified catalog but rejects the new request")
		check(controller._tiles_for(bad)==null and controller.get("_cached_tiles")==tile and tile.verified_identity().manifest_sha256==options.tile_manifest_sha256,"bad tile update retains old metadata but rejects the new request")
		for kind: String in ["source","tiles"]:
			var directory: String=ProjectSettings.globalize_path("user://metadata-only-"+kind)
			DirAccess.make_dir_recursive_absolute(directory)
			var name: String=RAW.MANIFEST_NAME if kind=="source" else TILES.MANIFEST_NAME
			var original: String=options.raw_root if kind=="source" else options.tile_root
			var copy:=FileAccess.open(directory.path_join(name),FileAccess.WRITE)
			copy.store_buffer(FileAccess.get_file_as_bytes(original.path_join(name)));copy.close()
			var requested: Dictionary=options.duplicate();requested["raw_root" if kind=="source" else "tile_root"]=directory
			var before: RefCounted=controller._catalog_for(requested) if kind=="source" else controller._tiles_for(requested)
			check(before!=null,"verified metadata-only copy for corruption guard; no terrain/art delivery claim: "+kind)
			copy=FileAccess.open(directory.path_join(name),FileAccess.READ_WRITE);copy.store_8(32);copy.close()
			var rejected: RefCounted=controller._catalog_for(requested) if kind=="source" else controller._tiles_for(requested)
			check(rejected==null and controller.get("_cached_catalog" if kind=="source" else "_cached_tiles")==before,"same-path changed metadata cannot reuse a cached acceptance: "+kind)
			DirAccess.remove_absolute(directory.path_join(name))
	else:
		options.raw_root="/missing/cache-source";options.tile_root="/missing/cache-tiles";options.source_manifest_sha256="0".repeat(64);options.tile_manifest_sha256="0".repeat(64)
		check(controller._catalog_for(options)==null and controller._tiles_for(options)==null,"missing metadata never creates a cache")
	print("CURRENT523_SOURCE_INPUT_CACHE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_metadata":actual,"map_play_verified":false}))
	quit(0 if failures.is_empty() else 1)
