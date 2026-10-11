extends RefCounted
## Explicit TWILIGHT art choices informed by public visual references.
## Never interpreted as original terrain IDs or navigation rules.
const PATH = "res://data/maps/reference_visual_profiles.json"
static var catalog: Dictionary = {}
const PROP_CELLS = {"house":0,"market":1,"oak":2,"oak2":2,"pine":3,"birch":2,
	"bush":4,"wall":5,"waystone":6,"crates":7,"pillar":8,"rocks":9,"rock":9}

static func profile(id: String) -> Dictionary:
	if catalog.is_empty(): catalog = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return catalog.get("maps",{}).get(id,{})

static func cell(atlas: Texture2D, index: int) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = atlas
	result.region = Rect2(Vector2(index%4,index/4)*atlas.get_size()/4.0,atlas.get_size()/4.0)
	result.filter_clip = true
	return result

static func prop_index(kind: String, family: String) -> int:
	if kind=="pillar" and family=="faith": return 12
	if kind in ["rocks","rock"] and family=="albino": return 10
	if kind in ["oak","oak2"] and family=="escaros": return 14
	return int(PROP_CELLS.get(kind,-1))
