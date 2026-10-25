extends RefCounted

const PINNED_REAPER_PATH := "res://assets/actors/eight_direction/original_based/reaper_male/SpriteFrames.tres"
const PINNED_REAPER_PROOF_SHA := "6402666115e8f7b45ea3a7a333e8755c2c28545f575bec442026bd295db38406"

static func pinned_existing_walk_two(proof: Dictionary, frames_path: String, profile_id: String) -> bool:
	if frames_path != PINNED_REAPER_PATH or profile_id != "transform:258": return false
	var path := frames_path.get_base_dir().path_join("provenance.json")
	return FileAccess.get_sha256(path) == PINNED_REAPER_PROOF_SHA and proof == JSON.parse_string(FileAccess.get_file_as_string(path))

static func recorded_frame(proof: Dictionary, role: String, direction: String, phase: int, texture: Texture2D) -> Dictionary:
	if phase < 0 or not texture is AtlasTexture: return {}
	var atlas := texture as AtlasTexture
	if atlas.atlas == null: return {}
	var track: Dictionary = proof.get("tracks", {}).get(role, {})
	var rows: Array = track.get("source_rows", [])
	var files: Array = proof.get("source_files", [])
	var matches: Array[Dictionary] = []
	for frame: Dictionary in proof.get("frames", []):
		if str(frame.get("direction", "")) != direction: continue
		if frame.has("role") or frame.has("phase"):
			if str(frame.get("role", "")) != role or int(frame.get("phase", -1)) != phase: continue
		else:
			# Initial approved packs record role phases in tracks.source_rows.
			# Read their existing row/PNG/rect/anchor; never invent an anchor.
			if phase >= rows.size() or int(frame.get("row", -1)) != int(rows[phase]): continue
		var sheet := int(frame.get("sheet", -1))
		var source_path := ""
		if sheet >= 0 and sheet < files.size():
			source_path = str(files[sheet].get("path", ""))
		elif sheet >= 0:
			for file: Dictionary in track.get("atlas_files", []):
				if str(file.get("path", "")).ends_with("/poses-%d.png" % sheet):
					source_path = str(file.path)
		if source_path.is_empty() or source_path != atlas.atlas.resource_path: continue
		var region: Array = frame.get("region", [])
		var margin: Array = frame.get("margin", [])
		var anchor: Array = frame.get("source_anchor", [])
		if region.size() != 4 or margin.size() != 4 or anchor.size() != 2: continue
		if Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3])) != atlas.region: continue
		if Rect2(float(margin[0]), float(margin[1]), float(margin[2]), float(margin[3])) != atlas.margin: continue
		matches.append(frame)
	# A missing, ambiguous, wrong-PNG or changed-rectangle record stays a fail.
	return matches[0] if matches.size() == 1 else {}
