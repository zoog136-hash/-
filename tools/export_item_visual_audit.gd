extends SceneTree

const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _rows(records: Array, images: Dictionary) -> Array:
	var rows: Array = []
	for index: int in range(records.size()):
		var record: Dictionary = records[index]
		var before: String = JSON.stringify(record)
		var name_value: String = str(record.get("name",""))
		var info: Dictionary = RESOLVER.describe(record,name_value,images)
		var texture: Texture2D = RESOLVER.texture(record,name_value,images)
		var row: Dictionary = {"row":index,"sourceId":record.get("sourceId",""),"name":name_value,
			"grade":record.get("grade","일반"),"type":record.get("type",""),"slot":record.get("slot",""),
			"pinned_path":record.get("image_path",""),"source_url":record.get("sourceUrl",""),
			"source_image_url":record.get("sourceImageUrl",""),"resolution":info,
			"loaded":texture!=null,"size":[texture.get_width(),texture.get_height()] if texture!=null else []}
		if texture == null: failures.append("missing texture: "+name_value)
		if before != JSON.stringify(record): failures.append("record mutated: "+name_value)
		rows.append(row)
	return rows

func _run() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	var images: Dictionary = world.catalog_image_index.get("아이템",{})
	var result: Dictionary = {"engine":Engine.get_version_info().string,"rendering_method":RenderingServer.get_current_rendering_method(),
		"catalog":_rows(raw.get("아이템",[]),images),"legacy":_rows(legacy.get("아이템",[]),images),
		"runtime":_rows(world.catalog_db.get("아이템",[]),images),"failures":failures,
		"texture_cache_size":RESOLVER.cache_size()}
	var output: String = OS.get_environment("TWILIGHT_ITEM_AUDIT")
	if output.is_empty(): output = "user://item-visual-runtime.json"
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: failures.append("cannot write audit "+output)
	else:
		file.store_string(JSON.stringify(result,"\t"))
		file.close()
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("ITEM_VISUAL_AUDIT_OK catalog=%d legacy=%d runtime=%d" % [result.catalog.size(),result.legacy.size(),result.runtime.size()])
	else: print("ITEM_VISUAL_AUDIT_FAILED ",failures)
	quit(0 if failures.is_empty() else 1)
