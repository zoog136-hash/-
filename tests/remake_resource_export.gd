extends SceneTree

# Read-only registry/load audit. It never adds the world to the tree, boots a
# scene, writes a save, installs a source pack, or claims a visual playtest.
const WORLD = preload("res://scripts/world.gd")
const VISUALS = preload("res://scripts/animation/visual_manifest.gd")
const ANIMATION = preload("res://scripts/animation/animation_catalog.gd")
const EXTERNAL = preload("res://addons/twilight_l1j/twilight_runtime_assets.gd")
const A2 = preload("res://addons/twilight_l1j/twilight_external_a2_bridge.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")

func _initialize() -> void:
	call_deferred("_run")

func _texture_info(texture: Texture2D) -> Dictionary:
	if texture == null: return {"loaded":false, "path":""}
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		if atlas.atlas == null: return {"loaded":false, "path":""}
		return {"loaded":true, "path":atlas.atlas.resource_path, "region":[atlas.region.position.x, atlas.region.position.y, atlas.region.size.x, atlas.region.size.y]}
	return {"loaded":true, "path":texture.resource_path, "size":[texture.get_width(), texture.get_height()]}

func _pixel_digest(texture: Texture2D) -> String:
	if texture == null: return ""
	var pixels: Image = texture.get_image()
	if pixels == null: return ""
	pixels.convert(Image.FORMAT_RGBA8)
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(str(pixels.get_size()).to_utf8_buffer())
	hashing.update(pixels.get_data())
	return hashing.finish().hex_encode()

func _item(record: Dictionary, images: Dictionary) -> Dictionary:
	var name_value: String = str(record.get("name", ""))
	var result: Dictionary = {"name":name_value,"sourceId":record.get("sourceId", ""),"image_path":record.get("image_path", ""),"sourceUrl":record.get("sourceUrl", ""),"slot":record.get("slot", ""),"grade":record.get("grade", "")}
	# The optional unified resolver supersedes the historical UI precedence.
	# Its identity review status is evidence, never an original-delivery claim.
	if FileAccess.file_exists("res://scripts/ui/item_visual_resolver.gd"):
		var resolver = load("res://scripts/ui/item_visual_resolver.gd")
		var description: Dictionary = resolver.describe(record, name_value, images)
		var resolved_texture: Texture2D = resolver.texture(record, name_value, images)
		result["icon"] = _texture_info(resolved_texture)
		result.icon["path"] = description.path if not str(description.path).is_empty() else "res://scripts/ui/item_fallback_art.gd"
		result.icon["selection"] = description.route
		result.icon["rgba_sha256"] = _pixel_digest(resolved_texture)
		result["resolver_description"] = description
		var ground_description: Dictionary = resolver.describe(record, name_value, images, true)
		var ground_texture: Texture2D = resolver.texture(record, name_value, images, true)
		result["ground_icon"] = _texture_info(ground_texture)
		result.ground_icon["path"] = ground_description.path if not str(ground_description.path).is_empty() else "res://scripts/ui/item_fallback_art.gd"
		result.ground_icon["rgba_sha256"] = _pixel_digest(ground_texture)
		result["ground_resolver_description"] = ground_description
		result["manifest_binding"] = VISUALS.item_binding(record, name_value)
		return result
	var texture: Texture2D = EXTERNAL.item_icon(record, name_value)
	var selected: String = "external_runtime"
	if texture == null:
		texture = VISUALS.item_icon(record, name_value)
		selected = "reviewed_manifest"
	if texture == null:
		texture = A2.item_icon(record, name_value)
		selected = "external_a2"
	var path: String = str(record.get("image_path", ""))
	if path.is_empty(): path = str(images.get(name_value, ""))
	if texture == null and not path.is_empty() and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
		selected = "catalog_image"
	if texture == null:
		path = str(images.get(name_value, record.get("image_path", "")))
		if not path.is_empty() and ResourceLoader.exists(path):
			texture = load(path) as Texture2D
			selected = "name_index"
	if texture == null:
		texture = UI.item_icon(record, name_value, images)
		selected = "shared_ui_fallback"
	result["icon"] = _texture_info(texture)
	result["icon"]["selection"] = selected
	result.icon["rgba_sha256"] = _pixel_digest(texture)
	result["manifest_binding"] = VISUALS.item_binding(record, name_value)
	return result

