extends RefCounted
class_name TwilightMonsterArt

## Original family silhouettes, cached cropped atlas views, and species-specific
## proportions/gear. This is procedural directional art, not eight authored views.
static var atlases: Array = []
static var textures: Dictionary = {}
static var plates: Dictionary = {}
const SHADER = preload("res://scripts/monsters/monster_body.gdshader")

static func texture_for(record: Dictionary) -> Texture2D:
	if not record.has("visual"): return null
	if atlases.is_empty():
		atlases = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters/art_atlases.json")) as Array
	var visual: Dictionary = record.visual
	var atlas: int = int(visual.atlas)
	var cell: int = int(visual.cell)
	var key: String = "%d:%d" % [atlas,cell]
	if textures.has(key): return textures[key] as Texture2D
	if atlas < 0 or atlas >= atlases.size() or cell < 0 or cell >= 16: return null
	var plate: Dictionary = atlases[atlas]
	if not plates.has(atlas): plates[atlas] = load(str(plate.path))
	var result := AtlasTexture.new()
	result.atlas = plates[atlas] as Texture2D
	var a: Array = plate.rects[cell]
	result.region = Rect2(float(a[0]),float(a[1]),float(a[2]),float(a[3]))
	result.filter_clip = true
	textures[key] = result
	return result

static func material_for(visual: Dictionary, texture: Texture2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("variation", float(visual.get("variant",0)))
	material.set_shader_parameter("accent", Color(str(visual.get("accent","c4aa64"))))
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		var size: Vector2 = atlas.atlas.get_size()
		var r: Rect2 = atlas.region
		material.set_shader_parameter("uv_rect", Vector4(r.position.x/size.x,r.position.y/size.y,r.size.x/size.x,r.size.y/size.y))
	return material
