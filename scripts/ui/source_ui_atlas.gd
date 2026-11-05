extends RefCounted
## Private original pixels, exact verified atlas keys, one decode per page.
const INDEX = preload("res://data/ui/base508_card_atlas.json")
const SOURCE_API = "res://scripts/lineagem_base508.gd"
static var pages: Dictionary = {}
static var frames: Dictionary = {}
static var missing: Dictionary = {}
static var textures: Dictionary = {}

static func frame(plist: String, key: String) -> Image:
	var identity: String = plist + ":" + key
	if frames.has(identity): return frames[identity]
	if missing.has(identity) or not ResourceLoader.exists(SOURCE_API): return null
	var entry: Dictionary = INDEX.data.atlases.get(plist,{})
	var spec: Dictionary = entry.get("frames",{}).get(key,{})
	if spec.is_empty(): return null
	var api: Script = load(SOURCE_API)
	var path: String = api.asset_path(entry.page)
	if path.is_empty() or not FileAccess.file_exists(path): return null
	if not pages.has(path):
		if FileAccess.get_sha256(path)!=entry.page_sha256:
			missing[identity]="page_hash_mismatch"; return null
		var original: Image = Image.load_from_file(path)
		if original==null or original.is_empty(): return null
		original.convert(Image.FORMAT_RGBA8)
		pages[path]=original
	var rect: Array = spec.rect
	var packed_size := Vector2i(rect[3],rect[2]) if spec.rotated else Vector2i(rect[2],rect[3])
	var page: Image = pages[path]
	var region := Rect2i(Vector2i(rect[0],rect[1]),packed_size)
	if not Rect2i(Vector2i.ZERO,page.get_size()).encloses(region):
		missing[identity]="frame_out_of_page"; return null
	var trimmed: Image = page.get_region(region)
	if spec.rotated: trimmed.rotate_90(COUNTERCLOCKWISE)
	var source_rect: Array = spec.source_rect
	if trimmed.get_size()!=Vector2i(source_rect[2],source_rect[3]):
		missing[identity]="trim_size_mismatch"; return null
	var result: Image = Image.create(spec.source_size[0],spec.source_size[1],false,Image.FORMAT_RGBA8)
	result.blit_rect(trimmed,Rect2i(Vector2i.ZERO,trimmed.get_size()),Vector2i(source_rect[0],source_rect[1]))
	frames[identity]=result
	return result

static func texture(plist: String, key: String) -> Texture2D:
	var identity: String = plist+":"+key
	if textures.has(identity): return textures[identity]
	var original: Image = frame(plist,key)
	if original==null: return null
	textures[identity]=ImageTexture.create_from_image(original)
	return textures[identity]
