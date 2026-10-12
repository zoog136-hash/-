extends RefCounted
class_name TwilightPresentationCatalog

## Body assignments describe inspected TWILIGHT art, not original-game taxonomy.
## Unknown/new records get a conservative shared rig without name heuristics.
const PATH = "res://data/animation_presentation.json"
const MANIFEST = preload("res://scripts/animation/visual_manifest.gd")
static var data: Dictionary = {}

static func configure(profile: TwilightAnimationProfile, kind: String, record: Dictionary) -> void:
	if data.is_empty(): data = JSON.parse_string(FileAccess.get_file_as_string(PATH)) as Dictionary
	var body: String = "humanoid"
	if kind == "transform":
		body = str(data.transforms.get(str(record.get("sourceId", "")), {}).get("body", "humanoid"))
	elif kind == "monster":
		body = str(data.monster_bodies.get(str(record.get("visual", {}).get("body", "")), "humanoid"))
		# The installed source can differ from the fallback atlas family (a
		# biped werewolf vs a quadruped wolf, for example). Prefer reviewed art.
		var source: String = str(MANIFEST.monster_binding(record).get("path", ""))
		if not source.is_empty() and ResourceLoader.exists(source):
			body = str(data.get("monster_sources", {}).get(source, {}).get("body", body))
	var override: Dictionary = record.get("animation_profile", {})
	body = str(override.get("body_kind", body))
	profile.body_kind = body
	var settings: Dictionary = data.archetypes.get(body, data.archetypes.humanoid)
	for property: String in settings: profile.set(property, settings[property])
	for property: String in settings:
		if override.has(property): profile.set(property, override[property])
	profile.presentation = data.bosses.get(profile.profile_id, {}).duplicate(true)
	profile.presentation.merge(override.get("presentation", {}), true)
	if not profile.presentation.is_empty():
		profile.attack_animation_speed = float(profile.presentation.get("animation_speed", profile.attack_animation_speed))
		for role: String in ["attack", "cast", "special"]:
			if not profile.animation_names.has(role):
				profile.animation_names[role] = str(profile.presentation.get(role + "_animation", role))
