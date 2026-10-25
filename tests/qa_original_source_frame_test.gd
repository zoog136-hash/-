extends SceneTree

const QA = preload("res://tests/qa_original_source_frame.gd")
const DIRECTIONS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("SOURCE_FRAME_QA_FAIL ", label)

func _initialize() -> void:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_animation_profiles.json"))
	var directories: Array[String] = ["res://assets/actors/eight_direction/original_based/reaper_female", "res://assets/actors/eight_direction/original_based/reaper_male", str(profiles.profiles["transform:328"].frames_path).get_base_dir()]
	for directory: String in directories:
		var actor := directory.get_file()
		var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory + "/provenance.json"))
		var frames: SpriteFrames = load(directory + "/SpriteFrames.tres")
		for direction: int in range(8):
			for role: String in ["idle", "walk", "attack", "hit", "death"]:
				var key := role + "_" + str(direction)
				for phase: int in range(frames.get_frame_count(key)):
					check(not QA.recorded_frame(proof, role, DIRECTIONS[direction], phase, frames.get_frame_texture(key, phase)).is_empty(), actor + "/" + key + "/" + str(phase))
		var texture := frames.get_frame_texture("idle_0", 0)
		var selected := QA.recorded_frame(proof, "idle", "E", 0, texture)
		var selected_index: int = proof.frames.find(selected)
		if selected_index < 0:
			check(false, "negative controls require a valid source record")
			continue
		var missing: Dictionary = proof.duplicate(true)
		missing.frames[selected_index].erase("source_anchor")
		check(QA.recorded_frame(missing, "idle", "E", 0, texture).is_empty(), "missing recorded anchor is rejected")
		var duplicate: Dictionary = proof.duplicate(true)
		duplicate.frames.append(duplicate.frames[selected_index].duplicate(true))
		check(QA.recorded_frame(duplicate, "idle", "E", 0, texture).is_empty(), "ambiguous source record is rejected")
		var wrong_rectangle: Dictionary = proof.duplicate(true)
		wrong_rectangle.frames[selected_index].region[0] += 1
		check(QA.recorded_frame(wrong_rectangle, "idle", "E", 0, texture).is_empty(), "changed source rectangle is rejected")
		var wrong_png: Dictionary = proof.duplicate(true)
		if wrong_png.has("source_files"):
			wrong_png.source_files[int(selected.sheet)].path = "res://assets/ui/potionRed.png"
		else:
			wrong_png.tracks.idle.atlas_files[0].path = "res://assets/ui/potionRed.png"
		check(QA.recorded_frame(wrong_png, "idle", "E", 0, texture).is_empty(), "wrong source PNG is rejected")
		check(QA.recorded_frame(proof, "idle", "E", -1, texture).is_empty(), "negative phase is rejected")
		var path := directory + "/SpriteFrames.tres"
		check(QA.pinned_existing_walk_two(proof, path, "transform:258") == (actor == "reaper_male"), "only original male reaper admits its recorded walk count")
		check(not QA.pinned_existing_walk_two(proof, path, "transform:999"), "new identity cannot borrow historical frame exception")
		check(not QA.pinned_existing_walk_two(missing, path, "transform:258"), "changed provenance cannot borrow historical exception")
	print("SOURCE_FRAME_QA_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	if failures.is_empty(): print("SOURCE_FRAME_QA_OK")
	quit(0 if failures.is_empty() else 1)
