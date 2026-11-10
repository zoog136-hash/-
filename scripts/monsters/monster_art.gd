extends RefCounted
class_name TwilightMonsterArt

## Original family silhouettes, cached cropped atlas views, and species-specific
## proportions/gear. This is procedural directional art, not eight authored views.
const SHADER = preload("res://scripts/monsters/monster_body.gdshader")
const LRU = preload("res://scripts/resources/bounded_weak_lru.gd")
## Strong reserve of atlas plates (a 1254x1254 RGBA plate is ~6 MB). Plates a
## live monster still shows stay reachable through the weak side, so the same
## instance is returned; only this cache's own references are dropped.
const PLATE_RESERVE: int = 2
static var atlases: Array = []
## Cropped AtlasTexture views: weak only (cheap to rebuild, and a strong view
## would pin its whole plate). A rebuilt view has the same atlas and region.
static var textures: RefCounted = LRU.new(0)
static var plates: RefCounted = LRU.new(PLATE_RESERVE)

static func texture_for(record: Dictionary) -> Texture2D:
	# Explicit reviewed source portrait; animation setup replaces it with the
	# matching frame resource. No family/template/name heuristic is involved.
	var portrait: String = str(record.get("source_portrait", ""))
	var source_id: String = str(record.get("sourceId", ""))
	if not source_id.is_empty() and portrait == "res://assets/monsters/reviewed_source/" + source_id + "/portrait.png":
		return load(portrait) as Texture2D
	var reviewed: Texture2D = preload("res://scripts/monsters/reviewed_existing_visuals.gd").portrait(record)
	if reviewed != null: return reviewed
	var family: Texture2D = preload("res://scripts/animation/visual_manifest.gd").monster_texture(record)
	if family != null: return family
	var external: Texture2D = preload("res://addons/twilight_l1j/twilight_runtime_assets.gd").monster_texture(record)
	if external != null: return external
	var from_a2: Texture2D = preload("res://addons/twilight_l1j/twilight_external_a2_bridge.gd").monster_texture(record)
	if from_a2 != null: return from_a2
	if not record.has("visual"): return null
	if atlases.is_empty():
		atlases = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters/art_atlases.json")) as Array
	var visual: Dictionary = record.visual
	var atlas: int = int(visual.atlas)
	var cell: int = int(visual.cell)
	var key: String = "%d:%d" % [atlas,cell]
	var known: Texture2D = textures.lookup(key) as Texture2D
	if known != null: return known
	if atlas < 0 or atlas >= atlases.size() or cell < 0 or cell >= 16: return null
	var plate: Dictionary = atlases[atlas]
	var pixels: Texture2D = plates.lookup(atlas) as Texture2D
	if pixels == null:
		# load() also returns Godot's cached instance while any owner holds it.
		pixels = load(str(plate.path)) as Texture2D
		if pixels != null: plates.store(atlas, pixels, pixels.get_width() * pixels.get_height() * 4)
	var result := AtlasTexture.new()
	result.atlas = pixels
	var a: Array = plate.rects[cell]
	result.region = Rect2(float(a[0]),float(a[1]),float(a[2]),float(a[3]))
	result.filter_clip = true
	textures.store(key, result)
	return result

## Map change: drop this cache's strong plate reserve. Plates still shown by a
## live or pooled monster stay alive through their owners and are reused.
static func release_unused() -> void:
	plates.trim(0)
	textures.prune()

static func cache_metrics() -> Dictionary:
	return {"plates":plates.metrics(), "textures":textures.metrics()}

static func material_for(visual: Dictionary, texture: Texture2D) -> ShaderMaterial:
	# The imported portrait was alpha-cleaned offline; avoid the atlas recoloring shader.
	if texture != null and texture.resource_path.begins_with("res://assets/external_l1j/monsters/"):
		return null
	var material := ShaderMaterial.new()
	if texture != null and texture.resource_path.begins_with("res://assets/l1j/verified/monsters/"):
		material.shader = preload("res://addons/twilight_l1j/source_color_key.gdshader")
		return material
	material.shader = SHADER
	material.set_shader_parameter("variation", float(visual.get("variant",0)))
	material.set_shader_parameter("accent", Color(str(visual.get("accent","c4aa64"))))
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		var size: Vector2 = atlas.atlas.get_size()
		var r: Rect2 = atlas.region
		material.set_shader_parameter("uv_rect", Vector4(r.position.x/size.x,r.position.y/size.y,r.size.x/size.x,r.size.y/size.y))
	return material
