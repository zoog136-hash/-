extends RefCounted
class_name TwilightSkillSPXBridge

## Optional private SPX effect pack; missing files retain procedural VFX.
const BINDINGS_PATH := "res://data/skills/external_spx_name_bindings.json"
const PREFIX := "res://assets/external_spx/skills/"

var bindings: Dictionary = {}
var families: Dictionary = {}
var cache: Dictionary = {}
var installed_layouts: Dictionary = {}

func _init() -> void:
	var manifest_path := "res://data/external_spx/skills_manifest.json"
	if FileAccess.file_exists(manifest_path):
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if manifest is Dictionary: installed_layouts = manifest.get("families", {})
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BINDINGS_PATH))
	if not (parsed is Dictionary):
		return
	if parsed.get("bindings", {}) is Dictionary:
		bindings = parsed["bindings"]
	if parsed.get("families", {}) is Dictionary:
		families = parsed["families"]

func binding_for(id: String) -> Dictionary:
	var value: Variant = bindings.get(id, {})
	return value as Dictionary if value is Dictionary else {}

func clip_for(id: String, phase: String) -> String:
	var binding: Dictionary = binding_for(id)
	var phases: Variant = binding.get("phases", {})
	if not (phases is Dictionary):
		return ""
	return str(phases.get(phase, ""))

func layout_for(id: String, phase: String) -> Dictionary:
	var family := str(binding_for(id).get("family", ""))
	return installed_layouts.get(family, {}).get("layout", {}).get(clip_for(id, phase), {})

func frames_for(id: String, phase: String) -> SpriteFrames:
	var binding: Dictionary = binding_for(id)
	var family := str(binding.get("family", ""))
	var clip := clip_for(id, phase)
	if family.is_empty() or clip.is_empty() or not families.has(family):
		return null
	var frames: SpriteFrames
	if cache.has(family):
		frames = cache[family] as SpriteFrames
	else:
		var path := PREFIX + family + "/SpriteFrames.tres"
		if not ResourceLoader.exists(path):
			return null
		frames = load(path) as SpriteFrames
		if frames == null:
			return null
		cache[family] = frames
	if frames == null or not frames.has_animation(clip):
		return null
	var count := frames.get_frame_count(clip)
	if count < 1 or count > 64:
		return null
	for index: int in range(count):
		if frames.get_frame_texture(clip, index) == null:
			return null
	return frames
