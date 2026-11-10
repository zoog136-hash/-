extends SceneTree
## Diagnostic consumption of actual pinned private bytes; never Main/gameplay use.
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
var checks: int = 0
var failures: Array[String] = []
var annotation_events: int = 0
var effect_events: int = 0
var observed: Dictionary = {}
var example_frame_status: Dictionary = {}
var started_msec: int = Time.get_ticks_msec()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func argument(prefix: String) -> String:
	for item: String in OS.get_cmdline_user_args():
		if item.begins_with(prefix): return item.trim_prefix(prefix)
	return ""

func write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func write_json(path: String, value: Dictionary) -> String:
	write_bytes(path, JSON.stringify(value).to_utf8_buffer())
	return FileAccess.get_sha256(path)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var manifest_path: String = argument("--bank=")
	var expected_sha: String = argument("--manifest-sha=")
	var scratch: String = argument("--scratch=")
	if manifest_path.is_empty() or not BANK.valid_sha(expected_sha) or scratch.is_empty() or DirAccess.dir_exists_absolute(scratch):
		printerr("Explicit --bank, --manifest-sha and NEW private --scratch required.")
		quit(2)
		return
	var manifest_bytes: PackedByteArray = FileAccess.get_file_as_bytes(manifest_path)
	check(BANK.digest(manifest_bytes) == expected_sha, "supplied actual bank manifest pin matches")
	if BANK.digest(manifest_bytes) != expected_sha: finish(); return
	var manifest: Dictionary = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	var bindings: Dictionary = {}
	var loops: Dictionary = {}
	for action: int in [0,1,2,3,8,9,18,19,30]:
		bindings["action" + str(action)] = action
		loops["action" + str(action)] = action == 0 # Explicit diagnostic caller policy.
	var preview := PREVIEW.new()
	root.add_child(preview)
	preview.native_annotations.connect(func(_event: Dictionary) -> void: annotation_events += 1)
	preview.native_effect_frame.connect(func(_event: Dictionary) -> void: effect_events += 1)
	check(not preview.configure("sprite:14120", manifest_path), "ordinary base508 configure still rejects the reference-bank version")
	check(preview.configure_reference_bank(manifest_path, expected_sha, 14120, bindings, loops, "action3"), "actual nine-action source bank loads through opt-in API")
	if not preview.installed(): printerr(JSON.stringify(preview.reference_bank_status)); finish(); return
	check(preview.reference_source_frame_status().is_empty(), "configure/prefetch is not observed-frame evidence")
	check(preview.attachment_status().source_layer_nodes == 1 and preview.attachment_status().active_compatibility_layers == 0, "strict mode retains clothes identity while suppressing unverified attr8 blend")
	var tracks: Dictionary = preview.get("_playback_tracks")
	for role: String in bindings:
		var track: Dictionary = tracks[role]
		check(int(track.source_action_id) == int(bindings[role]) and track.fps == 36 and track.loop == loops[role], "explicit source action/FPS and caller loop retained: " + role)
		var total: float = 0.0
		for frame: Dictionary in track.directions[0]:
			check(is_equal_approx(frame.duration, float(frame.source_ticks) / 36.0), "duration is original ticks divided by explicit36FPS: " + role)
			total += frame.duration
		for direction: int in range(8):
			preview.advance_reference_source(0.0, "action0" if role != "action0" else "action3", direction)
			check(preview.advance_reference_source(0.0, role, direction), "explicit selected action and stored direction render: %s/%d" % [role,direction])
			var status: Dictionary = preview.reference_source_frame_status()
			check(status.get("source_action_id") == bindings[role] and status.get("stored_direction") == direction, "selected source frame trace preserves exact action/direction")
			check(status.get("whole_file_use") == false and status.get("actual_observed_original_bytes") == null and status.get("actual_main_game_feature_use") == false, "diagnostic frame evidence never promotes whole-file/Main use")
			check(status.get("selected_layers", []).size() == 2, "strict draws only exact body and shadow layers")
			for layer: Dictionary in status.get("selected_layers", []):
				check(layer.stored_bit == direction and layer.frame_index == track.directions[direction][0].source_frame and int(layer.layer_id) in [14120,14121], "stored bit/frame and original layer ID survive texture assignment")
				check(layer.raw_sha256 == manifest.members[layer.member].sha256, "selected frame retains actual raw member SHA")
				observed[layer.member] = true
			preview.advance_reference_source(total * 2.0, role, direction)
			var expected_frame: int = int(track.directions[direction][0 if loops[role] else -1].source_frame)
			check(preview.last_source_frame == expected_frame, "explicit loop wraps or one-shot holds final original frame: " + role)
	check(annotation_events == 0 and effect_events == 0, "native annotations are retained source evidence and never dispatched by this adapter")
	var before: Dictionary = preview.reference_source_frame_status()
	preview.advance_source(100.0, "attack", 4, 999, true)
	check(preview.reference_source_frame_status() == before, "legacy gameplay state cannot remap explicit reference roles")
	check(not preview.advance_reference_source(0.0, "guessed_idle", 0) and not preview.advance_reference_source(0.0, "action3", 8), "unknown role and nonstored direction cannot be guessed")
	preview.advance_reference_source(0.0, "action0", 0)
	preview.advance_reference_source(0.0, "action3", 0)
	var textures: Dictionary = preview.get("_textures")
	check(textures.has("Sprite/14120-56.sp2:0:11") and textures.has("Sprite/14120-56.sp2:7:11"), "texture cache distinguishes stored direction in the same raw file")
	preview.advance_reference_source(4.0/36.0 + 0.000001, "action3", 0)
	check(preview.last_source_frame == 0 and textures.has("Sprite/14120-56.sp2:0:0"), "original tick boundary advances to a different frame/cache key")
	var compatible := PREVIEW.new()
	root.add_child(compatible)
	compatible.playback_mode_override = "compatible"
	check(compatible.configure_reference_bank(manifest_path, expected_sha, 14120, {"chosen":3}, {"chosen":false}, "chosen") and compatible.advance_reference_source(0.0, "chosen", 0), "explicit compatible source preview renders through the same node/draw path")
	var clothes: Sprite2D = compatible.get("_effect_nodes").get(14122)
	check(clothes != null and clothes.visible and clothes.get_meta("source_attributes") == ["8"], "original clothes ID/attr8 use existing scoped compatibility policy")
	if clothes != null:
		var native_offset: Array = compatible.get("_playback_tracks").chosen.directions[0][0].effect_layers[0].offset
		check(clothes.texture.get_size() == Vector2(1,1) and clothes.position == Vector2(float(native_offset[0]),float(native_offset[1])), "legitimate empty clothes frame is transparent1x1 at its exact native offset, not a missing layer")
	var compatible_status: Dictionary = compatible.reference_source_frame_status()
	example_frame_status = compatible_status
	check(compatible_status.selected_layers.size() == 3 and compatible_status.selected_layers[-1].empty, "selected empty clothes retains exact raw frame provenance")
	# Copy only the supplied pinned bank; corruption tests never mutate its originals.
	DirAccess.make_dir_recursive_absolute(scratch)
	var copy_manifest: String = scratch.path_join("manifest.json")
	write_bytes(copy_manifest, manifest_bytes)
	for spec: Dictionary in manifest.members.values():
		write_bytes(scratch.path_join(str(spec.path)), FileAccess.get_file_as_bytes(manifest_path.get_base_dir().path_join(str(spec.path))))
	for actions: Dictionary in manifest.actors.values():
		for spec: Dictionary in actions.values():
			write_bytes(scratch.path_join(str(spec.path)), FileAccess.get_file_as_bytes(manifest_path.get_base_dir().path_join(str(spec.path))))
	var probe := PREVIEW.new()
	root.add_child(probe)
	check(not probe.configure_reference_bank(copy_manifest, "0".repeat(64), 14120, {"chosen":3}, {"chosen":false}, "chosen"), "wrong manifest pin fails closed")
	check(not probe.configure_reference_bank(copy_manifest, expected_sha, 14121, {"chosen":3}, {"chosen":false}, "chosen"), "another actor ID cannot borrow nearby source files")
	check(not probe.configure_reference_bank(copy_manifest, expected_sha, 14120, {"chosen":3}, {}, "chosen"), "missing explicit caller loop policy fails closed")
	var actor_path: String = scratch.path_join(str(manifest.actors["sprite:14120"]["3"].path))
	var actor_bytes: PackedByteArray = FileAccess.get_file_as_bytes(actor_path)
	for mutation: String in ["snapshot", "action_key", "fps", "directions", "attributes", "compact_type", "layer_proof_type"]:
		var changed_manifest: Dictionary = manifest.duplicate(true)
		var actor: Dictionary = JSON.parse_string(actor_bytes.get_string_from_utf8())
		match mutation:
			"snapshot": changed_manifest.source_snapshot = "base508"
			"action_key": actor.action_key = "list_14.spr:B999:A0"
			"fps": actor.actor.roles["source_action:3"].fps = 0
			"directions": actor.actor.roles["source_action:3"].directions.pop_back()
			"attributes": actor.erase("source_layer_declarations")
			"compact_type": actor.compact_roles = []
			"layer_proof_type": actor.source_proof.declarations = [null]
		changed_manifest.actors["sprite:14120"]["3"].sha256 = write_json(actor_path, actor)
		var changed_sha: String = write_json(copy_manifest, changed_manifest)
		check(not probe.configure_reference_bank(copy_manifest, changed_sha, 14120, {"chosen":3}, {"chosen":false}, "chosen") and not probe.installed(), "invalid selected source metadata fails closed: " + mutation)
	write_bytes(actor_path, actor_bytes)
	write_bytes(copy_manifest, manifest_bytes)
	for member: String in ["Sprite/14120-56.sp2", "Sprite/14121-56.sp2", "Sprite/14122-56.sp2"]:
		check(probe.configure_reference_bank(copy_manifest, expected_sha, 14120, {"chosen":3}, {"chosen":false}, "chosen") and probe.advance_reference_source(0.0, "chosen", 0), "actual source is primed before cache corruption: " + member)
		var raw_path: String = scratch.path_join(str(manifest.members[member].path))
		var raw: PackedByteArray = FileAccess.get_file_as_bytes(raw_path)
		if member.contains("14121"):
			DirAccess.remove_absolute(raw_path)
		else:
			# Members are re-verified when their size or modification time
			# changes (user decision 2026-11-11, see reference_sp2_bank.gd).
			# A real rewrite changes the time; wait past the 1 s resolution so
			# this same-size one-byte corruption is a real change.
			await create_timer(1.1).timeout
			var corrupt: PackedByteArray = raw.duplicate()
			corrupt[0] ^= 1
			write_bytes(raw_path, corrupt)
		check(not probe.advance_reference_source(0.0, "chosen", 0) and not probe.installed() and probe.reference_source_frame_status().is_empty(), "raw corruption/removal is rechecked despite cached textures, including strict-hidden clothes: " + member)
		write_bytes(raw_path, raw)
	for metadata_path: String in [actor_path, copy_manifest]:
		check(probe.configure_reference_bank(copy_manifest, expected_sha, 14120, {"chosen":3}, {"chosen":false}, "chosen") and probe.advance_reference_source(0.0, "chosen", 0), "metadata cache guard primed")
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(metadata_path)
		write_bytes(metadata_path, bytes + PackedByteArray([32]))
		check(not probe.advance_reference_source(0.0, "chosen", 0) and not probe.installed(), "changed pinned metadata cannot reuse cached acceptance")
		write_bytes(metadata_path, bytes)
	check(FileAccess.get_sha256(manifest_path) == expected_sha, "original source bank remained untouched")
	preview.free(); compatible.free(); probe.free()
	finish()

func finish() -> void:
	print("REFERENCE_SP2_BANK_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"duration_seconds":float(Time.get_ticks_msec()-started_msec)/1000.0,"purpose":"diagnostic_reference_preview","actual_actor_id":14120,"source_actions":9,"stored_directions":8,"selected_raw_member_paths":observed.keys(),"example_selected_frame":example_frame_status,"actual_observed_original_bytes":null,"whole_file_use":false,"actual_main_game_feature_use":false,"M_visual_equivalence_verified":false}))
	quit(0 if failures.is_empty() else 1)
