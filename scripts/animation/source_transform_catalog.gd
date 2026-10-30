extends RefCounted
## Locally installed, individually reviewed source appearances. No gameplay fields.
const MANIFEST_PATH = "res://data/source_transform_visuals.json"
static var entries: Dictionary = {}

static func configure(profile: Resource, kind: String, record: Dictionary) -> void:
	if kind != "transform" or str(record.get("grade", "")) not in ["일반", "고급", "희귀", "영웅", "전설"]: return
	if entries.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary: entries = parsed.get("entries", {})
	var entry: Dictionary = entries.get(profile.profile_id, {})
	if entry.is_empty() or str(record.get("name", "")) != str(entry.get("name", "")) or str(record.get("grade", "")) != str(entry.get("grade", "")): return
	var path: String = str(entry.get("frames_path", ""))
	if not ResourceLoader.exists(path): return
	# Retain layout, projectile/hit/collision offsets, timing and hit markers.
	# Baphomet already uses directional8; changing layout would change projectiles.
	# The generated visual manifest can promote directional4 to authored4.
	# Both retain the same legacy projectile geometry; preserve the actual
	# configured layout rather than overriding either presentation adapter.
	if (str(profile.layout) == "directional8") != (str(entry.get("required_layout", "")) == "directional8"): return
	profile.frames_path = path
	profile.animation_names = {}
	profile.pixel_scale = float(entry.pixel_scale)
	profile.sprite_offset = Vector2(float(entry.sprite_offset[0]), float(entry.sprite_offset[1]))
	profile.color_tint = Color.WHITE
	profile.authored_motion_weight = 0.0
	# Reviewed aliases may opt in to their canonical action clock. Pass the
	# declaration once; ActorMotion validates and caches identical timelines.
	if bool(entry.get("canonical_alias_clocks", false)):
		var aliases: Variant = entry.get("same_model_aliases", {})
		if aliases is Dictionary:
			var clock_aliases: Dictionary = {}
			for pair: Array in [["recovery", "attack"], ["corpse", "death"]]:
				if str(aliases.get(pair[0], "")) == pair[1]:
					clock_aliases[pair[0]] = pair[1]
			if not clock_aliases.is_empty():
				profile.set_meta("twilight_explicit_role_timeline_aliases", clock_aliases)