func _profile(kind: String, record: Dictionary, path: String) -> Dictionary:
	var profile = ANIMATION.for_record(kind, record, path)
	var frames: SpriteFrames = ANIMATION.frames_for_profile(profile, path)
	return {"id":profile.profile_id,"layout":profile.layout,"frames_path":profile.frames_path,"loaded":ANIMATION.first_texture(frames) != null,"motion_style":profile.motion_style,"attack_hit_ratio":profile.attack_hit_ratio,"attack_hit_frame":profile.attack_hit_frame,"movement_fps":profile.movement_fps}

func _asset_paths(value: Variant, result: Dictionary) -> void:
	if value is Dictionary:
		for child: Variant in value.values(): _asset_paths(child, result)
	elif value is Array:
		for child: Variant in value: _asset_paths(child, result)
	elif value is String and str(value).begins_with("res://assets/"):
		result[str(value)] = true

func _run() -> void:
	if not ResourceLoader.exists("res://assets/ui/attack.png"):
		printerr("REMAKE_RESOURCE_EXPORT_BLOCKED: run the Godot editor import first")
		quit(2)
		return
	var world = WORLD.new()
	world._load_data()
	var output: Dictionary = {"schema":1,"engine":Engine.get_version_info().string,"classes":world.job_classes,"catalog":{},"legacy_items":[],"monsters":[],"maps":[],"source_maps":world.original_maps,"effects":[]}
	var images: Dictionary = world.catalog_image_index.get("아이템", {})
	for category: String in ["변신", "마법인형", "성물", "아이템"]:
		var entries: Array = []
		for record: Dictionary in world.catalog_db.get(category, []):
			if category == "아이템":
				entries.append(_item(record, images))
			else:
				var kind: String = {"변신":"transform","마법인형":"doll","성물":"relic"}[category]
				entries.append({"name":record.name,"sourceId":record.get("sourceId", ""),"image_path":record.get("image_path", ""),"sourceUrl":record.get("sourceUrl", ""),"profile":_profile(kind, record, str(record.get("image_path", "")))})
		output.catalog[category] = entries
	for record: Dictionary in world.item_db: output.legacy_items.append(_item(record, images))
	for record: Dictionary in world.monster_db:
		var texture: Texture2D = world._monster_texture(record)
		output.monsters.append({"name":record.name,"is_boss":world.LOOT_DROP.is_boss_record(record),"sourceId":record.get("sourceId", ""),"visual":record.get("visual", {}),"texture":_texture_info(texture),"manifest_binding":VISUALS.monster_binding(record),"profile":_profile("monster", record, ""),"special":record.get("special", {})})
	for record: Dictionary in world.maps:
		var definition: Dictionary = record.get("field_definition", {})
		var path: String = str(record.get("field_path", ""))
		if definition.is_empty() and FileAccess.file_exists(path):
			definition = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
		if not definition.is_empty(): definition = world.MONSTER_CATALOG.apply_map(definition)
		var paths: Dictionary = {}
		_asset_paths(definition, paths)
		var asset_loads: Dictionary = {}
		for asset_path: String in paths:
			asset_loads[asset_path] = ResourceLoader.exists(asset_path) and load(asset_path) != null
		output.maps.append({"id":record.id,"name":record.name,"definition_path":path,"loaded":not definition.is_empty(),"spawns":definition.get("monster_spawn", []),"asset_paths":paths.keys(),"asset_loads":asset_loads})
	for record: Dictionary in world.skills_db:
		output.effects.append({"id":record.id,"name":record.name,"class":record.get("class", ""),"icon":record.get("icon", ""),"runtime_effect":record.get("runtime_effect", "UNKNOWN"),"mode":record.get("mode", "")})
	var destination: String = OS.get_environment("TWILIGHT_RESOURCE_EXPORT")
	if destination.is_empty():
		printerr("Set TWILIGHT_RESOURCE_EXPORT to an output JSON path")
		world.free()
		quit(2)
		return
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write resource export: ", destination)
		world.free()
		quit(2)
		return
	file.store_string(JSON.stringify(output, "\t", true))
	file.close()
	print("REMAKE_RESOURCE_EXPORT_OK classes=", output.classes.size(), " items=", output.catalog["아이템"].size(), " monsters=", output.monsters.size(), " maps=", output.maps.size(), " effects=", output.effects.size())
	world.free()
	quit(0)
